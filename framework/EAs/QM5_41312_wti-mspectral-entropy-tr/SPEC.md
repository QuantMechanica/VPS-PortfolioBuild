# QM5_41312_wti-mspectral-entropy-tr - Strategy Spec

**EA ID:** QM5_41312

**Slug:** `wti-mspectral-entropy-tr`

**Strategy ID:** `URIGUEN-MOP-WTI-SPECENT-20260902_S01`

**Source:** `URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902`

**Author:** Development

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
reconstruct forty-nine consecutive completed broker-month-end closes and form
forty-eight chronological adjacent log returns. Subtract the return mean, run
an exact length-48 discrete Fourier transform, and measure normalized Shannon
entropy over the twenty-four one-sided non-DC power bins.

Follow the newest twelve-month WTI return sign for one broker month only when
spectral entropy is at most `0.88`. This combines peer-reviewed normalized
spectral-power entropy semantics with a peer-reviewed monthly WTI own-return
continuation carrier. The exact conjunction, window, and boundary are a
QuantMechanica research hypothesis. Entropy and momentum magnitude never
scale risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 48 | completed adjacent monthly log returns |
| `strategy_dft_bins` | 24 | one-sided non-DC bins, including Nyquist |
| `strategy_total_power_floor` | `1e-24` | strict fail-closed total-power floor |
| `strategy_probability_tolerance` | `1e-10` | unit probability-sum tolerance |
| `strategy_entropy_lower_tolerance` | `1e-12` | admitted negative roundoff magnitude |
| `strategy_entropy_upper_tolerance` | `1e-10` | admitted above-one roundoff magnitude |
| `strategy_entropy_ceiling` | `0.88` | inclusive low-entropy gate |
| `strategy_momentum_months` | 12 | newest returns used for direction |
| `strategy_direction_epsilon` | `1e-12` | symmetric neutral band |
| `strategy_history_bars` | 1500 | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | inclusive entry-cost ceiling |

Q02 has one baseline and no optimization surface.

## 3. Symbol Universe, Clock, and Exact Formula

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Symbol slot: 0; governed magic: `413120000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of that D1 boundary.
- Current-month prices are excluded from the signal.
- No proxy, substitute carrier, futures curve, inventory series, spread, or
  secondary symbol is authorized.

For chronological completed-month closes `C[0..48]`:

```text
x[i] = ln(C[i+1] / C[i]), i=0..47
mean = sum(x[i]) / 48
y[i] = x[i] - mean
```

For `k=1..24`, calculate the unnormalized length-48 DFT with no taper or
padding:

```text
Re[k] = sum(y[i]*cos(2*pi*k*i/48), i=0..47)
Im[k] = -sum(y[i]*sin(2*pi*k*i/48), i=0..47)
raw[k] = Re[k]^2 + Im[k]^2
power[k] = 2*raw[k], k=1..23
power[24] = raw[24]
total = sum(power[1..24])
p[k] = power[k] / total
Hspec = -sum(p[k]*ln(p[k]), p[k]>0) / ln(24)
mom12 = sum(x[36..47])
```

Require finite arithmetic, `total > 1e-24`, probability sum within `1e-10`
of one, and entropy within `[-1e-12,1+1e-10]`; clamp only admitted roundoff
to `[0,1]`. Nyquist bin 24 is not doubled. Then:

```text
BUY  iff Hspec <= 0.88 and mom12 > +1e-12
SELL iff Hspec <= 0.88 and mom12 < -1e-12
FLAT otherwise
```

The embedded fixtures require a pure paired-frequency cosine to have total
power `0.4608` and entropy zero, an equal-amplitude Nyquist path to have total
power `0.2304` and entropy zero, and a constant return path to fail the strict
power floor.

## 4. Timeframe, Entry, Risk, and Attempt Semantics

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualified month may open one market position with a
frozen completed-bar `3.5*ATR(20,D1)` broker hard stop and no target. Existing
owned exposure or foreign `XTIUSD.DWX` exposure blocks entry. Framework quote,
contract, tick, volume, sizing, and margin guards remain authoritative.

The normalized broker-month attempt is persisted before history, signal,
news, spread, quote, ATR, sizing, margin, or order gates. A failed gate cannot
cause a same-month retry. Entry-month state is persisted only after a
confirmed fill and may be recovered from matching position-deal history after
restart.

Both news axes and legacy news are OFF. Friday close and stress rejection are
disabled. Entry spread must be finite and in `[0,1500]` points.

## 5. Expected Behaviour, Management, and Exit

An owned position closes on the first processed tick in a later normalized
broker month or after forty elapsed calendar days. Missing or inconsistent
position, stop, side, entry-time, or entry-month state causes a defensive
strategy close. There is no target, trail, break-even, partial close, entropy
exit, intramonth flip, Friday flatten, retry, scale-in, grid, martingale, or
pyramid.

The framework kill switch and broker hard stop remain authoritative. Runtime
uses only MT5-native price, calendar, ATR, quote, position, deal, and
terminal-global state. It has no external runtime feed, optimizer, randomized
tie breaker, trained artifact, or portfolio-state dependency.

## 6. Source Citation and Expected Activity

The governed packet is
`strategy-seeds/sources/URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902/source.md`.
Uriguen et al. support normalized power-spectral entropy and its zero-power
term. Pinned SciPy source fixes constant detrending and one-sided paired versus
Nyquist power semantics. Moskowitz, Ooi, and Pedersen support monthly
own-return continuation and explicit WTI membership. None evaluates this
exact gate, threshold, CFD transport, risk contract, or portfolio fit.

A fixed-seed, market-free normal simulation qualified 59,188 of 100,000
forty-eight-return draws (`59.188%`), implying a pre-data cadence prior of
`7.10256` qualifying states per twelve clocks. This is a formula-density
check, not WTI performance evidence.

## 7. Risk Model and Kill Criteria

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; the only protective order is the frozen completed-D1
`3.5*ATR(20)` broker stop. There is no take-profit or dynamic risk scaling.

Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
single-carrier concentration, broker-month labels, short spectral samples,
outliers, and correlation with XNG or risk assets. A hard stop can slip
through gaps. Low spectral entropy describes frequency-power concentration;
it does not prove predictability, periodicity, stationarity, independence, or
decorrelation. Live use is not authorized.

Retire on zero positions, fewer than five completed positions in any full
scored post-warm-up year, nonpositive governed economics, nondeterminism, or
any endpoint, return, demeaning, DFT, paired/Nyquist power, normalization,
entropy, direction, fixed-risk, hard-stop, lifecycle, or downstream-gate
failure. Q09 alone may establish or reject portfolio diversification.

## Framework Alignment

- `Strategy_NoTradeFilter`: identity, registered magic, fixed risk,
  news/Friday/stress contract, and every strategy lock.
- bounded helpers: month clock, attempt state, endpoint reconstruction,
  return orientation, demeaning, exact DFT, one-sided power, normalization,
  entropy boundary, momentum side, and restart recovery.
- `Strategy_EntrySignal`: foreign/owned exposure, spread, quote, ATR, frozen
  stop, and one fixed-risk market request.
- `Strategy_ManageOpenPosition`: malformed-state repair, side validation,
  next-month exit, and forty-day stale exit.
- `Strategy_ExitSignal`: no additional discretionary exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | approved source build | G0-approved card; magic `413120000`; Q01 pending |
