# T11 canary export repair and guarded dry run — 2026-09-11

Task: f04d66ec-b296-4f2c-b5eb-83a8c2379626.

RESULT: Q-S3 REVIEW — export/defaults repair committed; real dry run REFUSED_CPU_GUARD. S3 identity remains unmeasured.

`tools/strategy_farm/research_canary.py` now follows `framework/scripts/run_smoke.ps1` by using a unique terminal-relative HTML export name and copying the result into the research artifact directory with SHA-256 verification. It loads `framework/registry/tester_defaults.json` (USD 100,000, leverage 100), verifies the existing T11 commission group against the canonical file, rejects nonzero tester exit codes, and checks resources every five seconds during a launched test. A resource failure aborts only its identity-bound canary job through the existing job registry. No factory process is interrupted. Code commit: 7a9c772fa5.

Focused verification: 9 pytest tests passed, including actual controller execution with a mocked process/export, canonical-default rejection, commission mismatch refusal, and capture hash equality. Python syntax compilation and `git diff --check` passed. Mocked tests are not MT5 evidence.

The existing staging receipt is preserved verbatim in `2026-09-11_f04d66ec_staging_receipt.json`. Canonical and staged EX5 hashes were rechecked against the WINSWEEP declaration; both are `68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01`. The setfile receipt binds `afa42711867677bd7d5641f93e52a104f31c86a181f835579241b214f35bf47c`.

The real dry-run receipt is preserved verbatim in `2026-09-11_f04d66ec_dry_run_receipt.json`, from `D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_040516_2e51dfdb/receipt.json`. Signed private history verification passed. The five-sample fleet CPU average was 92.080%, exceeding the mandatory 90% ceiling; the controller refused before launch. This cycle therefore made no non-dry launch attempt. Factory before/after observations remain recorded in the receipt; concurrent factory progress is not attributed to this controller.

| Required comparison | Fleet MEASURED cell | T11 this cycle |
| --- | --- | --- |
| Net profit | 2941.71 | Unmeasured: CPU guard refused |
| Profit factor | 1.03 | Unmeasured |
| Total trades | 208 | Unmeasured |
| Report SHA-256 | b60d80f80657ca8a7cdd11bad1856834281aa3b079723ac55950feac6702cbea | No report |

Fleet source: `D:/QM/reports/work_items/be5d3ce4-4762-5bf0-96e0-3c3469f9e3c9/QM5_41398/20260910_102420/summary.json`, `runs[0]`; work item remains `done / MEASURED`. No identity PASS or economic delta is inferred from a refusal.

Hand-back for b48ba1fb: use the same governed CLI below when resources admit it; first retain a passing dry-run receipt, then omit only `--dry-run` for the authorized smoke. Compare all four fields against the source above and report any difference without tuning. Relative export is covered by the focused test but still awaits real MT5 confirmation.

```text
python C:/QM/repo/tools/strategy_farm/research_canary.py --program WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025 --terminal T11 --expert QM5_41398_balke-pattern-repair-opt.ex5 --expert-path D:/QM/mt5/T11/MQL5/Experts/QM5_41398_balke-pattern-repair-opt.ex5 --setfile D:/QM/mt5/T11/MQL5/Profiles/Tester/QM5_41398_balke-pattern-repair-opt_USDJPY.DWX_H1_2021_s3_l3_x18.set --symbol USDJPY.DWX --period H1 --from-date 2021.01.01 --to-date 2021.12.31 --max-agents 4 --dry-run
```

## Router continuation — corrected fleet guard and S3 result

Task: `f04d66ec-b296-4f2c-b5eb-83a8c2379626`.

The controller default now matches the fleet CPU policy: a five-sample average
is refused only above 95%, and this task used the authorized `--max-agents 2`
T11 scope. Focused verification after the one-line policy correction:

```text
python -m pytest tools/strategy_farm/tests/test_research_canary.py -q
9 passed
python -m py_compile tools/strategy_farm/research_canary.py
PASS
```

The real dry run passed at
`D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_043507_13d7f421/receipt.json`:
108-file signed history PASS, zero T11-owned MetaTester agents, 39,430,549,504
bytes available RAM, and CPU samples `99.4, 91.3, 90.8, 78.0, 86.7` (mean
89.24%, below 95%). It did not launch a terminal.

The one authorized non-dry 2021 smoke wrote its durable receipt at
`D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_043920_a419cb70/receipt.json`.
Its pre-launch guards passed (zero T11-owned agents, 48,185,860,096 bytes RAM,
CPU mean 83.26% under 95%); the suspended T11 process was identity-bound to a
kill-on-close job and exited 0. MT5 did not create the requested relative HTML
export, so the controller correctly recorded `status: REFUSED`, reason `tester
exited without report`. During the run the factory mutation lock appeared;
the receipt truthfully records `isolation_unchanged: false` for that one field.
T11 was never in the activation list and no T1-T10 process was interrupted.

| Required comparison | Fleet MEASURED cell | T11 smoke |
| --- | ---: | --- |
| Net profit | 2941.71 | Unmeasured: no report |
| Profit factor | 1.03 | Unmeasured: no report |
| Total trades | 208 | Unmeasured: no report |
| Report SHA-256 | `b60d80f80657ca8a7cdd11bad1856834281aa3b079723ac55950feac6702cbea` | Unmeasured: no report |

**RESULT (Q-only):** Q-S3 is REVIEW. The new guard policy and real dry-run
passed, but the report-export contract failed again on the actual smoke. There
is no S3 identity PASS, delta, tuning, or selection claim. Any repair must
preserve T11-only isolation and prove a real report before another comparison.
