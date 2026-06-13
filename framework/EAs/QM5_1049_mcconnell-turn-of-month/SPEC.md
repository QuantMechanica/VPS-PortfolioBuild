# QM5_1049_mcconnell-turn-of-month - Strategy Spec

**EA ID:** QM5_1049
**Slug:** mcconnell-turn-of-month
**Source:** afab7a6f-c3c8-51ae-a609-f376744beb8e (see SSRN 925589 / Financial Analysts Journal 2008)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades the McConnell-Xu turn-of-the-month effect on daily equity-index bars. It opens one long position after the D1 bar that ends the prior calendar month has closed, using the broker's actual D1 trading sessions so weekends and unavailable sessions are skipped by the bar stream. It exits after the third trading session of the new month has closed. The baseline has no regime filter; the optional SMA filter skips entries when the D1 200-SMA is descending.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | >= 1 | D1 ATR period for the hard protective stop. |
| strategy_atr_stop_mult | 3.0 | > 0 | ATR multiple used for the long-position stop. |
| strategy_exit_trading_day | 3 | >= 1 | Trading-session count in the new month after which the position is flattened. |
| strategy_regime_filter | false | true/false | Optional P3 filter; when enabled, skip entry if the long SMA is descending. |
| strategy_regime_sma_period | 200 | >= 2 | D1 SMA length used by the optional regime filter. |
| strategy_max_spread_points | 0 | >= 0 | Optional spread ceiling in points; 0 disables this filter. |
| strategy_require_d1 | true | true/false | Blocks trading unless the chart/test period is D1. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index exposure, the card's primary P2 baseline symbol.
- WS30.DWX - Dow 30 index exposure, portable US large-cap equity-index proxy.
- GDAXI.DWX - DAX 40 exposure, matching the card's Germany submarket coverage.
- UK100.DWX - FTSE 100 exposure, matching the card's UK submarket coverage.

**Explicitly NOT for:**
- SPX500.DWX - unavailable in the card's DWX feed context; no registry row is used.
- SPY.DWX - not a canonical DWX custom symbol for this framework.
- ES.DWX - not a canonical DWX custom symbol for this framework.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About 4 trading days |
| Expected drawdown profile | Monthly equity-index exposure with ATR hard stop and framework kill-switch protection. |
| Regime preference | Seasonality / calendar anomaly |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** afab7a6f-c3c8-51ae-a609-f376744beb8e
**Source type:** paper
**Pointer:** SSRN 925589, "Equity Returns at the Turn of the Month: Trading Strategies and Implications for Investors and Managers" by John J. McConnell and Wei Xu.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1049_mcconnell-turn-of-month.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-13 | Initial build from card | e21db26d-5a13-472f-81b4-ac1a0534a1ea |
