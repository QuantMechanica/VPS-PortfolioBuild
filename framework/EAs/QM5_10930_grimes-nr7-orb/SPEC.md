# QM5_10930_grimes-nr7-orb - Strategy Spec

**EA ID:** QM5_10930
**Slug:** `grimes-nr7-orb`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades an M15 opening-range breakout only when the prior completed D1 bar is NR7, meaning its true range is the narrowest of the last seven completed D1 bars. After the first four M15 bars of the broker day close, a long setup requires the session open or first M15 close to be above the prior D1 high, with none of those first four closes back below that prior high. A short setup mirrors the rule around the prior D1 low. Entry is triggered at the opening-range high or low plus/minus 0.1 * ATR(20), stop is outside the other side of the opening range by 0.2 * ATR(20), target is 2R, stop moves to breakeven at 1R, trails by the prior three M15 bars after 1.5R, and open trades are closed two M15 bars before broker day end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | `> 0` | ATR period used for entry buffer, stop buffer, and opening-range height filter. |
| `strategy_nr7_lookback_days` | 7 | `>= 2` | Completed D1 bars used to test the NR7 prior-day condition. |
| `strategy_opening_range_bars` | 4 | `>= 1` | Number of first-session M15 bars used to build the opening range. |
| `strategy_entry_buffer_atr_mult` | 0.10 | `>= 0` | ATR multiple added beyond the opening-range edge for the breakout trigger. |
| `strategy_stop_buffer_atr_mult` | 0.20 | `>= 0` | ATR multiple beyond the opposite opening-range edge for the stop. |
| `strategy_max_open_range_atr_mult` | 2.00 | `> 0` | Reject setup if opening-range height is greater than this ATR multiple. |
| `strategy_target_r_mult` | 2.00 | `> 0` | Take-profit distance as a multiple of initial risk. |
| `strategy_breakeven_trigger_r` | 1.00 | `> 0` | R multiple that moves stop to entry price. |
| `strategy_trail_trigger_r` | 1.50 | `>= breakeven trigger` | R multiple that activates the prior-three-bar trailing stop. |
| `strategy_trail_lookback_bars` | 3 | `>= 1` | Closed M15 bars used for the trailing stop. |
| `strategy_spread_stop_fraction` | 0.10 | `> 0` | Skip entry if spread exceeds this fraction of stop distance. |
| `strategy_exit_bars_before_day_end` | 2 | `>= 1` | Close open trades this many M15 bars before broker midnight. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index exposure explicitly named by the card; backtest-only per DWX discipline.
- `NDX.DWX` - US large-cap technology index exposure in the card's portable basket.
- `WS30.DWX` - US large-cap Dow index exposure in the card's portable basket.
- `GDAXI.DWX` - registered DAX 40 custom symbol used as the available DWX equivalent for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_D1` for the prior-day NR7 condition |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | Intraday, from opening-range breakout until 2R, trailing stop, or two M15 bars before broker day end. |
| Expected drawdown profile | Breakout strategy with clustered losses during false opening breaks. |
| Regime preference | Volatility-expansion / breakout after prior-day compression. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** blog
**Pointer:** Adam H. Grimes, "NR7: an old friend", 2015-11-10, https://www.adamhgrimes.com/nr7-an-old-friend/ and "Daytrading the S&P 500: Intraday trend structure and setup", 2019-05-21, https://www.adamhgrimes.com/daytrading-the-sp-500-intraday-trend-structure-and-setup/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10930_grimes-nr7-orb.md`

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
| v1 | 2026-06-06 | Initial build from card | f696f9a6-0930-47fe-ad54-baca63322fd7 |
