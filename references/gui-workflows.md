# Drive the whole ZCode interface

This is a control guide for the real desktop app. No private cloud token, injected JavaScript, Codex-specific tool, or separate model runtime is required. The native helper source is for macOS; build it locally first. Then the Python front end speaks ordinary command-line arguments and JSON.

## How to choose a control

1. Read `info` and `doctor`. Verify the application identity and current version.
2. Save `snapshot --enhance --screenshot`. Read its JSON and screenshot.
3. Find the target by its role, label, identifier, and location. Use its current ID. If several controls share a label, distinguish the surrounding section and bounds.
4. Use `press` only for an action listed on that element. The default action is `AXPress`; menus can expose other supported actions. Use `set-value` only for an editable field. Never set a password with this generic method.
5. Save a fresh snapshot and verify the intended result. Use a new snapshot for the next action.

For a standalone native dialog, read the app-owned window IDs in `info` and use `snapshot --window-id ACTUAL-WINDOW-ID`. Inspect that selected window before confirming. It must belong to ZCode; IDs from other apps are rejected. Main-window and selected-dialog snapshots both use `main/...` element paths for the chosen root. The helper checks identity before a native action. Snapshots expire after 120 seconds. Changed target state, another window, or a restarted process invalidates an old snapshot. The identity guard is not a guarantee of business identity: two identical controls may refer to different records. Check the surrounding text before a consequential action. Screenshots and shortened values are observations, not guaranteed complete exports of chat history. Expand or scroll through the real interface when needed.

## Workspaces and tasks

- The current home screen exposes `Choose workspace`, `Add project`, `New task`, task grouping, search, archived items, and navigation controls.
- To open a directory already authorized by the user, `workspace-url /absolute/directory` prints the URL without changing anything. `open-workspace /absolute/directory` sends the deep link through macOS. Inspect the native confirmation and confirm only the exact authorized folder. Verify the selected project and workspace name afterward.
- Use the visible task list to select an existing task. Check its title and workspace before continuing it. An empty task list does not imply missing stored tasks in another workspace or an archived view.
- A draft or `New task` does not mean a model was invoked. Select the correct workspace first and inspect the input and model controls.
- Creating, archiving, forking, stopping, or deleting a task changes stored state. Act only when the user's current request covers that consequence. Preserve task history unless removal is explicitly authorized.

## Drafts, models, and modes

- The inspected home input's placeholder is `Ask ZCode anything, @ to add context, / for commands or capabilities`.
- Set the editable input with `set-value`, then observe that the draft is correct. For a rich text editor that rejects direct setting, focus the observed field, take a fresh snapshot, and use native `type --snapshot ... --id ... --value-stdin`. It inserts at the current selection without replacing content or using the clipboard. It rejects a different focused field or app, secure or read-only fields, and input over 65,536 UTF-8 bytes. The supplied native pointer and keyboard methods are the input route. Do not paste into an uncertain field.
- The current view includes `Add context`, `Switch mode`, `Choose model`, a thought-effort selector, and `Send`. Read selected values rather than assuming defaults.
- Use a pop-up's supported action, then inspect the options before selecting one. A model name in the UI does not prove a live model response.
- Submit only when the user has authorized the actual model task and any paid use. Native `press` on the fresh Send element can submit; this package does not automatically submit a draft.
- Once submitted, observe status, tool progress, final text, and any permission request. A spinner is ongoing work; an arbitrary elapsed time is not failure. Do not retry a submission if its acknowledgment was uncertain; inspect the task first.
- Do not switch to less restrictive execution permissions to bypass a denied or pending action. Approval dialogs are decisions, not obstacles to click away.

## Settings and extensions

The inspected settings sidebar contains General, Appearance, Model settings, Browser, Memory, Plugins, Skills, Subagents, MCP Servers, Commands, Hooks, Indexing, Usage stats, and Onboard. Navigate by the current labels, not fixed positions.

- Open `Settings`, inspect the page, select its section, and re-observe before changing a field or switch.
- Commands use Markdown under `~/.zcode/commands`. Skills use folders under `~/.zcode/skills`. Refresh the relevant list after authorized file changes; verify the exact new name. Presence in the folder and discovery in the app are separate facts.
- Search fields are useful safe control tests. Save the original value and restore it after the test. Do not click Delete, uninstall, or a permission switch just to prove automation.
- Model and server pages can contain credentials. Treat screenshots as private; do not export or reveal secrets. Do not copy credentials into another harness or service without specific user authority.
- Enabling remote access, changing security permissions, and connecting new services can widen access or spend money. Obtain the authority required by that consequence.

## Files, terminal, review, and browser

These panels depend on the chosen workspace. First verify the workspace path, then inspect visible toolbar and tab controls.

- Files: use the tree or authorized open-file dialog, choose the exact file, and verify the editor title and content. Saving a file is separate from running or deploying it.
- Terminal: the inspected toolbar has `Toggle terminal`. Open it and verify the terminal belongs to the selected workspace and machine. A typed command has not run until it is submitted; running commands needs task authority.
- Review: select the correct changes or branch view and check both file and side of the comparison. Do not mark a review resolved as a substitute for applying and testing a requested fix.
- Browser: use the app's current browser controls. Verify the URL, loaded page, and content. Native GUI primitives can operate these controls, while ZCode's own Browser Use plugin is a separate facility for the agent inside ZCode. Permission or sign-in prompts need the usual authority.
- Menus and dialogs: read the native snapshot and supported actions. If a system dialog appears, inspect the path, account, destination, and consequences before confirming. Do not accept password changes or payments on behalf of the user through generic automation.

