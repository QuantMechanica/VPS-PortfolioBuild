# QM5_1556_aa-zak-mom12 - Strategy Spec

**EA ID:** QM5_1556
**Slug:** `aa-zak-mom12`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

This EA is a long/cash trend-following timer. On the first D1 bar of each new month, it compares the latest completed D1 close with the close 252 D1 bars earlier, which is the DWX-testable proxy for the card's 12-month momentum rule. If the momentum ratio is above 100, it opens one long position with a 3 x ATR(20,D1) stop. If the monthly momentum ratio falls to 100 or lower at a later monthly rebalance, it closes the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | 20-400 | D1 bars used as the 12-month momentum proxy. |
| `strategy_momentum_trigger` | 100.0 | 95-105 | MT5 momentum ratio threshold; above 100 means positive trailing return. |
| `strategy_atr_period_d1` | 20 | 5-100 | D1 ATR period for initial stop distance. |
| `strategy_atr_sl_mult` | 3.0 | 0.5-10.0 | ATR multiple for the hard stop. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional current-spread cap; 0 disables for zero-spread DWX tests. |
| `strategy_first_d1_bar_only` | true | true/false | Restricts rebalance checks to the first D1 bar of each month. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 timing proxy from the source, backtest-only in DWX.
- `NDX.DWX` - liquid US equity-index proxy for live-routable parallel validation.
- `WS30.DWX` - liquid US equity-index proxy for live-routable parallel validation.
- `GDAXI.DWX` - non-US equity-index timing proxy.
- `XAUUSD.DWX` - gold timing proxy from the card's cross-asset DWX port.
- `XTIUSD.DWX` - DWX crude-oil proxy replacing the card's unavailable `USOIL.DWX` alias.
- `EURUSD.DWX` - major FX timing proxy.
- `GBPUSD.DWX` - major FX timing proxy.
- `USDJPY.DWX` - major FX timing proxy.

**Explicitly NOT for:**
- `USOIL.DWX` - not present in the DWX symbol matrix; mapped to `XTIUSD.DWX`.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid for Q02 dispatch.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` plus first-D1-bar-of-month rebalance check |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 signal checks, fewer actual entries when momentum stays positive or negative |
| Typical hold time | weeks to months |
| Expected drawdown profile | trend-following whipsaws around flat 12-month momentum |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `web_blog`
**Pointer:** Valeriy Zakamulin, Alpha Architect, "Trend-Following with Valeriy Zakamulin: Anatomy of Trading Rules (Part 4)", 2017-08-13.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1556_aa-zak-mom12.md`

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
| v1 | 2026-06-27 | Initial build from card | be373b7a-ca38-4b89-882e-1a212d17e5e6 |
