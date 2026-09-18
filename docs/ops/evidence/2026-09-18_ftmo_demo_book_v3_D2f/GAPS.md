# GAPS — FTMO demo book v3 (D2f) package, 2026-09-18

Ordered by what blocks deployment. G1 and G2 are hard blockers; G3 blocks a verification check;
G4-G8 are hygiene and correctness findings that do not stop the cutover.

---

## G1 (BLOCKER) — `sealed_source_hash_drift` for 21505 and 13054

`python -m tools.strategy_farm.ftmo.trial_setpath --roster <D2f> --run-name ... --dry-run` refuses
with `Refusal: sealed_source_hash_drift` at `trial_setpath.py:267`. No `sets/` is produced, so
`demo_install --package` refuses with `package_sets_manifest_missing`.

Cause: commit `9359ecaf2b` (2026-09-13, Hard Rule OWNER 2026-09-06 symbol-input rollout) appended

    ; symbol inputs (Hard Rule OWNER 2026-09-06): factory .DWX defaults; live presets carry bare broker names
    strategy_host_symbol=XAGUSD.DWX          (resp. XTIUSD.DWX)

to the canonical backtest setfiles of 21505 and 13054. The `Q10_NEWS / CONFIG_LOCKED` seals still
pin the pre-commit bytes:

| ea_id | seal `baseline_setfile_sha256` | on disk now | seal corresponds to |
|---|---|---|---|
| 21505 | `a345970c4c597963...` | `fd653cf2c8a6f7f2...` | pre-commit content, **CRLF** |
| 13054 | `d834b193a77b1d10...` | `9388a6e804380c18...` | pre-commit content, **LF** |

No strategy parameter changed — the delta is exactly those two lines. The other six sleeves pass.

**Fix:** re-take the Q10_NEWS seal for `QM5_21505 / XAGUSD.DWX` and `QM5_13054 / XTIUSD.DWX` against
the current setfile bytes, together with the recompile in G2 (a rebuilt `.ex5` is a new identity, so
one re-seal covers both). Re-running Q10 is factory/gate work — Fable or Codex, not this seat. Do
**not** revert the setfiles to silence the check: the appended line is exactly the input D2f needs.

---

## G2 (BLOCKER) — 21505 and 13054 ship a hard `.DWX` symbol gate; the `.ex5` was never rebuilt

Commit `9359ecaf2b` changed the `.mq5` and the `.set` of both EAs but **not the `.ex5`**. `git log`
on the two binary paths stops at `e550961321` (2026-08-17, 21505) and `d15464ec86` (2026-08-12,
13054), and the commit's file list contains no `.ex5`. The binaries therefore still contain:

    21505:  return (_Symbol == "XAGUSD.DWX" && _Period == PERIOD_D1);
    13054:  return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);

Independent confirmation from the live terminal: `chart09.chr` and `chart06.chr` enumerate every EA
input and **neither lists `strategy_host_symbol`**. A preset line carrying it would be inert.

Two consequences:

1. **13054 has been silently dark on the FTMO demo since 2026-09-06.** Its installed binary is the
   sealed `2e65488f...` build on a `USOIL.cash` chart; `USOIL.cash != XTIUSD.DWX`, so the host gate
   never opens. The D2f financing case counts 13054 as a contributing sleeve.
