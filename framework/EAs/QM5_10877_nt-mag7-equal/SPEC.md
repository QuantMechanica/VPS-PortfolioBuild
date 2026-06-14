# QM5_10877_nt-mag7-equal - Strategy Spec

**EA ID:** QM5_10877
**Slug:** nt-mag7-equal
**Source:** 886c5c2e-a87b-5893-9dff-5833be8bc0a3 (see `strategy-seeds/sources/886c5c2e-a87b-5893-9dff-5833be8bc0a3/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA ports the NexusTrade Magnificent Seven monthly equal-weight rebalance idea to liquid index CFD proxies. On D1, it enters one long market position at the first tradable bar of a new calendar month when no position already exists for the EA magic. The position has no profit target and no signal exit in the baseline; it exits through a wide catastrophic stop placed at entry minus 4.0 times ATR(D1, 20). Friday close is disabled by default because the source rule is to stay invested.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 1+ | ATR period used for the catastrophic stop. |
| `strategy_atr_stop_mult` | 4.0 | >0 | ATR multiplier for the initial long stop. |
| `strategy_first_trade_window_days` | 7 | 1+ | Calendar-day grace window used to catch the first tradable D1 bar of the month after weekends or holidays. |
| `strategy_sma_guard_enabled` | false | true/false | Optional P3 regime-guard variant from the card; off for the P2 baseline. |
| `strategy_sma_guard_period` | 200 | 1+ | SMA period used only when the optional regime guard is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - closest routable index proxy for the Magnificent Seven growth/technology exposure.
- `SP500.DWX` - broad US large-cap proxy listed in the card; valid for backtest-only custom-symbol evaluation.
- `WS30.DWX` - Dow 30 proxy for the card's robustness checks across US large-cap exposure.

**Explicitly NOT for:**
- Individual MAG7 equities - not available in the DWX matrix for this V5 pipeline.
- `SPY.DWX`, `SPX500.DWX`, `ES.DWX` - unavailable aliases; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | MN1 new-bar detector for monthly cadence; optional D1 SMA(200) guard when enabled |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Weeks to months, until catastrophic stop or optional guard exit |
| Expected drawdown profile | Wide stop and passive long exposure can carry equity-style drawdowns. |
| Regime preference | Persistent long momentum in large-cap indices |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 886c5c2e-a87b-5893-9dff-5833be8bc0a3
**Source type:** blog
**Pointer:** Austin Starks, NexusTrade, "Build your first algorithmic trading strategy in three steps", https://nexustrade.io/blog/algo-trading-fundamentals-build-your-first-strategy-20260415
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10877_nt-mag7-equal.md`

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
| v1 | 2026-06-14 | Initial build from card | 00976f58-2e94-434c-a6a0-ec3808a777c9 |
