# Codex cross-model challenge: nine-gate funnel autopsy

**Bottom line: the 53.6% headline is stale and its “byte-identical” proof is false, but it is not alarmist about the scale of the Q07 defect. The corrected latest-PASS exposure is still 50.5182% of Sunday risk. More seriously, the audit missed malformed KS baselines, live binaries that predate two kill-switch path repairs, a basket-order bypass of Q06/Q07 stress, and the fact that the supposedly OFF factory was running during this audit.**

## Scope and evidence state

- Repo branch: `agents/board-advisor`.
- Claude audit commit: `92cd3a33a647db9cb10a426fc2b4cf1223da9d53`.
- The branch advanced during this audit because the running pump made additional commits. I compared the implementation files cited below from the audit commit to the later HEAD; `git diff --name-status 92cd3a33..HEAD -- <cited files>` was empty. New EA tranches and factory artifacts did change around them.
- SQLite was opened only with:

  ```python
  sqlite3.connect(
      "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro",
      uri=True,
  )
  ```

- Unless a different time is stated, the final internally consistent DB snapshot below is the read transaction at `2026-07-25T09:04:01.810Z`.
- I ran no backtest and did not read or touch `C:\QM\mt5\T_Live`. Deployment statements use `D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json`, not a direct T_Live inspection.
- This report is the only file I created.

## 1. Verdict table

| Claim | Verdict | Correction |
|---|---|---|
| 1. 53.6% of book risk rests on vacuous Q07 passes | **WEAKENED** | `75/157` and the historical `12 / 5.230471 / 53.6459%` join reproduce exactly, but that is an **ever-PASS** join. Latest Q07 PASS evidence gives **11 sleeves, 4.925520 risk, 50.5182%**; latest overall state gives **10 sleeves, 4.867771 risk, 49.9259%**. `variance_pct=0.00` means equal parsed two-decimal PFs, not byte-identical runs. |
| 2. Twenty orphaned Q10 passes | **WEAKENED** | **27 disk PASS pairs, 7 DB PASS pairs, 20 orphans** survives. FTMO qualification has no disk fallback, but **0/20** orphans clears Q02–Q08 otherwise, and **20/20 are already in the current DXZ LIVE manifest**. The missing rows block FTMO qualification and automated Q11 discovery; they do not block their present DXZ trading. |
| 3. KS baseline-load failure disables the live distribution kill-switch | **SURVIVES** | The live/non-tester path is fail-open at INFO. Common Files has exact baselines for **20/24** live sleeves, but **11/24 live binaries (4.7193 risk)** predate the first committed baseline-path fix. Only **11/24 (4.4316 risk)** are even plausibly armed from repo provenance plus current Common Files. The audit also missed severe baseline-data corruption. |
| 4. Q03 is a phantom gate | **SURVIVES** | `q03_plateau_runner.py` has no production caller. The repeated-Q02 count is **102/106**, not 104/106, on the exact same EA-symbol pair; latest-state FAIL is **74/75** previously Q02-PASS. |
| 5. Q06 is not harsher than Q05 | **WEAKENED** | Numeric thresholds are imported unchanged and the old cost multipliers do not exist. But Q06 really does apply seeded 10% entry rejection on the standard order path, and Q06 hard-fails DD where Q05 parks it as `FAIL_DD_PORTFOLIO_REVIEW`. The old cost-stress design was explicitly re-ratified away on 2026-07-06. |
| 6. Infra split and requeue arithmetic | **WEAKENED** | The audit-time Q02 figure of about **2,246** was sound; the moving final snapshot was **2,245**. Applying “no downstream row” consistently gives **3,281**, not 3,301. The audit’s all-gate number summed “never real” without the downstream exclusion. The claim of zero surviving artifacts is false: **535 report roots, 516 logs, 75 work-item IDs with summaries, and 104 IDs with `report.htm`** survive. |

## 2. Per-claim detail

### Claim 1 — Q07 headline

#### The database counts reproduce, but they are historical rather than current

I ran:

```sql
SELECT verdict, status,
       COUNT(*) AS rows,
       COUNT(DISTINCT ea_id || '|' || symbol) AS pairs
FROM work_items
WHERE phase = 'Q07'
GROUP BY verdict, status;

SELECT COUNT(*) AS rows,
       COUNT(DISTINCT ea_id || '|' || symbol) AS pairs
FROM work_items
WHERE phase = 'Q07'
  AND verdict = 'PASS'
  AND json_extract(payload_json, '$.verdict_reason')
      LIKE 'variance_pct=0.00<%';
```

At `2026-07-25T09:04:01.810Z`:

- Q07 PASS: 231 rows, **157 distinct EA-symbol pairs**.
- Zero-formatted PASS: 109 rows, **75 distinct pairs**.
- Latest row per EA-symbol: 204 pairs, 148 currently PASS, **69 currently PASS at zero variance**.
- Latest PASS row per EA-symbol: 157 pairs, **71 whose latest PASS is zero variance**.

