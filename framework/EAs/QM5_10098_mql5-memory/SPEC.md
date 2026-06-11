# QM5_10098_mql5-memory - Strategy Spec

**EA ID:** QM5_10098
**Slug:** `mql5-memory`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `sources/mql5-examples`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA stores bullish or bearish market-memory zones after either a closed-bar structure break or a liquidity sweep of a recent swing high or low. A buy is opened when price returns into an unexpired bullish zone and the lower timeframe confirms upward continuation; a sell is opened under the mirrored bearish conditions. Stops sit beyond the source zone or swept extreme with an ATR buffer. Targets use the next opposing swing when it is usable, then a midpoint extension, then a fixed 2R fallback.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ltf` | `PERIOD_M5` | `M1`-`H1` | Lower timeframe used for directional closed-candle confirmation before zone entry. |
| `strategy_swing_bars` | `3` | `1`-`10` | Bars on each side required to confirm a swing high or swing low. |
| `strategy_scan_bars` | `160` | `30`-`500` | Closed bars scanned once per new bar for structural breaks and sweeps. |
| `strategy_atr_period` | `14` | `2`-`100` | ATR period for the stop buffer around the memory zone. |
| `strategy_atr_buffer_mult` | `0.50` | `0.10`-`5.00` | ATR multiple added beyond the zone invalidation side. |
| `strategy_zone_expiry_hours` | `12` | `1`-`72` | Maximum age of an untriggered memory zone. |
| `strategy_max_trades_per_day` | `3` | `1`-`20` | Daily entry cap per symbol and magic. |
| `strategy_midpoint_extension_mult` | `1.0` | `0.0`-`5.0` | Zone-height extension from midpoint when no opposing swing target is usable. |
| `strategy_fallback_rr` | `2.0` | `0.5`-`10.0` | Fixed R multiple used when no source target is available. |
| `strategy_spread_cap_points` | `0` | `0`-`500` | Optional spread cap; `0` disables the card-neutral spread guard. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid DWX forex pair with OHLC/ATR data for swing-zone tests.
- `GBPUSD.DWX` - card target; liquid DWX forex pair with similar structure and sweep behavior.
- `XAUUSD.DWX` - card target; DWX metal symbol where liquidity sweeps and retests are common.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline use the `.DWX` research/backtest namespace only.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no broker/tester data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `M5` lower-timeframe confirmation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Intraday; up to the 12-hour zone expiry plus SL/TP resolution |
| Expected drawdown profile | Event-driven pullback losses clustered around failed memory-zone invalidations |
| Regime preference | Liquidity sweep, supply-demand retest, and volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** MQL5 article
**Pointer:** Hlomohang John Borotho, "Automating Market Memory Zones Indicator: Where Price is Likely to Return", MQL5 Articles, 2026, https://www.mql5.com/en/articles/21255
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10098_mql5-memory.md`

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
| v1 | 2026-06-12 | Initial build from card | 42e476a6-2734-4aa1-8637-ba99684c2a75 |
