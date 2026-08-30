# QM5_41224 WTI Same-Calendar Regime Shift - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41224_wti-samecal-regimeshift_card.md`,
SHA-256
`6A266965F7CF089E610EF4BE6FA4AA34A7FD892BBF8A15699C344555ED72EFC4`,
and only the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41224`
- slug: `wti-samecal-regimeshift`
- strategy ID: `KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- intended magic: `412240000`

The atomic `farmctl reserve-ea-ids` allocator selected numeric ID `41224` and
wrote exactly one active registry row. The decision did not guess, hand-edit,
or reuse an identity. Magic allocation remains a separate governed build
prerequisite and is not claimed by this decision.

## Source and traceability

The durable source approval was committed as
`2a0ace4ac513246b2daa273894ca6bc274f2a33c` before extraction. The bounded
source packet is
`strategy-seeds/sources/KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026/source.md`,
SHA-256
`1B55931E62B815BB686841330932C0D6E36A168CFC6C7ED53BC67CE398983BCE`,
committed as `e22c19561` before this G0 decision.

Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance*, provide
same-calendar commodity-return information, explicit crude-oil membership,
monthly renewal, and a five-year floor. Moskowitz, Ooi, and Pedersen (2012),
*Journal of Financial Economics*, provide explicit WTI membership, own-return
direction, and monthly renewal. The exact single-WTI chronological five/five
sign reversal, recent-block direction, and CFD execution are untested QM
translation choices; no performance or correlation claim transfers.

## Locked approved rule

At the first executable normalized `XTIUSD.DWX` D1 broker-month transition in
`(Y,M)`, reconstruct completed WTI log returns for calendar month `M` in every
exact year `Y-1..Y-10`. All ten observations are mandatory, with strict
adjacent-month endpoints, one uniform energy D1-label convention, and a
confirming following bar. No current-month price is allowed.

Compute:

```text
recent_mean = mean(r_1..r_5)
older_mean  = mean(r_6..r_10)
```

Buy WTI only when `recent_mean > +1e-12` and
`older_mean < -1e-12`. Sell WTI only when
`recent_mean < -1e-12` and `older_mean > +1e-12`. Equal block signs, either
inclusive tie, incomplete history, or invalid state consumes the month flat.
Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, a nonnegative 1,500-point spread cap,
one durable attempt per broker month, next-month renewal, and a forty-day
stale repair. Both news axes, legacy news mode, and Friday close are OFF.

## Reputable-source gate

- R1 `PASS_WITH_TWO_BLOCK_SINGLE_CARRIER_CFD_TRANSLATION_RISK`. Two complete-
  read, DOI-bearing peer-reviewed sources cover same-calendar commodities,
  explicit crude-oil/WTI membership, own-return direction, and monthly
  renewal; the exact chronological disagreement conjunction is untested.
- R2 `PASS`. Calendar, normalized endpoints, exact year membership, two fixed
  block sizes, arithmetic means, strict reversal, recent-block side, attempt,
  fixed risk, stop, spread cap, and lifecycle are locked.
- R3 `PASS_WITH_TEN_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
  Registered native WTI D1 data supply runtime inputs; history depth, labels,
  rolls, financing, gaps, and translation risks remain explicit.
- R4 `PASS`. Deterministic native arithmetic and framework execution only;
  no trained signal, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` returned `ok` on
the exact approved card before this decision.

## Non-duplicate decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_regimeshift_preallocation_dedup_20260830.json`,
SHA-256
`75457AA3AFF5BF445FCDC11799CA2BC6ABD574DB0486CE6B5BD3E3F1AF3ACF17`,
scanned 4,723 registry identities, 1,361 cards, and 45 Strategy Wiki nodes. It
found no exact collision and surfaced only the expected raw WTI same-calendar
fuzzy neighbor.

Manual review establishes that `QM5_20099` follows the mean of one combined
same-calendar sample, while this card requires a sign reversal between exact
recent and older five-year blocks and follows the recent block. Robust-
location, t-score, and sign-score siblings also reduce one sample rather than
compare chronological blocks. `QM5_41223` applies continuous exponential
year-age decay and trades stable seasonal states that this card forbids.
`QM5_41172` detects a daily location break within one just-completed month,
not a reversal across exact same-calendar observations from ten years.

For recent-to-old returns
`[+.01,+.01,+.01,+.01,+.01,-.03,-.03,-.03,-.03,-.03]`, the combined mean is
negative and `QM5_20099` sells, while this card's positive recent block against
the negative older block buys. Stable all-positive or all-negative histories
make mean and decay siblings trade but force this card flat. The chronological
split, strict disagreement state, and recent-block side jointly change
direction and exposure.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_CHRONOLOGICAL_REGIME_SHIFT`.

## Build authorization and kill boundary

This G0 decision authorizes deterministic slot-0 magic allocation, one V5 EA
source/binary, one fixed-risk backtest setfile, strict compile/Q01 checks, and
one paced Q02 enqueue when CPU admission is clear. It authorizes no manual
tester run or phase advancement.

Q02 must retire the unchanged card on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, or any clock, endpoint, block, mean, sign, side, attempt, risk,
stop, spread, lifecycle, or determinism defect. Failure may not be rescued by
changing the years, block sizes, direction, carrier, tie rule, stop, hold,
spread, or adding a fallback.

Direct WTI is structurally outside the certified XAU/SP500/NDX/XNG carrier
set, but realized independence is unproven and remains an unchanged Q09
decision. No live/demo/shadow/stress/optimization preset, terminal control,
AutoTrading, `T_Live`, deploy/live manifest, portfolio gate, portfolio
admission, correlation waiver, or certification action is authorized.
