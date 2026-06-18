# QM5_1234_ict-golden-bullet - Strategy Spec

**EA ID:** QM5_1234
**Slug:** ict-golden-bullet
**Source:** fa90d4d7-7a46-5439-9ff6-96ee841913b3
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades the ICT Golden Bullet afternoon session. It builds a New York 12:00-12:59 reference range on M5, combines that with the previous completed H1 candle, then watches the 13:00-13:59 New York window for a sweep of either side of liquidity. A short setup requires a buy-side sweep, a close back below liquidity, and a bearish fair-value gap; a long setup mirrors that below sell-side liquidity. Entries are limit orders at the midpoint of the gap, with structure-based stops, nearest opposing reference-range target when reward/risk is sufficient, otherwise a fixed 2R target, and a 14:55 New York time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | M5 only for this card | Base timeframe for session range, sweep, FVG, and entry evaluation |
| `strategy_ny_entry_start_hhmm` | `1300` | 0000-2359 | New York session start for arming entries |
| `strategy_ny_entry_end_hhmm` | `1400` | 0000-2359 | New York session end; pending orders are cancelled after this time |
| `strategy_ny_time_exit_hhmm` | `1455` | 0000-2359 | New York time exit for any open position |
| `strategy_reference_start_hhmm` | `1200` | 0000-2359 | Start of the M5 reference range |
| `strategy_reference_end_hhmm` | `1300` | 0000-2359 | End of the M5 reference range |
| `strategy_sweep_buffer_points` | `5` | >=0 | Minimum liquidity sweep beyond the reference level, in points |
| `strategy_stop_buffer_points` | `5` | >=0 | Stop buffer beyond the sweep/FVG stop side, in points |
| `strategy_min_stop_points` | `25` | >=1 | Minimum accepted stop distance in points |
| `strategy_atr_period_m5` | `14` | >=1 | M5 ATR period used by stop and volatility filters |
| `strategy_atr_period_h1` | `14` | >=1 | H1 ATR period used by the session-range quality filter |
| `strategy_max_stop_atr_mult` | `1.50` | >0 | Maximum stop distance as a multiple of M5 ATR |
| `strategy_min_reward_risk` | `1.50` | >0 | Minimum reward/risk required for the range swing target |
| `strategy_take_profit_rr` | `2.00` | >0 | Fallback target in R multiples |
| `strategy_max_displacement_bars` | `3` | >=1 | Number of M5 bars allowed after the sweep for displacement/FVG confirmation |
| `strategy_min_range_atr_h1_mult` | `0.30` | >=0 | Minimum 12:00-13:00 range as a multiple of H1 ATR |
| `strategy_min_atr_m5_mult` | `0.50` | >=0 | Minimum current M5 ATR versus same-slot historical median |
| `strategy_atr_median_days` | `20` | 1-20 | Historical daily samples for the ATR filter |
| `strategy_max_spread_points` | `35` | >=0 | Absolute spread cap in points; zero-spread tester quotes are allowed |
| `strategy_max_spread_mult` | `2.50` | >=0 | Spread cap versus same-hour median spread |
| `strategy_spread_median_days` | `20` | >=1 | Historical days used for same-hour median spread |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX symbol with M5/H1 DWX data.
- `GBPUSD.DWX` - card-listed liquid FX symbol with M5/H1 DWX data.
- `USDJPY.DWX` - card-listed liquid FX symbol with M5/H1 DWX data.
- `AUDUSD.DWX` - card-listed liquid FX symbol with M5/H1 DWX data.
- `USDCAD.DWX` - card-listed liquid FX symbol with M5/H1 DWX data.
- `NZDUSD.DWX` - card-listed liquid FX symbol with M5/H1 DWX data.
- `XAUUSD.DWX` - card-listed metal CFD with M5/H1 DWX data.
- `XTIUSD.DWX` - card-listed oil CFD with M5/H1 DWX data.
- `NDX.DWX` - card-listed US index CFD with M5/H1 DWX data.
- `WS30.DWX` - card-listed US index CFD with M5/H1 DWX data.
- `GDAXI.DWX` - card-listed DAX index CFD with M5/H1 DWX data.
- `UK100.DWX` - card-listed FTSE index CFD with M5/H1 DWX data.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - the build only registers verified DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | Previous completed `H1` candle and `H1` ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Intraday; entries during 13:00-14:00 New York and forced exit at 14:55 New York |
| Expected drawdown profile | Stop-defined, single-position-per-magic afternoon session exposure |
| Regime preference | New York PM liquidity sweep with displacement and volatility expansion |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fa90d4d7-7a46-5439-9ff6-96ee841913b3
**Source type:** public strategy article / OWNER-requested ICT Bullet source
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1234_ict-golden-bullet.md`; primary URL `https://www.babypips.com/learn/forex/ict-silver-bullet`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1234_ict-golden-bullet.md`

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
| v1 | 2026-06-18 | Initial build from card | 1385918e-e676-4e18-8580-355a8652670f |
