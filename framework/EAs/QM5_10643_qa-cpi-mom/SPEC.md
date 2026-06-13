# QM5_10643_qa-cpi-mom - Strategy Spec

**EA ID:** QM5_10643
**Slug:** qa-cpi-mom
**Source:** 35e40f89-5980-5d15-8964-70f9760db187
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades one scheduled US CPI release supplied through strategy inputs. It computes `surprise = actual_cpi - expected_cpi`; a cooler surprise at or below the negative threshold can buy index CFDs, and a hotter surprise at or above the positive threshold can sell them. The trade is allowed only inside the configured seconds-after-release window, only when price has moved at least the configured ATR fraction away from the release-bar open, and only while the spread is below the configured pre-release median spread multiple. Exits are a 15-minute time stop by default, an early close if price crosses back through the release-bar open, hard stop loss, break-even after +1R, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_release_time` | `2024.01.11 15:30:00` | valid broker datetime | Timestamp of the CPI release event used by the single-event backtest. |
| `strategy_event_values_valid` | `true` | `true/false` | Set false to skip the event when actual or expected CPI data are missing. |
| `strategy_actual_cpi` | `3.0` | event feed value | Actual CPI value for the release. |
| `strategy_expected_cpi` | `3.2` | event feed value | Consensus CPI value for the release. |
| `strategy_surprise_threshold_pp` | `0.10` | `>0` | Minimum absolute CPI surprise in percentage points. |
| `strategy_entry_delay_seconds` | `5` | `>=0` | Lower bound after release before entry is allowed. |
| `strategy_entry_window_seconds` | `90` | `> entry_delay` | Upper bound after release for new entries. |
| `strategy_release_time_uncertainty_sec` | `0` | `0-5 allowed` | Timestamp uncertainty; values above 5 seconds block entry. |
| `strategy_atr_period` | `14` | `>0` | M1 ATR period for confirmation and stop distance. |
| `strategy_confirm_atr_mult` | `0.25` | `>0` | Required move from release-bar open as a fraction of ATR. |
| `strategy_stop_atr_mult` | `1.0` | `>0` | Initial stop distance as a fraction of ATR. |
| `strategy_time_exit_minutes` | `15` | `>0` | Maximum holding time after entry. |
| `strategy_pre_release_median_spread_pts` | `40.0` | `>0` | Supplied pre-release median spread in points for the event. |
| `strategy_spread_cap_mult` | `3.0` | `>0` | Current spread must be below median spread times this multiple. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol fits the US large-cap index reaction targeted by the CPI surprise card.
- `NDX.DWX` - Nasdaq 100 is a liquid US large-cap growth index expected to react to CPI surprise momentum.
- `WS30.DWX` - Dow 30 is a liquid US large-cap index and completes the card's portable P2 basket.

**Explicitly NOT for:**
- `SPY.DWX` - not a canonical available DWX symbol in the matrix.
- `SPX500.DWX` - not the canonical S&P 500 custom symbol; use `SP500.DWX`.
- `ES.DWX` - not a registered DWX CFD/custom-symbol target for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | `15 minutes maximum` |
| Expected drawdown profile | High slippage and spread sensitivity around CPI releases. |
| Regime preference | news-driven event momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 35e40f89-5980-5d15-8964-70f9760db187
**Source type:** article
**Pointer:** Quant Arb, Event-Based Alpha: A Quick Guide, The Quant Stack / algos.org, 2024-05-31, plus archived copy cited in the approved card.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10643_qa-cpi-mom.md`

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
| v1 | 2026-06-14 | Initial build from card | 99b61cd3-6d84-42b2-a550-58dd175a4170 |
