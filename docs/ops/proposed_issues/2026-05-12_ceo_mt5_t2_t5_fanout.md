## Proposed CEO issue — MT5 T2–T5 EA fan-out for Friday restart

**Target route:** CEO `7795b4b0` (CEO dispatches to Pipeline-Operator / DevOps).
**Drafted by:** Board Advisor 2026-05-12 — for OWNER to post via Paperclip API.
**Linked plan:** "Friday morning restart" (OWNER directive 2026-05-12).

---

### Aufgabe

Bring MT5 terminals T2–T5 to a state where the Phase Orchestrator can dispatch baseline (P2) and sweep (P3) backtests in parallel across all five factory terminals as soon as it is re-enabled on Friday. Currently only T1 has a running `terminal64.exe` and a deployed V5 EA binary; T2–T5 have terminals on disk but no V5 binaries and no running process.

### Was zu tun

1. **Inventory check on each of T2, T3, T4, T5** (factory layout `D:/QM/mt5/T<n>/`):
   - Confirm `terminal64.exe` is present and portable mode is wired (i.e., MT5 reads/writes inside the Tn folder, not roaming `AppData`).
   - Confirm `MQL5/Profiles/Tester/` exists.
   - Confirm `MQL5/Profiles/Tester/Groups/<server>_<account>.txt` exists with the correct commissions block (UTF-16 LE BOM CRLF) — see memory `reference_mt5_tester_commissions.md`.
   - Confirm tester defaults match `framework/registry/tester_defaults.json` (100k EUR deposit, 1:100 leverage, RISK_FIXED=$1000 baseline, Model 4 every-real-tick).
   - Confirm `bases/Custom/history/` is populated for all baseline symbols (or that the DWX import has run on each terminal).

2. **Deploy current V5 EA binaries** to each of T2–T5 using the existing script:
   - `framework/scripts/deploy_ea_to_all_terminals.ps1`
   - Verify SHA256 of each `.ex5` matches T1's reference copy across all four terminals.
   - Verify magic-number registry consistency (`ea_id * 10000 + slot`).

3. **Start each terminal once interactively (or via runner) to verify clean startup**:
   - Start `terminal64.exe` on T2, T3, T4, T5.
   - Confirm Strategy Tester opens, expert list shows the deployed V5 EAs.
   - Close the terminal. The Orchestrator will re-launch via `p2_baseline.py` on dispatch.

4. **Update aggregator state**:
   - After deployment, run `scripts/aggregator/standalone_aggregator_loop.py` for one cycle (or wait for the next `QM_AggregatorState_1min` fire). Verify `D:/QM/reports/state/last_check_state.json::bl_progress.T2..T5.terminal_pid` are no longer `"none"` once the orchestrator launches them.

5. **Record evidence**:
   - SHA256s of deployed `.ex5` per terminal.
   - Test-defaults snapshot (`MQL5/Profiles/Tester/Groups/<server>_<account>.txt` first 20 lines per terminal).
   - History file inventory per terminal (counts of `.hcc` under `bases/Custom/history/`).
   - CSV at `docs/ops/evidence/2026-05-13_t2_t5_fanout_ready.csv` with columns: `terminal,terminal64_present,portable_mode,tester_groups_ok,history_files_count,ea_binary_sha256,verified_at_utc`.

### Leitprinzipien

- **No T6_Live changes** — Hard Rule. T6 is OFF LIMITS for this work.
- **Read-only on `bases/`** — Hard Rule (no deletion).
- **Tester-defaults must come from the documented source** — no invented commission / swap / DST values (Hard Rule).
- **Evidence over claims** — Hard Rule. CSV must land at the path above before the Orchestrator is re-enabled.
- **Idempotent** — re-running the deploy script must be safe (it overwrites identical SHA256 to the same SHA256, no churn).

### Pfade

- Factory MT5 root: `D:/QM/mt5/T2..T5/`
- Live MT5 (DO NOT TOUCH): `C:/QM/mt5/T6_Live/`
- EA binaries to deploy: `C:/QM/repo/framework/EAs/<EA>/<EA>.ex5`
- Deploy script: `C:/QM/repo/framework/scripts/deploy_ea_to_all_terminals.ps1`
- Magic-number registry: `C:/QM/repo/framework/registry/magic_number_registry.csv`
- Tester defaults source-of-truth: `C:/QM/repo/framework/registry/tester_defaults.json`
- Evidence directory (create if missing): `C:/QM/repo/docs/ops/evidence/`
- Aggregator state: `D:/QM/reports/state/last_check_state.json`
- Aggregator script: `C:/QM/repo/scripts/aggregator/standalone_aggregator_loop.py`

### Akzeptanzkriterien

- All four CSV evidence rows for T2..T5 present, with `terminal64_present=true`, `portable_mode=true`, `tester_groups_ok=true`, `history_files_count>0`, `ea_binary_sha256` matching T1's reference.
- Aggregator `last_check_state.json` shows T2..T5 with `terminal_pid != "none"` once the orchestrator has launched at least one test on each terminal.
- No changes to T6_Live in `git status` or filesystem-diff snapshots.
- No new `.ex5` SHA256 mismatch between any two factory terminals.

### Bezug zum Friday Restart

This work, plus re-enabling `QM_Phase_Orchestrator` (currently `Disabled`, action fixed by Board Advisor 2026-05-12), plus restarting the Paperclip API (currently down on `127.0.0.1:3100`), are the three preconditions for restoring full pipeline throughput. Without this fan-out, the orchestrator will only dispatch to T1 and the existing 1-terminal bottleneck remains. The Board Advisor will not re-enable the orchestrator until this issue closes.

### Non-Goals

- No EA build (this issue does not require Development).
- No new framework code (this issue does not require CTO).
- No agent hires / pauses (OWNER-class).
- No T6 / live trading work (Hard Rule).
