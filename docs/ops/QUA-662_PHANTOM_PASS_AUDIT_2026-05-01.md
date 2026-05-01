# QUA-662 P2 Phantom-PASS Matrix Audit (2026-05-01)

**Author:** Board Advisor, at OWNER direction.
**Verdict:** All 36 rows in `D:\QM\reports\pipeline\QM5_1003\P2\report.csv` are INVALID. Five concurrent failure modes; matrix is 100% noise.
**Authority:** OWNER 2026-05-01 directive; DL-038 (Seven Binding Backtest Rules); DL-054 (Anti-Theater Pass Criteria, this commit).

## Smoking gun

Pipeline-Op produced both files in the same directory in the same window:

| File | Verdict by Pipeline-Op |
|---|---|
| `report.csv` (37 lines, 1 header + 36 data rows) | every row `PASS` |
| `zero_trade_audit_20260501.json` | `"rows": 36, "zero_trade_rows": 36` |

A row with zero trades cannot be `PASS`. The two files contradict each other. Pipeline-Op's harness wrote both and never reconciled them.

## Five concurrent failure modes

### 1. Tester read-access broken on ~21 imported symbols (premature P0-21 closure)

Source: `D:\QM\mt5\T1\dwx_import\logs\hourly_2026-04-27.log` 2026-04-27 09:48.

The verify pass produced lines such as:

```
[FAIL_tail_bars]      USDCAD.DWX: ... bars_one_shot=0; bars_one_shot_err=(-2, 'Terminal: Invalid params'); bars_drift=-100,000
[FAIL_tail_mid_bars]  USDJPY.DWX: ... bars_one_shot=0; bars_one_shot_err=(-2, 'Terminal: Invalid params'); bars_drift=-100,000
[FAIL_tail_bars]      WS30.DWX:   ... bars_one_shot=0; bars_one_shot_err=(-2, 'Terminal: Invalid params'); bars_drift=-100,000
```

Sample of FAIL symbols in the log: `USDCAD`, `USDCHF`, `USDJPY`, `GBPAUD`, `GBPCAD`, `GBPCHF`, `GBPJPY`, `GBPNZD`, `GBPUSD`, `NZDCAD`, `NZDCHF`, `NZDJPY`, `NZDUSD`, `GDAXIm`, `NDXm`, `UK100`, `WS30`, `XAGUSD`, `XAUUSD`, `XNGUSD`, `XTIUSD` (all with `.DWX` suffix). The same log emitted `readiness report -> ... verdict=READY` despite these FAILs in the same run.

**Implication for `PROJECT_BACKLOG.md`:** P0-21 (Tick Data Manager + Custom Tick Data verification) was reported READY but is not actually READY. Mark as INCOMPLETE pending root-cause of `bars_one_shot=0` / `Terminal: Invalid params`. Likely areas to investigate: TDM session vs custom-symbol path mismatch (paths like `Custom\Forex\USDCAD.DWX` may have changed); MT5 build 5833 maxbars window vs sidecar tail; symbol-meta `chart_mode` / `tick_value` consistency.

### 2. Hallucinated symbol — XBRUSD.DWX

