---
ea_id: QM5_12784
slug: progo-xti
type: strategy
strategy_id: SRC03_S16_XTI
source_id: SRC03
target_symbols: [XTIUSD.DWX]
period: D1
g0_status: APPROVED
pipeline_phase: Q02
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 16
---

# Williams Pro-Go XTI Flow Crossover

This build implements the approved `progo-xti` card. Runtime logic uses only
Darwinex `XTIUSD.DWX` D1 OHLC and framework ATR/spread data.

## Rules

- Public flow: `Open[D1] - Close[prior D1]`.
- Professional flow: `Close[D1] - Open[D1]`.
- Long when the smoothed professional-flow line crosses above the smoothed
  public-flow line.
- Short when it crosses below.
- Exit on opposite cross, ATR hard stop, max-hold guard, or framework Friday
  close.

## Guardrails

- No external runtime data.
- No ML.
- No grid or martingale.
- One `XTIUSD.DWX` position per magic slot.

## Pipeline Status

- Q02 queued on 2026-06-29: `work_items/e04d6c58-8b0d-461c-a0f3-22912b484695`.
