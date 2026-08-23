"""Render fail-closed public EA showcase pages from a reduced projection.

This module is deliberately separate from the internal Strategy Archive and
Strategy Card renderers.  It never reads a Strategy Card, EA source, farm DB,
deployment manifest, or live terminal.  Its sole input is a purpose-built
public projection whose exact fields are validated before any output is
written.

The renderer is staging-only.  It refuses ``public-data`` as an output target
and has no publish, git, Netlify, MQL5, MT5, or network action.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import os
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from website_archive_contract import REDACTED, scrub_text  # noqa: E402


PROJECTION_SCHEMA = "qm.public-ea-showcase-projection.v1"
RENDER_SCHEMA = "qm.public-ea-showcase-render.v1"
DEFAULT_OUT_DIR = Path(r"D:\QM\exports\website_contract_preview\ea_showcase")

_PUBLIC_ID_RE = re.compile(r"^card_[0-9a-f]{16}$")
_EVIDENCE_ID_RE = re.compile(r"^rpt_[0-9a-f]{16}$")
_SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
_UUID_RE = re.compile(
    r"\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-"
    r"[89ab][0-9a-f]{3}-[0-9a-f]{12}\b",
    re.IGNORECASE,
)
_INTERNAL_EA_RE = re.compile(r"\bQM5[-_]\d+\b", re.IGNORECASE)
_LEGACY_PHASE_RE = re.compile(r"\bP(?:\d+(?:[._]\d+)?)\b", re.IGNORECASE)
_RULE_MANUAL_RE = re.compile(
    r"(?:```|`[^`]+`|&&|\|\||==|!=|<=|>=|"
    r"\b(?:entry|exit)\s+(?:if|when)\b|"
    r"\b(?:take[- ]?profit|stop[- ]?loss)\s*(?:=|at)\b|"
    r"\b(?:parameter|lookback)\s*[=:]|"
    r"\b[A-Za-z_][A-Za-z0-9_]*\s*\([^)]*\))",
    re.IGNORECASE,
)

_TOP_KEYS = {"schema", "generated_at", "items"}
_ITEM_REQUIRED = {
    "public_id",
    "slug",
    "title",
    "eligibility",
    "thesis",
    "risk_profile",
    "behavior",
    "failure_modes",
    "evidence_chain",
    "track_records",
}
_ITEM_ALLOWED = _ITEM_REQUIRED | {"mql5_listing_url"}
_ELIGIBILITY_KEYS = {
    "in_live_book",
    "traded_live",
    "marketplace_candidate",
    "product_ea_ready",
    "rights_status",
}
_EVIDENCE_KEYS = {"evidence_id", "kind", "label", "summary"}
_TRACK_KEYS = {"evidence_id", "kind", "label", "period_label", "summary"}
_REQUIRED_EVIDENCE_KINDS = {
    "GATE_EVIDENCE",
    "OUT_OF_SAMPLE",
    "COST_MODEL",
    "DRAWDOWN",
}
_EVIDENCE_KINDS = _REQUIRED_EVIDENCE_KINDS | {
    "BACKTEST_RECORD",
    "LIVE_RECORD",
}
_TRACK_KINDS = {"BACKTEST", "LIVE"}
_TRACK_TO_EVIDENCE_KIND = {
    "BACKTEST": "BACKTEST_RECORD",
    "LIVE": "LIVE_RECORD",
}


class ShowcaseContractError(RuntimeError):
    """The reduced showcase projection is unsafe or incomplete."""


def _expect_object(value: Any, where: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ShowcaseContractError(f"{where} must be an object")
    return value


def _expect_keys(
    value: dict[str, Any],
    *,
    required: set[str],
    allowed: set[str],
    where: str,
) -> None:
    keys = set(value)
    missing = sorted(required - keys)
    extra = sorted(keys - allowed)
    if missing:
        raise ShowcaseContractError(f"{where} missing fields: {', '.join(missing)}")
    if extra:
        raise ShowcaseContractError(
            f"{where} contains non-public fields: {', '.join(extra)}"
        )


def _safe_text(
    value: Any,
    *,
    field: str,
    max_length: int,
    number_free: bool = False,
) -> str:
    if not isinstance(value, str):
        raise ShowcaseContractError(f"{field} must be text")
    text = " ".join(value.split())
    if not text:
        raise ShowcaseContractError(f"{field} must not be empty")
    if len(text) > max_length:
        raise ShowcaseContractError(f"{field} exceeds {max_length} characters")
    if scrub_text(text) != text or REDACTED in text:
        raise ShowcaseContractError(f"{field} contains a private locator or identity")
    if _UUID_RE.search(text) or _INTERNAL_EA_RE.search(text):
        raise ShowcaseContractError(f"{field} contains an internal identifier")
    if _LEGACY_PHASE_RE.search(text):
        raise ShowcaseContractError(f"{field} uses a legacy operator phase name")
    if _RULE_MANUAL_RE.search(text):
        raise ShowcaseContractError(f"{field} contains build-manual syntax")
    if number_free and re.search(r"\d", text):
        raise ShowcaseContractError(
            f"{field} contains an unevidenced numeric claim"
        )
    return text


def _parse_generated_at(value: Any) -> str:
    if not isinstance(value, str):
        raise ShowcaseContractError("generated_at must be an ISO timestamp")
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ShowcaseContractError("generated_at must be an ISO timestamp") from exc
    if parsed.tzinfo is None:
        raise ShowcaseContractError("generated_at must include a timezone")
    return value


def _validate_mql5_url(value: Any, field: str) -> str:
    if not isinstance(value, str):
        raise ShowcaseContractError(f"{field} must be a URL")
    parts = urlsplit(value)
    if (
        parts.scheme != "https"
        or parts.hostname not in {"mql5.com", "www.mql5.com"}
        or parts.username is not None
        or parts.password is not None
        or parts.port is not None
        or parts.query
        or parts.fragment
        or not re.fullmatch(r"/en/market/product/\d+/?", parts.path)
    ):
        raise ShowcaseContractError(
            f"{field} must be a clean official MQL5 Market product URL"
        )
    return value


def _validate_eligibility(value: Any, where: str) -> dict[str, Any]:
    rec = _expect_object(value, where)
    _expect_keys(
        rec,
        required=_ELIGIBILITY_KEYS,
        allowed=_ELIGIBILITY_KEYS,
        where=where,
    )
    for key in (
        "in_live_book",
        "traded_live",
        "marketplace_candidate",
        "product_ea_ready",
    ):
        if type(rec[key]) is not bool:  # bool only; integers are not accepted
            raise ShowcaseContractError(f"{where}.{key} must be boolean")
        if not rec[key]:
            raise ShowcaseContractError(f"{where}.{key} must be true")
    if rec["rights_status"] != "CLEARED":
        raise ShowcaseContractError(f"{where}.rights_status must be CLEARED")
    return dict(rec)


def _validate_evidence(value: Any, where: str) -> list[dict[str, str]]:
    if not isinstance(value, list) or not value:
        raise ShowcaseContractError(f"{where} must be a non-empty list")
    out: list[dict[str, str]] = []
    seen_ids: set[str] = set()
    kinds: set[str] = set()
    for idx, raw in enumerate(value):
        item_where = f"{where}[{idx}]"
        rec = _expect_object(raw, item_where)
        _expect_keys(
            rec,
            required=_EVIDENCE_KEYS,
            allowed=_EVIDENCE_KEYS,
            where=item_where,
        )
        evidence_id = str(rec["evidence_id"])
        if not _EVIDENCE_ID_RE.fullmatch(evidence_id):
            raise ShowcaseContractError(f"{item_where}.evidence_id is invalid")
        if evidence_id in seen_ids:
            raise ShowcaseContractError(f"duplicate evidence_id: {evidence_id}")
        kind = str(rec["kind"])
        if kind not in _EVIDENCE_KINDS:
            raise ShowcaseContractError(f"{item_where}.kind is invalid")
        seen_ids.add(evidence_id)
        kinds.add(kind)
        out.append(
            {
                "evidence_id": evidence_id,
                "kind": kind,
                "label": _safe_text(
                    rec["label"], field=f"{item_where}.label", max_length=100
                ),
                "summary": _safe_text(
                    rec["summary"], field=f"{item_where}.summary", max_length=420
                ),
            }
        )
    missing = sorted(_REQUIRED_EVIDENCE_KINDS - kinds)
    if missing:
        raise ShowcaseContractError(
            f"{where} missing required evidence classes: {', '.join(missing)}"
        )
    return out


def _validate_track_records(
    value: Any,
    evidence_by_id: dict[str, dict[str, str]],
    where: str,
) -> list[dict[str, str]]:
    if not isinstance(value, list):
        raise ShowcaseContractError(f"{where} must be a list")
    out: list[dict[str, str]] = []
    for idx, raw in enumerate(value):
        item_where = f"{where}[{idx}]"
        rec = _expect_object(raw, item_where)
        _expect_keys(
            rec,
            required=_TRACK_KEYS,
            allowed=_TRACK_KEYS,
            where=item_where,
        )
        kind = str(rec["kind"])
        if kind not in _TRACK_KINDS:
            raise ShowcaseContractError(
                f"{item_where}.kind must be BACKTEST or LIVE"
            )
        evidence_id = str(rec["evidence_id"])
        evidence = evidence_by_id.get(evidence_id)
        if evidence is None:
            raise ShowcaseContractError(
                f"{item_where} references unpublished evidence {evidence_id}"
            )
        expected_kind = _TRACK_TO_EVIDENCE_KIND[kind]
        if evidence["kind"] != expected_kind:
            raise ShowcaseContractError(
                f"{item_where} {kind} record is bound to {evidence['kind']} evidence"
            )
        out.append(
            {
                "evidence_id": evidence_id,
                "kind": kind,
                "label": _safe_text(
                    rec["label"], field=f"{item_where}.label", max_length=100
                ),
                "period_label": _safe_text(
                    rec["period_label"],
                    field=f"{item_where}.period_label",
                    max_length=100,
                ),
                "summary": _safe_text(
                    rec["summary"], field=f"{item_where}.summary", max_length=420
                ),
            }
        )
    if not any(row["kind"] == "BACKTEST" for row in out):
        raise ShowcaseContractError(f"{where} requires a BACKTEST record")
    return out


def _validate_item(value: Any, index: int) -> dict[str, Any]:
    where = f"items[{index}]"
    rec = _expect_object(value, where)
    _expect_keys(rec, required=_ITEM_REQUIRED, allowed=_ITEM_ALLOWED, where=where)

    public_id = str(rec["public_id"])
    if not _PUBLIC_ID_RE.fullmatch(public_id):
        raise ShowcaseContractError(f"{where}.public_id is invalid")
    slug = str(rec["slug"])
    if not _SLUG_RE.fullmatch(slug):
        raise ShowcaseContractError(f"{where}.slug is invalid")

    eligibility = _validate_eligibility(rec["eligibility"], f"{where}.eligibility")
    evidence = _validate_evidence(rec["evidence_chain"], f"{where}.evidence_chain")
    evidence_by_id = {row["evidence_id"]: row for row in evidence}
    track_records = _validate_track_records(
        rec["track_records"], evidence_by_id, f"{where}.track_records"
    )

    failures_raw = rec["failure_modes"]
    if not isinstance(failures_raw, list) or not (1 <= len(failures_raw) <= 6):
        raise ShowcaseContractError(
            f"{where}.failure_modes must contain one to six items"
        )
    failures = [
        _safe_text(
            item,
            field=f"{where}.failure_modes[{idx}]",
            max_length=300,
            number_free=True,
        )
        for idx, item in enumerate(failures_raw)
    ]

    out: dict[str, Any] = {
        "public_id": public_id,
        "slug": slug,
        "title": _safe_text(rec["title"], field=f"{where}.title", max_length=120),
        "eligibility": eligibility,
        "thesis": _safe_text(
            rec["thesis"],
            field=f"{where}.thesis",
            max_length=600,
            number_free=True,
        ),
        "risk_profile": _safe_text(
            rec["risk_profile"],
            field=f"{where}.risk_profile",
            max_length=500,
            number_free=True,
        ),
        "behavior": _safe_text(
            rec["behavior"],
            field=f"{where}.behavior",
            max_length=500,
            number_free=True,
        ),
        "failure_modes": failures,
        "evidence_chain": evidence,
        "track_records": track_records,
    }
    if "mql5_listing_url" in rec and rec["mql5_listing_url"] not in (None, ""):
        out["mql5_listing_url"] = _validate_mql5_url(
            rec["mql5_listing_url"], f"{where}.mql5_listing_url"
        )
    return out


def validate_projection(value: Any) -> dict[str, Any]:
    """Validate and return the exact reduced public projection."""
    root = _expect_object(value, "projection")
    _expect_keys(root, required=_TOP_KEYS, allowed=_TOP_KEYS, where="projection")
    if root["schema"] != PROJECTION_SCHEMA:
        raise ShowcaseContractError(f"schema must be {PROJECTION_SCHEMA}")
    generated_at = _parse_generated_at(root["generated_at"])
    if not isinstance(root["items"], list):
        raise ShowcaseContractError("items must be a list")
    items = [_validate_item(raw, idx) for idx, raw in enumerate(root["items"])]
    public_ids = [item["public_id"] for item in items]
    slugs = [item["slug"] for item in items]
    if len(public_ids) != len(set(public_ids)):
        raise ShowcaseContractError("public_id values must be unique")
    if len(slugs) != len(set(slugs)):
        raise ShowcaseContractError("slug values must be unique")
    return {"schema": PROJECTION_SCHEMA, "generated_at": generated_at, "items": items}


_CSS = """
:root{color-scheme:dark;--bg:#0b0e12;--panel:#121821;--line:#263142;--text:#edf2f7;--muted:#9ba9ba;--accent:#64d8cb;--live:#80e27e;--test:#f6c86d;--risk:#ff8d8d}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font-family:Inter,system-ui,sans-serif;line-height:1.6}.wrap{max-width:1040px;margin:auto;padding:48px 24px 80px}a{color:var(--accent)}h1{font-size:clamp(2rem,5vw,3.7rem);line-height:1.05;margin:.3rem 0 1.2rem}h2{margin-top:2.4rem;font-size:1.05rem;text-transform:uppercase;letter-spacing:.12em;color:var(--muted)}.eyebrow,.badge{font:700 .72rem ui-monospace,monospace;letter-spacing:.13em;text-transform:uppercase}.eyebrow{color:var(--accent)}.badges{display:flex;gap:.5rem;flex-wrap:wrap}.badge{border:1px solid var(--line);padding:.35rem .55rem}.badge.live{color:var(--live)}.badge.test{color:var(--test)}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:1rem}.card,.record{background:var(--panel);border:1px solid var(--line);padding:1.1rem}.card h3,.record h3{margin:.1rem 0 .45rem}.muted{color:var(--muted)}.risk{border-left:3px solid var(--risk)}ul{padding-left:1.25rem}.cta{display:inline-block;margin-top:1.2rem;padding:.75rem 1rem;border:1px solid var(--accent);text-decoration:none;font-weight:700}.record.test{border-color:#5a4a2b}.record.live{border-color:#315b38}.evidence-id{font:600 .7rem ui-monospace,monospace;color:var(--muted)}.index-list{display:grid;gap:.8rem;margin-top:2rem}.index-item{display:block;padding:1rem;background:var(--panel);border:1px solid var(--line);text-decoration:none}.index-item strong{color:var(--text)}
""".strip()


def _e(value: Any) -> str:
    return html.escape(str(value), quote=True)


def _render_record(record: dict[str, str]) -> str:
    kind_class = "live" if record["kind"] == "LIVE" else "test"
    label = "LIVE — REAL ACCOUNT RECORD" if record["kind"] == "LIVE" else "BACKTEST — NOT LIVE"
    return (
        f'<article class="record {kind_class}">'
        f'<span class="badge {kind_class}">{label}</span>'
        f'<h3>{_e(record["label"])}</h3>'
        f'<div class="muted">{_e(record["period_label"])}</div>'
        f'<p>{_e(record["summary"])}</p>'
        f'<div class="evidence-id">Evidence {_e(record["evidence_id"])}</div>'
        "</article>"
    )


def render_item(item: dict[str, Any]) -> str:
    evidence_html = "".join(
        '<article class="card">'
        f'<div class="eyebrow">{_e(row["kind"].replace("_", " "))}</div>'
        f'<h3>{_e(row["label"])}</h3><p>{_e(row["summary"])}</p>'
        f'<div class="evidence-id">Evidence {_e(row["evidence_id"])}</div>'
        "</article>"
        for row in item["evidence_chain"]
        if row["kind"] in _REQUIRED_EVIDENCE_KINDS
    )
    failures_html = "".join(f"<li>{_e(row)}</li>" for row in item["failure_modes"])
    backtests = [row for row in item["track_records"] if row["kind"] == "BACKTEST"]
    live = [row for row in item["track_records"] if row["kind"] == "LIVE"]
    backtest_html = "".join(_render_record(row) for row in backtests)
    live_html = (
        "".join(_render_record(row) for row in live)
        if live
        else '<div class="card muted">No public live track record is attached. Backtest evidence above remains labelled as backtest.</div>'
    )
    listing = item.get("mql5_listing_url")
    listing_html = (
        f'<a class="cta" rel="noopener noreferrer nofollow" href="{_e(listing)}">View the EA on MQL5</a>'
        if listing
        else '<p class="muted">MQL5 listing pending.</p>'
    )
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{_e(item['title'])} · QuantMechanica</title><style>{_CSS}</style></head>
<body><main class="wrap">
<a href="index.html">← EA showcases</a>
<div class="eyebrow">QuantMechanica · public EA showcase</div>
<h1>{_e(item['title'])}</h1>
<div class="badges"><span class="badge live">Live-book strategy</span><span class="badge live">Rights cleared</span><span class="badge">Marketplace candidate</span></div>
{listing_html}
<h2>Why the edge may exist</h2><p>{_e(item['thesis'])}</p>
<div class="grid"><article class="card"><h2>Risk profile</h2><p>{_e(item['risk_profile'])}</p></article><article class="card"><h2>How it behaves</h2><p>{_e(item['behavior'])}</p></article></div>
<h2>Evidence chain</h2><div class="grid">{evidence_html}</div>
<h2>Where it can fail</h2><article class="card risk"><ul>{failures_html}</ul></article>
<h2>Backtest record</h2><div class="grid">{backtest_html}</div>
<h2>Live track record</h2><div class="grid">{live_html}</div>
</main></body></html>"""


def render_index(projection: dict[str, Any]) -> str:
    links = "".join(
        f'<a class="index-item" href="{_e(item["slug"])}.html">'
        f'<strong>{_e(item["title"])}</strong><br>'
        '<span class="muted">Live-book strategy · rights cleared · marketplace candidate</span></a>'
        for item in projection["items"]
    )
    if not links:
        links = (
            '<div class="card muted">No EA currently satisfies all publication gates: '
            "live-book membership, traded-live evidence, product readiness, marketplace candidacy, and per-EA rights clearance.</div>"
        )
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>EA Showcases · QuantMechanica</title><style>{_CSS}</style></head>
<body><main class="wrap"><div class="eyebrow">QuantMechanica</div><h1>EA showcases</h1>
<p class="muted">A deliberately reduced public surface for strategies that are both in the live book and eligible for an MQL5 product page.</p>
<div class="index-list">{links}</div></main></body></html>"""


def _assert_staging_target(out_dir: Path) -> None:
    resolved = out_dir.resolve()
    public_data = (REPO_ROOT / "public-data").resolve()
    if resolved == public_data or public_data in resolved.parents:
        raise ShowcaseContractError("renderer is staging-only; public-data is forbidden")


def _atomic_write(path: Path, content: str) -> None:
    temp = path.with_name(f".{path.name}.tmp")
    temp.write_text(content, encoding="utf-8", newline="\n")
    os.replace(temp, path)


def render_projection(value: Any, out_dir: Path) -> dict[str, Any]:
    """Validate all input, then render one immutable projection directory."""
    projection = validate_projection(value)
    _assert_staging_target(out_dir)
    canonical = json.dumps(projection, sort_keys=True, separators=(",", ":"))
    render_id = hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:16]
    target = out_dir / f"render_{render_id}"
    target.mkdir(parents=True, exist_ok=True)

    pages = [(item["slug"], render_item(item)) for item in projection["items"]]
    _atomic_write(target / "index.html", render_index(projection))
    for slug, content in pages:
        _atomic_write(target / f"{slug}.html", content)

    manifest = {
        "schema": RENDER_SCHEMA,
        "source_schema": PROJECTION_SCHEMA,
        "source_generated_at": projection["generated_at"],
        "render_id": render_id,
        "pages": [
            {
                "public_id": item["public_id"],
                "slug": item["slug"],
                "has_live_track_record": any(
                    row["kind"] == "LIVE" for row in item["track_records"]
                ),
                "has_mql5_listing": bool(item.get("mql5_listing_url")),
            }
            for item in projection["items"]
        ],
    }
    _atomic_write(
        target / "manifest.json",
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    )
    return {"render_dir": str(target), "render_id": render_id, "pages": len(pages)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--projection", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args(argv)
    try:
        value = json.loads(args.projection.read_text(encoding="utf-8-sig"))
        result = render_projection(value, args.out_dir)
    except (OSError, json.JSONDecodeError, ShowcaseContractError) as exc:
        print(f"PUBLIC_EA_SHOWCASE_REFUSED: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
