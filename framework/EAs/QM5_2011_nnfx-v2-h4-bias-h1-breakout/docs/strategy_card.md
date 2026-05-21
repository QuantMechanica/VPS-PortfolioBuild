---
ea_id: QM5_2011
slug: nnfx-v2-h4-bias-h1-breakout
name: NNFX V2 H4 Bias H1 Breakout
priority: high
trigger: BOARD_ADVISOR_NNFX_V2
created_at: 2026-05-20
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 70
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
---

# NNFX V2 H4 Bias H1 Breakout (QM5_2011)

## Source Citation

2012-2024 No Nonsense Forex public NNFX framework, URL: https://nononsenseforex.com/. Breakout timing is a mechanical Donchian/ATR port of the framework's trend-continuation confirmation idea.

## Thesis

The first NNFX cohort used confirmation stacks that often blocked trades. This version keeps the H4 NNFX bias but times entries with H1 compression breakouts, giving the EA a cleaner way to participate after volatility contraction.

## Rules

### Target Symbols

Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. H4 bias; H1 entry.

### Regime / Baseline

- Long bias when H4 close > EMA(100), MACD main > signal, and SSL(10) green > red.
- Short bias when H4 close < EMA(100), MACD main < signal, and SSL(10) green < red.
- Compression filter: H1 ATR(14) must be below its 80-bar median during at least 3 of the prior 8 closed H1 bars.

### Entry

- Long Entry when H4 long bias is active and the latest closed H1 bar closes above the highest high of the prior 20 H1 bars.
- Short Entry when H4 short bias is active and the latest closed H1 bar closes below the lowest low of the prior 20 H1 bars.
- RSI(14) H1 must be above 52 for longs or below 48 for shorts.
- One position per symbol/magic; skip new entries during the final 2 H1 bars before weekly close.

### Exit

- Exit on opposite H1 Donchian(10) break.
- Exit on H4 bias flip.
- Time Exit after 96 H1 bars.

### Stop / Risk

- Initial Stop is 2.2 * ATR(14) H1.
- Trail by 2.5 * ATR(14) H1 once unrealized profit exceeds +1.5R.
- No martingale, no grid, no position scaling.

## Expected Frequency

Expected trades per year per symbol: 70. H1 breakout after compression should produce enough samples while filtering low-quality chop.

## G0 Review

| Gate | Verdict | Notes |
| --- | --- | --- |
| R1 Track Record | PASS | Public NNFX trend framework combined with standard Donchian breakout mechanics. |
| R2 Mechanical | PASS | Bias, compression, Entry, Exit, Stop, and time filters are deterministic. |
| R3 Data Available | PASS | All required inputs are native H1/H4 OHLC-derived indicators on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed-rule system only; no ML or adaptive model training. |
