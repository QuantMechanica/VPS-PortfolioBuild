# QM5_12985_ndx-rsi2-shorthold-mr — Strategy Spec

**EA ID:** QM5_12985
**Slug:** `ndx-rsi2-shorthold-mr`
**Source:** `CEO-PROPTRACK-SLATE-2026-07-03` (see `strategy-seeds/sources/CEO-PROPTRACK-SLATE-2026-07-03/`)
**Author of this spec:** Development
**Last revised:** 2026-07-04

---

## 1. Strategy Logic

On a D1 bar close, the EA checks two conditions on the last closed bar: (1) the close must be above the 200-period simple moving average (regime filter — only buy in an uptrend), and (2) the 2-period RSI must be below 10 (extreme short-term oversold dip). When both conditions are true, the EA enters a BUY at the next bar's open with a protective stop set 3 × ATR(14) below entry. The position is closed on whichever comes first: the D1 close crossing above the 5-period SMA (Connors canonical mean-reversion exit), a time stop after 5 D1 bars, or the broker hitting the protective ATR stop. The protective stop is a documented prop-track deviation from the Connors no-stop original, added for FTMO intraday-DD control.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `rsi_entry_threshold` | 10.0 | 5–15 | RSI(2) must be below this to trigger BUY |
| `max_hold_bars` | 5 | 2–10 | Maximum D1 bars before forced time-stop exit |
| `stop_atr_mult` | 3.0 | 2.0–5.0 | ATR(14) multiplier for protective stop distance |
| `sma_regime_period` | 200 | fixed | SMA period for regime filter (Connors 200-day) |
| `sma_exit_period` | 5 | fixed | SMA period for exit signal (Connors 5-day) |
| `rsi_period` | 2 | fixed | RSI period (fixed at 2 per the published strategy) |
| `atr_period_sl` | 14 | fixed | ATR period for stop calculation |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Nasdaq 100 index CFD; liquid, index class commission ~$4.4/trade negligible vs ~25 trades/yr; live-tradable
- `SP500.DWX` — S&P 500 index CFD; similar commission profile; ~25 trades/yr viable net; backtest-only (DXZ does not route orders)
- `GDAXI.DWX` — DAX 40 index CFD; EU equity-index diversifier within same MR family; same commission class

**Explicitly NOT for:**
- Forex pairs — high commission relative to ~25 trades/yr makes net PF unviable per Q04 cost gates
- Commodities — index MR thesis does not port to commodity term-structure driven instruments

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` (via skeleton OnTick) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~25 |
| Typical hold time | 1–5 D1 bars (1–5 days) |
| Expected drawdown profile | MR on indices; cluster stops in crash regimes; bounded per-trade by 3×ATR; ~15% overall per card |
| Regime preference | mean-reversion during uptrend (above SMA200) |
| Win rate target (qualitative) | high (Connors RSI2 historically >70% WR on indices) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CEO-PROPTRACK-SLATE-2026-07-03`
**Source type:** book
**Pointer:** Connors, L. & Alvarez, C. (2009). Short Term Trading Strategies That Work. TradingMarkets Publishing. Ch. 9 — licensed copy, library-mining lane P2. Local source note: `D:/QM/strategy_farm/artifacts/source_notes/e540c29a-f8f3-56b4-852b-8a5e42863f97.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12985_ndx-rsi2-shorthold-mr.md`

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
| v1 | 2026-07-04 | Initial build from card | e4d1b6f7-e6bd-4eeb-a2e8-3171ad9d213f |
