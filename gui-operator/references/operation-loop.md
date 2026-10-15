# Operation loop

Use this method after an adapter has been built and its supported methods are known. Read only the app and task details needed for the next action. Keep the real document, account, workspace, and destination in view throughout the task.

## Establish the target

Load the actual profile. Inspect the running installation and version. Choose the process and native window or browser context. If the app is not running, launch it only within the task's authority using its normal launcher; the included adapter does not launch apps. Existing access, successful observation, usable controls, working input, and task completion are separate checks.

Use a current snapshot and image. For repeated labels, combine role, label, identifier, surrounding context, visible business record, and document identity. A changing list may reuse element paths. If the target is ambiguous, gather another observation or navigate to a distinguishing state before acting.

## Use an assigned monitor without assuming separate input

When the user assigns another monitor, inspect the displays and identify the allowed one from current context. Use a supported window-placement route, then read the resulting window bounds and capture it again. Do not invent a movement command or assume that an old monitor number remains correct. Check that the intended input point lies on an active display and belongs to the selected window. A captured off-screen window is not a usable pointer target.

Placing a window on that monitor does not create a separate keyboard or pointer session. Prefer exposed actions and direct field changes when they work without taking foreground focus. Keyboard, pointer, and shortcut operations still need the exact observed focused window and field. Keep those actions short and inspect their result. If focus changes or a human edit appears, stop the old action sequence, read the current state, and continue only from reconciled targeting. Do not repeatedly steal focus back or restore over the newer edit.

Inspect newly opened menus and dialogs even if they appear on the user's monitor. Select their actual owner and window before continuing. Keep unrelated screen content out of the evidence. Report verified window placement separately from any verified input isolation; claim isolation only after a separate session or routing mechanism has actually been exercised.

## Decide and act

Ask internally: what change should this action cause, how will it be visible, and can it safely be repeated? Select the supported action that reaches that change. The adapter performs one guarded operation; the agent owns the task decision.

For an exposed button, use its supported action. For an editable field, prefer direct replacement when the app supports it. For keyboard input, confirm the exact focused field and window. For a visual control without readable metadata, use a current selected-window image and measured scale. A visible control in a covered or background window cannot safely receive ordinary pointer input.

Use the smallest action that advances the task. Inspect afterward. A focus change can reveal another window. A click can open a menu or start a slow operation. A shortcut can mean something different in a different field. Treat those transitions as new state instead of continuing an old sequence blindly.

## Verify the transition

Compare the actual result with the expected one. After a text change, read the value. After navigation, inspect the destination. After scrolling, verify movement or the intended item becoming visible. After a dialog opens, select its real owner and window. After saving, verify the exact persisted file or reopen the record when the task requires persistence.

Wait through observations that show loading, progress, or completion. Keep the stopping condition concrete: a status becomes complete, the saved record appears, the document path changes, or the expected result is present. A first frame during animation is not a stable result. If the task has a user deadline, observe it; otherwise do not call a slow operation failed solely because a preferred delay elapsed.

## Repetition and unknown results

| Situation | Next action |
|---|---|
| Adapter refuses before input | Read the stated cause and inspect the current target; correct the identified prerequisite |
| App state changed as expected | Continue from the new state |
| A supported operation returns but expected state is absent | Inspect focus, loading, app errors, and target identity |
| Timeout or connection loss leaves acknowledgment unknown | Reconcile visible or saved state before any repeat |
| Save, send, submit, purchase, or record creation is uncertain | Locate the actual destination record or receipt; use its identity to avoid duplicates |
| Permission or account access is denied | Use an authorized recovery route; do not change access or bypass a denial |

Do not reuse a stale observation, repeat unchanged failures, or retry an irreversible consequence because a response was missing. The recovery skill contains routes for these cases.

## Finish the whole task

Check the final exact text, selected record, destination, and user-visible or saved outcome. Confirm restoration when requested: original field, scroll state, selection, window state, or scratch app cleanup. Preserve unrelated human edits and never restore over a newly changed document without reconciling it.

Record the app version, profile fingerprint, adapter version or bytes, actions, later observations, final saved state, and any untested path. Say what was actually completed. A working input method proves a control method; the user's requested result needs its own evidence.
