"""Research-state read-model (schema ``qm.research-state/v1``).

A small, deterministic generator that projects the research programme's durable
ledgers + campaign manifests + Kimi quota telemetry into the shared read-model
``D:/QM/reports/state/research_state.json`` consumed by Mission Control's Research
view (slice D1) and the weekly briefing (directive §69, §72 RESEARCH block,
follow-up §16).

Inputs (all injectable; every one tolerated as absent -> EVIDENCE_MISSING):

* ``campaigns_root``           -- ``D:/QM/research/campaigns/<id>/campaign.json``
  (schema ``qm.research-campaign/v1``; written by the campaign runner).
* ``research_source_ledger``   -- QM-RESEARCH mint/seal ledger (research_source.py).
* ``experiment_memory_ledger`` -- LEARN ledger (experiment_memory.py); source of the
  "most important failed lesson".
* ``kimi_quota_state``         -- real quota telemetry (kimi_quota_fetcher.py).
* ``kimi_governor_state``      -- derived NORMAL/CONSERVE/EXHAUSTED + usage_source.

No LLM call, no farm-DB write, no network. Pure file reads -> one JSON write.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

RESEARCH_STATE_SCHEMA = "qm.research-state/v1"
CAMPAIGN_SCHEMA = "qm.research-campaign/v1"

DEFAULT_STATE_DIR = Path(r"D:\QM\reports\state")
DEFAULT_CAMPAIGNS_ROOT = Path(r"D:\QM\research\campaigns")
DEFAULT_OUT = DEFAULT_STATE_DIR / "research_state.json"

# The permanent research programmes (directive §38, §45, §46, §47, §50). This is
# the charter's fixed programme roster, not invented state; each carries the
# provider that originates/owns it.
_PROGRAMME_ROSTER: tuple[tuple[str, str], ...] = (
    ("external_edge_harvest", "antigravity"),
    ("internal_edge_discovery", "fable+kimi"),
    ("failure_mining", "kimi"),
    ("white_space_research", "fable"),
    ("ftmo_gap_research", "kimi"),
)

# Hypothesis lifecycle buckets (directive §43 loop stages).
_HYPOTHESIS_BUCKETS = ("new", "under_criticism", "preregistered", "mechanized", "falsified")


def _utc_now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _read_json(path: Path) -> Any:
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError:
        return rows
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        if isinstance(obj, dict):
            rows.append(obj)
    return rows


def _load_campaigns(campaigns_root: Path) -> list[dict[str, Any]]:
    """Read every ``<id>/campaign.json`` under the campaigns root (sorted by id)."""
    out: list[dict[str, Any]] = []
    root = Path(campaigns_root)
    if not root.is_dir():
        return out
    for child in sorted(root.iterdir(), key=lambda p: p.name):
        manifest = child / "campaign.json"
        if not manifest.is_file():
            continue
        data = _read_json(manifest)
        if isinstance(data, dict):
            out.append(data)
    return out


def _campaign_summary(camp: dict[str, Any]) -> dict[str, Any]:
    return {
        "campaign_id": camp.get("campaign_id") or "UNKNOWN",
        "question": camp.get("question") or "EVIDENCE_MISSING",
        "status": camp.get("status") or "UNKNOWN",
        "artifact": camp.get("artifact") or "EVIDENCE_MISSING",
        "sealed": bool(camp.get("sealed")),
        "critic_provider": camp.get("critic_provider") or "NOT_EVALUATED",
        "critic_verdict": camp.get("critic_verdict") or "NOT_EVALUATED",
    }


def _bucket_hypotheses(campaigns: list[dict[str, Any]]) -> dict[str, list[str]]:
    buckets: dict[str, list[str]] = {name: [] for name in _HYPOTHESIS_BUCKETS}
    for camp in campaigns:
        cid = camp.get("campaign_id") or "UNKNOWN"
        for hyp in camp.get("hypotheses") or []:
            if not isinstance(hyp, dict):
                continue
            status = str(hyp.get("status") or "").strip().lower()
            hid = f"{cid}/{hyp.get('id') or hyp.get('hypothesis_id') or '?'}"
            if status in buckets:
                buckets[status].append(hid)
    for name in buckets:
        buckets[name] = sorted(set(buckets[name]))
    return buckets


def _most_important_failed_lesson(
    experiment_rows: list[dict[str, Any]], campaigns: list[dict[str, Any]]
) -> str:
    """Deterministic pick of the single most important negative lesson.

    Prefers an experiment-memory row explicitly carrying a ``lesson`` on a
    falsified/negative observation (latest by ts); else the last campaign-declared
    lesson; else EVIDENCE_MISSING. Never invented.
    """
    candidates: list[tuple[str, str]] = []  # (sort_key, lesson_text)
    for row in experiment_rows:
        verdict = str(row.get("verdict") or "").upper()
        lesson = str(row.get("lesson") or row.get("negative_finding") or "").strip()
        if not lesson:
            continue
        if verdict.startswith(("FAIL", "FALSIF", "NEGATIVE", "RETIR")) or row.get("falsified"):
            candidates.append((str(row.get("ts_utc") or row.get("ts") or ""), lesson))
    if candidates:
        candidates.sort(key=lambda t: t[0])
        return candidates[-1][1]
    # Fall back to a campaign-declared lesson.
    camp_lessons: list[str] = []
    for camp in campaigns:
        for lesson in camp.get("lessons") or []:
            if str(lesson).strip():
                camp_lessons.append(str(lesson).strip())
    if camp_lessons:
        return camp_lessons[-1]
    return "EVIDENCE_MISSING"


def _kimi_quota(
    quota_state_path: Path, governor_state_path: Path
) -> dict[str, Any]:
    """Fold the real Kimi quota telemetry + governor state (no network fetch)."""
    quota = _read_json(quota_state_path)
    gov = _read_json(governor_state_path)

    usage_source = "UNKNOWN"
    state = "UNKNOWN"
    if isinstance(gov, dict):
        usage_source = str(gov.get("usage_source") or "UNKNOWN")
        state = str(gov.get("state") or gov.get("quota_state") or "UNKNOWN")

    real: dict[str, Any] | None = None
    if isinstance(quota, dict) and str(quota.get("fetch_status")) == "ok":
        def _ratio(block: Any) -> Any:
            if isinstance(block, dict) and block.get("used_ratio") is not None:
                return block.get("used_ratio")
            return None

        real = {
            "plan": quota.get("plan"),
            "source": quota.get("source"),
            "source_timestamp": quota.get("source_timestamp"),
            "monthly_used_ratio": _ratio(quota.get("monthly")),
            "rolling_5h_used_ratio": _ratio(quota.get("rolling_5h")),
            "rolling_7d_used_ratio": _ratio(quota.get("rolling_7d")),
            "extra_quota_active": quota.get("extra_quota_active"),
        }
    return {
        "kimi": {
            "usage_source": usage_source,
            "state": state,
            "real": real,  # None when no fresh ok fetch is on disk (honest, not invented)
        }
    }


def _universe_map_summary(path: Path) -> dict[str, Any]:
    """Compact §19 universe-map slice for Mission Control / Kimi-Fable prioritisation.

    Reads the already-generated ``strategy_universe_map.json`` read-model (written
    by ``universe_map.py``); never recomputes. Absent -> EVIDENCE_MISSING so the
    research view degrades gracefully.
    """
    model = _read_json(path)
    if not isinstance(model, dict) or model.get("schema") != "qm.strategy-universe-map/v1":
        return {"status": "EVIDENCE_MISSING", "path": str(path)}
    da = model.get("directive_answers") or {}

    def _share(block: Any) -> Any:
        return block.get("share_pct") if isinstance(block, dict) else None

    def _count(block: Any) -> Any:
        return block.get("count") if isinstance(block, dict) else None

    return {
        "status": "PRESENT",
        "generated_at_utc": model.get("generated_at_utc"),
        "inputs_sha256": model.get("inputs_sha256"),
        "totals": model.get("totals"),
        "breakout_share_pct": _share(da.get("breakout_derivative_share")),
        "mean_reversion_pairs": _count(da.get("mean_reversion")),
        "short_duration_fx_pairs": _count(da.get("short_duration_fx_systems")),
        "gold_share_pct": _share(da.get("gold_share")),
        "session_tagged_pct": _share(da.get("session_diversification")),
        "high_density_ftmo_pairs": _count(da.get("high_density_ftmo_systems")),
        "top_whitespace": (model.get("whitespace_ranked") or [])[:5],
    }


def _roi_summary(path: Path) -> dict[str, Any]:
    """Compact §20/§49 ROI slice from the generated ``research_roi.json`` read-model."""
    model = _read_json(path)
    if not isinstance(model, dict) or model.get("schema") != "qm.research-roi/v1":
        return {"status": "EVIDENCE_MISSING", "path": str(path)}
    programmes = {
        p.get("origin_programme"): {
            "registry_eas": (p.get("funnel") or {}).get("registry_eas"),
            "reached_q02": (p.get("funnel") or {}).get("reached_q02"),
            "reached_q08": (p.get("funnel") or {}).get("reached_q08"),
            "reached_q14": (p.get("funnel") or {}).get("reached_q14"),
            "book_admission_total": (p.get("book_admission") or {}).get("total"),
            "yield_admit_per_q02_pct": p.get("yield_admit_per_q02_pct"),
        }
        for p in (model.get("programmes") or [])
        if p.get("is_directive_roi_programme") or ((p.get("funnel") or {}).get("registry_eas") or 0) > 0
    }
    return {
        "status": "PRESENT",
        "generated_at_utc": model.get("generated_at_utc"),
        "inputs_sha256": model.get("inputs_sha256"),
        "origin_distribution": (model.get("origin_derivation") or {}).get("origin_distribution"),
        "sources_considered": model.get("sources_considered"),
        "economic_contribution_pnl": "EVIDENCE_MISSING",
        "programmes": programmes,
    }


def _programme_status(name: str, campaigns: list[dict[str, Any]]) -> str:
    """A programme is ACTIVE once it has at least one campaign, else PLANNED."""
    key = name.replace("_research", "").replace("_", "-")
    for camp in campaigns:
        cid = str(camp.get("campaign_id") or "").lower()
        prog = str(camp.get("programme") or "").lower()
        if key in cid or key in prog or name in prog:
            return "ACTIVE"
    # External harvest + internal discovery are permanently running programmes.
    if name in {"external_edge_harvest", "internal_edge_discovery"}:
        return "ACTIVE"
    return "PLANNED"


def build_research_state(
    *,
    campaigns_root: Path | str = DEFAULT_CAMPAIGNS_ROOT,
    research_source_ledger: Path | str = DEFAULT_STATE_DIR / "research_source_ledger.jsonl",
    experiment_memory_ledger: Path | str = DEFAULT_STATE_DIR / "experiment_memory_ledger.jsonl",
    kimi_quota_state: Path | str = DEFAULT_STATE_DIR / "kimi_quota_state.json",
    kimi_governor_state: Path | str = DEFAULT_STATE_DIR / "kimi_governor_state.json",
    universe_map_state: Path | str = DEFAULT_STATE_DIR / "strategy_universe_map.json",
    research_roi_state: Path | str = DEFAULT_STATE_DIR / "research_roi.json",
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Assemble the ``qm.research-state/v1`` read-model dict deterministically."""

    campaigns = _load_campaigns(Path(campaigns_root))
    experiment_rows = _read_jsonl(Path(experiment_memory_ledger))
    # research_source_ledger is read for completeness/provenance context; the
    # authoritative per-hypothesis lifecycle lives in the campaign manifests.
    source_rows = _read_jsonl(Path(research_source_ledger))

    programmes = [
        {
            "name": name,
            "status": _programme_status(name, campaigns),
            "owner_provider": provider,
        }
        for name, provider in _PROGRAMME_ROSTER
    ]

    return {
        "schema": RESEARCH_STATE_SCHEMA,
        "generated_at_utc": (now.isoformat() if now else _utc_now_iso()),
        "programmes": programmes,
        "kimi_campaigns": [_campaign_summary(c) for c in campaigns],
        "hypotheses": _bucket_hypotheses(campaigns),
        "most_important_failed_lesson": _most_important_failed_lesson(experiment_rows, campaigns),
        "quota": _kimi_quota(Path(kimi_quota_state), Path(kimi_governor_state)),
        "universe_map": _universe_map_summary(Path(universe_map_state)),
        "roi": _roi_summary(Path(research_roi_state)),
        "counts": {
            "campaigns": len(campaigns),
            "research_source_ledger_rows": len(source_rows),
            "experiment_memory_rows": len(experiment_rows),
        },
    }


