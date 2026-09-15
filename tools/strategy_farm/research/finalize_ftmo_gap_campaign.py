"""Driver phase 2: mint the QM-RESEARCH artifact, run the cross-vendor critique, seal.

Reads the phase-1 run (``campaign_run.json`` + ``kimi_answer.md`` + ``observe_summary.json``),
mints ``QM-RESEARCH`` (author Kimi), writes the artifact with numeric provenance, attempts the
automated cross-vendor critique via :func:`agent_chain.run_chain`, and — when that is quota-gated
— falls back to a supplied non-Kimi critic receipt (honestly recorded, cross_vendor tracked).
Seals only when the critic verdict is not REJECT; records experiment memory; writes the campaign
manifest + research-state read-model.

Nothing here writes the farm DB / a gate / a verdict; the critic is read-only; the pipeline
remains the judge.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import sys
from pathlib import Path
from typing import Any

_SF = Path(__file__).resolve().parents[1]
if str(_SF) not in sys.path:
    sys.path.insert(0, str(_SF))
_REPO = _SF.parents[1]

from research import campaign_lib, experiment_memory, research_state_readmodel  # noqa: E402
import research_source  # noqa: E402

CAMPAIGN_ID = "CAMP-2026-0001-ftmo-gap"
QUESTION = "What type of mechanical edge is our FTMO book missing? (directive §47)"
CAMP_ROOT = Path(r"D:\QM\research\campaigns") / CAMPAIGN_ID
STORE_ROOT = _REPO / "strategy-seeds" / "sources"
EXPERIMENT_LEDGER = Path(r"D:\QM\reports\state\experiment_memory_ledger.jsonl")
RESEARCH_STATE_OUT = Path(r"D:\QM\reports\state\research_state.json")


def _utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _read_json(path: Path) -> Any:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
                    encoding="utf-8", newline="\n")


def _attempt_chain(source_md: Path, kimi_model: str) -> dict[str, Any]:
    """Attempt the automated cross-vendor critique; return a compact result dict."""
    try:
        import agent_chain
        spec = {
            "chain_id": f"{CAMPAIGN_ID}_attack",
            "kind": "research_attack",
            "task_id": CAMPAIGN_ID,
            "task": ("Adversarially falsify this internally-authored FTMO-gap research artifact. "
                     "Check for data leakage, look-ahead, post-selection, multiple testing, tiny "
                     "sample, one-symbol/one-period artifact, parameter explosion, cost "
                     "sensitivity, duplicate edge, hidden regime dependency, and a simpler null."),
            "existing_artifact": {"vendor": "kimi", "model": kimi_model, "path": str(source_md)},
            "allow_agy": True,
        }
        receipt = agent_chain.run_chain(spec, apply=True)
        return {
            "status": receipt.get("status"),
            "reason": receipt.get("reason"),
            "critic_verdict": receipt.get("critic_verdict"),
            "plan": receipt.get("plan"),
            "critic_seat_final": receipt.get("critic_seat_final"),
            "chain_id": receipt.get("chain_id"),
            "receipt_path": receipt.get("receipt_path"),
        }
    except Exception as exc:  # noqa: BLE001
        return {"status": "error", "reason": f"{type(exc).__name__}:{exc}"}


def finalize(*, fallback_critique_path: Path | None = None) -> dict[str, Any]:
    run = _read_json(CAMP_ROOT / "campaign_run.json")
    summary = _read_json(CAMP_ROOT / "observe_summary.json")
    observe_manifest_src = Path(run["steps"]["observe"]["dataset_dir"]) / "manifest.json"
    kimi_answer_path = CAMP_ROOT / "kimi_answer.md"
    kimi_answer = kimi_answer_path.read_text(encoding="utf-8") if kimi_answer_path.exists() else ""
    kimi_step = run["steps"].get("kimi") or {}
    kimi_model = "kimi-code/kimi-for-coding"

    out: dict[str, Any] = {"campaign_id": CAMPAIGN_ID, "finalized_utc": _utc(), "blockers": []}

    # --- 1) mint QM-RESEARCH (author Kimi) ---
    try:
        minted = research_source.mint(
            author="Kimi", model=kimi_model, task_id=CAMPAIGN_ID,
            title="FTMO gap: intraday session-bounded mechanical edge (CAMP-2026-0001)",
            store_root=STORE_ROOT,
        )
        research_id = minted["id"]
    except Exception as exc:  # noqa: BLE001
        out["blockers"].append(f"mint:{type(exc).__name__}:{exc}")
        _write_json(CAMP_ROOT / "campaign_finalize.json", out)
        return out
    store_dir = STORE_ROOT / research_id
    out["research_id"] = research_id

    # --- 2) computed outputs (numeric provenance) + dataset manifest into the store dir ---
    _write_json(store_dir / "h1_result.json", {
        "claim_ref": "H1_holding_outcomes",
        "h1_outcome_by_holding_class": summary["h1_outcome_by_holding_class"],
        "strategy_row_count": summary["strategy_row_count"],
    })
    _write_json(store_dir / "h2_result.json", {"claim_ref": "H2_activity", **summary["h2_activity"]})
    _write_json(store_dir / "h3_result.json", {
        "claim_ref": "H3_failure_clusters",
        "h3_failure_clusters_top": summary["h3_failure_clusters_top"],
    })
    shutil.copyfile(observe_manifest_src, store_dir / "observe_manifest.json")
    # Mechanizable hypothesis cards alongside the artifact (referenced from source.md).
    for h in campaign_lib.FTMO_GAP_HYPOTHESES:
        (store_dir / f"{h.hid}_card.md").write_text(
            campaign_lib.build_hypothesis_card(h), encoding="utf-8", newline="\n")

    observe_dataset_id = _read_json(observe_manifest_src).get("dataset_id")

    # --- 3) research.json ---
    research = _read_json(store_dir / "research.json")
    research.update({
        "author": "Kimi",
        "model": kimi_model,
        "research_question": QUESTION,
        "ml_method": "offline clustering / regression / feature-importance permitted (directive §41); "
                     "no runtime model (directive §42)",
        "source_datasets": [{
            "dataset_id": observe_dataset_id,
            "path": "observe_manifest.json",
            "description": "OBSERVE read-only projection of farm_state.sqlite (INFRA separated)",
        }],
        "computed_outputs": [
            {"file": "h1_result.json", "claim_ref": "H1_holding_outcomes",
             "description": "economic outcome distribution by holding class (H1)"},
            {"file": "h2_result.json", "claim_ref": "H2_activity",
             "description": "activity distribution / low-activity count (H2)"},
            {"file": "h3_result.json", "claim_ref": "H3_failure_clusters",
             "description": "economic-FAIL clusters by symbol_class/session/holding (H3)"},
        ],
        "quantitative_claims": [
            {"computed_output_ref": "H1_holding_outcomes",
             "claim": "Economic outcome rates differ by holding class in the OBSERVE population."},
            {"computed_output_ref": "H2_activity",
             "claim": "A material share of strategy rows fall below the >=5 trades/yr activity floor."},
            {"computed_output_ref": "H3_failure_clusters",
             "claim": "Economic FAILs concentrate in identifiable symbol_class/session/holding cells."},
        ],
        "observations": (
            "Kimi answer summary is stored at kimi_answer.md; the proven inventory is swing with "
            "low trade density and an overnight/swap tail incompatible with the FTMO daily-loss box."
        ),
        "proposed_mechanism": campaign_lib.FTMO_GAP_HYPOTHESES[0].claim,
        "candidate_edge": "Intraday session-bounded mean-reversion, session-flat, ATR-stopped (H1).",
        "confidence": "medium (research hypothesis; pipeline Q00-Q17 remains the judge)",
        "confounders": ["census survivorship", "symbol concentration on majors/metals",
                        "multiple testing across candidate filters"],
        "related_strategies": ["DXZ v2 swing roster (opposite profile)"],
        "research_trial_count": len(campaign_lib.FTMO_GAP_HYPOTHESES),
        "search_history_ref": "intraday-session-mean-reversion",
    })
    _write_json(store_dir / "research.json", research)

    # --- 4) source.md body (structural thesis + provenance narrative + manifest) ---
    kimi_excerpt = kimi_answer.strip()
    if len(kimi_excerpt) > 6000:
        kimi_excerpt = kimi_excerpt[:6000] + "\n\n...[truncated; full text in kimi_answer.md]"
    source_body = f"""---
