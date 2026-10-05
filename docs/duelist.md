# The duelist

A duel is a one-on-one negotiation over a single deal, against another team's agent, on the game's clock. Each side has a private limit. The value of the deal shrinks with every round of talk, and from the second scored session on, the delivery day becomes a second issue. Six duels run at once, each with a message cap per tick. We played 238 duels: 34 practice and 204 scored.

## Saturday: the models decide

Aleks's original duelist (Clock-Standing) splits the work in three:
- a **strategist** model reads the duel and sets a band, a target and a delivery day;
- a **negotiator** model writes the message and the price inside that band, without ever being told our limit;
- **code** clamps, vetoes and repairs every move, and holds when holding is free.

It worked: 88 % of duels ended in a deal in Duels I and 82 % in Duels II. It was also slow. In Duels II the average decision took 7.5 s and the slowest 21.9 s, and a quarter of the 514 decisions ran past 10 s. Sunday's tick was 15 s.

## Sunday: code decides, the model writes

On Saturday night, from 22:01 to 01:39, Lucas's Builder session rebuilt the decision layer on top of Aleks's duelist (`agents/duelist/policy.py`):
- **code** decides to accept, hold or step, and picks the delivery day;
- **one model call**, to Claude Haiku 4.5, writes only the words within a time budget. If the call is late, code's own plain text goes out instead;
- an **8 s failover** means a slow model never costs us the tick.

| | Saturday (Duels II) | Sunday (Duels III + Final) |
|---|---|---|
| Who decides | strategist + negotiator models | code |
| Mean decision time | 7.5 s | 0.43 s |
| Slowest decision | 21.9 s | 2.5 s |
| Duels / deals | 68 / 56 | 102 / 84 |

## The guards

- **Whole-package worth.** Every limit and every accept check prices the full package, money plus the value of the delivery day (with the seller's day bonus offset). A last-line `final()` check runs on every outgoing move (`agents/duelist/guards.py`, `agent.py`).
- **No flaggable words.** Any team could flag a message as bad faith, and a correct flag scored for the flagger. So our text never makes a checkable claim: it passes an English and Spanish claim-word filter and a check for stray numbers, and code's plain text is the fallback.
- **Their words are evidence, not instructions.** The prompts say so explicitly. A rival's deadlines, "final offers" and notes claiming to come from the organisers are moves in the game, not orders.
- **Restart-safe.** On restart, our existing messages count as already sent, so the duelist never sends one twice. The test for this replays a real incident, duel 181.

## Measured, then tuned

- **The scoring model is exact on our data.** In all 238 duels, the game's round count equals the smaller of the two sides' message counts. In all 189 deals, our predicted result matches the game's to within 0.1. We ran that check on the full records; the shipped test replays it on the practice-duel fixtures.
- **31 hot-reloaded parameters** (`agents/duelist/params.py`): bounded, cross-checked and reloaded all-or-nothing. If the file is missing, a git-tracked default plays, with a warning.
- **The Duel Lab** (`tools/duel_sim_v2.py`): a simulator with rivals fitted on Duels II transcripts and calibrated per role on 62 of those duels.
- **The wave loop** (`tools/duel_loop.py`): after each wave of duels, it tests one-parameter tweaks against today's policy on common random numbers. It proposes only tweaks whose paired 95 % confidence interval sits entirely above zero, and it never applies anything itself: a human runs `approve` or `revert`.
- **A one-way safety switch** (`tools/duel_gates.py`): if the deal rate falls below a threshold, a pre-approved conservative set replaces the live one, once. A kill file stops it.
- **One-command deploy** (`tools/duelist_sunday.sh`): the approved commit runs from its own worktree. The script refuses to start while a duelist is running and gates on the full test suite. It has `--rollback` and `--stop`.

## What didn't go to plan

- **We broke our own gate.** During Sunday's sessions we tuned parameters by hand past the approved set, including one change the loop had blocked.
- **The simulator predicted high.** It forecast 0.43 duel points per duel for Duels III; we got 0.36. It had been calibrated on Saturday's duels, and its out-of-sample check was weak.