def write_research_state(out_path: Path | str = DEFAULT_OUT, **kwargs: Any) -> dict[str, Any]:
    """Build + write the read-model JSON; returns the model dict."""
    model = build_research_state(**kwargs)
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(model, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    return model


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--campaigns-root", type=Path, default=DEFAULT_CAMPAIGNS_ROOT)
    parser.add_argument("--research-source-ledger", type=Path,
                        default=DEFAULT_STATE_DIR / "research_source_ledger.jsonl")
    parser.add_argument("--experiment-memory-ledger", type=Path,
                        default=DEFAULT_STATE_DIR / "experiment_memory_ledger.jsonl")
    parser.add_argument("--kimi-quota-state", type=Path,
                        default=DEFAULT_STATE_DIR / "kimi_quota_state.json")
    parser.add_argument("--kimi-governor-state", type=Path,
                        default=DEFAULT_STATE_DIR / "kimi_governor_state.json")
    parser.add_argument("--universe-map-state", type=Path,
                        default=DEFAULT_STATE_DIR / "strategy_universe_map.json")
    parser.add_argument("--research-roi-state", type=Path,
                        default=DEFAULT_STATE_DIR / "research_roi.json")
    args = parser.parse_args(argv)
    model = write_research_state(
        out_path=args.out,
        campaigns_root=args.campaigns_root,
        research_source_ledger=args.research_source_ledger,
        experiment_memory_ledger=args.experiment_memory_ledger,
        kimi_quota_state=args.kimi_quota_state,
        kimi_governor_state=args.kimi_governor_state,
        universe_map_state=args.universe_map_state,
        research_roi_state=args.research_roi_state,
    )
    print(json.dumps({
        "out": str(args.out),
        "campaigns": model["counts"]["campaigns"],
        "quota_usage_source": model["quota"]["kimi"]["usage_source"],
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
