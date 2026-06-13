# QM5_12550_ict-london-close-reversal-m15 - Strategy Spec

**EA ID:** QM5_12550
**Slug:** ict-london-close-reversal-m15
**Source:** ict-mmm-notes-2020-london-close
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades M15 London Close reversals with H4/D1 context. A short setup requires a London buy day, confirmed by the London session making a high above the Asian range and prior day's high, followed by a London Close sweep above that high and a closed M15 market structure shift below the preceding swing low. A long setup is the mirror image after a London sell day. Entries use the 70.5% retracement of the London open-to-extreme swing, with a 3-bar limit-order expiry or market entry when price has already traded through the retracement zone.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | >=1 | M15 ATR period for stop buffer and runner trail. |
| strategy_ote_fraction | 0.705 | 0.0-1.0 | Retracement fraction for the OTE limit entry. |
| strategy_ote_zone_low | 0.620 | 0.0-1.0 | Lower bound of H4 OTE context zone. |
| strategy_ote_zone_high | 0.795 | 0.0-1.0 | Upper bound of H4 OTE context zone. |
| strategy_stop_atr_buffer | 0.30 | >0 | ATR buffer beyond the London session extreme for the initial stop. |
| strategy_london_open_gmt_h | 9 | 0-23 | London session open hour in GMT/UTC. |
| strategy_london_build_end_gmt_h | 15 | 0-23 | End of London session range build in GMT/UTC. |
| strategy_close_start_gmt_h | 15 | 0-23 | London Close killzone start hour in GMT/UTC. |
| strategy_close_end_gmt_h | 17 | 0-23 | London Close killzone end hour in GMT/UTC. |
| strategy_close_end_gmt_m | 30 | 0-59 | London Close killzone end minute in GMT/UTC. |
| strategy_asian_start_gmt_h | 0 | 0-23 | Asian range start hour in GMT/UTC. |
| strategy_asian_end_gmt_h | 9 | 0-23 | Asian range end hour in GMT/UTC. |
| strategy_m15_scan_bars | 160 | >=80 | Closed M15 bars used for session/MSS structure scans. |
| strategy_mss_max_bars | 10 | >=1 | Maximum bars between sweep and MSS trigger. |
| strategy_swing_scan_bars | 24 | >=4 | Bars searched for the swing point preceding the sweep. |
| strategy_d1_pivot_lookback | 80 | >=20 | D1 bars used to detect lower-high/lower-low or mirror bias. |
| strategy_h4_ote_lookback | 60 | >=20 | H4 bars used to detect context OTE zones and swing targets. |
| strategy_limit_valid_bars | 3 | >=1 | Pending limit validity after MSS confirmation. |
| strategy_runner_rr_fallback | 2.0 | >0 | Fallback TP2 multiple if prior day/H4 target is unavailable. |
| strategy_partial_fraction | 0.50 | 0.0-1.0 | Position fraction closed at TP1. |
| strategy_atr_trail_mult | 1.0 | >0 | ATR trailing multiplier for the runner after TP1. |
| strategy_max_spread_points | 80 | >=0 | Maximum allowed spread in points; 0 disables this filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed M15 FX pair with DWX data available.
- GBPUSD.DWX - Card-listed M15 FX pair with DWX data available.
- USDJPY.DWX - Card-listed M15 FX pair with DWX data available.
- XAUUSD.DWX - Card-listed M15 gold symbol with DWX data available.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research/backtest artifacts require the `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/custom-symbol data is not available for P2 fanout.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | D1 bias pivots, H4 OTE/context target, D1 prior high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Intraday, usually London Close to same-session TP/runner exit |
| Expected drawdown profile | Approximately 15% card expectation; bounded by RISK_FIXED backtest sizing |
| Regime preference | London Close session reversal after liquidity sweep and MSS |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ict-mmm-notes-2020-london-close
**Source type:** educational notes / ICT canonical model derivative
**Pointer:** `D:/QM/strategy_farm/source_cache/ict-twfx-mmm-notes.txt`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12550_ict-london-close-reversal-m15.md`

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
| v1 | 2026-06-13 | Initial build from card | 10e4d27a-50a9-489c-927c-0cd247537d25 |
