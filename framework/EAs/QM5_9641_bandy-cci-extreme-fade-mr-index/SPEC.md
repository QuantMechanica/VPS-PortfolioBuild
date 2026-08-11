# QM5_9641_bandy-cci-extreme-fade-mr-index — Strategy Spec

**EA ID:** QM5_9641
**Slug:** `bandy-cci-extreme-fade-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press 2015, ISBN 978-0-9791037-7-1 — CCI mean-reversion exemplar with a long-SMA regime gate on US equity-index proxies)
**Author of this spec:** Claude (capacity-spilled build_ea)
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Daily-bar, long-only mean-reversion fade on index CFDs. On every closed D1 bar the
EA computes the Lambert CCI(20) (typical-price formulation) and a 200-day close
SMA regime gate. It enters LONG at the next session open when CCI(20) is at or
below -100 (a deep oversold stretch) AND the close is above the 200-day SMA (the
empirically motivated bull-regime filter — raw CCI extremes are noise-dominated in
bear regimes). The short side is disabled entirely. A position exits when CCI(20)
crosses back to its zero line (>= 0, take-profit), after a 7-trading-day time stop,
or on a broker-side hard stop set at entry to 2.5 * ATR(14, D1). Two filters guard
new entries: a bespoke "no-trade-on-chaos" rule that skips entry when ATR(14)/close
sits in the top 1st percentile of the trailing 252 bars, and a ±30-minute
high-impact news blackout. One position per magic; no pyramiding. All indicator
and percentile state is computed once per closed D1 bar and cached; the per-tick
path only reads cached state and the current Ask/Bid.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 20 | 10-40 | Lambert CCI period (D1, typical price). |
| `strategy_cci_entry` | -100.0 | -200..-50 | Enter long when CCI <= this threshold. |
| `strategy_cci_exit` | 0.0 | -20..+50 | Take-profit when CCI crosses back to >= this (zero line). |
| `strategy_regime_ma_period` | 200 | 100-300 | Long-only regime gate: SMA(Close, N, D1). |
| `strategy_atr_period` | 14 | 5-30 | ATR period (D1) for the stop-distance basis. |
| `strategy_atr_sl_mult` | 2.5 | 1.0-5.0 | Hard SL = entry - mult * ATR(14, D1). |
| `strategy_time_stop_days` | 7 | 3-21 | Force exit after N closed D1 bars in trade. |
| `strategy_vol_lookback` | 252 | 60-504 | Trailing-window length for the chaos percentile filter. |
| `strategy_vol_top_pctile` | 1.0 | 0.5-5.0 | Skip new entry if ATR/close is in the top N-th percentile of the window. |

Framework inputs of note: `qm_news_temporal = QM_NEWS_TEMPORAL_PRE30_POST30`
(card: skip new entries within ±30 min of high-impact NFP/FOMC/CPI releases) with
`qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ` (live-venue overlay), and
`qm_friday_close_enabled = false` (a daily MR hold spans up to 7 trading days
across weekends; a Friday flatten would truncate every multi-day hold). The news
gate sits on the entry path only and never suspends management/exits.

---

## 3. Symbol Universe

Registered (all present in `dwx_symbol_matrix.csv` with the correct `.DWX`
suffix), slots 0-2 — the full US large-cap index basket per the P2 Saturation Rule:

- `SP500.DWX` (slot 0) — S&P 500; the card's primary index (OWNER-provided Custom
  Symbol ticks 2018-07→2026-05); Bandy's canonical US-equity-index proxy.
- `NDX.DWX` (slot 1) — Nasdaq 100; live-tradable growth index; parallel-validation
  target for the T_Live promotion gate.
- `WS30.DWX` (slot 2) — Dow 30; live-tradable broad US large-cap index; second
  parallel-validation target.

All three are index CFDs whose regime/oscillator dynamics are sufficiently similar
that the same CCI(20)/SMA200 rule ports directly (card R3 PASS). SP500.DWX is
backtest-primary; NDX/WS30 are live-routable and are registered regardless per the
P2 saturation rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (all CCI / SMA200 / ATR / vol-percentile state on `PERIOD_D1`) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` — state advances once per closed D1 bar; per-tick path reads cached state only |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~7` (card `expected_trades_per_year_per_symbol: 7`) |
| Typical hold time | `a few days up to a 7-trading-day time stop` |
| Expected drawdown profile | `~18% expected DD (card expected_dd_pct: 18.0)` |
| Regime preference | `mean-reversion inside a confirmed bull regime (close > SMA200)` |
| Expected PF (card) | `~1.18 (card expected_pf: 1.18)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** `book`
**Pointer:** `Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press (2015), ISBN 978-0-9791037-7-1 — CCI(±100) mean-reversion exemplar paired with a long-SMA regime gate on US equity-index proxies`
**R1 lineage recorded and R2-R4 PASS** per `artifacts/cards_approved/QM5_9641_bandy-cci-extreme-fade-mr-index.md`.

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
| v1 | 2026-08-11 | Initial build from card | build task fead18b1-3859-48aa-a192-0eb7c1a79530 |
