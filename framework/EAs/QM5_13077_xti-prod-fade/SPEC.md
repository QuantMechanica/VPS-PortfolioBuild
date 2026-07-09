# QM5_13077_xti-prod-fade - Strategy Spec

**EA ID:** QM5_13077
**Slug:** `xti-prod-fade`
**Source:** `EIA-XTI-FIELDPROD-FADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

The EA trades `XTIUSD.DWX` on D1 around the EIA weekly petroleum release
window. On a new D1 bar it inspects the prior completed bar; that bar must be
Wednesday or Thursday, probe outside a 34-day channel, close back inside the
channel, show an ATR-sized range and rejection tail, and be stretched away from
the slow SMA. The EA enters in the opposite direction of the failed probe with
an ATR stop and target, then exits on SMA mean reach, adverse channel failure,
time stop, target, stop, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_dow_1` | 3 | 3 | First broker day-of-week accepted as WPSR proxy, Wednesday. |
| `strategy_event_dow_2` | 4 | 4 | Second broker day-of-week accepted as WPSR proxy, Thursday. |
| `strategy_context_channel` | 34 | 21-55 | Channel probe lookback, excluding the signal bar. |
| `strategy_exit_channel` | 13 | 8-21 | Adverse channel-failure exit lookback. |
| `strategy_trend_period` | 80 | 50-120 | SMA period for mean/stretched-state checks. |
| `strategy_atr_period` | 20 | 14-30 | ATR period for range, stop, and target distance. |
| `strategy_min_probe_atr` | 0.18 | 0.10-0.30 | Minimum channel overshoot in ATR units. |
| `strategy_min_signal_range_atr` | 0.75 | 0.55-1.00 | Minimum signal-bar range in ATR units. |
| `strategy_min_tail_ratio` | 0.28 | 0.20-0.40 | Minimum rejection-tail share of signal range. |
| `strategy_min_sma_stretch_atr` | 0.25 | 0.10-0.45 | Minimum probe stretch from SMA in ATR units. |
| `strategy_atr_sl_mult` | 2.50 | 2.00-3.25 | ATR multiple for hard stop. |
| `strategy_atr_tp_mult` | 2.25 | 1.75-3.00 | ATR multiple for profit target. |
| `strategy_max_hold_days` | 6 | 4-9 | Maximum calendar days to hold a position. |
| `strategy_max_spread_points` | 1000 | 700-1500 | Skip entries above this modeled spread. |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI crude CFD proxy with local D1 history and EIA crude
  field-production source exposure.

**Explicitly NOT for:**
- `XNGUSD.DWX` - natural gas has different storage/weather drivers and is
  already represented by separate XNG sleeves.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metals do not represent EIA crude
  field-production supply capacity.
- Index CFDs - equity-index exposure is outside the source lineage.

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
| Trades / year / symbol | 6 |
| Typical hold time | 2-6 calendar days |
| Expected drawdown profile | Medium-high, crude gaps bounded by ATR hard stop and Friday close. |
| Regime preference | Failed release-window channel probes that mean-revert toward SMA. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-XTI-FIELDPROD-FADE-2026`  
**Source type:** official EIA data series and weekly report cadence  
**Pointer:** `https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCRFPUS2` and `https://www.eia.gov/petroleum/supply/weekly/`  
**R1-R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/xti-prod-fade_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). The committed Q02 setfile uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from card | Mission-directed XTI field-production failed-probe fade |
