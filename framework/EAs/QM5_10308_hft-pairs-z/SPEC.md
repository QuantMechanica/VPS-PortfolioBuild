# QM5_10308_hft-pairs-z - Strategy Spec

**EA ID:** QM5_10308
**Slug:** `hft-pairs-z`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9` (see SSRN microstructure/HFT source)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades short-term mean reversion between preselected, correlated DWX pairs. On each M5 bar it reads the host symbol and its mapped peer, computes rolling return correlation, estimates a beta-normalized spread, and converts the spread into a z-score. If the spread z-score is at or beyond +2.0 the host leg is sold; if it is at or beyond -2.0 the host leg is bought. The position exits when the spread mean-reverts to `abs(z) <= 0.25`, reaches the emergency stop threshold, exceeds the 24-bar hold limit, or leaves the first liquid session block.

The card describes two-leg synthetic execution. This implementation runs one instance per host symbol and trades the primary host leg while reading the peer leg for the spread signal, matching the card's reviewer-escalation fallback for V5 single-position execution.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf` | `PERIOD_M5` | M5 intended | Signal timeframe. |
| `strategy_formation_bars` | `17280` | >= 50 | Formation window for pair correlation and beta. |
| `strategy_z_bars` | `5760` | 20 to formation window | Rolling spread window used for z-score mean and standard deviation. |
| `strategy_min_corr` | `0.80` | 0.0 to 1.0 | Minimum rolling return correlation before entries are allowed. |
| `strategy_entry_z` | `2.0` | > exit z | Absolute z-score entry threshold. |
| `strategy_exit_z` | `0.25` | 0 to entry z | Absolute z-score exit threshold after mean reversion. |
| `strategy_stop_z` | `3.5` | > entry z | Emergency spread stop threshold. |
| `strategy_max_hold_bars` | `24` | >= 1 | Maximum M5 bars to hold a position. |
| `strategy_atr_period` | `14` | >= 2 | ATR period for per-leg catastrophic stop. |
| `strategy_atr_sl_mult` | `2.0` | > 0 | ATR multiple for stop placement. |
| `strategy_session_start_hour` | `13` | 0-23 broker time | Start of the liquid session block. |
| `strategy_session_start_minute` | `0` | 0-59 | Minute offset for session start. |
| `strategy_session_minutes` | `180` | > last-entry block | Total trading session length. |
| `strategy_no_entry_last_minutes` | `30` | >= 0 | Blocks new entries near the end of the session. |
| `strategy_max_cost_fraction` | `0.20` | 0 to 1 | Maximum spread cost as fraction of expected reversion distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - host leg for the EURUSD/GBPUSD FX pair.
- `GBPUSD.DWX` - host leg for the GBPUSD/EURUSD FX pair.
- `AUDUSD.DWX` - host leg for the AUDUSD/NZDUSD FX pair.
- `NZDUSD.DWX` - host leg for the NZDUSD/AUDUSD FX pair.
- `SP500.DWX` - host leg for the SP500/NDX index pair; backtest-only at T6.
- `NDX.DWX` - host leg for the NDX/SP500 index pair.
- `XAUUSD.DWX` - host leg for the XAUUSD/XAGUSD metals pair.
- `XAGUSD.DWX` - host leg for the XAGUSD/XAUUSD metals pair.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - the EA needs native DWX M5 bars for both host and peer.
- Single symbols without a mapped peer - the spread and z-score cannot be computed.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_tf)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Intraday, up to 24 M5 bars |
| Expected drawdown profile | Small frequent losses when pair divergence continues beyond the emergency z-stop. |
| Regime preference | Intraday mean reversion in highly correlated pairs. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** paper
**Pointer:** SSRN paper "High Frequency Equity Pairs Trading: Transaction Costs, Speed of Execution and Patterns in Returns", David Bowen, Mark C. Hutchinson, Niall O'Sullivan, Journal of Trading, Summer 2010.
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10308_hft-pairs-z.md`

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
| v1 | 2026-06-26 | Initial spec backfill and Q02 zero-trade repair | ad67d4c4-6c91-4088-9e51-995bbfdacfc7 |
