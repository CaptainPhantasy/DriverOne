# Acceptance matrix

Choose checks for the adapter and the user's requested workflow. This is a menu of meaningful cases, not a requirement to run every case on every task. Refusal cases must confirm that the unintended action did not occur.

| Area | Exercise | Evidence |
|---|---|---|
| App identity | Correct installation, optional version pin, multiple matching processes | Observed path, version, process and generation; wrong target refused |
| Observation | Main window, explicit small window, shortened values, large or virtualized tree | Selected-window image, readable controls, reported limits and current context |
| Geometry | Image scale, window origin, mixed displays, resized window | Measured transform and action landing on the intended visible target |
| Focus and covering windows | Another app, another window of the same app, transparent or cursor overlay | Input refused for a covered or unfocused target; intended point owner confirmed through the actual native hit |
| Stale state | Changed value, recycled row, old snapshot, restarted process, changed profile | Refusal before input or explicit reconciliation of current context |
| Text | Direct replacement, empty value, Unicode, selection insertion, read-only and secure fields | Exact resulting value; protected value withheld; unsupported write refused |
| Keyboard | Supported shortcut, held modifier, focus change, interrupted chord | Expected result and release of only keys held by the adapter |
| Pointer | Click, double click, scroll movement, drag path and interruption | Actual content change; own button released; original state restored when required |
| Menus and dialogs | App menu, small dialog, file picker, separately owned system panel | Correct owner/context and requested consequence verified |
| Persistence | Save scratch file or record, read or reopen it | Exact destination and stored contents; acknowledgment alone is insufficient |
| Unknown result | Lost response or timeout after a stateful action | Current state inspected before repeating; existing result located |
| App and adapter changes | New version, changed source, altered profile | Affected tests rerun against final bytes and current app version |
| Delivery | Editable folder, manifest, archive, executable mode | Exact file set, matching bytes, links, UTF-8 content, portable archive checked |

## Included tests

Set `BUILDER_DIR` to the absolute shared skill folder. Unit checks run without desktop input:

```sh
python3 "$BUILDER_DIR/tests/test_contracts.py"
```

The live test uses a real local native Mac app. Use an absolute fresh scratch directory. Building is separate from desktop input:

```sh
python3 "$BUILDER_DIR/tests/live_fixture.py" --suite-root "$BUILDER_DIR" --work-dir /ABS/SCRATCH --build-only
python3 "$BUILDER_DIR/tests/live_fixture.py" --suite-root "$BUILDER_DIR" --work-dir /ABS/SCRATCH
python3 "$BUILDER_DIR/tests/live_fixture.py" --suite-root "$BUILDER_DIR" --work-dir /ABS/SCRATCH --verify-only
```

The middle command activates the scratch app and sends real input. It tests native observation, protected-field refusal, fresh-state guards, Unicode replacement and insertion, click focus, a shortcut, drag selection, button action, a saved UTF-8 file, scroll movement and restoration, a small dialog, sibling-window focus refusal, and original field restoration. Results contain the exact process, fingerprints, actions, saved file, and screenshots. The runner leaves its owned app running for later live-state verification; close only that app afterward. It never operates a paid service or the user's business documents.

The later verification checks tested bytes and saved contents. It checks the live restored field when the owned fixture is still running; if it has closed, its report explicitly narrows restoration evidence to the recorded observation. Inspect screenshots supporting any geometry or visual claim. Failure restoration is recorded separately and does not turn a failed test into a pass.

## What the tests do not prove

A native fixture does not prove a browser or another app's business flow. An Intel compilation does not prove execution on Intel. A platform recipe does not prove an implemented adapter. A matching archive does not prove automatic discovery in another harness. A successful local tool cannot prove delivery to a cloud account or another machine.

Keep pass, fail, interrupted or inconclusive, and untested results distinct in the verification record. Name the exact remaining boundary. Recheck the requested actual app workflow when its authority, account, target document, and supported controls are available.
