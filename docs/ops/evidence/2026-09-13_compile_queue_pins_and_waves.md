# Compile queue: symbol-literal patches, source-pin drift, rollout waves (2026-09-13)

Evidence-first work log for three bounded compile-queue jobs. Read-only DB access
only (`file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`). No compile, no
terminal, no `--apply`, no enqueue was run.

---

## JOB A — patch four post-cutover EAs carrying hard-coded `.DWX` symbol literals

### Pre-patch DB gate (COMPILE_OK check, read-only)

`ea_id` is stored as the short label string (`QM5_<n>`), so the check binds strings:
`SELECT count(*) FROM work_items WHERE ea_id=? AND phase='COMPILE_EA' AND verdict='COMPILE_OK'`.

| EA | COMPILE_OK rows | other COMPILE_EA rows | decision |
|----|----|----|----|
| QM5_41374 | 0 | 1 (status=failed, verdict=COMPILE_FAIL) | PATCH |
| QM5_41389 | 0 | 1 (failed / COMPILE_FAIL) | PATCH |
| QM5_41397 | 0 | 1 (failed / COMPILE_FAIL) | PATCH |
| QM5_41399 | 0 | 1 (failed / COMPILE_FAIL) | PATCH |

None carries a `COMPILE_OK` verdict, so all four were patched. (Each has one prior
`COMPILE_FAIL` row — they are not literally "before first compile", but the gate
criterion is `COMPILE_OK`, which is absent.)

### Why the reference pattern had to be adapted

The inventory tool classes any `.DWX`/symbol literal not on an `input string` line as
`trading_logic_literal`, then grades it `WARN` if the file existed at baseline commit
`bb584c73…` (`existed_at_cutover=True`) else `FAIL`. Ground-truth runs:

- References `QM5_41113` / `QM5_41179` are **cut=True** → their
  `QM_MagicSymbolCanonical("XXXUSD.DWX")` literals in `Strategy_InputsValid` grade **WARN**
  (`severity {'ALLOW':2,'WARN':2}`), so those files pass "no FAIL".
- The four targets are **cut=False** → the *same* literal would grade **FAIL**.

So for the targets, no `.DWX` literal may remain on a non-input line — copying the
`…== QM_MagicSymbolCanonical("XXXUSD.DWX")` idiom verbatim would itself be a FAIL.
The literal-free idiom of the cited single-symbol reference `QM5_41470`
(`QM_MagicSymbolCanonical(_Symbol) == QM_MagicSymbolCanonical(<input>)`, no literal)
was used instead. Every symbol literal now lives only on an `input string` line
(default = old literal, so backtests are unchanged), classed `symbol_input_default` = ALLOW.

### Patch shape (minimal, no strategy-logic change)

Two-leg baskets (41374 XTI/XNG, 41389 & 41399 XAU/XAG): added the host-leg
`input string strategy_<host>_symbol` (foreign input already existed) with the Hard-Rule
comment; changed globals `g_leg_* = "";` fed from inputs in `OnInit` before the
`IsHostChart`/`InputsValid` gate; replaced the literal comparisons in `InputsValid` with
literal-free checks — both inputs non-empty, `QM_MagicSymbolCanonical(host) !=
QM_MagicSymbolCanonical(foreign)`, and `QM_MagicSymbolCanonical(host) ==
QM_MagicSymbolCanonical(_Symbol)`. `IsHostChart` kept exact `_Symbol == g_leg_<host>`
(matches 41113/41179).

Single-symbol (41397 WTI): added `input string strategy_symbol`; `const string g_symbol`
→ mutable `string g_symbol = "";` fed in `OnInit`; `Strategy_IsHostChart` made canonical
(`QM_MagicSymbolCanonical(_Symbol) == QM_MagicSymbolCanonical(strategy_symbol)`), matching
41470. The single-quoted `required_symbol='XTIUSD.DWX'` in a `PrintFormat` diagnostic is
matched by neither tool and was left untouched (minimal diff).

### Before → after (per EA)

