# CODEX BRIEF 2026-08-02 — FTMO research lane runner + provision receipts

**Author:** Claude. **Implementer:** Codex (Sol, effort max). **Reviewer:** Claude.
**Predecessor (APPROVED):** `docs/research/FTMO_STREAM_CAMPAIGN_DESIGN_2026-08-02.md`
— read it; its lane contract, exporter contract and receipt requirements bind
this ticket. OWNER provisioned an FTMO demo account 2026-08-02 and Claude has
already created the two portable research roots (see below).

**Hard constraints:** never touch `C:\QM\mt5\T_Live`; never enable AutoTrading
anywhere; never contact the FTMO *live/trial* data directory beyond the
already-completed account-state copy; no credentials or passwords in the repo,
in logs, or in evidence documents (the demo login number may be referenced, a
password never); no Q-pipeline verdicts from this lane; no enqueue (Claude
enqueues after reviewing your receipts). Factory T1-T10 keeps running — the
lane must never take more than 2 concurrent slots' worth of host resources.

## Already done (verify, do not redo)

- `D:\QM\mt5\FTMO_STREAM1` and `D:\QM\mt5\FTMO_STREAM2`: portable copies of the
  FTMO Global Markets MT5 installation (~322 MB each; `terminal64.exe`,
  `metatester64.exe`, `Config`, empty `Bases`).
- Both `Config` dirs carry the OWNER-provisioned demo account state
  (`accounts.dat`, `servers.dat`, `common.ini` with `Login=1514165262`,
  `Server=FTMO-Demo`) copied from the installation's data directory.
- Neither root has been launched. `Bases` is empty: **no native history yet.**

## Build

1. **Provision receipts** (`qm.ftmo-lane-provision-receipt/v1`, one per lane,
   under `D:\QM\reports\state\`): prove every point the approved design demands
   — dedicated research root (not AppData/live-trial, not T_Live), server
   FTMO-Demo + company contains FTMO, AutoTrading/Experts disabled, terminal
   EXE + config hashes, portable-mode assertion, and the capacity permit
   (max 2 lanes, ≥8 of 10 normal factory slots stay free). Receipts must NOT
   contain secrets. Where a claim cannot be proven yet (native history), the
   receipt must say so explicitly rather than assert it.
2. **History bootstrap — PREMISE CORRECTED 2026-08-02 (OWNER finding, verified).**
   FTMO serves **real ticks only for roughly the last week**; deeper history is
   M1 bars. Verified read-only in the installation's data directory: **zero
   `.tkc` tick caches**, but per-year `.hcc` M1 history (2024/2025/2026 present
   after first connect). **Model-4 (real-tick) multi-year campaign runs are
   therefore impossible on FTMO** — do not attempt them, and do not let the
   runner silently fall back to a different model.
   Consequences you must implement:
   - the receipt must record, per symbol, the actual real-tick coverage window
     and the M1 coverage window **separately**, and must never assert real-tick
     coverage it cannot prove;
   - the runner takes an explicit execution-model parameter and stamps it into
     every artifact; an M1-modelled run must carry an unambiguous evidence
     class (e.g. `FTMO_M1_MODELLED`) that is **never** presented as tick-level
     venue execution;
   - the exporter/evaluator contract must refuse to merge the two classes into
     one stream without disclosure.
   **Serialize the bootstrap across the two lanes** — both are logged into the
   same demo account, so simultaneous first connections can disconnect each
   other. Document that constraint in the runner.
3. **Lane runner** (`tools/strategy_farm/ftmo_lane_runner.py` or the shape you
   justify): claims only `FTMO_STREAM1/2`, binds terminal EXE + server profile
   + EX5 + set file + tester INI + report + Q08 trade delta + equity-log delta
   by hash, harvests into an isolated evidence root, hands off to
   `ftmo_daily_net_export.py`, and never writes a Q-pipeline verdict. Its rows
   must be invisible to the ordinary T1-T10 workers and to survivor-port
   collection.
4. **Symbol rebinding (OWNER-surfaced 2026-08-02, load-bearing).** The FTMO
   account does NOT carry the `.DWX` symbols — that is by design (they are
   Darwinex custom symbols; FTMO natives are `XAUUSD` and `GER40.cash`). Wave-1
   sleeves are bound to `.DWX` in their set files, and the EAs run a
   single-symbol guard (`SYMBOL_GUARD_INIT`). You must therefore:
   - derive FTMO-symbol-bound set files for each wave-1 sleeve from the sealed
     `.DWX` set (identical strategy parameters; only the symbol/host-symbol
     binding changes), hash-bind both the source and derived set in the receipt,
     and never mutate the sealed originals;
   - prove the EA initializes on the native symbol (symbol guard, digits,
     contract size, tick value) BEFORE any campaign run — a failing guard is a
     stop, not something to work around by weakening the guard;
   - state explicitly in the evidence that the derived set is a venue rebinding
     of the same strategy, so the evaluator's sleeve identity stays traceable to
     the sealed original.
   If a sleeve cannot be faithfully rebound (e.g. index contract semantics
   differ materially between `GDAXI.DWX` and `GER40.cash`), report it as an
   exclusion with reasons instead of forcing it.
5. **Tests** for receipt refusal paths (wrong server, AutoTrading enabled,
   live-dir root, missing history, capacity violation), symbol-rebinding
   provenance, and runner binding.

## Handback

Router task → REVIEW with the receipts + an evidence doc containing verbatim
test output, the receipt paths/hashes, and the exact wave-1 enqueue commands
for Claude (five sealed sleeves per the campaign design). State plainly what is
still unproven.
