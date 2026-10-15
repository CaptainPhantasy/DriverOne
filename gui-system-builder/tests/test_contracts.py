"""Record and command-boundary checks. These tests do not drive a GUI."""
import contextlib
import copy
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import profile_tools as records
import gui_control as control
import live_fixture as fixture


def profile():
    return {"schema_version": 1, "name": "fixture", "platform": "macos",
            "identity": {"bundle_id": "local.gui.operation.fixture", "app_path": "/tmp/Fixture.app"},
            "expected_version": {"version": "1.0", "build": "1"}}


def workflow():
    return {"schema_version": 1, "id": "fixture-flow", "profile_name": "fixture", "goal": "Verify a fixture edit",
            "preconditions": ["The exact fixture is running"],
            "steps": [{"id": "observe", "intent": "Read the target", "action": "observe",
                       "expected": ["Fixture input is visible"], "repetition": "safe-after-check"}],
            "completion": ["The expected result was observed"], "restoration": ["Restore the original input"]}


class RecordsTests(unittest.TestCase):
    def test_valid_profile_and_workflow_bind(self):
        p = records.validate_profile(profile())
        self.assertEqual(records.validate_workflow(workflow(), p)["profile_name"], p["name"])

    def test_mismatched_workflow_target_is_rejected(self):
        w = workflow(); w["profile_name"] = "other-app"
        with self.assertRaises(records.RecordError): records.validate_workflow(w, profile())

    def test_executable_in_profile_is_rejected(self):
        for field in ("command", "shell", "startup_args", "helper_path", "environment"):
            p = profile(); p[field] = "/bin/sh -c touch /tmp/unrequested"
            with self.subTest(field=field), self.assertRaises(records.RecordError): records.validate_profile(p)

    def test_profile_cannot_hide_shell_in_identity(self):
        p = profile(); p["identity"]["shell"] = "/bin/sh"
        with self.assertRaises(records.RecordError): records.validate_profile(p)

    def test_relative_native_path_and_boolean_schema_rejected(self):
        p = profile(); p["identity"]["app_path"] = "Fixture.app"
        with self.assertRaises(records.RecordError): records.validate_profile(p)
        p = profile(); p["schema_version"] = True
        with self.assertRaises(records.RecordError): records.validate_profile(p)

    def test_bundle_identifier_empty_segments_rejected(self):
        for bundle_id in ("dev..app", "dev.app.", ".dev.app", "dev.app.."):
            p = profile(); p["identity"]["bundle_id"] = bundle_id
            with self.subTest(bundle_id=bundle_id), self.assertRaises(records.RecordError): records.validate_profile(p)

    def test_web_origin_has_no_credentials_or_page_path(self):
        for origin in ("https://user:secret@example.test", "https://example.test/private", "https://example.test/?token=x"):
            p = {"schema_version": 1, "name": "web-fixture", "platform": "web", "identity": {"url_origin": origin}}
            with self.subTest(origin=origin), self.assertRaises(records.RecordError): records.validate_profile(p)

    def test_duplicate_json_and_nonfinite_numbers_rejected(self):
        with tempfile.TemporaryDirectory(prefix="gui-record-test-") as directory:
            p = Path(directory) / "record.json"
            for text in ('{"name":"first","name":"second"}', '{"nested":{"x":1,"x":2}}', '{"n":NaN}', '{"n":Infinity}', '{"n":-Infinity}'):
                p.write_text(text, encoding="utf-8")
                with self.subTest(text=text), self.assertRaises(records.RecordError): records.load_record(str(p))

    def test_duplicate_workflow_steps_rejected(self):
        w = workflow(); w["steps"].append(copy.deepcopy(w["steps"][0]))
        with self.assertRaises(records.RecordError): records.validate_workflow(w, profile())

    def test_mutation_repetition_and_unknown_actions_rejected(self):
        for action in ("save", "submit", "exec-shell"):
            w = workflow(); w["steps"][0]["action"] = action
            with self.subTest(action=action), self.assertRaises(records.RecordError): records.validate_workflow(w, profile())

    def test_profile_fingerprint_changes_with_target(self):
        p = profile(); altered = copy.deepcopy(p); altered["identity"]["bundle_id"] = "local.other.fixture"
        self.assertNotEqual(records.fingerprint(p), records.fingerprint(altered))
        reordered = dict(reversed(list(p.items())))
        self.assertEqual(records.fingerprint(p), records.fingerprint(reordered))