| EA | lint before | lint after | inventory before | inventory after |
|----|----|----|----|----|
| QM5_41374 | FAIL, 3 violations (L60,61,172) | **OK, 0** | FAIL 3 | **0 FAIL** (ALLOW 2) |
| QM5_41389 | FAIL, 5 violations (L66,67,201,202,205) | **OK, 0** | FAIL 5 | **0 FAIL** (ALLOW 2) |
| QM5_41397 | OK, 0 (single-quoted literal) | **OK, 0** | FAIL 1 (L56) | **0 FAIL** (ALLOW 1) |
| QM5_41399 | FAIL, 5 violations (L65,66,200,201,204) | **OK, 0** | FAIL 5 | **0 FAIL** (ALLOW 2) |

Commands (per EA):
`python -X utf8 framework/scripts/lint_ea_symbol_literals.py --ea-root framework/EAs/<label>` → exit 0 / "no hardcoded .DWX symbol literals".
`python -X utf8 tools/strategy_farm/ea_symbol_literal_inventory.py --repo-root C:/QM/repo --baseline-commit bb584c73239c5bd9f7ba98d2bf5863bafa8cfe48 --ea-label <label>` → `literal_severity_counts` has no `FAIL`.

### build_gate_hardening (`--repo-root C:/QM/repo --ea-label <label>`)

All four: **0 failures / 0 failure_classes**, `matrix_valid: true`, magic-registry slots
active and set-file symbols matrix-exact. Only advisory **warnings**, all pre-existing and
unrelated to the symbol patch: `card_error: "card missing"` on D13/D14/D15 + build_symbol
checks, and `EA_CARD_LOSS_LIMIT_UNDECIDABLE` / `EA_BROKER_TIME_WINDOW_UNDECIDABLE`
(no approved Strategy Card of record; nothing guessed). Not fixed (out of scope).

Files patched:
- `framework/EAs/QM5_41374_xtixng-weffdiv-rv/QM5_41374_xtixng-weffdiv-rv.mq5`
- `framework/EAs/QM5_41389_xauxag-blockmed-rv/QM5_41389_xauxag-blockmed-rv.mq5`
- `framework/EAs/QM5_41397_wti-seas-surprise-rv/QM5_41397_wti-seas-surprise-rv.mq5`
- `framework/EAs/QM5_41399_xauxag-medret-rv/QM5_41399_xauxag-medret-rv.mq5`

---

## JOB B — what happens when a worker claims a COMPILE_EA row whose payload `mq5_sha256` differs from the current file

**Answer: (2) it REFUSES. It does not recompile-and-re-pin.**

The claim/preflight path recomputes the *current* source hash and hard-fails on drift.
`classify_candidate` (`tools/strategy_farm/compile_work_items.py:4238`) reads the live file:

```
4259    source = ea_dir / f"{canonical_label}.mq5"
4260    source_sha = sha256_file(source) if source.is_file() else None
```

and returns it as `candidate["mq5_sha256"]`. The claim handler then enforces:

```
6135        evidence["candidate_recheck"] = candidate
6136        if not candidate.get("eligible"):
6137            raise RuntimeError("CANDIDATE_RECHECK_REFUSED:" + ";".join(candidate.get("reasons") or [candidate.get("reason")]))
6138        if candidate.get("mq5_sha256") != payload.get("mq5_sha256"):
6139            raise RuntimeError("SOURCE_CHANGED_AFTER_ENQUEUE")
6140        evidence["mq5_path"] = str(candidate["mq5_path"])
6141        evidence["mq5_sha256"] = str(candidate["mq5_sha256"])
```

- The **reason class for the SHA-drift case specifically is `SOURCE_CHANGED_AFTER_ENQUEUE`**
  (line 6138-6139): current file hash ≠ payload `mq5_sha256` → `RuntimeError`, raised
  *before* MetaEditor. Nothing is recompiled; the row is not re-pinned.
- The sibling guard `CANDIDATE_RECHECK_REFUSED` (line 6137; constant
  `COMPILE_RECHECK_FAILURE_CLASS = "CANDIDATE_RECHECK_REFUSED"`, line 51) fires for other
  ineligibility from `classify_candidate` — e.g. `OPEN_COMPILE_EA_EXISTS`,
  `USABLE_CURRENT_COMPILE_VERDICT_EXISTS`, `EX5_ALREADY_PRESENT`, `MQ5_SOURCE_MISSING`.

