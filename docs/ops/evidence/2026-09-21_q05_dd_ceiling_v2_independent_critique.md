# Independent critique — Q05 DD ceiling v2 proposal (H-Q05-R50)

Router task: `75f27580-d59f-472d-b01a-76effb3b491d` (creator: codex; critic: claude,
per sec68A non-Codex-seat requirement). Read-only review — **no source, threshold,
verdict, work item, registry row, or pipeline gate was changed by this critique.**

Target: `docs/research/Q05_DD_CEILING_V2_PROPOSAL_2026-09.md` (commit `01c729af97`),
evidence CSV `docs/research/Q05_DD_CEILING_V2_COHORT_2026.csv`.

## Verdict: REVISE

Not APPROVE_SHADOW, not REJECT. The mechanical work (code citation, hash, cohort
extraction, FP/FN arithmetic) is verified correct. Two open items must close before
the shadow rerun can be treated as decision-grade; neither invalidates H-Q05-R50, but
both bear directly on the predeclared refutation criteria (§4 of the proposal).

## What was independently reproduced and confirmed exact

- `framework/scripts/q05_stress_medium.py` SHA-256
  `0928ffefbc0e34625ede4ba71523235b3aa0466263475713d426d90527813317` matches the
  current file exactly; commit `9a78fa3647983710cdbb321a127d0950025140ca` exists and
  the file is unchanged since (`git diff <commit> -- framework/scripts/q05_stress_medium.py`
  is empty).
- Line citations verified against current file: `PF_FLOOR`/`DD_PCT_MAX`/`MIN_TRADES`/
  `STARTING_EQUITY` at q05_stress_medium.py:52-55; `dd_pct` computation at
  q05_stress_medium.py:574; the DD-ceiling branch at q05_stress_medium.py:596-606
  (`FAIL_DD_PORTFOLIO_REVIEW`, no Q06 cascade). All accurate.
- CSV recomputation (independent script over
  `docs/research/Q05_DD_CEILING_V2_COHORT_2026.csv`, 61 data rows): row count 61,
  57 unique `(ea_id, symbol)` pairs, duplicate set
  `{QM5_10790/XAUUSD:3, QM5_10796/XAUUSD:2, QM5_10423/XAUUSD:2}`, lineage split
  43/14/4 (`explicit_lineage`/`setfile_match`/`pair_fallback`) — all match the
  document exactly.
- Main FP/FN table reproduced bit-for-bit: v1 `TP=0,FP=0,TN=26,FN=35`; v2
  `TP=27,FP=18,TN=8,FN=8`, 45 advanced, precision 0.600, recall 0.771.
- 57-row latest-per-pair sensitivity reproduced exactly: `TP=24,FP=18,TN=8,FN=7`,
  42 advanced.
- Density-bucket table (rows/median DD_R/rows≤50R per bucket) and the 30/40/50/60/75R
  threshold sweep both reproduced exactly, cell for cell.
- Pearson r(density, DD_R) = 0.5943 over the 61-row cohort — matches the reported
  +0.594.
- Zero rows have `q05_profit_factor <= 1.0` — consistent with the code's PF-floor gate
  running before the DD check (q05_stress_medium.py:588-595), confirming every row in
  this cohort already cleared the Q05-report PF test before being parked on DD alone.

No arithmetic, selection, or citation defect was found anywhere in the document.

## 1. Cohort lineage — clean by construction, one residual gap

The extraction filter (`phase=Q05, verdict=FAIL_DD_PORTFOLIO_REVIEW,
created_at>=2026-01-01`) is deterministic and not survivorship-biased in the
population sense: it captures every row that failed Q05 for this specific reason,
not a filtered subset of "interesting" failures, and repeated measurements are kept
rather than collapsed. This is sound.

The residual gap is the 4 `pair_fallback` rows (6.6% of the cohort — the only
lineage tier that binds Q02 evidence by `(ea_id, symbol)` alone, without an exact
setfile/run tie to this specific Q04→Q05 chain):

| work_item_id | EA/symbol | q02_pf | expectancy_r | v2 disposition |
|---|---|---:|---:|---|
| `172d3385` | QM5_10562/XAUUSD | 0.91 | -0.0445 | ADVANCE (counted FP) |
| `80f23a8c` | QM5_10194/GDAXI | 1.03 | +0.0143 | ADVANCE (counted TP) |
| `8b215abf` | QM5_10469/GDAXI | 0.99 | -0.0064 | ADVANCE (counted FP) |
| `01a2e2ad` | QM5_10468/GDAXI | 0.97 | -0.0153 | ADVANCE (counted FP) |