class CommandBoundaryTests(unittest.TestCase):
    def test_duplicate_profile_target_flags_are_refused(self):
        for flags in (("--profile", "/tmp/first.json", "--profile", "/tmp/second.json"),
                      ("--profile", "/tmp/first.json", "--profile=/tmp/second.json"),
                      ("--profile=/tmp/first.json", "--profile=/tmp/second.json")):
            with self.subTest(flags=flags), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                control.parser().parse_args([*flags, "info"])
            self.assertEqual(error.exception.code, 2)

    def test_duplicate_process_target_flags_are_refused(self):
        for flags in (("--pid", "12", "--pid", "13"),
                      ("--pid", "12", "--pid=13"),
                      ("--pid=12", "--pid=13")):
            with self.subTest(flags=flags), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                control.parser().parse_args(["--profile", "/tmp/fixture.json", *flags, "info"])
            self.assertEqual(error.exception.code, 2)

    def test_target_and_action_option_abbreviations_are_refused(self):
        for arguments in (("--prof", "/tmp/fixture.json", "info"),
                          ("--profile", "/tmp/fixture.json", "activate", "--window-i", "1"),
                          ("--profile", "/tmp/fixture.json", "snapshot", "--max-n", "50"),
                          ("--profile", "/tmp/fixture.json", "press", "--snap", "/tmp/snapshot.json", "--id", "main/0")):
            with self.subTest(arguments=arguments), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                control.parser().parse_args(arguments)
            self.assertEqual(error.exception.code, 2)

    def test_argv_keeps_shell_punctuation_literal(self):
        literal = '$(touch /tmp/gui-suite-should-not-exist); `echo unsafe` & | >'
        result = control.execute([sys.executable, "-c", "import json,sys; print(json.dumps({'ok':True,'arg':sys.argv[1]}))", literal])
        self.assertEqual(result["arg"], literal)

    def test_stdin_is_not_appended_to_command_arguments(self):
        with patch.object(control.subprocess, "run", return_value=subprocess.CompletedProcess(["helper"], 0, '{"ok":true}', "")) as run:
            control.execute(["helper", "--value-stdin"], text="private text")
        args, kwargs = run.call_args
        self.assertEqual(args[0], ["helper", "--value-stdin"])
        self.assertEqual(kwargs["input"], "private text")
        self.assertNotIn("shell", kwargs)

    def test_absent_backend_does_not_simulate_a_control(self):
        with patch.object(control.platform, "system", return_value="Darwin"), patch.object(control, "NATIVE", Path("/tmp/nonexistent-gui-helper")):
            with self.assertRaises(control.ControlError): control.native_arguments(profile(), "snapshot")

    def test_platform_without_adapter_is_refused(self):
        p = {"schema_version": 1, "name": "linux-fixture", "platform": "linux", "identity": {"executable_path": "/usr/bin/fixture"}}
        with self.assertRaises(control.ControlError): control.native_arguments(p, "info")

    def test_app_path_bundle_and_version_mismatch_refused(self):
        actual = {"bundle_id": "local.gui.operation.fixture", "app_path": "/tmp/Fixture.app", "version": "1.0", "build": "1", "pid": 74251}
        for key, wrong in (("bundle_id", "local.wrong.app"), ("app_path", "/tmp/Other.app"), ("version", "2.0"), ("build", "2")):
            changed = dict(actual); changed[key] = wrong
            with self.subTest(key=key), self.assertRaises(control.ControlError): control.verify_info(profile(), changed)

    def test_snapshot_limits_reject_before_capture(self):
        with tempfile.TemporaryDirectory(prefix="gui-record-test-") as directory:
            p = Path(directory) / "profile.json"; p.write_text(json.dumps(profile()), encoding="utf-8")
            actual = {"ok": True, "bundle_id": "local.gui.operation.fixture", "app_path": "/tmp/Fixture.app", "version": "1.0", "build": "1", "pid": 74251}
            for flags in (("--max-nodes", "0"), ("--max-depth", "81"), ("--max-value-chars", "4097"), ("--output-dir", "relative"), ("--enhance",)):
                with self.subTest(flags=flags), patch.object(control, "native_arguments", return_value=["helper", "info"]), patch.object(control, "execute", return_value=actual) as execute:
                    with self.assertRaises(control.ControlError): control.main(["--profile", str(p), "snapshot", *flags])
                    self.assertEqual(execute.call_count, 1, "No capture may follow invalid options")

    def test_observed_process_is_retained_for_following_action(self):
        with tempfile.TemporaryDirectory(prefix="gui-record-test-") as directory:
            p = Path(directory) / "profile.json"; p.write_text(json.dumps(profile()), encoding="utf-8")
            actual = {"ok": True, "bundle_id": "local.gui.operation.fixture", "app_path": "/tmp/Fixture.app", "version": "1.0", "build": "1", "pid": 74251}
            with patch.object(control, "native_arguments", return_value=["helper"]) as arguments, patch.object(control, "execute", side_effect=[actual, {"ok": True, "performed": "activate"}]), contextlib.redirect_stdout(io.StringIO()):
                control.main(["--profile", str(p), "activate"])
            self.assertEqual(arguments.call_args_list[0].args[1:], ("info", None))
            self.assertEqual(arguments.call_args_list[1].args[1:], ("activate", 74251), "The action must stay on the process observed by info")

    def test_invalid_observed_process_refuses_following_action(self):
        with tempfile.TemporaryDirectory(prefix="gui-record-test-") as directory:
            p = Path(directory) / "profile.json"; p.write_text(json.dumps(profile()), encoding="utf-8")
            for invalid_pid in (None, True, 0, -1, "74251", 2147483648):
                actual = {"ok": True, "bundle_id": "local.gui.operation.fixture", "app_path": "/tmp/Fixture.app", "version": "1.0", "build": "1", "pid": invalid_pid}
                with self.subTest(pid=invalid_pid), patch.object(control, "native_arguments", return_value=["helper"]), patch.object(control, "execute", return_value=actual) as execute:
                    with self.assertRaisesRegex(control.ControlError, "valid checked process identifier"):
                        control.main(["--profile", str(p), "activate"])
                    self.assertEqual(execute.call_count, 1, "No action may follow invalid process identity")

    def test_timeout_is_unknown_and_not_retried(self):
        with patch.object(control.subprocess, "run", side_effect=subprocess.TimeoutExpired(["helper"], 30)) as run:
            with self.assertRaisesRegex(control.ControlError, "Outcome unknown"): control.execute(["helper"])
        self.assertEqual(run.call_count, 1)

    def test_invalid_adapter_reply_is_not_success(self):
        for reply in ('not-json', '{"ok":false}', '[]'):
            with self.subTest(reply=reply), patch.object(control.subprocess, "run", return_value=subprocess.CompletedProcess(["helper"], 0, reply, "")):
                with self.assertRaises(control.ControlError): control.execute(["helper"])


