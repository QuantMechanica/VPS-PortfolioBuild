# QM5_10763_fx-month-end-rebal - Strategy Spec

**EA ID:** QM5_10763
**Slug:** `fx-month-end-rebal`
**Source:** `not_provided_in_card_frontmatter`
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

On the last weekday business day of each month, the EA reads `SP500.DWX` D1 closes and computes month-to-date return from the prior month close to the latest closed daily bar. If the return is above +2.0%, it trades short USD across the six USD majors: buy `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX` and sell `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`. If the return is below -2.0%, it mirrors the direction and trades long USD. Entries are allowed only at the card's broker-time London-fix entry hour, and open positions close at the card's broker-time WMR fix exit hour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_symbol` | `SP500.DWX` | valid DWX symbol | D1 equity-index signal feed for month-to-date return. |
| `strategy_mtd_threshold_pct` | `2.0` | `0.0-20.0` | Absolute MTD return threshold required to trade. |
| `strategy_atr_period` | `14` | `2-100` | D1 ATR lookback for stop distance. |
| `strategy_atr_sl_mult` | `1.5` | `0.1-10.0` | Stop-loss distance as a multiple of D1 ATR. |
| `strategy_entry_broker_hour_non_us_dst` | `16` | `0-23` | Broker entry hour named by the card for non-US-DST months. |
| `strategy_entry_broker_hour_us_dst` | `15` | `0-23` | Broker entry hour named by the card for US-DST months. |
| `strategy_exit_broker_hour_non_us_dst` | `18` | `0-23` | Broker exit hour named by the card for non-US-DST months. |
| `strategy_exit_broker_hour_us_dst` | `17` | `0-23` | Broker exit hour named by the card for US-DST months. |
| `strategy_news_blackout_minutes` | `120` | `0-360` | High-impact news blackout minutes before and after events. |
| `strategy_max_spread_points` | `0.0` | `0.0-1000.0` | Optional spread cap; `0.0` disables the extra cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - direct USD major in the card's short-USD/long-USD basket.
- `GBPUSD.DWX` - direct USD major in the card's short-USD/long-USD basket.
- `AUDUSD.DWX` - direct USD major in the card's short-USD/long-USD basket.
- `USDJPY.DWX` - inverse USD major in the card's short-USD/long-USD basket.
- `USDCHF.DWX` - inverse USD major in the card's short-USD/long-USD basket.
- `USDCAD.DWX` - inverse USD major in the card's short-USD/long-USD basket.

**Explicitly NOT for:**
- `SP500.DWX` - signal feed only; the card says it is backtest-only and not a traded FX leg.
- `NDX.DWX` - fallback signal feed mentioned by the card, not the canonical G0 signal used for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `SP500.DWX` D1 closes for MTD signal; traded symbol D1 ATR for stop loss |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | Intraday from month-end entry hour to WMR-fix exit hour |
| Expected drawdown profile | Frontmatter `expected_dd_pct: 8.0`; FTMO block target <=5% daily and <=10% total |
| Regime preference | Month-end hedge-rebalancing flow after large positive or negative equity-index months |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `not_provided_in_card_frontmatter`
**Source type:** `paper`
**Pointer:** Melvin, M. & Prins, J. (2015), "Equity hedging and exchange rates at the London 4 p.m. fix", Journal of Financial Markets 22, 50-72; supporting BIS Market Committee WMR London 4pm fix report.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10763_fx-month-end-rebal.md`

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
| v1 | 2026-06-12 | Initial build from card | 2a5afa4c-5de8-4785-a3fc-f98ea933ea06 |