The distinction matters. Among the 75 pairs that ever had a zero-variance PASS, the latest overall row is:

- 69 PASS-zero;
- 3 PASS-nonzero;
- 2 INFRA_FAIL;
- 1 FAIL.

The audit silently changed “ever had this evidence” into present tense.

#### The 12 sleeves and 5.2305 risk are a valid but stale join

I read `D:\QM\reports\portfolio\portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json` and joined on normalized `(ea_id, symbol)`, using:

```python
manifest_key = (str(ea_id), symbol.upper().replace("_DWX", ".DWX"))
risk = sum(sleeve["risk_percent"] for matching sleeves)
```

The manifest declares 9.75 total risk; its 24 sleeve values actually sum to 9.749999.

| Evidence definition | Matching sleeves | Risk | Share of declared 9.75 |
|---|---:|---:|---:|
| Ever had Q07 PASS with formatted zero | 12 | 5.230471 | 53.6459% |
| Latest Q07 PASS is formatted zero | 11 | 4.925520 | 50.5182% |
| Latest Q07 row is currently PASS-zero | 10 | 4.867771 | 49.9259% |

The difference is not cosmetic:

- `QM5_10513 / XAUUSD.DWX` had an older zero PASS but a later nonzero Q07 PASS (`variance_pct=6.68`) before the Sunday manifest. It does not belong in a latest-PASS headline.
- `QM5_10440 / NDX.DWX` has an older zero PASS but is currently INFRA_FAIL. It belongs in the latest-PASS view, not the latest-state PASS view.
- `QM5_1567 / EURUSD.DWX`, risk 0.179051, is a legacy deterministic EA with no effective Q07 RNG/rejection inputs. Its zero variance is expected, not evidence of five distinct stochastic trials.

The 10 latest-zero manifest PASSes other than QM5_1567 all predate commit `1224d518b`:

```text
QM5_10440  2026-06-07
QM5_10911  2026-06-15
QM5_10919  2026-07-03
QM5_10939  2026-06-26
QM5_11165  2026-06-14
QM5_11421  2026-06-26
QM5_12567  2026-06-25/27
QM5_12989  2026-07-03
QM5_1556   2026-07-05
```

Those 10 sum to 4.746469 risk, or **48.6817%** of 9.75. The remaining 0.179051, or 1.8364%, is the deterministic legacy EA. The warning is therefore still large, but the causal statement must separate pre-fix evidence from an EA on which the test has no stochastic treatment.

#### What `variance_pct` actually measures

`framework/scripts/q07_multiseed.py` is unambiguous:

- canonical seeds come from `framework/registry/multiseed_seeds.json`: `[42, 17, 99, 7, 2026]`;
- lines 360–366 read `r["pf"]`, compute `max(pfs)-min(pfs)`, and divide that spread by mean PF;
- lines 371–373 round the stored metric to two decimals;
- line 387 formats the reason with `variance_pct={variance_pct:.2f}`;
- PASS additionally requires every PF to be at least 1.0.

So the variance is over **profit factor**, not net profit, trades, or the trade sequence.

PF comes from `framework/scripts/q05_stress_medium.py:129-147`, which reads `runs[-1]["profit_factor"]` from `summary.json`. The MT5 report value stored there is normally two decimal places. A third-decimal PF difference has already been discarded before Q07 calculates variance. In the surviving evidence I checked, a formatted zero was not a hidden third-decimal difference: all five parsed PFs were exactly equal.

That still does **not** prove byte identity. It proves equality of one coarse scalar.

For the 75-pair ever-zero set, selecting the latest zero PASS evidence:

- only 24 aggregate directories survive;
- all 24 have five per-seed records;
- all 24 have equal parsed PF, trades, DD and net profit across their five records;
- 22 have all five HTML reports still present, and in all 22 cases the five SHA-256 hashes are five different hashes.

One direct example is:

`D:\QM\reports\work_items\ed4b47fa-b6d8-4d71-ba3b-73e12fb6440e.requeued_20260714T2137250000\QM5_10569`

Its five reports have these different SHA-256 hashes:

```text
22C4957273C644648A9B09CC5D0DCC3262B39316A77E87B8E90430D6B5372052
EFFC01B4E8C5997082E9CC1D2B0269AC8BC01DFA08BE8AC39AEFC30E8DD9183B
15F900496A9F9815F56307A7BC643C942480019E16401096F10B519F0B011087
37A21EBC2C9D6D98F1776E8398CA69BEA34291080488543FAC4E210B840769A7
C4F32A772755FE180189534D5A65AA09B975A55981A214DF84B213D5DFEC3268
```

The audit’s phrase “byte-identical results” is false. “Identical parsed headline metrics” is supportable.

#### Is a seed supposed to matter?

Yes, for the normal V5 path under Q06/Q07 stress.