## Native keyboard and pointer controls

No separate Steer installation is needed for these primitives, including native text insertion. Use `set-value` when replacing an entire supported field; `type` inserts text at the current selection and needs the exact observed field already focused. First use `activate`, verify `info`, and capture a current main-window snapshot. The helper requires ZCode and the selected window to remain focused at action time. `activate --window-id ACTUAL-ID` raises an explicitly observed window. Pointer positions must belong to that exact selected window, so a covering dialog or second ZCode window is refused. The native check ignores only fully transparent windows and the confirmed macOS cursor image; unknown covering surfaces are refused. Observe and select the dialog itself. Never guess coordinates or key names.

```sh
python3 "$SKILL_DIR/scripts/zcode_control.py" click --snapshot ACTUAL-ABSOLUTE-JSON --x ACTUAL-X --y ACTUAL-Y
python3 "$SKILL_DIR/scripts/zcode_control.py" hotkey --snapshot ACTUAL-ABSOLUTE-JSON --keys escape
python3 "$SKILL_DIR/scripts/zcode_control.py" scroll --snapshot ACTUAL-ABSOLUTE-JSON --direction down --lines 3
python3 "$SKILL_DIR/scripts/zcode_control.py" drag --snapshot ACTUAL-ABSOLUTE-JSON --from-x X1 --from-y Y1 --to-x X2 --to-y Y2
```

All sample coordinates and snapshot names above are placeholders. `click` supports left/right buttons and one/double clicks. `hotkey` accepts one supported chord, not a script. The native helper validates keys, finite coordinates within the selected main window, current app/window state, and the snapshot age before sending input. A shortcut releases its own synthetic modifiers; a conflicting physically held modifier is refused before input. These commands perform one action; observe afterward.

Scroll moves the real pointer once to the observed target, checks its position and the selected window again, then posts one wheel event. The requested lines describe the wheel event, not a guaranteed pixel distance. Wait for the view to settle and verify the resulting content. If an observed heading or item exposes `AXScrollToVisible`, `press --action AXScrollToVisible` can bring it into view; this route was exercised on the Commands heading. Do not assume equal opposite wheel counts restore the same position.

Native screenshot images can be twice the window's point size. For a point picked from the image, use `x = image_x * main_window_width / image_pixel_width` and the equivalent expression for y. Do not add the screen origin: the helper applies it. Distinguish this from Steer's screen coordinates.

## Optional Steer observations

The driver exposes read-only Steer observations when that local tool is installed. Read exact flags with `steer help OPERATION`. Use `see`, `ocr`, `focus`, `find`, `screens`, `wait`, or `window list ZCode` to inspect state. Check the reported application and screen before relying on the result. Its first-window capture may select ZCode's sharing overlay. The native helper's selected-window screenshot is the basis for this package's actions.

Steer input and window changes are not exposed by this wrapper. The native commands check the snapshot and selected target directly. Do not use native helper IDs as Steer IDs; they are different formats.

## Build and portability

This source distribution includes `scripts/mac_gui.swift` and `scripts/build_native.py`. Build the local helper on macOS 14 or newer with Python 3 and Apple's Xcode command-line tools already installed:

```sh
python3 -B scripts/build_native.py
```

The command compiles for the current Mac and writes the ignored local executable `scripts/zcode-macos`. Use `python3 -B scripts/build_native.py --universal` for both Apple Silicon and Intel slices. Compilation of both has been checked; only Apple Silicon has been exercised live. No compiled helper is committed to this repository. The build command does not download or install dependencies.

`ZCODE_GUI_NATIVE` can point to an already-built helper for a local comparison. `ZCODE_GUI_STEER` can name an already-approved Steer executable; `ZCODE_GUI_APP` changes only the plist path used by `doctor`, not the native target bundle. These are process configuration choices, not values read from a website or app document. The native target remains `dev.zcode.app`.

## Recover from a failed action

- Missing main window: check whether ZCode is running or minimized. Launch/restore only when authorized, then take a new snapshot.
- Stale identity: take a new snapshot; resolve the new target from observed content. Do not bypass the guard.
- A truncated tree: increase `--max-depth` or `--max-nodes` within the driver's limits, or inspect a narrower visible part of the interface.
- Missing permission: report the exact Accessibility, Screen Recording, or harness sandbox boundary. Do not label it a missing app API or silently grant access.
- Screenshot shows a tiny overlay: use the native main-window capture rather than Steer's first-window capture.
- Foreground or focused window changed: no keyboard/pointer action is sent. Activate the intended observed window, verify, and observe again.
- A covering window: select and inspect that exact ZCode dialog/window, or raise the original window. Do not bypass the pointer ownership guard.
- Timeout or lost acknowledgment: inspect current state before retrying. The action might already have happened.
- Version changed: repeat inspection of relevant controls and routes. Internal method names and source offsets are tied to the inspected build.
