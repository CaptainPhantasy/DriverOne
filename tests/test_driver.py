#!/usr/bin/env python3
"""Behavior checks for the shell driver. No GUI changes or network requests."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

script=Path(__file__).resolve().parents[1]/'scripts/zcode_control.py'
spec=importlib.util.spec_from_file_location('zcode_control',script)
driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)

class DriverTests(unittest.TestCase):
    def test_workspace_url_round_trip_spaces_and_unicode(self):
        with tempfile.TemporaryDirectory(prefix='ZCode space Ω ') as raw:
            url=driver.workspace_url(raw)
            parsed=driver.urllib.parse.urlparse(url)
            self.assertEqual((parsed.scheme,parsed.netloc,parsed.path),('zcode','workspace','/open'))
            self.assertEqual(driver.urllib.parse.parse_qs(parsed.query)['path'],[str(Path(raw).resolve())])
    def test_missing_or_relative_workspace_rejected(self):
        for raw in ('relative-directory','/this-path-does-not-exist-zcode-test'):
            with self.assertRaises(driver.ControlError):driver.workspace_url(raw)
    def test_pointer_rejected_without_target_snapshot(self):
        with self.assertRaises(driver.ControlError):driver.safe_steer_args('click',['--x','1','--y','2'])
    def test_coordinate_click_needs_screen(self):
        with self.assertRaises(driver.ControlError):driver.safe_steer_args('click',['--snapshot','abc','--x','1','--y','2'])
    def test_native_identity_guard_instead_of_overlay_window_mutation(self):
        with self.assertRaises(driver.ControlError):driver.safe_steer_args('window',['close','ZCode'])
    def test_wrong_app_rejected(self):
        with self.assertRaises(driver.ControlError):driver.safe_steer_args('see',['--app','OtherApp'])
        with self.assertRaises(driver.ControlError):driver.ensure_frontmost({'frontmost_bundle_id':'com.apple.finder'})
    def test_equal_and_duplicate_app_selectors_rejected(self):
        for args in (['--app=OtherApp'],['--app','ZCode','--app','OtherApp'],['--app=ZCode','--app=OtherApp']):
            with self.assertRaises(driver.ControlError):driver.safe_steer_args('see',args)
    def test_window_selection_and_typing_arguments(self):
        args=driver.parser().parse_args(['snapshot','--window-id','1043'])
        self.assertEqual(args.window_id,1043)
        args=driver.parser().parse_args(['type','--snapshot','/tmp/observed.json','--id','main/1','--value-stdin'])
        self.assertEqual(args.command,'type')
    def test_current_target_allowed(self):
        driver.ensure_frontmost({'frontmost_bundle_id':'dev.zcode.app'})
        self.assertEqual(driver.safe_steer_args('see',['--app','ZCode']),['--app','ZCode','--json'])
    def test_text_is_argv_not_shell(self):
        text='literal $(touch SHOULD_NOT_EXIST); `echo hello`'
        result=driver.execute(['/usr/bin/python3','-c','import json,sys;print(json.dumps(sys.argv[1:]))',text])
        self.assertEqual(result,[text])
    def test_uncertain_timeout_is_not_success(self):
        with patch.object(driver.subprocess,'run',side_effect=driver.subprocess.TimeoutExpired(['helper'],1)):
            with self.assertRaisesRegex(driver.ControlError,'uncertain'):driver.execute(['helper'])
    def test_external_steer_mutations_are_not_a_guard_bypass(self):
        for command,args in (('click',['--snapshot','arbitrary','--x=1','--y=2']),('type',['text','--into','B1','--snapshot','arbitrary']),('hotkey',['cmd+a']),('scroll',['down']),('drag',['--from','B1'])):
            with self.assertRaises(driver.ControlError):driver.safe_steer_args(command,args)
    def test_workspace_timeout_has_uncertain_result(self):
        with tempfile.TemporaryDirectory() as raw, patch.object(driver.platform,'system',return_value='Darwin'), patch.object(driver.subprocess,'run',side_effect=driver.subprocess.TimeoutExpired(['open'],15)):
            with self.assertRaisesRegex(driver.ControlError,'uncertain'):driver.main(['open-workspace',raw])
    def test_optional_steer_tilde_path(self):
        with tempfile.TemporaryDirectory() as raw:
            helper=Path(raw)/'steer';helper.write_text('');helper.chmod(0o700)
            with patch.dict(driver.os.environ,{'ZCODE_GUI_STEER':'~/steer'}),patch.object(driver.Path,'home',return_value=Path(raw)),patch.object(driver.Path,'expanduser',lambda p: Path(str(p).replace('~',raw,1))):
                self.assertEqual(driver.steer_binary(),str(helper))
    def test_native_missing_fails_instead_of_fake_control(self):
        with patch.dict(driver.os.environ,{'ZCODE_GUI_NATIVE':'/missing-helper-zcode-test'}):
            with self.assertRaises(driver.ControlError):driver.native_binary()

if __name__=='__main__':unittest.main()
