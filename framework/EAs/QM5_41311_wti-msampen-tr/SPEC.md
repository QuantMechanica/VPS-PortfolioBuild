# QM5_41311_wti-msampen-tr - Strategy Spec

**EA ID:** QM5_41311

**Slug:** `wti-msampen-tr`

**Strategy ID:** `RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902_S01`

**Source:** `RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902`

**Author:** Codex

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
reconstruct sixty-one consecutive completed broker-month-end closes. Convert
them to sixty chronological adjacent log returns. Calculate original sample
entropy with embedding dimension two, lag one, strict Chebyshev distance, and
a radius equal to `0.2` times the sample standard deviation of those returns.

Follow the newest twelve-month WTI return sign for one broker month only when
sample entropy is at most `2.5`. This combines an established monthly
own-return continuation carrier with a deterministic local-template
recurrence gate. The conjunction and threshold are research hypotheses, not
claims made by the cited papers. Entropy and momentum magnitude never scale
risk.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 60 | completed adjacent monthly log returns |
| `strategy_embedding_dimension` | 2 | sample-entropy template dimension |
| `strategy_embedding_lag` | 1 | adjacent elements within each template |
| `strategy_radius_sd_fraction` | `0.2` | strict match radius multiplier |
| `strategy_sd_floor` | `1e-12` | sample-SD fail-closed floor |
| `strategy_entropy_ceiling` | `2.5` | inclusive low-entropy gate |
| `strategy_momentum_months` | 12 | newest returns used for direction |
| `strategy_direction_epsilon` | `1e-12` | symmetric neutral band |
| `strategy_history_bars` | 1800 | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_endpoint_stale_days` | 10 | newest endpoint age ceiling |
| `strategy_atr_period` | 20 | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | survivor repair ceiling |
| `strategy_max_spread_points` | 1500 | inclusive entry-cost ceiling |

Q02 has one baseline and no optimization surface.

## 3. Carrier and Clock

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Symbol slot: 0; governed magic: `413110000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of that D1 boundary.
- Current-month prices are excluded from the signal.
- No proxy, substitute carrier, futures-chain feed, spread, or secondary
  symbol is authorized.

For chronological completed-month closes `C[0..60]`:

```text
x[i] = ln(C[i+1] / C[i]), i=0..59
mean = sum(x[i]) / 60
sd   = sqrt(sum((x[i]-mean)^2) / 59)
r    = 0.2 * sd
```

There are 59 length-two templates and 58 length-three templates. For each
dimension, count unordered pairs with distinct starting indices. A pair
matches only if every coordinate has absolute distance strictly less than
`r`; equality is not a match. Let `B` be the length-two count and `A` the
length-three count. Require `B >= A > 0`, then:

```text
SampEn = ln(B / A)
mom12  = sum(x[48..59])

BUY  iff SampEn <= 2.5 and mom12 > +1e-12
SELL iff SampEn <= 2.5 and mom12 < -1e-12
FLAT otherwise
```

The deterministic alternating-return fixture must produce `B=841`, `A=812`,
and `SampEn=ln(841/812)=0.03509131981127019`. A Chebyshev distance exactly
equal to the radius must not match.

## 4. Entry, Risk, and Attempt Semantics

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

## 5. Management and Exit

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

## 6. Expected Activity and Kill Criteria

A fixed-seed, market-free normal simulation qualified 59,272 of 100,000
sixty-return draws (`59.272%`); 13,328 were invalid because the length-three
match count was zero and 27,400 valid draws exceeded `2.5`. This implies a
pre-data cadence prior of 7.11264 qualifying attempts per twelve months. It is
only a formula-density check, not WTI performance evidence.

Retire on zero positions, fewer than five completed positions in any full
scored post-warm-up year, nonpositive governed economics, nondeterminism, or
any endpoint, return, SD, radius, match, entropy, direction, fixed-risk,
hard-stop, lifecycle, or downstream-gate failure. Q09 alone may establish or
reject portfolio diversification.

## 7. Source and Risk Boundary

The governed packet is
`strategy-seeds/sources/RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902/source.md`.
Tomcala and the pinned CRAN implementation support the sample-entropy formula,
Chebyshev distance, strict radius, sample-SD default, and template/count
semantics. Richman and Moorman provide original sample-entropy provenance.
Moskowitz, Ooi, and Pedersen support monthly own-return continuation and WTI
membership. None evaluates this exact gate, threshold, CFD transport, or risk
contract.

Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
single-carrier concentration, broker-month labels, finite-sample match
scarcity, scale/outlier sensitivity, and correlation with XNG or risk assets.
The hard stop can slip through gaps. Low sample entropy describes template
recurrence; it does not prove predictability, stationarity, independence, or
decorrelation. Live use is not authorized.

## Framework Alignment

- `Strategy_NoTradeFilter`: identity, registered magic, fixed risk,
  news/Friday/stress contract, and every strategy lock.
- bounded helpers: month clock, attempt state, endpoint reconstruction,
  return orientation, sample SD/radius, strict pair matching, exact counts,
  entropy boundary, momentum side, and restart recovery.
- `Strategy_EntrySignal`: foreign/owned exposure, spread, quote, ATR, frozen
  stop, and one fixed-risk market request.
- `Strategy_ManageOpenPosition`: malformed-state repair, side validation,
  next-month exit, and forty-day stale exit.
- `Strategy_ExitSignal`: no additional discretionary exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | approved source build | G0-approved card; magic `413110000`; Q01 pending |
