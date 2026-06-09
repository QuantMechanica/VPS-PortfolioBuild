# QM5_10019_rw-fx-nfp-drift — Strategy Spec

**EA ID:** QM5_10019
**Slug:** `rw-fx-nfp-drift`
**Source:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On the first Friday of each month (the US Non-Farm Payrolls release day), the EA measures the cumulative M5 price drift on the traded symbol from 06:00 New York time to the 08:00 New York bar close. If that drift exceeds +0.20 × ATR(14,M5), a long position is entered at 08:00 NY; if the drift is below −0.20 × ATR(14,M5), a short is entered. The position is force-closed at 08:25 NY, before the 08:30 data release. The strategy follows the pre-event directional momentum rather than the post-release reaction, so no future data is used. Entry is skipped if the bid-ask spread exceeds 25% of ATR(14,M5). Initial stop loss and optional take profit are both set at 0.60 × ATR(14,M5) from the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 5–50 | ATR lookback period (M5 bars) |
| `strategy_drift_atr_mult` | 0.20 | 0.05–1.0 | Minimum pre-event drift as fraction of ATR to qualify entry |
| `strategy_sl_atr_mult` | 0.60 | 0.1–3.0 | Stop loss distance as fraction of ATR |
| `strategy_tp_atr_mult` | 0.60 | 0.1–3.0 | Take profit distance as fraction of ATR (used when strategy_use_atr_tp=true) |
| `strategy_use_atr_tp` | true | true/false | Whether to set an ATR-based take profit (false = time-only exit) |
| `strategy_max_spread_atr` | 0.25 | 0.05–1.0 | Maximum spread as fraction of ATR; wider spreads skip entry |
| `strategy_pre_start_hhmm_ny` | 600 | integer | NY time (HHMM) from which drift is measured (06:00 NY) |
| `strategy_entry_hhmm_ny` | 800 | integer | NY time (HHMM) at which entry is attempted (08:00 NY) |
| `strategy_exit_hhmm_ny` | 825 | integer | NY time (HHMM) at which force-flat occurs (08:25 NY) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary symbol from the source research; high liquidity FX pair, tight spreads during London session pre-NFP window
- `GBPUSD.DWX` — correlated USD-denominated FX pair; similar pre-NFP drift pattern expected
- `USDJPY.DWX` — USD-denominated FX pair with high liquidity; drift sign computed from own pre-event return

**Explicitly NOT for:**
- Index or commodity symbols — strategy is based on FX pre-NFP drift which is specific to USD-correlated currency pairs

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | ~25 minutes (08:00–08:25 NY) |
| Expected drawdown profile | Low single-digit % drawdown; monthly event frequency limits exposure |
| Regime preference | news-driven |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Source type:** paper / blog
**Pointer:** Robot Wealth / Kris Longmore, "Exploiting The Non-Farm Payrolls Drift", https://robotwealth.com/exploiting-the-non-farm-payrolls-drift/
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10019_rw-fx-nfp-drift.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | f655bda9-2d73-4dca-95d8-d9e94ad063fd |
