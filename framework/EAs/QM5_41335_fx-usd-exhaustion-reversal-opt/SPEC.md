# QM5_41335_fx-usd-exhaustion-reversal-opt - Strategy Spec

**EA ID:** QM5_41335
**Slug:** `fx-usd-exhaustion-reversal-opt`
**Parent EA:** `QM5_12580_fx-usd-exhaustion-reversal`
**Target symbols:** `AUDUSD.DWX`
**Source:** `OWNER-CODEX-FX-USD-EXHAUSTION-20260626`
**Author of this spec:** Claude
**Last revised:** 2026-09-03

---

## 1. Strategy Logic

This derivative preserves the approved parent mechanics for the single
`AUDUSD.DWX` carrier and adds only the six optional DL-089 closed-D1 pattern
veto inputs. With all six inputs at zero, the veto corset is neutral and the
EA reproduces the parent (`QM5_12580`) exactly.

The parent treats the USD major complex as one short-term risk factor. Once per
closed D1 bar it computes a three-day USD-basket return across the seven DWX
majors, z-scores it against the prior `strategy_basket_z_lookback` observations,
and fades an overextended USD move. When the basket z-score exceeds
`strategy_basket_z_threshold` (USD overbought) it enters short-USD; below the
negative threshold it enters long-USD. The carrier symbol must also be extended
at least `strategy_extension_atr_mult * ATR(14)` away from its `SMA(10)` in the
same exhaustion direction. Friday entries are skipped, and no new entry is taken
if an open position already holds the same USD directional exposure. Exits are by
ATR stop (`strategy_stop_atr_mult`), a `strategy_hold_bars` time stop, or an
earlier revert of the prior close back to `SMA(10)`.

The DL-089 corset evaluates a closed-D1 pattern profile once per candidate
entry: `Pattern_AllowsRequest` consults the six `opt_pp_*` predicate slots
before any order is submitted. A zero slot is inert; a non-zero slot vetoes the
corresponding buy or sell leg when its pattern predicate does not fire on the
just-closed D1 reference bar. There is no take-profit, trailing, grid,
martingale, or ML logic beyond the parent's rules.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_basket_return_bars` | 3 | 1-20 | Bars in the USD-basket return window. |
| `strategy_basket_z_lookback` | 80 | 20-250 | Lookback for the basket-return z-score. |
| `strategy_basket_z_threshold` | 1.5 | 0.5-4.0 | Absolute z-score threshold for a USD exhaustion signal. |
| `strategy_sma_period` | 10 | 3-80 | Daily SMA period for the carrier extension and revert exit. |
| `strategy_atr_period` | 14 | 5-80 | Daily ATR period for extension normalization and stop distance. |
| `strategy_extension_atr_mult` | 1.2 | 0.2-5.0 | ATR multiple the carrier must be stretched from its SMA. |
| `strategy_stop_atr_mult` | 1.5 | 0.5-6.0 | ATR multiple for the initial stop distance. |
| `strategy_hold_bars` | 4 | 1-40 | Maximum D1 bars to hold a position. |
| `opt_pp_buy1..3` | 0 | pattern id | DL-089 buy-side pattern veto slots; zero disables the slot. |
| `opt_pp_sell1..3` | 0 | pattern id | DL-089 sell-side pattern veto slots; zero disables the slot. |

---

## 3. Symbol Universe

**Designed for:**

- `AUDUSD.DWX` - declared DL-089 measurement carrier (basket slot 2; liquid major FX pair).

The parent `QM5_12580` factor-construction universe (`EURUSD`, `GBPUSD`,
`AUDUSD`, `NZDUSD`, `USDJPY`, `USDCHF`, `USDCAD` - all `.DWX`) remains its own
contract and is read only to build the USD-basket z-score; this measurement
sibling ships only the `AUDUSD.DWX` carrier required by the DL-089 census, and
the EA trades exclusively the chart symbol whose basket slot equals
`qm_magic_slot_offset` (2 for AUDUSD).

**Explicitly NOT for:**

- Any symbol outside the declared `AUDUSD.DWX` carrier - the census measures a single (EA, symbol) cell.
- Non-DWX symbols - the farm only backtests registered `.DWX` history symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Pattern reference TF | `D1`, closed shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` through the framework gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `5` (neutral baseline reproduces the parent) |
| Typical hold time | A few days (bounded by `strategy_hold_bars`). |
| Expected drawdown profile | Short-term counter-trend fades against a synchronized USD move. |
| Regime preference | Overextended, mean-reverting USD-basket conditions. |
| Win rate target (qualitative) | Medium with a bounded reward-to-risk from the ATR stop and time stop. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `OWNER-CODEX-FX-USD-EXHAUSTION-20260626`
**Source type:** `OWNER-approved Codex strategy proposal` (inherited from the approved QM5_12580 parent card)
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12580_fx-usd-exhaustion-reversal.md`
**R1-R4 verdict (Q00):** all PASS / see `docs/strategy_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 census) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | n/a | No live or pipeline verdict is authorized for this measurement sibling. |
| Full live | n/a | No live or pipeline verdict is authorized for this measurement sibling. |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-03 | DL-089 measurement sibling of QM5_12580 (path-to-25 sibling wave) | Parent mechanics byte-equivalent + six-slot pattern-permission corset. |
