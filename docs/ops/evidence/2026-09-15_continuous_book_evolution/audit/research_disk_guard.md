# Audit — Research Resource Guards (directive §34, evidence-based)

**Scope:** measure disk/RAM/CPU headroom, the research resource guard, tester-cache
retention policy, and the actual disk needs of the research jobs. Read-only.
**Date:** 2026-09-15 · **Auditor:** Claude (read-only) · **Truth precedence:** directive §1.

---

## Headline (3 lines)

1. The research guard refuses jobs when **D: < 80 GB free** (`RESEARCH_DISK_MIN_FREE_GB=80`, drive `D:/`), but the tester-cache purge holds D: at its **60 GB** low-water — so **80 > 60 means research on D: is structurally, permanently refused**; live guard right now returns `allowed:false … DISK_LOW:61.2GB<80.0GB`.
2. The 80 GB floor is **not evidence-based**: research's real D: footprint is ~0.3 GB (the venv); its dataset output already writes to **C:** (`DEFAULT_OUT_ROOT=C:\QM\repo\artifacts\research_datasets`, currently empty, few-MB CSVs). CPU (0%) and RAM (27.8 GB free) are not the binding constraint — disk is, and only because the guard watches the wrong drive at the wrong threshold.
3. D: has only **61.2 GB free of 953.9 GB** (6.4%); **~30 GB of idle tester cache is reclaimable now** under the existing evidence-guarded retention policy (would lift D: to ~91 GB and clear the guard). Factory worst-case burn is ~50–100 GB/hr under 10-terminal cold-cache saturation.

---

## Findings (numbered, each with evidence)

### 1. Volumes — free/total per drive
Measured `Get-Volume` / `Get-PSDrive` (locale uses comma decimals):

| Drive | Label | Total GB | Free GB | Free % | Type | Note |
|-------|-------|---------:|--------:|-------:|------|------|
| C: | (system) | 476.1 | 86.9 | 18.2% | Fixed | repo + research dataset output |
| D: | QM_DATA | 953.9 | 61.2 | 6.4% | Fixed | factory + runtime + evidence; **binding constraint** |
| G: | Google Drive | 476.1 | 82.5 | — | Cloud (Drive File Stream) | Company Vault. **Cloud-backed virtual drive — never use for scratch/venv/factory; not local, not fail-safe.** |

