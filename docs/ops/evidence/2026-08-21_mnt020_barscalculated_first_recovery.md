# MNT-020 — BarsCalculated-first cohort recovery

**Task:** `663ba5f6-69fa-42b2-9ce3-c78d52f452a6`  
**Measured:** 2026-08-21 10:15 UTC against the live farm database opened read-only  
**Source implementation:** `b4745f5b2a00bd4eae66df7c9be23adcd5a40d74` on `agents/board-advisor`  
**Disposition:** `SOURCE_REPAIRED_RUNTIME_PROOF_DEFERRED` — this is not a pipeline verdict and not a live-use authorization.

## Result

The structural defect is repaired in source and prevented at the build gate.
The source census found **31 EAs / 66 parsed `BarsCalculated(...)` call sites**.
After the repair, the same parsed census reports **0 raw EA call sites**. Comments
and quoted strings are removed before call parsing, so documentary examples do
not change membership.

Runtime acceptance is deliberately still open. QM5_20096 has not been rebuilt
or rerun because this task expressly forbids recompiling the active inventory
and the factory is at its hard CPU ceiling. Its existing `.ex5` therefore
remains the old binary and its existing Q02 rows remain valid historical
evidence, not evidence for this repair.

## Evidence-first zero-trade classification

The anchor is work item `41a774ad-2429-42de-8714-52822c225513`, Q02,
QM5_20096 / USDCHF.DWX / H4 / 2022-07-01 through 2022-12-31 on T3.

- The run was a real-tick, valid-report run with zero trades; its result was
  `FAIL`, reason class `MIN_TRADES_NOT_MET`, and farm verdict `ZERO_TRADES`.
- The generation-bound logger sample contains existing handles (`h_sma=10`,
  `h_sto=11`) but `bc_sma=-1`, `bc_sto=-1`, `ntf_pass=0`, and `edges=0` through
  15,000,000 filter calls while the H4 bar count reaches 3,113.
- That excludes insufficient host history and order-path economics. The first
  unreachable gate is the readiness check itself: both `BarsCalculated` calls
  ran before the first buffer read in the entry hook.
- Classification under `processes/02-zt-recovery.md` is therefore
  **implementation defect / entry path unreachable**, not an economic no-signal.

Evidence paths:

- `D:/QM/reports/work_items/41a774ad-2429-42de-8714-52822c225513/QM5_20096/20260807_120134/summary.json`
- `D:/QM/reports/work_items/41a774ad-2429-42de-8714-52822c225513/QM5_20096/20260807_120134/logger_sample.jsonl`

The old run is bound to MQ5 SHA-256
`70b073b42da51b1e9044e50adfc7a5ce637e01c8d851a252a27633b51f8bef7e`
and EX5 SHA-256
`a343d30a5d70d5dc705f5dfc79450bd70f7fa7a264b124cd4ce68bbe3aa7a3e5`.
The repaired MQ5 SHA-256 is
`052f50a55e71f258e43861571c6a8fd7d7324cbe83ee5d3498e3889536e348f7`.
The canonical EX5 still has the old hash, which is the expected and visible
proof that no prohibited rebuild occurred.

## Repair contract

`framework/include/QM/QM_Indicators.mqh` now owns the readiness sequence:

1. `CopyBuffer` primes the requested handle/buffer.
2. Only then is `BarsCalculated` inspected.
3. The result is cached for the current host bar, preventing the historical
   millions-of-calls retry/log class.
4. A non-negative count below `required_bars` remains ordinary warm-up and is
   never mislabeled as infrastructure failure.
5. A persistent `-1` (or a still-unreadable buffer after the required count is
   present) emits bounded retry evidence at bars 1, 2, 4, 8, 16, and 32. At bar
   32 it emits `SETUP_DATA_MISSING`, so the defect cannot silently become an
   economic ZERO_TRADES verdict.
6. `QM_IndicatorRecordFirstTradableBar` emits the one-shot
   `INDICATOR_FIRST_TRADABLE_BAR` marker using schema
   `qm.indicator-first-tradable-bar/v1`. QM5_20096 records it only after both
   SMA and Stochastic handles are ready.

