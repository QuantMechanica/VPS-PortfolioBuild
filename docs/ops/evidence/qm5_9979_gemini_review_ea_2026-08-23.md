# Claude review_ea — QM5_9979 (Gemini-built)

**Router task ID:** `84776da8-b769-4828-8fed-ceb8f9c5b101`
**Reviewer:** Claude (headless orchestration cycle)
**Date:** 2026-08-23
**Source build artifact:** `artifacts/qm5_9979_build_result.json`,
`docs/ops/evidence/build_ea_qm5_9979_20260823.md` (Gemini's own build note)

## Scope

`review_ea` task routed to claude with `reason: codex_review_required_for_gemini_code`
— per CLAUDE.md hard rules, Gemini-authored code requires mandatory Codex review
before acceptance. This is the Claude-side correctness pass; it does **not**
substitute for that Codex review. Task stays in `REVIEW`, not advanced to
`APPROVED`/`PIPELINE`.

## QM5_9979 — Bandy Index Gap-Fade Mean-Reversion

- `mq5` SHA256 verified locally: `4d873d6705b19bbf7621ab2a4dba3cd35d5e27cc5f812b315e03bd7de0c4360c`
  — matches build artifact. `ex5` SHA256 `ae0354af71cc647b56e3b482ccba4bf57f9390ec76c1bfd0dcff5421a0490fbf`.
- Compile log (`framework/build/compile/20260823_084541/...compile.log`):
  `0 errors, 0 warnings`.
- Magic base `99790000` = `9979 * 10000 + 0` — correct; `magic_numbers.csv:17292-17304`
  covers all 13 registered symbols (GDAXI/NDX/SP500/UK100/WS30/XAUUSD/EURUSD/
  GBPUSD/USDJPY/USDCHF/AUDUSD/USDCAD/NZDUSD.DWX, offsets 0-12), all `active`.
- `validate_build_guardrails.py` re-run locally against the EA dir: `PASS`,
  14 files checked, 0 findings, `max_news_stale_hours=336` (at the hard ceiling,
  not exceeding it).
- Provenance check: SPEC.md/mq5 header cite
  `artifacts/cards_approved/QM5_9979_bandy-index-gap-fade-mr-index.md`, which
  does **not** exist under the git checkout (`C:/QM/repo/artifacts/cards_approved/`).
  **Correction (see the 11496/11516/11517 review batch,
  `docs/ops/evidence/2026-08-23_review_ea_11496_11516_11517.md`): the approved
  card actually exists at the canonical runtime location
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9979_bandy-index-gap-fade-mr-index.md`**
  — I had not checked that path when this doc was first written and called it
  "missing" on a git-checkout-only search; it is not missing, just not
  git-tracked. Independently, provenance was also traced through
  `D:/QM/strategy_farm/artifacts/source_notes/9ef19e06-5ca6-5b35-aa06-b8187aa0e016.md`
  (my own prior research note, Batch 12 addendum, 2026-05-19): QM5_9979 was
  G0-approved as "`bandy-index-gap-fade-mr-index` — direct mirror of QM5_9965
  (gap-and-go): same gap-significance threshold + regime gate, opposite
  commitment direction, mean-reversion trade targeting the gap-fill." This
  matches the implemented logic (see below). No registry-hygiene action needed
  after this correction.
- Entry logic (`Strategy_EntrySignal`): `gap = bar1.open - bar2.close` (D1,
  shift1 vs shift2, no look-ahead — ATR/SMA also read at shift consistent with
  a closed gap bar); significance `|gap| >= 0.5*ATR(14)`; long when
  `gap<0 && close1>open1 && close1>SMA(200)`, short mirrored — matches the
  documented "gap-fade" mirror-of-gap-and-go mechanic (fade a down-gap only
  when the gap bar itself closed bullish and price is above the long-term
  regime filter, and vice versa). 2-bar anti-cluster via `iBarShift` on the
  last same-direction entry bar time — correctly gates re-entry.
- Exit (`Strategy_ExitSignal`): gap-fill target (`high>=close_prev` long /
  `low<=close_prev` short) OR 5-D1-bar time stop — matches SPEC. Catastrophic
  stop `1.5*ATR(14)` via `QM_StopATR` at entry, no TP (gap-fill/time-stop is
  the exit) — consistent, no inline stop math.
- `req.symbol_slot = qm_magic_slot_offset` wired correctly (2026-08-16
  host-slot-magic conflation class checked — not present here).
- All 6 `strategy_*` inputs (`strategy_gap_atr_mult`, `strategy_regime_sma_period`,
  `strategy_atr_period`, `strategy_atr_stop_mult`, `strategy_time_stop_days`,
  `strategy_anti_cluster_bars`) are read at a use site — no unwired inputs
  (2026-08-10 unwired-input check).
- News: standard framework wiring, `qm_news_temporal=PRE30_POST30`,
  `qm_news_compliance=DXZ`, `qm_news_stale_max_hours=336` (ceiling, not
  exceeded) — not disabled/bypassed like some event-driven EAs; `OnTick`
  correctly gates on `QM_NewsAllowsTrade2` before the entry path.
- `QM_FrameworkTrackOpenPositionMae()` is the first statement in `OnTick`,
  `ZeroMemory(req)` precedes `Strategy_EntrySignal` — both match the current
  build-hardening contract used by recently-built sibling EAs.
- Backtest set files (13 generated, one sampled: EURUSD.DWX): `RISK_FIXED=1000`,
  `RISK_PERCENT=0` — correct per hard rule.
- No ML, no grid/martingale, one-position-per-magic (`QM_TM_OpenPositionCount`
  guard), D1 swing horizon, ATR-based catastrophic stop — in scope for the
  Edge Lab charter.
- Minor, non-blocking observation: `QM_TM_OpenPosition`/`QM_TM_ClosePosition`
  return values are not captured/logged (order-result diagnostics). No current
  build guardrail requires this; it is the same pre-hardening pattern recently
  hardened on QM5_13128's fork (commit `4112f5b07`) but there is no fail-closed
  gate for it today, so this is not a defect against current criteria — flagging
  only as a candidate for a future uniform hardening pass, not a blocker.

**Verdict: no correctness defects found; one pre-existing registry-hygiene gap
noted (missing card file, traced via source notes, not build-introduced).**
Faithful implementation of the G0-approved gap-fade mirror mechanic.

## Disposition

Task moves to `REVIEW` with a PASS-leaning verdict from the Claude side. Per
hard rules this does not authorize `APPROVED`/`PIPELINE` — Codex review remains
mandatory before this EA advances. No close-review call was made; task stays
in `REVIEW` for Codex to pick up.
