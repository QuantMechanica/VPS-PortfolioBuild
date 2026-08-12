# QM5_20015_wti-halloween-winter - Strategy Spec

**EA ID:** QM5_20015
**Slug:** `wti-halloween-winter`
**Source:** `BURAKOV-WTI-HALLOWEEN-2018` (see `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-20

## 1. Strategy Logic

The EA carries WTI long exposure during the source's November-May winter
interval and remains flat from June through October. It packages that exposure
as seven non-overlapping monthly trades: close the prior package at each
broker-month boundary, reopen long in November-May, and never re-enter after a
stop within the same month. Every entry uses a frozen D1 ATR hard stop.

## 2. Parameters

| Parameter | Default | Authorized value | Meaning |
|---|---:|---:|---|
| `strategy_first_long_month` | 11 | 11 | First winter-exposure broker month |
| `strategy_last_long_month` | 5 | 5 | Last winter-exposure broker month |
| `strategy_atr_period` | 20 | 20 | Completed D1 ATR hard-stop period |
| `strategy_atr_sl_mult` | 4.0 | 4.0 | Frozen ATR stop multiple |
| `strategy_max_hold_days` | 35 | 35 | Stale guard around monthly renewal |
| `strategy_max_spread_points` | 1500 | 1500 | WTI entry spread cap |

All strategy parameters are locked for Q02. A different seasonal boundary,
continuous annual hold, summer short or price filter requires a new card.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` (slot 0) - registered Darwinex WTI CFD proxy named by the
  OWNER commodity-sleeve mission and supported by the local D1 tester route.

**Explicitly not for:**

- `XNGUSD.DWX` - the source's U.S. natural-gas row reports the reverse effect
  and the current book already contains separate XNG logic.
- Gold, silver, indices and FX - outside this West Texas source extraction.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; broker-month keys plus completed D1 ATR only |
| Bar gating | one framework `QM_IsNewBar()` consume on the D1 host |

The EA does not require MN1 bars or any external seasonal calendar.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 7 as a deterministic calendar prior; Q02 must verify at least 5 |
| Typical hold time | one broker month, capped at 35 calendar days |
| Expected drawdown profile | high WTI gap/financing/basis risk bounded by fixed dollar risk and a broker stop |
| Regime preference | positive WTI November-May seasonal carry |

## 6. Source Citation

**Source ID:** `BURAKOV-WTI-HALLOWEEN-2018`
**Source type:** peer-reviewed open-full-text paper (tier B)
**Pointer:** `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`
**R1-R4 verdict (G0):** all PASS; see the approved card.

Burakov, D., Freidin, M. and Solovyev, Y. (2018), "The Halloween
Effect on Energy Markets: An Empirical Study," *International Journal of
Energy Economics and Policy* 8(2), 121-126.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | $1,000 per trade (HR4) |
| Live burn-in (Q13) | `RISK_PERCENT` | Min-lot equivalent under an OWNER manifest |
| Full live (post-Q13 PASS) | `RISK_PERCENT` | Allocated by the later portfolio process |

ENV-to-mode validation is enforced by `QM_FrameworkInit`. This build creates
no live setfile and does not touch T_Live, AutoTrading, deploy/T_Live
manifests, portfolio admission or the portfolio gate.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-20 | Initial source-backed WTI winter-season build | task `5f18eea1-3d7e-4787-ba31-b823373c7569` |
