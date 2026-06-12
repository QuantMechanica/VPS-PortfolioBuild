# QM5_12537_ict-ote-displacement-xau - Strategy Spec

**EA ID:** QM5_12537
**Slug:** ict-ote-displacement-xau
**Source:** ict-2022-model-canonical-2026-06-12 (see `sources/ict-inner-circle-trader`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades an ICT liquidity sweep followed by a market-structure shift on M15 during the broker 14:00-17:00 NY AM killzone. For a long, the last closed M15 bar must sweep below a prior-day, Asia-range, or recent M15 pivot-low liquidity pool and close back above it; within eight M15 bars, price must close above the most recent pivot high. The EA then places a buy limit at 29.5% of the displacement leg above the sweep extreme, which is the card's 70.5% retracement entry, with the short side mirrored. The stop is 0.3 x ATR(14) beyond the sweep extreme, half the position is closed at the displacement extreme, and the runner exits at 2.5R or broker 21:00.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | M15 expected | Execution and structure timeframe. |
| `strategy_session_start_h` | `14` | 0-23 | Broker-hour start of the NY AM killzone. |
| `strategy_session_end_h` | `17` | 0-23 | Broker-hour end of the NY AM killzone. |
| `strategy_time_exit_h` | `21` | 0-23 | Broker-hour discretionary flat time for open runners. |
| `strategy_asia_start_h` | `0` | 0-23 | Broker-hour start used for Asia-range liquidity. |
| `strategy_asia_end_h` | `8` | 0-23 | Broker-hour end used for Asia-range liquidity. |
| `strategy_pivot_left_bars` | `2` | 1+ | Bars older than a candidate pivot used to confirm swing structure. |
| `strategy_pivot_right_bars` | `2` | 1+ | Bars newer than a candidate pivot used to confirm swing structure. |
| `strategy_pool_lookback_m15` | `96` | 10+ | M15 bars covering the card's last 24 H1 bars for pivot-pool search. |
| `strategy_mss_max_bars` | `8` | 1+ | Maximum M15 bars allowed between sweep and MSS close. |
| `strategy_limit_valid_bars` | `12` | 1+ | M15 bars before the OTE pending limit expires. |
| `strategy_atr_period` | `14` | 1+ | ATR period for stop buffer and max-risk filter. |
| `strategy_ote_leg_fraction` | `0.295` | 0-1 | Entry location above the long sweep extreme; mirrors for shorts. |
| `strategy_stop_atr_buffer` | `0.30` | 0+ | ATR multiple beyond the sweep extreme for the stop. |
| `strategy_max_risk_atr` | `1.50` | 0+ | Skip entries whose entry-to-stop distance exceeds this ATR multiple. |
| `strategy_runner_rr` | `2.50` | 0+ | Runner target in R after the TP1 partial. |
| `strategy_partial_fraction` | `0.50` | 0-1 | Fraction closed at TP1. |
| `strategy_max_spread_points` | `0.0` | 0+ | Optional spread cap; zero disables the extra strategy cap. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Primary card market for gold ICT liquidity sweeps.
- `NDX.DWX` - R3 PASS portable index symbol named by the approved card.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - not available to the DWX backtest terminals.
- Non-M15 setfile periods - the card specifies M15 execution.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` previous-day high/low; M15-derived 24 H1-bar liquidity window |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_signal_tf)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Intraday, pending limit valid 12 M15 bars and runner flat at broker 21:00 |
| Expected drawdown profile | Around 10% expected max drawdown from card frontmatter |
| Regime preference | Liquidity sweep with displacement / volatility expansion |
| Win rate target (qualitative) | Medium; deeper OTE entry targets higher R with lower fill rate |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ict-2022-model-canonical-2026-06-12`
**Source type:** video / public ICT material
**Pointer:** `https://www.youtube.com/@InnerCircleTrader` and `artifacts/cards_approved/QM5_12537_ict-ote-displacement-xau.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12537_ict-ote-displacement-xau.md`

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
| v1 | 2026-06-12 | Initial build from card | 7936cff7-c000-434c-a7e1-2cf8df7b5791 |