- `framework/include/QM/QM_Common.mqh:116-137` resets the central RNG from the supplied seed.
- `framework/include/QM/QM_Entry.mqh:264-269` calls `QM_RandBoolTagged("entry_reject", probability)` before opening a trade.
- Q07 first generates a Q06 HARSH set, where `qm_stress_reject_probability=0.10`, then varies the seed.

I scanned the canonical MQ5 source for every active EA ID with a source at the audit snapshot, using `framework/registry/ea_id_registry.csv` and `framework/EAs/QM5_*/*.mq5`:

- 3,013 active EA IDs had canonical source;
- 2,915 had both `qm_rng_seed` and `qm_stress_reject_probability` declared and passed/used;
- 2,711 had that RNG configuration plus the standard `QM_TM_OpenPosition` path and no basket helper;
- another 156 had RNG configuration, the standard path and a basket helper;
- zero called `MathRand` or `MathSrand` directly;
- two called central `QM_Rand*` helpers directly.

For the actual Q07 population:

| Population | Pairs | EAs | EAs with RNG config | EAs using basket helper | Legacy/no RNG config |
|---|---:|---:|---:|---:|---:|
| Ever Q07 PASS | 157 | 125 | 123 | 13 | 2 |
| Ever zero Q07 PASS | 75 | 65 | 63 | 11 | 2 |

“Most V5 EAs are deterministic, therefore zero is correct” is the wrong model. Their strategy signals may be deterministic, but Q07 deliberately layers seeded stochastic trade rejection over them. For the standard path, different seeds are meant to reject different entries.

There are two real exceptions:

1. Legacy EAs such as QM5_1551 and QM5_1567 use the older `QM_FrameworkInit` signature. The stress probability remains its default zero, so changing a set-file seed cannot change entries.
2. Basket EAs can bypass the stochastic entry hook entirely; see “What the audit missed”.

#### The injector defect was real, but the repair attribution is incomplete

`git show 1224d518b -- framework/scripts/q07_multiseed.py` confirms a real bug.

Before the fix, absent `qm_rng_seed`, the code did:

```python
anchor = "qm_magic_slot_offset="
if anchor in text:
    new = text.replace(
        anchor + "0",
        f"qm_magic_slot_offset=0\nqm_rng_seed={seed}",
        1,
    )
```

If the slot offset was not zero, the `if` succeeded but the replacement was a no-op. The fix matches the whole offset line, inserts after it, and validates that exactly one requested seed exists.

The archived QM5_10569 evidence proves the effect:

```text
label=42    effective report seed=42  ...seed42.set
label=17    effective report seed=42  ...seed17.set
label=99    effective report seed=42  ...seed99.set
label=7     effective report seed=42  ...seed7.set
label=2026  effective report seed=42  ...seed2026.set
```

However, the repair is incomplete. `q07_multiseed.py:66-176` recovers old results by extracting the nominal seed from the set filename in `tester.ini`; it never validates the effective `qm_rng_seed` recorded in the report. The July 15 aggregate:

`D:\QM\reports\work_items\ed4b47fa-b6d8-4d71-ba3b-73e12fb6440e\QM5_10569\Q07\XAUUSD_DWX\aggregate.json`

was produced after the fix, but all five records are `metric_source="summary_json_reused"` from July 7 pre-fix runs. It relabels those five effective-seed-42 reports as five distinct seeds.

Of the 24 surviving ever-zero aggregates I classified:

- 8 had five nominal seeds but effective report seed 42 throughout: injector defect;
- 7 had five genuinely distinct effective seeds but were basket implementations whose order helper bypasses rejection;
- 7 were legacy/no-RNG-input EAs;
- 1 had only one surviving report;
- 1 had no reports left.

**Conclusion:** the historical injector defect is proven, and the corrected risk remains large. But `variance_pct=0.00` alone is not an identity test, not every zero has the same cause, and post-fix recovery can preserve pre-fix contamination.

### Claim 2 — twenty orphaned Q10 passes

#### Counts

I enumerated:

```powershell
rg --files D:\QM\reports -g aggregate.json |
  rg '\\Q10(\\|$)'
```

and parsed every JSON result, taking the newest `generated_at_utc` for each EA-symbol.

- 44 Q10 aggregate files exist.
- 41 files say PASS and collapse to **27 distinct PASS pairs**.
- 3 files say INVALID and collapse to 3 distinct INVALID pairs.

The DB query:

```sql
SELECT verdict, status,
       COUNT(*) AS rows,
       COUNT(DISTINCT ea_id || '|' || symbol) AS pairs
FROM work_items
WHERE phase = 'Q10'
GROUP BY verdict, status;
```

returns 9 PASS/done rows and **7 distinct PASS pairs**. The disk-PASS set minus the DB-PASS set is exactly **20 pairs**.

`framework/scripts/q10_confirmation.py:276-284` writes `aggregate.json` and, on PASS, invokes the baseline generator. It contains no SQLite write. The audit-time durable row depended on orchestrated work-item dispatch/ingestion.

#### FTMO is fail-closed, with no disk fallback

