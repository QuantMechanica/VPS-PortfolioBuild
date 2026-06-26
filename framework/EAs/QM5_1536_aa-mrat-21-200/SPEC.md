# QM5_1536_aa-mrat-21-200 - Strategy Spec

**EA ID:** QM5_1536
**Slug:** `aa-mrat-21-200`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

At the start of each month the EA computes MRAT for every registered basket symbol as SMA(close, 21 D1 bars) divided by SMA(close, 200 D1 bars). It computes the cross-sectional standard deviation of those MRAT values, selects the top two symbols only when MRAT - 1 is at least that sigma, and selects the bottom two symbols only when 1 - MRAT is at least that sigma. The EA opens long positions for selected top symbols and short positions for selected bottom symbols, then closes positions at the next monthly rebalance if the symbol is no longer selected or the side changes. Initial stop loss is 3.0 x ATR(20, D1), with no pyramiding or averaging.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_sma_d1` | 21 | 1+ | Fast D1 SMA period used in MRAT numerator. |
| `strategy_slow_sma_d1` | 200 | 2+ | Slow D1 SMA period used in MRAT denominator. |
| `strategy_atr_period_d1` | 20 | 1+ | D1 ATR period for initial stop and spread cap. |
| `strategy_atr_sl_mult` | 3.0 | >0 | ATR multiple for the initial stop loss. |
| `strategy_spread_atr_mult` | 0.25 | >=0 | Blocks entry only when positive modeled spread exceeds this fraction of ATR. |
| `strategy_sleeve_count_symbols` | 2 | 1+ | Number of top and bottom symbols selected in this 10-symbol universe. |
| `strategy_min_valid_symbols` | 8 | 2-10 | Minimum symbols with valid SMA data before ranking. |
| `strategy_rebalance_day_cutoff` | 5 | 1-10 | First broker-calendar days of a month treated as the monthly session-open rebalance window. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol from the card's DWX index proxy universe.
- `NDX.DWX` - Nasdaq 100 index proxy from the card's DWX universe.
- `WS30.DWX` - Dow 30 index proxy from the card's DWX universe.
- `GDAXI.DWX` - DAX index proxy from the card's DWX universe.
- `XAUUSD.DWX` - Gold CFD from the card's metal sleeve.
- `XAGUSD.DWX` - Silver CFD from the card's metal sleeve.
- `EURUSD.DWX` - Major FX pair from the card's FX sleeve.
- `GBPUSD.DWX` - Major FX pair from the card's FX sleeve.
- `USDJPY.DWX` - Major FX pair from the card's FX sleeve.
- `XTIUSD.DWX` - Matrix-valid WTI crude proxy for the card's `USOIL` target.

**Explicitly NOT for:**
- `USOIL.DWX` - Not present in `dwx_symbol_matrix.csv`; replaced by `XTIUSD.DWX`.
- Symbols outside the registered 10-symbol basket - the strategy depends on cross-sectional ranks for this exact portable universe.

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
| Trades / year / symbol | `100` from card frontmatter |
| Typical hold time | Monthly rebalance; selected positions normally hold days to one month unless Friday close intervenes. |
| Expected drawdown profile | Cross-sectional momentum with 3x ATR stop; drawdown should cluster in trend reversals and broad cross-asset whipsaw. |
| Regime preference | Cross-sectional trend / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `blog / paper summary`
**Pointer:** `https://alphaarchitect.com/moving-average-distance/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1536_aa-mrat-21-200.md`

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
| v1 | 2026-06-26 | Initial build from card | 6c96287c-8c7a-4c94-aa17-d30d9e40fe4b |
