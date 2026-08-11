# QM5_9501_pring-kst-w1 — Strategy Spec

**EA ID:** QM5_9501
**Slug:** `pring-kst-w1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (ForexFactory Trading Systems — Martin Pring long-term-KST thread cluster; Pring 1993 "Martin Pring on Market Momentum" ch. 8-9)
**Author of this spec:** Claude (capacity-spilled build_ea)
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Long-term (weekly) momentum system built on Martin Pring's Know-Sure-Thing (KST)
composite. On every closed W1 bar the EA reconstructs KST as a weighted sum of
four SMA-smoothed Rate-of-Change series — `KST = 1*SMA(ROC(9),6) +
2*SMA(ROC(12),6) + 3*SMA(ROC(18),6) + 4*SMA(ROC(24),9)` — and its signal line
`Signal = SMA(KST, 9)`. It goes LONG on the next W1 open when the weekly close is
above its 40-week SMA, KST crosses above Signal, and KST is in positive territory
(> 0); SHORT mirrors (close below the 40-week SMA, KST crosses below Signal, KST
< 0). A position exits on the opposite KST/Signal cross, on a 26-week time stop,
or on a broker-side hard stop set at entry to `3.0 * ATR(14, W1)`. A whipsaw
guard blocks any fresh entry within 4 W1 bars of a prior stop-loss exit, and an
entry is skipped if the spread exceeds `0.05 * ATR(14, W1)`. All indicator state
is computed once per closed W1 bar and cached; the per-tick path only reads
cached state and current Bid/Ask.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_roc1_period` | 9 | 4-40 | ROC lookback 1 (W1 bars). |
| `strategy_roc2_period` | 12 | 4-40 | ROC lookback 2 (W1 bars). |
| `strategy_roc3_period` | 18 | 4-52 | ROC lookback 3 (W1 bars). |
| `strategy_roc4_period` | 24 | 4-64 | ROC lookback 4 (W1 bars). |
| `strategy_rcma_short` | 6 | 2-20 | SMA smoothing applied to ROC1..ROC3. |
| `strategy_rcma_long` | 9 | 2-24 | SMA smoothing applied to ROC4. |
| `strategy_signal_period` | 9 | 2-24 | Signal line = SMA(KST, period). |
| `strategy_bias_ma_period` | 40 | 10-80 | 40-week close SMA regime/bias filter. |
| `strategy_atr_period` | 14 | 5-30 | ATR period (W1) for the stop-distance basis. |
| `strategy_atr_sl_mult` | 3.0 | 1.0-5.0 | Hard stop = entry -/+ mult * ATR(14, W1). |
| `strategy_time_stop_bars` | 26 | 8-52 | Force exit after N closed W1 bars in trade. |
| `strategy_reentry_block_bars` | 4 | 0-12 | No fresh entry within N W1 bars of an SL exit. |
| `strategy_spread_atr_frac` | 0.05 | 0.01-0.30 | Skip entry if spread > frac * ATR(14, W1). |

KST composite weights (1, 2, 3, 4) are Pring's canonical fixed constants that
define the indicator identity and are held as literals, not inputs. Framework
inputs of note: `qm_news_temporal = OFF` (card: news filter not applied to W1
entries) and `qm_friday_close_enabled = false` (a weekly position EA holds across
many Fridays; a Friday flatten would truncate every multi-week hold).

---

## 3. Symbol Universe

Registered (all present in `dwx_symbol_matrix.csv` with the correct `.DWX`
suffix), slots 0-12:

- `EURUSD.DWX` (slot 0) — deepest-liquidity major; long W1 history for the KST warmup.
- `GBPUSD.DWX` (slot 1) — liquid major; distinct business-cycle momentum.
- `USDJPY.DWX` (slot 2) — liquid major; strong multi-month trend legs suit W1 KST.
- `AUDUSD.DWX` (slot 3) — commodity-linked major; cyclical momentum.
- `USDCAD.DWX` (slot 4) — oil-linked major; adds macro-cycle diversity.
- `USDCHF.DWX` (slot 5) — safe-haven major; orthogonal trend timing.
- `NZDUSD.DWX` (slot 6) — commodity-linked major; complements AUD.
- `XAUUSD.DWX` (slot 7) — gold; long-cycle momentum instrument (metals).
- `XTIUSD.DWX` (slot 8) — WTI crude; business-cycle-sensitive energy leg.
- `GDAXI.DWX` (slot 9) — DAX 40; equity-index long-term momentum.
- `NDX.DWX` (slot 10) — Nasdaq 100; growth-index momentum.
- `WS30.DWX` (slot 11) — Dow 30; broad US large-cap momentum.
- `UK100.DWX` (slot 12) — FTSE 100; European equity-index momentum.

**Explicitly NOT registered (card-listed but absent from the matrix):**
- `FRA40.DWX` (CAC 40) — no French index CFD exists in `dwx_symbol_matrix.csv`; not registered (no invented symbols).
- `JP225.DWX` (Nikkei 225) — no Japanese index CFD exists in the matrix; not registered.

The KST composite is timeframe- and instrument-agnostic (card R3 PASS), so the
full portable basket present in the matrix is registered per the P2 Saturation
Rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `W1` |
| Multi-timeframe refs | none (all KST/Signal/bias/ATR state on `PERIOD_W1`) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_W1)` — state advances once per closed W1 bar; per-tick path reads cached state only |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~3` (card `expected_trades_per_year_per_symbol: 3`) |
| Typical hold time | `multi-week to multi-month (up to a 26-week time stop)` |
| Expected drawdown profile | `~18% expected DD (card `expected_dd_pct: 18.0`)` |
| Regime preference | `trend-following (long-term / business-cycle momentum)` |
| Expected PF (card) | `~1.2 (card `expected_pf: 1.2`)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `ForexFactory Trading Systems — Martin Pring long-term-KST thread cluster (https://www.forexfactory.com/thread/post/14002300); Pring, "Martin Pring on Market Momentum" (McGraw-Hill 1993) ch. 8-9`
**R1 lineage recorded and R2-R4 PASS** per `artifacts/cards_approved/QM5_9501_pring-kst-w1.md`.

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
| v1 | 2026-08-11 | Initial build from card | build task 037da632-6b8f-435f-b142-3829e442a2a9 |
