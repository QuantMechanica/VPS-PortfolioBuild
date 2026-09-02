# WTI Monthly Ljung-Box Trend - Source Approval

Date: 2026-09-02

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue is not tester dispatch and remains
subject to the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy sleeve mission on
branch `agents/board-advisor`. It requests one new structural low-frequency
commodity edge, reputable-source criteria, fixed-risk backtests, committed
non-duplicate work, and Q02 enqueue while excluding live and portfolio-gate
changes.

## Candidate Identity

- proposed slug: `wti-ljungbox-tr`
- proposed strategy ID: `LJUNGBOX-MOP-WTI-PORTMANTEAU-20260902_S01`
- proposed source ID: `LJUNGBOX-MAHDI-MOP-WTI-PORTMANTEAU-20260902`
- exact host/traded slot zero: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine broker month
- signal: Ljung-Box six-lag omnibus serial-dependence statistic at or above
  `5.35` on forty-eight completed monthly WTI log returns, followed in the
  newest twelve-month return direction

The governed allocator owns the numeric EA ID. This record neither predicts
nor hand-allocates it.

## Reviewed Evidence

1. Mahdi (2016), *SpringerPlus* 5, 1485, DOI
   `10.1186/s40064-016-3167-4`. The complete open-access paper was read end to
   end. Its nonseasonal background fixes the residual-autocorrelation
   definition, the Ljung-Box finite-sample statistic, and asymptotic
   chi-square reference; the broader paper documents finite-sample and model-
   diagnostic limitations.
2. Ljung and Box (1978), *Biometrika* 65(2), 297-303, DOI
   `10.1093/biomet/65.2.297`. Oxford University Press metadata and abstract
   establish original attribution only. No paywalled body claim is used.
3. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete published-paper read, monthly own-return
   continuation, and explicit WTI membership.
4. `strategy-seeds/sources/LJUNGBOX-MAHDI-MOP-WTI-PORTMANTEAU-20260902/source.md`,
   SHA-256
   `B0F6C55FC39ADD8E3880501FACD110B805511BEFF85DB4551D4BF92BCADA3043`,
   and `retrieval_route_20260902.json`, SHA-256
   `3F4866DC69E3399374C88EB64054350A90A46D67742EC2E5D498F731FCF01D39`,
   bind the exact extraction and claim limits.

The governed URL router returned `PERMISSION_REQUIRED` for an unapproved
third-party mirror. That mirror is excluded from evidence. No source tests
the exact raw-return portmanteau/twelve-month-direction conjunction, the
`5.35` boundary as a profitable gate, Darwinex CFD equivalence, fixed risk,
costs, lifecycle, activity, or portfolio correlation. No source p-value,
return, accuracy, alpha, Sharpe ratio, drawdown, or decorrelation statistic
transfers.

## Locked Mechanic

For forty-eight chronological completed-month log returns, subtract their
arithmetic mean. With the common centered-squares denominator, calculate
ordinary autocorrelations `rho[k]` for lags one through six and then:

```text
Q6 = 48*50 * sum(rho[k]^2/(48-k), k=1..6)
```

Require positive finite closes, finite intermediate arithmetic, and centered
sum of squares above `1e-18`. Qualify inclusively at `Q6>=5.35`; buy when the
newest twelve-return sum exceeds `1e-12`, sell below `-1e-12`, and consume
ties or invalid states flat. The squared-lag gate intentionally detects
serial dependence without assigning its sign; the independent continuation
carrier owns direction.

The boundary is the two-decimal pre-data approximation to the chi-square-six
median `5.348120627447121`. It is a state divider, not a significance test.
There is one attempt per broker month, persisted before every fallible gate.
Risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop, no target, a
1,500-point spread ceiling, next-month renewal, and forty-day stale exit.
Both news axes, legacy news, Friday close, and stress rejection are OFF.

The fixed-seed market-free null receipt, SHA-256
`42CE471AE4965FEDB5FE5DCDE7A06DC90F6856375051EB842669E35C6F21254E`,
qualifies 50.1025% of 200,000 samples, or `6.0123` theoretical qualifying
clocks per twelve months. It is only a pre-data cadence check. Q02 owns the
actual five-per-year floor and economics.

## Reputable-Source And Duplicate Decision

- R1: `PASS_WITH_SYNTHESIS_BOUNDARY`.
- R2: `PASS` with all arithmetic, clock, risk, and lifecycle rules fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` on registered native WTI D1.
- R4: `PASS`; bounded deterministic arithmetic, no ML or banned signal.

The corrected-root dedup receipt scanned 4,798 registry rows, 1,427 cards,
and 45 wiki nodes with a `CLEAN` verdict:
`artifacts/qm5_wti_ljungbox_tr_preallocation_dedup_20260902.json`, SHA-256
`C521D0D0F30869B1CD4F8F3B07DC8906B1D6B2EC472F420AE35BC61B36DF0D49`.

The nearest semantic systems remain mechanically distinct. `QM5_20256`
uses a signed linear combination of autocorrelations inside a variance
ratio; `QM5_41310` uses a raw successive-difference ratio; `QM5_41170` is
rank-based. Entropy, sign-word, recurrence, calendar, event, channel, and
plain trend systems do not aggregate six finite-sample-weighted squared
monthly autocorrelations. The certified `QM5_12567` is a two-day long-only
XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_LJUNG_BOX_Q6_GE5P35_GATED_12M_CONTINUATION`.

## Kill And Safety Boundary

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, or on any deterministic
contract defect. No result-based change to sample, lag count, weights,
boundary, direction, carrier, stop, hold, spread, or retry is allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. If the measured factory ceiling binds, stop without compiling or
enqueuing.
