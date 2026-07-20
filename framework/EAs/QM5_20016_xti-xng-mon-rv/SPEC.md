# QM5_20016_xti-xng-mon-rv - Strategy Spec

**EA ID:** QM5_20016  
**Slug:** `xti-xng-mon-rv`  
**Source:** `TGIF-WTI-WEEKEND-2017` (see `strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/`)  
**Author of this spec:** Codex  
**Last revised:** 2026-07-20

## 1. Strategy Logic

On the first eligible tick of each broker-calendar Monday D1 bar, the EA sells
`XTIUSD.DWX` and buys `XNGUSD.DWX` as one package. It jointly sizes the legs
to target equal absolute USD notionals while their two frozen `3 * ATR(20)`
hard stops consume no more than one fixed-risk budget. Both legs close at the
first tick of the next host D1 bar; any orphan, wrong-direction, duplicate,
missing-stop, or materially unbalanced package is closed immediately.

The source paper reports opposite Monday-return signs, but its observations
are Friday-close to Monday-close. This executable Monday-open carrier misses
the weekend gap and is a QM translation that Q02 must falsify. The two
standalone component directions already exist elsewhere in the registry; this
EA is valid only as the jointly sized and jointly repaired logical package.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | locked | registered foreign Natural Gas leg |
| `strategy_entry_dow` | 1 | locked | Monday, where Sunday is zero |
| `strategy_entry_grace_minutes` | 5 | locked | maximum delay from D1 bar open |
| `strategy_atr_period_d1` | 20 | locked | completed-D1 ATR stop estimator |
| `strategy_atr_sl_mult` | 3.0 | locked | frozen hard-stop multiple per leg |
| `strategy_notional_ratio` | 1.0 | locked | XTI:XNG absolute USD notional target |
| `strategy_max_notional_error_pct` | 20.0 | locked | maximum rounded/filled target error |
| `strategy_max_hold_days` | 3 | locked | missing-boundary stale guard |
| `strategy_xti_max_spread_pts` | 1000 | locked | WTI entry spread ceiling |
| `strategy_xng_max_spread_pts` | 2500 | locked | Natural Gas entry spread ceiling |
| `strategy_deviation_points` | 20 | locked | paired market-order deviation |

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - D1 host and fixed Monday short, magic slot 0.
- `XNGUSD.DWX` - fixed Monday long foreign leg, magic slot 1.
- `QM5_20016_XTI_XNG_MON_RV_D1` - logical tester symbol; the only valid result.

**Explicitly NOT for:**

- Standalone XTI or XNG tests - either leg alone violates the card.
- Other commodities - the same-source opposite Monday signs are specific to
  the WTI and Natural Gas observations selected by the card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; both legs use synchronized D1 bars |
| Bar gating | `QM_IsNewBar()` on the XTI D1 host |
| Q02 shared window | 2018-01-02 through 2024-12-31 |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 48 completed paired packages; retire below five |
| Expected frequency | one eligible Monday package per broker week |
| Typical hold time | one D1 bar, normally Monday open to Tuesday open |
| Expected drawdown profile | high until gap, legging, basis, and stop behavior are measured |
| Regime preference | fixed cross-energy weekday differential |
| Win rate target (qualitative) | unknown before Q02 |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `TGIF-WTI-WEEKEND-2017`  
**Source type:** peer-reviewed academic paper  
**Pointer:** https://jfi-aof.org/index.php/jfi/article/view/2264 and
`strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/source.md`  
**R1-R4 verdict (Q00):** all PASS per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20016_xti-xng-mon-rv.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per complete package (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This card authorizes backtest research only;
it does not authorize a live preset or deployment action.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-20 | Initial build from card | task `45b03eb8-039c-4f1e-a6df-2b2a3a50ea8c` |
