# CLAUDE.md

See [AGENTS.md](AGENTS.md) for working rules.

Key rule: delegate most edit-type work (code edits, patch/.rej fixing, debugging builds) to a subagent on the latest Opus with high reasoning and research allowed; keep the main thread for orchestration, commands, and reporting. Reason: new Opus on the main thread can mis-trigger a cybersecurity refusal on this low-level device work.
