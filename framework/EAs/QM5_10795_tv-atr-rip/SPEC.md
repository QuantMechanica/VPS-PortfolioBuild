# QM5_10795_tv-atr-rip — Strategy Spec

**EA ID:** QM5_10795
**Slug:** `tv-atr-rip`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

Short-only mean-reversion that "sells the rip". On each closed bar the EA builds
a raw trigger series `raw[k] = close[k] + ATR(atr_period)[k] * atr_mult` and
smooths it with a simple moving average over `smooth_period` bars. When the last
closed-bar close pushes ABOVE that smoothed trigger — i.e. price is stretched
more than a (smoothed) ATR above its recent closes — the EA opens a short at
market. An optional EMA(200) filter restricts shorts to price below the EMA. The
position is closed when the close falls back below the previous bar's low (the
source reversal exit), after a fixed number of bars (time exit), or at a
mandatory hard ATR safety stop placed `sl_atr_mult × ATR(sl_atr_period)` above
entry. Friday-close flat is handled by the framework.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `trig_atr_period` | 20 | 14-30 | ATR period used in the raw trigger |
| `trig_atr_mult` | 1.0 | 0.75-1.5 | ATR multiplier added to close in the raw trigger |
| `smooth_period` | 10 | 5-20 | SMA length smoothing the raw trigger |
| `sl_atr_period` | 20 | 14-30 | ATR period for the hard safety stop |
| `sl_atr_mult` | 2.0 | 1.5-3.0 | Hard-stop distance in ATR units (above entry) |
| `time_stop_bars` | 10 | 0-40 | Bars-held time exit (0 disables); 10 D1 / 40 H1 |
| `use_ema_filter` | false | bool | Require close below EMA(200) to short |
| `ema_filter_period` | 200 | 50-300 | EMA trend-filter period |
| `use_session_filter` | false | bool | Restrict entries to a broker-hour window |
| `session_start_hour` | 0 | 0-23 | Session window start (broker hour) |
| `session_end_hour` | 24 | 1-24 | Session window end (broker hour, exclusive) |

---

## 3. Symbol Universe

**Designed for** (card §R3 portable basket):
- `EURUSD.DWX` — major FX, deep liquidity, clean mean-reversion behaviour.
- `GBPUSD.DWX` — major FX, sharp intraday rips suit the fade.
- `USDJPY.DWX` — major FX, trend/range alternation gives overextensions.
- `XAUUSD.DWX` — gold, high-ATR spikes are prime "rip" candidates.
- `GDAXI.DWX` — DAX 40; card said `GER40.DWX` (not in matrix) → ported to the
  canonical DAX symbol `GDAXI.DWX`.
- `NDX.DWX` — Nasdaq 100, live-routable US large-cap index.
- `WS30.DWX` — Dow 30, live-routable US large-cap index.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker does not route orders); not in this EA's
  registered basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~35` |
| Typical hold time | `a few days to ~10 D1 bars` |
| Expected drawdown profile | `squeeze risk on shorts; bounded by hard ATR stop` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `forum` (TradingView open-source script page)
**Pointer:** TradingView script `ylozoEOC` "[SHORT ONLY] ATR Sell the Rip Mean
Reversion Strategy", author `Botnet101`, published 2025-02-16.
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_10795_tv-atr-rip.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-05 | Initial build from card | d1f913c3-f456-4e31-8389-50933a5cd045 |
