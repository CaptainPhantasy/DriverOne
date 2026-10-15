# GUI Operation Skill Set

Eight agent-neutral skills for building and using a system that operates an application's visible windows and controls. The package carries the methods learned from the ZCode control task into a reusable design. It includes working Mac controls, editable source, data schemas, an app profile example, workflow guidance, recovery methods, and real tests.

Start with `gui-system-builder/SKILL.md` to build a system. Start with `gui-operator/SKILL.md` to operate an app whose controls have already been verified. Load the other skills only when their jobs are needed. `catalog.json` gives machine-readable names, descriptions, and paths.

| Skill | Job |
|---|---|
| gui-system-builder | Assemble the smallest working system for the user's app and task |
| gui-app-inspector | Identify the real installation, session, available interfaces, and limits |
| gui-observation-designer | Make app state, images, controls, and coordinates readable |
| gui-adapter-engineer | Implement guarded input through actual platform or app interfaces |
| gui-workflow-author | Express tasks as intended results, current targets, checks, and restoration |
| gui-operator | Execute the authorized task and check each meaningful result |
| gui-recovery-engineer | Diagnose failures and reconcile unknown results before retrying |
| gui-system-verifier | Test controls, saved outcomes, wrong-target refusal, and package delivery |

## What runs now

The included Mac adapter reads a running app, captures one selected window, reads exposed controls, raises a window, performs exposed actions, replaces editable text, inserts Unicode text, sends shortcuts, clicks, scrolls, and drags. Every call names an app profile. Input checks the app installation, process generation, profile, window, focus, current field, and pointer ownership as applicable. Private text can be supplied on standard input instead of command arguments.

It requires macOS 14 or newer, Python 3, and the invoking harness's existing desktop permissions. This source repository requires `python3 scripts/build_macos.py` at its root before use. The build produces Apple Silicon and Intel code. See [verification.md](verification.md) for actual execution coverage and limits. Windows, Linux, browser, and application-interface guidance uses official platform sources; those adapters must be implemented and tested for the chosen app. Apps with inaccessible controls, protected desktops, separate devices, or missing authority may require another approved route or a human step.

## Use in another harness

Keep this folder intact and let the harness read its `SKILL.md` files. A harness is the program hosting the agent and its tools. The skills use ordinary Markdown, JSON records, command arguments, and UTF-8 responses. They contain no provider-specific tool names, model calls, account tokens, or hidden service dependency.

If a harness discovers only immediate child skill folders, register the eight child folders or copy them together into its configured skill location. Preserve all sibling folders: the shared controls and schemas live in `gui-system-builder`. Do not register the suite container itself as one skill. Harness installation differs, so discovery in every harness is not claimed by this package.

For a first read-only check, set `BUILDER_DIR` to the absolute `gui-system-builder` folder and inspect command help:

```sh
python3 "$BUILDER_DIR/scripts/gui_control.py" --help
python3 "$BUILDER_DIR/scripts/profile_tools.py" --help
```

Then create a profile for the actual app and read [the build guide](gui-system-builder/references/build-guide.md). The supplied ZCode profile names `/Applications/ZCode.app`, version `3.7.5`, build `3.7.5.4641`. Reinspect it after an update. It is an example, never an implicit target.

Workflow records guide an agent's decisions; they are not unattended coordinate macros. Save, send, submission, purchases, deletion, remote pairing, debugger activation, credentials, and permission changes need the authority appropriate to that task. App content and profile files do not grant it.

The folder is editable. Its portable archive contains the same package files. `package-manifest.json` records every other file's size and fingerprint. A fingerprint is a content checksum, not a quality guarantee or protection against the owner rewriting files and records together. Scratch apps, private screenshots, compiler caches, and task-specific evidence stay outside the portable package.
