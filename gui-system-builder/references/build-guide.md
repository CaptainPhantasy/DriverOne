# Build guide

Start with one useful user workflow. Inspect the actual target, implement the needed controls, run the workflow, and verify its result. Expand coverage after that works. A large framework is not a prerequisite.

## Four pieces

| Piece | Purpose | Keep it small |
|---|---|---|
| App profile | Exact app identity, inspected version, available routes, limits | Data only; no credentials, launch command, or permission grant |
| Adapter | Read state and perform one guarded action | One local process is enough unless the app needs a persistent session |
| Workflow | User goal, starting conditions, expected changes, repetition and restoration | Outcomes and current selectors; no permanent coordinate script |
| Evidence | Actual action, later result, saved-state check, tested versions | Include unknown and untested outcomes |

The agent supplies decisions. The adapter supplies deterministic mechanics. A successful command is separate from a successfully completed workflow. See [the control contract](control-contract.md) for the shared record format and app-specific boundaries.

## Use the included Mac runtime

Set `BUILDER_DIR` to this `gui-system-builder` folder. Use an absolute profile filename. The provided ZCode profile is tied to its inspected version; it is an example, not a default target.

```sh
python3 "$BUILDER_DIR/scripts/profile_tools.py" profile "$BUILDER_DIR/assets/profiles/zcode.json"
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$BUILDER_DIR/assets/profiles/zcode.json" doctor
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$BUILDER_DIR/assets/profiles/zcode.json" info
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile "$BUILDER_DIR/assets/profiles/zcode.json" snapshot --enhance --screenshot --output-dir /tmp/gui-observations
```

`doctor` reports whether the included backend exists for the host. `info` reads the app and existing permissions. Neither grants access or proves a workflow. Native controls require the Mac desktop where the app runs, Python 3, macOS 14 or newer, and the harness's existing permission to use controls, capture images, and post input. A sandbox can block access separately. Use the harness's authorized permission route; do not bypass a denial.

To adapt another Mac app, create a new profile with `schema_version: 1`, a short `name`, `platform: macos`, and its actual `identity.bundle_id`. Add its verified absolute `app_path` and expected version/build when known. Leave `electron_accessibility` false or absent for ordinary native apps. Use `info` to inspect actual values before pinning them. Change a pin only after investigating the app update; never silently accept drift.

Every input uses a fresh saved snapshot. Examples show placeholders that must be replaced from actual observations:

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile /ABS/PROFILE.json press --snapshot /ABS/OBSERVATION.json --id ACTUAL-ID
printf '%s' 'exact requested text' | python3 "$BUILDER_DIR/scripts/gui_control.py" --profile /ABS/PROFILE.json set-value --snapshot /ABS/OBSERVATION.json --id ACTUAL-FIELD --value-stdin
python3 "$BUILDER_DIR/scripts/gui_control.py" --profile /ABS/PROFILE.json activate --window-id ACTUAL-WINDOW
```

Read each command's help for click, type, hotkey, scroll, drag, and snapshot limits. Use `--pid` when choosing among multiple matching app instances; that process must belong to the profile's app. Explicit window selection supports small visible ordinary dialogs. The default chooses a large ordinary window; check that choice rather than trusting it as the user's intended document.

## Build a different platform adapter

Read `gui-adapter-engineer/references/platform-adapters.md` in the sibling folder. Implement the shared observation/action result contract using that platform's actual interfaces. Discover supported methods at runtime. Return an explicit unsupported result for missing methods. Do not substitute a stub, newly launched browser, or separate app instance for the user's existing session.

An app-specific documented interface is useful only if its process, version, target session, authentication, and operation are verified. Keep a private or source-only route labeled as such. Provide one narrow client before adding a control service, tool bridge, or multi-process architecture. Do not expose a debugger or start remote pairing as a discovery shortcut.

## Build and test the native source

This source repository builds the helper with `python3 scripts/build_macos.py` at its root. The result contains Apple Silicon and Intel slices. The verification record distinguishes compilation from execution. To rebuild for the current Mac with installed Xcode command-line tools:

```sh
xcrun swiftc -O -parse-as-library -swift-version 5 "$BUILDER_DIR/scripts/mac_gui.swift" -o /tmp/gui-macos-rebuilt
```

To produce the supplied two-architecture form, compile separately with `-target arm64-apple-macosx14.0` and `-target x86_64-apple-macosx14.0`, then combine with `lipo -create`. Keep the original package and test the new executable before replacing it.

`tests/test_contracts.py` checks records and command behavior without GUI input. `tests/live_fixture.py --help` describes the actual local test app, build-only stage, live run, and later read-only verification. Run the live stage only when local desktop test input is authorized. The fixture writes only its supplied scratch destination. Retain results and exact helper fingerprints; then test the actual app workflow separately.

## Deliver a usable system

Deliver the adapter source and executable, profile, workflow, supported-method report, tests, fingerprints, actual results, and precise limitations. Include an editable folder and a portable archive when handing off the system. Verify archive contents after the final edit. Finish the requested work instead of stopping at a profile or a working helper demo.
