# QM5_11904_grimes-sperandeo-failure-test-2b-h1 - Strategy Spec

**EA ID:** QM5_11904
**Slug:** `grimes-sperandeo-failure-test-2b-h1`
**Source:** `d4f8e6a2-9c31-5b47-a672-c8e3f5d2b91a`
**Author of this spec:** Codex
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

On each completed H1 bar, the EA finds the most recent confirmed five-bars-per-side swing high and swing low between 5 and 100 bars old. It buys when the closed bar breaches the prior swing low by at least 3 pips but no more than 1.5 ATR(14), then closes back above the pivot; the short rule mirrors this at a swing high. The stop sits two pips beyond the failure bar, the target is the nearer of 2R or the prior counter-direction swing, and any remaining position closes after 48 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_swing_pivot_lookback_bars` | 10 | even integer >= 2 | Total neighbouring bars in the fractal test; default means five bars on each side. |
| `strategy_pivot_min_age_bars` | 5 | >= half pivot window | Minimum age of an eligible confirmed pivot. |
| `strategy_pivot_max_age_bars` | 100 | >= minimum age | Maximum age of an eligible pivot before it is stale. |
| `strategy_breach_min_pips` | 3 | > 0 | Minimum wick penetration beyond the pivot. |
| `strategy_breach_max_pips_atr_mult` | 1.5 | > 0 | Maximum penetration as ATR(14); larger moves are treated as genuine breakouts. |
| `strategy_atr_period` | 14 | > 0 | H1 ATR period used only for the maximum-breach test. |
| `strategy_close_back_inside_required` | true | true/false | Requires the failure bar to close back through the breached pivot. |
| `strategy_target_method` | `prior_swing_or_rr` | fixed baseline | Selects the nearer of the counter-swing and R-multiple target. |
| `strategy_target_rr` | 2.0 | > 0 | R-multiple target when it is nearer than the counter-swing. |
| `strategy_stop_buffer_pips` | 2 | > 0 | Stop buffer beyond the failure bar extreme. |
| `strategy_time_exit_bars` | 48 | > 0 | Maximum H1 bars in an open trade. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` - highly liquid USD major suitable for H1 pivot failure tests.
- `GBPUSD.DWX` - liquid Sterling major named by the approved card.
- `USDJPY.DWX` - liquid JPY major named by the approved card.
- `USDCAD.DWX` - North American USD major and a diversity candidate outside the certified book.
- `USDCHF.DWX` - liquid European USD major and a diversity candidate outside the certified book.
- `AUDUSD.DWX` - liquid antipodean USD major named by the approved card.
- `NZDUSD.DWX` - liquid antipodean USD pair and a diversity candidate outside the certified book.
- `EURJPY.DWX` - liquid EUR/JPY cross and a diversity candidate outside the certified book.
- `GBPJPY.DWX` - liquid GBP/JPY cross and a diversity candidate outside the certified book.
- `AUDJPY.DWX` - liquid AUD/JPY cross and a diversity candidate outside the certified book.

**Explicitly NOT for:**

- Symbols outside the ten-pair approved card universe; no cross-asset expansion is authorized by this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)`; one bounded raw-price pivot scan per closed H1 bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Expected trade frequency | low-frequency, event-driven failure tests |
| Typical hold time | several H1 bars; hard time exit at 48 H1 bars |
| Expected drawdown profile | false-break reversal losses bounded by the failure-bar stop; card expectation 15% |
| Regime preference | failed breakouts and liquidity sweeps around established swing pivots |
| Win rate target (qualitative) | medium; card expected PF 1.25 |

---

## 6. Source Citation

**Source ID:** `d4f8e6a2-9c31-5b47-a672-c8e3f5d2b91a`

**Source type:** named-author trading books and workbook.

**Pointer:** Adam Grimes, *The Art and Science of Trading - Course Workbook* (Hunter Hudson Press, 2017), Module 6; Victor Sperandeo, *Trader Vic: Methods of a Wall Street Master* (John Wiley, 1991), the 2B entry; classical Wyckoff spring/upthrust lineage.

R1 lineage is recorded and R2-R4 are PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11904_grimes-sperandeo-failure-test-2b-h1.md`.

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
| v1 | 2026-08-10 | Initial build from approved card | `1c4e69ce-eb0d-44da-b15e-30d31698d5e8` |
