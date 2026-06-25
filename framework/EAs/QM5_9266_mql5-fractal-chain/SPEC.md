# QM5_9266_mql5-fractal-chain - Strategy Spec

**EA ID:** QM5_9266
**Slug:** mql5-fractal-chain
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades consecutive confirmed Bill Williams fractal chains on H4 bars. A long entry requires the two most recent confirmed fractal events to be bullish fractal lows, no bearish fractal between them, spacing no wider than 0.75 x ATR(14), and the last closed bar above EMA(50). A short entry mirrors the rule with two bearish fractal highs and close below EMA(50). Exits occur on an opposite confirmed fractal plus EMA break, a closed-bar break through the stored chain level, SL/TP, or a 24-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period for chain spacing and stop buffer. |
| strategy_ema_period | 50 | 2-300 | EMA trend filter period. |
| strategy_chain_atr_mult | 0.75 | 0.10-5.00 | Maximum distance between the two fractals as an ATR multiple. |
| strategy_stop_atr_mult | 0.50 | 0.10-5.00 | ATR buffer beyond the fractal chain for initial stop placement. |
| strategy_take_rr | 2.20 | 0.50-10.00 | Initial take profit in R multiples. |
| strategy_max_hold_bars | 24 | 1-200 | Failsafe time exit in H4 bars. |
| strategy_fractal_lookback | 80 | 5-300 | Maximum confirmed bars scanned to find the two most recent fractal events. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed major FX pair with DWX H4 OHLC, EMA, ATR, and fractal data.
- GBPJPY.DWX - Card-listed JPY cross with DWX H4 OHLC, EMA, ATR, and fractal data.
- GDAXI.DWX - DWX DAX custom symbol used as the available matrix equivalent for card-listed GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to GDAXI.DWX for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Up to 24 H4 bars |
| Expected drawdown profile | Trend-following support/resistance chain strategy with ATR-defined loss per trade. |
| Regime preference | trend / support-resistance continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 56): Bill Williams Fractals", 2025-03-04, https://www.mql5.com/en/articles/17334
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9266_mql5-fractal-chain.md`

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
| v1 | 2026-06-26 | Initial build from card | 31b20532-834a-4887-a8b1-db2d41a19a1f |