`tools/strategy_farm/portfolio/ftmo_qualification.py` states at lines 1–6 that it is specifically an FTMO Challenge inventory and that DXZ rescue is a separate contract.

Its behavior is explicit:

- line 27: `STRICT_PHASES = ("Q02", ..., "Q08", "Q10")`;
- lines 64–78: `_latest_phase_row` reads only `work_items`, requires `status='done'`, and orders by latest timestamp;
- lines 208–236: a missing row adds `<phase>_pass_missing`; any verdict other than exact `PASS` blocks;
- there is no aggregate-file fallback for a missing phase row.

So `q10_pass_missing` is a real FTMO hard block.

But the audit overstates what ingesting the 20 rows would accomplish. I reproduced `_latest_phase_row` for Q02–Q08 for each orphan:

```sql
SELECT verdict
FROM work_items
WHERE ea_id=? AND symbol=? AND phase=? AND status='done'
ORDER BY updated_at DESC, created_at DESC, id DESC
LIMIT 1;
```

**Zero of the 20** has exact PASS across every earlier strict phase. They also have Q08 failures/soft failures/infra, Q04 soft/low-frequency states, or missing phases. Adding Q10 rows would make **0/20** `CHALLENGE_READY`.

#### Which track is actually affected?

- **FTMO Challenge:** all 20 are hard-blocked at Q10, but none is otherwise ready.
- **Automated DXZ/Q11 candidate discovery:** `tools/strategy_farm/agent_router.py:1149-1190` also selects Q10 PASS from `work_items` only, so the orphaned pairs are invisible to that automatic sync.
- **Current DXZ live trading:** not blocked. All **20/20** orphaned PASS pairs appear in `D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json`, whose status is `LIVE`.

This is a persistence and automation defect, not evidence that 20 new sleeves are waiting one row away from live or FTMO admission.

### Claim 3 — KS distribution kill-switch

#### The fail-open path is reachable in live

The actual initialization path is:

- `framework/include/QM/QM_Common.mqh:215-222` initializes the ordinary kill switch and then unconditionally calls `QM_KillSwitchKSInit(ea_id, _Symbol)`.
- `framework/include/QM/QM_KillSwitchKS.mqh:217-220` skips only when `MQL_TESTER != 0`.
- A live chart is not the strategy tester, so it reaches the baseline load. An `ENV=live` string does not guard this path.
- lines 223–231 set `g_qm_ks_baseline_loaded=false`, log INFO event `KS_BASELINE_ABSENT` with action `ks_killswitch_dormant`, and continue initialization.
- lines 239–240 and 307–310 make the trade feed and check no-ops while the baseline is absent.

The audit calls the log `ks_killswitch_dormant`; that is the JSON action. The event name is `KS_BASELINE_ABSENT`. The failure is visible if someone reads INFO logs, but it is fail-open and non-fatal.

#### Other guards do not cover the same risk

`QM_Common.mqh:215` initializes the ordinary guard as:

```text
daily loss = 3.0%
portfolio DD threshold = 0.0 (disabled)
per-trade risk cap = 1.0%
```

`framework/include/QM/QM_KillSwitch.mqh` also supports a manual halt file and an external portfolio-DD signal.

Those controls are not substitutes for distribution drift:

- the daily halt reacts only after a 3% equity loss;
- the per-trade cap limits sizing, not a changed win/loss distribution;
- manual and portfolio files require an external action/signal;
- the default portfolio-DD percentage is zero.

This is a real uncovered detection layer, not harmless redundancy.

#### Current Common Files inventory and symbol naming

I listed only:

`C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines`

It contains 54 JSON files, representing 27 EA-symbol pairs with both canonical `.DWX`-derived and suffix-stripped aliases.

I compared exact runtime filenames computed by:

```powershell
"QM5_$ea_$($symbol.Replace('.','_')).json"
```

to the 24 sleeves in `portfolio_manifest_live_24sleeve_20260724.json`.

- Exact Common baseline present: **20/24**.
- Missing: **4/24**, totaling 0.9617 of the live manifest’s 9.7499 risk:

  ```text
  QM5_1567_EURUSD_DWX.json
  QM5_10440_NDX_DWX.json
  QM5_10513_XAUUSD_DWX.json
  QM5_13117_EURGBP_DWX.json
  ```

The current LIVE manifest says its `symbol` is the host/chart symbol and records `.DWX`, for example `NDX.DWX`. That maps to `QM5_<id>_NDX_DWX.json`, not `QM5_<id>_NDX.json`. Where a baseline exists, `framework/scripts/gen_q10_baseline.py:118-127` writes both variants anyway. Symbol aliasing is implemented correctly for the current `.DWX` deployment; absence, not `NDX` versus `NDX_DWX`, is the issue for QM5_10440.

#### The deployed-binary provenance is worse than the file inventory

The distribution KS originally used an impossible drive-letter path. Commit history shows:

