# QM5_41313_wti-ljungbox-tr - Strategy Spec

**EA ID:** QM5_41313

**Slug:** `wti-ljungbox-tr`

**Strategy ID:** `LJUNGBOX-MOP-WTI-PORTMANTEAU-20260902_S01`

**Source:** `LJUNGBOX-MAHDI-MOP-WTI-PORTMANTEAU-20260902`

**Author:** Development

**Last revised:** 2026-09-02

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of each normalized broker month,
reconstruct forty-nine consecutive completed broker-month-end closes and form
forty-eight chronological adjacent log returns. Demean them, compute ordinary
autocorrelations at lags one through six with a common centered-squares
denominator, and aggregate their finite-sample-weighted squares with the
Ljung-Box statistic.

When `Q6>=5.35`, follow the newest twelve-month WTI return sign for one broker
month. Ljung-Box arithmetic and monthly WTI continuation have reputable
method lineage; applying the diagnostic to raw WTI returns as this exact state
gate is untested QuantMechanica synthesis. Statistic and momentum magnitude
never scale risk.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_month_returns` | 48 | completed adjacent monthly log returns |
| `strategy_ljung_box_lags` | 6 | ordinary autocorrelation lags |
| `strategy_variance_floor` | `1e-18` | strict centered-squares floor |
| `strategy_q_boundary` | `5.35` | inclusive portmanteau gate |
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

## 3. Symbol, Clock, And Exact Formula

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Symbol slot zero; governed magic `413130000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of that D1 boundary.
- Current-month prices are excluded. No proxy, secondary symbol, external
  curve, inventory series, file, API, or portfolio state is authorized.

For chronological completed-month closes `C[0..48]`:

```text
x[i] = ln(C[i+1]/C[i]), i=0..47
mean = sum(x[i])/48
y[i] = x[i]-mean
den = sum(y[i]^2, i=0..47)
rho[k] = sum(y[i]*y[i-k], i=k..47)/den, k=1..6
Q6 = 48*50*sum(rho[k]^2/(48-k), k=1..6)
mom12 = sum(x[i], i=36..47)

BUY  iff Q6 >= 5.35 and mom12 > +1e-12
SELL iff Q6 >= 5.35 and mom12 < -1e-12
FLAT otherwise
```

Every close and intermediate must be finite and positive where required, and
`den>1e-18`. The squared-autocorrelation gate deliberately ignores lag sign;
the newest twelve-month return alone assigns side. The embedded alternating
fixture has correlations `[-47/48,46/48,-45/48,44/48,-43/48,42/48]`,
variance sum `0.0048`, and `Q6=278.125`; a constant path must fail closed.

## 4. Entry, Risk, And Attempt Semantics

Q02 fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualified month may open one market position with a
frozen completed-bar `3.5*ATR(20,D1)` broker hard stop and no target. Foreign
WTI exposure or an existing owned position blocks entry. Framework quote,
contract, tick, volume, sizing, and margin guards remain authoritative.

Persist the normalized broker-month attempt before history, signal, news,
spread, quote, ATR, sizing, margin, or order gates. Never retry a consumed
month. Persist entry-month state only after confirmed fill and recover it from
matching deal history after restart. Both news axes and legacy news are OFF;
Friday close and stress rejection are disabled. Entry spread must be finite
and in `[0,1500]` points.

## 5. Management And Exit

Close an owned position on the first processed tick in a later normalized
broker month or after forty elapsed calendar days. Missing or inconsistent
position, stop, side, entry time, or entry-month state causes a defensive
strategy close. There is no target, trail, break-even, partial close,
statistic exit, intramonth flip, Friday flatten, retry, scale-in, grid,
martingale, or pyramid. Framework kill switch and broker hard stop remain
authoritative.

## 6. Evidence, Activity, And Risk

The governed packet is
`strategy-seeds/sources/LJUNGBOX-MAHDI-MOP-WTI-PORTMANTEAU-20260902/source.md`.
Mahdi fixes the formula and limitations; Ljung and Box establish original
attribution; Moskowitz, Ooi, and Pedersen support monthly own-return
continuation and explicit WTI membership. None evaluates the conjunction,
boundary, CFD transport, risk contract, costs, or portfolio fit.

A pre-data fixed-seed independent-normal check qualifies `50.1025%`, or
`6.0123` theoretical monthly clocks per twelve. It is only a formula-density
prior. Q02 owns actual activity and economics. Retire on zero positions,
fewer than five completed positions in any full post-warm-up scored year,
nonpositive governed economics, nondeterminism, or any formula, attempt,
fixed-risk, hard-stop, or lifecycle defect.

Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
single-carrier concentration, broker-month labels, noisy 48-return estimates,
roll-induced autocorrelation, and the intentional admission of both
persistent and anti-persistent lag states. Q09 alone may establish or reject
portfolio diversification. Live use is not authorized.

## Framework Alignment

- `Strategy_NoTradeFilter`: identity, registered magic, fixed risk,
  news/Friday/stress contract, and every strategy lock.
- bounded helpers: month clock, attempt state, endpoint reconstruction,
  return orientation, demeaning, six autocorrelations, Ljung-Box aggregation,
  boundary, momentum side, and restart recovery.
- `Strategy_EntrySignal`: foreign/owned exposure, spread, quote, ATR, frozen
  stop, and one fixed-risk market request.
- `Strategy_ManageOpenPosition`: malformed-state repair, side validation,
  next-month exit, and forty-day stale exit.
- `Strategy_ExitSignal`: no additional discretionary exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | approved source build | G0-approved card; magic `413130000`; Q01 pending |
