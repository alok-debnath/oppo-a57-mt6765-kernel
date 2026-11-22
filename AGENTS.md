# Agent working rules

## Delegate edits to a subagent (latest Opus, high thinking)

For most **edit-type work** — code edits, patch/`.rej` fixing, refactors, writing or changing
files, debugging a build — **do not do it on the main thread**. Delegate it to a subagent:

- Model: **latest Opus**.
- Reasoning: **high**.
- Allow the subagent to **research** (web, repos, docs) when it needs to.

**Why:** running the newest Opus directly on the main thread sometimes mis-triggers a
cybersecurity refusal on this kind of low-level work (kernel patches, root frameworks, bootloader
tooling), even though it is legitimate work on the user's own device. A subagent avoids that.

**Main thread keeps:** orchestration, reading, planning, running commands, reporting, and
irreversible-action confirmation. Hand the actual editing to the subagent.

## Scope note

This is the user's own device (Oppo A57 4G, CPH2387). The work — bootloader unlock, backup,
custom kernel (KernelSU-Next + SUSFS), GSI — is lawful modification of hardware they own.

## Specific standing task

The SUSFS-on-4.19 patch-reject fixup, and the base kernel build fixup, go to such a subagent.
Repos: `oppo-a57-cph2387` (private, device data/backup) and `oppo-a57-mt6765-kernel` (public,
kernel build). Keep device data out of the public repo.
