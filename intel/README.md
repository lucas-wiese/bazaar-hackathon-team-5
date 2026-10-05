# intel/: what the sessions wrote during the game

These are the decisions, measured facts, runbooks and checks the Claude Code sessions wrote live, between Friday night and Sunday afternoon. They're kept as they were written, with references to files that aren't in this snapshot. The team's working repo had about sixty of these files. This is a selection.

| Layer | File | What it is |
|---|---|---|
| **Decide** | [`directives.md`](directives.md) | The Chief of staff's decision log: 84 of 100 timestamped calls, newest on top, each with its limits and its reason, most with a [Verified]/[Likely]/[Open] label. Limits change only through `GUARDRAIL` lines. Lightly redacted (see its header) |
| **Act** | [`ORCHESTRATOR.md`](ORCHESTRATOR.md) | The Operator's runbook: the system it operates, hard limits, "decide, don't ask", what to do on each event |
| | [`saturday-sessions.md`](saturday-sessions.md) | Four sessions, one role each: who owns what, the rules between them, and each session's first prompt |
| **Learn** | [`GAME.md`](GAME.md) | The facts we measured about the game, including the ones that corrected our beliefs |
| | [`metrics.md`](metrics.md) | The live brief every agent read, rebuilt every 2 minutes from raw data (last state) |
| **Duels** | [`duel-lab.md`](duel-lab.md) | The Duel Lab: the simulator, its calibration and every GO / NO-GO on duelist parameters |
| | [`duel-sets/`](duel-sets) | The approved parameter sets the tuning loop switches between |
| **Market** | [`market-playbook.md`](market-playbook.md) | The Market session's playbook for our venue and the Market Tests |
| **Check** | [`contra-duels.md`](contra-duels.md) | A contrarian review: a fresh session trying to break Sunday's duel plan before it ran |
| | [`duelist-reaudit.md`](duelist-reaudit.md) | An independent re-audit of the Sunday duelist's branch, run offline before Duels III and the Final |
