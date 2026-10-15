#!/usr/bin/env python3
"""Real local macOS fixture checks. Full mode sends GUI input; build and verify modes do not."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import struct
import subprocess
import sys
import time

BUNDLE_ID = "local.gui.operation.fixture"
EXPECTED_NATIVE_VALUE = "GUI_NATIVE_Ω🙂"


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run_checked(argv, timeout=30):
    result = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(json.dumps({"command": argv, "exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr}, ensure_ascii=False))
    return result


def builder_path(suite_root):
    root = Path(suite_root).resolve()
    return root if (root / "scripts" / "gui_control.py").is_file() else root / "gui-system-builder"


def build_fixture(work_dir, suite_root):
    if sys.platform != "darwin": raise ValueError("The live fixture is a macOS test app")
    work = Path(work_dir).resolve()
    if not Path(work_dir).is_absolute(): raise ValueError("--work-dir must be absolute")
    work.mkdir(parents=True, exist_ok=True)
    builder = builder_path(suite_root)
    source = builder / "tests" / "fixtures" / "fixture.swift"
    app = work / "GUI Operation Fixture.app"
    contents = app / "Contents"
    binary = contents / "MacOS" / "gui-fixture"
    existing_info = contents / "Info.plist"
    if existing_info.exists():
        existing = plistlib.loads(existing_info.read_bytes())
        if existing.get("CFBundleIdentifier") != BUNDLE_ID: raise ValueError("Refusing to replace an unrelated app bundle")
    binary.parent.mkdir(parents=True, exist_ok=True)
    (contents / "Resources").mkdir(exist_ok=True)
    info = {"CFBundleExecutable": "gui-fixture", "CFBundleIdentifier": BUNDLE_ID,
            "CFBundleName": "GUI Operation Fixture", "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0", "CFBundleVersion": "1", "NSPrincipalClass": "NSApplication",
            "NSHighResolutionCapable": True}
    existing_info.write_bytes(plistlib.dumps(info, sort_keys=True))
    architecture = platform.machine()
    if architecture not in ("arm64", "x86_64"): raise ValueError("Unsupported fixture build architecture")
    run_checked(["/usr/bin/xcrun", "swiftc", "-O", "-parse-as-library", "-swift-version", "5", "-target", architecture + "-apple-macosx14.0",
                 "-module-cache-path", str(work / "swift-module-cache"), str(source), "-o", str(binary)], timeout=60)
    binary.chmod(0o755)
    profile = {"schema_version": 1, "name": "gui-operation-fixture", "platform": "macos",
               "identity": {"bundle_id": BUNDLE_ID, "app_path": str(app)},
               "expected_version": {"version": "1.0", "build": "1"},
               "capabilities": {"electron_accessibility": False},
               "limits": ["Local fixture only; no network or paid operations"]}
    profile_path = work / "fixture-profile.json"
    profile_path.write_text(json.dumps(profile, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = {"ok": True, "mode": "build-only", "app_path": str(app), "binary": str(binary),
              "profile_file": str(profile_path), "fixture_source_sha256": sha(source), "fixture_binary_sha256": sha(binary)}
    (work / "fixture-build.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


class Exercise:
    def __init__(self, work_dir, suite_root, pid):
        self.work = Path(work_dir).resolve()
        self.builder = builder_path(suite_root)
        self.driver = self.builder / "scripts" / "gui_control.py"
        self.profile = self.work / "fixture-profile.json"
        self.pid = pid
        self.records = []
        self.checks = []
        self.original = None
        self.original_scroll = None
        self.owned_values = set()
        self.small_window = None

    def call(self, arguments, text=None, refusal=None, profile=None):
        argv = [sys.executable, str(self.driver), "--profile", str(profile or self.profile), "--pid", str(self.pid), *arguments]
        completed = subprocess.run(argv, input=text, capture_output=True, text=True, timeout=15)
        output = json.loads(completed.stdout)
        record = {"action": arguments[0], "exit": completed.returncode, "result": output}
        self.records.append(record)
        if refusal is not None:
            actual = output.get("backend_result", output).get("error")
            if completed.returncode == 0 or actual not in refusal:
                raise AssertionError({"expected_refusal": sorted(refusal), "actual": record})
        elif completed.returncode != 0 or output.get("ok") is not True:
            raise AssertionError(record)
        elif arguments[0] in ("set-value", "type") and isinstance(text, str):
            self.owned_values.add(text)
        return output

    def snapshot(self, window_id=None, screenshot=False):
        arguments = ["snapshot", "--output-dir", str(self.work / "captures"), "--max-value-chars", "512"]
        if window_id is not None: arguments += ["--window-id", str(window_id)]
        if screenshot: arguments += ["--screenshot"]
        summary = self.call(arguments)
        tree = json.loads(Path(summary["snapshot_file"]).read_text(encoding="utf-8"))
        if tree["truncated"]: raise AssertionError("Fixture tree is truncated")
        return summary, tree

    @staticmethod
    def node(tree, identifier):
        matches = [node for node in tree["nodes"] if node["identity"]["identifier"] == identifier]
        if len(matches) != 1: raise AssertionError({"identifier": identifier, "matches": len(matches)})
        return matches[0]

    def set_value(self, summary, node, text):
        return self.call(["set-value", "--snapshot", summary["snapshot_file"], "--id", node["id"], "--value-stdin"], text)

    def press(self, identifier, window_id=None):
        summary, tree = self.snapshot(window_id)
        node = self.node(tree, identifier)
        self.call(["press", "--snapshot", summary["snapshot_file"], "--id", node["id"]])

    def check(self, name, observed): self.checks.append({"name": name, "status": "PASS", "observed": observed})

    @staticmethod
    def point(tree, node):
        bounds, window = node["bounds"], tree["main_window_bounds"]
        return bounds["x"] - window["x"] + bounds["width"] / 2, bounds["y"] - window["y"] + bounds["height"] / 2

    def live(self):
        self.call(["activate"])
        summary, tree = self.snapshot(screenshot=True)
        input_node = self.node(tree, "fixture.input")
        original = input_node["value"]
        self.original = original
        header = Path(summary["screenshot_file"]).read_bytes()[:24]
        if header[:8] != b"\x89PNG\r\n\x1a\n": raise AssertionError("Capture is not PNG")
        dimensions = struct.unpack(">II", header[16:24])
        if dimensions[0] < 800 or dimensions[1] < 650: raise AssertionError("Fixture capture is unexpectedly small")
        main_window = tree["window_id"]
        self.check("actual main-window PNG and complete tree", {"snapshot": summary["snapshot_file"], "image": summary["screenshot_file"], "pixels": dimensions, "nodes": tree["node_count"]})
        direct = "DIRECT_Ω🙂"
        stale_summary, stale_node = summary, input_node
        self.set_value(summary, input_node, direct)
        summary, tree = self.snapshot(); input_node = self.node(tree, "fixture.input")
        if input_node["value"] != direct: raise AssertionError("Direct Unicode replacement differs")
        self.check("direct Unicode replacement", input_node["value"])
        self.call(["set-value", "--snapshot", stale_summary["snapshot_file"], "--id", stale_node["id"], "--value-stdin"], "wrong", refusal={"SNAPSHOT_STALE"})
        summary, tree = self.snapshot(); input_node = self.node(tree, "fixture.input")
        if input_node["value"] != direct: raise AssertionError("Stale refusal changed text")
        self.check("stale value reference refused without a change", direct)
        secure = self.node(tree, "fixture.secure")
        if secure["value"] != "[REDACTED_SECURE_FIELD]" or not secure["value_redacted"]: raise AssertionError("Secure value was not redacted")
        self.call(["set-value", "--snapshot", summary["snapshot_file"], "--id", secure["id"], "--value-stdin"], "not-entered", refusal={"SECURE_VALUE_REJECTED"})
        self.check("secure field redacted and write refused", "SECURE_VALUE_REJECTED")

        altered = json.loads(self.profile.read_text(encoding="utf-8")); altered["name"] = "different-profile"
        mismatch = self.work / "mismatched-profile.json"
        mismatch.write_text(json.dumps(altered, indent=2) + "\n", encoding="utf-8")
        self.call(["set-value", "--snapshot", summary["snapshot_file"], "--id", input_node["id"], "--value-stdin"], "wrong", refusal={"INVALID_SNAPSHOT"}, profile=mismatch)
        self.check("snapshot from a different profile refused", "INVALID_SNAPSHOT")
        self.set_value(summary, input_node, "")
        summary, tree = self.snapshot(); input_node = self.node(tree, "fixture.input")
        x, y = self.point(tree, input_node)
        self.call(["click", "--snapshot", summary["snapshot_file"], "--x", str(x), "--y", str(y)])
        summary, tree = self.snapshot(); input_node = self.node(tree, "fixture.input")
        if tree["focused_id"] != input_node["id"]: raise AssertionError("Click did not focus input")
        self.call(["type", "--snapshot", summary["snapshot_file"], "--id", input_node["id"], "--value-stdin"], EXPECTED_NATIVE_VALUE)
        summary, tree = self.snapshot(); input_node = self.node(tree, "fixture.input")
        if input_node["value"] != EXPECTED_NATIVE_VALUE: raise AssertionError("Native Unicode typing differs")
        self.check("pointer focus and native Unicode input", input_node["value"])
        self.call(["hotkey", "--snapshot", summary["snapshot_file"], "--keys", "cmd+a"])
        summary, tree = self.snapshot(); input_node = self.node(tree, "fixture.input")
        replacement = "DRAG_SELECT_ASCII"
        self.call(["type", "--snapshot", summary["snapshot_file"], "--id", input_node["id"], "--value-stdin"], replacement)
        summary, tree = self.snapshot(); input_node = self.node(tree, "fixture.input")
        if input_node["value"] != replacement: raise AssertionError("Shortcut did not replace the entire value")
        self.check("native select-all shortcut and replacement", replacement)
        bounds, window = input_node["bounds"], tree["main_window_bounds"]
        y = bounds["y"] - window["y"] + bounds["height"] / 2
        self.call(["drag", "--snapshot", summary["snapshot_file"], "--from-x", str(bounds["x"] - window["x"] + 2), "--from-y", str(y), "--to-x", str(bounds["x"] - window["x"] + bounds["width"] - 2), "--to-y", str(y)])
        summary, tree = self.snapshot(); input_node = self.node(tree, "fixture.input")
        self.call(["type", "--snapshot", summary["snapshot_file"], "--id", input_node["id"], "--value-stdin"], EXPECTED_NATIVE_VALUE)
        summary, tree = self.snapshot(); input_node = self.node(tree, "fixture.input")
        if input_node["value"] != EXPECTED_NATIVE_VALUE: raise AssertionError("Drag did not select and replace the entire text")
        self.check("native drag selection and replacement", EXPECTED_NATIVE_VALUE)
        self.press("fixture.apply")
        summary, tree = self.snapshot()
        if self.node(tree, "fixture.status")["value"] != "Applied: " + EXPECTED_NATIVE_VALUE: raise AssertionError("Apply status differs")
        self.check("button action updates actual status", "Applied: " + EXPECTED_NATIVE_VALUE)
        self.press("fixture.save")
        saved = self.work / "fixture-saved.txt"
        if saved.read_text(encoding="utf-8") != EXPECTED_NATIVE_VALUE: raise AssertionError("Saved file content differs")
        self.check("save action persists exact UTF-8 file", {"path": str(saved), "sha256": sha(saved)})

        self.press("fixture.remember-view")
        summary, tree = self.snapshot()
        scrollers = [n for n in tree["nodes"] if n["role"] == "AXScrollBar"]
        if len(scrollers) != 1: raise AssertionError({"expected": "one native scroll bar", "actual": len(scrollers)})
        initial_scroll = float(scrollers[0]["value"])
        self.original_scroll = initial_scroll
        scroll_area = self.node(tree, "fixture.scroll")
        x, y = self.point(tree, scroll_area)
        self.call(["scroll", "--snapshot", summary["snapshot_file"], "--direction", "down", "--lines", "4", "--x", str(x), "--y", str(y)])
        moved = None
        for _ in range(8):
            summary, tree = self.snapshot()
            current_scroll = float(next(n for n in tree["nodes"] if n["role"] == "AXScrollBar")["value"])
            if current_scroll > initial_scroll:
                moved = current_scroll; break
            time.sleep(0.05)
        if moved is None: raise AssertionError("Native wheel did not move the scrolling content")
        self.press("fixture.restore-view")
        restored_scroll = None
        for _ in range(8):
            summary, tree = self.snapshot()
            current_scroll = float(next(n for n in tree["nodes"] if n["role"] == "AXScrollBar")["value"])
            if abs(current_scroll - initial_scroll) < 0.0001:
                restored_scroll = current_scroll; break
            time.sleep(0.05)
        if restored_scroll is None: raise AssertionError("Application view restore did not restore the initial scroll position")
        self.check("native wheel moves content; app view action restores original position", {"initial": initial_scroll, "moved": moved, "restored": restored_scroll, "restoration_method": "observed Remember view and Restore view button actions"})

        before_dialog = self.call(["info"])
        previous_windows = {w["window_id"] for w in before_dialog["windows"]}
        self.press("fixture.open-dialog")
        info = self.call(["info"])
        small = [w for w in info["windows"] if w["on_screen"] and w["layer"] == 0 and w["window_id"] not in previous_windows]
        if len(small) != 1: raise AssertionError({"small_window_candidates": small, "windows": info["windows"]})
        small_id = small[0]["window_id"]
        self.small_window = small_id
        self.call(["activate", "--window-id", str(small_id)])
        small_summary, small_tree = self.snapshot(small_id, screenshot=True)
        dialog_input = self.node(small_tree, "fixture.dialog-input")
        self.set_value(small_summary, dialog_input, "dialog Ω")
        small_summary, small_tree = self.snapshot(small_id)
        if self.node(small_tree, "fixture.dialog-input")["value"] != "dialog Ω": raise AssertionError("Small-window value differs")
        self.check("explicit small-window snapshot and value action", {"window_id": small_id, "window_bounds": small_tree["main_window_bounds"]})
        summary, tree = self.snapshot(main_window)
        self.call(["hotkey", "--snapshot", summary["snapshot_file"], "--keys", "cmd+a"], refusal={"SELECTED_WINDOW_NOT_FOCUSED"})
        self.check("main-window input refused while sibling window is focused", "SELECTED_WINDOW_NOT_FOCUSED")
        self.press("fixture.close-dialog", small_id)
        self.small_window = None
        self.call(["activate", "--window-id", str(main_window)])
        summary, tree = self.snapshot(main_window)
        self.set_value(summary, self.node(tree, "fixture.input"), original)
        summary, tree = self.snapshot(main_window, screenshot=True)
        if self.node(tree, "fixture.input")["value"] != original: raise AssertionError("Original field was not restored")
        self.check("original input restored", original)
        return {"schema_version": 1, "status": "PASS", "checks": self.checks, "records": self.records,
                "pid": self.pid, "bundle_id": BUNDLE_ID, "profile_file": str(self.profile),
                "app_path": str(self.work / "GUI Operation Fixture.app"), "saved_file": str(saved),
                "saved_value": EXPECTED_NATIVE_VALUE, "saved_sha256": sha(saved), "original_value": original,
                "original_scroll_value": initial_scroll,
                "final_snapshot_file": summary["snapshot_file"], "final_screenshot_file": summary["screenshot_file"],
                "helper_sha256": sha(self.builder / "scripts" / "gui-macos"), "driver_sha256": sha(self.driver),
                "profile_tools_sha256": sha(self.builder / "scripts" / "profile_tools.py"),
                "fixture_source_sha256": sha(self.builder / "tests" / "fixtures" / "fixture.swift"),
                "fixture_binary_sha256": sha(self.work / "GUI Operation Fixture.app" / "Contents" / "MacOS" / "gui-fixture"),
                "live_test_source_sha256": sha(Path(__file__))}

    def restore_after_failure(self):
        if self.small_window is not None:
            info = self.call(["info"])
            if any(w["window_id"] == self.small_window and w["on_screen"] for w in info["windows"]):
                self.press("fixture.close-dialog", self.small_window)
        if self.original_scroll is not None:
            self.press("fixture.restore-view")
            _, tree = self.snapshot()
            value = float(next(n for n in tree["nodes"] if n["role"] == "AXScrollBar")["value"])
            if abs(value - self.original_scroll) >= 0.0001: raise AssertionError("Failure restoration did not restore view")
        if self.original is not None:
            summary, tree = self.snapshot()
            node = self.node(tree, "fixture.input")
            if node["value"] != self.original:
                if node["value"] not in self.owned_values:
                    raise AssertionError("Current text differs from this test's known writes; preserved the changed field instead of overwriting it")
                self.set_value(summary, node, self.original)
            _, tree = self.snapshot()
            if self.node(tree, "fixture.input")["value"] != self.original: raise AssertionError("Failure restoration did not restore input")
        return {"status": "PASS", "input_restored": self.original is not None, "view_restored": self.original_scroll is not None}


def verify_results(work_dir, suite_root):
    work = Path(work_dir).resolve()
    results = json.loads((work / "fixture-results.json").read_text(encoding="utf-8"))
    if results["status"] != "PASS" or not results["checks"] or any(c["status"] != "PASS" for c in results["checks"]): raise AssertionError("Stored live checks did not all pass")
    builder = builder_path(suite_root)
    if sha(builder / "scripts" / "gui-macos") != results["helper_sha256"]: raise AssertionError("Native helper differs from the tested bytes")
    if sha(builder / "scripts" / "gui_control.py") != results["driver_sha256"]: raise AssertionError("Driver differs from the tested bytes")
    if sha(builder / "scripts" / "profile_tools.py") != results["profile_tools_sha256"]: raise AssertionError("Record tools differ from the tested bytes")
    if sha(builder / "tests" / "fixtures" / "fixture.swift") != results["fixture_source_sha256"]: raise AssertionError("Fixture source differs from the tested bytes")
    if sha(Path(__file__)) != results["live_test_source_sha256"]: raise AssertionError("Live test source differs from the exercised version")
    if sha(Path(results["app_path"]) / "Contents" / "MacOS" / "gui-fixture") != results["fixture_binary_sha256"]: raise AssertionError("Fixture app differs from the tested bytes")
    saved = Path(results["saved_file"])
    if saved.read_text(encoding="utf-8") != results["saved_value"] or sha(saved) != results["saved_sha256"]: raise AssertionError("Persisted file differs")
    final = json.loads(Path(results["final_snapshot_file"]).read_text(encoding="utf-8"))
    if Exercise.node(final, "fixture.input")["value"] != results["original_value"]: raise AssertionError("Stored restoration state differs")
    running = True
    try: os.kill(results["pid"], 0)
    except ProcessLookupError: running = False
    if running:
        exercise = Exercise(work, suite_root, results["pid"])
        exercise.call(["info"])
        _, current = exercise.snapshot()
        if Exercise.node(current, "fixture.input")["value"] != results["original_value"]: raise AssertionError("Live fixture field is not restored")
        scroll = float(next(n for n in current["nodes"] if n["role"] == "AXScrollBar")["value"])
        if abs(scroll - results["original_scroll_value"]) >= 0.0001: raise AssertionError("Live fixture scroll position is not restored")
    return {"ok": True, "mode": "verify-only", "live_checks": len(results["checks"]), "fixture_pid": results["pid"],
            "fixture_running": running, "stored_file_verified": str(saved), "helper_sha256": results["helper_sha256"],
            "restoration_verified": "live and recorded" if running else "recorded; fixture no longer running"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", required=True); parser.add_argument("--suite-root", required=True)
    modes = parser.add_mutually_exclusive_group(); modes.add_argument("--build-only", action="store_true"); modes.add_argument("--verify-only", action="store_true")
    args = parser.parse_args(argv)
    if not Path(args.work_dir).is_absolute() or not Path(args.suite_root).is_absolute(): raise ValueError("Use absolute work and suite paths")
    if args.build_only: print(json.dumps(build_fixture(args.work_dir, args.suite_root), indent=2)); return 0
    if args.verify_only: print(json.dumps(verify_results(args.work_dir, args.suite_root), indent=2)); return 0
    work = Path(args.work_dir).resolve()
    build_path = work / "fixture-build.json"
    if not build_path.is_file(): raise ValueError("Run --build-only first so compilation is separate from live input")
    build = json.loads(build_path.read_text(encoding="utf-8"))
    if sha(build["binary"]) != build["fixture_binary_sha256"]: raise AssertionError("Fixture binary differs from its build record")
    if sha(builder_path(args.suite_root) / "tests" / "fixtures" / "fixture.swift") != build["fixture_source_sha256"]: raise AssertionError("Fixture source changed; build the current source first")
    session_path = work / "fixture-session.json"
    pid = None
    if session_path.is_file():
        session = json.loads(session_path.read_text(encoding="utf-8"))
        try: os.kill(session["pid"], 0); pid = session["pid"]
        except ProcessLookupError: pass
    if pid is None:
        run_checked(["/usr/bin/open", "-n", build["app_path"], "--args", "--scratch-file", str(work / "fixture-saved.txt")])
        driver = builder_path(args.suite_root) / "scripts" / "gui_control.py"
        end = time.monotonic() + 8
        while True:
            found = subprocess.run([sys.executable, str(driver), "--profile", str(work / "fixture-profile.json"), "info"], capture_output=True, text=True, timeout=15)
            data = json.loads(found.stdout)
            if found.returncode == 0 and type(data.get("pid")) is int:
                pid = data["pid"]; break
            if time.monotonic() >= end: raise AssertionError({"launch_identity": data})
            time.sleep(0.1)
        session_path.write_text(json.dumps({"pid": pid, "bundle_id": BUNDLE_ID, "app_path": build["app_path"]}, indent=2) + "\n", encoding="utf-8")
    exercise = Exercise(work, args.suite_root, pid)
    end = time.monotonic() + 8
    while True:
        try:
            exercise.call(["info"])
            break
        except AssertionError:
            if time.monotonic() >= end: raise
            time.sleep(0.1)
    try:
        results = exercise.live()
    except Exception as error:
        failure = {"schema_version": 1, "status": "FAIL", "pid": pid, "error": str(error), "checks": exercise.checks, "records": exercise.records}
        try: failure["restoration"] = exercise.restore_after_failure()
        except Exception as restoration_error: failure["restoration"] = {"status": "FAIL", "error": str(restoration_error)}
        (work / "fixture-failure.json").write_text(json.dumps(failure, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(failure, ensure_ascii=False, indent=2)); return 1
    (work / "fixture-results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "mode": "live", "passed": len(results["checks"]), "checks": results["checks"],
                      "pid": pid, "helper_sha256": results["helper_sha256"], "results_file": str(work / "fixture-results.json"),
                      "final_screenshot_file": results["final_screenshot_file"], "fixture_left_running": True}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try: sys.exit(main())
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False)); sys.exit(1)
