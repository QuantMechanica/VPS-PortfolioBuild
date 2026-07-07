# QM5_13033_novo-crt-h4-sweep-reversal - Strategy Spec

**EA ID:** QM5_13033
**Slug:** `novo-crt-h4-sweep-reversal`
**Source:** `YT-NOVO-LEGACY-2026-07`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades a New York morning failed-breakout pattern on M5 using the
12:00-16:00 broker-time H4 candle as the daily anchor range. A trade is allowed
only when that H4 anchor and the three prior H4 candles are indecisive by
body/range fraction. Between 16:00 and 18:30 broker time, the first closed M5
bar that sweeps beyond the anchor range and closes back inside sets direction:
a high-side sweep looks for a short, and a low-side sweep looks for a long.
Entry occurs on the codified CISD trigger, with a structural stop beyond the
sweep-side extreme and take-profit at the opposite side of the anchor range.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_body_max_frac` | 0.50 | 0.30-0.70 | Maximum anchor H4 body as a fraction of its range. |
| `strategy_prior_body_max_frac` | 0.50 | 0.30-0.70 | Maximum mean body/range across the three prior H4 candles. |
| `strategy_anchor_open_hour` | 12 | 12 | Broker hour of the H4 anchor candle open. |
| `strategy_sweep_start_minute` | 960 | 900-1020 | Broker minute-of-day when sweep detection starts. |
| `strategy_sweep_end_minute` | 1110 | 1050-1170 | Broker minute-of-day when sweep detection ends. |
| `strategy_trigger_window_min` | 120 | 30-180 | Minutes after the sweep during which CISD can trigger. |
| `strategy_atr_period_m5` | 14 | 10-30 | M5 ATR period for the structural stop buffer. |
| `strategy_sl_buffer_atr` | 0.10 | 0.00-0.30 | ATR fraction added beyond the sweep/anchor extreme. |
| `strategy_tp_mode` | 0 | 0-1 | `0` targets the opposite anchor side; `1` targets anchor midpoint. |
| `strategy_flatten_minute` | 1200 | 1140-1260 | Broker minute-of-day for mandatory time flatten. |
| `strategy_max_spread_points` | 2500 | 0-5000 | Skip entries above this modeled spread; zero DWX spread is allowed. |

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - primary index CFD venue for the taught CRT setup.
- `XAUUSD.DWX` - gold venue included by the approved card and available in DWX.

**Explicitly NOT for:**
- `XTIUSD.DWX` and `XNGUSD.DWX` - energy-specific seasonality and inventory
  drivers are outside this session range-sweep source.
- Forex pairs - not in this card's approved target universe.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_H4` anchor candle plus prior three H4 candles |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Intraday, usually minutes to a few hours, force-flat by 20:00 broker. |
| Expected drawdown profile | Medium; one position per day with a structural stop beyond the sweep. |
| Regime preference | Session-anchored range reversal after failed liquidity sweeps. |
| Win rate target (qualitative) | Medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `YT-NOVO-LEGACY-2026-07`  
**Source type:** public video and internal mechanization dossier  
**Pointer:** `https://www.youtube.com/watch?v=fNFTpKmSQB8` and `docs/ops/evidence/3b1fe1ab_novo_legacy_mechanization_dossier_2026-07-07.md`  
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13033_novo-crt-h4-sweep-reversal.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial build from card | d186904d-71fd-4080-a126-4bde58836da0 |
