---
name: gui-system-builder
description: Build an agent-neutral control system for a chosen GUI application, with app inspection, guarded adapters, workflow records, recovery, and real outcome checks. Use when creating or extending the system rather than only operating an existing app.
---
# Build an application control system

A GUI is an application's visible windows and controls. An adapter is the small program that connects the agent to that application. Build a working adapter for the user's actual app and task. This package supplies a real Mac adapter and methods for building other platform adapters; it does not make every app or platform automatically controllable.

Start with the user's desired result and the actual installation. Preserve the exact app, account, document, record, machine, and destination. Inspect existing tools and the app before adding a service or changing settings. Choose the least complicated control route that reaches the user's existing session and exposes enough evidence to verify the result. A supported app command may work better than a pointer action; a private sign-in callback cannot substitute for control of a window.

Read [the build guide](references/build-guide.md) for implementation and [the control contract](references/control-contract.md) before writing an adapter. Use the two schemas and `scripts/profile_tools.py` to keep app profiles and workflow records consistent. These records contain data and findings. They do not grant permission or run shell commands.

For Mac apps, first build the helper from the repository root with `python3 scripts/build_macos.py`, as shown in [README.md](../README.md). Then reuse `scripts/gui_control.py` and the built `scripts/gui-macos` executable. Every call requires an explicit profile. The native helper binds observations and actions to the app, its installation, its current process generation, the selected window, and the profile fingerprint. It provides observation, focus, exposed actions, field replacement, Unicode insertion, shortcuts, clicking, scrolling, and dragging. Inspect `--help` before using flags. Other platforms need an implemented and tested adapter, as described in the platform guide included with `gui-adapter-engineer`.

Route only the needed work to these package components: `gui-app-inspector` for identity and available routes; `gui-observation-designer` for readable state and image geometry; `gui-adapter-engineer` for actual controls; `gui-workflow-author` for outcome-based steps; `gui-operator` for execution; `gui-recovery-engineer` for failures or unknown results; and `gui-system-verifier` for final checks. Their folders are siblings in this suite. Each can be used independently for its own job.

Build and exercise one complete useful workflow before broadening coverage. Keep supported methods and untested methods distinct. Add a persistent connection, extra process, model, or dependency only when the inspected app and requested workflow need it. Never turn discovery into automatic remote pairing, debugger enablement, credential collection, or permission grants.

Deliver the editable adapter source, working controls, profile, workflow records, test results, version information, and explicit remaining limits. A running helper is a milestone. Completion means the requested user-visible or saved result was checked at the intended destination.