- `47f1d9709` on 2026-07-05 fixed the ordinary manual/portfolio halt paths from invalid `D:\...` paths to MQL sandbox-relative paths.
- `d8b741d02` on 2026-07-06 fixed the KS baseline path from `D:\QM\data\baselines\...` to `QM\baselines\...`.

The current LIVE manifest records deployed EX5 mtimes. Eleven sleeves, totaling **4.7193 risk**, predate the baseline-path fix:

```text
10919 XTIUSD.DWX
11421 AUDUSD.DWX
11421 EURUSD.DWX
10939 GBPUSD.DWX
10911 GDAXI.DWX
10440 NDX.DWX
11132 SP500.DWX
10513 XAUUSD.DWX
12567 XAUUSD.DWX
12989 XAUUSD.DWX
12567 XNGUSD.DWX
```

Nine of those now have Common baselines, but a binary compiled from the pre-fix source still asks for the impossible old path. Barring an unrecorded pre-commit local build, those nine cannot use the files that now exist. The same pre-July-5/6 group also predates the ordinary manual-halt path repair.

Crossing deployed mtime with current Common files gives:

| Provenance / Common baseline | Sleeves | Risk |
|---|---:|---:|
| Pre-path-fix binary, baseline absent | 2 | 0.3627 |
| Pre-path-fix binary, baseline now present | 9 | 4.3566 |
| Post-path-fix binary, baseline absent | 2 | 0.5990 |
| Post-path-fix binary, baseline present | 11 | 4.4316 |

Only the last 11 are plausibly armed from the evidence available outside T_Live.

#### The audit missed that the baselines themselves are malformed

`framework/scripts/gen_q10_baseline.py:71-103` does not parse table cells. It strips a whole deal row, finds decimal-looking substrings, and takes `nums[-2]`, assuming that the last number is balance and the previous one is profit.

That assumption fails in two ordinary MT5 cases:

1. spaced thousands: `-1 023.75` is matched as positive `023.75`;
2. numeric comments such as `sl 0.74059` add a decimal after the balance, shifting `nums[-2]` to the balance fragment.

The generator also stores the deal’s **gross `DEAL_PROFIT` column**. Live code at `QM_Common.mqh:805-808` feeds:

```text
DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION
```

to the KS window. The baseline and live samples therefore do not even measure the same quantity.

I parsed the actual `<td>` cells in the newest 27 Q10 PASS reports and compared the true Profit cell with the value selected by the generator:

- 6,569 closing-deal rows;
- **2,380 corrupted rows**;
- **24/27 baseline pairs** contain at least one corrupted value;
- 19/27 source reports contain nonzero commission;
- 12/27 contain nonzero swap.

Example from the Q10 AUDUSD report:

```text
... commission=-2.31 swap=-8.26 profit=-1 023.75 balance=98 665.86 sl 0.74059
```

The regex heuristic does not recover `-1023.75` from that row.

As a read-only forensic replay, I fed the correctly parsed chronological historical net deals through the exact current ring size, 30-sample minimum, KS statistic, and `1.358 * sqrt((n1+n2)/(n1*n2))` threshold, while retaining the malformed stored baseline. This is not a backtest and is not a forecast; it tests whether a baseline disagrees with its own source history.

- **17/27** Q10 PASS baselines would declare their own correctly parsed source history divergent at some point.
- Of the 11 live sleeves that are plausibly armed from binary provenance plus Common-file presence, **10/11 have parser corruption** and **8/11 self-diverge** in that replay.

The KS path therefore has both failure modes: dormant where load/provenance fails, and false-kill risk where a malformed baseline loads.

### Claim 4 — Q03 phantom gate

I searched the audit commit:

```powershell
git grep -n "q03_plateau_runner" 92cd3a33 -- ':!docs/**'
```

The only matches are:

- self-references inside `framework/scripts/q03_plateau_runner.py`;
- `framework/scripts/tests/test_q03_plateau_runner.py`;
- a static file-list entry in `tools/strategy_farm/codex_kill_safety_audit.py`.

The safety audit reads/scans the file; it does not execute the gate.

The production dispatch confirms the orphan:

- `tools/strategy_farm/farmctl.py` has a misleading `PHASE_RUNNER_SCRIPTS["Q03"] = "p3_param_sweep.py"`;
- Q03 is absent from `REAL_PHASE_RUNNER_PHASES`;
- `_spawn_work_item_runner` therefore sends Q03 to `_spawn_run_smoke_for_work_item`, not to any phase runner;
- the source comment explicitly says “Q03 repeats the Q02 baseline for determinism.”

No dispatch table reaches `q03_plateau_runner.py`.

DB correction:

```sql
WITH f AS (
  SELECT DISTINCT ea_id, symbol
  FROM work_items
  WHERE phase='Q03' AND verdict='FAIL'
)
SELECT COUNT(*) AS fail_pairs,
       SUM(EXISTS(
         SELECT 1 FROM work_items q
         WHERE q.phase='Q02'
           AND q.ea_id=f.ea_id
           AND q.symbol=f.symbol
           AND q.verdict='PASS'
       )) AS same_pair_q02_pass
FROM f;
```

