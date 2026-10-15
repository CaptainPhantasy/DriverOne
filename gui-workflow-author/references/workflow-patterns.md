# Complete workflow patterns

Use the shared [control contract](../../gui-system-builder/references/control-contract.md) and [schemas](../../gui-system-builder/schemas/). The examples below describe real operations to exercise; they do not claim that an uninstalled platform adapter works.

## Workflow record

Keep the record plain and specific. The schema's required fields are:

| Field | What to record |
|---|---|
| `id` | A stable name for this workflow |
| `profile_name` | The exact application profile used |
| `goal` | The user-visible finished result, with exact destination and content where supplied |
| `preconditions` | App and workspace identity, required starting state, existing authority, and needed adapter methods |
| `steps` | Observed transitions toward the result |
| `completion` | Independent checks that establish the requested visible or saved result |
| `restoration` | Temporary state to restore, requested changes to retain, and conditions that make restoration unsafe |

Each step uses these fields:

| Field | What to record |
|---|---|
| `id` | Unique within this workflow |
| `intent` | The state change the step should produce |
| `selector` | Role, label, current record context, and selected window needed to find the right control |
| `action` | One supported adapter action with actual inputs resolved from the fresh observation |
| `expected` | The later observation or saved state that proves the step's effect |
| `repetition` | Whether to inspect the existing result before any repeated action, or whether repetition is safe after checking state |

`preconditions`, `completion`, `restoration`, and each step's `expected` are arrays of strings. A selector can use `role`, `label`, `identifier`, `value`, `context` as an array of strings, and `window_title`. Include only attributes the actual observation can establish. Selectors are optional for `observe`, `wait`, and `verify` steps.

Use these exact repetition values:

- `safe-after-check`: a fresh check can establish that repeating the step retains the intended result.
- `inspect-before-repeat`: reconcile the existing result before any repeated action, because it may already have happened.
- `never-automatic`: a repeat needs the missing fact or authority applicable to its consequence.

Describe why a repeated action might create a duplicate, execute twice, replace unsaved content, or toggle the result back. Even a safe repeat needs a fresh target observation. This classification does not revoke authority already provided by the user.

The action names are `observe`, `activate`, `press`, `set-value`, `type`, `hotkey`, `scroll`, `drag`, `wait`, `verify`, `save`, and `submit`. `save` and `submit` describe workflow goals; the operator must resolve their actual visible controls or supported interface actions. They are not invented driver commands. The profile reports the adapter's implemented methods.

The record may refer to generated evidence paths, but it must not depend on a particular harness's tool names. Actual adapter command names belong in the application profile. If a route is unavailable, select another verified route or implement and exercise the needed method; do not pretend a description is executable integration.

## Editor: edit, save, and reopen

Establish the app, document, and exact path. Read existing content and unsaved-state indicators. If another document has the same title, use its path or other context to distinguish it. Preserve unrelated content.

Focus the observed editor. Set, insert, or replace text according to the actual supported operation. Confirm exact Unicode characters and line breaks. Check composition has settled before using a save shortcut. Capture the resulting editor content.

Use the visible Save action or a verified shortcut. When a native dialog appears, inspect that dialog's owner and exact destination. A file-extension change does not convert the format. If saving would replace an unrelated existing file, inspect that file and resolve the consequence within the user's authority.

Check the stored file through an authorized read or reopen it in the app. Verify exact content, required format, and destination. A dismissed dialog proves only that the dialog closed. If autosave is involved, read its actual status and verify persisted state. Do not close an unrelated unsaved document to make the test easier.

## Settings and extension discovery

Read the original value and relevant section. Change the exact requested setting, then observe its stored state. Refresh the list only when needed. Installing a command or skill file and seeing the app discover it are separate outcomes; verify both when requested.

Use an exact-name search to check discovery and match a separate name or description row. Restore the temporary search value. Reopening the settings view can check persistence without restarting the application. Restart only when required for the requested feature and authorized; never use it as a routine cleanup step.

## File picker and native dialogs

Detect newly opened windows from the inventory. Select the exact observed dialog, including a system-owned dialog when the adapter supports that owner. Read directory, filename, format, selected records, overwrite warnings, and buttons. Changing directories or field text is separate from confirming the action.

After confirmation, verify the destination or resulting document in the parent app. Re-establish its focus before continuing. A main-window snapshot does not establish a dialog's controls, and a label such as `Continue` does not reveal the consequence without its surrounding text.

## Terminal execution

Verify the terminal's machine, workspace directory, session identity, and visible prompt. Do not infer these from the app's outer project title alone. Inspect a command already in the input line before replacing or executing it. Keep shell text literal and use the harness's safe argument handling when commands are passed outside the GUI.

Separate drafting from execution. Multiline pasted text or an embedded newline can execute a command immediately. Use a demonstrated input method and a single explicit execution step. Read the resulting prompt, exit information when exposed, and actual output or created artifact. A successful typing action proves neither command execution nor success.

For an uncertain acknowledgment, inspect output, process state, or the expected artifact before submitting again. A repeated build may be harmless; a repeated migration, deployment, payment, or external message may not be. Use the existing task authority for each actual consequence.

## Model task or message submission

Verify the task, workspace, model selection, mode, destination, and exact draft. A selected model name is a configuration observation, not proof of a live response. Preserve user-provided wording. Inspect added attachments or context before submission.

Submit only under the user's authority for that task and any resulting cost or communication. Once submitted, record the task identity and observe progress, permission requests, result text, and completion state. A spinner means work may be ongoing. A successful Send action proves only that the input was requested.

If acknowledgment is lost, look for the existing task or message using its identity and content before any resend. If a permission request stops the task, preserve its state and identify the exact decision. A separate direct model call cannot prove that the GUI task ran correctly.

## Virtualized rows and custom canvases

Find records using visible context, filters, and bounded scrolling. Reused row identifiers are not record identity. Capture again before selecting a record and verify the opened detail view.

For a custom canvas, define the intended visible or saved change: selected tool, moved object, drawn shape, or changed viewport. Map the current image into the adapter's coordinate system. Verify the resulting content after each action. For a saved drawing, reopen the document or inspect its actual stored representation when authorized. A pointer movement alone is not evidence of a changed object.

## Long operation and partial state

Wait on meaningful conditions and keep observing progress at reasonable intervals. Separate a rejected operation, an operation still running, a lost observation connection, and an operation interrupted by a genuine deadline. These states need different recovery.

If a later step fails, preserve completed work. Record which edits, files, tasks, and submissions already exist. Resume from those observations rather than replaying the entire workflow. Restore temporary test filters or selections only when doing so cannot overwrite a newer user change. An explicit user cancellation stops dependent actions; a side question does not revoke authority to finish the original workflow.

## Completion evidence

Check the original goal again. Validate exact destination and values, current saved state, final visible behavior, and any requested app discovery or reload. Name the actual tested app and adapter versions. State which paid, remote, destructive, or other important paths were not exercised. Keep receipts and detailed observations in evidence files; give the user the result, material limits, and a useful evidence link.
