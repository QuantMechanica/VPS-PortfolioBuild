# QM5_9290_mql5-dem-env-fakeout — Strategy Spec

**EA ID:** QM5_9290
**Slug:** `mql5-dem-env-fakeout`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades a 3-bar mean-reversion fakeout against Envelope channel bands on H4,
confirmed by a DeMarker extreme. Long signal: the bar two periods ago was inside the
channel, the previous bar closed at or below the lower Envelope (fake break down), and
the current closed bar is back above the lower Envelope while DeMarker is at or below
0.30 (oversold). Short signal is symmetric: fake break above the upper Envelope,
DeMarker at or above 0.70 (overbought). Stop is placed at the breached Envelope band
minus/plus 0.5 × ATR(14). The position is closed by the opposite fakeout signal or
after 12 H4 bars, whichever comes first. An additional filter suppresses entries when
the Envelope width has expanded more than 25% over the prior 3 bars (strong-trend guard).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_dem_period` | 13 | 5–50 | DeMarker oscillator period |
| `strategy_env_period` | 14 | 5–50 | Envelopes moving-average period |
| `strategy_env_deviation` | 0.1 | 0.05–1.0 | Envelopes band deviation (% of price) |
| `strategy_env_method` | MODE_SMA | MODE_SMA/EMA | Envelopes MA method |
| `strategy_atr_period` | 14 | 5–50 | ATR period used for stop distance |
| `strategy_atr_sl_mult` | 0.5 | 0.1–3.0 | ATR multiplier for stop offset beyond band |
| `strategy_dem_long_thresh` | 0.30 | 0.10–0.45 | DeMarker upper bound for long entry |
| `strategy_dem_short_thresh` | 0.70 | 0.55–0.90 | DeMarker lower bound for short entry |
| `strategy_max_hold_bars` | 12 | 4–48 | Max H4 bars before time-exit |
| `strategy_env_expand_max` | 0.25 | 0.10–1.0 | Max Envelope width expansion ratio (entry filter) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair; H4 Envelopes produce reliable mean-reversion bands with sufficient liquidity
- `GBPUSD.DWX` — primary test symbol in source article; H4 fakeout pattern explicit in reference
- `USDJPY.DWX` — major FX pair; mean-reversion dynamics analogous to EURUSD/GBPUSD on H4

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX` — equity indices have asymmetric drift; Envelope fakeout on H4 is not tested here
- `XAUUSD.DWX` — different volatility regime; Envelope deviation tuning not calibrated

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | 1–12 H4 bars (4–48 hours) |
| Expected drawdown profile | Medium-revert; moderate DD from single adverse trend move |
| Regime preference | mean-revert / false-breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 63): Using Patterns of DeMarker and Envelope Channels", MQL5 Articles, 2025-05-07
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9290_mql5-dem-env-fakeout.md`

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
| v1 | 2026-06-10 | Initial build from card | b4b9e38a-a79f-42fd-84be-32d7e2a12956 |
