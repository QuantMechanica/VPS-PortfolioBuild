# QM5_11214_ft-clucmay — Strategy Spec

**EA ID:** QM5_11214
**Slug:** `ft-clucmay`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Author of this spec:** Codex
**Last revised:** 2026-08-25

---

## 1. Strategy Logic

On each closed M5 bar, the EA buys when the close is below EMA(50), below
`0.985 ×` the lower Bollinger Band(20, 2) computed from typical price, and its
tick volume is less than 20 times the mean of the preceding 30 bars. The order
uses an ATR(14) stop at 1.5 ATR, limited so it is never wider than 5% of entry,
and a server-side 1% profit target. It also closes after a closed bar recovers
above the Bollinger middle band; the framework independently enforces the news
pause and Friday close.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_bb_period` | 20 | 20–40 | Bollinger lookback from the approved sweep. |
| `strategy_bb_deviation` | 2.0 | fixed | Bollinger standard-deviation width. |
| `strategy_bb_lower_mult` | 0.985 | 0.975–0.995 | Extra discount applied to the lower band. |
| `strategy_ema_period` | 50 | 50–150 | Close-price EMA used by the setup filter. |
| `strategy_volume_mean_bars` | 30 | fixed | Prior closed bars in the tick-volume baseline. |
| `strategy_volume_mean_mult` | 20.0 | 5–20 | Maximum signal-bar volume as a multiple of its baseline. |
| `strategy_atr_period` | 14 | fixed | ATR lookback for the initial stop. |
| `strategy_atr_sl_mult` | 1.5 | fixed | ATR multiple for the initial stop distance. |
| `strategy_max_stop_pct` | 0.05 | fixed | Source stop cap as a fraction of entry price. |
| `strategy_roi_target` | 0.01 | 0.006–0.015 | Immediate ROI target as a fraction of entry price. |
| `strategy_max_spread_stop_frac` | 0.06 | fixed | Largest positive spread as a share of planned stop distance. |

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major-FX baseline, active at magic slot 0.
- `GBPUSD.DWX` — liquid major-FX diversification, active at magic slot 1.
- `USDJPY.DWX` — non-European major-FX diversification, active at magic slot 2.
- `XAUUSD.DWX` — liquid metal comparison sleeve from the approved R3 basket, active at magic slot 3.

**Explicitly NOT for:**

- Other `.DWX` symbols — they are outside this card's approved R3 basket and require separate evidence.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 100; card range 70–150 |
| Typical hold time | intraday, until middle-band recovery, 1% target, stop, or Friday close |
| Expected drawdown profile | high-risk clustered losses when downside extensions continue rather than revert |
| Regime preference | liquid mean reversion after an unusually deep downside extension |
| Win rate target (qualitative) | not claimed by the source; downstream gates measure it |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** public GitHub strategy implementation
**Pointer:** Gert Wohlgemuth, `ClucMay72018.py`, `freqtrade-strategies`, commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`, path `user_data/strategies/berlinguyinca/ClucMay72018.py`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11214_ft-clucmay.md`.

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
| v1 | 2026-08-25 | Initial build from card | Build task `0252ecca-3c52-44e6-93ff-392bb0f97f2f` |
