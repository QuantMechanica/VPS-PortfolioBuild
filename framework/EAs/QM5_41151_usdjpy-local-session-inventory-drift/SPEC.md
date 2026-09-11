# QM5_41151_usdjpy-local-session-inventory-drift — Strategy Spec

**EA ID:** QM5_41151
**Slug:** usdjpy-local-session-inventory-drift
**Source:** BREEDON-RANALDO-FX-INTRADAY-2013
**Author of this spec:** Codex
**Last revised:** 2026-09-11

## 1. Strategy Logic

On the exact 09:00 Asia/Tokyo H1 bar of Monday through Friday, the EA submits one market BUY when no position is owned by its magic, the Tokyo date has not been consumed, completed H1 ATR and execution metadata are valid, and uncached news-calendar checks clear the full owned interval. The date is persisted and flushed before submission, so a broker rejection or restart cannot create a second attempt.

The position has a 1.5-times completed H1 ATR(14) hard stop, no profit target, and is flattened at or after 18:00 Tokyo time. Japan Standard Time is the fixed UTC+09:00 civil-time contract and has no DST transition. Invalid clock conversion, missing history, stale news data, invalid risk geometry, and ownership faults all fail closed. There is no momentum filter, grid, averaging, pyramiding, reversal, banned indicator, or ML/adaptive component.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| strategy_atr_period_h1 | 14 | locked 14 | Completed H1 ATR period for the initial hard stop |
| strategy_hard_stop_atr | 1.5 | locked 1.5 | Initial hard-stop distance in completed H1 ATR units |

The configuration guard additionally locks `qm_ea_id=41151`, `qm_magic_slot_offset=0`, and fixed-risk mode (`RISK_PERCENT=0`, finite `RISK_FIXED>0`). It does not compare RNG, news, or Friday-close inputs. Stress rejection is checked only for finiteness and inclusive 0..1 range.

## 3. Symbol Universe

**Designed for:**

- The chart carrier `_Symbol`, bound by the registry and canonical setfile to `USDJPY.DWX`.
- Slot 0, magic `411510000`.

**Explicitly not for:**

- Other carriers or multi-symbol execution. A carrier change creates a new strategy identity.
- Grid, martingale, averaging, pyramiding, post-session reversal, or discretionary filtering.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Chart and execution timeframe | H1 |
| Signal time | exact 09:00 Asia/Tokyo H1 open |
| Owned interval | [09:00,18:00] Asia/Tokyo local civil time |
| Volatility input | H1 ATR(14), completed shift 1 only |
| Bar gating | one `QM_IsNewBar(_Symbol, PERIOD_H1)` consume per tick |

The fixed 09:00–18:00 JST mapping is the existing governed Tokyo local-hours convention recorded by `QM5_1333_chan-fx-local-hours` as 00:00–09:00 UTC. A session without an exact executable 09:00 H1 bar is operationally non-trading. The approved card does not identify a versioned Japanese civil-holiday dataset, so the build does not invent a holiday proxy; adding one requires a governed card/calendar revision.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Maximum opportunities | one per Tokyo weekday before no-trade filters |
| Card frequency declaration | approximately 100 trades/year/symbol; Q02 measures the actual implementation |
| Direction | BUY USDJPY, expressing JPY depreciation during Japanese local hours |
| Typical hold time | at most nine hours, always flat at/after 18:00 JST |
| Regime | structural local-session inventory drift |

Nine fresh trailing-hour news checks at 10:00 through 18:00 JST cover the complete [09:00,18:00] interval. Missing or stale tester/live calendar coverage blocks the entry.

## 6. Source Citation

**Source ID:** BREEDON-RANALDO-FX-INTRADAY-2013

**Citation:** Francis Breedon and Angelo Ranaldo (2013), “Intraday Patterns in FX Returns and Order Flow,” *Journal of Money, Credit and Banking* 45(5), 953–965.

**Primary source:** https://www.snb.ch/public/asset/en/www-snb-ch/publications/research/working-papers/2011/working_paper_2011_04/publications0_en/working_paper_2011_04.n.pdf

**Card pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_41151_usdjpy-local-session-inventory-drift.md

R1 lineage is recorded and R2–R4 PASS per the approved card. The durable local-hours reference spec defines the Tokyo interval as 00:00–09:00 UTC, equivalent to 09:00–18:00 JST; the card predeclares the source-signed JPY depreciation expression. No paper performance statistic or portfolio property is transferred to this EA.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest | RISK_FIXED | $1,000 per trade with RISK_PERCENT=0 |
| Live | not authorized | Any future risk requires downstream portfolio and deployment approval |

The framework sizes from entry-to-stop geometry and rejects invalid tick-value, volume, or stop metadata. The initial stop is never widened or trailed. Friday-close and kill-switch handling run before strategy entry logic. An ownership fault flattens every position owned by this magic at the first safe executable point.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-11 | Initial build from approved card | build task `c41b054d-8bb2-4c6a-9506-8d366b4f5869` |

