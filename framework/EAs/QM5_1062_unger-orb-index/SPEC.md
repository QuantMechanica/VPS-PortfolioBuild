# QM5_1062_unger-orb-index - Strategy Spec

**EA ID:** QM5_1062
**Slug:** `unger-orb-index`
**Source:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9` (see `strategy-seeds/sources/eb97a148-0af9-5b9c-878c-25fb5dfa34f9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades an intraday opening-range breakout on index CFDs. It waits for the first 30 minutes of the cash session, records the M5-bar high and low of that window, then arms a buy stop one pip above the range and a sell stop one pip below it. The first filled side cancels the opposite pending order, the stop is placed at the opposite side of the opening range with a 2x D1 ATR cap, and any open trade is closed at the final M5 bar of the cash session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_or_window_minutes` | 30 | 15-60 in 5-minute steps | Opening-range window length in minutes. |
| `strategy_atr_period_d1` | 14 | >= 1 | D1 ATR lookback used for the stop cap and narrow-range filter. |
| `strategy_atr_cap_mult` | 2.0 | > 0 | Maximum stop distance as a multiple of D1 ATR. |
| `strategy_narrow_atr_mult` | 0.5 | >= 0 | Skip the day if opening range is smaller than this multiple of D1 ATR. |
| `strategy_entry_offset_pips` | 1 | >= 0 | Stop-entry offset beyond the opening-range high or low. |
| `strategy_spread_samples` | 20 | 1-256 | Rolling spread samples used for the 2x median-spread entry filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DAX 40 custom symbol available in the DWX matrix; used as the available port for the card's GER40/DAX primary market.
- `NDX.DWX` - Nasdaq 100 index CFD, matching the card's secondary US index breakout market.
- `WS30.DWX` - Dow 30 index CFD, matching the card's secondary US index breakout market.

**Explicitly NOT for:**
- `GER40.DWX` - named by the card, but not present in `framework/registry/dwx_symbol_matrix.csv`.
- `SP500.DWX` - not part of this card's stated universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_D1` ATR(14) for stop cap and narrow-range filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | Intraday, from post-opening-range trigger until stop or cash-session close |
| Expected drawdown profile | Breakout sleeve with bounded per-trade stop at opening range or 2x D1 ATR |
| Regime preference | Volatility-expansion breakout during liquid cash sessions |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9`
**Source type:** `book / video`
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1062_unger-orb-index.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1062_unger-orb-index.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-13 | Initial build from card | aa191610-e091-4a0d-8cd7-57d8737a29ca |
