# QM5_9988_tv-opening-range-breakout-dual - Strategy Spec

**EA ID:** QM5_9988
**Slug:** `tv-opening-range-breakout-dual`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA tracks two opening ranges on M15 bars for each broker day. OR1 records the high and low of the short early window, and OR2 records the high and low of the longer window. After a range window ends, a long entry fires when an M15 bar closes above that range high, and a short entry fires when an M15 bar closes below that range low. Each OR side has its own magic slot and is disarmed after its first entry for the session; any open positions are closed at the configured session end if SL or TP has not already closed them.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_use_symbol_session_defaults` | `true` | `true/false` | Use built-in broker-time session defaults by symbol class. |
| `strategy_or1_start_hhmm` | `800` | `0000-2359` | Manual OR1 start time when symbol defaults are disabled. |
| `strategy_or1_end_hhmm` | `830` | `0000-2359` | Manual OR1 end time when symbol defaults are disabled. |
| `strategy_or2_start_hhmm` | `800` | `0000-2359` | Manual OR2 start time when symbol defaults are disabled. |
| `strategy_or2_end_hhmm` | `900` | `0000-2359` | Manual OR2 end time when symbol defaults are disabled. |
| `strategy_session_end_hhmm` | `2100` | `0000-2359` | Manual forced-flat time when symbol defaults are disabled. |
| `strategy_enable_long_or1` | `true` | `true/false` | Allow OR1 close-above-range long entries. |
| `strategy_enable_short_or1` | `true` | `true/false` | Allow OR1 close-below-range short entries. |
| `strategy_enable_long_or2` | `true` | `true/false` | Allow OR2 close-above-range long entries. |
| `strategy_enable_short_or2` | `true` | `true/false` | Allow OR2 close-below-range short entries. |
| `strategy_sl_mode` | `1` | `0,1,2` | Initial SL mode: fixed pips, OR range multiple, or ATR multiple. |
| `strategy_tp_mode` | `1` | `0,1,2` | TP mode: fixed pips, OR range multiple, or ATR multiple. |
| `strategy_fixed_sl_pips` | `50` | `>0` | Fixed-pips SL distance for `strategy_sl_mode=0`. |
| `strategy_fixed_tp_pips` | `100` | `>0` | Fixed-pips TP distance for `strategy_tp_mode=0`. |
| `strategy_atr_period` | `14` | `>0` | M15 ATR period for ATR SL/TP and flat-range guard. |
| `strategy_sl_range_mult` | `0.5` | `>0` | SL distance as a multiple of the triggering OR range. |
| `strategy_tp_range_mult` | `1.0` | `>0` | TP distance as a multiple of the triggering OR range. |
| `strategy_sl_atr_mult` | `1.0` | `>0` | SL distance as a multiple of ATR when ATR SL mode is active. |
| `strategy_tp_atr_mult` | `2.0` | `>0` | TP distance as a multiple of ATR when ATR TP mode is active. |
| `strategy_flat_or_atr_mult` | `0.3` | `>=0` | Skip an OR if its range is below this multiple of ATR. |
| `strategy_spread_sl_mult` | `0.3` | `>=0` | Skip entry if modeled spread is wider than this share of initial SL distance. |
| `strategy_max_concurrent_per_symbol` | `2` | `0-4` | Maximum simultaneous open OR slots per symbol; `0` disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - direct DWX analog for the source USO oil ETF instrument.
- `NDX.DWX` - liquid US large-cap index target listed in the approved card.
- `WS30.DWX` - liquid US large-cap index target listed in the approved card.
- `XAUUSD.DWX` - liquid commodity market listed in the approved card.
- `EURUSD.DWX` - explicit FX-major target from the card's target-symbol list.
- `GBPUSD.DWX` - explicit FX-major target from the card's target-symbol list.
- `SP500.DWX` - supplementary S&P 500 backtest target; valid for P2 but not broker-routable live.

**Explicitly NOT for:**
- `USO`, `SPY`, `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX backtest symbols for this build.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable in the factory symbol universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | Intraday; minutes to same-session close |
| Expected drawdown profile | Bounded by initial SL on each OR slot |
| Regime preference | Breakout / volatility expansion after session open |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView public script
**Pointer:** `https://www.tradingview.com/script/9f62cUq1-Opening-Range-UltraPro-Max-Plus/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9988_tv-opening-range-breakout-dual.md`

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
| v1 | 2026-06-20 | Initial build from card | 8a710b66-8b15-45a4-8ea5-1ee54b23184c |
