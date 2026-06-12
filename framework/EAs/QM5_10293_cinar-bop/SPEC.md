# QM5_10293_cinar-bop - Strategy Spec

**EA ID:** QM5_10293
**Slug:** cinar-bop
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades the Balance of Power sign on the close of each D1 bar. Balance of Power is `(Close - Open) / (High - Low)`: a positive value opens or keeps a long position, a negative value opens or keeps a short position, and an exact zero holds. If an opposite sign appears while a position is open, the EA closes that position and opens the opposite direction on the same closed-bar decision path. The source has no profit target, so the V5 port uses only a catastrophic `2.0 * ATR(14)` stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | `1+` | ATR lookback used for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.0 | `> 0` | ATR multiplier for the catastrophic stop distance. |
| `strategy_bop_deadband` | 0.0 | `0.0+` | Optional neutral band around zero; default preserves the card's exact zero-line rule. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `AUDCHF.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `AUDJPY.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `AUDNZD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `AUDUSD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `CADCHF.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `CADJPY.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `CHFJPY.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `EURAUD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `EURCAD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `EURCHF.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `EURGBP.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `EURJPY.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `EURNZD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `EURUSD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `GBPAUD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `GBPCAD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `GBPCHF.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `GBPJPY.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `GBPNZD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `GBPUSD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `GDAXI.DWX` - canonical DAX custom symbol in the DWX matrix; used for the card's DAX reference.
- `NDX.DWX` - index OHLC symbol in the DWX matrix; named directly by the card.
- `NZDCAD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `NZDCHF.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `NZDJPY.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `NZDUSD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `SP500.DWX` - index OHLC symbol in the DWX matrix; valid for backtest-only S&P 500 coverage.
- `UK100.DWX` - index OHLC symbol in the DWX matrix; card ports directly to index CFDs.
- `USDCAD.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `USDCHF.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `USDJPY.DWX` - FX OHLC symbol in the DWX matrix; card ports directly to major FX.
- `WS30.DWX` - index OHLC symbol in the DWX matrix; named directly by the card.
- `XAGUSD.DWX` - metal OHLC symbol in the DWX matrix; card ports directly to metals.
- `XAUUSD.DWX` - metal OHLC symbol in the DWX matrix; named directly by the card.
- `XNGUSD.DWX` - commodity OHLC symbol in the DWX matrix; card R3 says OHLC CFD portability.
- `XTIUSD.DWX` - commodity OHLC symbol in the DWX matrix; card R3 says OHLC CFD portability.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build never registers phantom broker symbols.
- `DAX.DWX` - card wording only; canonical matrix symbol is `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Until the next opposite D1 BOP sign; usually one or more days. |
| Expected drawdown profile | Trend/momentum sleeve with whipsaw risk during alternating candle-pressure regimes. |
| Regime preference | Momentum / candle-pressure continuation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/cinar/indicator/blob/master/strategy/trend/bop_strategy.go and https://github.com/cinar/indicator/blob/master/trend/bop.go
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10293_cinar-bop.md`

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
| v1 | 2026-06-12 | Initial build from card | 3d4fb82c-9f59-4339-96fa-0d4bf0f2e2ec |
