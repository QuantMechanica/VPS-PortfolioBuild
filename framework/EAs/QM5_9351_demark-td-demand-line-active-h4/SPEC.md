# QM5_9351_demark-td-demand-line-active-h4 - Strategy Spec

**EA ID:** QM5_9351
**Slug:** `demark-td-demand-line-active-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

The EA trades DeMark active TD-line breaks on closed H4 bars. It finds the two most recent TD supply pivots and demand pivots, continuously re-anchors the active line, and enters when the latest H4 close cleanly breaks that line by 0.10 ATR after the prior bar had not broken it. Long trades break an active supply line; short trades break an active demand line. The initial stop uses the three-bar extreme around the break plus 0.30 ATR, the target uses DeMark's projector distance to the opposite recent pivot, and positions are time-stopped after 40 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 | Timeframe for pivots, line breaks, ATR, and time stop. |
| `strategy_scan_bars` | `120` | 20-300 | Closed H4 bars scanned for the two most recent TD pivots. |
| `strategy_atr_period` | `14` | 5-50 | ATR period for entry buffer, spread cap, and SL buffer. |
| `strategy_min_line_age_bars` | `3` | 1-20 | Minimum bars since the latest TD pivot before a line may break. |
| `strategy_break_atr_mult` | `0.10` | 0.05-0.50 | ATR penetration required beyond the active TD line. |
| `strategy_sl_atr_buffer` | `0.30` | 0.10-1.00 | ATR buffer beyond the three-bar SL extreme. |
| `strategy_spread_atr_mult` | `0.15` | 0.05-0.50 | Maximum modeled spread as a fraction of H4 ATR; zero spread is allowed. |
| `strategy_time_stop_bars` | `40` | 10-80 | H4 bars after which an open position is closed at market. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major for TD-line price structure.
- `GBPUSD.DWX` - liquid FX major for TD-line price structure.
- `USDJPY.DWX` - liquid FX major for TD-line price structure.
- `AUDUSD.DWX` - liquid FX major for TD-line price structure.
- `USDCAD.DWX` - liquid FX major for TD-line price structure.
- `USDCHF.DWX` - liquid FX major for TD-line price structure.
- `NZDUSD.DWX` - liquid FX major for TD-line price structure.
- `XAUUSD.DWX` - card-approved metal proxy for DeMark line breaks.
- `XTIUSD.DWX` - card-approved oil CFD for non-index commodity diversity.
- `NDX.DWX` - major index CFD validation proxy.
- `WS30.DWX` - major index CFD validation proxy.
- `GDAXI.DWX` - major European index CFD validation proxy.
- `UK100.DWX` - major European index CFD validation proxy.
- `SP500.DWX` - backtest-only S&P 500 custom symbol, never live-routed.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must keep the `.DWX` suffix.
- Symbols without reliable H4 OHLC history - the strategy requires closed-bar pivots.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | 1-7 trading days, capped at 40 H4 bars |
| Expected drawdown profile | Moderate breakout whipsaw risk, bounded by structural SL |
| Regime preference | Trendline breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum plus published technical-analysis books
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9351_demark-td-demand-line-active-h4.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9351_demark-td-demand-line-active-h4.md`

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
| v1 | 2026-07-09 | Initial build from card | 0149bcd6-6d80-4e10-8718-05a055c10a2c |
