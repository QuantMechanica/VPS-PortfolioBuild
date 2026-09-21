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

## Revision 2 (2026-09-21, Fable) — after cross-vendor critique 1614737c

Critique verdict (Codex, verbatim in `../../ops/evidence/2026-09-20_velocity_book/hv1_hv3_critique_1614737c.md`):
H-V1 REVISE, H-V2 REVISE, H-V3 REJECT, plus a confirmed provenance defect (the sealed manifests bound baseline
hashes that did not match the stored files). Fable's response: build a 0-factory-hour measurement harness and
replace every prior by a measurement, then reseal.

**Harness.** `tools/strategy_farm/session_tools/hcc_m1_reader_0921.py` reads the terminals' `.hcc` M1 custom
history read-only (validated against the terminal's own JSONL export: EURUSD 94,574 / 94,575 rows identical,
GBPUSD 100,000 / 100,000). `velocity_hv_prescreen_0921.py` simulates the frozen mechanism closed-bar on M1
(shift-1 contract, zoneinfo-mapped anchors, registry commission, `.DWX` spread = 0, selection 2018-07..2022-12
/ validation 2023-25, floor / cap frozen from selection only). Output:
`../../ops/evidence/2026-09-20_velocity_book/velocity_hv_prescreen_0921.json` and the sealed
`prescreen_extract.json` in 0009 / 0010.

**Measured (A15 arm, commission-only, R at RISK_FIXED 1000):**

| hyp | symbol | period | trades | /bd | E[R] | PF | worst-yr DD | R/bd | cost_R median |
|---|---|---|---|---|---|---|---|---|---|
| H-V1 | EURUSD | SEL | 932 | 0.79 | −0.054 | 0.91 | 36.5 | −0.043 | 0.040 (+ spread GAP) |
| H-V1 | EURUSD | VAL | 626 | 0.80 | +0.022 | 1.04 | 30.9 | +0.018 | |
| H-V1 | GBPUSD | SEL | 935 | 0.80 | −0.068 | 0.89 | 50.0 | −0.054 | 0.031 (+ spread GAP) |
| H-V1 | GBPUSD | VAL | 589 | 0.75 | +0.058 | 1.11 | 19.5 | +0.044 | |
| H-V2 | XAUUSD | SEL | 682 | 0.58 | −0.050 | 0.91 | 27.8 | −0.029 | 0.018 + FTMO spread 0.087 |
| H-V2 | XAUUSD | VAL | 447 | 0.57 | +0.038 | 1.07 | 19.7 | +0.022 | 0.018 + FTMO spread 0.067 |

Floors / caps (× ATR(14,H1), p10 / p90 of SEL): EURUSD 0.86 / 1.93, GBPUSD 0.88 / 2.06, XAUUSD 0.85 / 2.19.
The A20 arms and the H-V1 breakout-only / failure-only variants are all ≤ 0 on SEL (see the artifacts).

**Outcome.** Both surviving hypotheses trip their own falsification criteria on the selection period
(E[R] < +0.08 / +0.10, PF < 1.05; H-V2 additionally the DD kill bar). Density was never the problem
(0.6-0.8 trades/bd); expectancy is, and the 60-minute pre-open ranges are too thin for the range-width stop
to carry commission (0.03-0.04R) plus spread (H-V2: measured FTMO median 0.44 USD = 0.07-0.09R). The
regime-dependent positive validation cells (EURUSD breakout 2024, GBPUSD 2023/25) are not a selection basis.
**Disposition: 0009 / 0010 resealed as draft revision 2 with RETIRE recommended; 0011 sealed retired.** A
second Codex critic round audits the prescreen simulator (anchor mapping, closed-bar contract, cost model)
before Fable retires 0009 / 0010; no card, build or factory row from any of the three.

**What carries forward.** The harness measures any session-anchored intraday hypothesis in ~30 s with zero
factory time and should precede every future Velocity card; and the lesson generalises the 41484 finding —
a one-hour pre-open range on FX majors / gold is a cost trap at RISK_FIXED sizing, so the next hypotheses
must either use wider structural ranges (multi-hour, ATR-scaled stops) or mechanisms whose expectancy per
trade is an order of magnitude above 0.05R.

## H-V4 (2026-09-21, Fable) — NY pre-open session-range breakout on USDJPY, from the family-F1 sweep

[QM-RESEARCH-2026-0012](../../../strategy-seeds/sources/QM-RESEARCH-2026-0012/source.md) — the one artifact
minted from the pre-registered family-F1 sweep (`VELOCITY_FAMILY_F1_SESSION_RANGE_SWEEP_2026-09-21.md`,
registration `60de323f25`, results `270c9a4c98`): QM5_13213 mechanics unchanged, range = the N completed
60-minute bars of a :30-aligned grid ending 15:30 server (= 08:30 America/New_York, server = NY + 7 h all
year), flat 23:00 server. Frozen arms C2 (N=2, primary) and C3 (N=3) on USDJPY, C3 on EURUSD (secondary).
Harness figures (≈ +0.02R optimistic vs the tester, control-cell calibrated): USDJPY C2 SEL n=998 / 0.85 per
bd / E[R] +0.141 / PF 1.30 / +0.120 R per bd, VAL +0.144 / 1.30 / +0.116 — about twice the incumbent Tokyo
window (A3 +0.070 / +0.054 R per bd in the same harness); EURUSD C3 +0.076 / +0.105. 9/9 USDJPY cells positive
on SEL, 8/9 survive VAL; 314 cells searched (27 SEL passes vs 17.4 null, 13 survivors vs 5.5). Sealed `draft`,
`verify` clean except ledger status; cross-vendor critic (Codex) routed. No card, build or factory row.
