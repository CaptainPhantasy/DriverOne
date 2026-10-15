---
name: gui-recovery-engineer
description: Recover graphical-app work from stale targets, wrong windows, missing permissions, ignored input, uncertain acknowledgments, loading, version changes, and lost connections. Diagnose the failed layer, preserve completed changes, and verify a supported alternate route before resuming.
---
# Recover progress without losing work

Use this skill when an app action failed, produced the wrong result, or returned an uncertain acknowledgment. Recovery starts from the current app state. It does not start by repeating the last click.

Read the shared [control contract](../gui-system-builder/references/control-contract.md), application profile, workflow record, and the exact failed observation or command result. Preserve completed edits, saved files, submitted tasks, and unrelated work. Distinguish action failure from an unavailable observation: a disconnected reader may have missed an action that already happened.

Inspect the actual target again. Check app and version identity, selected window, focused field, current record, loading state, and visible result. For an uncertain submission, look for the resulting task, file, message, or record before considering repetition. A missing acknowledgment cannot justify a duplicate payment, message, command, or model task.

Identify the failed layer with evidence. It may be target selection, stale state, image scale, input delivery, app behavior, storage, authentication, desktop permission, harness access, or a lost connection. One failed probe does not prove that the app lacks a control interface or that the workstation is unavailable. Read [failure-atlas.md](references/failure-atlas.md) for practical diagnostics and alternate routes.

Choose a different supported recovery when the evidence explains why it should work. Examples include selecting the observed dialog, raising the actual window, using an exposed field action instead of keyboard insertion, reading a narrower control tree, or reconnecting the exact existing service. An alternate route needs the same task authority and platform permissions; it cannot bypass a denial. Do not restart the app, enable debugging, grant access, or change execution mode automatically.

Make the smallest justified correction, then rerun the affected action with fresh targeting. Observe the resulting state and verify the workflow's expected result. Record the failed mechanism, what worked, the remaining limits, and the actual correction. Avoid unchanged retries and endless search loops. A test budget is a search boundary, not evidence that a running operation failed.

Continue every independent authorized step while a genuine external boundary remains. If recovery requires a fact only the user can supply, missing authentication, unavailable resource, or new authority, ask once for that exact dependency. Report completed work and the precise remaining action. Do not present partial progress or a workaround as completion while the requested normal workflow remains unverified.
