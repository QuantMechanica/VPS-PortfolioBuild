---
ea_id: QM5_12958
slug: nnfx-hma-wae-swing
type: strategy
source_id: CEO-SWING-SLATE-2026-07-02
source_citation: "VP (No Nonsense Forex). The NNFX Algorithm framework (baseline + confirmation + volume, D1, published channel methodology, https://nononsenseforex.com); Hull, A. (2005). Hull Moving Average (reduced-lag MA, hullmovingaverage.com); Waddah Attar Explosion indicator (public MQL5 CodeBase implementation). Mechanics corroborated by agy sweep SWING_STRATEGY_YT_SWEEP_2026-07-02.md (Strategy 4)."
sources:
  - "[[sources/CEO-SWING-SLATE-2026-07-02]]"
concepts:
  - "[[concepts/nnfx-framework]]"
  - "[[concepts/baseline-confirmation-volume]]"
indicators:
  - "[[indicators/hull-ma]]"
  - "[[indicators/waddah-attar-explosion]]"
  - "[[indicators/atr]]"
strategy_type_flags: [trend-following, nnfx, swing, multi-day-hold, long-short, low-frequency, partial-exit]
target_symbols: [XAUUSD.DWX, GDAXI.DWX, EURJPY.DWX]
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 baseline crosses with volume confirmation; ~15-30 signals/year/symbol."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "NNFX is a fully published mechanical framework (baseline/confirmation/volume/ATR risk model) with a large practitioner evidence base; HMA and WAE are public, deterministic indicators. Directly serves OWNER's standing NNFX hypothesis test (task #18). Video performance claims from the agy sweep are NOT relied on for R1."
r2_mechanical: PASS
r2_reasoning: "Long: D1 close > HMA(20) AND WAE trend bar exceeds both deadzone and explosion lines. Short mirrored. SL 1.5x ATR(14); partial exit 50% at 1.0x ATR(14) + breakeven; trail: close opposite side of HMA(20). All closed-bar, deterministic. Partial-close uses the framework's qm_tm_partial_close path."
r3_data_available: PASS
r3_reasoning: "XAUUSD/GDAXI (best surviving classes) + one JPY-cross for the missing class; all in the DWX matrix; WAE/HMA implementable natively (no external libs)."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no grid, no martingale; fixed parameters; one position per magic; WAE is closed-form MACD/BB arithmetic."
pipeline_phase: G0
last_updated: 2026-07-02
expected_pf: 1.25
expected_dd_pct: 15.0
g0_approval_reasoning: "APPROVED — independent WS3 G0 review 2026-07-02: R1 source quality is sufficient for an OWNER-directed NNFX hypothesis test because the framework and HMA/WAE components are public and deterministic, with video performance claims not used as proof; R2 is mechanical and closed-bar (HMA baseline cross, WAE threshold confirmation, ATR stop/partial, HMA-side final exit); R3 XAUUSD.DWX, GDAXI.DWX, and EURJPY.DWX D1 are covered; R4 has no ML/grid/martingale and one position per magic. Distinctness accepted because this rebuild targets canonical HMA+WAE NNFX fidelity rather than prior wrong-indicator NNFX variants."
---

# NNFX Hull-MA + Waddah-Attar Swing (canonical baseline+volume framework)

## Edge / Thesis

The NNFX framework's core claim: D1 trend-following survives when entries require BOTH a
baseline cross (reduced-lag HMA) AND an expansion-of-volatility confirmation (WAE above
deadzone), filtering the low-energy crosses that kill naive MA systems. The farm's earlier
NNFX attempts failed a fidelity audit (wrong indicators); this card is the canonical
pairing. It directly tests OWNER's standing hypothesis (#18) with the pipeline as judge.

## Mechanics (deterministic, closed D1 bars)

1. Long entry: close crosses above HMA(20) AND WAE trend value > deadzone line AND > explosion line, bullish side. Short mirrored.
2. SL: 1.5x ATR(14) from entry.
3. Partial: close 50% at +1.0x ATR(14), move SL to breakeven.
4. Final exit: D1 close on opposite side of HMA(20).
5. One position per magic; no adds. RISK_FIXED backtest; news gate entries-only; weekend hold allowed, Friday close DISABLED (swing class).

## Parameters

- hma_period = 20; wae_sensitivity = 150, wae_deadzone = 15 (published defaults)
- atr_period = 14, sl_mult = 1.5, partial_tp_mult = 1.0

## Risks / Kill Criteria

Generic-trend Q04 base rate is 3.4% — the WAE gate must earn its keep by cutting chop
entries. Kill on pooled Q04 net PF < 1.0 per symbol; no indicator swapping (that's a new
card, not a tweak).

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact GDAXI.DWX/D1 configuration used by Q08 (set file `QM5_12958_nnfx-hma-wae-swing_GDAXI.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_12958",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "12958",
    "qm_friday_close_enabled": "false",
    "qm_friday_close_hour_broker": "21",
    "qm_magic_slot_offset": "1",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_risk_cap_pct": "1.0",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "14",
    "strategy_hma_period": "20",
    "strategy_partial_fraction": "0.50",
    "strategy_partial_tp_mult": "1.0",
    "strategy_sl_mult": "1.5",
    "strategy_wae_bb_deviation": "2.0",
    "strategy_wae_bb_period": "20",
    "strategy_wae_deadzone_points": "15.0",
    "strategy_wae_fast_macd": "12",
    "strategy_wae_sensitivity": "150.0",
    "strategy_wae_signal_macd": "9",
    "strategy_wae_slow_macd": "26"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "653da9fc6f2e518e9880649e7eae8945ff8f075cf26826ed13b5d1c0b8796559",
  "symbol": "GDAXI.DWX",
  "timeframe": "D1"
}
```
