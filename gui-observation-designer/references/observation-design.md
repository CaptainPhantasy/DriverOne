# Observation methods

Use the shared [control contract](../../gui-system-builder/references/control-contract.md). Keep app and workflow records compatible with the schemas under [the builder's schemas folder](../../gui-system-builder/schemas/).

## Read the smallest useful surface

Start with application identity and a window inventory. Then capture the selected window or task-relevant region. This makes the result easier to understand and reduces unrelated private content. Record the actual process and window identifiers, version, title, capture time, focused window, and whether the content tree was shortened. If the adapter cannot report an attribute, leave it unknown. Do not fill it from an old profile.

Read sensitive fields through the narrowest permitted method. Avoid exporting whole account pages when the task only needs a status or destination. A screenshot may include a visible secret even if the control tree masks its value. Keep task evidence local unless its transmission is authorized.

For each candidate target, capture its role, label, supported actions, current value where appropriate, bounds, and nearby record or section text. Match the intended object as well as the control. For example, a `Save` button next to the requested document differs from an identically named button in a settings panel.

## Choose a reading route

| Surface | Read first | Check before acting |
|---|---|---|
| Ordinary form | Exposed roles, labels, values, and actions | Correct section, field, and focused window |
| Custom canvas | Selected-window image and exposed surrounding controls | Target location, image scale, and changed appearance |
| Virtualized list | Visible rows and relevant row context | Record identity after every scroll or filter |
| Editor | Document identity, current text, selection, and composition state when exposed | Exact insertion or replacement meaning |
| Native dialog | New window inventory and that window's own controls | Owner, destination, selected file, and consequence |
| Terminal | Session title, machine, directory, visible prompt, and command draft | Intended session and whether execution already occurred |
| Running task | Progress, result text, permission state, and stored task identity | Ongoing work versus final output or a blocked decision |

Source inspection can explain a route, but it cannot replace a current observation of the running app. An updater or sign-in callback is not a control route merely because it listens on a local port. Starting a second app runtime does not prove attachment to the visible session.

## Coordinates and custom canvases

Record the image width and height, its captured content rectangle, the window's coordinate rectangle, and any cropping or padding. Use the adapter's documented coordinate system. When the image covers the whole window with no padding, a simple conversion is:

```text
window_x = image_x * window_width / image_width
window_y = image_y * window_height / image_height
```

If the image is cropped, add the crop's window offset after applying its scale. If padding exists, remove its pixel offset first. Screen coordinates need the window's screen origin as well. A moved window, zoom change, display change, or resized capture invalidates an earlier transform. Read a fresh image after those changes.

Text recognition finds possible text locations; it does not prove that the matched text is clickable. Match the surrounding shape and nearby labels. Use a point inside an unambiguous target, away from edges and overlapping controls. Before input, verify that the point belongs to the selected window using the adapter's available guard. After input, check the expected visible or saved change. If the image cannot distinguish targets, improve the observation or report the missing information.

Canvas operations need task-specific evidence. A clicked drawing tool should show the selected tool; a moved object should have the intended position; a saved drawing should reopen with its content. A successful click cannot substitute for these checks.

## Multiple monitors and a shared desktop

Inspect the current display inventory before placing or targeting a window on another monitor. Record the selected display's actual bounds and scale, then read the target window's resulting bounds. Displays can have negative screen origins or different scales. A monitor number or an old arrangement does not establish where a window is now. After moving or resizing a window, capture it again and recalculate its image-to-window transform.

Verify that the intended pointer point lies on an active display and belongs to the exact selected window. A selected-window image may include off-screen content; a readable image alone does not establish pointer access. Observe popovers and native dialogs separately, since they can appear on a different display from their parent window.

Permission to use another monitor establishes the allowed display area. It does not establish a separate keyboard, pointer, clipboard, or foreground session. In a shared desktop session, inspect the focused app, selected window, and editable field before input. Prefer exposed actions or direct field changes when they accomplish the task without changing foreground focus. If the human changes focus or content, observe again and reconcile that state rather than reusing the previous target.

Report monitor placement and input separation as distinct evidence. Say which display and window were verified. Claim a separate input session only when its actual connection and routing were inspected and exercised; another physical monitor is not that proof.

## Virtualized lists and bounded exploration

Filtering by an exact known record often gives a clearer result than broad scrolling. Preserve the original filter. Verify the requested record's identifying context rather than accepting the first partial text match.

When scrolling is necessary:

1. Record the visible rows and an anchor near the viewport edge.
2. Move one useful section, then capture again.
3. Check that content actually changed. Repeated anchors can reveal a boundary or an ignored wheel event.
4. Match the requested record using its name plus relevant date, path, account, or other known context.
5. Capture again before acting; reused row controls may now represent another record.

Choose a bounded search range from the known list or requested scope. If the range is unknown, use a reasonable initial observation budget and expand only when new evidence supports further search. Exhausting the initial budget means the target remains unlocated, not that it does not exist. Check filters, grouping, collapsed sections, another workspace, and archived views before concluding absence.

## Loading and stable state

Define the condition that matters for the next action: dialog appeared, row loaded, save indicator finished, result exists, or a field became enabled. Poll that condition with reasonable spacing. Inspect progress during long operations. A spinner means work may still be running; no spinner does not necessarily mean a save reached storage.

For moving layouts, compare relevant bounds and values across fresh observations. Animations or a live clock elsewhere should not block an otherwise stable control. For stored changes, verify storage through an app-supported read, reopening the document, or another authorized independent read. Do not invent a failure because an arbitrary time passed. If a real deadline exists, report the operation as still running, interrupted, or failed according to observed evidence.

## Text, selection, and composition

Distinguish setting the entire value from inserting at the current selection. Before insertion, verify the focused editable field and the document or form it belongs to. Check the selected range if the adapter exposes it. Otherwise use an observed, meaningful selection action and verify its result. Test Unicode and multiline text on a disposable field before relying on a new adapter's input method.

Composition is the temporary text state used by some keyboard input methods. If composition is active or unknown after typing, observe the settled text before sending Enter, Tab, or a submit shortcut. Newlines can insert a line, execute a terminal command, or send a message depending on the field. Verify the field's behavior and use an explicit submit action when available. Compare exact final text, including line breaks; do not silently normalize it.

Prefer supported field-setting or direct text insertion methods. If clipboard use is required and authorized, record its initial state without exposing it. Restore it only when it still contains the temporary value written by this operation. Another actor's clipboard change must not be overwritten by a stale restoration.

## Native dialogs and observation evidence

Detect a dialog through a fresh window inventory, not a guessed window number. It may belong to the target app or an operating-system service. The chosen adapter must support that observed owner. Read its title, destination, selected items, buttons, and relevant consequence. Verify exact paths and account names before confirmation. After closing the dialog, re-establish the original window and focus.

Store the observation file, relevant image or crop, adapter version, target selection, and expected condition with each important result. Redact or omit private content unrelated to the evidence. Report what those observations prove and what remains unreadable. Screenshots, controls, and saved files are complementary evidence; none automatically proves the others.
