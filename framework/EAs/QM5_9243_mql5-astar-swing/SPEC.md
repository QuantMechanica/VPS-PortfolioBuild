# QM5_9243_mql5-astar-swing - Strategy Spec

**EA ID:** QM5_9243
**Slug:** `mql5-astar-swing`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

On each new H1 bar, the EA scans recent closed bars for valid swing highs and lows using a five-bar swing lookback, a minimum three-bar spacing between swing nodes, and a maximum of 100 nodes. A swing high is rejected if a later close moved above it, and a swing low is rejected if a later close moved below it. The remaining swings form a graph with neighbor and skip-one edges; edge cost is ATR-normalized price distance plus spread and same-type swing penalties. The EA opens long when the best A* path to an overhead swing target has at least 0.55 upward directional ratio, cost no greater than 5.0 ATR, and no adverse one-ATR blockade; it opens short on the symmetric downward path. The target is the final A* target node, the stop is the previous opposing swing plus or minus 0.5 ATR(14), and positions close on opposite qualified path or after 72 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_swing_lookback` | 5 | >=2 | Bars on each side required to confirm a swing high or low. |
| `strategy_max_nodes` | 100 | >=8 | Maximum number of valid swing nodes included in the path graph. |
| `strategy_min_swing_bars` | 3 | >=1 | Minimum bar spacing between accepted swing nodes. |
| `strategy_atr_period` | 14 | >=1 | ATR period used for edge cost and stop buffer. |
| `strategy_spread_penalty` | 1.5 | >=0.0 | Edge-cost penalty scaled by current spread. |
| `strategy_noise_penalty` | 0.5 | >=0.0 | Edge-cost penalty for same-type swing connections. |
| `strategy_max_path_cost_atr` | 5.0 | >0.0 | Maximum qualified A* path cost in ATR units. |
| `strategy_min_direction_ratio` | 0.55 | >0.0 | Required share of path edges moving in the trade direction. |
| `strategy_stop_atr_buffer_mult` | 0.5 | >0.0 | ATR buffer beyond the previous opposing swing for SL placement. |
| `strategy_max_hold_bars` | 72 | >0 | Maximum H1 bars to hold a position. |
| `strategy_max_spread_points` | 40 | >=0 | Maximum modeled spread in points; zero spread is allowed. |
| `strategy_scan_bars` | 260 | >=32 | Closed-bar history window used for swing graph construction. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid major FX pair with H1 OHLC, spread, and ATR data.
- `GBPJPY.DWX` - card target; liquid JPY cross with H1 swing structure and ATR data.
- `XAUUSD.DWX` - card target; gold symbol with H1 swing structure and ATR data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for Darwinex `.DWX` backtesting.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | `Up to 72 H1 bars` |
| Expected drawdown profile | `Swing-path trades with structural SLs should have moderate, clustered drawdowns in choppy ranges.` |
| Regime preference | `market-structure swing/trend continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/22184`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9243_mql5-astar-swing.md`

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
| v1 | 2026-06-20 | Initial build from card | 772a51f8-5365-4de0-b27c-7830b8ddb086 |
