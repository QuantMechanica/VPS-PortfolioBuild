# Unger pattern census — closing finding

Scope is the 27 `DL089_*` programs whose `q12_selection_receipt.json` existed
and completed before 2026-09-13 UTC. Every one records top-level verdict
`NO_FILTER_CHANGE`: **27/27**. Eight record `stability.stable=false`:
QM5_10700, 10706, 11708, 12855, 20266, 21501, 21502 and 21507. Thus the census
found no reproducible hour/day filter improvement, and instability is not a
license to choose a visually attractive cell.

The two closest-looking cases still fail their sealed stability rule:

- `DL089_QM5_10706_GBPUSD_DWX_2019_2025`: candidate BUY hour 52 is not worse
  in only 2/4 test years versus 3 required; final selection remains empty.
  Receipt sha256: `4286eb7f814f3a5b2568f50fd5a17edd2920c5e726048dd95419054a5223a688`.
- `DL089_QM5_11708_EURUSD_DWX_2019_2025`: SELL hours 11/53/79 meet the
  not-worse count but are subsets of the earlier selection in 0/3 folds versus
  2 required; final selection remains empty. Receipt sha256:
  `11e182b0911b56d2d731d4879c2e8fcd7c0b0166dfa7f871f49350a6c24f4e55`.

Traceability: source files are
`D:/QM/strategy_farm/artifacts/opt_census/DL089_*/q12_selection_receipt.json`.
Sort the 27 pre-cutoff rows by directory name, serialize
`directory,sha256,verdict,stable` joined by LF, and the aggregate sha256 is
`66a52959228e5a32eeeccfae3f1fa2d019ec8207f2260feed47ee5a9c2e6944b`.
Two receipts completed on 2026-09-13 and are outside the requested 27-program
snapshot; they do not alter the conclusion (both also say `NO_FILTER_CHANGE`).

Decision: close the Unger pattern-census question. Do not mechanize a filter
from this census and do not weaken its Q12 rule. New pattern research needs a
new, predeclared causal thesis rather than another pass over these cells.

RESULT scope=27 no_filter_change=27 wf_unstable=8 near_misses=QM5_10706,QM5_11708 decision=CLOSE_NO_FILTER
