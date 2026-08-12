# QM5_12926_renko-color-streak-h1 — Strategy Spec

**EA ID:** QM5_12926
**Slug:** `renko-color-streak-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-12

---

## 1. Strategy Logic

Builds synthetic Renko bricks from tick price (brick size = ATR(14, D1) x 0.1,
re-cached once per H1 open and static for that bar). LONG when the just-closed
brick is green and it is the 4th consecutive green brick (N=3 prior + 1
confirming) AND the brick's close is above the Renko-stream EMA(50); SHORT is
the mirror on a 4-brick red streak below the EMA. One position per symbol.
Exit is primary opposite-color-brick close, backed by a fixed RR=2.0
take-profit and an optional trailing stop at 2x brick-size from the running
best brick close since entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_brick_atr_period` | 14 | 5-50 | D1 ATR period used to size the Renko brick |
| `strategy_brick_atr_mult` | 0.1 | 0.05-0.3 | Brick size = D1 ATR(period) x this multiplier |
| `strategy_min_streak` | 3 | 2-5 | N prior same-color bricks required before the confirming brick (P3 sweep) |
| `strategy_use_ema_bias` | true | bool | Require the confirming brick's close to be on the trend side of the Renko-stream EMA |
| `strategy_ema_period` | 50 | 10-200 | EMA period fed by brick closes (not chart bars) |
| `strategy_sl_brick_mult` | 2.0 | 1.5-3.0 | Initial SL = (1 + mult) x brick-size beyond the entry brick's close (= 2x brick below the entry brick's low/high per the card) |
| `strategy_tp_rr` | 2.0 | 1.5-3.0 | Fixed take-profit as a multiple of the initial SL distance |
| `strategy_trailing_enabled` | true | bool | Enable the 2x-brick trailing stop (tertiary exit) |
| `strategy_trailing_brick_mult` | 2.0 | 1.0-3.0 | Trailing distance in brick-size multiples from the running best brick close |
| `strategy_spread_cap_points` | 25 | 10-100 | Raw-point spread guard; inert on `.DWX` (0 modeled spread) in the tester |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- `EURUSD.DWX` — card R3 primary FX-major Renko basket entry, clean Renko regime
- `GBPUSD.DWX` — card R3 basket member, clean Renko regime
- `USDJPY.DWX` — card R3 basket member, clean Renko regime
- `XAUUSD.DWX` — card R3 basket member, gold trends cleanly in Renko discretization
- `AUDUSD.DWX` — card R3 basket member, clean Renko regime

**Explicitly NOT for:**
- Index/CFD symbols (`NDX.DWX`, `WS30.DWX`, etc.) — card R3 names only the FX-major + gold basket; not evaluated for this card

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` (chart/tester timeframe; entry logic is brick-driven, not bar-driven — see §1) |
| Multi-timeframe refs | `D1` ATR(14) for brick sizing, cached once per H1 open |
| Bar gating | Brick-close event (`RenkoEngine_UpdateOnTick`), not `QM_IsNewBar()` — see build `open_questions` |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` (card frontmatter `expected_trades_per_year_per_symbol`) |
| Typical hold time | `hours to a few days (few-bricks-per-trade, opposite-brick or RR exit)` |
| Expected drawdown profile | `moderate — fixed 2x-brick stop, RR=2.0 target, trend-following whipsaw risk in choppy regimes` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/471462` (ForexFactory Trading Systems — RenkoStreet master thread)
**R1–R4 verdict (Q00):** all PASS — R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_12926_renko-color-streak-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-12 | Initial build from card | 9d59d205-5ae3-4d14-b8cd-c476da66cb81 |
