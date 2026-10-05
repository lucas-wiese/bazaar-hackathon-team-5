# How the sessions worked together

Three people, their Claude Code sessions and about twenty background processes worked on one game, through one API key with shared rate limits, for three days. Everything below exists to stop two things: a write nobody owns, and a decision nobody can trace back.

## One role per session

On Saturday, Lucas's machine ran four Claude Code sessions in one window. Each one owned its files, and nobody else touched them:

| Session | Model | Owns | Talks to Lucas? |
|---|---|---|---|
| **Chief of staff** | Opus 5.5, xhigh | the directive log, every decision, the summary for Lucas | **Yes, the only one** |
| **Operator** | Opus 5.5, high | all game writes (trades, dealers, offers) and the trading daemons | No: it reports to the Chief |
| **Builder** | Opus 5.5, high | `tools/` and the code behind the bots. On Saturday night it rebuilt the duelist | No: it reports to the Chief |
| **Market** | Fable 5.1, high | `broker/`, our venue, the Market Test recorder | No: it reports to the Chief |

Aleks and Dani ran their own sessions on their own lanes (the duels, the room). Advisory analysts ran as detached processes on the Claude API (a scout on Sonnet, a judge on Opus): they wrote files the sessions read, and never acted.

The rules that kept them from stepping on each other:

1. **Nobody waits for a human.** Each session decides inside its hard limits and reports what it did. Only the Chief asks Lucas, and only about cash, guardrails, the venue, anything that risks a lot of score, or a teammate problem.
2. **Every file and every daemon has one owner.** To change something you don't own, you message its owner.
3. **One writer to the game per job.** The Operator handles trades and dealers, and the duelist handles duels. The Market session also built a broker to match trades on our own venue, but it never ran live: we kept the free stall.
4. **Messages are short:** `what · why · what I need (or FYI)`.
5. **Every action is one log line.**

## Decisions as a log, limits as GUARDRAIL lines

The Chief never touches the game. It writes decisions to an append-only log, newest on top, one line each: `time · decision with its limits · why`, labelled **[V]**erified (measured or read from the server), **[L]**ikely (inferred) or **[O]**pen. A hard limit, such as a cash floor or a price cap, changes only through a line that contains the word `GUARDRAIL`. The Operator executes each directive within the limits and reports back when one can't be done.

On Saturday and Sunday the log collected 100 decisions. 23 of them were GUARDRAIL lines, mostly one-off exceptions to a limit. The log is in [`intel/directives.md`](../intel/directives.md), lightly redacted (84 decisions and 19 GUARDRAIL lines published). Four lines from it, shortened:

```
- 16:43 · GUARDRAIL · Cash floor 70 for one Pícaros SAL-10 buy at ≤ 63 (structure check: exactly card:SAL-10,
  cash only); back to 100 once the fever resales land; no other buys meanwhile
- 16:55 · Final = game (0.5·Fri + Sat + Sun)/2.5 over 60 + judges over 40: confirmed. Duel accepts don't count
  against the market accept: all 6 duels can accept in the same tick → no serialization of duel accepts
- 17:45 · Ladder capped for us: stop ladder-driven deals [L, Analyst + /api/me: negotiating flat 21.88 across
  MAL-06, MAL-09 and SAL-04, 0 board effect on 3 deals]
- 00:35 Sun · CORRECTION [V]: MARKET-MAKING 30 = MARKET TEST 22.5 + REAL TRADES 7.5 (the 21:10 line had them
  swapped; every file that says "real trades 22.5" is wrong)
```

The last one is the system working as intended: a belief written down with its source can be found and corrected. Not every copy caught up, though. One analyst file kept the old split, and stale copies were a recurring problem.

## The Operator's runbook: decide, don't ask

The Operator runs unattended. Its standing order, in Lucas's words on Friday night: *"I don't want things stopped by me not looking."* The Operator decides and acts on everything inside the hard limits, and only a GUARDRAIL line moves one. Its context is disposable because all state lives in files. When the context gets heavy, it writes a five-line handoff and a fresh session takes over. That was the design. In practice, one Operator session ran from Saturday 09:34 on about 21 hours of compacted context, and a 600 s sleep loop woke it.

**Exactly one Operator at a time.** On Friday two sessions wrote to the game at once. On Saturday, `tools/operator_lock.py` made it structural:

```bash
python3 tools/operator_lock.py acquire operator   # exit 1, and who holds it, if another session does
python3 tools/operator_lock.py heartbeat          # on every wake-up; exit 1 if we are not the holder
python3 tools/operator_lock.py release
```

The lock records the pid of the Claude Code process itself (the nearest `claude` ancestor), not the pid of the script, so the lock lives exactly as long as the session. A lock whose process is dead, or whose heartbeat is more than 10 minutes old, is stale, and anyone may take it.

## Read-only by default

Only two roles write to the game. Everything else senses:

- `tools/collector.py` appends every public event, our state and each leaderboard snapshot to `data/`, about every 15 s. It is the single source of truth every agent reads.
- `tools/metrics.py` turns `data/` into a short factual brief every 2 minutes. It is deterministic and uses no LLM.
- `tools/status.py` rewrites a status file every 5 minutes. It is the only writer of that file.
- `tools/watch.py` prints one line per change that matters, for a Claude Code `Monitor`. It was built to wake the Operator.
- `tools/duel_monitor.py` flags live duels and reviews each wave.
- `tools/preflight.py` checks every API key before a session acts, after a $1 spend cap once stopped the analysts for 17 minutes.
- `tools/daemons.sh` starts each daemon by explicit name, never all at once, and restarts any that die.

## Git is the bus

Three laptops and their Claude Code sessions stayed in sync through the repo itself:

```json
{
  "hooks": {
    "SessionStart":     [{"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/tools/team_sync.sh\" pull"}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/tools/team_sync.sh\" pull"}]}],
    "Stop":             [{"hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/tools/team_sync.sh\" push"}]}]
  }
}
```

- **Pull before every prompt, push after every turn.**
- **Each person writes their own log** (`team/<name>.md`). Logs merge with `merge=union`, so they never conflict. Shared files still could:
- **Daemons commit through `tools/gitsync.py`.** A file lock keeps them from colliding on git. It never pulls over work in progress, because on Saturday morning an `--autostash` pull had left a rebase stuck and broken every session's pull.

This is shared context with a latency of one prompt, not real time. It was fast enough for decisions, and too slow for anything that had to react within a tick, which is why those reactions live in code.

## Checking before the big calls

Many of the big calls got a separate pass first. A fresh verifier subagent graded a plan or a claim against its sources, and contrarian reviews argued the other side. The context that writes a plan is bad at catching its own mistakes. On Sunday at 07:25, contrarian reviews of the endgame plan, the duels and the market changed the plan before the game reopened. Not every big call got a pass, and a pass is no guarantee: one directive labelled verified (a scoring cap) turned out to be wrong and was retracted half an hour later.

What we'd change: run that check automatically on every directive.
