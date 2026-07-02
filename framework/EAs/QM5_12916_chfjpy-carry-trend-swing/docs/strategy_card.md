---
ea_id: QM5_12916
slug: chfjpy-carry-trend-swing
type: strategy
source_id: CEO-SWING-SLATE-2026-07-02
source_citation: "Koijen, R., Moskowitz, T., Pedersen, L. & Vrugt, E. (2018). Carry. Journal of Financial Economics 127(2); Menkhoff, L. et al. (2012). Currency momentum strategies. Journal of Financial Economics 106(3)."
sources:
  - "[[sources/CEO-SWING-SLATE-2026-07-02]]"
concepts:
  - "[[concepts/fx-carry-trend]]"
  - "[[concepts/jpy-funding-currency]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/momentum]]"
strategy_type_flags: [carry-trend, trend-filtered, swing, multi-week-hold, long-only, low-frequency, jpy-cross]
target_symbols: [CHFJPY.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Carry-trend regime entries on pullback recovery; 3-6 trades/year, multi-week holds."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Peer-reviewed JFE evidence for both legs of the mechanic: carry persistence (Koijen et al. 2018) and 3-month FX momentum (Menkhoff et al. 2012). JPY is the canonical funding currency; CHFJPY is the identified missing JPY/CHF-cross book class."
r2_mechanical: PASS
r2_reasoning: "Regime: close > SMA(200) AND close > close[63] (3-month momentum positive). Entry: close crosses back above SMA(10) after having been below it. Exit: close < SMA(50). All closed-bar, deterministic."
r3_data_available: PASS
r3_reasoning: "CHFJPY.DWX D1 is covered in the DWX FX matrix. Low frequency keeps the FX commission share of gross smaller than intraday sleeves."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no grid, no martingale; fixed parameters; one position per magic."
pipeline_phase: G0
last_updated: 2026-07-02
expected_pf: 1.25
expected_dd_pct: 22.0
g0_approval_reasoning: "APPROVED - independent WS3 G0 review 2026-07-02: R1 passes on peer-reviewed carry and FX momentum evidence; R2 is deterministic and closed-bar; R3 CHFJPY.DWX D1 is in the DWX FX matrix; R4 has no ML/grid/martingale and is single-position. Distinctness accepted because it adds missing carry-trend/JPY-cross exposure."
---

# CHFJPY Carry-Trend Swing

## Edge / Thesis

JPY is the persistent G10 funding currency; being long CHFJPY expresses short-JPY carry with a Swiss-franc quote leg. Peer-reviewed evidence supports carry persistence and 3-month FX momentum. The sleeve adds missing carry-trend / JPY-cross exposure rather than another basket, index mean-reversion, or metals trend sleeve.

## Mechanics

1. Regime: close > SMA(200) and close > close[63].
2. Entry: long only, close crosses above SMA(10) from below while regime holds.
3. Exit: close < SMA(50).
4. One position per magic. RISK_FIXED backtest; news gate entries only; weekend hold allowed; Friday close disabled.

## Parameters

- sma_regime = 200
- momentum_lookback = 63
- sma_entry = 10
- sma_exit = 50

## Risks / Kill Criteria

BoJ intervention shocks can hit long JPY-cross positions violently, and the SMA(50) exit lags. Q05 should probe this. Kill on pooled Q04 net PF < 1.0 or Q05 catastrophic single-fold loss > 3x average; no re-optimization.