Result: **106 FAIL pairs, 102 with a same-pair Q02 PASS**, not 104.

The 106 break down as:

- 95 pairs with `run_smoke_fail:MIN_TRADES_NOT_MET`;
- 10 pairs with `ACTIVE_TIMEOUT`;
- 1 pair with `run_smoke_fail:NON_DETERMINISTIC`.

On latest state only, 75 pairs are Q03 FAIL and 74 previously have same-pair Q02 PASS.

The conclusion survives. The audit’s 104 came from an EA-level or otherwise broadened match; exact EA-symbol matching gives 102.

### Claim 5 — Q06 versus Q05

The implementation facts mostly reproduce:

- `framework/scripts/q05_stress_medium.py:50-52`: PF floor 1.0, DD ceiling 25.0%, minimum trades 20.
- `framework/scripts/q06_stress_harsh.py:32-35`: imports those constants directly.
- `framework/scripts/gen_stress_setfile.py:37-38`: MED rejection 0.00, HARSH rejection 0.10.
- Neither runner passes a slippage, spread multiplier, or commission multiplier.
- `decisions/2026-07-06_q06_spec_reratification.md` explicitly records that the old +5/x3/x3 design never existed and re-ratifies Q06 as 10% seeded trade rejection.

The literal title “Q06 is not harsher” is still wrong in two ways:

1. For the normal `QM_TM_OpenPosition` path, 10% seeded rejection changes the trade sample and is a real adverse perturbation. At the audit source snapshot, 2,711 active-source EAs had the configured RNG plus standard non-basket entry path.
2. Above 25% DD, Q05 returns `FAIL_DD_PORTFOLIO_REVIEW`, while `q06_stress_harsh.py:177-178` returns hard `FAIL`.

It is also less universal than the audit suggests:

- legacy EAs without the stress input get no perturbation;
- `QM_BasketOpenPosition` bypasses the rejection hook, so basket Q06/Q07 can be identical.

Correct statement: **Q06 has the same numeric PF/trade/DD thresholds, no historical cost-multiplier implementation, a real 10% rejection stress on the standard path, hard-fail DD semantics, and no equivalent stress on the basket helper.** The missing cost multipliers are a coverage choice ratified on July 6, not an unnoticed current-code drift.

### Claim 6 — infra split and requeue arithmetic

#### The audit mixes two definitions

I implemented the stated definition exactly:

```sql
WITH po(phase, ord) AS (
  VALUES ('Q02',2),('Q03',3),('Q04',4),('Q05',5),('Q06',6),
         ('Q07',7),('Q08',8),('Q09',9),('Q10',10)
),
infra AS (
  SELECT DISTINCT w.ea_id, w.symbol, w.phase, p.ord
  FROM work_items w
  JOIN po p USING (phase)
  WHERE w.verdict='INFRA_FAIL'
)
SELECT phase, COUNT(*)
FROM infra i
WHERE NOT EXISTS (
  SELECT 1 FROM work_items r
  WHERE r.ea_id=i.ea_id
    AND r.symbol=i.symbol
    AND r.phase=i.phase
    AND r.verdict IS NOT NULL
    AND r.verdict!='INFRA_FAIL'
)
AND NOT EXISTS (
  SELECT 1 FROM work_items d
  JOIN po pd ON pd.phase=d.phase
  WHERE d.ea_id=i.ea_id
    AND d.symbol=i.symbol
    AND pd.ord>i.ord
)
GROUP BY phase;
```

At the final snapshot:

| Phase | Has any INFRA pair | Never got non-INFRA verdict | Also has no higher-numbered phase row |
|---|---:|---:|---:|
| Q02 | 9,346 | 2,249 | 2,245 |
| Q03 | 508 | 11 | 0 |
| Q04 | 1,220 | 982 | 982 |
| Q05 | 54 | 31 | 26 |
| Q06 | 8 | 5 | 5 |
| Q07 | 19 | 15 | 14 |
| Q08 | 37 | 9 | 9 |
| **Total** |  | **3,302** | **3,281** |

Earlier in this audit, before another live result landed, Q02 was 2,246 and “never real” totaled exactly 3,301. That reconstructs Claude’s numbers:

- the Q02 correction used the **no-downstream** definition;
- the all-gate 3,301 total used **never-real only**, without subtracting downstream rows.

The arithmetic is internally inconsistent. With the same definition at all gates, the final snapshot is 3,281.

The definition itself is also not a faithful pipeline-state model. The pipeline is a DAG, not a numeric chain. `farmctl.py` deliberately launches a Q04-early probe in parallel with Q03. A Q04 row therefore does not prove Q03 resolved. That is why all 11 current never-real Q03 pairs disappear under the simplistic “any higher phase exists” rule. A defensible requeue inventory needs phase-specific dependency edges and current build/evidence lineage, not phase-number comparison.

