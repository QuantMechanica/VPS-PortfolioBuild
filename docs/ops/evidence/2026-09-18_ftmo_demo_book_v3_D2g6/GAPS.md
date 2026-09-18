# GAPS — FTMO demo book v3 (D2g6) package, 2026-09-18

Ordered by what blocks deployment. **No gap blocks the package itself** — `trial_setpath`,
`governor_rebind` and `demo_install` all pass, and the one `demo_install` refusal is the AutoTrading
guard working as designed. G1 and G2 block **steps of the RUNBOOK**, not the package, and both are
repo edits owed by router ticket `57bfd3af`. G3–G9 are correctness and hygiene findings.

D2f's two hard blockers (G1 `sealed_source_hash_drift` for 21505/13054, G2 the `.DWX` gate in their
binaries) are **closed by roster construction**: Addendum 4 drops both sleeves. They remain open as
*repo* work under `57bfd3af`, and they are the reason the book is 1.71875 % and not 2.34375 %.

---

## G1 (blocks RUNBOOK step 8) — the launcher's contract verifier is pinned to the incumbent 11-chart profile

`tools/strategy_farm/verify_ftmo_demo_instrumentation_contract.ps1` hard-pins:

- `Assert-ExactProfileFiles` — the exact file set `chart01.chr … chart11.chr + order.wnd`;
- `$legs` — eight sleeve rows, each with chart file name, `ea_id`, slug, symbol,
  `period_type`/`period_size`, `expertmode`, slot, `risk_percent`, `risk_fixed`,
  `portfolio_weight`, preset filename, **preset sha256** and **binary sha256**;
- governor and telemetry contracts including `$governorChallengeId`, `$governorAllowedMagicsCsv`,
  `$governorEaIdsCsv` and four more sha pins;
- a blank chart11.

After the D2g6 cutover the profile is **9 charts**, MT5 renumbers the `.chr` files, six legs are gone
and four are new. The verifier exits 2.

That matters because `tools/strategy_farm/FTMO_ON.ps1` — the canonical launcher, run at logon by
scheduled task **`QM_FTMO_AtLogon`** — invokes it *before* launching and aborts on a non-zero exit
with `profile_contract_failed` (launcher exit 2, journalled to
`D:\QM\reports\state\live_launcher_events.jsonl`). **The FTMO demo terminal would not come back up
after a reboot.** This is exactly the failure mode already recorded on 2026-09-09
(`docs/ops/evidence/2026-09-09_ftmo_launcher_readiness_probe.md`, `OPEN_ITEMS_STATUS.md`
2026-09-09T18:15Z).

**Fix:** re-pin the verifier from the post-edit profile, in the same reviewed commit — the standing
SOP in `docs/ops/FTMO_M13_CAPTURE_RUNBOOK_2026-09-06.md` §2. Procedure: RUNBOOK step 7. Note the
script compares with `-ceq`, so the sha strings must be **upper-case**.

**Better fix (same shape as G2):** derive the legs from the active package roster + `sets/manifest.json`
instead of hand-pinning them, so the next recomposition needs no script edit.

---

## G2 (blocks a RUNBOOK verification, not the cutover) — `ftmo_trial_pulse.EXPECTED_MAGICS` is the incumbent eight

    EXPECTED_MAGICS = {107060001, 114210000, 114220004, 119100006, 130540000, 15370001, 200480000, 215050000}

D2g6 is `{104030002, 107000003, 107060001, 114220004, 132130000, 412190000}` — intersection **2**.
`ftmo_trial_pulse.py:492` filters every EA-log row through `if m in EXPECTED_MAGICS`, so after the
cutover:

- `expected_magics: 8`, `magics_seen: 0..2` — never 6, never 8;
- `magics_missing: [15370001, 114210000, 119100006, 130540000, 200480000, 215050000]`, permanently;
- the four new magics are invisible to `seen_magics`, `KS_DAY_ANCHOR_SET`, `KS_BOOK_TAG_SET` and the
  `SERVER_REQUEST_EVENTS` counters;
- `kill_switch_runtime_proof_warns` adds `ks_day_anchor_missing:<=2/8` / `ks_book_tag_missing:<=2/8`
  on Prague weekdays;
- `magics_missing` is a **WARN**, not an ALARM (line 948-951), so the task still exits 0.

So the pulse will sit at WARN and say nothing true about D2g6. The check "`magics_seen == 8`" from the
D2f plan is not merely wrong for six sleeves — it is **uninterpretable**, and reacting to
`magics_missing` by re-attaching a retired sleeve would be the wrong move.

`EXPECTED_STATE_DECISION_PATH` (`docs/ops/evidence/2026-09-06_ftmo_demo_governor_manifest.md`) and the
2026-09-06 comments in the same file are also stale.

