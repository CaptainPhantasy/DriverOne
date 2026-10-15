---
name: gui-adapter-engineer
description: Build and verify the operating-system, browser, or application adapter that connects a GUI control system to a real target. Use for native controls, screenshots, keyboard and pointer input, and documented control services.
---
# GUI adapter engineer

Build the smallest working connection for the requested app and workflow. An adapter translates the system's common actions into a particular app or operating system's controls. Keep the control system independent of the agent model and its tool names.

Start with the actual installed app, its version, its running process, and its visible window. A documented interface, a discovered interface, an authenticated connection, and an exercised workflow are separate evidence states. Do not describe a source finding as a working connection. An update service or sign-in callback cannot stand in for application control.

Read [platform-adapters.md](references/platform-adapters.md) for the platform you are building. This suite includes a macOS runtime. Windows, Linux, browser, and application-service sections are build recipes; they do not supply working adapters. When the complete suite is installed, inspect `../gui-system-builder/scripts/gui_control.py --help` through Python before choosing commands. Use its current profile and read commands to bind the actual target. A profile records an app's identity and permitted control route. Do not invent command flags or profile fields.

Prefer supported control actions over pointer coordinates when they express the requested behavior. Accessibility is the operating system's interface for reading and acting on app controls. Discover each control's available actions and writable attributes. Use a fresh screenshot and guarded native input for a canvas, missing controls, or a behavior the control interface cannot express. Browser page controls and native file dialogs may need different adapters.

Record identity, supported operations, existing permissions, observation time, coordinate origin, screenshot dimensions, and the conversion between screen points and image pixels. Keep app and window selection explicit. A title alone is not identity. Reject stale references, ambiguous targets, disabled controls, unsupported actions, and mismatched geometry. Reobserve instead of silently picking another control. Focus and verify the actual window before keyboard or pointer input; release only the keys and buttons this adapter pressed.

Return performed, refused, failed, partial, or unknown outcomes accurately. A timeout does not prove that an app action failed. Inspect the current app before repeating a mutation. Verify later visible state and any required saved result. A successful command is not proof that the user's workflow finished.

Use existing authorized access. Do not harvest tokens, change privacy settings, restart apps, enable debugging, weaken isolation, or elevate privileges just to obtain another route. Those changes need authority appropriate to their consequences. A system dialog owned by another process needs its own target binding and task authority. Keep private captures local and redact secure values; images may still contain sensitive content.

Finish with working code, capability findings, named tests, and exact remaining limits. Promise the tested operations on the tested target. Do not promise that every GUI exposes every control.
