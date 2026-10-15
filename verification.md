# Verification record

This source repository omits the generated executable. The tests below describe the ready-to-run local delivery from the same control source. Build instructions are in `README.md`; `package-manifest.json` describes this source distribution.

The real window tests ran on **2026-10-13**, on Apple Silicon running macOS **27.2**, build **26B5101f**. Saved results and the unchanged tested program files were checked again on **2026-10-15**. This record distinguishes actual execution, compiled code, inspected source, and implementation guides.

## Passing package and program checks

- All eight skill folders passed the standard skill-format validator. Package links and catalog paths resolve.
- All **26** command and record unit checks passed, including a repeat on 2026-10-15. They cover explicit targets, duplicate and abbreviated options, app/version/path mismatch, keeping the inspected process, bounded records, shell punctuation remaining literal, protected text transport, unsupported platforms, unknown timeout results, and cleanup preserving unrelated changed text.
- Both JSON schemas passed Draft 2020-12 checks. The ZCode app profile and workflow passed their schemas and the package's semantic validator. Final delivery checks compare the installed folder, editable copy, manifest, and both archives for matching file sets, bytes, and permissions.
- Six native argument checks refused invalid requests before reading an app: missing target, malformed app identifier, malformed fingerprint, invalid process selector, relative installation path, and duplicate target flags.
- The final Swift source compiled for Apple Silicon and Intel. The combined executable contains `arm64` and `x86_64`. Actual execution was on Apple Silicon; Intel execution was not tested.
- The generalized helper read the installed ZCode at `/Applications/ZCode.app`, bundle `dev.zcode.app`, version `3.7.5`, build `3.7.5.4641`, on 2026-10-13. That check was read-only. Prior ZCode controls are background evidence, not a fresh full ZCode workflow with this package.
- Independent forward use produced Windows form/save and Mac save-recovery workflow designs. Their standalone records passed validation. An unbound Windows profile was rejected, as was a workflow paired with that incomplete profile. These refusals do not imply a working Windows adapter or a completed Windows save.

## Fourteen real window checks passed

A real local native test app exercised the final helper on **C32R50x**, the display the owner identified as the spare. Its main window was inside that display's observed bounds. A separate monitor does not isolate the shared keyboard or pointer; the operation guide explains this limit.

All **14 checks passed in one complete run**:

1. Capture the exact main window as a PNG and read its complete control tree.
2. Replace editable text with Unicode.
3. Refuse a stale value reference without changing the field.
4. Redact a secure value and refuse a write to that field.
5. Refuse a snapshot bound to a different app profile.
6. Focus the input through a pointer click and insert native Unicode text.
7. Select all through a native shortcut and replace the selection.
8. Select through a native drag and replace the selection.
9. Perform a button action and observe the actual changed status.
10. Save the exact UTF-8 text `GUI_NATIVE_Ω🙂` to the scratch file.
11. Move actual scroll content, then restore its exact original position through the app's observed Remember view and Restore view controls.
12. Capture and control an explicitly selected small sibling window.
13. Refuse main-window keyboard input while the sibling window has focus.
14. Restore and observe the original input value.

The scroll value moved from `0` to `0.07662835249042145` and was restored to `0`. The original input was empty and the final recorded input is empty. The saved file's SHA-256 is `c765e0dd4d23d433474ee2a56afb77aacbde563b1f93f0c710a87220d1eff4cf`.

On 2026-10-15, a separate read-only verification checked all fourteen saved passes, the saved file, the program fingerprints, and the recorded final restoration. The scratch app was no longer running. This later check verifies saved evidence and unchanged tested files; it is not a new live replay or a claim about current desktop state. Final main-window and small-window images were also inspected.

## Corrections supported by observed evidence

The fixture uses the normal Mac app launcher and a window placed inside the selected display. The helper refuses input points outside active displays. A capturable image alone does not establish pointer access.

The native tool uses Apple's system-wide topmost accessibility point test, requiring the exact app process and containing window. A broad system-host window rectangle does not establish that it owns the point. App identity, process generation, selected window, focus, profile binding, visibility, stale-state checks, and display bounds remain guarded.

The supplied capture route is the fixed Apple executable `/usr/sbin/screencapture` with an explicit selected window, no interactive mode, and no display or clipboard fallback. It verifies the child process exit, decoded PNG, window identity, bounds, and measured image scale. A ten-second limit stops only its own capture child. ScreenCaptureKit is described as an implementation option in the platform guide; it is not the included executable's capture route.

The runner selects the actual newly observed small window instead of assuming its outer height. Failure cleanup restores only values matching the test's known writes. It preserves unexpected independently changed text; two unit checks cover that behavior.

Accessibility messaging failure returns `ACTION_OUTCOME_UNKNOWN` for exposed actions, field writes, and window raising. Apple's installed header documents that such an error does not necessarily mean the action failed. A live messaging timeout was not induced.

## Limits

The supplied working adapter is for macOS 14 or newer. Windows, Linux, browser and app-service sections are official-source implementation guides. Their adapters must be built and tested for the chosen app. No other machine, remote desktop, protected desktop, Intel execution, account authentication, paid model task, purchase, external message, or production application workflow was exercised. Automatic discovery in every agent harness was not tested; the package explains how to register the eight sibling skills together.

A native test app does not prove another app's business flow. A matching archive proves its file set and bytes, not semantic quality or control of every application. Packaged file fingerprints are in `package-manifest.json`; detailed actions, earlier failures, and later checks are retained in the task evidence record. Scratch apps, screenshots, private data, and task-specific receipts are excluded from the portable package.

## Final tested program fingerprints

- `scripts/gui_control.py`: `c9745954b450ea6e0c53f1e0d4e8a87ef4bf202d7881d7267405e11f1357e8df`
- `scripts/profile_tools.py`: `82a5a73bc3db31ee72bc26bd8dd0c9b581228fe71028863da4f41b1cf953e278`
- `scripts/mac_gui.swift`: `27cc8d4ad913b5568572005dc2f0d18e711abc197bf9e513639b881f7e477704`
- `scripts/gui-macos`: `4dbcfcd756fa0e3265fad6d55bbf2c628e3668ddec02498fae968bce83b222f2`
- `tests/live_fixture.py`: `354167c14e2d45370cf9fcb99536ffc6134902259d818eb3ea1950a3e981bafb`
- `tests/fixtures/fixture.swift`: `7314ee6a98b3e975e4156ccd184f7af1dfade941b61cfd7100e4ceca72fda83d`
- `tests/test_contracts.py`: `f6d031d7f1beb920e8a5cc30334bdba9421744aa1ebcba4d91b0ba56c6f6ac0e`
