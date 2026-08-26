# QM5_41169_wti-foster-record-tr - Strategy Spec

**EA ID:** QM5_41169

**Slug:** `wti-foster-record-tr`

**Strategy ID:** `MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026_S01`

**Source:** `MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-26

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker
month, reconstruct the latest close in each of the immediately prior thirteen
consecutive completed broker months. Start the oldest close as both running
frontiers. Each later close is one strict upper record, strict lower record,
or neutral observation. Equality is neutral, and all twelve observations must
be conserved by the three counts.

Let `d = upper_count - lower_count`. Buy when `d >= 2`, sell when `d <= -2`,
and consume the month flat otherwise. A valid direction owns one fixed-risk
WTI position until the first later normalized broker month, protected by a
frozen ATR hard stop. No record magnitude or excess count changes risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_endpoint_count` | 13 | consecutive completed month-end closes |
| `strategy_record_threshold` | 2 | absolute record-count difference required |
| `strategy_history_bars_d1` | 900 | bounded endpoint reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | raw current-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All inputs are locked for one Q02 baseline. There is no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411690000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe And Formula

```text
running_high = running_low = C[0]
upper = lower = neutral = 0
for i = 1..12:
  if C[i] > running_high: upper += 1; running_high = C[i]
  else if C[i] < running_low: lower += 1; running_low = C[i]
  else: neutral += 1
require upper + lower + neutral == 12
d = upper - lower
BUY iff d >= 2; SELL iff d <= -2; otherwise FLAT
```

The formation and decision cadence are monthly. The current month contributes
no signal close. Strict comparisons make equal-to-frontier values neutral.

## 5. Expected Behaviour

- Pre-result density prior: five to eight completed WTI positions per full
  post-warm-up year; Q02 retires below five in any full year.
- Exactly 2,963,909,390 of `13!` distinct-rank permutations qualify, or
  47.5975508224%, implying 5.7117060987 monthly decisions per year. This is
  arithmetic, not a WTI independence, significance, frequency, or result.
- Symmetric direct-WTI structural continuation; one consumed attempt per
  broker month and at most one owned position.
- The path statistic is mechanically distinct from endpoint, fitted-slope,
  Mann-Kendall, Cox-Stuart paired-sign, quarterly-vote, and XNG pullback rules.
  Only Q09 may establish realized portfolio decorrelation.

## 6. Source Citation

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Foster and Stuart (1954), "Distribution-Free Tests in Time-Series Based on
the Breaking of Records," *JRSS B* 16(1), 1-22, DOI
`10.1111/j.2517-6161.1954.tb00143.x`.

Castillo-Mateo, Cebrian, and Asin (2023), "RecordTest," *Journal of
Statistical Software* 106(5), DOI `10.18637/jss.v106.i05`.

Canonical bounded packet:
`strategy-seeds/sources/MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026/source.md`.
The sources supply WTI monthly-continuation and strict forward-record lineage.
They do not test this thirteen-endpoint, threshold-two CFD trading rule.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes, legacy news,
and Friday close are OFF. Maximum entry spread is 1,500 points.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deployment, portfolio admission, portfolio-gate
change, alternate frontier, weak-record mode, dynamic threshold, retry,
scale-in, grid, martingale, target, trail, break-even move, or partial exit.

## 8. Deterministic Failure Contract

The month is durably consumed before history, arithmetic, news, spread,
quote, ATR, sizing, margin, or order checks. Missing/duplicate month keys,
mixed label conventions, stale endpoints, nonpositive/nonfinite closes,
wrong endpoint count, invalid frontier, broken count conservation, or
`abs(d)<2` fails flat. An order reject never retries the month. Lifecycle
repair runs every tick before entry-only gates and closes duplicate,
malformed, wrong-side, later-month, or stale owned exposure.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact consecutive
  endpoints, strict record counts, conservation, threshold-two direction,
  spread/quote/ATR/stop checks, and one fixed-risk request.
- trade_management: malformed or wrong-side repair, entry-month direction
  reconstruction, later-month exit, and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-26 | approved source build | G0-approved card and governed magic `411690000` |
