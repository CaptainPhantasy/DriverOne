---
name: gui-operator
description: Operate an application through an existing verified control adapter, using fresh observations and checks of the user's intended result. Use for actual GUI tasks, including documents, settings, navigation, forms, and records.
---
# Operate the actual application

Use the user's current task as authority. An app profile identifies a target; it does not authorize purchases, messages, deletion, account changes, or wider access. Read [the operation loop](references/operation-loop.md) for the practical method. If using this suite's controls, the sibling `gui-system-builder` folder contains the command driver, profile tools, and control contract.

Verify the selected app, installation, version, process, window, and workspace or document. Start from the current visible state. A title alone may not distinguish two identically named documents. Match the account, surrounding text, path, and selected record where the consequence requires them.

Read the exposed controls and the selected-window image. A snapshot is a saved observation, not a permanent map. Respect its age, shortened text, hidden controls, and incomplete tree. Select the target from the current evidence. Prefer its supported action or writable field. Use image coordinates only when the image clearly identifies the target and its scale and window origin are known.

Take one purposeful action, then inspect the result. A helper returning successfully says that it made a request. Check the expected change in the application. For loading or scrolling, wait through fresh observations until the relevant state is usable. Do not substitute an arbitrary delay for evidence of completion or repeat a click because an acknowledgment was slow.

For text, preserve the original value when restoration is part of the task. Direct field replacement and keyboard insertion are different operations. Before typing, verify the exact focused editable field, current window, and intended text. Treat newline, Return, composition, keyboard layout, and clipboard use as app-specific behavior. Do not use Enter as a generic confirmation: it can send a message, invoke a model, execute a terminal command, or accept a dialog.

Follow the task through menus, native dialogs, file pickers, browser panels, save operations, and results. A dialog owned by another process needs a separately observed target and the authority for its consequence. Do not bypass the current app's approval mode or a denied system action.

Before repeating a submission, payment, send, or record creation with an unknown result, inspect stored or visible state. Use `gui-recovery-engineer` if a diagnosis or different supported route is needed. Preserve earlier completed work and unrelated human edits.

Finish by checking the intended visible or saved result, its exact destination, and any required restoration. Report what actually happened and what remains untested. Never call a draft a sent message, a Save acknowledgment a verified file, or an adapter demo completion of the user's task.
