# Extended Structural Optimization Backlog - Non-Time Edge Discovery

This document outlines the optimization plan for technical, structural, and multi-timeframe parameters to maximize strategy robustness.

## Category 1: Volatility & ATR Sensitivity (The "ATR-Stretch" Class)
*Goal: Find the optimal 'breathing room' for each strategy based on current market volatility.*

| EA ID | Name | Optimization Targets | Strategy |
| :--- | :--- | :--- | :--- |
| **QM5_10003** | Xaron Morning BO | `strategy_min_range_atr_mult` (0.1-1.0), `strategy_sl_range_mult` (0.5-1.5) | Find the perfect BO-trigger relative to ATR. |
| **QM5_10009** | Cointeg BB | `strategy_stop_excursion_mult` (1.0-3.0) | How much "heat" can a mean-reversion trade take? |
| **QM5_10019** | NFP Drift | `strategy_drift_atr_mult` (0.1-0.5), `strategy_sl_atr_mult` (0.4-1.2) | Scale the post-news drift entry to volatility. |

## Category 2: Indicator Thresholds & Momentum (The "Trigger" Class)
*Goal: Fine-tune entry/exit sensitivity to reduce noise.*

| EA ID | Name | Optimization Targets | Strategy |
| :--- | :--- | :--- | :--- |
| **QM5_10000** | TASAYC Breakout | `strategy_cci_period` (10-40), `strategy_cci_threshold` (50-200) | Is 100 really the best level for a BO? |
| **QM5_10014** | UK Stoch M15 | `strategy_stoch_k_period` (5-21), `strategy_stoch_d_period` (3-8) | Smooth the stochastic for M15 noise. |
| **QM5_10002** | Sisyphus 2MA | `strategy_fast_ema_period` (3-15), `strategy_rsi_period` (2-14) | Optimize the short-term pullback sensitivity. |

## Category 3: Multi-Timeframe (MTF) & Bias Alignment
*Goal: Find the best higher-timeframe "Anchor" for execution.*

| EA ID | Name | Optimization Targets | Strategy |
| :--- | :--- | :--- | :--- |
| **QM5_10005** | Profigenics | `strategy_htf` (M30, H1, H4, D1), `strategy_bias_period` (20-100) | Which HTF filter produces the highest PF? |
| **QM5_10038** | 4x25EMA MTF | All 4 EMA periods and TF combinations | Find the optimal harmonic alignment of trends. |

## Execution Protocol

1.  **Symbol-Specific Setfiles:** Unlike time-ranges, technical parameters are highly symbol-dependent. We run separate P3 sweeps for Forex vs. Indices vs. Gold.
2.  **Ratio Optimization:** Focus on `Profit Factor / Max Drawdown` as the primary fitness function in MT5.
3.  **Cross-Correlation Check:** Ensure that optimizing technical parameters doesn't just "curve-fit" a specific period, but maintains edge in Walk-Forward (P4).
