# QM5_41203 XAU/XAG same-calendar signed-rank sleeve — build and Q02 enqueue

Date: 2026-08-29

Branch: `agents/board-advisor`

Outcome: **COMPILE_OK; one logical XAU/XAG D1 Q02 basket row enqueued**

## Edge and portfolio role

`QM5_41203_xauxag-samecal-srank` is a monthly two-leg structural sleeve. At
the first completed D1 boundary of each broker month it reconstructs the
synchronized XAU-minus-XAG log-return difference for that same calendar month
in exact years `Y-1..Y-10`. With at least five valid pairs, it rejects epsilon
zeros and absolute ties, ranks absolute differences strictly, centers the
positive-rank sum as `S=2*Vplus-n(n+1)/2`, and holds opposite XAU/XAG legs in
the score direction until the next month boundary.

This is a relative-value/calendar package rather than another directional XAU,
index, or XNG signal. It does not assert realized decorrelation; Q09 retains
that decision. Repository-wide preallocation dedup resolved the expected
XAU/XAG same-calendar mean carrier and the single-WTI signed-rank neighbor as
mechanically distinct. The durable receipt is
`artifacts/qm5_xauxag_samecal_srank_preallocation_dedup_20260829.json`.

## Governance and build

The governed source packet combines peer-reviewed same-calendar return
seasonality, peer-reviewed XAU/XAG commodity-carrier evidence, and pinned R
Core signed-rank arithmetic. The source approval, G0 decision, approved card,
EA ID 41203, two active magic rows, generated resolver, basket manifest, source,
SPEC, and fixed-risk presets are committed. The canonical and runtime approved
cards are byte-identical at SHA-256 `6bd56e05...defc96`.

The first governed compiler row `eb70f232-b874-4816-8243-dd12f4dc145f`
compiled with zero MetaEditor errors and warnings, then failed closed on the
current explicit MAE-hook and dynamic-buffer proof contracts. The repair added
the required framework MAE sampler call and an explicit `ArraySize` write
guard; it changed no signal mechanic. Its append-only authority is bound to
that exact failed row, EA label, old hash, new hash, and failure vector.

Successor row `f2ed8f35-2dd4-423b-8feb-da31c70eefe9` compiled source SHA-256
`aabcac8d...f75ea` on quiescent T6 without launching a tester. It completed
`COMPILE_OK`, strict build-check PASS, zero errors, zero warnings, and produced
EX5 SHA-256 `fa4eb606...380d0`. The logical basket setfile retains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Capacity and Q02 handoff

Immediately before Q02 insertion, five one-second whole-host CPU samples were
75.9790%, 81.7068%, 82.2437%, 84.6696%, and 82.7166%. The maximum, 84.6696%,
was below the 97% hard ceiling.

Recording build task `69f223e2-8f27-498e-ae6a-1c1a980406f0` inserted exactly
one logical Q02 row:

- work item `b9747d17-e3ff-405a-96e6-3a7e2b8aba5f`;
- logical symbol `QM5_41203_XAU_XAG_SAMECAL_SR_D1`, D1;
- host `XAUUSD.DWX`, traded legs `XAUUSD.DWX` and `XAGUSD.DWX`;
- USD tester currency, 100000 deposit, 2018-07-02 through 2024-12-31;
- priority track, cohort size one;
- custom-history admission ACTIVE with 216 selected archive rows;
- read back pending, unclaimed, attempt zero, with no skipped target.

No dispatch tick or tester was launched manually. Resident workers own later
execution.

## Verification and safety

- Signed-rank/reference suite: 9 tests PASS.
- Card schema and G0 linters: PASS.
- Build-skill registry/magic/directory guard: PASS.
- SPEC validator and build guardrails: PASS.
- Static build gate: zero failures.
- Governed compile and strict build check: PASS.
- Exact compile-repair authorization test: PASS.
- EX5 provenance guard: PASS for QM5_41203 against compile row `f2ed8f35`;
  the whole-index command remained nonzero only for unrelated pre-existing
  staged EX5 paths.

No portfolio gate, T_Live file, deploy manifest, AutoTrading state, or live
terminal was changed. No certification or correlation claim is made. The
machine-readable receipt is
`artifacts/qm5_41203_build_q02_enqueue_20260829.json`.
