# QM5_1801_chande-momentum-oscillator-h4 - Strategy Spec

**EA ID:** QM5_1801
**Slug:** chande-momentum-oscillator-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades the Chande Momentum Oscillator on H4 bars. It buys when the 20-bar CMO exits oversold from below -50 and the latest closed H4 price is above the D1 EMA(200); it sells when CMO exits overbought from above +50 and price is below the D1 EMA(200). Positions use a 2.5 x ATR(20, H4) initial stop, no trailing stop, and close when CMO crosses the zero line, touches the opposite threshold, or reaches the 25-H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cmo_period` | 20 | 5-80 | Number of H4 close-to-close changes summed for CMO. |
| `strategy_oversold_level` | -50.0 | -90 to -10 | Oversold threshold used for long recovery entries and short profit exits. |
| `strategy_overbought_level` | 50.0 | 10-90 | Overbought threshold used for short recovery entries and long profit exits. |
| `strategy_d1_ema_period` | 200 | 50-300 | D1 EMA macro-regime filter period. |
| `strategy_atr_period` | 20 | 5-80 | H4 ATR period for initial stop and spread guard. |
| `strategy_atr_sl_mult` | 2.5 | 1.0-6.0 | Initial protective stop distance as a multiple of ATR. |
| `strategy_spread_atr_mult` | 0.35 | 0.05-1.00 | Entry is blocked only when modeled spread exceeds this share of ATR. |
| `strategy_max_hold_h4_bars` | 25 | 4-80 | Maximum holding period in H4 bars before time-stop exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - Chande's canonical S&P futures example is testable on the approved S&P 500 custom symbol.
- `NDX.DWX` - US large-cap index proxy for the same bounded momentum-oscillator logic.
- `WS30.DWX` - Dow 30 index proxy included in the card's portable index basket.
- `GDAXI.DWX` - DAX 40 global index proxy listed in the card's R3 basket.
- `UK100.DWX` - FTSE 100 global index proxy listed in the card's R3 basket.
- `EURUSD.DWX` - standard FX major matching the card's currency-futures portability claim.
- `GBPUSD.DWX` - standard FX major matching the card's currency-futures portability claim.
- `USDJPY.DWX` - standard FX major matching the card's currency-futures portability claim.
- `USDCHF.DWX` - standard FX major matching the card's currency-futures portability claim.
- `USDCAD.DWX` - standard FX major matching the card's currency-futures portability claim.
- `AUDUSD.DWX` - standard FX major matching the card's currency-futures portability claim.
- `NZDUSD.DWX` - standard FX major matching the card's currency-futures portability claim.
- `XAUUSD.DWX` - gold exposure listed in the card's R3 portability section.
- `XTIUSD.DWX` - commodity exposure listed in the card's R3 portability section.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable aliases; the canonical S&P 500 custom symbol is `SP500.DWX`.
- Non-DWX broker symbols - research and backtest artifacts must keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(200) regime filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 25 H4 bars, about 4 days |
| Expected drawdown profile | Mean-reversion drawdowns controlled by fixed ATR emergency stop and time stop. |
| Regime preference | Mean-reversion entries inside the D1 macro-trend regime. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** book, journal, forum
**Pointer:** Tushar S. Chande and Stanley Kroll, *The New Technical Trader* (1994), chapter 4; ForexFactory CMO threads referenced by the approved card.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1801_chande-momentum-oscillator-h4.md`

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
| v1 | 2026-07-07 | Initial build from card | 13a06a7c-4545-4122-a36c-be3a0c6a4417 |
