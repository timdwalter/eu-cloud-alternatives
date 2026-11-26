# Test log – Azure

## Step 0 – Project setup (2026-11-26)

**What:** Initialised GitHub Spec Kit for Claude Code and clarified the scope in a "grill-me" interview (results in [decisions.md](decisions.md)).
**How:** CLI (local machine, Windows 11).

**Prerequisites that were not obvious**
- Spec Kit needs `uv`. Installed with `winget install astral-sh.uv`; the shell PATH had to be reloaded before `uvx` was found.
- Local machine had only Node.js. Still missing: az, terraform, kubectl, helm, gh, docker.

**Where the agent was unsure / wrong**
- Used the flag `--ai claude` from older Spec Kit docs; the current CLI uses `--integration claude`. Fixed after reading `specify init --help`.
- Spec Kit's agent check did not find the `claude` binary on PATH; worked around with `--ignore-agent-tools`.

**Scope changes during the interview (noteworthy for the article)**
- Started from a fairly complete enterprise stack (Argo CD, Key Vault + External Secrets, external-dns, remote state, two node pools, monitoring). Cut down deliberately to an "ultra minimal" stack; see the "Dropped on purpose" list in decisions.md.

**Time:** ~1 h (mostly the scope discussion).
