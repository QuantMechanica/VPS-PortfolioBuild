# QM5_10605_mql5-stepxccx - Strategy Spec

**EA ID:** QM5_10605
**Slug:** `mql5-stepxccx`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the ColorStepXCCX cloud on completed H4 bars. It opens long when buffer 0 crosses from below/equal to above buffer 1, and opens short when buffer 0 crosses from above/equal to below buffer 1. It exits an open long on the bearish opposite flip and exits an open short on the bullish opposite flip. If no opposite flip appears, it closes after 16 completed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for ColorStepXCCX and ATR reads. |
| `strategy_signal_bar` | `1` | `1+` | Closed-bar shift used for the signal. |
| `strategy_d_smooth_method` | `4` | `0-9` | ColorStepXCCX price smoothing method; default maps to JJMA in the source indicator. |
| `strategy_d_period` | `30` | `1+` | ColorStepXCCX price smoothing period. |
| `strategy_d_phase` | `100` | indicator-defined | ColorStepXCCX price smoothing phase parameter. |
| `strategy_m_smooth_method` | `7` | `0-9` | ColorStepXCCX deviation smoothing method; default maps to T3 in the source indicator. |
| `strategy_m_period` | `7` | `1+` | ColorStepXCCX average deviation period. |
| `strategy_m_phase` | `15` | indicator-defined | ColorStepXCCX deviation smoothing phase parameter. |
| `strategy_price_mode` | `6` | `1-11` | Applied price selector; default maps to typical price in the source indicator. |
| `strategy_step_fast` | `5` | `1+` | Fast step size for the cloud. |
| `strategy_step_slow` | `30` | `1+` | Slow step size for the cloud. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.5` | `>0` | ATR multiplier for the catastrophic stop. |
| `strategy_time_stop_bars` | `16` | `0+` | Maximum completed H4 bars to hold; `0` disables the time stop. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - source test instrument; directly matches the approved card.
- `EURUSD.DWX` - DWX FX major for portable cloud-flip testing.
- `GBPUSD.DWX` - DWX FX major for portable cloud-flip testing.
- `USDJPY.DWX` - DWX FX major for portable cloud-flip testing.
- `USDCHF.DWX` - DWX FX major for portable cloud-flip testing.
- `USDCAD.DWX` - DWX FX major for portable cloud-flip testing.
- `AUDUSD.DWX` - DWX FX major for portable cloud-flip testing.
- `NZDUSD.DWX` - DWX FX major for portable cloud-flip testing.

**Explicitly NOT for:**
- Equity indices and energy CFDs - the approved R3 text only names XAUUSD and DWX FX majors.
- Non-DWX symbols - build and backtest artifacts must use canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `65` |
| Typical hold time | Up to 16 completed H4 bars; earlier on opposite cloud flip. |
| Expected drawdown profile | Trend-following whipsaw risk during choppy cloud color changes. |
| Regime preference | Trend-following / cloud-color-change continuation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/1312`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10605_mql5-stepxccx.md`

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
| v1 | 2026-05-31 | Initial build from card | f97c2298-b102-4f6f-b810-b292ba3dbfcd |
