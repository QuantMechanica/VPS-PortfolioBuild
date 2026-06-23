# QM5_1159_qp-spy-overnight-ma20 - Strategy Spec

**EA ID:** QM5_1159
**Slug:** qp-spy-overnight-ma20
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA is long-only. On each new D1 bar, it reads the prior completed D1 close and the prior-bar SMA(20) of D1 closes. If the prior close is above the SMA(20), the EA opens one market long with a hard stop at 1.0 times D1 ATR(20). The mandatory time exit closes the position when the next D1 bar has formed, which is the MT5 conservative next-bar-open approximation for the card's close-to-next-cash-open overnight hold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 20 | >= 2 | D1 simple moving average length used for the close>SMA entry filter. |
| `strategy_atr_period` | 20 | >= 1 | D1 ATR length used for the hard stop. |
| `strategy_atr_stop_mult` | 1.0 | > 0.0 | ATR multiple for the entry stop loss. |
| `strategy_min_d1_closes` | 40 | >= `strategy_sma_period` | Minimum D1 close-history proxy before the EA can trade. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - canonical S&P 500 custom symbol for the source SPY/SP500 overnight effect; backtest-only per OWNER rollout evidence.
- `NDX.DWX` - US large-cap index proxy registered for the prompt's portable US index basket and T6 live-promotion caveat.
- `WS30.DWX` - US large-cap index proxy registered for the prompt's portable US index basket and T6 live-promotion caveat.

**Explicitly NOT for:**
- `SPY.DWX` - not present in the DWX symbol matrix.
- `SPX500.DWX` - not present in the DWX symbol matrix.
- `ES.DWX` - not present in the DWX symbol matrix.
- `GDAXI.DWX` - not a US large-cap proxy for this SPY overnight card.
- `UK100.DWX` - not a US large-cap proxy for this SPY overnight card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 from card frontmatter |
| Typical hold time | One D1 bar in MT5, approximating close-to-next-cash-open overnight exposure |
| Expected drawdown profile | Stop-defined overnight equity-index exposure with 1.0x D1 ATR(20) hard stop |
| Regime preference | Overnight effect with trend filter, long only when close is above SMA(20) |
| Win rate target (qualitative) | not specified by card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7ede58dd-d184-5099-9d48-7a65de230853
**Source type:** Quantpedia encyclopedia article
**Pointer:** https://quantpedia.com/market-sentiment-and-an-overnight-anomaly/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1159_qp-spy-overnight-ma20.md`

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
| v1 | 2026-06-23 | Initial build from card | af42fdf9-adfb-4289-b299-10356f224a6c |
