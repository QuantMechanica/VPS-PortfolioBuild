# QM5_41150_gbpusd-local-session-inventory-drift — Strategy Spec

**EA ID:** QM5_41150
**Slug:** gbpusd-local-session-inventory-drift
**Source:** BREEDON-RANALDO-FX-INTRADAY-2013
**Author of this spec:** Codex
**Last revised:** 2026-09-11

## 1. Strategy Logic

On the exact 07:00 Europe/London H1 bar of Monday through Friday, the EA submits one market SELL when no position is owned by its magic, the London date has not been consumed, completed H1 ATR and execution metadata are valid, and uncached news-calendar checks clear the full owned interval. The date is persisted and flushed before submission, so a broker rejection or restart cannot create a second attempt.

The position has a 1.5-times completed H1 ATR(14) hard stop, no profit target, and is flattened at or after 16:00 London time. London civil time uses the framework's recurring UK DST rules and unique local/UTC conversion. Clock ambiguity, missing history, stale news data, invalid risk geometry, and ownership faults all fail closed. There is no momentum filter, grid, averaging, pyramiding, reversal, banned indicator, or ML/adaptive component.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| strategy_atr_period_h1 | 14 | locked 14 | Completed H1 ATR period for the initial hard stop |
| strategy_hard_stop_atr | 1.5 | locked 1.5 | Initial hard-stop distance in completed H1 ATR units |

The configuration guard additionally locks `qm_ea_id=41150`, `qm_magic_slot_offset=0`, and fixed-risk mode (`RISK_PERCENT=0`, finite `RISK_FIXED>0`). It does not compare RNG, news, or Friday-close inputs. Stress rejection is checked only for finiteness and inclusive 0..1 range.

## 3. Symbol Universe

**Designed for:**

- The chart carrier `_Symbol`, bound by the registry and canonical setfile to `GBPUSD.DWX`.
- Slot 0, magic `411500000`.

**Explicitly not for:**

- Other carriers or multi-symbol execution. A carrier change creates a new strategy identity.
- Grid, martingale, averaging, pyramiding, post-session reversal, or discretionary filtering.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Chart and execution timeframe | H1 |
| Signal time | exact 07:00 Europe/London H1 open |
| Owned interval | [07:00,16:00] Europe/London local civil time |
| Volatility input | H1 ATR(14), completed shift 1 only |
| Bar gating | one `QM_IsNewBar(_Symbol, PERIOD_H1)` consume per tick |

A session without an exact executable 07:00 H1 bar is operationally non-trading. This makes a closed-market holiday fail closed. The approved card does not identify a versioned UK civil-holiday dataset for this FX session, so the build does not invent an additional jurisdictional calendar; such a rule requires a governed calendar artifact.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Maximum opportunities | one per London weekday before no-trade filters |
| Card frequency declaration | approximately 100 trades/year/symbol; Q02 measures the actual implementation |
| Direction | SELL GBPUSD during the UK local trading session |
| Typical hold time | at most nine hours, always flat at/after 16:00 London |
| Regime | structural local-session inventory drift |

Nine fresh trailing-hour news checks at 08:00 through 16:00 London cover the complete [07:00,16:00] interval. Missing or stale tester/live calendar coverage blocks the entry.

## 6. Source Citation

**Source ID:** BREEDON-RANALDO-FX-INTRADAY-2013

**Citation:** Francis Breedon and Angelo Ranaldo (2013), “Intraday Patterns in FX Returns and Order Flow,” *Journal of Money, Credit and Banking* 45(5), 953–965.

**Primary source:** https://www.snb.ch/public/asset/en/www-snb-ch/publications/research/working-papers/2011/working_paper_2011_04/publications0_en/working_paper_2011_04.n.pdf

**Card pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_41150_gbpusd-local-session-inventory-drift.md

R1 lineage is recorded and R2–R4 PASS per the approved card. The durable exhaustive-read record and the existing local-hours reference spec define the London/Europe interval as 07:00–16:00; the card predeclares the source-signed GBP depreciation expression. No paper performance statistic or portfolio property is transferred to this EA.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest | RISK_FIXED | $1,000 per trade with RISK_PERCENT=0 |
| Live | not authorized | Any future risk requires downstream portfolio and deployment approval |

The framework sizes from entry-to-stop geometry and rejects invalid tick-value, volume, or stop metadata. The initial stop is never widened or trailed. Friday-close and kill-switch handling run before strategy entry logic. An ownership fault flattens every position owned by this magic at the first safe executable point.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-11 | Initial build from card | build task `31c75268-67a5-443d-92c8-96760d5d5183` |
