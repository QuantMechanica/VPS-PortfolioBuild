# QM5_10736_tv-ema-wma-2tp - Strategy Spec

**EA ID:** QM5_10736
**Slug:** `tv-ema-wma-2tp`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation below)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades an EMA/WMA crossover on the configured signal timeframe. It opens long when EMA(20) crosses above WMA(50), and opens short when EMA(20) crosses below WMA(50). Each trade uses a fixed 20-pip initial stop and a single full-position target at 40 pips, reflecting the V5 baseline collapse of the source script's two profit targets. After price moves 20 pips in favor of the position, the EA moves the stop to breakeven; if the opposite EMA/WMA cross appears before SL or TP, it closes the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_CURRENT` | MT5 timeframe enum | Timeframe used for EMA/WMA crossover reads. |
| `strategy_ema_period` | `20` | `1` and above | EMA period from the card's P2 fallback default. |
| `strategy_wma_period` | `50` | `1` and above | WMA period from the card's P2 fallback default. |
| `strategy_stop_pips` | `20` | `1` and above | Fixed initial stop distance in pips. |
| `strategy_tp2_pips` | `40` | greater than `strategy_stop_pips` | Full-position take-profit distance in pips. |
| `strategy_breakeven_pips` | `20` | `1` and above | Favorable move required before moving SL to breakeven. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - listed in the card's R3 P2 basket and supports EMA/WMA plus fixed-pip exits.
- `GBPUSD.DWX` - listed in the card's R3 P2 basket and supports EMA/WMA plus fixed-pip exits.
- `XAUUSD.DWX` - listed in the card's R3 P2 basket and supports EMA/WMA plus fixed-distance exits through the V5 stop helper.
- `NDX.DWX` - listed in the card's R3 P2 basket and supports EMA/WMA plus fixed-distance exits through the V5 stop helper.

**Explicitly NOT for:**
- None beyond symbols outside the approved R3 P2 basket for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | Not specified in card frontmatter; mechanically bounded by 40-pip TP, 20-pip SL, opposite crossover, or framework Friday close. |
| Expected drawdown profile | Fixed 20-pip initial stop with breakeven after 20 pips favorable excursion. |
| Regime preference | EMA/WMA crossover trend-following regime, inferred from the approved mechanical rules. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source script
**Pointer:** TradingView script `Two Take Profits and Two Stop Loss`, author handle `ahmad_naquib`, published 2020-07-05, URL https://www.tradingview.com/script/tGTV8MkY-Two-Take-Profits-and-Two-Stop-Loss/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10736_tv-ema-wma-2tp.md`

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
| v1 | 2026-06-14 | Initial build from card | 17cb86f8-4918-4fff-ba14-176c984cd0c0 |
