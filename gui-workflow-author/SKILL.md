---
name: gui-workflow-author
description: Write and exercise complete graphical-app workflows with exact targets, starting conditions, observed steps, saved-state checks, and recovery from uncertain results. Cover editors, files, dialogs, terminals, model tasks, account forms, and custom canvases without relying on fixed clicks.
---
# Describe and finish the user's app workflow

Use this skill to turn a requested app operation into a workflow that another local agent can execute and verify. A workflow is a record of the intended result, the controls involved, and the evidence needed to establish completion. It is not a recording of guessed clicks.

Read the shared [control contract](../gui-system-builder/references/control-contract.md), actual application profile, and workflow schema under [schemas](../gui-system-builder/schemas/). Preserve the user's exact paths, record names, recipients, amounts, and wording. Inspect current app state before choosing steps. A reversible implementation detail can be decided from that state; a missing fact that changes the destination, money, authority, or result needs resolution before its dependent action.

Use the schema's fields: `id`, `profile_name`, `goal`, `preconditions`, `steps`, `completion`, and `restoration`. Each step carries `id`, `intent`, `selector`, `action`, `expected`, and `repetition`. Describe the target by current role, label, and record context. Keep coordinates as observed action inputs, not permanent workflow assumptions. Choose `safe-after-check`, `inspect-before-repeat`, or `never-automatic` to describe repetition. Observation, waiting, and verification steps may omit a selector.

Build toward the complete user result. For a document, verify the saved file and reopening behavior. For a setting, reread the stored value. For a submitted task, verify the actual task identity, progress, and final result. Do not treat a draft, enabled button, successful command exit, or visible spinner as finished work. Read [workflow-patterns.md](references/workflow-patterns.md) for these cases.

After each meaningful action, capture the affected state and check its expected result before continuing. Use current observations for menus, native dialogs, virtualized rows, editors, and custom canvases. Confirm exact text and selection before keyboard input. Distinguish inserting a newline from submitting a command or model prompt.

Handle uncertain acknowledgments in the workflow itself. Check whether a record, file, task, or submission already exists before retrying. Preserve partially completed edits and unrelated work. Restore temporary searches and test fields when appropriate; never undo the user's requested result as cleanup.

Exercise the workflow against the actual installed adapter and app when authorized. Record the tested versions, resulting saved state, and untested consequences. Existing authority carries across the workflow; ordinary reversible steps do not require repeated confirmation. New recipients, costs, destructive consequences, or access changes still need the authority applicable to that specific result.