class FixtureOwnershipTests(unittest.TestCase):
    def exercise(self):
        app = fixture.Exercise('/tmp/gui-fixture-owned-test', str(SCRIPTS.parent), 1)
        app.original = 'original'
        app.owned_values = {'test-written'}
        return app

    def tree(self, value):
        return {'nodes': [{'id': 'main/1', 'identity': {'identifier': 'fixture.input'}, 'value': value}]}

    def test_failure_cleanup_preserves_unrelated_field_changes(self):
        app = self.exercise()
        with patch.object(app, 'snapshot', return_value=({}, self.tree('changed elsewhere'))), patch.object(app, 'set_value') as setter:
            with self.assertRaisesRegex(AssertionError, 'preserved the changed field'): app.restore_after_failure()
        setter.assert_not_called()

    def test_failure_cleanup_restores_only_a_known_test_write(self):
        app = self.exercise()
        with patch.object(app, 'snapshot', side_effect=[({}, self.tree('test-written')), ({}, self.tree('original'))]), patch.object(app, 'set_value') as setter:
            result = app.restore_after_failure()
        self.assertEqual(setter.call_count, 1)
        self.assertEqual(setter.call_args.args[2], 'original')
        self.assertTrue(result['input_restored'])


if __name__ == "__main__":
    unittest.main()
