# DriverOne

Eight skills for building and operating a system that drives a graphical application. They work with any agent that can read files and run local commands. Start with [the skill guide](START-HERE.md).

`main` contains the general GUI version. [ZDrive](https://github.com/CaptainPhantasy/DriverOne/tree/ZDrive) contains the ZCode-specific driver.

## What works

The included Mac controls can inspect an app, capture a selected window, read exposed controls, select and raise windows, click, type Unicode, use shortcuts, drag, scroll, and perform exposed app actions. They check the current app, process, window, focus, and observed target before input.

The skills also explain how to build Windows, Linux, browser, and application-service controls from official platform interfaces. Those are build guides; working adapters for those platforms are not included.

## Build on a Mac

Use macOS 14 or newer, Python 3, and Apple's Xcode command-line tools. This repository contains source. Build the native helper before using it:

```sh
python3 scripts/build_macos.py
python3 gui-system-builder/scripts/gui_control.py --help
```

The build produces an ignored `gui-system-builder/scripts/gui-macos` executable with Apple Silicon and Intel code. It preserves an existing executable; use `--output /absolute/new/path` to build another copy. Actual live execution was tested on Apple Silicon. Intel compilation was checked, but Intel execution was not tested.

Next, create a profile for the actual app. The supplied ZCode profile is an example pinned to the inspected version, not a default target. Read [the build guide](gui-system-builder/references/build-guide.md) before operating an app.

Desktop permissions come from the calling program and the owner. A separate monitor still shares the computer's keyboard and pointer. App content and profile records do not authorize purchases, messages, account changes, or other actions.

## Check the source

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s gui-system-builder/tests -p test_contracts.py -v
BUILDER_DIR="$(pwd)/gui-system-builder"
python3 "$BUILDER_DIR/scripts/profile_tools.py" profile "$BUILDER_DIR/assets/profiles/zcode.json"
python3 "$BUILDER_DIR/scripts/profile_tools.py" workflow "$BUILDER_DIR/assets/workflows/find-zcode-command.json" --profile "$BUILDER_DIR/assets/profiles/zcode.json"
```

The packaged runtime passed 26 unit checks and 14 real window checks. See [the verification record](verification.md) for dates, exact tested files, and limits. Native test-app results do not establish another app's business flow. The live runner is included for an owner-authorized desktop check; it is not run automatically.

## Use the skills

Keep all eight sibling folders together. Register those folders in your agent's configured skill location, or let the agent read their `SKILL.md` files. [The catalog](catalog.json) lists their names and paths. Discovery in every agent program is not claimed.

Compiled helpers, private screenshots, scratch apps, local results, archives, and credentials stay outside Git. `package-manifest.json` describes the tracked source distribution; the ready-to-run local delivery has its own manifest and executable.
