# QM5_41275_wti-mqndisp-tr - Strategy Spec

**EA ID:** QM5_41275

**Slug:** `wti-mqndisp-tr`

**Strategy ID:** `AI-CODEX-WTI-MQNDISP-TREND-20260901_S01`

**Source:** `AI-CODEX-WTI-MQNDISP-TREND-20260901`

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker
month, reconstruct the immediately completed month. Require 17 through 23
completed sessions and select its final seventeen closes chronologically.
Form sixteen adjacent log returns and verify their sum against the endpoint
log return.

Sort all 120 pairwise absolute distances between those returns. The raw
36th one-based distance is `q_core`; no Qn consistency multiplier is used.
Buy when `net >= 4*q_core`, sell when `net <= -4*q_core`, and remain flat
between those inclusive boundaries. Require `q_core > 1e-12`.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_sessions_min` | 17 | completed-month session floor |
| `strategy_month_sessions_max` | 23 | completed-month session ceiling |
| `strategy_close_count` | 17 | final chronological closes |
| `strategy_return_count` | 16 | adjacent log returns |
| `strategy_distance_count` | 120 | all unordered return pairs |
| `strategy_qn_order_one_based` | 36 | raw Qn-core order statistic |
| `strategy_qn_core_floor` | 1e-12 | strict usable-core floor |
| `strategy_net_core_multiplier` | 4.0 | inclusive direction boundary |
| `strategy_endpoint_tolerance` | 1e-10 | return-orientation identity |
| `strategy_history_bars_d1` | 120 | bounded month reconstruction |
| `strategy_entry_window_minutes` | 180 | first-month-bar grace |
| `strategy_atr_period_d1` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale survivor repair |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |
| `strategy_deviation_points` | 20 | execution deviation lock |

There is one Q02 baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; governed magic: `412750000`.
- Runtime inputs are native MT5 prices, calendar, ATR, quotes, positions,
  deals, and terminal-persistent attempt state.
- There is no companion, hedge, conversion, or external runtime feed.

## 4. Timeframe

```text
C = final 17 chronological closes of immediately completed month
r[i] = ln(C[i+1] / C[i]), i=0..15
net = sum(r)
require abs(net - ln(C[16]/C[0])) <= 1e-10

D = sort(abs(r[j]-r[i]) for 0<=i<j<=15)
require len(D) == 120
q_core = D[35]
require q_core > 1e-12

BUY  if net >=  4*q_core
SELL if net <= -4*q_core
FLAT otherwise
```

For `n=16`, `h=floor(n/2)+1=9` and `k=C(h,2)=36`. The
implementation uses only the raw order statistic. It is a structural
classifier, not a significance test or volatility forecast.

Wrong history, month membership, chronology, session count, close, return,
endpoint, distance count, sort, index, core, or side consumes the month flat.

## 5. Expected Behaviour

The strategy persists the month attempt before history, arithmetic, news,
spread, quote, ATR, sizing, margin, or order gates. It opens at most one
position per month with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The stop is a frozen completed-bar
`3.5*ATR(20,D1)`; there is no target.

An owned position closes on the first tick in a later normalized broker
month or after forty calendar days. Duplicate, malformed, wrong-symbol,
wrong-side, or stopless exposure is repaired before entry-only gates.
There is no retry, trail, break-even, partial close, grid, martingale,
pyramid, scale-in, or opposite-signal exit.

Both news axes, legacy news, and Friday close are disabled.

## 6. Source Citation

The governed packet is
`strategy-seeds/sources/AI-CODEX-WTI-MQNDISP-TREND-20260901/source.md`.
Moskowitz, Ooi, and Pedersen (2012) support only WTI membership and monthly
own-return continuation. Rousseeuw and Croux (1993) support only the Qn
pairwise-distance order statistic. The exact daily-return trading
conjunction, continuous-CFD translation, fixed risk, stop, and lifecycle are
disclosed pre-result QM synthesis.

The canonical dedup receipt is
`artifacts/qm5_wti_mqndisp_tr_preallocation_dedup_20260901.json`.
Unlike `QM5_41126` (L1 path efficiency) and `QM5_41124` (RMS
coherence), this signal uses only the 36th of 120 pairwise return distances.
Fixed fixtures prove qualification disagreement in both directions. It also
uses no old/recent monthly group comparison, endpoint-only sign, permutation,
or rank-scale score.

Direct WTI introduces a physical crude-oil carrier absent from the stated
certified XAU/SP500/NDX/XNG book. This is not a decorrelation result; Q09
alone owns realized overlap.

## 7. Risk Model

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, failed deterministic fixtures, nonpositive governed
economics, or any downstream gate failure. WTI gaps, geopolitical and
inventory shocks, continuous-CFD roll/basis and financing, sparse decisions,
and correlation with gas or risk assets remain material risks.

This build authorizes no live preset, deployment, portfolio admission, or
correlation waiver.

## Framework Alignment

- `no_trade`: identity, carrier, period, risk/news/Friday/input locks,
  month clock, attempt, history, quote, spread, ATR, and sizing guards.
- `trade_entry`: cached Qn-core side, one fixed-risk market order, frozen
  ATR stop, and no target.
- `trade_management`: malformed-position, next-month, and forty-day repair.
- `trade_close`: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-09-01 | approved source build | G0-approved card; governed magic `412750000` |
