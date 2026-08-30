# QM5_41223 WTI Same-Calendar Four-Year Exponential Weight - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41223_wti-samecal-expw4_card.md`, SHA-256
`C68B6516616E55A37949DCD459445A5B38DDAF36107C56171CF7F0259E8A733F`,
and only the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41223`
- slug: `wti-samecal-expw4`
- strategy ID: `KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- intended magic: `412230000`

The atomic `farmctl reserve-ea-ids` allocator selected numeric ID `41223`
after the already governed `41215..41222` reservations and wrote exactly one
active registry row. The decision did not guess, hand-edit, or reuse an
identity. Magic allocation remains a separate governed build prerequisite
and is not claimed by this decision.

## Source And Traceability

The durable source approval was committed as
`ed236e3e0d324281fa4b1a36559987cbc5c9f22b` before extraction. The bounded
source packet is
`strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026/source.md`,
SHA-256
`39E99FD059CE2B6B4EE092A0448C5B2102BFCD9DA9FB527ED4103DD1AC96661F`,
committed as `a970a1b611bc33111f075b88d5610a393f84b982` before this G0 decision.

Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance*, provide
same-calendar commodity-return information, explicit crude-oil membership,
monthly renewal, and a five-year floor. Moskowitz, Ooi, and Pedersen (2012),
*Journal of Financial Economics*, provide explicit WTI membership,
own-return direction, and monthly renewal. The governed exponential-weight
packet fixes only auditable base-two arithmetic. The exact single-WTI
same-calendar/year-decay conjunction, four-year half-life, and CFD execution
are untested QM translation choices; no performance or correlation claim
transfers.

## Locked Approved Rule

At the first executable normalized `XTIUSD.DWX` D1 broker-month transition in
`(Y,M)`, reconstruct completed WTI log returns for calendar month `M` in exact
years `Y-1..Y-10`, skipping missing years without replacement and requiring
at least five valid observations. For exact year lag `k`, assign uncompressed
calendar age `k-1` and weight:

```text
weight_k = 2 ^ (-(k-1) / 4.0)
weighted_mean = sum(weight_k * return_k) / sum(weight_k)
```

Missing years contribute neither return nor weight but do not change any
older observation's age. Buy WTI only when
`weighted_mean > +1e-12`; sell WTI only when
`weighted_mean < -1e-12`; consume flat otherwise. Use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one frozen
`3.5*ATR(20,D1)` hard stop, no target, a nonnegative 1,500-point spread cap,
one durable attempt per broker month, next-month renewal, and 40-day stale
repair. Both news axes, legacy news, and Friday close are OFF.

## Reputable-Source Gate

- R1:
  `PASS_WITH_COMPOSITE_DECAY_AND_SINGLE_CARRIER_CFD_TRANSLATION_RISK`.
  Two complete-read peer-reviewed sources cover same-calendar commodities,
  explicit crude-oil/WTI membership, own-return direction, and monthly
  renewal; governed arithmetic fixes only the kernel; the exact conjunction
  and half-life are untested.
- R2: `PASS`. Calendar, normalized endpoints, exact year ages,
  missing-year noncompression, sample, base, exponent, half-life,
  normalization, strict sign, side, attempt, fixed risk, stop, spread cap,
  and lifecycle are locked.
- R3:
  `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
  Registered native WTI D1 data supply runtime inputs, with label, roll,
  financing, gap, and translation risks explicit.
- R4: `PASS`. Deterministic native arithmetic and framework execution only;
  no trained signal, banned signal indicator, external feed, grid,
  martingale, scale-in, or pyramid.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` returned `ok` on
the exact approved card before this decision.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_expw4_preallocation_dedup_20260830.json`, SHA-256
`60C966AE7522F051B4FE658923935C253C160CE2D054070D245CC5554FDD760F`,
scanned 4,722 registry identities, 1,360 cards, and 45 Strategy Wiki nodes. It
found no exact collision and surfaced only the expected equal-weight WTI
same-calendar fuzzy neighbor.

Manual review establishes that `QM5_20099` applies equal weight to each valid
same-calendar return, while this card fixes calendar-year exponential decay.
For recent-to-old returns
`[-0.04,-0.04,-0.04,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03]`, the
equal mean is `+0.009` and buys, while this card's weighted sum is negative
and sells. `QM5_20279` weights twelve contiguous recent monthly returns with
a three-month half-life rather than matching months across years.
`QM5_41204` estimates median/MAD state and iterative Huber weights;
`QM5_41211` estimates equal-weight sample variance and gates on a t-score;
`QM5_41212` discards magnitudes into Bernoulli signs.

The exact WTI same-calendar information object, uncompressed year ages,
four-year base-two kernel, normalized weighted sign, durable monthly attempt
state, and single-WTI position jointly change direction and information
influence relative to every built neighbor.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_EXPONENTIAL_YEAR_DECAY_DIRECTION`.

## Build Authorization And Kill Boundary

This G0 decision authorizes deterministic slot-0 magic allocation, one V5 EA
source/binary, one fixed-risk backtest setfile, strict compile/Q01 checks, and
one paced Q02 enqueue when CPU admission is clear. It authorizes no manual
tester run or phase advancement.

Q02 must retire the unchanged card on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, or any clock, endpoint, exact age, weight, normalization, sign,
side, attempt, risk, stop, spread, lifecycle, or determinism defect. Failure
may not be rescued through sample, half-life, age compression, tie rule,
direction, carrier, stop, hold, spread, or filter changes.

Direct WTI is structurally outside the certified XAU/SP500/NDX/XNG carrier
set, but realized independence is unproven and remains an unchanged Q09
decision. No live/demo/shadow/stress/optimization preset, terminal control,
AutoTrading, `T_Live`, deploy/live manifest, portfolio gate, portfolio
admission, correlation waiver, or certification action is authorized.