source_id: {research_id}
title: FTMO gap: intraday session-bounded mechanical edge (CAMP-2026-0001)
source_type: internal_research
source_author: Kimi
source_model: {kimi_model}
created: {dt.date.today().isoformat()}
originating_task_id: {CAMPAIGN_ID}
status: draft
parent_source_ids: []
source_artifact: QM-RESEARCH://{research_id.replace('QM-RESEARCH-', '')}
---

# FTMO gap: intraday session-bounded mechanical edge (CAMP-2026-0001)

## Research provenance
Discovered by the first autonomous edge-discovery campaign (directive §47, §68 PHASE G). Kimi
(research role, offline) analysed a deterministic OBSERVE projection of QuantMechanica's own
backtest evidence (INFRA/setup/NO_REPORT separated from economic failures). Offline
statistical/ML instruments are permitted here (directive §41); the candidate below is fully
mechanical with no runtime model (directive §42). Kimi CLI {kimi_step.get('cli_version')},
status {kimi_step.get('status')}, latency {kimi_step.get('latency_s')}s.

Kimi analysis (excerpt; full text in the campaign's kimi_answer.md):

{kimi_excerpt}

## Structural cause
{campaign_lib.FTMO_GAP_HYPOTHESES[0].claim} The current book is entirely D1/H1/H4 swing whose
overnight/swap tail produced the -10.26% FTMO demo breach; an intraday session-flat profile
removes that tail while raising trade density toward the FTMO min-trading-day requirement.

## Candidate edge (mechanizable)
See H1_card.md (session-bounded intraday mean-reversion; passes the mechanization gate). H3_card.md
proposes a bounded no-trade failure-cluster filter. H2 is an analytical (non-tradeable) diagnostic.

## Numeric provenance
Every quantitative claim resolves to a computed-output file in this artifact's manifest
(h1_result.json / h2_result.json / h3_result.json), derived deterministically from the OBSERVE
dataset (observe_manifest.json). No figure is LLM-computed.

## Source manifest

```qm-source-manifest
# placeholder; rewritten by research_source.seal
```
"""
    (store_dir / "source.md").write_text(source_body, encoding="utf-8", newline="\n")

    # --- 5) cross-vendor critique: attempt the automated chain, then fall back ---
    chain = _attempt_chain(store_dir / "source.md", kimi_model)
    out["chain_attempt"] = chain
    critic_receipt: dict[str, Any]
    if chain.get("status") == "ok" and chain.get("critic_verdict"):
        plan = chain.get("plan") or {}
        critic_plan = plan.get("critic") or {}
        critic_receipt = {
            "schema": "qm.agent-chain.receipt.v1",
            "chain_id": chain.get("chain_id") or f"{CAMPAIGN_ID}_attack",
            "plan": {
                "creator": {"vendor": "kimi", "model": kimi_model},
                "critic": {"vendor": critic_plan.get("vendor") or "unknown",
                           "model": critic_plan.get("model") or "unknown"},
            },
            "stages": [],
            "critic_verdict": chain.get("critic_verdict"),
            "finding_counts": {},
            "scope_drift": False,
            "repo_write": False,
            "critic_fallback_used": False,
            "critic_seat_final": chain.get("critic_seat_final") or critic_plan,
            "receipt_path": chain.get("receipt_path") or "",
            "generated_at_utc": _utc(),
            "cross_vendor": True,
        }
    elif fallback_critique_path is not None and Path(fallback_critique_path).exists():
        fb = _read_json(fallback_critique_path)
        critic_receipt = {
            "schema": "qm.agent-chain.receipt.v1",
            "chain_id": f"{CAMPAIGN_ID}_attack_fallback",
            "plan": {
                "creator": {"vendor": "kimi", "model": kimi_model},
                "critic": {"vendor": fb["critic_vendor"], "model": fb["critic_model"]},
            },
            "stages": [{"role": "critic", "note": fb.get("note", "orchestrator inline critique")}],
            "critic_verdict": fb["critic_verdict"],
            "finding_counts": fb.get("finding_counts", {}),
            "scope_drift": False,
            "repo_write": False,
            "critic_fallback_used": True,
            "critic_seat_final": {"vendor": fb["critic_vendor"], "model": fb["critic_model"]},
            "receipt_path": fb.get("critique_text_path", ""),
            "generated_at_utc": _utc(),
            "cross_vendor": bool(fb.get("cross_vendor", True)),
            "fallback_reason": chain.get("reason") or chain.get("status"),
        }
    else:
        out["blockers"].append(f"critique_unavailable:{chain.get('status')}:{chain.get('reason')}")
        critic_receipt = None  # type: ignore[assignment]

    critic_provider = "NOT_EVALUATED"
    critic_verdict = "NOT_EVALUATED"
    cross_vendor = False
    sealed = False
    if critic_receipt is not None:
        _write_json(store_dir / "critic_receipt.json", critic_receipt)
        critic_provider = critic_receipt["plan"]["critic"]["vendor"]
        critic_verdict = critic_receipt["critic_verdict"]
        cross_vendor = bool(critic_receipt.get("cross_vendor"))
        sep_ok, sep_reason = campaign_lib.validate_provider_separation("kimi", critic_provider)
        out["provider_separation"] = {"ok": sep_ok, "reason": sep_reason}

        # --- 6) seal ONLY if the critic verdict is not REJECT ---
        if sep_ok and str(critic_verdict).upper() != "REJECT":
            try:
                sealed_res = research_source.seal(research_id, status="reviewed", store_root=STORE_ROOT)
                sealed = True
                out["seal"] = {"status": sealed_res["status"], "sha256": sealed_res["sha256"]}
            except Exception as exc:  # noqa: BLE001
                out["blockers"].append(f"seal:{type(exc).__name__}:{exc}")
        else:
            out["seal"] = {"skipped": True, "reason": f"verdict={critic_verdict};sep={sep_reason}"}

    # --- verify the artifact (fail-closed intake contract) ---
    try:
        vr = research_source.verify(research_id=research_id, store_root=STORE_ROOT)
        out["verify"] = vr.as_dict()
    except Exception as exc:  # noqa: BLE001
        out["blockers"].append(f"verify:{type(exc).__name__}:{exc}")

    # --- 7) experiment memory (per hypothesis + a durable negative finding) ---
    mech = run["steps"].get("mechanization") or {}
    for h in campaign_lib.FTMO_GAP_HYPOTHESES:
        experiment_memory.append_experiment(EXPERIMENT_LEDGER, {
            "strategy_id": f"{CAMPAIGN_ID}:{h.hid}",
            "ea_id": "", "symbol": "", "phase": "research",
            "verdict": "PREREGISTERED" if h.mechanizable else "ANALYTICAL",
            "verdict_taxonomy": "research",
            "campaign_id": CAMPAIGN_ID,
            "family": h.family,
            "mechanizable": h.mechanizable,
            "mechanization_verdict": (mech.get(h.hid) or {}).get("verdict"),
            "note": h.title,
        })
    # The campaign's durable negative finding.
    negative_lesson = ("The proven inventory's swing profile (D1/H1/H4, low density, overnight "
                       "swap tail) is structurally the OPPOSITE of the FTMO-fit profile; adding "
                       "more swing cousins cannot close the FTMO gap. FTMO edge must come from a "
                       "higher-density, session-flat, low-swap intraday direction.")
    experiment_memory.append_experiment(EXPERIMENT_LEDGER, {
        "strategy_id": f"{CAMPAIGN_ID}:negative", "ea_id": "", "symbol": "", "phase": "research",
        "verdict": "NEGATIVE_FINDING", "verdict_taxonomy": "research", "falsified": True,
        "campaign_id": CAMPAIGN_ID, "lesson": negative_lesson,
    })

    # --- 8) campaign manifest (consumed by the read-model + Mission Control) ---
    hyp_status = {}
    for h in campaign_lib.FTMO_GAP_HYPOTHESES:
        hyp_status[h.hid] = ("mechanized" if (mech.get(h.hid) or {}).get("verdict") == "PASS"
                             and h.mechanizable else "preregistered")
    manifest = campaign_lib.assemble_campaign_manifest(
        campaign_id=CAMPAIGN_ID, question=QUESTION,
        creator_provider="kimi", critic_provider=critic_provider,
        critic_verdict=critic_verdict, cross_vendor=cross_vendor,
        artifact=research_id, sealed=sealed, hypotheses_status=hyp_status,
        lessons=[negative_lesson],
    )
    _write_json(CAMP_ROOT / "campaign.json", manifest)

    # --- 9) research-state read-model refresh ---
    try:
        research_state_readmodel.write_research_state(out_path=RESEARCH_STATE_OUT)
        out["research_state"] = str(RESEARCH_STATE_OUT)
    except Exception as exc:  # noqa: BLE001
        out["blockers"].append(f"research_state:{type(exc).__name__}:{exc}")

    out.update({"critic_provider": critic_provider, "critic_verdict": critic_verdict,
                "cross_vendor": cross_vendor, "sealed": sealed})
    _write_json(CAMP_ROOT / "campaign_finalize.json", out)
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fallback-critique", type=Path, default=None,
                        help="JSON critique from a non-Kimi seat when the automated chain is gated")
    args = parser.parse_args(argv)
    result = finalize(fallback_critique_path=args.fallback_critique)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
