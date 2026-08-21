"""Public Strategy-Archive contract generator (STAGING ONLY).

Transfers the existing operational Strategy Archive (the ``work_items`` pipeline
database + approved Strategy Cards + framework EA folders) into a *versioned,
redacted* JSON contract for quantmechanica.com.  The chain

    EA  ->  Strategy Card  ->  (Symbol, Gate) verdict  ->  Report reference

is addressable end-to-end through stable public IDs.

Design constraints (task QM-TODO-20260820-003):

* **Read-only** over the farm DB — uses the ``work_items_clean`` TEMP view via
  :func:`work_item_clean_view.open_clean_view_connection`; never mutates state.
* **Staging only** — writes the contract tree into
  ``D:\\QM\\exports\\website_contract_preview\\``.  It deliberately does *not*
  write into ``public-data/`` and does *not* invoke the live exporter or its
  fail-closed public-snapshot incident guard.  Publication stays behind that
  existing guard; this generator only prepares a preview tree for review.
* **Fail-closed redaction** — every emitted record is built from an explicit
  field allowlist and scrubbed by :func:`redact_record`.  Unknown field classes
  are DROPPED by default; forbidden classes (absolute paths, hostnames/VPS
  detail, account numbers, credentials, magic numbers that map to accounts) are
  stripped or refused.  See :mod:`redaction` section below and the unit tests in
  ``tests/test_website_archive_contract.py``.

Operator surfaces show Qxx gate names only; storage keeps legacy ``P*`` keys.
This generator reads the legacy keys and maps them to canonical Qxx for output,
labelling any legacy-era row as ``era: "legacy"`` (truth rule: mixed-era cohorts
are labelled, never silently promoted).
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT / "tools" / "strategy_farm") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from phase_ids import PHASE_ORDER, PHASE_NAME, phase_qid  # noqa: E402

CONTRACT_VERSION = 1
CONTRACT_SCHEMA_ID = "https://quantmechanica.com/schemas/website-strategy-archive/v1.json"

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_FARM_ROOT = Path(r"D:\QM\strategy_farm")
DEFAULT_OUT_DIR = Path(r"D:\QM\exports\website_contract_preview")

# Publication guard reference (informational; this generator never publishes).
PUBLIC_DATA_DIR = REPO_ROOT / "public-data"

# ---------------------------------------------------------------------------
# REDACTION  (fail-closed).  Encoded as code + tests, not prose.
# ---------------------------------------------------------------------------

REDACTED = "[REDACTED]"

# Forbidden free-text patterns.  Ordered; each match is replaced with REDACTED.
# These target the concrete leak classes named in the task.
# Paths may contain spaces. Stop only at a strong prose/JSON delimiter; for a
# fail-closed projection, redacting extra text is safer than exposing the tail
# of ``G:\My Drive\...``. Accept forward slashes on drive-letter paths too.
_ABS_WIN_PATH = re.compile(r"(?<![A-Za-z0-9])[A-Za-z]:[\\/][^\r\n\"'<>|,;)]*")
_FILE_URI = re.compile(r"file:/{2,}[^\r\n\"'<>|,;)]*", re.IGNORECASE)
_UNC_PATH = re.compile(r"\\\\[A-Za-z0-9._$-]+\\[^\r\n\"'<>|,;)]*")
_ABS_POSIX_QM = re.compile(r"/(?:mnt|home|root|opt|var)/[^\r\n\"'<>|,;)]*")
_IPV4 = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
# labelled account/login/magic numbers, e.g. "account: 1234567", "magic=100390001"
_LABELLED_ID = re.compile(
    r"\b(account|acct|login|magic|magic_number|broker[_ ]?login)\b\s*[:=#]?\s*\d{4,}",
    re.IGNORECASE,
)
# credential-looking assignments, e.g. "password: hunter2", "api_key = abc123"
_CREDENTIAL = re.compile(
    r"\b(password|passwd|pwd|secret|api[_-]?key|token|credential|bearer)\b"
    r"\s*[:=]\s*\S+",
    re.IGNORECASE,
)
_LABELLED_ENDPOINT = re.compile(
    r"\b(host|hostname|server|vps)\b\s*[:=]\s*\S+",
    re.IGNORECASE,
)
# E-mail addresses (source authors, contacts) never belong on the public surface.
_EMAIL = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
# Infrastructure / personal-storage names (hard rule: no public VPS detail;
# OWNER's private storage provenance stays private).
_SENSITIVE_NAME = re.compile(r"\b(hyonix|dropbox)\b", re.IGNORECASE)
# Non-web URI schemes (l://..., obsidian://..., ssh://...) are internal locators;
# only plain http(s) survives because citations may carry public source links.
_NON_WEB_URI = re.compile(r"\b(?!https?://)[A-Za-z][A-Za-z0-9+.-]{0,15}://[^\r\n\"'<>| ]*")

_FREE_TEXT_PATTERNS = (
    _CREDENTIAL,
    _LABELLED_ENDPOINT,
    _LABELLED_ID,
    _FILE_URI,
    _UNC_PATH,
    _ABS_WIN_PATH,
    _ABS_POSIX_QM,
    _IPV4,
    _EMAIL,
    _NON_WEB_URI,
    _SENSITIVE_NAME,
)

# A key is forbidden ENTIRELY (value never survives) when any of these tokens
# appears in it.  Fail-closed: matched keys are dropped by allowlisting, but the
# token set is also applied defensively inside redact_record so a mistaken
# allowlist entry cannot leak.
_FORBIDDEN_KEY_TOKENS = (
    "magic",
    "account",
    "login",
    "password",
    "passwd",
    "secret",
    "token",
    "apikey",
    "api_key",
    "credential",
    "server",
    "host",
    "hostname",
    "vps",
    "terminal",
    "claimed_by",
    "claimant",
    "worker",
    "path",        # any *_path (evidence_path, setfile_path, ...) is a leak
    "dir",
    "ip_addr",
    "ipaddr",
)


def _key_is_forbidden(key: str) -> bool:
    k = key.lower()
    return any(tok in k for tok in _FORBIDDEN_KEY_TOKENS)


def scrub_text(value: str) -> str:
    """Strip every forbidden free-text class from a string.

    Absolute Windows/UNC/file:// paths, POSIX system paths, IPv4 addresses,
    labelled account/login/magic numbers and credential assignments are all
    replaced with ``[REDACTED]``.  Safe for report excerpts and card bodies.
    """
    if not isinstance(value, str):
        return value
    out = value
    for pat in _FREE_TEXT_PATTERNS:
        out = pat.sub(REDACTED, out)
    return out


def redact_value(key: str, value: Any) -> Any:
    """Redact a single (key, value).  Fail-closed.

    * Forbidden key  -> refused (returns ``[REDACTED]``, never the value).
    * str value      -> scrubbed of forbidden free-text classes.
    * dict / list    -> recursively scrubbed (nested unknown keys dropped).
    * scalar         -> passed through.
    """
    if _key_is_forbidden(key):
        return REDACTED
    if isinstance(value, str):
        return scrub_text(value)
    if isinstance(value, dict):
        # Nested dicts: drop forbidden keys, scrub the rest (values only —
        # nested shape is caller-controlled, so no outer allowlist here).
        return {
            k: redact_value(k, v)
            for k, v in value.items()
            if not _key_is_forbidden(k)
        }
    if isinstance(value, list):
        return [redact_value(key, v) for v in value]
    return value


def redact_record(record: dict[str, Any], allowed: set[str]) -> dict[str, Any]:
    """Project ``record`` onto the allowlist, scrubbing survivors.

    Fail-closed rules:

    1. Only keys in ``allowed`` survive — **unknown field classes are DROPPED**.
    2. Even an allowlisted key is refused if its name matches a forbidden token
       (defence in depth against an allowlist mistake).
    3. Surviving string / dict / list values are scrubbed by :func:`redact_value`.
    """
    out: dict[str, Any] = {}
    for key, value in record.items():
        if key not in allowed:
            continue  # unknown -> dropped
        if _key_is_forbidden(key):
            continue  # allowlist mistake -> still refused
        out[key] = redact_value(key, value)
    return out


# ---------------------------------------------------------------------------
# Stable public IDs
# ---------------------------------------------------------------------------

def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def _sha256_file(path: Path) -> str | None:
    try:
        h = hashlib.sha256()
        with path.open("rb") as fh:
            for chunk in iter(lambda: fh.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return None


def report_id_for(evidence_path: str) -> str:
    """Opaque, path-free report id.  The raw path is never exposed."""
    return "rpt_" + _sha256_text(evidence_path)[:16]


def run_id_for(work_item_id: str) -> str:
    return "run_" + _sha256_text(work_item_id)[:16]


def card_id_for(card_sha256: str) -> str:
    return "card_" + card_sha256[:16]


# ---------------------------------------------------------------------------
# Era / gate helpers
# ---------------------------------------------------------------------------

def _era_for(raw_phase: str) -> str:
    """A row stored under a legacy P-key is a legacy-era result."""
    return "legacy" if str(raw_phase).upper().startswith("P") else "current"


def _public_gate(raw_phase: str) -> str | None:
    """Canonical Qxx for output, or None for non-pipeline/internal phases."""
    qid = phase_qid(raw_phase)
    if qid in PHASE_ORDER:
        return qid
    return None  # HARNESS_PP_FIXTURE and any unknown internal phase -> dropped


_PASS_VERDICTS = {
    "PASS", "PASS_SOFT", "PASS_LOWFREQ", "PASS_PORTFOLIO",
    "AUTO_PASS", "MULTI_SEED_PASS", "MODE_SELECTED", "CONFIG_LOCKED",
}


def _public_verdict(verdict: str | None) -> str:
    """Map storage verdicts to a small public vocabulary (honest, coarse)."""
    v = (verdict or "").upper()
    if not v:
        return "OPEN"
    if v in _PASS_VERDICTS:
        return "PASS"
    if v.startswith("FAIL"):
        return "FAIL"
    if v in ("INFRA_FAIL", "INVALID", "INVALID_EVIDENCE",
             "INVALID_BUILD_STATIC_FIDELITY", "NEED_MORE_DATA"):
        return "INFRA"
    if v.startswith("RETIRE") or v == "OBSOLETE_NON_DWX_SYMBOL":
        return "RETIRED"
    if v.startswith("SUPERSEDED"):
        return "SUPERSEDED"
    if v == "ZERO_TRADES":
        return "ZERO_TRADES"
    return "OPEN"


def _headline_score(row: dict[str, Any], has_metrics: bool) -> tuple:
    """Rank attempts within an (ea, symbol, gate) cell for the headline row.

    Prefer non-ablation, graded (metrics present), pass-ish, most recent —
    mirrors the archive dashboard's representative-attempt rule so the public
    row is not an INFRA re-run that hides a genuine PASS.
    """
    nonabl = 0 if row.get("is_ablation") else 1
    graded = 1 if has_metrics else 0
    passish = 1 if (row.get("verdict") or "").upper() in _PASS_VERDICTS else 0
    return (nonabl, graded, passish, row.get("updated_at") or "")


# ---------------------------------------------------------------------------
# Card projection
# ---------------------------------------------------------------------------

_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)

# Allowlisted card-frontmatter fields for the public projection.  Everything
# else in the frontmatter is DROPPED (fail-closed).
_CARD_FM_ALLOW = {
    "ea_id", "slug", "type", "source_citation", "sources", "concepts",
    "indicators", "target_symbols", "period", "expected_trade_frequency",
    "expected_trades_per_year_per_symbol", "g0_status", "r1_track_record",
    "r2_mechanical", "r3_data_available", "r4_ml_forbidden", "pipeline_phase",
    "last_updated", "g0_approval_reasoning",
}


def _parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    """Minimal YAML-ish frontmatter parser (no external dep).

    Handles the flat ``key: value`` and ``key: [a, b]`` and ``- item`` list
    shapes that the Strategy-Card frontmatter uses.  Anything it cannot parse is
    left out — the projection is allowlisted anyway.
    """
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return {}, text
    body = text[m.end():]
    fm_raw = m.group(1)
    fm: dict[str, Any] = {}
    cur_key: str | None = None
    for line in fm_raw.splitlines():
        if not line.strip():
            continue
        if line.lstrip().startswith("- ") and cur_key:
            fm.setdefault(cur_key, [])
            if isinstance(fm[cur_key], list):
                fm[cur_key].append(line.lstrip()[2:].strip().strip('"'))
            continue
        if ":" in line and not line.startswith(" "):
            key, _, val = line.partition(":")
            key = key.strip()
            val = val.strip()
            cur_key = key
            if val == "":
                fm[key] = []  # list follows on subsequent - lines
            elif val.startswith("[") and val.endswith("]"):
                inner = val[1:-1].strip()
                fm[key] = [x.strip().strip('"') for x in inner.split(",") if x.strip()]
            else:
                fm[key] = val.strip('"')
    return fm, body


def _card_grade(fm: dict[str, Any]) -> tuple[str, list[str]]:
    """Heuristic Strategy-Card DOCUMENT-quality grade (not profitability).

    Grades the card's completeness against the programme rubric.  Returns
    ``(grade, missing_parts)``.  Deliberately conservative and transparent — the
    missing list is published so the grade is auditable, never a black box.
    """
    missing: list[str] = []
    if not fm.get("source_citation") and not fm.get("sources"):
        missing.append("source_provenance")
    if not (fm.get("indicators") or fm.get("concepts")):
        missing.append("mechanical_definition")
    if not fm.get("target_symbols"):
        missing.append("target_symbols")
    if not fm.get("period"):
        missing.append("timeframe")
    r4 = str(fm.get("r4_ml_forbidden", "")).upper()
    ml_blocked = r4 not in ("PASS", "")
    if ml_blocked:
        return "Blocked", ["ml_forbidden_rule_violation"]
    if not missing and str(fm.get("g0_status", "")).upper() == "APPROVED":
        grade = "A"
    elif len(missing) <= 1:
        grade = "B"
    elif len(missing) <= 2:
        grade = "C"
    else:
        grade = "D"
    return grade, missing


def project_card(card_path: Path) -> dict[str, Any] | None:
    """Redacted public projection of one approved Strategy Card."""
    try:
        content = card_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    card_sha = _sha256_text(content)
    fm, body = _parse_frontmatter(content)
    # The FILENAME is the canonical public identity (it matches the DB ea_id and
    # the framework/EAs folder). Some card frontmatters carry a stale/bare id
    # (e.g. QM5_1143_*.md with `ea_id: 1143`); trusting frontmatter there breaks
    # the EA->card->gate join. Prefer the filename-derived QM5_<n>, and record a
    # reconciliation flag when the frontmatter disagrees.
    name_m = re.match(r"(QM5_\d+)_", card_path.name)
    fm_ea = str(fm.get("ea_id") or "").strip()
    ea_id = name_m.group(1) if name_m else fm_ea
    if not ea_id:
        # Non-EA intake note (e.g. ANTIGRAVITY_PROMPT_*) — not a strategy card.
        return None
    id_reconciled = bool(name_m and fm_ea and fm_ea != ea_id)
    fm_public = redact_record(fm, _CARD_FM_ALLOW)
    if "ea_id" in fm_public:
        fm_public["ea_id"] = ea_id  # canonical identity from filename
    grade, missing = _card_grade(fm)
    # Body excerpt: scrubbed, bounded.  Full body is IP-sensitive mechanical
    # detail; the public projection carries a redacted lead excerpt only.
    excerpt = scrub_text(body.strip())[:1200]
    return {
        "card_id": card_id_for(card_sha),
        "ea_id": ea_id,
        "slug": scrub_text(str(fm.get("slug") or "")),
        "card_sha256": card_sha,
        "grade": grade,
        "grade_missing_parts": missing,
        "id_reconciled_from_frontmatter": id_reconciled,
        "frontmatter": fm_public,
        "excerpt_redacted": excerpt,
    }


# ---------------------------------------------------------------------------
# Slug map (EA folder -> human slug)
# ---------------------------------------------------------------------------

def build_slug_map(repo_root: Path) -> dict[str, dict[str, Any]]:
    """ea_id -> {slug, has_source, has_binary} from framework/EAs folders."""
    out: dict[str, dict[str, Any]] = {}
    eas_dir = repo_root / "framework" / "EAs"
    if not eas_dir.exists():
        return out
    for d in eas_dir.iterdir():
        if not d.is_dir():
            continue
        name = d.name
        if "_" not in name:
            continue
        ea_id, _, slug = name.partition("_")
        if not ea_id.startswith("QM5_"):
            # folder names are QM5_<num>_<slug> -> partition on first underscore
            # gives ea_id="QM5", so re-split on the numeric id boundary.
            m = re.match(r"(QM5_\d+)_(.+)", name)
            if not m:
                continue
            ea_id, slug = m.group(1), m.group(2)
        out[ea_id] = {
            "slug": slug,
            "has_source": (d / f"{name}.mq5").exists(),
            "has_binary": (d / f"{name}.ex5").exists(),
        }
    return out


# ---------------------------------------------------------------------------
# Main build
# ---------------------------------------------------------------------------

# Allowlists for the emitted record types (fail-closed projection).
_SUMMARY_ALLOW = {
    "ea_id", "slug", "family", "timeframe", "card_id", "card_grade",
    "highest_pass_gate", "most_advanced_gate", "gate_status",
    "n_symbols_tested", "symbols_sample", "n_gate_results", "has_source",
    "has_binary", "era", "last_reliable_check_utc", "freshness",
}
_GATE_RESULT_ALLOW = {
    "ea_id", "symbol_id", "gate_id", "gate_name", "gate_contract_version",
    "era", "run_id", "verdict", "metrics", "updated_at_utc", "freshness",
    "freshness_reasons", "report_id", "report_published",
}
_METRICS_ALLOW = {
    "net_profit", "profit_factor", "trades", "drawdown_money",
    "drawdown_pct", "sharpe",
}

_RECHECK_DUE_DAYS = 120


def _freshness(updated_at: str, evidence_present: bool, now: dt.datetime,
               era: str) -> tuple[str, list[str]]:
    reasons: list[str] = []
    if not evidence_present:
        reasons.append("EVIDENCE_MISSING")
    if era == "legacy":
        reasons.append("GATE_CHANGED")
    age_days = None
    try:
        upd = dt.datetime.fromisoformat(str(updated_at).replace("Z", "+00:00"))
        if upd.tzinfo is None:
            upd = upd.replace(tzinfo=dt.UTC)
        age_days = (now - upd).days
    except (ValueError, TypeError):
        pass
    if age_days is not None and age_days > _RECHECK_DUE_DAYS:
        reasons.append("RECHECK_DUE")
    if not reasons:
        return "current", []
    return "stale", reasons


def build_contract(db_path: Path, farm_root: Path, repo_root: Path,
                   *, verbose: bool = False) -> dict[str, Any]:
    """Read the farm DB read-only and assemble the redacted contract tree.

    Returns a dict with keys ``summaries``, ``cards``, ``gate_results``,
    ``report_manifest`` and ``counts``.  Pure builder — writes nothing.
    """
    from work_item_clean_view import open_clean_view_connection
    from gate_manifest import load_gate_manifest

    manifest = load_gate_manifest()
    gate_contract_version = f"{manifest.schema_version}#{manifest.sha256[:12]}"

    now = dt.datetime.now(dt.UTC)
    slug_map = build_slug_map(repo_root)

    # ---- cards ----
    cards: list[dict[str, Any]] = []
    card_by_ea: dict[str, dict[str, Any]] = {}
    cards_dir = farm_root / "artifacts" / "cards_approved"
    if cards_dir.exists():
        for cf in sorted(cards_dir.glob("QM5_*.md")):
            proj = project_card(cf)
            if proj is None:
                continue
            cards.append(proj)
            card_by_ea.setdefault(proj["ea_id"], proj)

    # ---- gate results (headline row per (ea, symbol, gate)) ----
    conn = open_clean_view_connection(db_path)
    try:
        cur = conn.execute(
            "SELECT id, ea_id, phase, symbol, status, verdict, updated_at, "
            "evidence_path FROM work_items_clean")
        wi_rows = cur.fetchall()
        wi_cols = [c[0] for c in cur.description]
        # metrics keyed by work_item_id
        metrics: dict[str, dict[str, Any]] = {}
        try:
            mcur = conn.execute(
                "SELECT work_item_id, net_profit, profit_factor, trades, "
                "drawdown_money, drawdown_pct, sharpe, is_ablation FROM ea_metrics")
            mcols = [c[0] for c in mcur.description]
            for mr in mcur.fetchall():
                md = dict(zip(mcols, mr))
                metrics[md["work_item_id"]] = md
        except Exception:  # ea_metrics may not exist
            metrics = {}
    finally:
        conn.close()

    # aggregate to headline per cell
    best: dict[tuple[str, str, str], dict[str, Any]] = {}
    ea_symbols: dict[str, set[str]] = {}
    ea_phase_pass: dict[str, set[str]] = {}
    ea_phase_any: dict[str, set[str]] = {}
    ea_last_upd: dict[str, tuple[str, str]] = {}  # ea -> (updated_at, phase)

    for raw in wi_rows:
        r = dict(zip(wi_cols, raw))
        ea_id = r.get("ea_id")
        if not ea_id:
            continue
        raw_phase = r.get("phase") or ""
        gate = _public_gate(raw_phase)
        if gate is None:
            continue  # internal / non-pipeline phase dropped
        symbol = r.get("symbol") or ""
        m = metrics.get(r.get("id"))
        r["is_ablation"] = bool(m.get("is_ablation")) if m else False
        key = (ea_id, symbol, gate)
        cur_best = best.get(key)
        if cur_best is None or _headline_score(r, m is not None) > \
                _headline_score(cur_best["_row"], cur_best["_has_m"]):
            best[key] = {"_row": r, "_has_m": m is not None, "_metrics": m,
                         "_gate": gate, "_ea": ea_id, "_symbol": symbol}
        if symbol:
            ea_symbols.setdefault(ea_id, set()).add(symbol)
        pv = _public_verdict(r.get("verdict"))
        ea_phase_any.setdefault(ea_id, set()).add(gate)
        if pv == "PASS":
            ea_phase_pass.setdefault(ea_id, set()).add(gate)
        upd = r.get("updated_at") or ""
        if ea_id not in ea_last_upd or upd > ea_last_upd[ea_id][0]:
            # Preserve the storage key for the era roll-up. The mapped Qxx key
            # would silently label a legacy P row as current in the summary.
            ea_last_upd[ea_id] = (upd, raw_phase)

    # ---- emit gate_results + report_manifest ----
    gate_results: list[dict[str, Any]] = []
    report_manifest: dict[str, dict[str, Any]] = {}
    for key, blob in best.items():
        r = blob["_row"]
        gate = blob["_gate"]
        m = blob["_metrics"]
        raw_phase = r.get("phase") or ""
        era = _era_for(raw_phase)
        ev_path = r.get("evidence_path") or ""
        evidence_present = bool(ev_path) and Path(ev_path).exists()
        report_id = None
        report_published = False
        if ev_path:
            report_id = report_id_for(ev_path)
            if report_id not in report_manifest:
                # content hash only — the raw path never leaves this process.
                content_sha = _sha256_file(Path(ev_path)) if evidence_present else None
                report_manifest[report_id] = {
                    "report_id": report_id,
                    "published": False,
                    "status": "REPORT_NOT_PUBLISHED",
                    "content_sha256": content_sha,
                    "media_type": "application/json"
                    if ev_path.lower().endswith(".json") else "text/html",
                }
        fresh, fresh_reasons = _freshness(
            r.get("updated_at") or "", evidence_present, now, era)
        metrics_public = redact_record(
            {k: (m or {}).get(k) for k in _METRICS_ALLOW}, _METRICS_ALLOW
        ) if m else {}
        rec = {
            "ea_id": blob["_ea"],
            "symbol_id": blob["_symbol"] or None,
            "gate_id": gate,
            "gate_name": PHASE_NAME.get(gate, gate),
            "gate_contract_version": gate_contract_version,
            "era": era,
            "run_id": run_id_for(r.get("id") or ""),
            "verdict": _public_verdict(r.get("verdict")),
            "metrics": metrics_public,
            "updated_at_utc": scrub_text(str(r.get("updated_at") or "")),
            "freshness": fresh,
            "freshness_reasons": fresh_reasons,
            "report_id": report_id,
            "report_published": report_published,
        }
        gate_results.append(redact_record(rec, _GATE_RESULT_ALLOW))

    # ---- emit strategy summaries (one row per EA) ----
    summaries: list[dict[str, Any]] = []
    all_eas = set(ea_symbols) | set(ea_phase_any) | set(card_by_ea) | set(slug_map)
    for ea_id in sorted(all_eas):
        card = card_by_ea.get(ea_id)
        sm = slug_map.get(ea_id, {})
        passes = ea_phase_pass.get(ea_id, set())
        anyp = ea_phase_any.get(ea_id, set())
        highest_pass = max(passes, key=PHASE_ORDER.index) if passes else None
        most_adv = max(anyp, key=PHASE_ORDER.index) if anyp else None
        last_upd, _ = ea_last_upd.get(ea_id, ("", ""))
        symbols = sorted(ea_symbols.get(ea_id, set()))
        n_results = sum(1 for k in best if k[0] == ea_id)
        # gate status: coarse rollup of the most-advanced cell verdict
        gate_status = "OPEN"
        if highest_pass:
            gate_status = "PASS"
        elif most_adv:
            gate_status = "IN_VALIDATION"
        fam = None
        tf = None
        if card:
            fm = card.get("frontmatter", {})
            tf = fm.get("period")
        rec = {
            "ea_id": ea_id,
            "slug": sm.get("slug") or (card or {}).get("slug"),
            "family": fam,
            "timeframe": tf,
            "card_id": (card or {}).get("card_id"),
            "card_grade": (card or {}).get("grade"),
            "highest_pass_gate": highest_pass,
            "most_advanced_gate": most_adv,
            "gate_status": gate_status,
            "n_symbols_tested": len(symbols),
            "symbols_sample": symbols[:8],
            "n_gate_results": n_results,
            "has_source": bool(sm.get("has_source")),
            "has_binary": bool(sm.get("has_binary")),
            "era": _era_for(ea_last_upd.get(ea_id, ("", ""))[1]) if most_adv else "current",
            "last_reliable_check_utc": scrub_text(str(last_upd)),
            "freshness": "unknown" if not last_upd else "current",
        }
        summaries.append(redact_record(rec, _SUMMARY_ALLOW))

    counts = {
        "eas": len(summaries),
        "cards": len(cards),
        "gate_results": len(gate_results),
        "reports_referenced": len(report_manifest),
    }
    if verbose:
        print("counts:", json.dumps(counts, indent=2))
    return {
        "summaries": summaries,
        "cards": cards,
        "gate_results": gate_results,
        "report_manifest": list(report_manifest.values()),
        "counts": counts,
        "gate_contract_version": gate_contract_version,
        "generated_at": now.replace(microsecond=0).isoformat(),
    }


def _assert_staging_only(out_dir: Path) -> None:
    """Fail-closed: never write into public-data/ or the live export surface."""
    resolved = out_dir.resolve()
    if PUBLIC_DATA_DIR.resolve() in (resolved, *resolved.parents):
        raise SystemExit(
            f"REFUSED: {resolved} is inside public-data/. This generator is "
            "STAGING ONLY; publication stays behind the public-snapshot guard.")


def write_contract(contract: dict[str, Any], out_dir: Path) -> dict[str, str]:
    """Write the four contract files + an index manifest into ``out_dir``."""
    _assert_staging_only(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    gen = contract["generated_at"]
    gcv = contract["gate_contract_version"]

    files = {
        "strategy_summaries.json": ("strategy_summaries", "summaries"),
        "strategy_cards_public.json": ("strategy_cards", "cards"),
        "gate_results.json": ("gate_results", "gate_results"),
        "report_manifest.json": ("report_manifest", "report_manifest"),
    }
    written: dict[str, str] = {}
    for fname, (kind, key) in files.items():
        payload = {
            "contract_version": CONTRACT_VERSION,
            "$schema_id": CONTRACT_SCHEMA_ID,
            "kind": kind,
            "generated_at": gen,
            "gate_contract_version": gcv,
            "items": contract[key],
        }
        p = out_dir / fname
        p.write_text(json.dumps(payload, indent=2, ensure_ascii=False),
                     encoding="utf-8")
        written[fname] = str(p)

    index = {
        "contract_version": CONTRACT_VERSION,
        "$schema_id": CONTRACT_SCHEMA_ID,
        "kind": "index",
        "generated_at": gen,
        "gate_contract_version": gcv,
        "staging_only": True,
        "publication_note": (
            "Preview tree only. Publication to public-data/ stays behind the "
            "existing fail-closed public-snapshot incident guard "
            "(tools/strategy_farm/public_snapshot_incident_guard.py). This "
            "generator never writes public-data/ and never invokes the exporter."
        ),
        "counts": contract["counts"],
        "files": list(files.keys()),
    }
    ip = out_dir / "index.json"
    ip.write_text(json.dumps(index, indent=2, ensure_ascii=False), encoding="utf-8")
    written["index.json"] = str(ip)
    return written


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    ap.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    ap.add_argument("--dry-run", action="store_true",
                    help="build and report counts, write nothing")
    args = ap.parse_args(argv)

    contract = build_contract(args.db, args.farm_root, args.repo_root,
                              verbose=True)
    if args.dry_run:
        print("dry-run: nothing written")
        return 0
    written = write_contract(contract, args.out_dir)
    print("wrote:")
    for name, path in written.items():
        print(f"  {name}: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
