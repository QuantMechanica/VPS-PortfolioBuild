---
ea_id: QM5_11196
slug: ft-heracles
type: strategy
source_id: 1580128f-e465-5454-bb97-a7572a6cfd6d
source_citation: "Masoud Azizi (@Mablue), Heracles.py, freqtrade-strategies, GitHub, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Heracles.py"
sources:
  - "[[sources/freqtrade-strategies]]"
concepts:
  - "[[concepts/volatility-compression]]"
  - "[[concepts/donchian-channel]]"
  - "[[concepts/keltner-channel]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/keltner-channel]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX]
period: H4
expected_trade_frequency: "Source comments report 25 trades in a 100-iteration result block; H4 channel-ratio DWX estimate is 20-50 trades/year/symbol."
expected_trades_per_year_per_symbol: 30
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-09-06
g0_approval_reasoning: "OWNER receipt 5bf3bf5e-e3a9-40f8-8346-d2df9ca9b1e2: Q14 sweep proposal is not executed research; single XAUUSD configuration locked for DSR n=1."
---

# Freqtrade Heracles Donchian Keltner Ratio

## Source
- Source: [[sources/freqtrade-strategies]]
- Citation: Masoud Azizi (@Mablue), "Heracles.py", freqtrade-strategies, GitHub, 2026 URL https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Heracles.py.
- Author / handle: `@Mablue (Masoud Azizi)`.
- Source location: `user_data/strategies/Heracles.py`.
- Repository commit inspected: `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`.

## Mechanics

### Entry
- Work on H4 closed bars.
- Compute:
  - Keltner channel width band, window 20, ATR window 10.
  - Donchian channel percent band, window 10.
- Long entry:
  - `d = DonchianPercentBand.shift(15) / KeltnerWidth.shift(9)`.
  - Enter long when `0.16 <= d <= 0.75`.

### Exit
- Source signal exit is disabled (`exit_long = 0`), so use source management exits:
  - ROI ladder: 59.8% immediately, 16.6% after 644 minutes, 11.5% after 3269 minutes, 0% after 7289 minutes.
- Friday Close enforced by V5 defaults.

### Stop Loss
- Source stoploss: -25.6%.
- MT5 baseline: `QM_StopATR(14, 2.5)` with P3 sweep.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Additional filters
- One active position per symbol/magic.
- Skip high-impact news window.
- Spread <= 8% of planned stop distance.
- Require 40-bar warmup before evaluating shifted channel ratio.

## Concepts
- [[concepts/volatility-compression]] - primary
- [[concepts/donchian-channel]] - secondary
- [[concepts/keltner-channel]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full GitHub URL plus author handle/name in source comments. |
| R2 Mechanical | PASS | Shifted Donchian/Keltner ratio, ROI ladder, and stoploss are deterministic. |
| R3 DWX-testbar | PASS | Uses OHLC channel/volatility indicators; portable to DWX FX/metals/indices. |
| R4 No ML | PASS | Fixed hyperopt constants; no ML, adaptive parameters, grid, or martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX. Crypto source is ported as a volatility/channel state edge.

## Parameters To Test
```yaml
- name: buy_div_min
  default: 0.16
  sweep_range: [0.10, 0.16, 0.25]
- name: buy_div_max
  default: 0.75
  sweep_range: [0.50, 0.75, 0.90]
- name: donchian_shift
  default: 15
  sweep_range: [9, 15, 20]
- name: keltner_shift
  default: 9
  sweep_range: [5, 9, 15]
- name: atr_stop_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
```

## Author Claims
```text
"Heracles Strategy: Strongest Son of GodStra" (Heracles.py)
"With just 1 Genome!" (Heracles.py)
Source comments report "25 trades", "Avg profit   5.92%", and "Avg duration 4 days, 6:24:00 min."
```

## Initial Risk Profile
```yaml
expected_pf: TBD
expected_dd_pct: TBD
expected_trade_frequency: 30/year
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## Framework Alignment
```yaml
modules_used:
  no_trade:
    used: true
    notes: "News blackout, spread guard, warmup for shifted indicators."
  trade_entry:
    used: true
    notes: "Shifted Donchian percent-band divided by shifted Keltner width inside fixed band."
  trade_management:
    used: true
    notes: "V5 risk stop plus source ROI ladder."
  trade_close:
    used: true
    notes: "Source signal exit disabled; close through ROI/stop/Friday rules."
hard_rules_at_risk:
  - friday_close
at_risk_explanation: |
  Multi-day H4 holds require standard V5 weekend/Friday handling.
```

## Pipeline history
- G0: 2026-05-23, PENDING.

## Lessons Learned
- TBD during pipeline run.
+## Approved Amendment (2026-09-06) — DSR Single Configuration

- Authority: OWNER receipt `5bf3bf5e-e3a9-40f8-8346-d2df9ca9b1e2`, YES / Option A.
- The earlier Parameters To Test list is a **Q14 proposal**, not executed research. It contributes zero research trials unless a complete loser-inclusive ledger is declared.
- This declaration locks the exact XAUUSD.DWX/H4 configuration used by Q08. It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_11196",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "11196",
    "qm_filter_news_enabled": "1",
    "qm_filter_news_mode": "3",
    "qm_filter_regime_bear_return_pct": "2.0",
    "qm_filter_regime_bull_return_pct": "2.0",
    "qm_filter_regime_enabled": "0",
    "qm_filter_regime_lookback_bars": "100",
    "qm_filter_volatility_atr_period": "14",
    "qm_filter_volatility_compression_ratio": "0.75",
    "qm_filter_volatility_enabled": "0",
    "qm_filter_volatility_expansion_ratio": "1.25",
    "qm_filter_volatility_lookback_bars": "50",
    "qm_friday_close_enabled": "true",
    "qm_friday_close_hour_broker": "21",
    "qm_magic_slot_offset": "2",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_stop_mult": "2.5",
    "strategy_atr_stop_period": "14",
    "strategy_buy_div_max": "0.75",
    "strategy_buy_div_min": "0.16",
    "strategy_donchian_shift": "15",
    "strategy_donchian_window": "10",
    "strategy_keltner_atr_period": "10",
    "strategy_keltner_shift": "9",
    "strategy_keltner_window": "20",
    "strategy_max_spread_stop_frac": "0.08",
    "strategy_min_warmup_bars": "40",
    "strategy_roi_0_min": "0.598",
    "strategy_roi_1_after_min": "644",
    "strategy_roi_1_min": "0.166",
    "strategy_roi_2_after_min": "3269",
    "strategy_roi_2_min": "0.115",
    "strategy_roi_3_after_min": "7289",
    "strategy_roi_3_min": "0.0",
    "strategy_timeframe": "PERIOD_H4"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "b3c076515a4e7180c37a45a3e5d8d065e17a028ce35232373f40cbf0c210bf66",
  "symbol": "XAUUSD.DWX",
  "timeframe": "H4"
}
```
