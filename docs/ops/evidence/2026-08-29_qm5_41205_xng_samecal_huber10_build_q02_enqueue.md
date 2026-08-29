# QM5_41205 XNG same-calendar Huber build and Q02 enqueue

Date: 2026-08-29

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED`

## Delivered edge

`QM5_41205_xng-samecal-huber10` is a low-frequency second-XNG sleeve under
the OWNER-authorized different-logic route. At the first normalized D1
broker-month transition it requires the completed XNG log return for the same
calendar month in exact years `Y-1..Y-10`. It forms the even median and raw
even MAD, freezes `scale=1.4826*MAD` and `delta=1.5*scale`, runs exactly 32
Huber reweighted-location updates, and follows the final sign beyond the
inclusive `1e-12` flat band until the next month.

This mechanic is structurally different from certified `QM5_12567`, which is
a short-horizon cumulative-RSI2 pullback conditioned on a 200-day trend
state. The new EA instead uses ten disjoint historical matching months, takes
symmetric long and short positions, and renews monthly. It is logic-diverse,
not a new carrier, so realized low correlation is not claimed; unchanged Q09
remains authoritative.

Canonical preallocation dedup found no exact identity. It found the expected
fuzzy neighbors `QM5_20100` (raw XNG same-calendar mean) and `QM5_41204`
(the same Huber statistic on WTI). The locked ten-return disagreement vector
makes the Huber rule SELL at `-0.00031225666666666747`, while the raw mean is
positive and the centered signed-rank score is `+3`; both neighbors BUY.

## Governance and implementation

- Peer-reviewed source lineage: Keloharju, Linnainmaa, and Nyberg (2016),
  *Journal of Finance*, for same-calendar returns and explicit natural-gas
  membership; Huber (1964), *Annals of Mathematical Statistics*, for the
  bounded-influence location family.
- Governed source packet:
  `strategy-seeds/sources/KELOHARJU-HUBER-XNG-SAMECAL10-2026/source.md`
  (`4b64219d...`).
- Durable source approval commit: `288b86854`.
- Approved G0 card and deterministic identity commit: `b7a824f75`.
- EA, magic, resolver, reference fixtures, spec, and fixed-risk preset commit:
  `e906629ef`.
- Active identity: `QM5_41205`, `XNGUSD.DWX`, D1, slot 0, magic
  `412050000`.
- Sole baseline risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The runtime farm copy normalized only the informational non-gating R1 tier to
`TIER_C`; it did not change the committed mechanic, R2-R4 gates, risk, or
execution contract.

The independent suite passed 10/10 deterministic calendar, exact-year,
Huber-arithmetic, disagreement, attempt, lifecycle, card, setfile, registry,
and resolver fixtures. Card-schema, G0, execution-contract, spec,
symbol-scope, registry/resolver, array/performance, MAE-hook, setfile, and
static build gates passed without candidate-specific findings.

## Governed compile

Build task `48050e01-bcee-4a17-b4fc-4613054dbc88` bound the source to compile
item `68cf7a68-65fd-42e7-a3d4-f6edaed00f5d`. A target-only dry run and apply
released only its rollout hold after the expected and actual MQ5 SHA-256 both
matched
`a3ba3a1e53dc3a0a1bbc3e2c44f23cf6d5a3298a89e03a8edc946cd3e85bacb3`.

The resident T10 worker claimed it in compile-only mode under reservation
pressure and returned:

- verdict: `COMPILE_OK`;
- strict compiler: 0 errors, 0 warnings;
- build check: PASS, 0 failures, 0 warnings;
- EX5 SHA-256:
  `f709aaacc19beb0b0f816cf3db4abf3de4c894bbdff452dee7c9f17461989f50`;
- evidence:
  `D:/QM/reports/work_items/68cf7a68-65fd-42e7-a3d4-f6edaed00f5d/QM5_41205/COMPILE_EA/compile_evidence.json`.

No ad-hoc compile, tester launch, terminal control, or retry bypass was used.

## Q02 enqueue and capacity

The five-sample pre-Q02 CPU window averaged `76.33%` and peaked at `82.45%`,
below the hard `97%` ceiling. The post-enqueue confirmation averaged `65.86%`
and peaked at `72.52%`; the ceiling never bound.

Recording the successful build atomically appended exactly one priority-track
Q02 item:

- work item: `6becdb9f-bcb1-40e1-aace-065c43d10da7`;
- symbol/timeframe: `XNGUSD.DWX` / D1;
- setfile:
  `framework/EAs/QM5_41205_xng-samecal-huber10/sets/QM5_41205_xng-samecal-huber10_XNGUSD.DWX_D1_backtest.set`;
- readback: `pending`, attempt 0, unclaimed;
- custom-history admission: ACTIVE, 108 selected XNG archive rows.

The item was enqueued only. This mission did not manually dispatch or
backtest it.

## Remaining falsification risks

- Exact ten-year warm-up and all-ten-year completeness can produce zero or
  sub-floor Q02 activity if XNG history or broker-month labels are incomplete.
- Continuous-CFD session labels, roll construction, and futures-to-CFD basis
  remain empirical translation risks.
- This is a new structural return logic on the existing XNG carrier. Q09 must
  reject it if realized overlap with `QM5_12567` or the certified book is too
  high.

## Safety boundary

No AutoTrading state, live/demo/shadow/stress preset, T_Live/deploy manifest,
portfolio gate, portfolio admission, or correlation waiver was touched.
Neither certification nor diversification is claimed before downstream
evidence.

Machine-readable receipt:
`artifacts/qm5_41205_build_q02_enqueue_20260829.json`.
