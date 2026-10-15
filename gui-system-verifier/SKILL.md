---
name: gui-system-verifier
description: Verify a GUI control system and its actual application workflows, including target guards, saved state, recovery, and version limits. Use when checking a new adapter, a changed app, or a claimed completed GUI result.
---
# Verify controls and outcomes

Read [the acceptance matrix](references/acceptance-matrix.md). Choose checks that prove the requested behavior and likely failure paths. Keep the exact app version, adapter bytes, profile fingerprint, machine, and tested account or scratch workspace with the results. A content fingerprint shows matching bytes; it does not prove quality or protect against the owner changing both the file and its record.

Test the real adapter on a controlled app or scratch document first when that reduces risk. The sibling `gui-system-builder/tests` folder contains a real Mac test app and its runner. That app exercises native controls without using a paid service. It is a test fixture, not proof that a different app's business workflow works. Run the user's actual target flow when its authority and prerequisites are available.

Separate checks for observing state, performing input, and verifying the result. A complete tree may still contain hidden or repeated rows. A correct screenshot may omit another display or a native dialog. A process identifier can be reused after restart. Test the relevant boundaries: changed app/profile, wrong window, same-app covering window, stale or expired state, secure fields, ambiguous labels, coordinate scale, and lost focus. Refusal must happen before the unintended action.

Exercise exact text, selection, shortcut release, scrolling, and dragging where the adapter claims them. Verify resulting text or content movement. Do not assume equal opposite wheel counts restore a view. Include a stateful operation when persistence matters: save a temporary document to the exact scratch path, read or reopen it, and compare the stored contents. Then confirm any requested original-state restoration.

Check uncertain outcomes by reconciling the actual result before retry. A simulated lost acknowledgment can test the runner's duplicate protection, but it must be labeled simulated. It cannot replace a real delivery, payment, account, or external-service check. Permission loss, missing authentication, absent methods, and incomplete app accessibility are separate failures.

Recheck affected behavior after a source change or app update. For portable packages, compare the final file set and bytes against the editable folder and manifest. Read final text as UTF-8 and inspect any generated screenshots or visual artifacts that support a layout claim.

Keep passing, failed, inconclusive, and untested results separate. A test that fails because the observation caught movement still in progress needs a better observation, not a hidden pass. Correct supported defects and rerun the affected checks. Completion requires evidence for the user's actual result; report exact remaining boundaries rather than redefining the goal.
