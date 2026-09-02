# QM5_41301_tsm-meanret-opt - Strategy Spec

**EA ID:** QM5_41301
**Slug:** tsm-meanret-opt
**Source:** d3c009d7-a8d6-5251-b572-4777b207c2b9
**Parent EA:** QM5_10145_tsm-meanret
**Parent card:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_10145_tsm-meanret.md
**Author of this spec:** Claude CEO
**Last revised:** 2026-09-02

---

## 1. Strategy Logic

On each completed D1 bar, the EA compares the latest completed close with the
close `N` completed bars earlier and computes the average log return over that
window. It opens or stays long when that rolling mean return is positive beyond
the configured threshold. In optional long/short mode, it opens or stays short
when the rolling mean return is non-positive beyond the configured threshold.
Long-only positions exit to flat when the rolling mean return is less than or
equal to zero; long/short positions reverse when the sign changes. Every entry
uses an emergency stop at `atr_stop_mult * ATR(14)` by default.

The derivative adds six optional closed-D1 pattern veto slots: three for buy
entries and three for sell entries. Each slot holds a `QM_PatternPermission`
predicate ID evaluated on the closed reference bar (`PERIOD_D1`, shift 1)
immediately before order placement; a BUY request is checked against the
buy-side predicates and a SELL request against the sell-side predicates,
symmetrically. Zero disables a slot, so with the shipped defaults the Q02
control is mechanically identical to the approved parent. An enabled predicate
may suppress an entry on its own side; it cannot create a trade or alter exits,
sizing, the ATR stop, news behavior, or Friday-close behavior.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_n` | 15 | 3, 5, 15, 30, 90 | Number of completed D1 bars used for the rolling mean return. |
| `strategy_shorts_enabled` | false | false, true | Enables short entries and long/short reversals when rolling mean return is non-positive. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for the emergency stop. |
| `strategy_atr_stop_mult` | 3.0 | 2.5, 3.0, 4.0 | ATR multiple for the emergency stop distance. |
| `strategy_min_abs_mean_return` | 0.0 | 0.0, 0.00025, 0.0005 | Minimum absolute rolling mean return required for new entries. |
| `opt_pp_buy1..3` | 0 | pattern IDs | Optional buy-side pattern veto predicate IDs (0 disables the slot). |
| `opt_pp_sell1..3` | 0 | pattern IDs | Optional sell-side pattern veto predicate IDs (0 disables the slot). |

The Q02 baseline keeps all six pattern inputs at zero. Pattern discovery is a
later governed measurement and is not part of this build.

---

## 3. Symbol Universe

| Slot | Symbol | Magic | Rationale |
|---:|---|---:|---|
| 0 | XAUUSD.DWX | 413010000 | close-only metals CFD measurement carrier for the DL-089 pattern census |

The EA rejects every other timeframe (`_Period != PERIOD_D1` blocks trading).
This measurement carrier isolates the pattern-veto census on a single
close-only symbol; portfolio and diversification claims remain later Q09/Q11
assertions, not build assumptions.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Pattern reference | `PERIOD_D1`, closed shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

Range and rolling-return geometry use completed bars only. The pattern-census
reference bar time is refreshed once per new D1 bar.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 (inherited parent prior; unchanged at zero-pattern defaults) |
| Typical hold time | days |
| Expected drawdown profile | Trend-state exits plus ATR emergency stops; losses cluster during choppy sign changes. |
| Regime preference | trend-following / time-series momentum |
| Win rate target (qualitative) | medium |

The pattern veto surface only removes entries; with the shipped zero defaults
the behavior is identical to the parent. This carrier inherits no new
profitability claim.

---

## 6. Source Citation

Derivative source ID: d3c009d7-a8d6-5251-b572-4777b207c2b9 (inherited from
parent `QM5_10145_tsm-meanret`).

**Source type:** blog / tutorial
**Pointer:** https://raposa.trade/blog/how-to-build-your-first-momentum-trading-strategy-in-python/
**R1-R4 verdict (Q00):** all PASS / see
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_10145_tsm-meanret.md`.

Derivative approval and DL-089 instrumentation authority are recorded in this
EA's `docs/strategy_card.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02 - Q10) | RISK_FIXED | USD 1,000 per trade |
| Live | not authorized | n/a |

The backtest preset explicitly fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. It retains the parent's two-axis DXZ news gate
(`qm_news_temporal=3`, `qm_news_compliance=1`) and Friday-close behavior. No
live preset, deployment artifact, or portfolio-gate change is created.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Approved DL-089 derivative V5 build | CEO order 2026-09-02, pattern instrumentation sibling of QM5_10145 |