Evidence: `Get-Volume`, `Get-PSDrive -PSProvider FileSystem` (this audit). G: is `G:\My Drive\QuantMechanica - Company Reference\` per `CLAUDE.md`; its reported size mirrors the local cache, it is not a real fixed volume.

### 2. D:/QM top-level directory sizes (depth-1; classification)
`Get-ChildItem -Recurse` sum per dir (upper bounds — the sum exceeds the 954 GB volume, so some content is block-clone/junction double-counted; treat as ceilings):

| Dir | GB | Class | Purgeable? |
|-----|---:|-------|-----------|
| `mt5` | 883.41 | mixed | **Only** `T*\Tester\bases` + `T*\Tester\Agent-*` (regenerable caches). `T*\Bases\Custom` (.DWX tick history) = **canonical, KEEP**; `T_Live` = **NEVER TOUCH** |
| `strategy_farm` | 173.16 | mixed | `state\farm_state.sqlite` + state = **canonical verdicts, KEEP** |
| `reports` | 88.31 | evidence | **KEEP** — purge never touches `D:\QM\reports` (policy) |
| `archive` | 41.19 | evidence | **KEEP** (archive matrix) |
| `data` | 2.97 | inputs | **KEEP** (news_calendar seed) |
| `tmp` | 2.02 | scratch | disposable (no auto-retention; manual) |
| `venvs` | 0.41 | tooling | keep |
| `research` | 0.30 | tooling | research venv (`D:\QM\research\venv`) |
| `ftmo` | 0.24 | artifacts | keep |
| `exports`/`scratch`/`audit_snapshots`/… | ≤0.12 each | mixed/scratch | `scratch` (0.08) disposable |

Evidence: background PowerShell size scan, this audit; `CLAUDE.md` (reports/Bases never purged); `tester_cache_purge.ps1` header lines 6–9.

### 3. Retention policy — tester_cache_purge.ps1 + scheduled task
- **Scheduled action (runtime truth):** `powershell.exe … -File …\tester_cache_purge.ps1 -LowWaterGB 60`, trigger every `PT10M`, task `QM_StrategyFarm_TesterCachePurge`, State `Ready`. Evidence: `Get-ScheduledTask` (this audit).
- **Script default (stale):** `param([int]$LowWaterGB = 150)` at `tester_cache_purge.ps1:30` with a comment claiming 80→150 was raised. The live task overrides to **60**. Effective floor = **60 GB**.
- **What it clears:** only `T<n>\Tester\bases\*` and `T<n>\Tester\Agent-*` (regenerable MT5 caches). It **never** touches `Bases` top-level tick data or `D:\QM\reports` (`tester_cache_purge.ps1:6–9`).
- **Evidence guard:** every run builds a DB + signed-live exclusion plan (`Get-EvidencePurgePlan` → `tester_cache_purge_guard.py`) and fails closed on any error; protects active work-item terminals and evidence targets. Live log: `EVIDENCE_EXCLUSIONS status=PASS db_pairs=38 live_pairs=24 union_pairs=99 protected_targets=35`. Evidence: `D:\QM\reports\state\tester_cache_purge.log`.
- **Behavior at 60 GB floor:** log shows D: hovering 60.2–61.2 GB, every run logging `SKIP: D: free …GB >= 60GB threshold`. So steady-state D: free ≈ 60–61 GB.

### 4. Research guard code and thresholds
`tools/strategy_farm/research/research_env.py`:
- `RESEARCH_DISK_MIN_FREE_GB = 80.0` (line 51); `DEFAULT_RESEARCH_DRIVE = Path("D:/")` (line 66); `DEFAULT_VENV_PATH = D:\QM\research\venv` (line 65).
- `CPU_HIGH_PAUSE_PERCENT = terminal_worker.CPU_MAX_LOAD_PERCENT = 97.0`; `RAM_MIN_FREE_GB = 14.0`, `RAM_RESUME_FREE_GB = 20.0` (read from `terminal_worker.py:168–169,210`).
- Guard refuses if CPU > 97%, **or D: free < 80 GB**, or free RAM < 14 GB, or mutation lock is `live` (`research_env.py:150–163`).
- **Live decision (this audit):** `allowed:false`, reasons `["DISK_LOW:61.2GB<80.0GB free on D:\\"]`, measurements `cpu 0.0%`, `free_ram 27.8GB`, `mutation_lock absent`. Command: `python research_env.py guard`.

**The layering is inconsistent:** worker backtest floor **40** < purge low-water **60** < research floor **80**. Since the purge deliberately parks D: at ~60, the research floor of 80 is above the maximum steady-state free space the system ever reaches. Research is therefore blocked not by real scarcity but by a floor set above the disk's own operating band. `research_env.py:49` comment reasons only against the 40 GB worker floor and never against the 60 GB purge floor that actually governs D:.

### 5. What research actually needs (measured)
- **Venv:** `D:\QM\research\venv` = **0.30 GB** (one-time, already provisioned). Packages: pandas/duckdb/scipy/scikit-learn/statsmodels/pyarrow.
- **Dataset output:** `observe_projector.py` `DEFAULT_OUT_ROOT = C:\QM\repo\artifacts\research_datasets` (line 57) — writes small CSVs (gate_outcomes, ea_metrics, holds, sources, idea_families) + a manifest. Directory currently **does not exist / empty** (no runs yet); comment line 54: "Small few-MB artifacts default to the C: repo/reports side, never a large D: intermediate." Source DB is read-only (`farm_state.sqlite` = 1.27 GB).
- **Runtime D: footprint after provisioning: ≈ 0 GB** (output on C:, DB read-only). So the 80 GB D: guard does **not** protect against research's own consumption; at most it is a "yield to a disk-pressured factory" latch — but calibrated to a value the disk never reaches.
- **RAM/CPU:** free RAM 27.8 GB (floor 14, resume 20 — ample); CPU 0% (pause line 97%). Concurrency capped at `MAX_WORKER_PROCESSES=2`, below-normal OS priority. Not binding.

### 6. Factory disk need / burn rate (worst case)
From `tester_cache_purge.log` (2026-08-13 saturation window): D: fell 126→46→22 GB over ~45 min of active 10-terminal backtesting, i.e. **~50–100 GB/hr** cold-cache growth; single idle-cohort purges reclaimed 72–101 GB. The 20 GB gap between the purge floor (60) and the research floor (80) is far smaller than one hour of factory burn — headroom is genuinely tight, which is why the guard must yield to the factory, but the current threshold makes it yield *always*.

### 7. Reclaimable disposable space now (evidence-guarded, no evidence deleted)
Dry-run of the sanctioned purge (`-LowWaterGB 300 -Mode IdleCaches -DryRun`): `IDLE_CACHE_PREFLIGHT targets=42 candidate_gb=30.023`, protecting active terminals `[T1,T2,T6,T7]` and 35 evidence targets. Running the real purge would lift D: ≈ 61 → ~91 GB — above the 80 GB guard. Plus `D:\QM\tmp` 2.02 GB and `D:\QM\scratch` 0.08 GB of non-evidence scratch.

---

## Drift table

| # | Doc/vault says | Runtime says | Path |
|---|----------------|--------------|------|
| 1 | Purge low-water 150 GB (`tester_cache_purge.ps1:30` default + comment) | Scheduled task runs `-LowWaterGB 60`; CLAUDE.md confirms 60 | `Get-ScheduledTask QM_StrategyFarm_TesterCachePurge`; `CLAUDE.md` §Disk |
| 2 | Research floor "stays well above the DISK_MIN_FREE_GB=40 worker floor" (`research_env.py:49`) | Floor 80 sits **above** the 60 GB purge floor that governs D:, so it is never satisfied; live guard `DISK_LOW:61.2<80` | `research_env.py:49,51`; `python research_env.py guard` |
| 3 | Research guard watches drive `D:/` (`research_env.py:66`); docstring implies research consumes D: | Research datasets write to **C:** (`observe_projector.py:57`); D: runtime footprint ≈ venv 0.3 GB only | `research_env.py:66`; `observe_projector.py:54,57` |
| 4 | (design doc sec 2.3) research floor 80 GB is the "D6 gate" | 80 is not derived from any measured research need (~0.3 GB); it exceeds the disk's operating band | `research_env.py:48–51` |

---

## Open questions strictly requiring OWNER

None. All values are measured or code-defined; the fix is a calibration/relocation change within existing autonomy (GRÜN/GELB: infra repair that does not touch verdict logic, tested, rollback-documented). The threshold constant is not a gate criterion or contract, so ROT does not apply.

---

## Recommended actions (concrete, for implementing phases)

### R1 — Fix the research guard so it is evidence-based (PRIMARY, recommended)
Research already writes to C: and its D: footprint is ~0.3 GB, so watch the drive research actually uses and set a floor from its measured need. In `tools/strategy_farm/research/research_env.py`:
- Line 66: `DEFAULT_RESEARCH_DRIVE = Path("C:/")` (the drive of `observe_projector.DEFAULT_OUT_ROOT`).
- Line 51: `RESEARCH_DISK_MIN_FREE_GB = 20.0` = `max(measured research need 0.3 GB × 2, 20 GB safety margin)`; C: has 86.9 GB free → passes with wide margin.
- Add env overrides read at guard entry: `QM_RESEARCH_DRIVE` (default `C:/`) and `QM_RESEARCH_DISK_MIN_FREE_GB` (default `20.0`), so OWNER/ops can retune without a code change.
- Relocate the venv off D: to keep D: purely factory: `DEFAULT_VENV_PATH = Path(r"C:\QM\research\venv")` (line 65), or add env `QM_RESEARCH_VENV_PATH`. Re-provision via `python research_env.py provision-venv --venv-path C:\QM\research\venv`.

### R2 — If the factory-yield intent on D: must be kept (FALLBACK)
Keep `DEFAULT_RESEARCH_DRIVE = D:/` but source the floor from the purge low-water so the two can never contradict: set `RESEARCH_DISK_MIN_FREE_GB = 60.0` (= the live purge `-LowWaterGB`) and document it as "must equal the tester_cache_purge low-water." Add env `QM_RESEARCH_DISK_MIN_FREE_GB`. Research then runs whenever D: ≥ 60 (its steady state) and yields exactly when the factory hits its own cache floor. Safe because research consumes ≈0 on D:.

### R3 — Retire the stale purge default
`tools/strategy_farm/tester_cache_purge.ps1:30`: change the default `[int]$LowWaterGB = 150` to `60` (matching the live scheduled-task override) and update the 80→150 comment, so the code default and runtime agree. Confirm the scheduled task keeps `-LowWaterGB 60`.

### R4 — Reclaim disposable space now (do NOT run in this audit; no evidence deleted)
The existing evidence-guarded purge reclaims ~30 GB of idle tester cache (protects active terminals + 35 evidence targets):
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\tester_cache_purge.ps1 -LowWaterGB 120 -Mode IdleCaches
```
(Setting `-LowWaterGB` above current free triggers the idle purge, which stops only idle slots, clears regenerable caches, and restarts workers.) Additionally `D:\QM\tmp` (2.0 GB) and `D:\QM\scratch` (0.08 GB) are non-evidence scratch a human may review and clear. **Never** propose deleting `reports`, `archive`, `strategy_farm\state`, `mt5\T*\Bases\Custom`, `data`, or anything under `T_Live`.

### R5 — Document the layering invariant
Record in the research design doc / `CLAUDE.md` the required ordering `worker_disk_floor (40) ≤ purge_low_water (60) ≤ research_floor` and that the research floor must never exceed the purge steady-state, so this contradiction cannot recur.
