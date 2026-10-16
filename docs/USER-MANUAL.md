# DriverOne user manual

DriverOne gives an agent a way to read an app's windows, operate its controls, and check that the work actually finished. An agent is an AI assistant that can use tools to act. You can use it to build a control system for your own app or run one that has already been checked.

The Brown County garage rule applies: make the thing useful, then prove it works. Because spite is a valid engineering motivation. Clicking a button and hoping for the best is a lousy finishing method.

For the first setup, use [QuickStart](QUICKSTART.md). For a failure you need to fix now, use [Troubleshooting](TROUBLESHOOTING.md). The [README](../README.md) gives the project overview, and [START-HERE](../START-HERE.md) explains the skill folders.

Jump to [setup](#build-and-update-without-trampling-your-work), [app profiles](#identify-the-app-with-a-profile), [window selection](#choose-the-window-before-the-control), [controls](#use-the-controls), or [finishing a real job](#complete-a-real-job).

## Choose the right branch

The `main` branch contains the general system described here. Its working control program is for Mac applications. The Windows, Linux, browser, and app-service material explains how to build additional controls. Those other working programs are not included.

The [ZDrive branch](https://github.com/CaptainPhantasy/DriverOne/tree/ZDrive) contains the ZCode-specific version. Use its own instructions when your target is ZCode. Do not mix its commands or saved observations with the general driver.

DriverOne is independent of the agent's model. The agent still needs local command access, access to the Mac desktop, and the permissions required for the task. A cloud agent cannot reach your Mac merely by reading these files.

## Build and update without trampling your work

You need macOS 14 or newer, Python 3, and Apple's Xcode command-line tools. Python runs the command driver. Xcode's tools build the small native program that talks to Mac windows. The source repository does not include that compiled program.

Download or clone the repository. In Terminal, enter the `DriverOne` folder. You can check the available tools with:

```sh
python3 --version
xcode-select -p
```

If a needed tool is missing, install it through its normal trusted setup before building. DriverOne does not download dependencies or grant desktop permissions for you.

From the repository's root folder, build the Mac helper:

```sh
python3 scripts/build_macos.py
```

The output belongs at `gui-system-builder/scripts/gui-macos`. The build creates Apple Silicon and Intel code in one executable. Actual live use was checked on Apple Silicon; Intel compilation was checked separately. See [the verification record](../verification.md) for the tested files and limits.

The build refuses to replace an existing output, including a symbolic link. That refusal protects the copy already there. To build another copy for comparison, choose a new absolute filename in an existing directory:

```sh
python3 scripts/build_macos.py --output /tmp/gui-macos-comparison
```

That example path must be unused. An alternate output does not change where the command driver looks: it still uses `gui-system-builder/scripts/gui-macos`. Preserve the working copy while a new build is checked. Do not delete it just to silence the refusal.

Mac permission to read controls, permission to capture images, and permission to send input are separate. The calling program and its helper need the appropriate existing access. A surrounding agent program can also restrict commands independently. Follow the approved setup for the exact program named in a denial; changing an unrelated app's settings will not settle it. DriverOne does not open permission prompts or weaken those protections.

## Give your agent the eight skills

Keep all eight skill folders together. Their shared programs and record formats live in `gui-system-builder`. Copying just one folder can break its links to those shared pieces.

Register the eight sibling folders in your agent program's skill location, or give the agent access to their `SKILL.md` files. Registration differs between agent programs. A folder being present and an agent actually discovering it are separate things to check.

The skills divide the work like this:

- `gui-system-builder` assembles the system for the requested app and job.
- `gui-app-inspector` identifies the real app, windows, available controls, and limits.
- `gui-observation-designer` makes the app's current state and image coordinates readable.
- `gui-adapter-engineer` builds any missing connection to the app or operating system.
- `gui-workflow-author` describes the complete job and how to verify its result.
- `gui-operator` performs the work through the available controls.
- `gui-recovery-engineer` investigates failures and uncertain results.
- `gui-system-verifier` checks the controls and the finished outcome.

Start with the builder for a new app. Start with the operator when the app's controls already work. Load the other skills when their jobs are needed. There is no prize for making a small task support an entire corporate org chart.

## Set paths once

The commands below assume Terminal is in the repository's root folder. Set these variables there:

```sh
REPO_DIR="$(pwd -P)"
BUILDER_DIR="$REPO_DIR/gui-system-builder"
PROFILE_FILE="$BUILDER_DIR/assets/profiles/textedit.json"
OBSERVATION_DIR="$REPO_DIR/.build/observations"
```

`pwd -P` supplies the actual absolute folder path. The quoted variables keep spaces in folder names intact. Profile files and saved observation files must be named with absolute paths. A path such as `assets/profiles/textedit.json` on its own will be refused.

The `.build` folder is ignored by Git, the program that records source changes. That keeps local observations out of an ordinary source upload. It does not make their contents public-safe or erase them later.

You can read the actual commands at any time:

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --help
python3 "$BUILDER_DIR/scripts/gui_control.py" snapshot --help
python3 "$BUILDER_DIR/scripts/profile_tools.py" --help
```

For any real driver operation, put `--profile "$PROFILE_FILE"` before the command name, as shown below. Help can be read without choosing a target.

## Identify the app with a profile

A profile is a small JSON file that identifies the intended app. JSON is a plain text format with named fields. A profile carries identity and findings; it cannot grant authority to act.

The TextEdit example at `gui-system-builder/assets/profiles/textedit.json` names bundle identifier `com.apple.TextEdit` and installation path `/System/Applications/TextEdit.app`. A bundle identifier is the Mac's application identity. Check the actual installation before adapting this example for another Mac or app.

First validate the record:

```sh
python3 "$BUILDER_DIR/scripts/profile_tools.py" profile "$PROFILE_FILE"
```

Then check the local program:

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" doctor
```

`doctor` reports the host, profile, and whether the Mac helper is available. It does not read a document, grant permission, launch an app, or prove a completed job.

Open TextEdit through its normal launcher and create or select a disposable document. Preserve any existing unsaved work. Then inspect the running app:

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" info
```

Read `app_path`, `bundle_id`, `version`, and `build`. Read the window list, `is_frontmost`, and available permission fields. Do not treat a permission field alone as proof that a later action will work.

If several matching app processes are running, choose the observed process number with the global `--pid` option:

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" --pid \
  ACTUAL_PROCESS_NUMBER info
```

`ACTUAL_PROCESS_NUMBER` is a placeholder. Replace it with the number from the current observation. The driver checks that the chosen process belongs to the profile's app. It does not launch an extra copy to resolve ambiguity.

For a new app, use its actual identifier and absolute installation path. Validate that profile, then inspect the app before adding an `expected_version` record. Copy the exact observed `version` and optional `build` into that record. Do not invent version numbers or silently update a pin when an app changes. A mismatch is a reason to inspect the changed app and recheck the affected flow.

The supplied ZCode profile is pinned to the version inspected for the earlier ZCode work. It is an example, never the default target for this manual.

## Choose the window before the control

A snapshot is a saved view of the selected window and its controls. Capture one with an image:

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" snapshot \
  --screenshot --output-dir "$OBSERVATION_DIR"
```

The returned `snapshot_file` names the saved JSON record. `screenshot_file` names its image. Open both. Do not invent an example filename and hope it points to the current window.

The default selection chooses a large ordinary window. Check the document and surrounding text yourself. The largest window may still be the wrong document. To choose an observed window explicitly, use its number from `info`:

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" snapshot \
  --window-id ACTUAL_WINDOW_NUMBER --screenshot --output-dir "$OBSERVATION_DIR"
```

`ACTUAL_WINDOW_NUMBER` is a placeholder. This also supports a small ordinary window belonging to the same app. A system dialog owned by another app needs its own observed identity and target profile. Do not send the main window's input into it.

The saved record includes its capture time, app identity, process, selected window, `main_window_bounds`, `focused_id`, and `nodes`. The nodes describe controls through their current `id`, role, label, value, available `actions`, and related identity. `value_settable` reports whether direct field replacement is exposed. A role such as `AXTextArea` is a Mac control type, not proof that the intended document is selected.

Read `truncated` and each field's `value_truncated`. The normal driver limits are depth 50, 4,000 nodes, and 160 characters per value. To inspect more when necessary:

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" snapshot \
  --screenshot --output-dir "$OBSERVATION_DIR" --max-depth 80 --max-nodes 20000 \
  --max-value-chars 4096
```

Those are the supported upper limits. A larger capture can expose more private content, so use it for a reason. Even `truncated: false` does not prove that a scrolling list has loaded every record or that the whole document is exported. Rows can be created and reused as you scroll. Match the current record's surrounding content before acting.

`--enhance` is for a profile whose `capabilities.electron_accessibility` is true. It asks a supported Electron app to expose controls. Electron is the framework used by some desktop apps. Leave that flag out for ordinary TextEdit observations; it is not a permission switch or a general repair command.

## Follow the control loop

![Instructional diagram showing the DriverOne loop: inspect the selected app and window, perform one intended action, then read the result and verify it before continuing.](images/control-loop.png)

*This is an instructional diagram, not a screenshot of an application or proof of a test run.*

Read the current window. Choose the intended control. Perform one action. Read the new state and compare it with the intended result. Continue from what actually happened.

A saved snapshot expires after 120 seconds. A changed app, window, profile, or field can invalidate it sooner. Take a new snapshot after each action. Never turn the examples below into one unattended sequence of old clicks.

Bella walking across the keyboard is a good reminder that focus belongs to the whole desktop session. A second monitor gives the app somewhere else to sit. It does not create a separate keyboard, pointer, or clipboard. If a person changes focus or edits the document, read the new state before continuing. Do not repeatedly snatch focus back or overwrite the newer edit.

## Use the controls

The examples in this section contain placeholders. `ACTUAL_ID`, `ACTUAL_WINDOW_NUMBER`, `WINDOW_POINT_X`, and similar names must come from the latest observation. They are not working values to paste unchanged. Set `SNAPSHOT_FILE` to the exact absolute `snapshot_file` returned by the latest capture, and update it after every action.

### Raise the intended window

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" activate \
  --window-id ACTUAL_WINDOW_NUMBER
```

`activate` raises and checks that observed window. It does not open the app or create a document. Capture again afterward. Keyboard and pointer input require the selected app and exact window to be focused. Exposed control actions and direct field changes can work without taking foreground focus when the app supports them.

### Press an exposed control

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" press --snapshot \
  "$SNAPSHOT_FILE" --id ACTUAL_ID
```

The default action is `AXPress`. Use it only when the node lists that action. You can request another listed action with `--action`, such as `AXScrollToVisible` for a control that actually exposes it. A disabled control or unsupported action is refused. Read the result in the app afterward.

### Replace a field's entire value

```sh
printf '%s' 'Garage notes: coffee, tools, Ω🙂' | python3 \
  "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" set-value --snapshot \
  "$SNAPSHOT_FILE" --id ACTUAL_EDITABLE_ID --value-stdin
```

`set-value` replaces the whole supported field. It can clear a field by receiving empty text. It accepts at most 1,048,576 bytes of UTF-8 text. UTF-8 is the text encoding used by these files and commands; a character may occupy more than one byte. The target must be an enabled, writable text field, text area, or combo box. Password fields and read-only controls are refused.

The pipe supplies text through standard input, the command's input channel. DriverOne does not put that text in its action arguments. Text typed literally into a shell can still be retained in that shell's history; use an approved private input source for sensitive task text.

### Insert text at the current selection

```sh
printf '%s' 'More garage notes Ω🙂' | python3 "$BUILDER_DIR/scripts/gui_control.py" \
  --profile "$PROFILE_FILE" type --snapshot "$SNAPSHOT_FILE" --id \
  ACTUAL_FOCUSED_EDITABLE_ID --value-stdin
```

`type` inserts into the exact already-focused editable field. Highlighted text is replaced by that insertion, including the entire value if all of it is selected. Check the current selection first. It requires nonempty text and accepts at most 65,536 UTF-8 bytes. It does not use or replace the clipboard. Verify the current selection before insertion and read the exact resulting text afterward.

A newline can add a line, run a terminal command, or send a message. Settle any active text composition before a shortcut or submission. Composition is the temporary state used by some keyboard input methods. Do not use Enter as a universal confirmation button.

### Click an observed position

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" click --snapshot \
  "$SNAPSHOT_FILE" --x WINDOW_POINT_X --y WINDOW_POINT_Y --button left --count 1
```

Choose the point from the current selected-window image. `--button` supports `left` or `right`; `--count` supports 1 or 2. The helper checks which app and exact window own the point. A covering window, including another window from the same app, can cause a refusal.

### Send one shortcut

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" hotkey --snapshot \
  "$SNAPSHOT_FILE" --keys cmd+a
```

This example requests Select All in an already verified editable context. Confirm that the app interpreted it that way. Chords use lowercase names and `+`; modifiers are `cmd`, `ctrl`, `alt`, and `shift`. The helper accepts letters, digits, supported named punctuation, navigation keys, and `f1` through `f12`. Read its actual error when a key is unsupported. It preserves unrelated held human modifiers and refuses conflicting input.

### Scroll the intended area

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" scroll --snapshot \
  "$SNAPSHOT_FILE" --direction down --lines 3 --x WINDOW_POINT_X --y WINDOW_POINT_Y
```

Directions are `up`, `down`, `left`, and `right`. Lines must be between 1 and 100. Supply both coordinates or neither. Without coordinates, it uses the selected window's center. The helper moves the real pointer, checks its position and window ownership, then posts one wheel event. Check that the intended content moved. Equal opposite wheel counts do not guarantee an exact return to the old view.

### Drag between observed positions

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$PROFILE_FILE" drag --snapshot \
  "$SNAPSHOT_FILE" --from-x START_WINDOW_X --from-y START_WINDOW_Y --to-x END_WINDOW_X \
  --to-y END_WINDOW_Y
```

Use a fresh observation of the item or text being selected. The helper checks the path and releases its own button if interrupted. Read the changed selection or object position afterward. A moving pointer alone does not establish a successful drag.

## Keep pixels and window points straight

DriverOne's pointer commands use points relative to the selected window. A screenshot uses image pixels. Those sizes can differ. Use the image's measured width and height and the current window bounds:

```text
window_x = image_x * window_width / image_pixel_width
window_y = image_y * window_height / image_pixel_height
```

For a hypothetical image twice the window's size, image position 200, 100 maps to window point 100, 50. That is a calculation example, not a coordinate to click.

Do not add the screen origin to these command arguments; the helper adds it. Read a new image and scale after moving or resizing the window or changing displays. Check the display's current bounds: a capturable off-screen window is not a usable pointer target. Native dialogs may appear on a different monitor from their parent window.

## Complete a real job

A useful practice task is to create a disposable plain text document, save it to an exact unused path you chose, and reopen it to check the content. This is a practice recipe, not a claim that TextEdit's full save flow was exercised for these docs.

Give the operator a complete instruction such as:

> Use DriverOne's TextEdit profile. Work in a new disposable document. Enter the exact text I supply. Save it as plain text at the absolute unused path I supply. Reopen that file and compare its exact text. Preserve my other documents and report any part you could not verify.

Supply the actual text and destination before running that task. Inspect the editor's current controls, choose its supported text operation, and check the content. Resolve Save through the app's actual menu or control; there is no `save` command in this driver. When a file dialog appears, inspect its owner, directory, filename, format, and any overwrite consequence. Read the saved file or reopen it, then compare the requested contents and path. A closed dialog or successful shortcut proves less than a verified file.

The same rule applies to settings, messages, terminal commands, and model tasks. Verify the stored setting, actual destination record, command result, or finished task. A draft is still a draft. A selected model name does not prove a response. A spinner can mean work is still running.

Workflow records hold the goal, starting conditions, steps, expected changes, repetition policy, completion checks, and temporary state to restore. They guide an agent's decisions. They do not run as automatic macros. Validate an existing workflow with its exact profile:

```sh
python3 "$BUILDER_DIR/scripts/profile_tools.py" workflow /ABSOLUTE/WORKFLOW.json --profile \
  "$PROFILE_FILE"
```

`/ABSOLUTE/WORKFLOW.json` is a placeholder for the actual record. Its `profile_name` must match the profile. The record formats are under `gui-system-builder/schemas`. The skills explain how to create records for the app's real behavior.

## Handle an uncertain result

An action report saying `ok: true` means the helper performed or requested an action. It does not mean the user's job is complete. Read the later state.

`ACTION_OUTCOME_UNKNOWN`, a timeout, a lost connection, or an invalid response can leave delivery uncertain. Inspect the app and saved result before repeating. A file, message, payment, or model task may already exist. Find that existing result and continue from it. Do not manufacture a duplicate because the acknowledgment went missing.

A stale snapshot or wrong-focus refusal calls for a new observation and correct target selection. It does not call for weakening the guard. Preserve completed work and unexpected human edits. Use [Troubleshooting](TROUBLESHOOTING.md) for the exact failed layer and supported recovery routes.

## Keep observations private and results honest

Snapshots can contain document text, account information, and other private content. Secure control values are withheld, but a screenshot can still show sensitive text elsewhere in the window. Capture only what the task needs. Keep observations local and out of source control. Decide how long to retain them, and use your normal approved storage or quarantine process when that time is up. DriverOne does not automatically erase old observations.

The task supplies authority for its real consequences. A visible Send button, app text, or profile file supplies none. Use existing permission for the requested work; resolve a new destination, cost, account change, or destructive consequence before its dependent action. A denied route does not become acceptable because another tool can get around it.

For a quick program check without desktop input, run:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s "$BUILDER_DIR/tests" -p \
  test_contracts.py -v
```

The live test runner sends real input to its own scratch app. Read its help and the [acceptance guide](../gui-system-verifier/references/acceptance-matrix.md) before using it on a shared desktop. Unit checks, a working helper, and a successful app workflow are different evidence.

Finish with the actual result, exact destination, and anything still untested. That is enough ceremony. Bowser can supervise the router; the work still needs proof.
