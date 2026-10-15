# ZDrive

ZDrive operates the existing ZCode desktop app on macOS. It gives local coding agents the same small commands for reading a window, finding controls, setting text, clicking, typing, scrolling, and dragging.

This is the ZCode-specific **ZDrive** branch of [DriverOne](https://github.com/CaptainPhantasy/DriverOne). The [main branch](https://github.com/CaptainPhantasy/DriverOne/tree/main) contains the general GUI operation suite for building drivers for other applications.

## Build and start

Use macOS 14 or newer with Python 3 and Apple's Xcode command-line tools already installed. ZCode must be installed on the same Mac. This repository ships editable source. It does not ship a compiled helper.

From this folder:

```sh
python3 -B scripts/build_native.py
python3 -B scripts/zcode_control.py doctor
python3 -B scripts/zcode_control.py info
python3 -B scripts/zcode_control.py snapshot --enhance --screenshot --output-dir /tmp/zdrive-observations
```

The build command compiles `scripts/mac_gui.swift` to the ignored local file `scripts/zcode-macos`. Add `--universal` to compile both Apple Silicon and Intel versions. Only Apple Silicon has been exercised live. The supplied native source targets only the ZCode app identifier `dev.zcode.app`. The `ZCODE_GUI_APP` setting changes only the app information read by `doctor`.

Existing macOS Accessibility access is required for controls. Existing Screen Recording access is required for screenshots. The driver checks access and never grants it. The shell must also have permission to reach the local desktop.

Read [SKILL.md](SKILL.md) for the agent instructions, [the workflow guide](references/gui-workflows.md) for commands and [the verification record](references/verification.md) for what has been checked. Keep screenshots and saved observations outside this repository. They can contain private app content.

## Use it from any agent

An agent needs a local shell, Python 3, and this folder. Set `SKILL_DIR` to the folder when following the examples in `SKILL.md`. To install it in ZCode's skill folder, copy this source folder into `~/.zcode/skills/zcode-gui-control` and run the build command there. Other agent tools can read the same skill file or invoke the same commands directly. Discovery in each agent tool must be checked separately.

Take a current snapshot, choose a control from that saved observation, perform one authorized action, then observe the result. The driver refuses expired or changed targets. Pointer and keyboard actions require the exact observed ZCode window to be focused. These checks reduce wrong-target mistakes; the agent must still check the meaning of a control before using it.

## Check the source

```sh
python3 -B -m unittest discover -s tests -v
python3 -B scripts/build_native.py --universal
```

The tests use temporary files and process stubs. They do not click or type into ZCode and do not make network requests. A successful build proves compilation, not a working desktop workflow. The source manifest lists the distributed source files and excludes generated build output.

The interface inventory describes findings from ZCode 3.7.5, build 3.7.5.4641, inspected on 2026-10-13. Private internal routes are observations rather than supported control services. Recheck the actual app after an update. The driver does not start a separate coding runtime, enable debugging, pair a remote server, or submit a paid model request on its own.