**Job B EAs — pending rows carry the OLD hash (read-only DB):** each of QM5_41113/41123/41142
has a done `COMPILE_OK` plus a `pending` (verdict NULL) COMPILE_EA row; 41179/41189 have a
`pending` + a `failed` row. The pending rows' pinned `mq5_sha256` no longer matches the
patched source, e.g. QM5_41179 pinned `74e7f100f5d5…` vs current source `6110e1969bf0…`;
QM5_41142 pinned `1bb336bbbd3b…` vs current `bd65d86feafb…`. A worker claiming these would
raise `SOURCE_CHANGED_AFTER_ENQUEUE`.

**Governed re-issue / re-pin (no in-place repin exists):** append-only enqueue via the
library functions `enqueue_compile_eas` (`compile_work_items.py:5075`) for a fresh
source-hash-bound row, or `enqueue_recheck_successor` (`:5576`, contract
`qm.compile-ea-stale-build-binding-successor/v1`) / `enqueue_repair_successor` (`:5440`)
for a stale-bound predecessor. `compile_work_items.py` exposes no CLI; these are wrapped by
the `retry_compile_stale_build_binding.py` / `retry_compile_recheck_canary.py` tools and by
`tools/strategy_farm/session_tools/*` re-enqueue scripts (the pattern used for today's
symfix rows).

---

## JOB C — release_compile_wave.py dry-run returns release_count 0

**Selector (`inspect`, `tools/strategy_farm/release_compile_wave.py`):**

```
 97        rows = conn.execute(
 98            f"""
 99            SELECT w.id,w.ea_id,w.status,w.claimed_by,w.verdict,w.payload_json,
100                   h.hold_code,h.active,h.release_on_restart,h.created_at
101            FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
102            WHERE w.phase='COMPILE_EA' AND w.status='pending'
103              AND w.claimed_by IS NULL AND h.active=1 AND h.hold_code=?   -- COMPILE_EA_WORKER_ROLLOUT_PENDING
...
115            source = repo / "framework" / "EAs" / label / f"{label}.mq5"
116            expected_sha = str(payload.get("mq5_sha256") or "").lower()
117            actual_sha = sha256_file(source).lower() if source.is_file() else None
...
126            if not label or not expected_sha or actual_sha != expected_sha:
127                item["reason"] = "SOURCE_SHA_STALE_OR_MISSING"
128                deferred.append(item)
129            elif selectors or len(eligible) < max_items:
130                eligible.append(item)
```

`release_count = len(eligible)` (line 142).

**Why nothing is selected (verified by dry-run, `--max-items 3`, no `--apply`):**
`held_pending_count = 12`, `release_count = 0`, every row `deferred` with
`reason = "SOURCE_SHA_STALE_OR_MISSING"`. All 12 held rollout rows fail the
source-freshness check at line 126 — their on-disk `.mq5` SHA no longer equals the pinned
payload `mq5_sha256`, because the sources were patched (symbol-literal and other fixes)
after the rows were enqueued. Examples: QM5_41179 exp `74e7f100…` / act `6110e196…`;
QM5_41142 exp `1bb336bb…` / act `bd65d86f…`; QM5_41189 exp `3d0ba891…` / act `8989d43b…`;
QM5_1538, 41176, 41192, 41352, 41356, 41368, 41382, 10069 all likewise STALE.
(The "30 pending COMPILE_EA" total includes 18 rows that carry **no** active
`COMPILE_EA_WORKER_ROLLOUT_PENDING` hold, so the hold join never selects them.)

**What the orchestrator must fix — not a flag:** `--max-items N` and `--work-item-id(s)`
do **not** help: the staleness test (lines 126-128) runs *before* the `max_items`/selector
branch (line 129), so a source-stale row is deferred no matter how it is selected. The fix
is to restore source freshness — re-issue/re-pin each held COMPILE_EA row to the current
patched source SHA via the governed append-only enqueue path (Job B:
`enqueue_compile_eas` / `enqueue_recheck_successor`), so `actual_sha == payload.mq5_sha256`.
Only then does `inspect` place rows in `eligible`.

**Exact command that would release one bounded wave (once rows are source-fresh — NOT executed):**

```
python -X utf8 tools/strategy_farm/release_compile_wave.py --max-items 1 --apply
```

(The dry-run equivalent is the same command without `--apply`, which today returns
`release_count 0`.)
