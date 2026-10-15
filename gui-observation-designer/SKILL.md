---
name: gui-observation-designer
description: Design reliable observations for a graphical app, including exposed controls, screenshots, custom canvases, native dialogs, virtualized lists, text fields, and loading states. Define exact target selection and coordinate mapping before an agent acts.
---
# Design observations that support real actions

Use this skill when an agent needs to understand an app well enough to act on the right window, record, or field. An observation is a saved view of the current app state. A selector is a rule for finding the intended control in that view. An adapter is the tool that reads and operates the app.

Read the shared [control contract](../gui-system-builder/references/control-contract.md) and the actual application profile. Inspect the adapter's returned fields before depending on them. Do not invent focus checks, coordinates, identifiers, image-reading tools, or complete text exports that the adapter does not supply. Build the Mac helper first using the command in [README.md](../README.md); the control source is included. Recipes for other platforms still need an installed, exercised adapter.

First establish app identity, version, selected window, and the view being inspected. Select the relevant ordinary window or observed dialog explicitly. A largest-window rule can help discovery, but does not prove that the right document or account is open. Read the title, surrounding controls, and relevant record content. Distinguish another app, a same-app popover, a system dialog, and an overlay.

Prefer exposed control roles, labels, current values, and supported actions when those identify the target. Accessibility is the operating-system feature that exposes those controls. Pair the control view with the selected-window image when the layout or visible context matters. Use image reading for controls that are drawn without exposed elements. Record how image pixels map into window coordinates; never assume that screenshot pixels and screen points match.

Mark missing, shortened, offscreen, and changing content. A virtualized list creates or reuses controls as rows enter view; a saved row identifier cannot establish the row's meaning after scrolling. Explore in bounded sections, match the requested record, and capture again before acting. Read [observation-design.md](references/observation-design.md) for concrete methods.

Before each action, require a current target observation and enough context to distinguish duplicate labels. Keyboard and pointer actions also need the correct focused window and field. During loading, observe progress and wait for the action's relevant condition. Two matching images can support visual stability; they cannot establish that data has finished saving.

Deliver the observation method, selectors, coordinate rules, completeness limits, and examples from the actual adapter. Verify them on the requested workflow. Report unreadable regions and uncertain targets plainly instead of filling them with guessed state.
