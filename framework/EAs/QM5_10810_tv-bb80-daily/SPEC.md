# QM5_10810_tv-bb80-daily - Strategy Spec

**EA ID:** QM5_10810
**Slug:** `tv-bb80-daily`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades only D1 bars. A long setup occurs when the last closed D1 close crosses above the upper Bollinger Band using length 80 and 1.0 standard deviation, while both the Bollinger middle line and SMA(200) are rising. A short setup is the mirror image below the lower band with both trend references falling. Positions are opened at the next D1 bar's first tradable tick, use a 2.0 ATR(14) safety stop, and exit when the closed D1 close crosses back through the Bollinger middle band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 80 | 60-100 P3 range | Bollinger Band period from the card baseline. |
| `strategy_bb_deviation` | 1.0 | 1.0-1.5 P3 range | Bollinger Band standard deviation multiplier. |
| `strategy_sma_period` | 200 | 150-200 P3 range | SMA trend filter period. |
| `strategy_atr_period` | 14 | fixed baseline | ATR period used for the V5 safety stop. |
| `strategy_atr_sl_mult` | 2.0 | 2.0-4.0 P3 range | ATR multiple for the safety stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major liquid forex pair in the card's P2 basket.
- `GBPUSD.DWX` - major liquid forex pair in the card's P2 basket.
- `USDJPY.DWX` - major liquid forex pair in the card's P2 basket.
- `XAUUSD.DWX` - DWX matrix version of the card's XAUUSD target.
- `GDAXI.DWX` - available DWX DAX symbol used for the card's GER40 exposure.
- `NDX.DWX` - liquid US index target in the card's P2 basket.
- `WS30.DWX` - liquid US index target in the card's P2 basket.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - not broker/tester available in the DWX environment.
- `GER40.DWX` - not present in the matrix; mapped to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | days to weeks, until a D1 middle-band cross or ATR safety stop |
| Expected drawdown profile | trend-following drawdowns during range-bound false breakouts |
| Regime preference | D1 trend / Bollinger breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView strategy
**Pointer:** `https://www.tradingview.com/script/h0ePZA90/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10810_tv-bb80-daily.md`

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
| v1 | 2026-06-05 | Initial build from card | 2e13397d-52b3-4c34-a30c-9101bb10f1a1 |
