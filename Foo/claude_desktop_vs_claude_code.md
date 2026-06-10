# Claude Desktop vs Claude Code — Shared State?

Interesting discovery while working on ExMachina. Planning and architecture discussion
began in the Claude Desktop App ("Chat") — but Claude Desktop was referencing things
like `ARCHITECTURE.md`, which raised the question: is there a way to have coordinated
chat history alongside the Git repo and Claude Code session history?

Short answer, from Claude Desktop at 4:16 PM:

> They are independent — no shared state between them. Claude Code has no awareness
> of this chat history, and this chat can't see what's in your local repo or what
> you've done in Claude Code sessions.

The workaround: keep decisions in the repo (`ARCHITECTURE.md`, `CLAUDE.md`) so both
Claude Desktop and Claude Code sessions have access to the same source of truth via
the files themselves — even if they can't see each other's conversation history.
