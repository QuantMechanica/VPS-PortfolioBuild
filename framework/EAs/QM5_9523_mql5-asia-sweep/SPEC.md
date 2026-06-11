# QM5_9523_mql5-asia-sweep — Strategy Spec

**EA ID:** QM5_9523
**Slug:** `mql5-asia-sweep`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `strategy-seeds/sources/a120af9a-fb72-526c-bb80-d1d098a617b5/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

During the Asia session (default 00:00–07:00 broker time), the EA records the highest high and lowest low from all completed M15 candles. Once the Asia session is closed, it waits for the London or New York session and monitors each completed M15 bar for a liquidity sweep: a bar whose high reaches above the Asia session high but whose close falls back below it (short setup), or a bar whose low reaches below the Asia session low but whose close comes back above it (long setup). When a sweep candle is confirmed on bar close, a market order is placed in the fade direction. The stop loss is set just beyond the sweep candle's extreme (high for shorts, low for longs), and the take-profit is set at a fixed risk-reward multiple of the stop distance. One trade per calendar day is permitted.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `AsiaStartHour` | 0 | 0–23 | Broker-time hour: Asia range build start (inclusive) |
| `AsiaEndHour` | 7 | 1–23 | Broker-time hour: Asia range build end (exclusive) |
| `LondonStartHour` | 9 | 0–23 | Broker-time hour: London session open (inclusive) |
| `LondonEndHour` | 17 | 1–24 | Broker-time hour: London session close (exclusive) |
| `NYStartHour` | 14 | 0–23 | Broker-time hour: New York session open (inclusive) |
| `NYEndHour` | 22 | 1–24 | Broker-time hour: New York session close (exclusive) |
| `MaxTradesPerDay` | 1 | 1–5 | Maximum entries per calendar day |
| `RR` | 1.5 | 0.5–5.0 | Take-profit risk:reward ratio |
| `MinRangeATRRatio` | 0.1 | 0.0–1.0 | Minimum sweep candle range as fraction of ATR(14, M15); filters zero-range bars |
| `SlBufferATRRatio` | 0.05 | 0.0–0.5 | SL buffer beyond sweep candle extreme as fraction of ATR(14, M15) |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — Gold; primary source context; high intraday Asia-range volatility with reliable London/NY sweep patterns
- `GDAXI.DWX` — DAX 40 (ported from card's GER40.DWX, which is not in dwx_symbol_matrix.csv; GDAXI.DWX is the canonical DWX German index); strong London-session liquidity, Asia range established in pre-European hours
- `EURUSD.DWX` — Euro/USD; highest FX liquidity; textbook Asia-range sweep dynamics at London open
- `GBPUSD.DWX` — GBP/USD; strong London-session correlation; frequently sweeps Asian session ranges at the London open

**Explicitly NOT for:**
- Monthly (MN1) instruments — untestable in MT5 tester
- Symbols without meaningful Asia-session activity

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~110 |
| Typical hold time | 1–8 hours (intraday, London/NY session) |
| Expected drawdown profile | Low to moderate; SL anchored to sweep candle extreme |
| Regime preference | mean-revert / session-breakout-fade |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** `forum` (MQL5 Articles)
**Pointer:** Eugene Mmene, "Mastering PD Arrays: Optimizing Trading from Imbalances in PD Arrays", MQL5 Articles, 2026-03-09, https://www.mql5.com/en/articles/21246
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9523_mql5-asia-sweep.md`

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
| v1 | 2026-06-11 | Initial build from card | 71c3e8e4-0b0d-4149-875f-13b9ea8d13b8 |
