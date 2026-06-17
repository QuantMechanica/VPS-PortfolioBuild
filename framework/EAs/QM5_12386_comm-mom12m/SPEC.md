# QM5_12386_comm-mom12m - Strategy Spec

**EA ID:** QM5_12386
**Slug:** comm-mom12m
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623 (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA evaluates the four approved DWX commodity CFDs on D1 bars and computes a 252-bar momentum value for each symbol. Once per calendar month, it ranks the available basket, goes long the strongest commodity and short the weakest commodity, and remains flat on the two middle-ranked commodities. Existing positions are reviewed only at the monthly rebalance; a long is closed when its symbol is no longer the strongest and a short is closed when its symbol is no longer the weakest. If fewer than four commodities have usable D1 momentum and ATR data, the EA stays flat and closes any open position for its symbol.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | 126-252 | D1 lookback for the 12-month commodity momentum rank. |
| `strategy_atr_period` | 20 | 10-40 | D1 ATR period used for emergency stop placement and tradability check. |
| `strategy_atr_stop_mult` | 3.0 | 2.0-4.0 | ATR multiple for the emergency stop. |
| `strategy_min_symbols` | 4 | 4 | Minimum tradable commodity CFDs required before new entries are allowed. |
| `strategy_spread_lookback_d1` | 60 | 20-120 | D1 spread-history window for the median-spread entry filter. |
| `strategy_spread_median_mult` | 2.0 | 1.0-4.0 | Maximum current spread as a multiple of median modeled spread. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - gold is one of the approved DWX commodity CFDs in the card's R3 basket.
- `XAGUSD.DWX` - silver is one of the approved DWX commodity CFDs in the card's R3 basket.
- `XTIUSD.DWX` - crude oil is one of the approved DWX commodity CFDs in the card's R3 basket.
- `XNGUSD.DWX` - natural gas is one of the approved DWX commodity CFDs in the card's R3 basket.

**Explicitly NOT for:**
- Non-commodity `.DWX` symbols - the rank rule is cross-sectional commodity momentum, not a general index or FX momentum sleeve.
- Commodity symbols outside `dwx_symbol_matrix.csv` - the EA only registers symbols that are available in the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About one calendar month, until the next rebalance or emergency stop. |
| Expected drawdown profile | Commodity trend shocks can produce concentrated leg losses; emergency stop is 3.0 x ATR(20). |
| Regime preference | Cross-sectional commodity momentum. |
| Win rate target (qualitative) | Medium, with gains expected from rank persistence rather than high hit rate. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public implementation / strategy catalog
**Pointer:** https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/momentum-effect-in-commodities.py
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12386_comm-mom12m.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`). Friday close is disabled by default because the card's explicit exit is monthly rebalance; forcing weekly Friday exits would change the strategy.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | a3cab52f-a9d6-4bbb-8f33-57bddefbe245 |
