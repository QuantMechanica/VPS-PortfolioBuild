# QM5_12356_orev-ma-break - Strategy Spec

**EA ID:** QM5_12356
**Slug:** `orev-ma-break`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA is long-only. On each closed D1 bar it checks whether SMA(50) is above SMA(200), whether the most recent close reclaimed SMA(50), and whether at least one of the prior configured bars closed below SMA(50). It opens one buy position at the next bar open with an ATR(21)-based hard stop and exits when two consecutive closes fall below SMA(50), SMA(200) rises above SMA(50), or the close falls below SMA(200).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_fast` | 50 | 40-75 | Fast SMA used for reclaim and exit checks. |
| `strategy_sma_slow` | 200 | 150-250 | Slow SMA used as the trend filter. |
| `strategy_closed_below_window` | 2 | 1-3 | Number of prior closed bars searched for a close below the fast SMA. |
| `strategy_atr_period` | 21 | 14-30 | ATR period for the V5 hard stop. |
| `strategy_atr_sl_mult` | 1.5 | 1.0-3.0 | ATR multiple for the hard stop; card names ATR stop but not a multiplier. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index exposure named in the card body and available as a backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index exposure named in the card.
- `WS30.DWX` - Dow 30 index exposure named in the card.
- `EURUSD.DWX` - Major FX pair named in the card frontmatter.
- `GBPUSD.DWX` - Major FX pair named in the card frontmatter.
- `USDJPY.DWX` - Major FX pair named in the card frontmatter.
- `XAUUSD.DWX` - Gold exposure named in the card.
- `GDAXI.DWX` - Matrix-valid DAX equivalent for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX S&P 500 symbols.

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
| Trades / year / symbol | `14` |
| Typical hold time | days to weeks |
| Expected drawdown profile | Medium risk trend-following pullback profile. |
| Regime preference | trend-following, moving-average reclaim |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** GitHub repository
**Pointer:** `https://github.com/oreilm49/quantconnect/blob/master/MABreakthroughETF/main.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12356_orev-ma-break.md`

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
| v1 | 2026-06-18 | Initial build from card | 435b383d-8b6a-4d59-9d5a-a6a9a7b7f757 |
