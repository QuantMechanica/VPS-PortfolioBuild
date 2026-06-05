# QM5_10778_tv-atr-t3 — Strategy Spec

**EA ID:** QM5_10778
**Slug:** `tv-atr-t3`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView `ATR and T3 strategy`, author `CryptoJoncis`)
**Author of this spec:** Claude
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

Mechanical trend-follower combining a Tillson T3 moving-average band with two
ATR trend states. The T3 band is built by applying a Tillson T3 (the classic
six-stage EMA cascade with a volume factor) to the bar **highs** (upper band)
and to the bar **lows** (lower band). Two ATR "trend states" are SuperTrend
direction trackers — a fast one and a slow one — each returning up or down.

Long when **both** ATR trend states are up **and** the last closed bar's close
is above the upper T3 band, with no open position. Short (mirror) when both ATR
states are down and the close is below the lower T3 band. Exit a long when the
bar midpoint `hl2 = (high+low)/2` falls below the lower T3 band; exit a short
when `hl2` rises above the upper T3 band. A V5 safety stop of
`strategy_safety_atr_mult * ATR(strategy_safety_atr_period)` from entry protects
the position while it waits for the band exit. There is no fixed take-profit.

All strategy state (T3 cascade, both SuperTrend trackers, last close, `hl2`) is
cached in file scope and advanced exactly one step per closed bar — the per-tick
path only reads cached values plus the current Bid/Ask. Sparse by design
(~10 trades/year/symbol).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_t3_length` | 8 | 3-50 | Tillson T3 smoothing length (card test: 5/8/13) |
| `strategy_t3_volume_factor` | 0.70 | 0.1-1.0 | Tillson T3 volume factor (card test: 0.5/0.7/0.9) |
| `strategy_atr_fast_period` | 14 | 5-50 | Fast ATR trend-state (SuperTrend) period (card test: 10/14) |
| `strategy_atr_fast_mult` | 2.00 | 0.5-6.0 | Fast ATR SuperTrend multiplier |
| `strategy_atr_slow_period` | 28 | 5-100 | Slow ATR trend-state (SuperTrend) period (card test: 20/28) |
| `strategy_atr_slow_mult` | 3.00 | 0.5-8.0 | Slow ATR SuperTrend multiplier |
| `strategy_safety_atr_period` | 14 | 5-50 | Safety-stop ATR period |
| `strategy_safety_atr_mult` | 3.00 | 1.0-6.0 | Safety stop distance = mult × ATR (card test: 2/3/4) |
| `strategy_warmup_bars` | 150 | 50-1000 | Closed bars before signals go live (recursion warmup) |
| `strategy_allow_shorts` | true | true/false | Permit short entries |

---

## 3. Symbol Universe

Registered in `magic_numbers.csv` (full portable basket from the card R3 row;
GER40 ported to its DWX equivalent GDAXI.DWX — see card / build open_questions).

**Designed for:**
- `EURUSD.DWX` — slot 0; deep liquid FX major, clean trends for a band breakout.
- `GBPUSD.DWX` — slot 1; FX major, similar trend character.
- `USDJPY.DWX` — slot 2; FX major; named in the card R3 basket.
- `XAUUSD.DWX` — slot 3; gold, strong persistent trends suit ATR+T3 trend logic.
- `GDAXI.DWX` — slot 4; DAX 40 (card's "GER40" ported to canonical DWX symbol).
- `NDX.DWX` — slot 5; Nasdaq 100, trending equity index, live-tradable.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker routes no orders); not in this EA's basket.
- Any symbol absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H12` (card `period: H12`; card also lists H4/H8/D1 for the P3 sweep) |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~10 (card: source states 6-10/yr; conservative 10) |
| Typical hold time | Days to weeks (H12 trend-follower) |
| Expected drawdown profile | Sparse trend system; few trades, occasional long band rides |
| Regime preference | Trend |
| Win rate target (qualitative) | Low-to-medium (trend-follower; winners larger than losers) |

---

## 6. Source Citation

This EA was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** forum (TradingView open-source script)
**Pointer:** `https://www.tradingview.com/script/XUUH8oiL-ATR-and-T3-strategy/` (author `CryptoJoncis`, 2018-09-08)
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_10778_tv-atr-t3.md`

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
| v1 | 2026-06-05 | Initial build from card | task 3accf0b6-3a96-415a-9183-1ed955ea80f4 |
