# QM5_1463_as-papa-bear — Strategy Spec

**EA ID:** QM5_1463
**Slug:** `as-papa-bear`
**Source:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9` (see `strategy-seeds/sources/2df06de7-6a3a-5b06-9e6d-446d1a01fab9/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On the first trading day of each calendar month (detected as the first D1 bar whose month number differs from the previous rebalance), compute for each of five basket assets a composite momentum score equal to the arithmetic average of the 3-month, 6-month, and 12-month total returns (using D1 closes at approximately 63, 126, and 252 bars back). Select the three highest-ranking assets. Close any currently held position that ranked outside the top three, then open a long market position in each top-three asset that is not already held. Positions are sized with a wide ATR-based stop loss (5× ATR-14 on D1) as a safety net; the actual exit is the next monthly rotation. The card specifies MN1 as the native timeframe; because MT5 tester generates 0 bars/ticks for DWX custom symbols on the MN1 period, D1 with month-change detection is used as the documented equivalent.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_momentum_3m_bars` | 63 | 40-80 | D1 bars for the 3-month return lookback |
| `strategy_momentum_6m_bars` | 126 | 80-160 | D1 bars for the 6-month return lookback |
| `strategy_momentum_12m_bars` | 252 | 200-270 | D1 bars for the 12-month return lookback |
| `strategy_sl_atr_mult` | 5.0 | 3.0-10.0 | ATR multiplier for the safety-net stop loss |
| `strategy_sl_atr_period` | 14 | 5-30 | ATR period used for stop-loss sizing |

---

## 3. Symbol Universe

This is a basket EA. It runs on NDX.DWX as the primary chart but opens and manages positions across all five basket symbols simultaneously.

**Designed for:**
- `NDX.DWX` — Nasdaq 100 index; equity growth proxy; live-tradable; primary chart symbol
- `WS30.DWX` — Dow Jones Industrial Average; broad US large-cap equity proxy; live-tradable
- `SP500.DWX` — S&P 500 index; OWNER-provided custom symbol (2018-2026); backtest-only (broker does not route live orders)
- `XAUUSD.DWX` — Gold spot; defensive asset and inflation hedge; replaces gold-ETF (IAU) from source universe
- `XTIUSD.DWX` — WTI Crude Oil; commodity proxy; replaces PDBC commodity ETF from source universe

**Explicitly NOT for:**
- Any single isolated symbol in isolation — the strategy requires all five symbols for momentum ranking

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` (momentum computed on D1 only) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` then month-change check |
| Native card TF | `MN1` (untestable in MT5 tester for DWX custom symbols; D1 proxy used) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (monthly basket rebalance decisions) |
| Typical hold time | ~1 month per position |
| Expected drawdown profile | multi-month drawdown during momentum reversals; wide ATR SL rarely hit |
| Regime preference | trend / multi-asset momentum |
| Win rate target (qualitative) | medium (rotation strategy; winners held, losers rotated out) |

---

## 6. Source Citation

**Source ID:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9`
**Source type:** web catalogue
**Pointer:** Allocate Smartly catalogue (Brian Livingston / Muscular Portfolios Papa Bear); BestFolio independent rule summary https://bestfolio.app/strategies/papa-bear
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1463_as-papa-bear.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

Note: `PORTFOLIO_WEIGHT` defaults to `0.333` in this EA (1/3 per sleeve) so each of the three simultaneously held positions risks 1/3 of the base RISK_FIXED budget.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | 0755f269-5618-499f-a64b-ff33fabccc6c |
