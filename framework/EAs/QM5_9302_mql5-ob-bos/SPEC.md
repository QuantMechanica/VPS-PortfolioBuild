# QM5_9302_mql5-ob-bos — Strategy Spec

**EA ID:** QM5_9302
**Slug:** `mql5-ob-bos`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed M15 bar, the EA scans the last 10 bars for an order block (OB): the final opposing candle immediately before an impulsive directional move. For a demand OB, a bearish candle is located, then confirmed valid when (a) an inducement — a minor dip below the candle's low between the OB and the BOS — occurred and (b) the impulsive move closed above the prior swing high (Break of Structure, BOS up). For a supply OB the logic mirrors in reverse. Entry fires when price retests the unmitigated OB zone on the last closed bar while the H1 EMA(50) trend filter aligns (price above EMA for longs, below for shorts). Stop loss is placed outside the OB zone plus an ATR(14) buffer; take profit targets 2R. Each zone is traded at most once; positions exit at 2R TP, ATR-buffered SL, opposite OB retest, or after 96 M15 bars maximum hold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ob_lookback` | 10 | 2–20 | Bars to scan back for candidate OB candle |
| `strategy_ema_period_h1` | 50 | 10–200 | H1 EMA period for higher-TF trend filter |
| `strategy_atr_period` | 14 | 7–28 | ATR period used for SL buffer beyond OB edge |
| `strategy_atr_sl_mult` | 1.0 | 0.5–3.0 | ATR multiplier applied to SL distance beyond OB |
| `strategy_tp_rr` | 2.0 | 1.0–5.0 | Take-profit as multiple of SL distance (R-ratio) |
| `strategy_max_hold_bars` | 96 | 24–288 | Maximum M15 bars to hold a position before forced exit |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major; clear swing structure and OB formation on M15
- `GBPUSD.DWX` — high-volatility FX major; frequent BOS events with identifiable inducement
- `XAUUSD.DWX` — gold; strong OB/BOS dynamics driven by institutional positioning
- `GDAXI.DWX` — DAX 40 index; card targeted GER40 (ported to GDAXI.DWX, canonical DWX symbol for DAX)

**Explicitly NOT for:**
- `GER40.DWX` — not present in dwx_symbol_matrix.csv; canonical equivalent is GDAXI.DWX (see open_questions)

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_H1` (trend filter EMA) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~70 |
| Typical hold time | 1–24 hours (M15 bars, max 96 bars = 24h) |
| Expected drawdown profile | Selective entries on confirmed OB+BOS+Inducement; moderate DD |
| Regime preference | Trend-following (H1 filter) with OB-retest precision entry |
| Win rate target (qualitative) | medium (2R target helps expectancy even at <50% WR) |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 48): Order Blocks, Inducement, Break of Structure", MQL5 Articles, 2026-04-28
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9302_mql5-ob-bos.md`

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
| v1 | 2026-06-10 | Initial build from card | b6d02990-02d3-408c-943e-7e1bb609420f |
