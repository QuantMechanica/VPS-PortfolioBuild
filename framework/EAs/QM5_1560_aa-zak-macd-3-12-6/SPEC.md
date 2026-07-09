# QM5_1560_aa-zak-macd-3-12-6 - Strategy Spec

**EA ID:** QM5_1560
**Slug:** `aa-zak-macd-3-12-6`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA implements the monthly Zakamulin MACD(3,12,6) timing rule from the approved card. It is long-only and otherwise sits in cash.

On each new D1 bar the EA rebuilds completed monthly OHLC bars from completed D1 bars, because the `.DWX` tester path does not reliably expose native monthly bars. It calculates EMA(3) and EMA(12) on completed monthly closes, defines `MAC = EMA(3) - EMA(12)`, and calculates an EMA(6) signal line over that MAC series. A long entry is allowed when MAC is greater than the signal line, at least 18 completed months are available, no position already exists for the symbol and magic number, and the near-zero filter is satisfied. The near-zero filter requires absolute MAC to be at least 0.25 times monthly ATR(20), also computed from the D1-aggregated monthly bars.

The EA exits the open long when the completed-month signal turns bearish, meaning MAC is less than or equal to the signal line. Each new trade receives an initial catastrophic stop at 3.0 times ATR(20,D1). There is no take-profit and no short side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_months` | 3 | 1-12 | Short monthly EMA lookback used in the MAC line. |
| `strategy_slow_ema_months` | 12 | 4-36 | Long monthly EMA lookback used in the MAC line. |
| `strategy_signal_ema_months` | 6 | 1-18 | EMA lookback used to smooth MAC into the signal line. |
| `strategy_min_completed_months` | 18 | 18-84 | Minimum completed monthly bars required before signal evaluation. |
| `strategy_atr_period_d1` | 20 | 5-60 | D1 ATR period used for initial stop distance. |
| `strategy_atr_sl_mult` | 3.0 | 1.0-8.0 | Multiplier applied to ATR(20,D1) for the initial stop loss. |
| `strategy_use_dead_macd_filter` | true | true/false | Enables the near-zero monthly MACD amplitude filter before new entries. |
| `strategy_monthly_atr_period` | 20 | 6-60 | Monthly ATR period used by the near-zero MACD filter. |
| `strategy_min_macd_atr_ratio` | 0.25 | 0.05-1.00 | Minimum absolute MAC to monthly ATR ratio required for entry. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - original source illustration is S&P 500 trend timing; tester-only caveat remains from the approved card.
- `NDX.DWX` - liquid equity-index trend proxy for parallel validation.
- `WS30.DWX` - liquid equity-index trend proxy for parallel validation.
- `GDAXI.DWX` - non-US equity-index trend proxy for index diversity.
- `XAUUSD.DWX` - macro-sensitive metal with long-horizon trend behavior.
- `XTIUSD.DWX` - DWX crude-oil proxy used because `USOIL.DWX` is not available in the DWX matrix.
- `EURUSD.DWX` - major FX pair for instrument diversity.
- `GBPUSD.DWX` - major FX pair for instrument diversity.
- `USDJPY.DWX` - major FX pair for instrument diversity.

**Explicitly NOT for:**
- `USOIL.DWX` - excluded only because it is not present in `framework/registry/dwx_symbol_matrix.csv`; the build ports the card's oil sleeve to `XTIUSD.DWX`.
- Intraday-only or spread-only synthetic symbols - the rule depends on stable completed daily bars aggregated into monthly closes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Completed monthly bars aggregated from D1 OHLC; ATR(20) on D1 for stop distance. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with the backtest setfiles fixed to D1. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 12 signal evaluations per year; actual entries are lower because the rule is monthly long/cash and does not pyramid. |
| Typical hold time | Weeks to months. |
| Expected drawdown profile | Trend-following equity curve with occasional large giveback before monthly exit or ATR stop. |
| Regime preference | Long-horizon trend continuation with sufficient monthly MACD amplitude. |
| Win rate target (qualitative) | Medium; payoff should come from larger winning trends rather than high turnover. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog
**Pointer:** Valeriy Zakamulin, "Trend-Following with Valeriy Zakamulin: Technical Trading Rules (Part 3)", Alpha Architect, 2017-08-11, https://alphaarchitect.com/trend-following-valeriy-zakamulin-technical-trading-rules-part-3/
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1560_aa-zak-macd-3-12-6.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from approved card | Build task `cc652ca1-79eb-49bd-85f9-450566373310`; USOIL card sleeve ported to XTIUSD DWX proxy. |