This complements Bug #4 commit `f09c2a1c3`: the pattern-filter marker and its
two consumers remain unchanged. The indicator marker uses the same measured
field shape but does not masquerade as `PATTERN_FIRST_TRADABLE_BAR` and does not
duplicate or weaken the pattern gate.

`tools/strategy_farm/build_gate_hardening.py` adds build-time failure
`EA_BARSCALCULATED_FIRST`. A direct EA-side call is rejected in favor of
`QM_IndicatorWarmupReady` / `QM_IndicatorWarmupCalculated`. The existing
`build_check.ps1` already invokes this checker, including per-`EALabel` builds.

QM5_20096's temporary July diagnosis counters and `STRATEGY_DIAG` flood were
removed before any rebuild identity can be minted. Its XWIN3 entry mechanics,
parameters, stops, risk, news, and management logic were not changed.

## Cohort

The 31 parsed-source members repaired in `b4745f5b2` are:

`QM5_11144`, `QM5_11912`, `QM5_20096`, `QM5_20097`, `QM5_20101`,
`QM5_20102`, `QM5_20103`, `QM5_20108`, `QM5_20112`, `QM5_20113`,
`QM5_20114`, `QM5_20116`, `QM5_20118`, `QM5_20121`, `QM5_20122`,
`QM5_20125`, `QM5_20126`, `QM5_20127`, `QM5_20129`, `QM5_20130`,
`QM5_20138`, `QM5_20139`, `QM5_20140`, `QM5_20142`, `QM5_20143`,
`QM5_20144`, `QM5_20147`, `QM5_20150`, `QM5_20151`, `QM5_20152`, and
`QM5_20179`.

The live, read-only latest-completed-Q02 census at 10:15 UTC is:

| Population | Latest completed Q02 ZERO_TRADES pairs | Distinct EAs |
|---|---:|---:|
| Whole farm | 1,092 | 327 |
| 31-EA parsed cohort (93 latest pair rows) | 74 | 27 |
| QM5_20096 | 4 | 1 |

QM5_20096's four rows are EURAUD (`bccf0a7c`), EURCAD (`7b899888`), GBPUSD
(`af0a148a`), and USDCHF (`41a774ad`). This is a before-runtime-proof
measurement: source repair cannot and did not rewrite historical verdicts.

The July note that both 20143 and 20144 were INFRA-only has evolved. Current
latest completed Q02 state has two INFRA_FAIL rows for 20143; 20144 now has
three PASS rows and one INFRA_FAIL row. Those outcomes do not disprove the
static reachability hazard, and they are not used as causal evidence for
QM5_20096.

## Verification

Executed after the repair:

```text
python -m pytest tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_build_guardrails.py -q
28 passed

python tools/strategy_farm/build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_20096_ha-stoch-h4-swing
failures=[]; D6_indicator_warmup_reachability.failures=0

python framework/scripts/generate_event_vocabulary.py --repo-root C:/QM/repo --check
PASS; events=308; unresolved=5

git diff --check
PASS
```

The D6 fixture proves all three required static directions: one real raw call
fails, a helper call passes, and `BarsCalculated` text in a comment/string does
not enter the cohort. A repository census test proves zero remaining raw EA
call sites. A helper contract test fixes the causal order (`CopyBuffer` before
`BarsCalculated`), one-probe-per-bar cache, persistent-error classifier,
bounded escalation, and first-tradable marker schema.

No MetaEditor/terminal compile, factory start, backtest interruption, verdict
mutation, T_Live action, or AutoTrading action was performed.

## Remaining governed runtime proof

After the active-inventory restriction is explicitly cleared, the continuation
must be serial and identity-bound:

1. compile QM5_20096 from source commit `b4745f5b2` outside T_Live;
2. record source/include closure and the new EX5 SHA-256;
3. run one Q02 canary on USDCHF.DWX/H4 with the same 2022-07-01..2022-12-31
   window and fixed-risk setfile;
4. require the report's `execution_identity.expert_binary.sha256` to equal the
   new canonical EX5 hash;
5. accept either trades (then continue normal Q-only adjudication) or bounded
   `SETUP_DATA_MISSING` / gate evidence; zero trades alone is never PASS;
6. let the MNT-038 canary contract decide whether cohort fanout is released.

Until those steps exist, the task's runtime acceptance criterion is not met and
QM5_20096 is not cleared.
