# QM5_10083_gh-rwr-pullback - Strategy Spec

**EA ID:** QM5_10083
**Slug:** gh-rwr-pullback
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175 (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades a long-only red-white-red pullback breakout on the chart timeframe. It checks the latest five closed bars and requires bar 3 bearish, bar 2 bullish, and bar 1 bearish, with bar 4 low above bar 3 low, bar 3 low above bar 2 low, and bar 1 low above bar 2 low. When the setup exists, it buys on a break above bar 1 high. The stop is bar 2 low and the take profit is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_reward_r_multiple` | 2.0 | `> 0` | Take-profit distance as a multiple of entry-to-stop risk. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target forex major with DWX OHLC data for the candle pattern.
- `GBPUSD.DWX` - Card target forex major with DWX OHLC data for the candle pattern.
- `GDAXI.DWX` - Card target DAX index CFD with DWX OHLC data for the candle pattern.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - build-time registration is limited to verified DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | H1 breakout trade held until attached SL, attached 2R TP, or framework Friday close. |
| Expected drawdown profile | Fixed structure stop at bar 2 low with framework fixed-risk sizing. |
| Regime preference | Pullback breakout after a short red-white-red candle sequence. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub source code
**Pointer:** https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Red%20White%20Red%20Partie%2001/Expert/rwr-1.0.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10083_gh-rwr-pullback.md`

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
| v1 | 2026-06-11 | Initial build from card | 29ed488a-f8fc-4f9d-a713-cc9fcbec0f70 |
