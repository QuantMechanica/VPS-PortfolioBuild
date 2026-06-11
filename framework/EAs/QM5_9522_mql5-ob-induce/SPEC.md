# QM5_9522_mql5-ob-induce — Strategy Spec

**EA ID:** QM5_9522
**Slug:** `mql5-ob-induce`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `strategy-seeds/sources/a120af9a-fb72-526c-bb80-d1d098a617b5/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed M30 bar the EA scans the last 30 bars for a valid Order Block setup. An Order Block is the final opposing candle (bearish candle for a bullish OB, bullish candle for a bearish OB) before a strong impulse move that exits a consolidation range. The setup requires four confirmations: (1) consolidation in the preceding candles (range ≤ OBMaxDeviation points), (2) impulse body ≥ OBImpulseThreshold × ATR(14), (3) an inducement sweep of at least minIndDepthPts before a Break of Structure (price closes beyond the post-impulse swing), and (4) a Fair Value Gap between the pre-OB bar and the impulse candle of at least minFVGPts. Entries are long-only from bullish OBs when the H4 SMA filter confirms an uptrend, and short-only from bearish OBs in a downtrend. Entry fires at market when current price retests the OB zone. SL sits below/above the OB edge plus a fixed offset; TP is set at 4× the SL distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ob_range_candles` | 7 | 3–20 | Number of consolidation bars to validate before the OB candle |
| `strategy_ob_max_dev_pts` | 50 | 10–200 | Max consolidation range in points for a valid OB zone |
| `strategy_ob_wait_bars` | 3 | 1–10 | Min bars after OB candle that must precede impulse confirmation |
| `strategy_ob_impulse_thresh` | 1.0 | 0.5–3.0 | Impulse candle body must be ≥ this multiple of ATR(14) |
| `strategy_atr_period` | 14 | 5–50 | ATR period used for impulse threshold |
| `strategy_ob_lookback` | 30 | 10–60 | Bars to scan backward for OB zones |
| `strategy_min_ind_depth_pts` | 20 | 5–100 | Minimum inducement swing depth in points |
| `strategy_min_fvg_pts` | 10 | 5–50 | Minimum Fair Value Gap size in points |
| `strategy_sl_offset_pts` | 10 | 1–50 | Extra SL buffer beyond OB edge in points |
| `strategy_rr_ratio` | 4.0 | 1.0–10.0 | TP = rr_ratio × SL distance |
| `strategy_htf_sma_period` | 50 | 10–200 | H4 SMA period for higher-timeframe trend filter |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — DAX 40; sufficient M30 OHLC history; OB structure valid on liquid European index (card listed GER40.DWX which maps to GDAXI.DWX — only canonical name in dwx_symbol_matrix.csv)
- `XAUUSD.DWX` — Gold; high volatility and clear swing structure make OB zones visible and frequently retested
- `EURUSD.DWX` — Major EUR/USD pair; high liquidity, clean M30 bars, institutional order-flow narrative fits OB logic
- `GBPUSD.DWX` — Cable; similar liquidity profile to EURUSD, OB patterns documented in source article

**Explicitly NOT for:**
- `GER40.DWX` — not a canonical DWX symbol; ported to GDAXI.DWX (see open_questions in build result)
- `SP500.DWX` — backtest-only; not in card's target set

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | H4 SMA(50) for trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~60 |
| Typical hold time | Hours to days (M30 OB retests) |
| Expected drawdown profile | Moderate; 4:1 RR with ~25–35% win rate yields positive expectancy |
| Regime preference | Trending (HTF SMA filter enforces direction) |
| Win rate target (qualitative) | Low–medium (high RR compensates) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 48): Order Blocks, Inducement, Break of Structure", MQL5 Articles, 2026-04-28
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9522_mql5-ob-induce.md`

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
| v1 | 2026-06-11 | Initial build from card | ec49574c-d1e6-488f-b55b-9cdb8d1b0d16 |
