# QM5_41245_wti-mcusum-shift-tr - Strategy Spec

**EA ID:** QM5_41245  
**Slug:** `wti-mcusum-shift-tr`  
**Strategy ID:** `AI-CODEX-WTI-MCUSUM-20260831_S01`  
**Source:** `AI-CODEX-WTI-MCUSUM-20260831`  
**Author:** Codex  
**Last revised:** 2026-08-31

## 1. Strategy logic

On the first executable `XTIUSD.DWX` D1 bar of a normalized broker month,
reconstruct thirteen consecutive completed broker-month-end closes. Convert
them to twelve chronological adjacent log returns and subtract the full-sample
return mean from each partial sum. Scan only splits `k=1..11`; the terminal
twelve-return sum is identically zero and is never a candidate.

The signal qualifies only when the largest absolute centered cumulative sum is
strictly positive, unique within `1e-12`, and located at `k=4..8`. Follow the
arithmetic mean of the returns after that split: positive buys WTI, negative
sells WTI, and a mean within `1e-12` of zero stays flat. The month is consumed
before history, arithmetic, execution, or order gates, so no failure retries.

## 2. Locked parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 12 | completed adjacent monthly log returns |
| `strategy_min_split` | 4 | earliest qualifying split |
| `strategy_max_split` | 8 | latest qualifying split |
| `strategy_tie_epsilon` | `1e-12` | absolute maximum-tie and zero-side tolerance |
| `strategy_history_bars` | 900 | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | first-month-bar raw execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | entry-cost ceiling |

There is one Q02 baseline and no optimization surface.

## 3. Symbol and runtime

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `412450000`.
- Native MT5 price, calendar, ATR, quote, position, deal, and persistent state
  are the only runtime inputs.
- There is no companion, conversion, ratio, hedge, external, or signal symbol.

## 4. Formula

```text
r[i] = log(C[i+1] / C[i]), i=0..11
mean = sum(r[0..11]) / 12

for k=1..11:
    S[k] = sum(r[0..k-1]) - k*mean

M = max(abs(S[k]))
K = {k : abs(abs(S[k]) - M) <= 1e-12}

qualify iff M > 1e-12 and size(K)=1 and 4 <= K[0] <= 8
post_mean = sum(r[K[0]..11]) / (12-K[0])

BUY  iff qualify and post_mean >  1e-12
SELL iff qualify and post_mean < -1e-12
FLAT otherwise
```

Every endpoint, ratio, logarithm, return, sum, mean, path value, and post mean
must be finite. Missing or duplicate months, a zero path, a tied maximum, an
edge maximum, a zero post mean, or arithmetic failure consumes the month flat.

## 5. Entry and risk

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualifying month can open at most one market position,
with a frozen completed-bar `3.5*ATR(20,D1)` broker hard stop and no target.
The EA rejects malformed/crossed quotes, invalid point metadata, and a spread
above 1,500 points; a valid modeled zero spread is allowed. Signal magnitude
and split location never scale risk.

Both news axes and legacy news are OFF. Friday close is disabled so a position
can retain the approved monthly holding period.

## 6. Exit and deterministic failure contract

An owned position closes on the first tick in a later normalized broker month
or after forty calendar days. Duplicate, malformed, wrong-symbol, wrong-side,
missing-stop, or otherwise invalid owned exposure is repaired before
entry-only gates. There is no target, trail, break-even, partial close,
same-month retry, scale-in, grid, martingale, pyramid, or opposite-signal exit.

## 7. Evidence and non-duplication

The governed source packet is
`strategy-seeds/sources/AI-CODEX-WTI-MCUSUM-20260831/source.md`. It records the
complete Moskowitz, Ooi, and Pedersen (2012) WTI monthly-continuation evidence,
Page (1954) bibliographic method record, the complete official NIST CUSUM
method page, and the explicitly untested trading synthesis.

Preallocation dedup receipt:
`artifacts/qm5_wti_mcusum_shift_tr_preallocation_dedup_20260831.json`, SHA-256
`F397FDCF63414FF4CFE1C64AA9D1EEE9DE368643F30B3451F2785F06B61C45D2`.
The edge uses magnitude-bearing log returns and an endogenous centered partial
sum. Existing nearby WTI builds use ranks, fixed ECDF gaps, pair counts, OLS
price slopes, or same-calendar returns. No realized decorrelation claim is
made; Q09 alone may establish portfolio overlap.

## 8. Expected behavior and kill criteria

The pre-result cadence prior is five to nine completed positions per full
post-warm-up year. Q02 retires on zero positions, fewer than five in any full
year, nonpositive governed economics, or any deterministic-fixture failure.
Continuous-CFD roll/basis, financing, gaps, small-sample split instability,
and broker month-label offsets remain material risks.

## Framework alignment

- `no_trade`: exact host, period, identity, slot, risk, news, Friday, stress,
  and strategy locks.
- `trade_entry`: consumed month, consecutive completed endpoints, exact CUSUM,
  cached post-segment side, quote/spread/ATR/stop guards, one fixed-risk order.
- `trade_management`: malformed/wrong-side repair, next-month exit, stale exit.
- `trade_close`: V5 close helper, broker hard stop, and kill switch.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-31 | approved source build | G0-approved card; governed magic `412450000` |

