# QM5_9298_mql5-bears-div — Strategy Spec

**EA ID:** QM5_9298
**Slug:** `mql5-bears-div`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each new H1 bar the EA checks for a bullish divergence in Bear's Power: the current bar's low is below the previous bar's low (lower low in price) but Bear's Power (Low minus EMA(close,13)) is higher than on the previous bar (rising oscillator). Only entries where the signal bar's close is above EMA(13) are accepted, providing a basic trend filter. A long market order is placed with the stop loss set at the signal bar's low minus 0.5 × ATR(14). The position is closed when Bear's Power declines for two consecutive closed bars (momentum fade) or when a bar closes back below the signal bar's low (failed setup).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bp_period` | 13 | 5–50 | EMA period for Bear's Power calculation (Low minus EMA(close, period)) |
| `strategy_sl_atr_period` | 14 | 5–30 | ATR period used to set the stop-loss distance below signal low |
| `strategy_sl_atr_mult` | 0.5 | 0.1–3.0 | Multiplier: stop = signal_low − mult × ATR |
| `strategy_ema_filter_period` | 13 | 5–200 | EMA period for trend filter; entry allowed only when close > EMA |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; clear H1 structure well-suited to oscillator divergence
- `GBPUSD.DWX` — liquid major FX pair with similar H1 characteristics
- `XAUUSD.DWX` — gold; strong trending and reversal behaviour; Bears Power divergences frequent
- `GDAXI.DWX` — DAX 40 index; card specified GER40 (ported to canonical GDAXI.DWX, documented in open_questions)

**Explicitly NOT for:**
- Any symbol not in the DWX symbol matrix (e.g. SPX500.DWX, GER40.DWX non-canonical names)

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~45 |
| Typical hold time | 2–10 hours (H1 bars) |
| Expected drawdown profile | Moderate; stop set 0.5 ATR below signal low |
| Regime preference | mean-revert / reversal at lower lows |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by Bear's Power", MQL5 Articles, 2022-08-10, https://www.mql5.com/en/articles/11297
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9298_mql5-bears-div.md`

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
| v1 | 2026-06-10 | Initial build from card | 7fbf2f26-9443-4841-8101-b65bb9e69f4d |
