#!/usr/bin/env python3
"""Weekly book-evolution ceremony runner (Phase H, OWNER-DEC-CBE-20260915).

Deterministic weekly recomposition of the two production books, driven end to end
from the frozen Friday evidence cut (directive sections 6, 61, 64, 68H, 70; canonical
model ``docs/ops/CONTINUOUS_BOOK_EVOLUTION.md`` section 7):

    friday-cut          freeze both venues + the supporting read-models into an
                        immutable, hash-pinned weekly cut; mark it CLOSED.
    saturday-analysis   evaluate both venues FROM THE FROZEN SNAPSHOTS ONLY, then
                        run a cross-vendor critique of each evidence.md (honest
                        fallback, never blocks on quota).
    sunday-recommendation   build the OWNER decision package answering the section 9
                        questions + the section 72 executive block; enqueue at most
                        one OWNER decision card per venue that proposes CHANGE
                        (idempotent); mirror to the Vault.
    runtime-verify      after OWNER action, READ-ONLY check that the live T_Live
                        profile and the FTMO demo roster match the accepted package.
    status              summarise the current week / cut.

Boundaries (never crossed here): no farm-DB write, no ``terminal64`` start, no live
deployment, no AutoTrading toggle, no FTMO purchase, no gate/verdict change, no
evidence rewrite. The engine is a pure function of the frozen inputs; every subcommand
is idempotent; ``friday-cut`` refuses to overwrite a CLOSED cut (``--force-new-cut``
mints a NEW cut id, never overwrites). The weekly default outcome is KEEP.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

_HERE = Path(__file__).resolve()
_FARM_ROOT = _HERE.parent
_REPO_ROOT = _HERE.parents[2]
for _p in (str(_REPO_ROOT), str(_FARM_ROOT)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
BOOK_EVOLUTION_ROOT = Path(r"D:\QM\reports\book_evolution")
STATE_DIR = Path(r"D:\QM\reports\state")
LOG_PATH = Path(r"D:\QM\strategy_farm\logs\book_evolution.log")

CUT_MANIFEST_SCHEMA = "qm.book-evolution-cut/v1"
CROSS_REVIEW_SCHEMA = "qm.book-evolution-cross-review/v1"
VERIFY_SCHEMA = "qm.book-evolution-runtime-verify/v1"
STATUS_SCHEMA = "qm.book-evolution-status/v1"

VENUES = ("dxz", "ftmo")

# Supporting read-models frozen into the cut so the weekend analysis + the Sunday
# package are reproducible from the frozen inputs alone (section 70).
STATE_INPUTS = (
    "ftmo_demo_cycle.json",
    "ftmo_challenge_readiness.json",
    "research_state.json",
    "factory_bottleneck.json",
    "kimi_quota_state.json",
    "book_evolution_health.json",
)

# Outcomes that mean "nothing to hand OWNER as a change".
KEEP_OUTCOMES = frozenset({"KEEP", "NO_VALID_CHANGE", "CONTINUE_OBSERVATION"})

# Friday-close cut instant: Friday 21:15 UTC. NY close is 22:00 CET / 21:00 CEST; the
# scheduled task fires 23:15 local (Fri) after close incl. DST slack. Using a fixed
# per-week instant makes the cut deterministic and reproducible.
CUT_HOUR_UTC = 21
CUT_MINUTE_UTC = 15


class BookEvolutionError(RuntimeError):
    """A ceremony precondition or invariant failed."""


# ---------------------------------------------------------------------------
# Time / week helpers
# ---------------------------------------------------------------------------
def iso_week_of(day: dt.date) -> str:
    y, w, _d = day.isocalendar()
    return f"{y}-W{w:02d}"


def friday_close_instant(iso_week: str) -> dt.datetime:
    """The canonical Friday market-close cut instant for an ISO week (UTC)."""
    year_s, week_s = iso_week.split("-W")
    friday = dt.date.fromisocalendar(int(year_s), int(week_s), 5)  # isoweekday 5 == Friday
    return dt.datetime(friday.year, friday.month, friday.day, CUT_HOUR_UTC, CUT_MINUTE_UTC, tzinfo=dt.UTC)


def _now() -> dt.datetime:
    return dt.datetime.now(tz=dt.UTC)


# ---------------------------------------------------------------------------
# Small IO helpers
# ---------------------------------------------------------------------------
def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        return json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def log(message: str, *, log_path: Path = LOG_PATH) -> None:
    line = f"{_now().isoformat()} book_evolution_runner {message}"
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass  # logging must never break the ceremony


def _git_commit() -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(_REPO_ROOT), "rev-parse", "HEAD"],
            capture_output=True, text=True, timeout=15, check=False,
        )
        return out.stdout.strip() or "UNKNOWN"
    except Exception:  # noqa: BLE001
        return "UNKNOWN"


# ---------------------------------------------------------------------------
# Path layout (one cut is a fully self-contained directory)
# ---------------------------------------------------------------------------
def week_dir(root: Path, iso_week: str) -> Path:
    return Path(root) / iso_week


def cut_dir(root: Path, iso_week: str, cut_id: str) -> Path:
    return week_dir(root, iso_week) / "cuts" / cut_id


def _snapshot_dir(cut: Path, venue: str) -> Path:
    return cut / "snapshot" / venue


def _analysis_root(cut: Path) -> Path:
    return cut / "analysis"


def _eval_dir(cut: Path, iso_week: str, venue: str) -> Path:
    # recompose.evaluate writes evaluation.json/evidence.md under <root>/<iso_week>/<venue>.
    return _analysis_root(cut) / iso_week / venue


def _read_model_path(cut: Path, venue: str) -> Path:
    return _analysis_root(cut) / f"{venue}_read_model.json"


def _cross_review_path(cut: Path, venue: str) -> Path:
    return _analysis_root(cut) / f"{venue}_cross_review.json"


def _active_pointer(root: Path, iso_week: str) -> Path:
    return week_dir(root, iso_week) / "active_cut.json"


def resolve_cut_id(root: Path, iso_week: str, cut_id: str | None) -> str:
    if cut_id:
        return str(cut_id)
    pointer = _read_json(_active_pointer(root, iso_week))
    if pointer and pointer.get("cut_id"):
        return str(pointer["cut_id"])
    return "c1"


def _next_free_cut_id(root: Path, iso_week: str) -> str:
    n = 1
    while cut_dir(root, iso_week, f"c{n}").exists():
        n += 1
    return f"c{n}"


# ---------------------------------------------------------------------------
# Default lazy hooks (injectable for tests)
# ---------------------------------------------------------------------------
def _default_freeze():
    from portfolio.recompose import recompose as rc  # noqa: PLC0415
    return rc.freeze


def _default_evaluate():
    from portfolio.recompose import recompose as rc  # noqa: PLC0415
    return rc.evaluate


def _default_chain():
    from tools.strategy_farm import agent_chain  # noqa: PLC0415
    return agent_chain.run_chain


def _default_upsert():
    from tools.strategy_farm import owner_decision_store  # noqa: PLC0415
    return owner_decision_store.upsert_open_item


def _default_state_builds() -> list[dict[str, Any]]:
    """Commands that refresh the supporting read-models before the freeze copy."""
    py = sys.executable
    return [
        {"name": "ftmo_demo_cycle", "argv": [py, "-X", "utf8", "-m", "tools.strategy_farm.ftmo.demo_cycle", "build"]},
        {"name": "ftmo_challenge_readiness", "argv": [py, "-X", "utf8", "-m", "tools.strategy_farm.ftmo.challenge_readiness", "build"]},
        {"name": "research_state", "argv": [py, "-X", "utf8", str(_FARM_ROOT / "research" / "research_state_readmodel.py")]},
        # factory_bottleneck build also writes book_evolution_health.json (unless --no-health).
        {"name": "factory_bottleneck", "argv": [py, "-X", "utf8", str(_FARM_ROOT / "factory_bottleneck_readmodel.py"), "build"]},
    ]


def _run_state_builds(builds: Sequence[Mapping[str, Any]] | None) -> list[dict[str, Any]]:
    if builds is None:
        builds = _default_state_builds()
    results: list[dict[str, Any]] = []
    for spec in builds:
        name = spec["name"]
        argv = list(spec["argv"])
        try:
            proc = subprocess.run(
                argv, capture_output=True, text=True, timeout=int(spec.get("timeout", 300)),
                cwd=str(_REPO_ROOT), check=False,
            )
            status = "OK" if proc.returncode == 0 else f"EXIT_{proc.returncode}"
            results.append({
                "name": name, "status": status, "returncode": proc.returncode,
                "cmd": " ".join(argv), "stderr_tail": (proc.stderr or "").strip()[-400:],
            })
        except Exception as exc:  # noqa: BLE001 - a missing terminal/import must not wedge the cut
            results.append({"name": name, "status": "ERROR", "cmd": " ".join(argv), "error": str(exc)[:400]})
        log(f"state_build {name} -> {results[-1]['status']}")
    return results


# ---------------------------------------------------------------------------
# friday-cut
# ---------------------------------------------------------------------------
def friday_cut(
    *,
    iso_week: str | None = None,
    cut_id: str | None = None,
    root: Path = BOOK_EVOLUTION_ROOT,
    as_of: dt.datetime | None = None,
    seed: int | None = None,
    force_new_cut: bool = False,
    freeze_fn: Callable[..., Mapping[str, Any]] | None = None,
    state_builds: Sequence[Mapping[str, Any]] | None = None,
    run_state_builds: bool = True,
    state_dir: Path = STATE_DIR,
) -> dict[str, Any]:
    """Freeze both venues + supporting read-models into an immutable CLOSED cut."""
    root = Path(root)
    week = iso_week or iso_week_of(_now().date())
    as_of = as_of or friday_close_instant(week)
    if as_of.tzinfo is None:
        as_of = as_of.replace(tzinfo=dt.UTC)
    seed = int(as_of.strftime("%Y%m%d")) if seed is None else int(seed)
    freeze_fn = freeze_fn or _default_freeze()

    # Resolve the cut id + the refuse-overwrite rule.
    if force_new_cut:
        resolved = cut_id or _next_free_cut_id(root, week)
    else:
        resolved = cut_id or "c1"
    cut = cut_dir(root, week, resolved)
    manifest_path = cut / "cut_manifest.json"
    if manifest_path.is_file():
        existing = _read_json(manifest_path) or {}
        if str(existing.get("status")) == "CLOSED" and not force_new_cut:
            raise BookEvolutionError(
                f"cut {resolved!r} for {week} is already CLOSED at {manifest_path}; "
                "re-run is refused. Use --force-new-cut to mint a NEW cut id (never overwrites)."
            )
        if force_new_cut and str(existing.get("status")) == "CLOSED":
            resolved = _next_free_cut_id(root, week)
            cut = cut_dir(root, week, resolved)
            manifest_path = cut / "cut_manifest.json"

    log(f"friday-cut start week={week} cut={resolved} as_of={as_of.isoformat()} seed={seed}")
    cut.mkdir(parents=True, exist_ok=True)

    # 1) refresh + 2) freeze the supporting read-models.
    build_results = _run_state_builds(state_builds) if run_state_builds else []
    inputs_dir = cut / "inputs"
    inputs_dir.mkdir(parents=True, exist_ok=True)
    input_records: list[dict[str, Any]] = []
    for name in STATE_INPUTS:
        src = Path(state_dir) / name
        if src.is_file():
            dest = inputs_dir / name
            shutil.copyfile(src, dest)
            input_records.append({"name": name, "status": "PRESENT", "sha256": _sha256_file(dest),
                                  "source_path": str(src), "size_bytes": dest.stat().st_size})
        else:
            input_records.append({"name": name, "status": "EVIDENCE_MISSING", "source_path": str(src)})

    # 3) freeze both venue snapshots.
    venue_records: dict[str, Any] = {}
    for venue in VENUES:
        snap = _snapshot_dir(cut, venue)
        snap.mkdir(parents=True, exist_ok=True)
        vm = freeze_fn(venue, snap, as_of=as_of, seed=seed)
        snap_manifest = snap / "manifest.json"
        venue_records[venue] = {
            "snapshot_dir": str(snap),
            "snapshot_manifest_sha256": _sha256_file(snap_manifest) if snap_manifest.is_file() else None,
            "qualified_pool_count": vm["qualified_pool"]["count"],
            "streams_present": vm["streams"]["count_present"],
            "streams_missing": vm["streams"]["count_missing"],
            "incumbent_labels": [i.get("label") for i in vm.get("incumbents", [])],
        }
        log(f"friday-cut froze {venue}: pool={vm['qualified_pool']['count']} "
            f"streams={vm['streams']['count_present']}/{vm['streams']['count_missing']}")

    # 4) immutable, hash-pinned CLOSED cut manifest.
    manifest = {
        "schema": CUT_MANIFEST_SCHEMA,
        "status": "CLOSED",
        "iso_week": week,
        "cut_id": resolved,
        "frozen_at_utc": as_of.isoformat(),
        "closed_at_utc": as_of.isoformat(),
        "generated_at_utc": as_of.isoformat(),
        "seed": seed,
        "git_commit": _git_commit(),
        "root": str(root),
        "cut_dir": str(cut),
        "venues": venue_records,
        "supporting_inputs": input_records,
        "state_build_results": build_results,
        "boundaries": (
            "no farm-DB write; no terminal64; no deployment; no AutoTrading; no FTMO purchase; "
            "reproducible from frozen inputs (OWNER-DEC-CBE-20260915 section 70)"
        ),
    }
    _write_json(manifest_path, manifest)
    # 5) active-cut pointer (the canonical cut the weekend commands operate on).
    _write_json(_active_pointer(root, week), {"cut_id": resolved, "iso_week": week,
                                              "closed_at_utc": as_of.isoformat()})
    log(f"friday-cut CLOSED week={week} cut={resolved} manifest={manifest_path}")
    return manifest


# ---------------------------------------------------------------------------
# saturday-analysis
# ---------------------------------------------------------------------------
def _assert_closed_cut(cut: Path) -> dict[str, Any]:
    manifest = _read_json(cut / "cut_manifest.json")
    if not manifest or str(manifest.get("status")) != "CLOSED":
        raise BookEvolutionError(f"no CLOSED cut at {cut}; run friday-cut first")
    return manifest


def _extract_cross_vendor(receipt: Mapping[str, Any]) -> tuple[bool | None, dict[str, Any]]:
    plan = receipt.get("plan") or {}
    critic = plan.get("critic") or {}
    cross = critic.get("cross_vendor")
    seat = {"vendor": critic.get("vendor"), "model": critic.get("model")}
    return (bool(cross) if cross is not None else None), seat


def _critic_verdict_pointer(receipt: Mapping[str, Any]) -> str:
    for stage in receipt.get("stages") or []:
        if stage.get("role") == "critic" and stage.get("artifact_path"):
            return str(stage["artifact_path"])
    return "NOT_EVALUATED"


def saturday_analysis(
    *,
    iso_week: str | None = None,
    cut_id: str | None = None,
    root: Path = BOOK_EVOLUTION_ROOT,
    evaluate_fn: Callable[..., Mapping[str, Any]] | None = None,
    chain_fn: Callable[..., Mapping[str, Any]] | None = None,
    cross_review_apply: bool = True,
) -> dict[str, Any]:
    """Evaluate both venues from the frozen snapshots + cross-review each evidence.md."""
    root = Path(root)
    week = iso_week or iso_week_of(_now().date())
    cid = resolve_cut_id(root, week, cut_id)
    cut = cut_dir(root, week, cid)
    manifest = _assert_closed_cut(cut)
    frozen_at = manifest["frozen_at_utc"]
    evaluate_fn = evaluate_fn or _default_evaluate()

    log(f"saturday-analysis start week={week} cut={cid}")
    result: dict[str, Any] = {
        "schema": "qm.book-evolution-analysis/v1",
        "iso_week": week, "cut_id": cid, "generated_at_utc": frozen_at,
        "venues": {},
    }
    for venue in VENUES:
        snap = _snapshot_dir(cut, venue)
        rm_path = _read_model_path(cut, venue)
        read_model = evaluate_fn(
            venue, snap, rm_path, book_evolution_root=_analysis_root(cut),
        )
        eval_dir = _eval_dir(cut, week, venue)
        evidence_md = eval_dir / "evidence.md"
        outcome = (read_model.get("proposal") or {}).get("outcome")
        # Cross-vendor critique of the evidence.md (honest fallback; never blocks on quota).
        cross = _cross_review(
            venue=venue, iso_week=week, cut_id=cid, cut=cut, evidence_md=evidence_md,
            read_model_path=rm_path, frozen_at=frozen_at, chain_fn=chain_fn, apply=cross_review_apply,
        )
        result["venues"][venue] = {
            "outcome": outcome,
            "owner_action": read_model.get("owner_action"),
            "read_model_path": str(rm_path),
            "evaluation_path": str(eval_dir / "evaluation.json"),
            "evidence_path": str(evidence_md),
            "cross_review_path": str(_cross_review_path(cut, venue)),
            "cross_vendor": cross.get("cross_vendor"),
            "cross_review_status": cross.get("chain_status"),
        }
        log(f"saturday-analysis {venue}: outcome={outcome} cross_vendor={cross.get('cross_vendor')} "
            f"chain={cross.get('chain_status')}")
    _write_json(cut / "analysis_index.json", result)
    return result


def _cross_review(
    *,
    venue: str,
    iso_week: str,
    cut_id: str,
    cut: Path,
    evidence_md: Path,
    read_model_path: Path,
    frozen_at: str,
    chain_fn: Callable[..., Mapping[str, Any]] | None,
    apply: bool,
) -> dict[str, Any]:
    out_path = _cross_review_path(cut, venue)
    record: dict[str, Any] = {
        "schema": CROSS_REVIEW_SCHEMA,
        "venue": venue, "iso_week": iso_week, "cut_id": cut_id,
        "generated_at_utc": frozen_at,
        "evidence_path": str(evidence_md),
        "cross_vendor": None,
        "critic_seat": None,
        "critic_verdict_path": "NOT_EVALUATED",
        "chain_status": "not_run",
        "blocked_on_quota": False,
        "reason": None,
    }
    chain_fn = chain_fn or _default_chain()
    spec = {
        "chain_id": f"book-evolution-{iso_week}-{venue}-{cut_id}",
        "kind": "book_evolution_cross_review",
        "language": "English",
        "task": (
            f"Cross-vendor critique of the weekly book-evolution evidence for {venue.upper()} "
            f"({iso_week}). Check the KEEP/CHANGE conclusion against the metrics, materiality and "
            f"risk diagnostics in the evidence; flag any unsupported claim. Read-only; do not "
            f"rewrite verdicts or the repo."
        ),
        "existing_artifact": {"path": str(evidence_md), "vendor": "claude", "model": "orchestrator"},
        "input_paths": [str(evidence_md), str(read_model_path)],
        "out_dir": str(cut / "chain" / venue),
        "allow_agy": True,
    }
    try:
        receipt = chain_fn(spec, apply=apply)
        status = str(receipt.get("status"))
        record["chain_status"] = status
        if status == "gated":
            record["reason"] = receipt.get("reason")
            record["blocked_on_quota"] = True
        else:
            cross, seat = _extract_cross_vendor(receipt)
            record["cross_vendor"] = cross
            record["critic_seat"] = seat
            record["critic_verdict_path"] = _critic_verdict_pointer(receipt)
        record["receipt_path"] = receipt.get("receipt_path") or str(Path(spec["out_dir"]) / "chain_receipt.json")
    except Exception as exc:  # noqa: BLE001 - the ceremony never blocks on the critic chain
        record["chain_status"] = "error"
        record["reason"] = str(exc)[:400]
    _write_json(out_path, record)
    return record


# ---------------------------------------------------------------------------
# sunday-recommendation
# ---------------------------------------------------------------------------
def _dry_run_artifact_commands(venue: str, iso_week: str) -> list[str]:
    """Technical-artifact preparation commands OWNER/orchestrator would run for a CHANGE.

    Emitted as DRY-RUN commands only — this runner NEVER executes them (live deployment,
    AutoTrading and any purchase remain OWNER-only).
    """
    if venue == "dxz":
        return [
            "# DXZ change -> stage risk presets + rebuild the T_Live book profile (DRY-RUN; never executed here):",
            "python -X utf8 tools/strategy_farm/portfolio/stage_tlive_presets_risk.py --help  # prepare per-sleeve RISK_PERCENT presets",
            "python -X utf8 tools/strategy_farm/build_tlive_book_profile.py build "
            "--manifest <staged_manifest.json> --staging D:/QM/strategy_farm/tlive_staging "
            "--name DarwinexZero_Book2_LiveOps  # (omit --apply for dry-run)",
            "python -X utf8 tools/strategy_farm/tlive_book_cutover.py plan  # read-only preflight of the cutover",
            "# OWNER alone approves the manifest in writing and flips AutoTrading on T_Live.",
        ]
    return [
        "# FTMO change -> refresh the demo roster / readiness (DRY-RUN; never executed here):",
        "python -X utf8 -m tools.strategy_farm.ftmo.demo_cycle build",
        "python -X utf8 -m tools.strategy_farm.ftmo.challenge_readiness build",
        "# A paid FTMO Challenge purchase is OWNER-only and never automated.",
    ]


def _section9_answers(venue: str, read_model: Mapping[str, Any]) -> list[str]:
    proposal = read_model.get("proposal") or {}
    outcome = proposal.get("outcome")
    changes = proposal.get("changes") or []
    materiality = proposal.get("materiality") or {}
    expected = proposal.get("expected_metrics") or {}
    lines = [
        f"- **What exactly changes:** {outcome} — {json.dumps(changes) if changes else 'no roster change'}.",
        f"- **What evidence changed:** frozen weekly cut evidence for {venue.upper()} "
        f"(read-model `{read_model.get('schema')}`, week `{read_model.get('iso_week')}`).",
        f"- **What the challenger contributes / which incumbent is displaced:** see `changes` above; "
        f"marginal contribution in the materiality factors.",
        f"- **What improves at portfolio level:** expected metrics `{json.dumps(expected)}`.",
        f"- **What could become worse:** operational risk `{json.dumps(proposal.get('operational_risk'))}`.",
        f"- **Is the improvement material:** `{materiality.get('material')}` "
        f"(reasons `{json.dumps(materiality.get('reasons'))}`).",
        f"- **Confidence:** `{json.dumps(proposal.get('confidence'))}`.",
        f"- **Operational risk:** `{json.dumps(proposal.get('operational_risk'))}`.",
    ]
    return lines


def _executive_block(inputs_dir: Path, dxz_rm: Mapping[str, Any] | None, ftmo_rm: Mapping[str, Any] | None) -> str:
    readiness = _read_json(inputs_dir / "ftmo_challenge_readiness.json") or {}
    demo = _read_json(inputs_dir / "ftmo_demo_cycle.json") or {}
    research = _read_json(inputs_dir / "research_state.json") or {}
    bottleneck = _read_json(inputs_dir / "factory_bottleneck.json") or {}
    kimi = _read_json(inputs_dir / "kimi_quota_state.json") or {}

    def g(d: Mapping[str, Any] | None, *keys, default="EVIDENCE_MISSING"):
        cur: Any = d
        for k in keys:
            if not isinstance(cur, Mapping) or k not in cur:
                return default
            cur = cur[k]
        return cur

    dxz_prop = (dxz_rm or {}).get("proposal") or {}
    ftmo_prop = (ftmo_rm or {}).get("proposal") or {}
    dxz_inc = (dxz_rm or {}).get("incumbent") or {}
    rs_counts = research.get("counts") or {}
    hyps = research.get("hypotheses") if isinstance(research.get("hypotheses"), Mapping) else {}
    bottls = bottleneck.get("bottlenecks") or []
    top_bottleneck = bottls[0] if bottls else "EVIDENCE_MISSING"

    lines = [
        "## Executive OWNER report (directive section 72)",
        "",
        "### DXZ",
        f"- What is live: incumbent `{dxz_inc.get('label')}` — {dxz_inc.get('sleeve_count', 'EVIDENCE_MISSING')} sleeves "
        f"(total risk `{dxz_inc.get('total_risk_pct')}`%).",
        f"- Is there a better book: proposed outcome `{dxz_prop.get('outcome')}` "
        f"(material `{(dxz_prop.get('materiality') or {}).get('material')}`).",
        f"- What exactly should change: {json.dumps(dxz_prop.get('changes') or []) or 'nothing'}.",
        f"- Why / expected benefit: expected metrics `{json.dumps(dxz_prop.get('expected_metrics') or {})}`.",
        f"- Main risk: `{dxz_prop.get('operational_risk')}`.",
        f"- OWNER action: `{(dxz_rm or {}).get('owner_action')}`.",
        "",
        "### FTMO",
        f"- What is running on Demo: {g(demo, 'sleeve_count')} sleeves, roster `{g(demo, 'roster_hash')[:12] if isinstance(g(demo,'roster_hash'), str) else g(demo,'roster_hash')}`, "
        f"total risk `{g(demo, 'total_book_risk_pct')}`%.",
        f"- How representative is the Demo: representative=`{g(demo, 'representative')}`, "
        f"validation `{g(demo, 'validation_days')}/{g(demo, 'validation_min_days')}` days, state `{g(demo, 'state')}`.",
        f"- How close to rationally buying the 100k 2-Step: readiness `{g(readiness, 'recommendation')}` "
        f"({g(readiness, 'rationale')}).",
        f"- Strongest remaining failure risk: `{g(readiness, 'strongest_failure_mode')}`.",
        f"- Would Fable spend the Challenge fee TODAY: `{g(readiness, 'would_fable_buy_today')}`.",
        f"- FTMO weekly outcome: `{ftmo_prop.get('outcome')}` (purchase is OWNER-only, never automated).",
        "",
        "### RESEARCH",
        f"- Hypotheses: new `{g(hyps, 'new')}` · preregistered `{g(hyps, 'preregistered')}` · "
        f"mechanized/survived `{g(hyps, 'mechanized')}` · under criticism `{g(hyps, 'under_criticism')}` · "
        f"falsified/failed `{g(hyps, 'falsified')}` (campaigns `{rs_counts.get('campaigns', 'EVIDENCE_MISSING')}`).",
        f"- Most important failed lesson: {research.get('most_important_failed_lesson', 'EVIDENCE_MISSING')}.",
        f"- Kimi campaigns: `{json.dumps(research.get('kimi_campaigns'))[:300] if research.get('kimi_campaigns') is not None else 'EVIDENCE_MISSING'}`.",
        "",
        "### KIMI",
        f"- Subscription fetch status: `{g(kimi, 'fetch_status')}` (source `{g(kimi, 'source')}`).",
        f"- Monthly quota: `{json.dumps(g(kimi, 'monthly'))}`.",
        f"- 5h quota: `{json.dumps(g(kimi, 'rolling_5h'))}`; 7d quota: `{json.dumps(g(kimi, 'rolling_7d'))}`.",
        f"- Reason to conserve: `{g(kimi, 'plan_status')}` / extra_quota_active=`{g(kimi, 'extra_quota_active')}`.",
        "",
        "### FACTORY",
        f"- Highest-value current bottleneck: `{json.dumps(top_bottleneck)[:300]}`.",
        f"- Frontier: `{json.dumps(bottleneck.get('frontier'))[:300] if bottleneck.get('frontier') is not None else 'EVIDENCE_MISSING'}`.",
        f"- Most costly process rule: `{json.dumps(bottleneck.get('degraded_reasons'))[:200] if bottleneck.get('degraded_reasons') else 'EVIDENCE_MISSING'}`.",
    ]
    return "\n".join(lines)


def _owner_card(venue: str, iso_week: str, read_model: Mapping[str, Any], package_rel: str) -> dict[str, Any]:
    proposal = read_model.get("proposal") or {}
    outcome = proposal.get("outcome")
    materiality = proposal.get("materiality") or {}
    card_id = f"BOOK-EVOLUTION-{iso_week.upper()}-{venue.upper()}"
    question = (
        f"Weekly book recomposition {iso_week} ({venue.upper()}): apply the proposed {outcome}? "
        f"(deterministic engine + cross-review; live deployment / AutoTrading remain OWNER-only)"
    )
    recommendation = read_model.get("recommendation_text") or (
        f"Review the proposed {outcome}; material={materiality.get('material')}."
    )
    yes_effect = (
        f"Reserve ONE Claude-lane task to PREPARE the {venue.upper()} change artifacts "
        f"(setfiles/manifests/profile as dry-run). No live change, no AutoTrading, no purchase "
        f"is authorized by this card; those remain a separate OWNER act."
    )
    no_effect = (
        f"KEEP the current {venue.upper()} book unchanged this week; re-evaluate at the next "
        f"weekly recomposition."
    )
    return {
        "id": card_id,
        "status": "OPEN",
        "category": "Book evolution",
        "severity": "action",
        "question": question,
        "recommendation": recommendation,
        "yes_effect": yes_effect,
        "no_effect": no_effect,
        "cost_of_wait": (
            "Weekly default is KEEP; waiting one week defers a material improvement that the "
            "frozen evidence already supports. No factory stop."
        ),
        "evidence": [package_rel],
        "depends_on": [],
    }


def sunday_recommendation(
    *,
    iso_week: str | None = None,
    cut_id: str | None = None,
    root: Path = BOOK_EVOLUTION_ROOT,
    no_owner_card: bool = False,
    no_vault: bool = False,
    upsert_fn: Callable[..., Mapping[str, Any]] | None = None,
    vault_root: Path | None = None,
    copy_canonical: bool = True,
) -> dict[str, Any]:
    """Build the OWNER decision package + (optionally) enqueue one card per CHANGE venue."""
    root = Path(root)
    week = iso_week or iso_week_of(_now().date())
    cid = resolve_cut_id(root, week, cut_id)
    cut = cut_dir(root, week, cid)
    manifest = _assert_closed_cut(cut)
    frozen_at = manifest["frozen_at_utc"]
    inputs_dir = cut / "inputs"

    read_models: dict[str, dict[str, Any] | None] = {}
    for venue in VENUES:
        rm = _read_json(_read_model_path(cut, venue))
        if rm is None:
            raise BookEvolutionError(
                f"missing {venue} read-model for {week}/{cid}; run saturday-analysis first"
            )
        read_models[venue] = rm

    package_rel = f"D:/QM/reports/book_evolution/{week}/OWNER_DECISION_PACKAGE.md"
    lines: list[str] = []
    lines.append(f"# OWNER decision package — weekly book recomposition {week}")
    lines.append("")
    lines.append(f"Generated (frozen cut instant): `{frozen_at}` · cut `{cid}` · git `{manifest.get('git_commit')}`.")
    lines.append("Deterministic + reproducible from the frozen cut inputs alone "
                 "(OWNER-DEC-CBE-20260915 section 70). Weekly default is KEEP.")
    lines.append("")
    lines.append("Boundaries: this package PREPARES; it never deploys, toggles AutoTrading, or buys a "
                 "Challenge. Those remain OWNER-only.")
    lines.append("")

    cards: list[dict[str, Any]] = []
    per_venue: dict[str, Any] = {}
    for venue in VENUES:
        rm = read_models[venue] or {}
        proposal = rm.get("proposal") or {}
        outcome = str(proposal.get("outcome"))
        owner_action = rm.get("owner_action")
        cross = _read_json(_cross_review_path(cut, venue)) or {}
        lines.append(f"## {venue.upper()} — outcome: **{outcome}**")
        lines.append("")
        lines.append(f"- OWNER action: `{owner_action}`.")
        lines.append(f"- Cross-review: cross_vendor=`{cross.get('cross_vendor')}` · "
                     f"status=`{cross.get('chain_status')}` · critic verdict `{cross.get('critic_verdict_path')}`"
                     + (" (blocked on quota; not a blocker)" if cross.get("blocked_on_quota") else ""))
        lines.append(f"- Recommendation: {rm.get('recommendation_text')}")
        lines.append("")
        if outcome in KEEP_OUTCOMES:
            lines.append(f"**No change proposed for {venue.upper()} this week — owner_action NONE.** "
                         "The frozen evidence did not clear the materiality threshold vs the incumbent.")
            lines.append("")
            per_venue[venue] = {"outcome": outcome, "owner_action": "NONE", "card_id": None}
        else:
            lines.append("### Section 9 answers (proposed change)")
            lines.extend(_section9_answers(venue, rm))
            lines.append("")
            lines.append("### Technical artifacts to prepare (DRY-RUN commands — never executed here)")
            lines.append("```")
            lines.extend(_dry_run_artifact_commands(venue, week))
            lines.append("```")
            lines.append("")
            card = _owner_card(venue, week, rm, package_rel)
            cards.append(card)
            per_venue[venue] = {"outcome": outcome, "owner_action": owner_action, "card_id": card["id"]}

    lines.append(_executive_block(inputs_dir, read_models["dxz"], read_models["ftmo"]))
    lines.append("")
    package_text = "\n".join(lines) + "\n"

    package_path = cut / "OWNER_DECISION_PACKAGE.md"
    _write_text(package_path, package_text)
    canonical_path = None
    if copy_canonical and not no_vault:
        canonical_path = week_dir(root, week) / "OWNER_DECISION_PACKAGE.md"
        _write_text(canonical_path, package_text)

    # Enqueue at most one OWNER decision card per CHANGE venue (idempotent).
    card_results: list[dict[str, Any]] = []
    if cards and not no_owner_card:
        upsert_fn = upsert_fn or _default_upsert()
        for card in cards:
            res = upsert_fn(card)
            card_results.append({"id": card["id"], "action": res.get("action")})
            log(f"sunday-recommendation card {card['id']} -> {res.get('action')}")
    elif cards:
        for card in cards:
            card_results.append({"id": card["id"], "action": "skipped_no_owner_card"})

    vault_path = None
    if not no_vault:
        vault_path = _mirror_vault(week, package_text, per_venue, vault_root=vault_root)

    result = {
        "schema": "qm.book-evolution-recommendation/v1",
        "iso_week": week, "cut_id": cid, "generated_at_utc": frozen_at,
        "package_path": str(package_path),
        "canonical_package_path": str(canonical_path) if canonical_path else None,
        "vault_path": str(vault_path) if vault_path else None,
        "per_venue": per_venue,
        "cards": card_results,
        "owner_action_required": any(v.get("card_id") for v in per_venue.values()),
    }
    _write_json(cut / "recommendation_index.json", result)
    log(f"sunday-recommendation done week={week} cut={cid} cards={[c['id'] for c in cards]}")
    return result


# ---------------------------------------------------------------------------
# Vault mirror ('08 Current State/Book Evolution/<ISO-week>.md' + a stable index)
# ---------------------------------------------------------------------------
def _default_vault_root() -> Path:
    return Path(r"G:\My Drive\QuantMechanica - Company Reference\08 Current State\Book Evolution")


def _mirror_vault(iso_week: str, package_text: str, per_venue: Mapping[str, Any], *, vault_root: Path | None = None) -> Path | None:
    base = Path(vault_root) if vault_root is not None else _default_vault_root()
    try:
        base.mkdir(parents=True, exist_ok=True)
        page = base / f"{iso_week}.md"
        header = (
            f"# Book Evolution — {iso_week}\n\n"
            f"> Generated by `book_evolution_runner.py sunday-recommendation` "
            f"(OWNER-DEC-CBE-20260915). Idempotent mirror of the OWNER decision package. "
            f"Canonical decision status: [[../../12 ToDo/AI ToDos/OWNER|Mission Control]].\n\n"
        )
        page.write_text(header + package_text, encoding="utf-8")
        _write_vault_index(base)
        return page
    except OSError:
        log(f"vault mirror skipped for {iso_week} (Vault not writable)")
        return None


def _write_vault_index(base: Path) -> None:
    weeks = sorted(
        (p.stem for p in base.glob("*.md") if p.name not in {"_index.md", "Book Evolution.md"}),
        reverse=True,
    )
    lines = [
        "# Book Evolution — Index",
        "",
        "> Generated (idempotent). One page per ISO week; the weekly OWNER decision package.",
        "> See [[../Continuous Book Evolution]] and the Mission Control decision queue.",
        "",
    ]
    for wk in weeks:
        lines.append(f"- [[{wk}]]")
    if not weeks:
        lines.append("_No weekly recomposition mirrored yet._")
    lines.append("")
    (base / "_index.md").write_text("\n".join(lines), encoding="utf-8")


# ---------------------------------------------------------------------------
# runtime-verify (read-only)
# ---------------------------------------------------------------------------
def _default_live_profile_dir() -> Path:
    """The live T_Live book profile dir (from the cutover ceremony, kept DRY)."""
    try:
        from tools.strategy_farm import tlive_book_cutover as tbc  # noqa: PLC0415
        return Path(tbc.PROFILE_DST)
    except Exception:  # noqa: BLE001
        return Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Profiles\Charts\DarwinexZero_Book2_LiveOps")


def runtime_verify(
    *,
    iso_week: str | None = None,
    cut_id: str | None = None,
    root: Path = BOOK_EVOLUTION_ROOT,
    live_profile_dir: Path | None = None,
    ftmo_demo_state: Path | None = None,
    verify_profile_fn: Callable[..., Mapping[str, Any]] | None = None,
) -> dict[str, Any]:
    """READ-ONLY post-OWNER check that runtime identity matches the accepted package.

    Writes ONLY ``<cut>/verify.json`` — never touches T_Live, charts, AutoTrading, the
    FTMO terminal, or any state outside its own report.
    """
    root = Path(root)
    week = iso_week or iso_week_of(_now().date())
    cid = resolve_cut_id(root, week, cut_id)
    cut = cut_dir(root, week, cid)
    _assert_closed_cut(cut)
    checks: list[dict[str, Any]] = []

    # --- DXZ profile identity (read-only verify against the built manifest).
    dxz_rm = _read_json(_read_model_path(cut, "dxz")) or {}
    dxz_outcome = (dxz_rm.get("proposal") or {}).get("outcome")
    prof_dir = Path(live_profile_dir) if live_profile_dir is not None else _default_live_profile_dir()
    prof_manifest = prof_dir / "profile_manifest.json"
    if prof_dir.is_dir() and prof_manifest.is_file():
        fn = verify_profile_fn
        if fn is None:
            try:
                from tools.strategy_farm import build_tlive_book_profile as bp  # noqa: PLC0415
                fn = bp.verify_profile
            except Exception as exc:  # noqa: BLE001
                checks.append({"name": "dxz_profile_verify", "status": "NOT_EVALUATED", "reason": str(exc)[:200]})
                fn = None
        if fn is not None:
            try:
                v = fn(prof_dir, prof_manifest)
                checks.append({"name": "dxz_profile_verify", "status": v.get("status"),
                               "mismatches": v.get("mismatches"), "charts_found": v.get("charts_found")})
            except Exception as exc:  # noqa: BLE001
                checks.append({"name": "dxz_profile_verify", "status": "NOT_EVALUATED", "reason": str(exc)[:200]})
    else:
        checks.append({"name": "dxz_profile_verify", "status": "EVIDENCE_MISSING",
                       "reason": f"live profile dir/manifest absent: {prof_dir}"})

    # --- FTMO demo roster identity (compare live demo roster_hash to the frozen cut).
    demo_live_path = Path(ftmo_demo_state) if ftmo_demo_state is not None else (STATE_DIR / "ftmo_demo_cycle.json")
    demo_live = _read_json(demo_live_path)
    demo_frozen = _read_json(cut / "inputs" / "ftmo_demo_cycle.json")
    if demo_live and demo_frozen:
        same = demo_live.get("roster_hash") == demo_frozen.get("roster_hash")
        checks.append({"name": "ftmo_demo_roster_matches_cut", "status": "OK" if same else "MISMATCH",
                       "live_roster_hash": demo_live.get("roster_hash"),
                       "cut_roster_hash": demo_frozen.get("roster_hash")})
    else:
        checks.append({"name": "ftmo_demo_roster_matches_cut", "status": "EVIDENCE_MISSING",
                       "reason": "live or frozen demo roster missing"})

    overall = "OK"
    for c in checks:
        if c["status"] in {"MISMATCH"}:
            overall = "MISMATCH"
            break
        if c["status"] in {"EVIDENCE_MISSING", "NOT_EVALUATED"} and overall == "OK":
            overall = "INCOMPLETE"
    report = {
        "schema": VERIFY_SCHEMA,
        "iso_week": week, "cut_id": cid,
        "generated_at_utc": _now().isoformat(),
        "dxz_proposed_outcome": dxz_outcome,
        "overall": overall,
        "checks": checks,
        "boundaries": "read-only; no toggle, no deployment, no write outside this report",
    }
    verify_path = cut / "verify.json"
    _write_json(verify_path, report)
    log(f"runtime-verify week={week} cut={cid} overall={overall}")
    return report


# ---------------------------------------------------------------------------
# status
# ---------------------------------------------------------------------------
def status(*, iso_week: str | None = None, cut_id: str | None = None, root: Path = BOOK_EVOLUTION_ROOT) -> dict[str, Any]:
    root = Path(root)
    week = iso_week or iso_week_of(_now().date())
    cid = resolve_cut_id(root, week, cut_id)
    cut = cut_dir(root, week, cid)
    manifest = _read_json(cut / "cut_manifest.json")
    phases = {
        "friday_cut": bool(manifest and manifest.get("status") == "CLOSED"),
        "saturday_analysis": (cut / "analysis_index.json").is_file(),
        "sunday_recommendation": (cut / "recommendation_index.json").is_file(),
        "runtime_verify": (cut / "verify.json").is_file(),
    }
    venues: dict[str, Any] = {}
    for venue in VENUES:
        rm = _read_json(_read_model_path(cut, venue)) or {}
        venues[venue] = {
            "outcome": (rm.get("proposal") or {}).get("outcome"),
            "owner_action": rm.get("owner_action"),
        }
    return {
        "schema": STATUS_SCHEMA,
        "generated_at_utc": _now().isoformat(),
        "iso_week": week, "cut_id": cid, "cut_dir": str(cut),
        "cut_closed": phases["friday_cut"],
        "phases": phases,
        "venues": venues,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def _parse_as_of(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    d = dt.datetime.fromisoformat(value)
    return d if d.tzinfo else d.replace(tzinfo=dt.UTC)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Weekly book-evolution ceremony runner (Phase H).")
    sub = parser.add_subparsers(dest="command", required=True)

    def _common(p: argparse.ArgumentParser) -> None:
        p.add_argument("--week", default=None, help="ISO week, e.g. 2026-W38 (default: current)")
        p.add_argument("--cut-id", default=None, help="cut id (default: active cut / c1)")
        p.add_argument("--root", type=Path, default=BOOK_EVOLUTION_ROOT)

    p_fri = sub.add_parser("friday-cut", help="freeze both venues + read-models into an immutable CLOSED cut")
    _common(p_fri)
    p_fri.add_argument("--as-of", default=None, help="freeze instant ISO-8601 (default: Friday-close of the week)")
    p_fri.add_argument("--seed", type=int, default=None)
    p_fri.add_argument("--force-new-cut", action="store_true", help="mint a NEW cut id (never overwrites a CLOSED cut)")
    p_fri.add_argument("--no-state-builds", action="store_true", help="skip refreshing the supporting read-models")

    p_sat = sub.add_parser("saturday-analysis", help="evaluate both venues from the frozen snapshots + cross-review")
    _common(p_sat)
    p_sat.add_argument("--no-cross-review-apply", action="store_true",
                       help="plan the critique (resolve the seat) without spending tokens")

    p_sun = sub.add_parser("sunday-recommendation", help="build the OWNER decision package + enqueue CHANGE cards")
    _common(p_sun)
    p_sun.add_argument("--no-owner-card", action="store_true", help="do not enqueue any OWNER decision card")
    p_sun.add_argument("--no-vault", action="store_true", help="do not mirror to the Vault or the canonical week path")

    p_ver = sub.add_parser("runtime-verify", help="read-only runtime identity check after OWNER action")
    _common(p_ver)

    p_st = sub.add_parser("status", help="summarise the current week / cut")
    _common(p_st)

    sub.add_parser("readmodels", help="refresh the four supporting read-models (for the 15-min task)")

    args = parser.parse_args(argv)

    if args.command == "readmodels":
        results = _run_state_builds(None)
        print(json.dumps({"readmodels": results}, indent=2))
        return 0

    if args.command == "friday-cut":
        out = friday_cut(
            iso_week=args.week, cut_id=args.cut_id, root=args.root,
            as_of=_parse_as_of(args.as_of), seed=args.seed, force_new_cut=args.force_new_cut,
            run_state_builds=not args.no_state_builds,
        )
        print(json.dumps({"friday_cut": out["iso_week"], "cut_id": out["cut_id"],
                          "status": out["status"], "manifest": str(cut_dir(args.root, out["iso_week"], out["cut_id"]) / "cut_manifest.json")},
                         indent=2))
        return 0
    if args.command == "saturday-analysis":
        out = saturday_analysis(
            iso_week=args.week, cut_id=args.cut_id, root=args.root,
            cross_review_apply=not args.no_cross_review_apply,
        )
        print(json.dumps(out, indent=2))
        return 0
    if args.command == "sunday-recommendation":
        out = sunday_recommendation(
            iso_week=args.week, cut_id=args.cut_id, root=args.root,
            no_owner_card=args.no_owner_card, no_vault=args.no_vault,
        )
        print(json.dumps(out, indent=2))
        return 0
    if args.command == "runtime-verify":
        out = runtime_verify(iso_week=args.week, cut_id=args.cut_id, root=args.root)
        print(json.dumps(out, indent=2))
        return 0
    if args.command == "status":
        out = status(iso_week=args.week, cut_id=args.cut_id, root=args.root)
        print(json.dumps(out, indent=2))
        return 0
    parser.error(f"unknown command {args.command!r}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
