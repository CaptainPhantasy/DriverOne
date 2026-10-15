---
name: zcode-gui-control
description: Drive the installed ZCode desktop app from any local agent with shell access using verified macOS controls, current screenshots, and guarded element actions. Inspect ZCode control interfaces and operate its workspaces, tasks, settings, files, terminal, and browser through the real GUI.
---
# ZCode GUI control

Use this package when an agent needs to operate **the existing ZCode desktop window**, rather than run a separate coding agent. It is independent of Codex, Claude, GLM, or another model's tool names. It needs a local shell, Python 3, and the macOS desktop where ZCode runs. It is not a remote web service or a grant of desktop permission.

A snapshot is a saved view of the window and its controls. Accessibility is the macOS feature used to read those controls and act on them. The command-line driver returns JSON, a plain structured text format that agents can read. This source checkout requires a local build: run `python3 -B scripts/build_native.py` from this folder before using native commands. No executable is committed to the repository.

The installed app inspected on 2026-10-13 is ZCode **3.7.5**, build **3.7.5.4641**, bundle `dev.zcode.app`. Check the current version first. An update can change controls and private interfaces.

## Start from the actual window

Set `SKILL_DIR` to this package's absolute folder. The default installation is `~/.zcode/skills/zcode-gui-control`.

```sh
python3 "$SKILL_DIR/scripts/zcode_control.py" doctor
python3 "$SKILL_DIR/scripts/zcode_control.py" info
python3 "$SKILL_DIR/scripts/zcode_control.py" snapshot --enhance --screenshot --output-dir /tmp/zcode-gui-control
```

Read the saved snapshot JSON and its screenshot. The helper selects ZCode's largest ordinary window and excludes tiny overlays. `--enhance` asks the app to expose its text and controls; it does not grant system permissions. Snapshot values are shortened. Use `snapshot --window-id ACTUAL-WINDOW-ID` for an observed ZCode-owned native dialog instead of the default main window. Secure fields are not readable. Limit captures to the task, keep them local, and do not upload private screen data.

For native actions, use an element's **current** `id` and the exact `snapshot_file` from the most recent observation:

```sh
python3 "$SKILL_DIR/scripts/zcode_control.py" press --snapshot /tmp/zcode-gui-control/ACTUAL-SNAPSHOT.json --id ACTUAL-ID
printf '%s' 'requested text' | python3 "$SKILL_DIR/scripts/zcode_control.py" set-value --snapshot /tmp/zcode-gui-control/ACTUAL-SNAPSHOT.json --id ACTUAL-EDITABLE-ID --value-stdin
```

Those example filenames and IDs are placeholders, never values to copy blindly. The native helper checks snapshot age (at most 120 seconds), process, window, and element identity before acting. This reduces stale-target mistakes; it cannot prove the business meaning of two visually identical controls. If an identity check fails, observe again and select the correct target. Never repeatedly click stale IDs.

After **one action**, take a new snapshot and verify the actual result. A successful command exit proves the request was performed, not that the requested workflow finished. Never batch a plan of unknown clicks.

## Routes and workflows

Read [references/gui-workflows.md](references/gui-workflows.md) for workspace and task operations, draft/send controls, model and mode choices, settings, commands, skills, files, terminal, browser, confirmations, menus, and recovery. Use the same observe–act–observe loop for all GUI areas. Do not assume a control has a stable ID, location, or English label after an update.

Read [references/interfaces.json](references/interfaces.json) for the inspected **33 service channels, 113 renderer functions, and 57 private coding-runtime methods**, and the remote-server routes. These are source findings, not public local GUI endpoints. They are documented so an agent does not mistake them for a working external API.

- `zcode://workspace/open?path=...` is a real workspace deep link with a native confirmation. The driver can construct or send it for an exact authorized local directory. Observe the confirmation and the final workspace. It does not send a prompt.
- Observed local HTTP listeners belonged to the updater and a sign-in callback. Neither drives the GUI. Their ports can change at each launch.
- `window.zcode`, Electron MessagePorts, and `app-server --stdio` are private internal routes. Starting another runtime does not establish attachment to this desktop session.
- `/api/server-info`, `/api/rpc-host-capability`, `/ws`, and `/ws/host` belong to a separately configured remote server. No such connection was opened or authenticated in this inspection.
- The packaged app does not enable the development debugging port by default. Do not restart it or enable debugging to make this skill work.

## Native keyboard and pointer controls

The package also provides `type`, `click`, `hotkey`, `scroll`, and `drag` through its own native helper. Each needs a fresh `--snapshot`; ZCode must already be foreground. The helper rejects the action if another app is foreground, the selected window is not focused, or the window changed. Pointer input also rejects a position covered by another window, including another ZCode window. Native `type --id ... --value-stdin` inserts text into the already-focused observed field without using the clipboard; it does not replace existing text. It accepts at most 65,536 UTF-8 bytes. Coordinates are **points relative to the selected window**, not screenshot pixels. Read the detailed commands and scale conversion in the workflow reference. One action still requires a later observation.

## Optional Steer observations

If Steer is already installed, the driver offers its read-only observations: `see`, `ocr`, `focus`, `find`, `screens`, `wait`, `help`, and `window list ZCode`. It uses the supplied native helper for actions. Read exact flags with:

```sh
python3 "$SKILL_DIR/scripts/zcode_control.py" steer help see
```

Steer's app screenshot can select a tiny overlay; its screen OCR can read the foreground app. Use the native selected-window capture and its actual controls to establish the target. Keep any desktop observations local and within the user's task.

## Permission and completion boundaries

Follow the current user's authority for edits, submitted prompts, paid model use, file writes, external messages, account changes, and production work. Seeing a Send button does not authorize its use. Never bypass a denial, read app credentials to discover a control token, approve a destructive dialog automatically, or weaken ZCode's execution mode to avoid approval.

Existing macOS Accessibility permission is needed for controls, and Screen Recording permission is needed for screenshots. If absent, report the exact missing permission; the helper never requests or grants it. A sandbox can also block process or desktop access even when macOS permissions exist; use that harness's authorized permission flow rather than classifying the whole workstation as unavailable.

Read [references/verification.md](references/verification.md) for exactly what was inspected and exercised. The package provides general GUI primitives and recipes; it does not claim that every paid, remote, or destructive workflow was tested. Complete the user-requested flow and report the evidence and any remaining boundary.
