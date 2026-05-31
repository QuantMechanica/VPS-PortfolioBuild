# QM5_10526_mql5-flat-chan — Strategy Spec

**EA ID:** QM5_10526
**Slug:** `mql5-flat-chan`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates M30 closed bars for a flat price channel. It builds a 20-bar channel from the completed bars before the breakout bar, requires the channel width to be no more than 1.2 times ATR(14), and requires both channel boundaries to have moved by no more than 0.25 times ATR(14) over five bars. It opens long when the last closed bar closes above the channel high plus 0.10 times ATR(14), and short when it closes below the channel low minus 0.10 times ATR(14). The stop is the opposite channel boundary, the target is the larger of channel width and 1.25R capped at 2.0R, and a 12-bar time stop exits trades that have not reached 0.5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_channel_lookback` | 20 | 12-36 | Completed bars used to form the flat channel. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for flatness, slope, and breakout indent thresholds. |
| `strategy_flat_atr_ratio` | 1.20 | 0.50-2.50 | Maximum channel width as a multiple of ATR. |
| `strategy_slope_bars` | 5 | 1-12 | Bars used to compare current channel boundary levels against prior boundary levels. |
| `strategy_max_slope_atr` | 0.25 | 0.00-1.00 | Maximum boundary movement over the slope window as a multiple of ATR. |
| `strategy_breakout_atr_indent` | 0.10 | 0.00-0.50 | Extra ATR distance beyond the channel boundary required for breakout confirmation. |
| `strategy_min_tp_r` | 1.25 | 0.50-3.00 | Minimum target distance expressed in R. |
| `strategy_max_tp_r` | 2.00 | 1.00-4.00 | Maximum target distance expressed in R. |
| `strategy_time_stop_bars` | 12 | 1-48 | Number of M30 bars after which the time stop is evaluated. |
| `strategy_time_stop_min_r` | 0.50 | 0.10-1.50 | Minimum favorable move required to avoid the time stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-recommended FX pair and primary M30 breakout target.
- `GBPUSD.DWX` — R3 portable FX basket member with DWX M30 data.
- `USDJPY.DWX` — R3 portable FX basket member with DWX M30 data.
- `AUDUSD.DWX` — R3 portable FX basket member with DWX M30 data.

**Explicitly NOT for:**
- `SP500.DWX` — not part of the card's FX/XAU R3 basket.
- `NDX.DWX` — not part of the card's FX/XAU R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `75` |
| Typical hold time | `up to 12 M30 bars when the time stop applies` |
| Expected drawdown profile | `breakout false-starts during non-expanding ranges` |
| Regime preference | `volatility-expansion breakout after compression` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `forum`
**Pointer:** `https://www.mql5.com/en/code/19150`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10526_mql5-flat-chan.md`

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
| v1 | 2026-05-29 | Initial build from card | 2dd11806-9dfe-43d5-a8ac-df29732eaf52 |
