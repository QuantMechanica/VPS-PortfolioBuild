# QM5_41280_usdchf-ww-shift-tr - Strategy Spec

**EA ID:** QM5_41280

**Slug:** usdchf-ww-shift-tr

**Strategy ID:** AI-CODEX-USDCHF-WW-SHIFT-20260902_S01

**Source:** AI-CODEX-USDCHF-WW-SHIFT-20260902

**Author of this spec:** Codex

**Last revised:** 2026-09-02

## 1. Strategy Logic

On each new USDCHF.DWX D1 processing edge, the EA compares the current
framework PERIOD_W1 key with its terminal-persistent consumed-week key. If the
week is new to this EA, it persists that week before history, signal, news,
spread, quote, ATR, sizing, margin, or order checks. Only a genuine first D1
bar of the new broker week observed within 360 elapsed minutes may proceed;
later starts consume the week flat.

The signal reads exactly shifts 12 through 1 from native USDCHF.DWX D1
history, producing twelve completed closes in chronological order. Timestamps
must be positive, unique, and strictly increasing. Closes must be positive,
finite, and pairwise distinct. The first six closes form the fixed older
sample and the final six form the fixed newer sample.

For all 36 cross-block pairs:

    U_new = count(newer[j] > older[i])
    U_old = count(older[i] > newer[j])

The EA requires U_new + U_old = 36 and independently verifies that U_new is
the newer combined rank sum minus 21. It buys when U_new is at least 24, sells
when U_new is at most 12, and consumes the week flat otherwise. There is no
tie averaging, p-value, fitted coefficient, variable split, endpoint fallback,
volatility signal, or signal-strength sizing.

A qualifying side opens at market with a frozen normalized
3.0 * ATR(20,D1) hard stop, no target, and no second position. Spread must not
exceed 50 points. The framework Friday close at broker hour 21 is the normal
exit. Seven elapsed calendar days and malformed-position repair are
authoritative fallbacks.

## 2. Parameters

The Q02 baseline is locked; there is no optimization grant.

| Parameter | Default | Status | Meaning |
|---|---:|---|---|
| strategy_endpoint_count | 12 | locked | completed D1 closes |
| strategy_block_size | 6 | locked | fixed older/newer sample size |
| strategy_u_lower | 12 | locked inclusive | short boundary |
| strategy_u_upper | 24 | locked inclusive | long boundary |
| strategy_history_bars_d1 | 128 | locked | bounded warm-up request |
| strategy_entry_window_minutes | 360 | locked | weekly entry grace |
| strategy_atr_period_d1 | 20 | locked | completed-bar stop estimator |
| strategy_atr_sl_mult | 3.0 | locked | hard-stop distance |
| strategy_max_hold_days | 7 | locked | stale repair |
| strategy_max_spread_points | 50 | locked | entry spread ceiling |
| strategy_deviation_points | 20 | locked | framework execution tolerance |

Framework values are also locked: EA ID 41280, slot 0, RNG seed 42,
RISK_FIXED 1000, RISK_PERCENT 0, PORTFOLIO_WEIGHT 1, both new news axes OFF,
legacy news OFF, stale ceiling 336 hours, Friday close enabled at hour 21, and
stress rejection zero.

## 3. Symbol Universe

**Designed for:** exact USDCHF.DWX, registry slot 0, governed magic 412800000.

The build is single-symbol and D1-only. It must not strip the .DWX suffix,
trade another CHF cross, add a second leg, or read rates, futures, macro,
files, forecasts, portfolio state, or external APIs.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Host and execution timeframe | D1 |
| Decision clock | first eligible D1 edge of a new framework broker week |
| Formation | shifts 12 through 1, forming bar excluded |
| Risk reference | completed D1 ATR(20), shift 1 |
| Normal lifecycle | framework Friday close at 21:00 broker time |
| Repair lifecycle | seven elapsed calendar days |

The EA requests 128 D1 bars during framework warm-up and performs twelve
bounded QM_ReadBar calls only after the D1 closed-bar gate and weekly
consumption boundary.

## 5. Expected Behaviour

The pre-result operating prior is about 10 to 25 completed positions per full
post-warm-up year. At most one attempt is consumed per framework broker week.
Exactly 364 of the 924 strict six-of-twelve rank assignments qualify, split
182 long and 182 short. That is a combinatorial design fact, not a market
probability or performance claim.

Positions normally last from the first weekly decision until Friday. Principal
risks are CHF discontinuities, weekly reversal, Friday liquidity, gaps,
financing, boundary instability, and downstream portfolio overlap. Q02 owns
activity and economics; later Q-only gates own robustness, crisis behavior,
news behavior, and portfolio overlap.

## 6. Source Citation

The source of record is
strategy-seeds/sources/AI-CODEX-USDCHF-WW-SHIFT-20260902/source.md. Durable
source approval is
decisions/2026-09-02_usdchf_weekly_mann_whitney_shift_trend_source_approval.md,
and G0 approval is
decisions/2026-09-02_qm5_41280_usdchf_weekly_mann_whitney_shift_trend_g0.md.

Moskowitz, Ooi, and Pedersen (2012) supply broad own-price continuation
lineage. Mann and Whitney (1947) supply the named method record. The complete
pinned R Core wilcox.test implementation and manual supply the strict no-tie
rank-sum/pair-count identity. None tests USDCHF, this weekly carrier, twelve
D1 levels, boundaries 12/24, the ATR stop, Friday exit, CFD costs, or
profitability. Those are approved pre-result QuantMechanica translations.

The approved corrected-root dedup receipt found no exact or fuzzy duplicate
across the governed registry/card/wiki scope. Monthly WTI Mann-Whitney, daily
mean-return sign, 252-day cross-sectional FX momentum, and multi-leg USDCHF
cointegration remain mechanically distinct.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest Q02-Q10 | RISK_FIXED | 1,000 account-currency units |
| Live/deploy | not authorized | no preset, manifest, or terminal action |

The V5 entry path performs authoritative fixed-risk sizing against the
normalized broker hard stop. No target, trail, break-even, partial close,
scale-in, averaging, grid, martingale, or pyramid exists. The canonical set
uses RISK_FIXED=1000, RISK_PERCENT=0, and PORTFOLIO_WEIGHT=1.

The approved general diversity-lane card locks both news axes and legacy news
mode OFF. This build does not claim Edge Lab classification, FTMO compliance,
portfolio admission, deployment readiness, or live authorization.

## Framework Alignment

- no_trade: exact host, identity, risk, news, Friday, stress, and strategy
  locks.
- trade_entry: consumed week, six-hour genuine transition, same-week deal
  guard, exact twelve-bar rank statistic, spread, quote, ATR, and hard stop.
- trade_management: duplicate/malformed/wrong-symbol/wrong-side/stopless
  repair and seven-day stale close.
- trade_close: broker hard stop, framework Friday close, kill switch, and V5
  close helpers.

## Revision History

| Version | Date | Reason | Evidence |
|---|---|---|---|
| v1 | 2026-09-02 | Initial build from OWNER-approved card | router task 317b4d6a-3338-4603-8006-a4660ad6d5f1 |

