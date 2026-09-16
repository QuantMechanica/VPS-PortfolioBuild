# QM5_41478_grimes-complex-pb-opt — Strategy Spec

**EA ID:** QM5_41478
**Slug:** `grimes-complex-pb-opt`
**Parent EA:** `QM5_10911_grimes-complex-pb`
**Target symbols:** `GDAXI.DWX`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (Adam H. Grimes complex-consolidation article; inherited from the approved parent card)
**Seal authority:** `OWNER-DEC-Q12-SIBLING-41478-20260916` (scope: QM5_41478 only)
**Author of this spec:** Kimi (interim, under OWNER delegation)
**Last revised:** 2026-09-16

---

## 0. Governance Classification (binding)

QM5_41478 is an **optimization/measurement sibling** of QM5_10911 — **NOT a new
edge, NOT independent diversification, NOT a new strategy family.** It exists
solely to run the DL-089 pattern-permission measurement census against the
approved parent's GDAXI book. The parent (10911), its verdicts and its evidence
are preserved unchanged. No live or pipeline verdict is authorized from this
sibling by itself; the DL-089 census it feeds is measurement only.

## 1. Strategy Logic

This derivative preserves the approved parent mechanics exactly and adds only the
six optional DL-089 closed-D1 pattern veto inputs. With all six inputs at zero,
the veto corset is neutral and behaviour is identical to the parent.

Parent (QM5_10911) logic, unchanged: H1 trend continuations after a complex
pullback. A long requires a rising EMA(50), price above EMA(50), a recent thrust
to a 20-bar high with range at least ATR(14), a first pullback of at least 0.8
ATR that remains above EMA(50), a failed first upside resumption, and then a
close above the high of that failed resumption leg. Shorts mirror the same
sequence below a falling EMA(50). Exits use a 1.5R target, a close through
EMA(20) against the trade, or a 30-bar time stop.

Sibling addition: the six closed-D1 pattern-veto inputs (`opt_pp_buy1..3`,
`opt_pp_sell1..3`) are wired through `QM_PatternProfile` and gate the sole order
consumer via `Pattern_AllowsRequest(req)` on the entry path
(`if(Strategy_EntrySignal(req) && Pattern_AllowsRequest(req))`). Zero disables a
slot. The pattern block is the verified byte-reused identity-free surface shared
with the approved Amendment C siblings (template: QM5_13013 → QM5_41321).

## 2. Parameters

Strategy-specific inputs are inherited unchanged from the parent (see parent
`SPEC.md` §2): `strategy_ema_trend_period`, `strategy_ema_exit_period`,
`strategy_atr_period`, `strategy_thrust_lookback_bars`,
`strategy_thrust_prior_high_bars`, `strategy_thrust_range_atr_mult`,
`strategy_pullback_atr_mult`, `strategy_failure_window_bars`,
`strategy_min_thrust_to_entry_bars`, `strategy_stop_buffer_atr_mult`,
`strategy_target_r_mult`, `strategy_max_hold_bars`.

Sibling-added measurement inputs (all default 0 = disabled):

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `opt_pp_buy1` | 0 | 0+ | DL-089 closed-D1 pattern permission slot (buy side, slot 1). 0 disables. |
| `opt_pp_buy2` | 0 | 0+ | DL-089 closed-D1 pattern permission slot (buy side, slot 2). 0 disables. |
| `opt_pp_buy3` | 0 | 0+ | DL-089 closed-D1 pattern permission slot (buy side, slot 3). 0 disables. |
| `opt_pp_sell1` | 0 | 0+ | DL-089 closed-D1 pattern permission slot (sell side, slot 1). 0 disables. |
| `opt_pp_sell2` | 0 | 0+ | DL-089 closed-D1 pattern permission slot (sell side, slot 2). 0 disables. |
| `opt_pp_sell3` | 0 | 0+ | DL-089 closed-D1 pattern permission slot (sell side, slot 3). 0 disables. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here.

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — DWX DAX custom symbol (matrix equivalent for the parent's
  card-listed `GER40.DWX`). Sole target of this measurement sibling; the
  DL-089 Q12 frontier pair under measurement is `QM5_10911`/`GDAXI.DWX`.

**Explicitly NOT for (sibling scope):**
- `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX` — the parent supports these; the
  sibling restricts to GDAXI.DWX to isolate the DL-089 measurement on the Q12
  frontier pair. Not a new edge and not a diversification claim.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` (DL-089 closed-D1 pattern permission predicates) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` (inherited from parent card; measurement sibling runs the neutral baseline) |
| Typical hold time | up to 30 H1 bars |
| Expected drawdown profile | identical to parent when `opt_pp_*` are all zero |
| Regime preference | trend continuation after complex pullback |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** `blog` (inherited from parent QM5_10911)
**Pointer:** parent `SPEC.md` §6; Adam H. Grimes complex-consolidation article and Fundamental Trading Patterns supplemental reference
**R1–R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41478_grimes-complex-pb-opt.md`
**Sibling transform template:** verified 7-hunk QM5_13013 → QM5_41321 diff; derivation evidence `docs/ops/evidence/2026-09-16_opt_sibling_10911/`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10 / DL-089 census) | RISK_FIXED | $1,000 per trade (RISK_PERCENT=0) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). Backtests require `RISK_FIXED > 0`,
`RISK_PERCENT = 0`, and `qm_news_stale_max_hours <= 336`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-16 | OWNER-sealed measurement sibling of QM5_10911 for DL-089 GDAXI census | OWNER-DEC-Q12-SIBLING-41478-20260916; staged evidence `2026-09-16_opt_sibling_10911/` |
