# QM5_41223 WTI same-calendar exponential-weight build and Q02 enqueue

Date: 2026-08-30

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED_CPU_CLEAR`

## Delivered edge

`QM5_41223_wti-samecal-expw4` is a low-frequency direct-WTI calendar
candidate. At the first normalized `XTIUSD.DWX` D1 broker-month transition it
reconstructs the completed WTI log return for the same calendar month in exact
years `Y-1..Y-10`, skips missing years without substitution, and requires at
least five valid observations. Exact lag `k` keeps calendar age `k-1` even
when an intervening year is absent. The signal is the normalized weighted
mean under:

```text
weight_k = 2 ^ (-(k-1) / 4.0)
weighted_mean = sum(weight_k * return_k) / sum(weight_k)
```

The EA buys only above `+1e-12`, sells only below `-1e-12`, and consumes the
month flat at equality or on an invalid state. An opened position closes at
the next normalized broker-month boundary, with a 40-day stale repair and a
frozen `3.5*ATR(20,D1)` hard stop.

Direct WTI is a new carrier relative to the certified XAU/SP500/NDX/XNG book,
and the signal uses a monthly exact-calendar year-decay clock. That is a
structural diversification candidate, not proof of low realized correlation.
Q09 remains the sole authority for portfolio overlap and diversification.

Canonical preallocation dedup scanned 4,722 registry identities, 1,360 cards,
and 45 Strategy Wiki nodes. It found no exact collision and surfaced the
expected `QM5_20099` equal-weight WTI same-calendar neighbor. On recent-to-old
returns `[-0.04,-0.04,-0.04,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03]`,
the equal mean is `+0.009` and buys, while this four-year exponential kernel
has a negative weighted sum and sells. The information set also differs from
`QM5_20279` contiguous-month exponential trend, while its arithmetic differs
from the Huber, t-score, and Bernoulli-sign same-calendar siblings.

## Governance and implementation

The reputable lineages are Keloharju, Linnainmaa, and Nyberg (2016), *The
Journal of Finance*, for same-calendar commodity information and crude-oil
membership, and Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
Economics*, for WTI own-return direction and monthly renewal. A governed
packet fixes base-two decay arithmetic. The exact WTI/decay conjunction,
four-year half-life, and CFD translation are QM specifications; no source
performance, significance, or correlation claim transfers.

- Source approval commit: `ed236e3e0d`.
- Bounded source packet commit: `a970a1b61`.
- Approved G0 card and deterministic identity commit: `31726a3cb`.
- Governed magic allocation commit: `f54518175`.
- EA, spec, fixtures, and fixed-risk preset commit: `e19347c3b`.
- Guardrail-only source repair commit: `0442f3199`.
- Exact append-only compile-repair authority commit: `0786e03c4`.
- Active slot 0 / magic: `412230000` for `XTIUSD.DWX`.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The implementation normalizes completed WTI D1 labels under one broker-date
offset, excludes the current incomplete month, preserves exact calendar-year
ages across missing observations, and consumes each monthly attempt even when
the signal is flat or an execution guard rejects entry. Fewer than five valid
returns, invalid prices or weights, a nonpositive denominator, or the exact
epsilon band produces no trade. News modes, legacy news, and Friday close are
off; no banned signal indicator, trained model, or external runtime feed is
used.

Eleven deterministic reference tests cover label normalization, exact-year
bounds, missing-year noncompression, exponential arithmetic, opposite-side
dedup fixtures, threshold equality, attempt state, fixed-risk preset,
registry, and resolver bindings. Card schema, G0 structure, spec, entry
contract, build guardrails, and raw-MQ5 quarantine checks passed.

## Governed compile and repair lineage

Build task `ca498dcb-0f31-4d64-8ff6-4de3d4e459e7` was bound to the first
compile item `ebbd3a51-2660-43df-b669-bdf0adfb0275`. Its compiler returned
zero errors and zero warnings, but strict Q01 correctly failed closed on
`EA_INDICATOR_BUFFER_UNBOUNDED` because one fixed-capacity age-buffer write
did not expose an explicit `ArraySize` guard.

The failed row and evidence were preserved. Commit `0442f3199` added explicit
fail-fast `ArraySize` proofs for the observation and age arrays without
changing the strategy rule. Commit `0786e03c4` bound one self-expiring repair
authority to the exact failed row, rejected source hash, repaired source hash,
EA label, and failure class. Its 40-test authority suite passed.

The append-only successor `add7713e-dff9-4a69-bd1f-0d81f2ed540b` was released
only after a source-hash-exact dry run. The resident T8 worker returned:

- verdict: `COMPILE_OK`;
- strict compiler: 0 errors, 0 warnings;
- build check: PASS, 0 failures, 0 warnings;
- MQ5 SHA-256:
  `b3b25a8179ffc8f2f35562d3494e529cff530758625fd951acb752ee88131081`;
- EX5 SHA-256:
  `00e348a47c1ad80865edcf7704d1395209d2ddbb7ac7ae015cd913454a06d361`;
- evidence:
  `D:/QM/reports/work_items/add7713e-dff9-4a69-bd1f-0d81f2ed540b/QM5_41223/COMPILE_EA/compile_evidence.json`.

The sole backtest preset is bound at build hash
`30a6b83f0ed40135a12fdbe0a32aa09961f9a458cd8bb508889899148fa60a19`.
It remains fixed-risk; no live, demo, shadow, stress, or optimization preset
was created.

## Q02 enqueue and CPU boundary

Immediately before `record-build`, five one-second whole-host CPU samples
averaged `77.72%` and peaked at `79.72%`, below the hard `97%` ceiling.
Recording the successful build atomically created exactly one Q02 item:

- work item: `6e56c36c-135d-4abc-a3d1-aa3f61c74f2c`;
- symbol/timeframe: `XTIUSD.DWX` / D1;
- setfile:
  `framework/EAs/QM5_41223_wti-samecal-expw4/sets/QM5_41223_wti-samecal-expw4_XTIUSD.DWX_D1_backtest.set`;
- readback: `pending`, attempt 0, unclaimed, priority-track;
- additional or skipped items: zero.

The immediate post-enqueue CPU window averaged `83.18%` and peaked at
`92.481%`, also below the ceiling. This mission performed no manual dispatch,
tester launch, retry, terminal reservation, or later pipeline action.

## Remaining falsification risks

- The five-observation floor and exact-year missing-data rule can produce zero
  or sparse Q02 activity.
- The four-year half-life is an untested QM translation choice and can let a
  few recent calendar years dominate direction.
- Continuous-CFD labels, financing, rolls, gaps, and futures-to-CFD basis
  remain empirical translation risks.
- A new WTI carrier and different clock do not establish realized
  independence; Q09 must reject excessive overlap with XNG, metals, and
  indices.

## Safety boundary

No AutoTrading state, live/demo/shadow/stress/optimization preset, `T_Live`
control or manifest, deploy manifest, portfolio gate, portfolio admission,
correlation waiver, or certification action was touched. Neither
certification nor diversification is claimed before downstream evidence.

Machine-readable receipt:
`artifacts/qm5_41223_build_q02_enqueue_20260830.json`.
