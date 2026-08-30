# QM5_41227 WTI same-calendar block-median build and Q02 enqueue

Date: 2026-08-30

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED_CPU_CLEAR`

## Delivered edge

`QM5_41227_wti-samecal-blockmed` is a low-frequency direct-WTI calendar
candidate. At the first genuine normalized `XTIUSD.DWX` D1 broker-month
transition into `(Y,M)`, it reconstructs the completed WTI log return for the
same named month in exact years `Y-5..Y-1`. All five observations are
mandatory and remain oldest to newest.

It forms four overlapping adjacent two-year means:

```text
b0=(r0+r1)/2, b1=(r1+r2)/2, b2=(r2+r3)/2, b3=(r3+r4)/2
s=sort_ascending([b0,b1,b2,b3])
location=(s1+s2)/2
```

The EA buys only above `+1e-12`, sells only below `-1e-12`, and consumes the
month flat at equality or on invalid state. It persists the monthly attempt
before every fallible history or entry gate. An accepted position holds to
the next normalized broker month behind a frozen `3.5*ATR(20,D1)` hard stop,
with 40 elapsed days as survivor repair.

Direct WTI is outside the certified XAU/SP500/NDX/XNG carrier set and the
signal uses a recurring calendar-year clock. This is a structural
diversification candidate, not evidence of low realized correlation. Only
unchanged Q09 may establish portfolio overlap and diversification value.

## Governance and non-duplicate evidence

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance*, supply
same-calendar commodity information, explicit crude-oil membership, monthly
renewal, and a five-year floor. Moskowitz, Ooi, and Pedersen (2012), *Journal
of Financial Economics*, supply explicit WTI membership, own-return direction,
and monthly renewal. The rolling pair means, even median, continuous CFD,
epsilon, risk, stop, spread, and lifecycle are disclosed pre-result QM
translations. No source performance, significance, CFD-equivalence, or
correlation claim transfers.

The first ten-year design was reduced to exact five years before allocation
because the registered `XTIUSD.DWX` D1 range is 2017-2025. This preserves the
source five-year floor and makes the card executable on registered history.

Canonical dedup scanned 4,726 registry identities, 1,364 cards, and 45
Strategy Wiki nodes. It found no exact match and surfaced the expected raw-
mean same-calendar neighbor `QM5_20099` for manual review.

- On `[-0.10,-0.10,+0.001,+0.10,+0.001]`, this EA buys from `+0.0005`
  while the full-sample mean sells from `-0.0196`.
- On `[-0.10,-0.10,+0.001,+0.001,+0.001]`, this EA sells from `-0.02425`
  while the individual-return median buys from `+0.001`.
- `QM5_20287_wti-blockmed-mom` uses four non-overlapping three-month blocks
  from twelve contiguous recent months, not four overlapping pairs from one
  named month across five years.

The governed identity is `QM5_41227`, slot 0, magic `412270000`. Key commits:

- source approval: `78362c2f9`;
- bounded source packet: `815252a55`;
- registered-history correction: `f0d70fd60`;
- approved G0 card and identity: `406ec96e8`;
- magic allocation: `331c96958`;
- fixture arithmetic correction: `f4ac6c9cf`;
- EA, SPEC, fixtures, and fixed-risk preset: `df3b5d8be`;
- governed compile and EX5: `60db7a573`.

## Build and validation

Compile work item `eba18271-585c-46c9-9071-1163b3ab65d5` was released only
after its expected and actual MQ5 hashes matched exactly. The resident T10
worker returned `COMPILE_OK`:

- compiler: zero errors and zero warnings;
- build check: PASS with zero failures;
- three nonfatal card-undecidable warnings; no parameter was inferred;
- MQ5 SHA-256:
  `5abb78f9ce25c60bf65093c1049a3b441404fa2a52dc13a61877ec828cd8c0b9`;
- EX5 SHA-256:
  `a04317c348e4ead5dfd571b724cafb7c98a14804a5ebb0514604203dcfc1dc74`;
- compile evidence:
  `D:/QM/reports/work_items/eba18271-585c-46c9-9071-1163b3ab65d5/QM5_41227/COMPILE_EA/compile_evidence.json`.

The sole preset is `XTIUSD.DWX` D1 and locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Its build hash is
`30807fbb20d30f2ae78522feddc60e1636fc89f327d5986fe0d10efa3413d41f`.
No live, stress, shadow, demo, or optimization preset exists.

Eleven independent reference tests passed. They cover native and `+1` labels,
completed endpoints, exact five-year membership, chronological pair means,
even-median indexes, both duplicate-disagreement fixtures, epsilon equality,
attempt persistence, spread boundaries, lifecycle, registry, resolver, card,
and setfile bindings. Card schema lint, SPEC validation, raw-source quarantine,
strategy-entry validation, and static build guardrails also passed.

## Capacity and Q02 enqueue

The mandatory whole-host CPU window sampled at
`2026-08-30T12:24:12.5289057Z` was:

`94.050%, 93.279%, 95.909%, 94.537%, 93.468%`

Average was `94.2486%` and maximum was `95.909%`; both were strictly below
the `97%` hard ceiling. The snapshot contained seven terminal processes and
five MetaTester processes.

The direct legacy `--ea --phase Q02` shortcut correctly refused because Q02
is not a cascade phase in this controller version. No item was created by
that attempt. The canonical build-record path then accepted build task
`0529d48d-72e5-48bd-b719-9e1a370104b3` and auto-enqueued exactly one item:

- work item: `e01180be-9a1c-4fe9-a183-30814f79b09d`;
- phase: `Q02`;
- symbol/timeframe: `XTIUSD.DWX`, D1;
- risk preset: the sole fixed-risk backtest setfile;
- readback: `pending`, attempt 0, unclaimed, priority track;
- enqueue time: `2026-08-30T12:26:10+00:00`.

No dispatcher, smoke test, manual tester, or terminal-control command was run.
Q02 now owns frequency, execution, cost, and baseline-economics evidence.

## Safety boundary

No AutoTrading state, manual tester, `T_Live` control or manifest, deploy
manifest, portfolio gate, portfolio admission, correlation waiver, or
certification state was touched. No live-use or decorrelation claim is made.

Machine-readable receipt:
`artifacts/qm5_41227_build_q02_enqueue_20260830.json`.