**Fix (ticket `57bfd3af` item 2):** make `EXPECTED_MAGICS` roster-driven — read the active package
roster — and point the decision path at the D2g6 receipt. Land it in the RUNBOOK step 2 commit.
Until then, RUNBOOK step 6's `parse_chart_profile` readback and the `demo_cycle` ledger are the
authority on which sleeves are attached.

---

## G3 — `attached_dark` cannot fire: no placement evidence is being produced

`demo_cycle.observe_placements` counts `TM_OPEN` / `ENTRY_ACCEPTED` lines in
`MQL5\Files\QM\QM*_ea-*.log`. D2f's read-only ledger build returned
`placements_observed = EVIDENCE_MISSING` for **all eight** incumbent sleeves,
`attached_dark_count: 0`, `attached_dark_magics: []`. Twenty-five `QM5_*_ea-*.log` files exist, so
the glob matches — they contain no placement markers. `flag_attached_dark` only sets `attached_dark`
when `observed == 0`, and `observed` is `None` when `placements` is empty, so the flag can never
become true.

The day-5 check "`attached_dark` empty" therefore proves nothing. Carried forward unchanged from D2f
G7, and it matters more now: with 13054 and 21505 gone, this check's remaining job is to catch a
*new* sleeve that attaches but never places — 13213, 10700, 10403 and 41219 have never run on this
venue.

**Fix (ticket `57bfd3af` item 3):** bind `observe_placements` to a source that actually carries
placements for this terminal (EA log markers, the collector's `trial_telemetry_raw.jsonl`, or the
terminal journal filtered by magic). Until then, `EVIDENCE_MISSING` on day 5 = **unverified**, never
"trading".

---

## G4 — `trial_setpath.py` cannot be run as a script

    python tools/strategy_farm/ftmo/trial_setpath.py --roster ... --dry-run
    ImportError: attempted relative import with no known parent package

The module uses `from .binding_hash import content_sha256` and, unlike `demo_install.py` and
`governor_rebind.py`, has no `if __package__ in {None, ""}: sys.path.insert(...)` bootstrap. Only
`python -m tools.strategy_farm.ftmo.trial_setpath` works — several docs quote the broken form.

**Fix:** add the same three-line bootstrap the sibling modules have. Low risk, Codex-sized.

---

## G5 — the FTMO alias registry is bound to the wrong account and is missing USDCAD

`framework/registry/execution_symbol_aliases_v1.json`, venue `FTMO_TRIAL`, carries
`account_id 1513845506`. The live demo account is **1514536732** (`demo_install.EXPECTED_LOGIN`,
`common.ini`, `ftmo_symbol_probe.json`). The venue also has no row for `USDCAD`, which D2g6 trades and
which is present in the terminal's tick and history directories. (D2f additionally lacked XAGUSD;
that symbol leaves with 21505.)

No impact on this package — the roster carries the venue name explicitly and neither `trial_setpath`
nor `governor_rebind` consults the alias registry on the roster path. But any tool that *does* use it
resolves the wrong account or finds nothing.

**Fix:** update `account_id`, add the `USDCAD` row.

---

## G6 — 10706 ships a binary that predates its own last source fix

`framework/EAs/QM5_10706_tv-mon-ls/QM5_10706_tv-mon-ls.mq5` last changed at `2a7647ae9d`
(2026-09-13, "BE-lock wrong-side-of-market guard + correct storm root cause"), but the `.ex5` last
changed at `18d46c2bf6` (2026-08-21). **The fix was never compiled** — not into the repo binary, and
not into the terminal's untracked 2026-09-06 alias build either (dated 2026-09-06 22:42, i.e. before
the fix).

Consequence for this package: **none, and specifically no regression.** Installing the sealed
`eaffda6f…` over the alias `6f290d49…` does not lose the BE-lock fix, because neither build has it.
The sealed binary is the correct deployable identity (it is what Q10 sealed and what the Q08 stream
financed); the alias build is unsealed and untracked.

Consequence beyond this package: 10706 runs on the demo with a known, source-fixed, uncompiled defect
(the 2026-09-10 "10706 Modify-Sturm" finding). Recompiling it is a **new identity** under the
2026-08-17 stale-EX5 doctrine and would require a re-seal — i.e. exactly the treatment 21505 and 13054
are queued for under `57bfd3af`. Decide deliberately; do not let it happen as a side effect.

**Related, unchanged from D2f:** four terminal binaries (10706, 11910, 21505, 1537) are untracked
builds that exist nowhere in the repo. After D2g6 only 10706 is still in the book, and this package
replaces it with the sealed one — so the cutover *reduces* the unsealed-binary exposure from four to
zero within the live book. The class of problem (unsealed binaries reaching a live terminal) is not
closed.

---

## G7 — defect found in the reused D2f package: malformed collector preset

`docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/collector/QM_FTMO_TrialTelemetry_1514536732.set`
contains a literal **0x0C form-feed byte** where `\ftmo_trial`'s backslash-f should be two characters:

    InpOutputDir=QM<0x0C>tmo_trial\FTMO_DEMO_BOOK_V3_D2F_20260918

`demo_install.validate_sources()` compares the collector preset's parsed dict **exactly** against
`{"InpOutputDir": "QM\\ftmo_trial\\" + cycle_id, …}`, so at `--execute` time D2f would have refused
with `collector_preset_contract_mismatch` — and in fact it would have failed earlier, in
`trial_setpath.values()`, with `malformed_set_line`. D2f never reached that check because `plan()`
calls `require_target()` first and refused on AutoTrading.

Root cause: the file was written through a path that interpreted `\f` as an escape. The 2026-09-06
legacy preset is correct, so this is a D2f-build artefact, not a tooling defect.

The D2g6 preset was written byte-controlled and round-trip verified
(`9de24d3d6b3ee4c46aa3f1d7a8f0b0ff56bacb830e4f200651ebf4e2e581e88c`), and `validate_sources()` now
passes it.

**Fix:** correct or retire the D2f collector preset so it cannot be picked up by mistake. More
usefully: `demo_install` should run `validate_sources()` before `require_target()` in `plan()`, or at
least report both — a dry run that hides a package defect behind an environment gate is how this one
survived a full review.

---

## G8 — the incumbent book overstated realised risk; the two-week clock restarts

The incumbent demo reports `total_book_risk_pct 2.5` across 8 sleeves, cycle started
`2026-09-15T14:12:11Z`, `RUNNING`. With 13054 dark since 2026-09-06 the realised book has been below
the reported one for the whole cycle.

D2g6 changes the roster hash, so the demo cycle restarts at `NEW` and the representative clock goes
back to zero. Say it plainly in the FTMO timeline: **the mandatory two-week demo runs from this
cutover, not from 2026-09-15**, so no D2g6 decision package exists before roughly **2026-10-02**.
Book risk also drops 2.5 % -> **1.71875 %** (Addendum 4 chose probability of success over speed:
full-sample financed LCB 0.8839, P1 max-loss 0.0152, p50 487 bd).

---

## G9 (observation, not a defect) — terminal file mtimes moved at 2026-09-18 03:35 with no content change

`MQL5\Experts\QM_FTMO\QM_FTMO_TrialTelemetry.ex5` and
`MQL5\Profiles\Presets\QM_FTMO_M13\QM_FTMO_TrialTelemetry_1514536732.set` both carry mtime
2026-09-18 03:35 (during the D2f package build), but their **content is unchanged**: sha256
`411638a1…` and `f4da1592…` respectively, exactly the values D2f recorded as
`destination_sha256_before`. No `install_receipt.json` exists in the D2f package and no
`_pre_FTMO_DEMO_BOOK_V3_D2F_20260918` backup directory was created, so no install ran. Recorded here
so the timestamp is not mistaken for an undocumented write later.

---

## Not gaps (verified clean for D2g6)

- `trial_setpath --roster --dry-run` derives **6/6** with no refusal; all six presets are byte-identical
  to the already-verified `D2f/probe_six_sleeves/sets_probe/` outputs, and two of them reproduce the
  2026-09-06 install byte-for-byte.
- Repo `.ex5` sha256 == Q10 seal `identities.ex5_sha256` for all six; each seal's
  `q08_evidence_sha256` == the sha256 of the Q08 `aggregate.json` it names (11422's gzipped, matched on
  the decompressed bytes). `demo_install` re-checks the first leg itself.
- **Zero `.DWX` string literals** (ASCII and UTF-16LE) in all six binaries — the property 21505 and
  13054 lack.
- All 6 magics active in `framework/registry/magic_numbers.csv` with matching ea_id, slot and
  `<dxz>.DWX` symbol; `magic == ea_id*10000 + slot` for all six.
- All 4 venue symbols (USDJPY, GBPUSD, XAUUSD, USDCAD) present in the FTMO demo's own tick and history
  directories.
- Every preset satisfies the install-time contract (`RISK_FIXED=0`, roster `RISK_PERCENT`,
  `qm_news_temporal=3` / `qm_news_compliance=2` / `qm_news_stale_max_hours=336` native-calendar
  fail-closed path, Friday flat at 21 broker time). No backtest news archive reference in any preset.
- `governor_rebind --dry-run` passes; both current governor preset shas equal the copies installed in
  the terminal, so repo and terminal are in sync for QM5_13206 before the rebind. `load_binding()`
  succeeds at HEAD.
- `demo_install --dry-run` refuses **only** with `autotrading_must_be_disabled`, which is correct
  behaviour: the live terminal has `[Experts] Enabled=1` and the installer will not stage into a hot
  terminal. Every other `require_target` gate (origin, login 1514536732, server FTMO-Demo, not a
  symlink, not T_Live, not T1–T10) verified green.
