# QM5_12594_yang-wti-reversal - Strategy Spec

**EA ID:** QM5_12594
**Slug:** `yang-wti-reversal`
**Source:** `05abad87-420d-5a51-8a9b-3c35ad795385` (see `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

This EA trades a weekly D1 reversal on `XTIUSD.DWX`. On the first D1 bar of the
trading week, it measures the prior closed D1 close against the close 63 bars
earlier. If WTI has fallen at least 6 percent, is stretched below SMA(63) by at
least 0.75 ATR, and the last 5 D1 bars confirm an upward reversal, it buys. The
short side mirrors the rule after a positive 63-day extreme. Positions exit when
price reaches SMA(63), after 15 calendar days, or via a fixed ATR stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_days` | 63 | 42-126 | D1 bars used for the medium-term return extreme |
| `strategy_confirm_days` | 5 | 3-8 | D1 bars used for short reversal confirmation |
| `strategy_mean_period` | 63 | 42-126 | SMA period used as stretch anchor and mean-reversion exit |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stretch and stop distance |
| `strategy_min_abs_return_pct` | 6.0 | 4.0-10.0 | Minimum absolute lookback return needed for a reversal setup |
| `strategy_min_stretch_atr` | 0.75 | 0.50-1.25 | Required distance from SMA in ATR units |
| `strategy_atr_sl_mult` | 3.5 | 2.5-4.5 | Hard stop distance in ATR units |
| `strategy_max_hold_days` | 15 | 10-21 | Calendar-day time stop |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - WTI crude oil CFD available in the DWX symbol matrix; this is the intended energy sleeve.

**Explicitly NOT for:**

- `XAUUSD.DWX` and `XAGUSD.DWX` - excluded to avoid adding another metal sleeve.
- `XNGUSD.DWX` - excluded because the book already has several XNG structural/event builds.
- Equity indices and FX pairs - outside this commodity-reversal card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Typical hold time | 3-15 D1 bars |
| Expected drawdown profile | Medium-high; fades WTI extremes with fixed ATR loss control |
| Regime preference | Medium-term commodity mean reversion after a large oil move |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `05abad87-420d-5a51-8a9b-3c35ad795385`
**Source type:** paper
**Pointer:** `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12594_yang-wti-reversal.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Initial build from card | pending branch commit |