I cannot independently re-derive the correct Q02 window for these 4 from the CSV
alone (that requires the raw MT5 report archive, out of scope for a read-only,
no-repo-access-beyond-git critique), so I am **not** asserting these labels are
wrong. But this is precisely the class of risk named in the proposal's own
refutation criterion 4 ("cross-terminal recovery or inferred lineage changes at
least 4 FP/FN cells"): all 4 of the weakest-lineage rows sit at that threshold
simultaneously. Recommend closing this before promotion: re-verify exact setfile
lineage for these 4, or exclude them from the sealed FP/FN table and report the
57-row corrected figures alongside the 61-row figures.

## 2. Admission proxy (Q02 PF > 1.0 AND E[R] > 0) — partially circular, correctly disclaimed

The proxy is drawn from the same statistic family (backtest profit factor /
expectancy) as the gate cascade that already produced this cohort — every row here
already cleared a PF>1.0 test at Q05 itself (q05_stress_medium.py:591-592) before
being parked for DD. Scoring a DD-ceiling change against a PF-based proxy therefore
measures **internal consistency between two overlapping PF-style backtest
measurements**, not independent evidence of live or portfolio-level economic value.

The document is explicit about this ("admission-proxy errors, not claims of live
profitability"; "no observed Q08 labels... to avoid laundering a speculative label
into a pipeline verdict") — that disclaimer is correct and should stand. My
addition: refutation criterion 2 (precision ≥0.55 / recall ≥0.70 against this same
proxy) inherits the circularity and should be weighted as an **internal-consistency
check on the retrospective screen**, not as evidence that v2 "captures more real
edges." Criterion 5 (actual Q08 evidence, FTMO DD controls) is the only
non-circular check in the package and should remain the binding one for any
activation decision, exactly as the document already states in §4's closing line.

## 3. Refutation criteria — falsifiable, appropriately scoped, one caveat

Criteria 1 (rerun mismatch bound), 3 (no other gate parameter may move), and 5
(Q08 downstream safety veto) are tight, falsifiable, and non-circular. Criterion 2
is falsifiable but should be read per §2 above — a pass on criterion 2 confirms the
retrospective screen replicated under an actual rerun, not that the admitted rows
are more likely to be genuinely profitable. Criterion 4 is open per §1 above.

## 4. RISK_FIXED 1000→500 halving: linearity is the entire load-bearing assumption, and the cohort is concentrated exactly where it is most likely to break

Under the proposal's own stated null (perfect linear position-size scaling), halving
`RISK_FIXED` halves `dd_money` 1:1, which leaves `DD_R = dd_money / RISK_FIXED`
**unchanged**. That is: if linearity holds exactly, v2 at `RISK_FIXED=500,
DD_R<=50` is mathematically identical to simply moving the ceiling to 50R at the
existing `RISK_FIXED=1000` — the risk-halving framing adds no discriminative power
by itself. Its only real function is to let the mandatory rerun (§6) surface
**non-linear** effects — lot-step floors, minimum volume, margin, and price-path
sensitivity — that the retrospective projection cannot capture. The document already
names this risk in prose; it is the single most consequential open technical
question in the paper and deserves quantitative framing:

Symbol distribution of the 61-row cohort (independently computed from the CSV):

| Symbol | Rows | Share |
|---|---:|---:|
| GDAXI.DWX | 23 | 37.7% |
| XAUUSD.DWX | 22 | 36.1% |
| USDJPY.DWX | 7 | 11.5% |
| NDX.DWX | 5 | 8.2% |
| GBPUSD.DWX | 2 | 3.3% |
| WS30.DWX | 1 | 1.6% |
| EURUSD.DWX | 1 | 1.6% |

GDAXI + XAUUSD together are 74% of the cohort and, among the 45 rows that would
newly ADVANCE under v2, 32/45 (71%) are GDAXI or XAUUSD. These are the two
instrument classes on this broker most exposed to coarse lot-step / minimum-volume
clipping relative to FX majors: if halving `RISK_FIXED` cannot translate into a
correspondingly halved position size (because the computed lot already sits at or
near the broker minimum/step), `dd_money` will not halve, `DD_R` will not stay
invariant, and the retrospective 50R label for exactly these rows becomes
unreliable in either direction — not merely "conservative by construction" as
linear scaling would guarantee, but genuinely unpredictable per-row.

Recommendation: the mandatory rerun in §6 should report results broken out by
symbol/instrument class (GDAXI+XAUUSD vs. the FX/index-future remainder), not only
in aggregate, specifically to test whether the linearity assumption holds
differently across that split. Given the concentration above, an aggregate pass
against criterion 1 could mask a class-specific failure that matters more for any
future generalization of this contract to other CFD/metal-heavy symbols.

## 5. FP/FN table plausibility

Independently recomputed and exact in every cell, at every threshold reported
(30R/40R/50R/60R/75R), at both the 61-row and 57-row (latest-per-pair) resolutions,
and in the density-bucket breakdown. No defect found.

## Summary for the decision owner (Fable)

- Do not activate. The document does not ask for activation and this critique does
  not change that.
- Before treating the shadow rerun's actual vs. projected comparison as
  decision-grade: (a) resolve the 4 `pair_fallback` rows (verify exact lineage or
  exclude and report both cohort sizes), and (b) require the rerun to report
  GDAXI/XAUUSD vs. FX-remainder splits explicitly, given 74% cohort concentration in
  the symbol class most likely to break the linearity assumption the whole proposal
  rests on.
- Everything else — code citation, hash, cohort extraction, refutation-criteria
  design, FP/FN arithmetic — checks out under independent reproduction.
