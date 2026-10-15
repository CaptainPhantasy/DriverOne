# Verification record

## Historical desktop checks: 2026-10-13

The original installed package was exercised against ZCode 3.7.5, build 3.7.5.4641, on an Apple Silicon Mac. Its native source is the unchanged `scripts/mac_gui.swift` in this source distribution. This is a historical check, not a fresh replay of every desktop action from this Git checkout.

The actual full ZCode window tree and its window-only screenshot were read and visually checked. Reversible Settings and Commands navigation, command-list refresh and search, exact Unicode field replacement, stale-snapshot refusal without a text change, activation, focused clicking, Unicode typing, shortcut replacement, wheel scrolling, text selection by dragging, and exact original field and scroll restoration passed. The final native input run passed seven checks. The installed skill was also discovered by its exact name in the real Settings > Skills view. No model task was submitted.

These checks used the following source and original installed executable fingerprints. A fingerprint is a SHA-256 content checksum. It ties the record to those bytes; it does not prove that every possible workflow works.

- Native source: `f1d14673e1d9509c55c862906c3c3cdfc17c40df56b32b8fe74ec3864a8d055b`.
- Original installed universal executable: `aadeb6d5173888c829186ca3080d64bc2ecb50ef1ce2c5abf60d34cb088c5316`.

The original installed executable is deliberately absent from this source repository. A fresh compilation can have a different executable fingerprint. No screenshot, app content export, installed-user inventory, or desktop test log is included.

## Source distribution checks: 2026-10-15

The Python driver's 15 behavior tests passed. They check literal arguments without shell execution, wrong app selection, duplicate selectors, missing helper handling, uncertain timeouts, workspace URL encoding, optional-tool path expansion, and refusal of optional Steer input routes that bypass native guards. These tests do not make GUI changes or network requests.

The documented local build command compiled the native source for both Apple Silicon and Intel with a macOS 14 minimum target. Both executable slices were checked. The rebuilt helper's help output and invalid-argument refusals were checked without sending GUI input. Only the historical Apple Silicon executable was exercised in a live workflow. Intel execution is untested.

All distributed text was read as UTF-8. Local documentation links and the source manifest were checked against saved files. The interface counts match their entries: 33 service channels, 113 renderer functions, and 57 private runtime methods. The source manifest lists the distributed files and excludes itself and local build output.

## Interface findings

`interfaces.json` records app-source locations and official reference URLs from the 2026-10-13 inspection. Private internal methods and separately configured remote routes are findings, not public GUI control services. Observed local HTTP listeners served an updater and a sign-in callback; they did not drive the GUI. Their dynamic port numbers are not distributed as configuration. Workspace deep-link parsing and its native confirmation were found in installed source; opening a folder through it was not exercised. No remote server was paired, debugging port enabled, separate coding runtime started, credentials read, or app restart performed.

Recheck controls and interfaces after a ZCode update. This source branch retains the ZCode-specific driver. DriverOne's main branch contains the separate general GUI operation suite.

## Verification limits

Paid model submission, account changes, credentials, remote server authentication, production changes, destructive dialogs, workspace deep-link opening, Intel runtime execution, other display scales, other keyboard layouts, and every possible task, editor, or browser dialog were not exercised. No other agent tool or cloud host was run during these checks. Each agent tool's skill discovery and desktop permissions must be checked in that tool.

The driver uses current snapshots, process and window identity, control identity, foreground focus, and pointer ownership checks. Those checks reduce wrong-target mistakes. They do not prove the business meaning of visually identical controls. Follow the current user's authority and verify the result after one action.
