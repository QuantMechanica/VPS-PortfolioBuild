# Velocity hypotheses H-V1..H-V3 — index (2026-09-21)

**Task:** `31012467-dde7-4b74-995c-def2241b28c0` (routed `fable-orchestrator-2026-09-21-velocity`,
supersedes `c46771ec-e516-461c-83f5-932a442f7d71`). **Author:** Claude. **Critic (separately
routed, not run by this task):** Codex.

Three new intraday hypotheses grounded in the frozen 2026-09-20 velocity evidence
(`docs/ops/evidence/2026-09-20_velocity_book/README.md`,
`docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md`). Per the task contract, each mechanism is paired
with its OWN native session structure rather than a transplanted window — directly
responding to the README.md section 2c lesson that the Balke 03:00-06:00 GMT+3 window is
USDJPY-specific and does not transfer to other FX majors (lineage QM5_41484 fan-out,
RETIRED 2026-09-20).

**No EA has been built and no rows have been enqueued from this task.** These are sealed
`QM-RESEARCH` artifacts only, per `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`.

Note on IDs: the task title anticipated `QM-RESEARCH-2026-0007..0009`, but the shared
ledger (`D:/QM/reports/state/research_source_ledger.jsonl`) already had `0007`/`0008`
allocated to unrelated `TAIL_RISK` Family-A hypotheses (Kimi, 2026-09-16, predating this
task's routing). `research_source.py mint` correctly allocated the next free ids:
**0009, 0010, 0011**.

| id | codename | symbols | native session anchor | trigger |
|---|---|---|---|---|
| [QM-RESEARCH-2026-0009](../../../strategy-seeds/sources/QM-RESEARCH-2026-0009/source.md) | H-V1 | EURUSD, GBPUSD | 07:00-08:00 UTC (London cash open) | opening-range breakout + failed-breakout/reversal |
| [QM-RESEARCH-2026-0010](../../../strategy-seeds/sources/QM-RESEARCH-2026-0010/source.md) | H-V2 | XAUUSD | 13:30-14:30 UTC (US cash/COMEX-linked open) | volatility-expansion breakout of the pre-open reference range |
| [QM-RESEARCH-2026-0011](../../../strategy-seeds/sources/QM-RESEARCH-2026-0011/source.md) | H-V3 | AUDJPY (21:00-22:00 UTC), GBPJPY (06:00-07:00 UTC) | each pair's own Asia-session liquidity handoff (not USDJPY's Tokyo-AM window) | session-open-gap fade (mean reversion — explicitly NOT the Balke stop-bracket breakout trigger) |

All three artifacts are sealed (`sha256(source.md)` recomputed, manifest hashes verified)
at ledger `status: draft`, `research_trial_count: 1` each (a directed hypothesis, not a
Kimi search-ledger product). `research_source.py verify --id <id>` reports exactly one
finding per artifact — `LEDGER_STATUS_BAD:draft` — which is the **expected and correct**
state: none has yet received the mandatory non-self cross-vendor critic (Codex, routed
separately per the task payload's `critic_vendor: codex`), so none is admissible for card
intake. This task does not attempt to satisfy that gate; it stops at a sealed, critic-ready
draft, per the acceptance criteria ("no EA built, no rows enqueued").

Every quantitative claim in the three `research.json` files cites a deterministic
`baseline_extract.json` (one per artifact, same directory), produced by
`tools/strategy_farm/session_tools/velocity_hv1_hv3_baseline_extract_20260921.py` — a
re-runnable script that reads the real `q02_velocity_screen.json` / `README.md` /
`FTMO_PORTFOLIO_GAP_CURRENT.md` files from the canonical checkout and emits only figures
copied verbatim or trivially aggregated from them (min/max/count), each accompanied by the
source file's own sha256. No figure in any of the three artifacts is asserted from model
memory alone; forward-looking priors (density, E[R]) are explicitly labelled as structural
assumptions to be falsified at Q02, not as measurements.

Each artifact's `source.md` contains, in full: the mechanical spec (bounded params, no ML),
density arithmetic with a `.DWX` pilot fire-count estimate over the evidence window's 1175
business days, a cost-to-target check (qualitative — no commission/spread figure is invented
per Hard Rule), explicit Q02/Q04 falsification criteria including an out-of-sample holdout
check (per the `census_frontier_holdout.json` lesson that in-sample winners in this EA
family do not generalize) and a joint-tail/correlation check against existing roster
sleeves, and a "Distinct from" paragraph against QM5_13213/10706/10700/41475/41476/41477/41484.
