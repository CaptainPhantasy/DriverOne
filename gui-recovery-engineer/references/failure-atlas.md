# Failure atlas

Use the shared [control contract](../../gui-system-builder/references/control-contract.md). The application profile says which routes were actually exercised. A suggested route below becomes usable only after its prerequisites are verified.

## First response to failure

Preserve the command result and the before observation. Capture current state through the existing authorized reader. Record what is already changed, saved, submitted, or still running. Then decide whether the action failed, the wrong target was selected, the expected result has not arrived, or only its acknowledgment was lost.

Read enough to identify the exact failed layer. A control method returning success says it delivered a request; the app may reject it, apply it to another record, or save it later. A control method returning a timeout may already have delivered input. Reconcile current state before another mutation.

## Target and observation failures

| Observation | Check | Supported recovery |
|---|---|---|
| Stale target refused | Current process, window, record, value, and bounds | Capture again and resolve the intended target from current context |
| First window is a tiny overlay | Actual window inventory, titles, owners, and dimensions | Select the observed ordinary window or exact dialog |
| Another same-app window received focus | Focused window and selected native window identity | Raise the intended observed window and verify focus before input |
| Pointer point is covered | Window order and ownership at the actual pointer position | Inspect the covering dialog or raise the intended window; retain the ownership check |
| Control tree is shortened | Reported depth, node, or value limits | Increase supported limits or read a narrower region |
| Requested row is absent | Filters, grouping, collapsed sections, workspace, archive, and viewport | Explore a bounded relevant region and match the row's real identity |
| Label matches several controls | Section, record, dialog, and nearby text | Use the distinguishing context; do not choose the first match |
| Capture has padding or wrong scale | Reported pixel size, content rectangle, window points, and display scale | Correct the transform and capture again before pointer input |
| Canvas has no exposed elements | Current selected-window image and surrounding controls | Use verified image-to-window mapping with visible result checks |

Do not disable stale-target or ownership checks to make an action pass. The ZCode task showed that overlays, incorrect image scale, and another same-app window can all create plausible but wrong input targets. The lesson is to fix selection and mapping, then verify the user-visible effect.

## Input failures

For keyboard input, inspect app and window focus, exact editable field, selected range, composition state, and current value. Confirm whether the method inserts text or replaces the whole field. If direct field replacement is supported, it may be a clearer route than a shortcut-dependent selection. If it is unsupported, use a verified focus and selection method, then inspect exact resulting text.

A shortcut can fail because a modifier was retained or a physical key conflicts with synthetic input. Inspect the adapter's delivery method and reported key state. Correct release of its own synthetic keys; do not blindly release the human user's held keys. Test the final build on a disposable field and verify exact replacement rather than merely checking a zero exit.

For Unicode, multiline input, and composition, compare the exact settled text. Do not silently normalize characters or line breaks. Check whether Enter inserts text or submits the field. If temporary clipboard use is required and authorized, restore only the clipboard value still owned by this operation; another actor's later content takes precedence.

For scrolling, inspect the actual pointer position, selected window, scroll container, and content movement. The event's requested coordinates may differ from the pointer position the app uses. Use a guarded pointer move when the adapter supports it, then verify movement. An exposed `scroll to visible` action can be a genuine alternate route. Equal opposite wheel counts do not prove restoration.

For dragging, verify starting ownership, the selected object or text, and the endpoint. Check whether the app changed its selection or moved the object. Ensure the adapter releases its own synthetic button on interruption. Never infer a successful drag solely from cursor movement.

## Connection and permission failures

Separate these layers:

- App not running, minimized, or showing a different workspace.
- Reader not connected to the intended app session.
- Missing desktop control permission.
- Missing screenshot permission.
- Harness access denied despite existing desktop permissions.
- App account authentication missing or expired.
- A route discovered in source but not exposed in the installed app.
- An optional tool unavailable while another existing route still works.

Check the actual target and any already configured owner service before declaring a whole capability absent. Reconnect the exact existing route when diagnostics support it. Lost variables, an app update, a failed connection, and a workstation outage are different facts.

A denied route does not authorize an alternate route that defeats the same protection. An alternate authorized interface may legitimately provide the required operation, but it must retain the user's scope, destination, and permission boundary. Do not scrape credentials, enable a debugging service, weaken a sandbox, or widen remote access to manufacture control.

If permission or authentication is genuinely missing, name the exact layer and smallest user action needed. Preserve independent work. Do not ask the user to repeat earlier authority for the same action or approve an agent-selected reporting process.

## Uncertain acknowledgment and duplicate prevention

Determine the expected durable result before any retry. Search for the existing task, record, message, file, or command output using known identifying context. Match destination and content as well as timestamps when available. If a saved file exists, inspect its actual content. If a task exists and is still running, continue observing that task instead of submitting another.

If current observations prove that the action did not occur, repeat it with fresh targeting. If they prove it occurred, resume from the new state. If the result remains ambiguous and repetition can create a harmful duplicate, preserve the ambiguity and obtain only the missing fact needed to resolve it. Do not convert uncertainty into an invented error or claim success without evidence.

## Long operations and partial work

Inspect meaningful progress and relevant completion conditions. A fixed timeout can end an observation call without ending the app operation. Report that distinction. Reattach to the same operation when supported. Interrupt or cancel it only under the user's authority or an applicable real stopping condition.

When later steps fail, keep earlier completed changes. Save evidence of the current document, task, setting, and destination. Resume from a verified checkpoint. Restore temporary filters and test fields only if they still contain this operation's temporary values. Do not overwrite a newer user edit during cleanup.

A backup or scratch copy can help preserve recoverable edits when authorized, but it must not replace the requested final product. Do not migrate, rewrite, or remove features just because the chosen control route is awkward.

## Version drift and alternate-route choice

Compare the installed app and adapter versions with the profile. An update can change labels, window owners, controls, private methods, and storage. Reinspect the affected flow and refresh the profile after verification. Old source offsets describe the old build, not a current interface guarantee.

Choose alternatives by mechanism, not by superficial wording. Direct field setting differs from keyboard insertion; selecting a dialog differs from raising the main window; reading saved state differs from reading a spinner. Repeating the same failed click with a new delay is only useful when evidence shows that loading or focus changed.

Keep the recovery record small: triggering observation, diagnosis, candidate mechanism, prerequisites, actual attempt, resulting state, and remaining limits. Follow any governing harness recovery or receipt protocol without turning its internal process into extra user requirements. After a supported correction passes, perform a later independent check of the requested outcome and continue the original workflow.
