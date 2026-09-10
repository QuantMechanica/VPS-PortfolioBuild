# QM5_41149_audusd-local-session-inventory-drift — Strategy Spec

**EA ID:** QM5_41149
**Slug:** audusd-local-session-inventory-drift
**Source:** BREEDON-RANALDO-FX-INTRADAY-2013
**Author of this spec:** Codex
**Last revised:** 2026-09-10

## 1. Strategy Logic

On the exact 10:00 Australia/Sydney H1 bar of Monday through Friday, the EA submits one market SELL when no position is owned by its magic, the local date has not been consumed, completed H1 ATR and execution metadata are valid, and uncached news-calendar checks clear the full owned interval. The date is persisted and flushed before submission, so a broker rejection or restart cannot create a second attempt.

The position has a 1.5-times completed H1 ATR(14) hard stop, no profit target, and is flattened at or after 16:00 Sydney time. Sydney DST uses recurring civil-time rules and unique local/UTC round trips. Clock ambiguity, missing history, stale news data, invalid risk geometry, and ownership faults all fail closed. There is no momentum filter, grid, averaging, pyramiding, reversal, banned indicator, or ML/adaptive component.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| strategy_atr_period_h1 | 14 | locked 14 | Completed H1 ATR period for the initial hard stop |
| strategy_hard_stop_atr | 1.5 | locked 1.5 | Initial hard-stop distance in completed H1 ATR units |

The configuration guard additionally locks `qm_ea_id=41149`, `qm_magic_slot_offset=0`, and fixed-risk mode (`RISK_PERCENT=0`, finite `RISK_FIXED>0`). It does not compare RNG, news, or Friday-close inputs. Stress rejection is checked only for finiteness and inclusive 0..1 range.

## 3. Symbol Universe

**Designed for:**

- The chart carrier `_Symbol`, bound by the registry and canonical setfile to `AUDUSD.DWX`.
- Slot 0, magic `411490000`.

**Explicitly not for:**

- Other carriers or multi-symbol execution. A carrier change creates a new strategy identity.
- Grid, martingale, averaging, pyramiding, post-session reversal, or discretionary filtering.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Chart and execution timeframe | H1 |
| Signal time | exact 10:00 Australia/Sydney H1 open |
| Owned interval | [10:00,16:00] Australia/Sydney local civil time |
| Volatility input | H1 ATR(14), completed shift 1 only |
| Bar gating | one `QM_IsNewBar(_Symbol, PERIOD_H1)` consume per tick |

A session without an exact executable 10:00 H1 bar is operationally non-trading. This makes a closed-market holiday fail closed. The approved card does not identify a versioned Australian/NSW civil-holiday dataset, so the build does not invent an additional jurisdictional calendar; such a rule requires a governed calendar artifact.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Maximum opportunities | one per Sydney weekday before no-trade filters |
| Card frequency declaration | approximately 100 trades/year/symbol; Q02 measures the actual implementation |
| Direction | SELL AUDUSD during the Australian local trading session |
| Typical hold time | at most six hours, always flat at/after 16:00 Sydney |
| Refutation focus | post-cost sign, stability across Sydney DST regimes, and concentration in news dates |

Six fresh trailing-hour news checks at 11:00 through 16:00 Sydney cover the complete [10:00,16:00] interval. Missing or stale tester/live calendar coverage blocks the entry.

## 6. Source Citation

**Source ID:** BREEDON-RANALDO-FX-INTRADAY-2013

**Citation:** Francis Breedon and Angelo Ranaldo (2013), “Intraday Patterns in FX Returns and Order Flow,” *Journal of Money, Credit and Banking* 45(5), 953–965.

**Primary source:** https://www.snb.ch/public/asset/en/www-snb-ch/publications/research/working-papers/2011/working_paper_2011_04/publications0_en/working_paper_2011_04.n.pdf

**Card pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_41149_audusd-local-session-inventory-drift.md

The source's Table 1 defines Australian local trading hours as 10:00–16:00. The card predeclares the source-signed AUD depreciation expression. No paper performance statistic or portfolio property is transferred to this EA.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest | RISK_FIXED | $1,000 per trade with RISK_PERCENT=0 |
| Live | not authorized | Any future risk requires downstream portfolio and deployment approval |

The framework sizes from entry-to-stop geometry and rejects invalid tick-value, volume, or stop metadata. The initial stop is never widened or trailed. Friday-close and kill-switch handling run before strategy entry logic. An ownership fault flattens every position owned by this magic at the first safe executable point.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-10 | Initial build from approved card | build task `8a6b57f0-4911-431d-8c1c-4f1be85fd431`; compile successor `72ea3a08-296e-4eaf-92f3-15282343e002`; Q02 `12134047-e835-498f-9a5e-c10598be9749` |
