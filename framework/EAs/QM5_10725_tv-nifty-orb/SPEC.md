# QM5_10725_tv-nifty-orb - Strategy Spec

**EA ID:** QM5_10725
**Slug:** `tv-nifty-orb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-01

---

## 1. Strategy Logic

The EA trades a one-minute opening-range breakout. It builds the range from the first five M1 candles after the local cash-market open, then arms buy-stop and sell-stop orders at the range boundary plus or minus 0.05 ATR(14), using an immediate market entry only when the trigger is already crossed at the first eligible bar. The initial stop uses the available opening-range boundary plus the latest three closed M1 candles as the structure proxy, trades are skipped when the stop distance is outside 0.25-2.5 ATR(14), and the initial take profit is 2R. At +1R the EA closes half, moves the stop to breakeven, and then closes the remainder if price touches EMA(20); any open trade is forced flat at the configured session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_or_bars` | 5 | 1-60 | Count of M1 bars used to form the opening range. |
| `strategy_atr_period` | 14 | >=1 | ATR period for entry buffer and stop-distance filters. |
| `strategy_buffer_atr_mult` | 0.05 | >=0 | ATR multiple added outside the opening range before a breakout qualifies. |
| `strategy_min_stop_atr_mult` | 0.25 | >=0 | Minimum allowed stop distance as an ATR multiple. |
| `strategy_max_stop_atr_mult` | 2.5 | >0 | Maximum allowed stop distance as an ATR multiple. |
| `strategy_ema_trail_period` | 20 | >=1 | EMA period used as the post-1R trailing exit line. |
| `strategy_rr_target` | 2.0 | >0 | Fixed take-profit multiple of initial risk. |
| `strategy_partial_close_fraction` | 0.50 | 0-1 | Fraction of current volume to close at +1R. |
| `strategy_session_start_override` | -1 | -1 or HHMM | Optional broker-time session start override; -1 uses symbol defaults. |
| `strategy_session_end_override` | -1 | -1 or HHMM | Optional broker-time session end override; -1 uses symbol defaults. |
| `strategy_max_spread_points` | 0.0 | >=0 | Optional spread ceiling in points; 0 disables the spread ceiling. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index CFD; liquid US index proxy for the Nifty ORB mechanics.
- `WS30.DWX` - Dow 30 index CFD; liquid US index proxy in the approved portable basket.
- `GDAXI.DWX` - Available DAX custom symbol; used as the DWX equivalent for card-stated `GER40.DWX`.
- `UK100.DWX` - FTSE 100 index CFD in the card's portable global index basket.
- `SP500.DWX` - S&P 500 custom symbol; valid for backtest-only build registration.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX custom symbol.
- `NIFTY.DWX` - not present in the DWX symbol matrix; the card explicitly ports the mechanics to liquid DWX index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | Intraday, from opening-range breakout until 2R, EMA(20) trail touch, stop loss, or session-end close. |
| Expected drawdown profile | Early-session breakout system with losses clustered during failed morning moves. |
| Regime preference | Intraday volatility-expansion breakout. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView protected-source strategy`
**Pointer:** `https://www.tradingview.com/script/RrT9ypRF-Nifty-ORB-1min-timeframe/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10725_tv-nifty-orb.md`

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
| v1 | 2026-06-01 | Initial build from card | 267dd257-eb3d-44b4-ae8f-93ce66694db3 |
