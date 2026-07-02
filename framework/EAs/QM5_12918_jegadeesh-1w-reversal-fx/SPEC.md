# QM5_12918_jegadeesh-1w-reversal-fx - Strategy Spec

**EA ID:** QM5_12918
**Slug:** `jegadeesh-1w-reversal-fx`
**Source:** `afab7a6f-c3c8-51ae-a609-f376744beb8e` (see approved farm card)
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

The EA trades a weekly short-term reversal rule on seven liquid G10 USD crosses. On each Monday entry window, it computes each pair's prior Friday-to-Friday D1 close return, ranks the pairs from weakest to strongest, and buys the bottom two prior-week losers. Positions use a D1 ATR(14) times 2.0 hard stop and exit on Friday close or after the configured five-trading-day time stop.

The central-bank filter is implemented from the existing news calendar by loading week keys for G10 rate-decision events such as FOMC statements, official bank-rate events, cash-rate events, policy-rate events, and monetary-policy statements. Entry is skipped if the current weekly key appears in that rate-decision calendar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bottom_count` | 2 | 1-7 | Number of weakest prior-week pairs eligible for long entry. |
| `strategy_atr_period` | 14 | >0 | D1 ATR lookback for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple for the initial stop loss. |
| `strategy_hold_trading_days` | 5 | >0 | Maximum D1 bar age before strategy time exit. |
| `strategy_min_eligible_symbols` | 5 | 2-7 | Minimum symbols with valid Friday-to-Friday returns before ranking is trusted. |
| `strategy_monday_start_hour` | 0 | 0-23 | Broker-time start hour for Monday entries. |
| `strategy_monday_end_hour` | 4 | 0-23 | Broker-time end hour for Monday entries. |
| `strategy_friday_exit_hour` | 21 | 0-23 | Broker-time Friday hour for discretionary strategy exit. |
| `strategy_max_spread_points` | 0 | >=0 | Maximum spread in points; 0 disables the guard so .DWX zero spread does not block. |
| `strategy_skip_rate_decision_weeks` | true | true/false | Skip entries on weeks containing a G10 central-bank rate-decision event. |
| `strategy_rate_calendar_path` | `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` | file path | News calendar used only to classify central-bank decision weeks. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - G10 USD cross in the approved seven-pair FX reversal universe.
- `GBPUSD.DWX` - G10 USD cross in the approved seven-pair FX reversal universe.
- `USDJPY.DWX` - G10 USD cross in the approved seven-pair FX reversal universe.
- `AUDUSD.DWX` - G10 USD cross in the approved seven-pair FX reversal universe.
- `USDCAD.DWX` - G10 USD cross in the approved seven-pair FX reversal universe.
- `USDCHF.DWX` - G10 USD cross in the approved seven-pair FX reversal universe.
- `NZDUSD.DWX` - G10 USD cross in the approved seven-pair FX reversal universe.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the source card defines a cross-sectional G10 FX return rank, not an index, metal, or energy rule.
- FX pairs outside the listed seven - they are not part of the approved ranking universe or magic-slot allocation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 closes for Friday-to-Friday returns; D1 ATR for stops |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | 5 trading days, normally Monday entry to Friday close |
| Expected drawdown profile | Mean-reversion positions are fragile to continuation and rely on ATR hard stops plus V5 kill-switch controls. |
| Regime preference | Mean-revert / short-term reversal |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Source type:** paper
**Pointer:** https://onlinelibrary.wiley.com/doi/10.1111/j.1540-6261.1990.tb05117.x and `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12918_jegadeesh-1w-reversal-fx.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12918_jegadeesh-1w-reversal-fx.md`

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
| v1 | 2026-07-02 | Initial build from card | 4652a1bb-eaa4-4dcc-89e0-2b7127a9669f |
| v2 | 2026-07-02 | Q02 ONINIT hardening | Rate-decision calendar loader now reads the Common Files CSV as structured CSV before fallback paths; strict compile PASS at `framework/build/compile/20260702_213910/QM5_12918_jegadeesh-1w-reversal-fx.compile.log`. |