`XBRUSD.DWX` appears as line 29 of `.scratch/qua662_done_symbols.txt`. It is not in any DWX import log. It is not in `D:\QM\mt5\T1\Custom\` (or wherever else custom symbols live). Tester journal at 2026-05-01 11:40Z confirms `XBRUSD.DWX: history data begins from 2026.02.02 00:00` — meaning whatever exists for it is broker-side recent data only, not the imported tick history needed for a 2024 baseline.

Pipeline-Op fabricated the symbol into the matrix. Source of the fabrication is not yet identified — possibly a hand-edit, possibly a copy-paste from a legacy V4 list.

### 3. Symbol-name mismatch — `NDX.DWX` vs `NDXm.DWX`, `GDAXI.DWX` vs `GDAXIm.DWX`

Imported names per `hourly_2026-04-27.log` paths: `Custom\Indices\Index 3\NDXm.DWX`, `Custom\Indices\Index DAX\GDAXIm.DWX`. Pipeline-Op's matrix uses `NDX.DWX` and `GDAXI.DWX` (no `m` suffix). Tester resolves by exact symbol name; un-suffixed names hit "no history" while data exists under the suffixed names.

This is a **canonical-name discipline** failure. Pipeline-Op should have read symbol names from the import log, not from a hand-maintained list.

### 4. Wrong tester deposit (10,000 instead of 100,000) and missing fixed-risk codification

Live tester journal 2026-05-01 11:40Z: `initial deposit 10000.00 USD, leverage 1:100`.

OWNER mandate: 100,000 USD with fixed risk = 1,000 USD per trade. This had been stated multiple times in conversation but was **not codified to disk** in any tester profile, set-file, or registry. If it is not on disk, no agent uses it.

Codified now: `framework/registry/tester_defaults.json` (this commit). DL-054 makes deposit-match a hard gate.

### 5. Parser misread `automatical testing finished` as success

The line `automatical testing finished` is printed in the tester journal whether trades fired or not — including the 100 ms `no data, stop testing` exits. Pipeline-Op's parser used this line as the success signal, which is why every row of `report.csv` got `PASS` despite zero trades.

DL-054 codifies the five gates a run must pass before Pipeline-Op may write `verdict = PASS`.

## Convergence: every "PASS" row fails ≥1 gate

| Failure | Symbols affected | DL-054 gate violated |
|---|---|---|
| Tester read-access broken (`bars_one_shot=0`) | ~21 of 36 | Gate 1 (tester data access) |
| Hallucinated symbol | `XBRUSD.DWX` | Gate 1 |
| Symbol-name mismatch | `NDX.DWX`, `GDAXI.DWX` | Gate 5 (canonical name) |
| Wrong deposit (10k) | all 36 | Gate 2 (tester defaults) |
| Wrong fixed-risk source (default not RISK_FIXED) | all 36 | Gate 2 |
| Journal contains rejected lines (`cannot get history`) | most | Gate 3 (journal clean) |
| Trade count = 0 | all 36 (per Pipeline-Op's own audit) | Gate 4 (trade evidence) |

Even the symbols that were imported AND had readable data AND used the correct name still fail Gates 2 and 4.

## Actions taken by Board Advisor in this commit

1. `framework/registry/tester_defaults.json` — canonical defaults file (deposit 100k, fixed risk 1k, anti-theater rejected-lines list).
2. `decisions/DL-054_anti_theater_pass_criteria.md` — five-gate codification.
3. `decisions/REGISTRY.md` — DL-054 row.
4. `D:\QM\reports\pipeline\QM5_1003\P2\INVALIDATION_NOTICE.md` — directory-level notice.
5. `D:\QM\reports\pipeline\QM5_1003\P2\report.csv` → `report.csv.INVALID`; new stub `report.csv` points at the notice.
6. `.scratch\qua662_done_symbols.txt` → `qua662_done_symbols.txt.INVALID`; new stub explains why and points at this audit.
7. `docs\ops\QUA-662_P2_TRANCHE2..TRANCHE7.md` — top-of-file `INVALID` banner added to each.
8. This audit doc.

## Actions still required (NOT done by Board Advisor — gated)

A. **Halt the running Pipeline-Op tester loop on T1** — needs CEO directive (Board Advisor cannot kill Paperclip-managed runs).

B. **Root-cause `bars_one_shot=0` / `Terminal: Invalid params` on imported `.DWX` symbols** — needs CTO + Pipeline-Op investigation of TDM session-vs-custom-path or symbol-meta mismatch. Board Advisor offers walkthrough scripts under CLAUDE.md § "Tick Data / Custom Symbol Validation".

C. **Reopen P0-21** in `PROJECT_BACKLOG.md` — premature READY stamp. Board Advisor will edit if not already done by CEO refresh.

D. **Wire DL-054 gates into Pipeline-Op launcher** — needs CTO + Quality-Tech.

E. **Re-issue QUA-662 with halt + invalidate + re-spec** — CEO action; comment template available.

## Cross-references

- DL-038 — Seven Binding Backtest Rules
- DL-046 — Meta-work purge (anti-theater principle)
- DL-053 — CEO operating contract
- DL-054 — Anti-Theater Pass Criteria (this commit)
- `D:\QM\mt5\T1\dwx_import\logs\hourly_2026-04-27.log` — verify-FAIL evidence
- `D:\QM\reports\pipeline\QM5_1003\P2\zero_trade_audit_20260501.json` — Pipeline-Op's own zero-trade evidence

— Board Advisor, 2026-05-01.