2. **21505 trades only because of an untracked alias rebuild.** The terminal runs `81386c2d...`,
   which exists nowhere in the repo (its pre-alias predecessor in
   `Experts\QM_FTMO\_pre_codex_alias_20260906_2047Z\` *is* the sealed `395c4747...`). Installing
   this package as planned replaces the alias build with the sealed one and makes 21505 dark too.

The same applies to 10706, whose terminal binary `6f290d49...` is likewise untracked — but 10706 has
no symbol gate at all (`CHART_SYMBOL_ONLY`), so restoring the sealed `eaffda6f...` is a provenance
improvement, not a functional risk.

This directly contradicts Addendum 3's *"All eight sleeves are class A: no recompile, no new
identity, no alias, no Q02 re-entry"*. It is true for six sleeves and false for 21505 and 13054.

**Fix:** recompile both EAs at HEAD (the source is already correct), re-seal (G1), then re-run the
package build. Two sleeves at 0.3125 % each = 0.625 % of the 2.34375 % book depend on it.
Owner: Codex (compile + seal), decision to proceed: Fable.

**Open question for Fable:** what did the 2026-09-06 alias rebuild actually change, and why did it
never reach the repo? Three terminal binaries (10706, 11910, 21505) and one more (1537) are
untracked builds. That is an unsealed-binary-in-production class of problem beyond this package.

---

## G3 — `ftmo_trial_pulse` is hard-bound to the incumbent eight magics

`tools/strategy_farm/ftmo_trial_pulse.py` carries

    EXPECTED_MAGICS = {107060001, 114210000, 114220004, 119100006, 130540000, 15370001, 200480000, 215050000}

i.e. the incumbent roster. After the D2f cutover, `magics_seen == 8` will be compared against a set
that shares only three members with the new book, and the post-change check (CHART_PLAN.md section 4
item 8) fails by construction. `EXPECTED_STATE_DECISION_PATH` and the 2026-09-06 comments in the
same file are also stale.

**Fix:** rebind `EXPECTED_MAGICS` to
`{104030002, 107000003, 107060001, 114220004, 130540000, 132130000, 215050000, 412190000}` and point
the decision path at the D2f receipt, in the same commit as the governor rebind (RUNBOOK step 2).
Better still: derive the set from `roster.json` so the next recomposition needs no code edit — the
same G1-class fix the roster-driven tooling already made for `trial_setpath` and `demo_install`.
The collector snapshot lookup is already cycle-agnostic (`ftmo_trial/*/trial_telemetry_raw.jsonl`),
so only the magic set needs work.

---

## G4 — `trial_setpath.py` cannot be run as a script

`python tools/strategy_farm/ftmo/trial_setpath.py --roster ... --dry-run` fails immediately with

    ImportError: attempted relative import with no known parent package

because the module uses `from .binding_hash import content_sha256` and, unlike `demo_install.py` and
`governor_rebind.py`, has no `if __package__ in {None, ""}: sys.path.insert(...)` bootstrap. Only
`python -m tools.strategy_farm.ftmo.trial_setpath` works. The invocation quoted in the deployment
brief and in several docs is the broken form.

**Fix:** add the same three-line bootstrap the sibling modules have. Low risk, Codex-sized.

---

## G5 — the FTMO alias registry is bound to the wrong account and is missing two symbols

`framework/registry/execution_symbol_aliases_v1.json`, venue `FTMO_TRIAL`, carries
`account_id 1513845506`. The live demo account is **1514536732** (`demo_install.EXPECTED_LOGIN`,
`ftmo_symbol_probe.json`, `common.ini`). The venue also has no rows for `USDCAD` or `XAGUSD`, both of
which D2f trades and both of which are present in the terminal's tick and history directories.

No impact on this package — the roster carries the venue name explicitly and neither `trial_setpath`
nor `governor_rebind` consults the alias registry on the roster path. But any tool that *does* use it
will resolve the wrong account or find nothing.

**Fix:** update `account_id`, add `USDCAD` and `XAGUSD` rows.

---

## G6 — `sealed_source_raw()` uses a raw-byte hash where the rest of the stack uses a content hash

`trial_setpath.sealed_source_raw()` compares `sha(raw)` against the seal, while every binding pin
goes through `binding_hash.content_sha256()` (LF-normalised) precisely because `core.autocrlf` gives
one committed content two digests — ticket a5cf99d0. Evidence that this is live and not theoretical:
the 21505 seal is the **CRLF** digest of its content and the 13054 seal is the **LF** digest of its
content, on the same machine, from two seals taken 5 days apart.

So even a content-identical setfile can refuse in one clone and verify in another, and G1 would have
been a partial false positive if the appended lines had not also changed the content.

**Fix (needs a decision, not a patch):** whether the Q10 baseline identity is *bytes* or *content*.
If bytes, the seal must record which line endings it sealed and the factory must normalise on write.
If content, `sealed_source_raw` should use `pin()` and existing seals need a one-off re-pin. This
touches gate evidence identity, so it is ROT-adjacent — Fable/OWNER decides, no seat changes it
unilaterally.

---

## G7 — `attached_dark` cannot fire: no placement evidence is being produced

`demo_cycle.observe_placements` counts `TM_OPEN` / `ENTRY_ACCEPTED` lines in
`MQL5\Files\QM\QM*_ea-*.log`. The read-only ledger build for this package
(`demo_cycle_observation_readonly.json`, `--dark-after-days 5`) returned
`placements_observed = EVIDENCE_MISSING` for **all eight** incumbent sleeves, `attached_dark_count: 0`,
`attached_dark_magics: []`. Twenty-five `QM5_*_ea-*.log` files exist in that directory, so the glob
matches — they simply contain no placement markers.

`flag_attached_dark` only sets `attached_dark` when `observed == 0`, and `observed` is `None` when
`placements` is empty, so the flag can never become true. The post-change check "`attached_dark`
empty after 5 trading days" therefore currently proves nothing.

This matters most because **13054 is exactly the sleeve the check exists to catch** (G2), and the
module docstring already names 13054 and 20048 as the motivating cases.

**Fix:** establish where placements are actually observable for this terminal (EA log markers, the
collector's `trial_telemetry_raw.jsonl`, or terminal journal `Trades` lines filtered by magic), and
bind `observe_placements` to that source. Until then, treat `EVIDENCE_MISSING` on day 5 as
*unverified*, never as *trading*.

---

## G8 — the incumbent book overstates realised risk; the cutover is rep-breaking

The incumbent demo reports `total_book_risk_pct 2.5` across 8 sleeves, cycle started
`2026-09-15T14:12:11Z`, state `RUNNING`, `validation_days 2.556`. With 13054 dark (G2) the realised
book has been below the reported one for the whole cycle, and 1537 XAGUSD is recorded in Addendum 3
at -149 % financed.

D2f changes the roster hash, so the demo cycle restarts at `NEW` and the 14-day representative clock
goes back to zero — expected and intended, but it means the current cycle's 2.5 days are discarded
and no D2f decision package exists before roughly 2026-10-02. Worth saying out loud in the FTMO
timeline: **the two-week demo requirement runs from the cutover, not from 2026-09-15.**

---

## Not gaps (verified clean)

- `load_binding()` passes at HEAD — Addendum 3 blocker (1), ticket a5cf99d0, is closed by
  `1279dad2a3`.
- All 8 magics are active in `framework/registry/magic_numbers.csv` with matching ea_id, slot and
  `<dxz>.DWX` symbol; `magic == ea_id*10000 + slot` holds for all 8.
- All 6 venue symbols are present in the FTMO demo's own tick and history directories.
- Repo `.ex5` sha256 equals the Q10 seal `ex5_sha256` for all 8 sleeves.
- `governor_rebind --dry-run` passes cleanly and both governor preset hashes match the copies
  installed in the terminal.
- The six derivable presets satisfy every install-time contract check (`RISK_FIXED=0`, correct
  `RISK_PERCENT` per roster row, native-calendar news mode, Friday flat at 21 broker time), and two
  of them reproduce the 2026-09-06 install byte-for-byte.
- `demo_install`'s refusal `autotrading_must_be_disabled` is correct behaviour, not a defect: the
  live terminal has `[Experts] Enabled=1` and the installer will not stage into a hot terminal.