#### It is not a clean 3,281-item requeue queue

I normalized only the mechanical `_DWX`/`.DWX` spelling and joined the 3,281 exact triples to:

- `framework/registry/ea_id_registry.csv`;
- `framework/registry/magic_numbers.csv`;
- `framework/registry/dwx_symbol_matrix.csv`.

Results at that query:

- normalized triples: 3,280; one exact triple disappears as an alias duplicate;
- 3,278 belong to registry `active` EAs and 2 to an `APPROVED` EA; none belongs to a retired EA;
- 2,902 have an active exact EA-symbol magic row;
- 83 have only a reserved magic row;
- 6 have a retired magic row;
- 289 have no magic row;
- 13 are logical-basket identifiers;
- 77 use obsolete/non-canonical `GER40.DWX` rather than registered `GDAXI.DWX`.

So Claude did not materially double-count retired cards, but it did conflate:

- registry-clean retryable units;
- reserved/not-yet-active symbol rows;
- retired or missing magic allocations;
- obsolete symbol aliases;
- logical baskets that need basket-aware dispatch.

The strict active-magic cohort is **2,902**, not 3,301. That is not necessarily the final actionable count—some missing-magic rows may be registry defects and some logical baskets are valid—but it is the honest registry-clean subset.

#### `summary_missing_retries_exhausted`

The reason-location warning is correct for the dominant class. The exact query is:

```sql
SELECT COUNT(*) AS rows,
       COUNT(DISTINCT ea_id || '|' || symbol) AS pairs,
       SUM(json_extract(payload_json,'$.verdict_reason') IS NULL) AS null_reason
FROM work_items
WHERE phase='Q02'
  AND verdict='INFRA_FAIL'
  AND json_extract(payload_json,'$.final_failure')
      ='summary_missing_retries_exhausted';
```

At the final moving snapshot:

- **43,741 rows** rather than the audit’s 43,737;
- **7,901 distinct pairs**;
- **43,430 rows with NULL `verdict_reason`**, exactly confirming the special reason-location problem.

Pair recovery depends on the definition:

```text
any non-INFRA verdict ever: 5,868 / 7,901 = 74.27%
status=done non-INFRA ever: 5,801 / 7,901 = 73.42%
```

That brackets the audit’s moving 73.8% figure. It is a historical association, not proof that any particular unresolved pair will recover.

#### “Zero surviving artifacts” is false

I selected the 43,741 work-item UUIDs above, listed top-level report directories and logs, and then recursively classified files only under matching UUID roots.

Results:

- **535** matching report-root directories;
- **516** matching `work_item_<uuid>.log` files;
- all 535 matching report roots belong to work items created before the audit file’s `2026-07-25T07:58:36Z` timestamp;
- **75 work-item IDs** have at least one `summary.json` (76 summary files);
- **104 work-item IDs** have at least one `report.htm`;
- 64 summaries are the exact recorded P2 prescreen evidence and say PASS;
- the 12 other summaries comprise 2 PASS and 10 FAIL; the FAIL summaries expose `BARS_ZERO`, `INCOMPLETE_RUNS`, `ONINIT_FAILED`, `REPORT_MISSING`, and `METATESTER_HUNG`.

The surviving share is small—43,206 of the 43,741 rows have no matching report root—but it is not zero. A stratified forensic sample exists. The claim that the transient classification rests **entirely** on recovery rate is therefore wrong; the stronger and still valid criticism is that the surviving evidence is sparse and likely selection-biased.

#### The claimed reason-source map is also too absolute

The current-state reason should be taken from the latest `work_items.payload_json.verdict_reason`, and `final_failure` is essential for the dominant Q02 class. That part is correct.

But `ea_metrics.detail_json` is not “null throughout.” I ran:

```sql
SELECT COUNT(*) AS rows,
       SUM(detail_json IS NULL) AS null_detail,
       SUM(detail_json IS NOT NULL) AS nonnull_detail
FROM ea_metrics;
```

At the query point:

- 55,563 metric rows;
- **12,718 non-NULL `detail_json`** rows;
- Q02 alone: 7,501 non-NULL;
- Q07: 172 non-NULL;
- even the summary-missing class has 36 joined non-NULL detail rows.

Some details include a `reason`, while others contain only run metrics. `ea_metrics` remains historical and is not the right source for the latest state, but “null throughout” is factually false.

## 3. What the audit missed

### 1. The factory was not OFF

This is the highest-consequence operational finding because it invalidates the premise of a stable autopsy and violated the stated safety state independently of my actions.

I ran the read-only query:

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -match 'python|claude|codex' } |
  Select-Object ProcessId, Name, CreationDate, CommandLine
