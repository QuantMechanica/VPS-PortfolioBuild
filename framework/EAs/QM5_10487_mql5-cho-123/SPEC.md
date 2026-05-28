# QM5_10487_mql5-cho-123 - Strategy Spec

**EA ID:** QM5_10487
**Slug:** `mql5-cho-123`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades a Chaikin Oscillator flat-to-trend breakout on closed M5 bars. It computes the Chaikin Oscillator from accumulation/distribution using source defaults fast 3 and slow 10, then blocks new entries when at least 90% of the last 20 evaluated bars sit inside +/-40. When the market is not flat, it opens long if the latest closed-bar CHO is at least +110 and short if it is at most -110. It exits on the opposite CHO open-level signal, on a 144-bar time stop, or through the baseline ATR SL and 2R TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cho_fast_period` | 3 | 1-50 | Fast EMA period for the Chaikin Oscillator. |
| `strategy_cho_slow_period` | 10 | 2-100 | Slow EMA period for the Chaikin Oscillator; coerced above fast period. |
| `strategy_cho_flat_level` | 40.0 | >0 | Absolute CHO boundary used to count flat bars. |
| `strategy_cho_open_level` | 110.0 | >0 | Absolute CHO threshold for long or short entries and opposite-signal exits. |
| `strategy_cho_flat_bars` | 20 | 1-100 | Number of recent closed bars used by the flat filter. |
| `strategy_channels_flat_pct` | 90.0 | 0-100 | Flat classification threshold from the approved card. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 1.5 | >0 | ATR multiplier for the initial stop loss. |
| `strategy_tp_r_multiple` | 2.0 | >0 | Take-profit distance as a multiple of initial risk. |
| `strategy_time_stop_bars` | 144 | 0-10000 | Maximum holding period in base-timeframe bars; 0 disables. |
| `strategy_max_spread_points` | 35.0 | 0+ | Maximum allowed spread in broker points; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source example and primary liquid FX target for the M5 CHO regime breakout.
- `GBPUSD.DWX` - liquid major FX pair with DWX M5 volume and OHLC data.
- `USDJPY.DWX` - liquid major FX pair with DWX M5 volume and OHLC data.
- `XAUUSD.DWX` - liquid metal CFD included in the approved card's P2 basket.

**Explicitly NOT for:**
- `SP500.DWX` - not part of this card's approved P2 basket.
- `NDX.DWX` - not part of this card's approved P2 basket.

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
| Trades / year / symbol | `100` |
| Typical hold time | M5 intraday trades, capped at 144 bars |
| Expected drawdown profile | Execution-cost-sensitive intraday breakout losses during flat regimes |
| Regime preference | breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/22127`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10487_mql5-cho-123.md`

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
| v1 | 2026-05-28 | Initial build from card | ca356b66-ef73-48ee-8fbf-831549765a48 |
