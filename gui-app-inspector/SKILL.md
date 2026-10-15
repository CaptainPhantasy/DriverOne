---
name: gui-app-inspector
description: Inspect a real GUI application and map its usable control routes, permissions, windows, controls, and workflow limits. Use before building or extending an application profile or choosing between native controls, browser control, and an application service.
---
# GUI app inspector

Produce an evidence-backed control map for the actual installed and running app. A control route is a way to read or operate the app, such as its accessible controls, browser pages, or documented commands. The map must distinguish what exists in source from what connects to the current app and what has actually been exercised.

Read [inspection-method.md](references/inspection-method.md) for the detailed inspection record and tricky boundaries. Start with the user's exact app, workflow, and destination. Inspect current installation path, executable, version, running process, visible windows, and any applicable project instructions. Do not infer the launch target from an app name, a nearby repository, or an old screenshot.

Identify the app's kind: native window, browser page, Electron desktop app, remote desktop, or a mixture. Accessibility is the operating system's interface for reading controls and invoking supported actions. Discover it independently from screenshots and keyboard or pointer access. A missing accessibility tree is not proof that the entire app is unreachable. A privacy denial, harness sandbox denial, missing tool, disconnected route, and unsupported app control are different observations.

Observe the current target without changing its account, settings, open documents, or running work. Record window identity, control roles and labels, available actions, editable fields, focus, loading state, dialogs, and coordinate scale. Custom canvases and virtualized lists need explicit investigation: items may appear only when rendered or scrolled into view. Do not conclude that unseen controls do not exist.

Inspect local commands, protocol links, documented services, listeners, app manifests, and packaged source only within the authorized task. Attribute each endpoint to a process and its purpose. Treat sign-in callbacks, updater services, internal message channels, and cloud model APIs as separate from GUI control until evidence establishes otherwise. Do not harvest credentials to test a speculative route.

Where testing is authorized, choose a harmless read and a reversible action tied to a clear expected result. Observe after each action, restore temporary state when appropriate, and report the actual outcome. Do not submit a paid prompt, send a message, publish, or approve a destructive dialog merely to prove control. A dialog owned by another process needs its own target identity and authority.

The complete suite's optional macOS runtime is at `../gui-system-builder/scripts/gui_control.py`. Read its Python command help before using current profile and observation commands. Other platform sections describe adapters to build; they are not installed control tools.

Deliver the versioned control map, sources and observation dates, exercised operations, permission boundaries, known unsupported paths, and the smallest remaining dependency. State a capability only as broadly as the evidence supports. Preserve original scope: a reachable button or successful health request does not prove a whole workflow is complete.