```

It showed:

- nine `terminal_worker.py` processes for T1, T2, T3, T4, T6, T7, T8, T9 and T10;
- an active Q07 multiseed runner;
- active Q08 aggregation/neighborhood runners;
- a pump task;
- later, additional Q04/Q07 work.

`D:\QM\strategy_farm\state\farm_state.sqlite` had `LastWriteTimeUtc=2026-07-25T08:45:23Z`, and DB counts changed while I queried them. The branch also advanced through pump auto-commits.

I did not start, stop, or touch any terminal or factory process. The owner needs to treat the “factory OFF” assertion as disproven at the time of this audit.

### 2. Q10 KS baselines corrupt 2,380 of 6,569 closing deals and compare gross history with net live results

This is more dangerous than the audit’s missing-file finding because it affects baselines that successfully load. The parser error spans 24/27 current PASS baselines, and the gross/net mismatch is structural. The self-history replay diverges in 17/27 cases and 8/11 plausibly armed live sleeves.

Evidence and method are in Claim 3. The repair must parse named table cells and generate the exact same net quantity that live feeds.

### 3. Eleven live sleeves predate both kill-switch path-repair waves

The current LIVE manifest records 11 EX5 mtimes before the July 5/6 fixes, totaling 4.7193 risk. For those binaries:

- the distribution baseline path is expected to remain the impossible drive-letter version;
- the default manual/portfolio halt file path is also expected to remain the impossible drive-letter version.

The internal 3% daily-loss halt still exists, but two external safety channels and the distribution channel cannot be presumed armed. A source-to-binary hash/commit manifest is missing, so this conclusion is a strong provenance inference rather than a binary decompilation result.

### 4. Basket orders bypass the only Q06/Q07 stochastic treatment

`framework/include/QM/QM_Entry.mqh:264-269` contains the seeded rejection hook. `framework/include/QM/QM_BasketOrder.mqh:104-218` performs kill/news/risk checks and calls `QM_TradeContextSend` directly, with no RNG or stress-rejection check.

This is not hypothetical:

- 174 active-source EAs in the later census call `QM_BasketOpenPosition`;
- 11 of the 65 ever-zero Q07 PASS EAs are basket implementations;
- surviving post-fix basket artifacts include genuinely distinct effective seeds with identical trades/PF/DD/net because no stochastic branch is reached.

Example: `framework/EAs/QM5_13140_energy-aliq-rank/QM5_13140_energy-aliq-rank.mq5` opens actual legs through `QM_BasketOpenPosition`; its standard entry function is a dummy path. Its five effective report seeds are distinct, yet all 134 trades and headline metrics are identical.

Q06 is therefore not a universal 10% rejection gate, and Q07 cannot certify multiseed robustness for basket executions until the basket helper consumes the same tagged RNG decision.

### 5. Q07 recovery can launder pre-fix evidence into a post-fix PASS

`_recover_existing_seed_results` searches `.requeued_*` archives and authenticates a seed by the seeded set filename in `tester.ini`. It does not compare that label with the effective report input.

The QM5_10569 July 15 aggregate is a direct post-fix PASS assembled entirely from five July 7 reports that all used effective seed 42. Any repair that only fixes `_write_seeded_setfile` leaves this laundering path open.

### 6. “Stuck” is being modeled as a linear phase number despite parallel gates

The Q04-early probe deliberately runs in parallel with Q03. Therefore “has any downstream row” is not a generic proof of recovery. This modeling error is why all 11 never-real Q03 pairs vanish from the supposedly stricter stuck count.

The state query needs an explicit phase-dependency graph plus build/evidence lineage. A numeric `phase > current_phase` test is not adequate.

## 4. What I could not settle

1. **Actual OnInit load state per live chart.** T_Live was prohibited. The decisive evidence would be an externally exported, read-only set of current startup log events keyed by EA/magic showing `KS_BASELINE_LOADED` or `KS_BASELINE_ABSENT`.

2. **Terminal-local baseline shadowing.** The loader checks terminal-local files before Common Files. I did not inspect T_Live, so I cannot exclude a local baseline for the four Common-missing sleeves or a stale local file shadowing a newer Common baseline.

3. **Exact binary-to-source provenance.** EX5 mtime predating the first committed fix is strong evidence, but a signed deploy manifest containing EX5 SHA-256 plus source commit/build SHA would settle it without decompilation.

4. **The 51 ever-zero Q07 pairs whose latest zero-PASS aggregate no longer exists.** Their cause can be inferred from source shape and run date, but only preserved reports can prove effective seed and order path.

5. **A true causal recovery rate for the Q02 summary-missing class.** The 73–74% historical pair association and the surviving artifact sample do not establish that unresolved pairs are transient. A sealed, registry-clean canary cohort with durable artifacts would settle it; I ran no canary or backtest.

6. **Audit-time DB reconstruction to the row.** No sealed SQLite snapshot at the Claude audit timestamp was available, and the factory was writing during this challenge. I preserved both the figures I reproduced before subsequent results landed and the final consistent read-transaction timestamp.

7. **Whether any malformed KS baseline has already fired or suppressed a live sleeve.** That requires live event history and position state, both outside the allowed read scope.
