"""Driver: run the first autonomous edge-discovery campaign for real.

CAMP-2026-0001-ftmo-gap (directive §47, §68 PHASE G, follow-up §16). This is the LIVE
orchestrator: it builds the OBSERVE dataset read-only, preregisters H1-H3, commissions Kimi
on the dataset, runs the governor telemetry, mints the QM-RESEARCH artifact, runs the
mechanization gate, and attempts the cross-vendor critique. Deterministic logic lives in
:mod:`campaign_lib`; the LLM-free tests cover that. Every step records an honest blocker on
failure and still produces a durable artifact (at minimum a negative finding).

Nothing here writes the farm DB, changes a gate, starts terminal64, or spends a critic call
that a quota flag forbids (the critique degrades to a recorded fallback).

Usage (phase 1 = OBSERVE..mint..mechanize..attempt-chain):
    python tools/strategy_farm/research/run_ftmo_gap_campaign.py run [--kimi-timeout 1500]
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

from research import (  # noqa: E402
    campaign_lib,
    mechanization_check,
    observe_projector,
    preregister,
    research_env,
    search_history_ledger,
)
import research_source  # noqa: E402

CAMPAIGN_ID = "CAMP-2026-0001-ftmo-gap"
QUESTION = "What type of mechanical edge is our FTMO book missing? (directive §47)"
REAL_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
CAMP_ROOT = Path(r"D:\QM\research\campaigns") / CAMPAIGN_ID
STORE_ROOT = _REPO / "strategy-seeds" / "sources"  # canonical, resolvable by intake
SEARCH_LEDGER = Path(r"D:\QM\reports\state\search_history_ledger.jsonl")


def _utc() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")


def _param_space_size(ranges: dict[str, str], steps: int = 10) -> int:
    """Coarse finite grid size for the search-history ledger (evidence only)."""
    size = 1
    for _ in ranges:
        size *= steps
    return min(size, 10 ** 9)


def build_kimi_prompt(observe_manifest: dict[str, Any], summary: dict[str, Any]) -> str:
    hyps = "\n".join(
        f"- {h.hid} [{h.family}]: {h.claim}\n    Refuted if: {h.refutation}"
        for h in campaign_lib.FTMO_GAP_HYPOTHESES
    )
    return f"""You are Kimi, a quantitative research provider inside QuantMechanica. You are doing
OFFLINE research only. Machine learning / statistics ARE permitted here (clustering,
regression, feature importance, regime identification) but the RESULT must be a MECHANICAL,
finite-parameter trading rule with NO runtime model, no inference API, no online learning
(directive §41/§42). Do NOT propose random indicator soup (§40).

MISSION (directive §47): FTMO is QuantMechanica's larger strategic gap. No current candidate
has FTMO fitness: the Q10 FTMO gate admits 0 of 42 pairs, the best FUND_SCORE is 0.41 vs a
1.0 floor, and the only real FTMO evidence is a demo that lost -9.95% and BREACHED the 10%
total-loss limit with an overnight/swap tail. The proven inventory is D1/H1/H4 swing with low
trade density. FTMO rewards: short holding, low swap, bounded daily loss, higher trade
density, high probability of completing the Challenge (not standalone profit factor).

You are given a deterministic OBSERVE dataset (read-only projection of QuantMechanica's own
backtest evidence; INFRA/setup/NO_REPORT failures are kept separate from economic failures)
and a computed summary. Do not invent numbers; ground every quantitative claim in the summary
or the dataset.

OBSERVE dataset manifest (content-addressed):
{json.dumps({k: observe_manifest.get(k) for k in ('dataset_dir', 'dataset_id', 'row_counts', 'verdict_taxonomy_split')}, indent=2)}

Deterministic OBSERVE summary (computed by campaign_lib.compute_observe_summary):
{json.dumps(summary, indent=2)}

Preregistered hypotheses to evaluate:
{hyps}

Deliver, in clear Markdown:
1. An evidence-backed answer to EACH of H1, H2, H3 (support / refute / inconclusive), citing
   the summary figures you rely on and naming the confound you are most worried about.
2. At least ONE mechanizable hypothesis for a high-density / short-holding / low-swap
   mechanical FTMO edge, grounded in the OBSERVE data (session/liquidity/volatility/regime
   reasoning — not random indicator combinations). State its structural cause, the exact
   mechanical entry/exit/stop/session/filter rules, finite bounded parameter ranges, timeframe,
   symbol assumptions, expected frequency, and its falsification/kill criteria.
3. Explicit NEGATIVE findings: which of these directions the evidence argues AGAINST, and what
   the failures collectively teach about where an FTMO edge is unlikely to be.

Be concise and specific. This is research input to a cross-vendor critic and the Q00-Q17
pipeline, which remain the final judge.
"""


def phase1(kimi_timeout: int = 1500) -> dict[str, Any]:
    CAMP_ROOT.mkdir(parents=True, exist_ok=True)
    run: dict[str, Any] = {
        "schema": "qm.campaign-run/v1",
        "campaign_id": CAMPAIGN_ID,
        "started_utc": _utc(),
        "steps": {},
        "blockers": [],
    }

    # --- research guard (informational; the OBSERVE projection is a light read-only job) ---
    try:
        guard = research_env.research_guard(research_scratch=CAMP_ROOT)
        run["steps"]["research_guard"] = guard.as_dict()
    except Exception as exc:  # noqa: BLE001
        run["blockers"].append(f"research_guard:{type(exc).__name__}:{exc}")

    # --- OBSERVE (read-only) ---
    observe_dir = CAMP_ROOT / "observe"
    try:
        manifest = observe_projector.project(REAL_DB, observe_dir)
        run["steps"]["observe"] = {
            "dataset_dir": manifest["dataset_dir"],
            "dataset_id": manifest["dataset_id"],
            "row_counts": manifest["row_counts"],
        }
        dataset_dir = Path(manifest["dataset_dir"])
    except Exception as exc:  # noqa: BLE001
        run["blockers"].append(f"observe:{type(exc).__name__}:{exc}")
        _write_json(CAMP_ROOT / "campaign_run.json", run)
        return run

    # --- deterministic OBSERVE summary (computed outputs, numeric provenance) ---
    summary = campaign_lib.compute_observe_summary(dataset_dir)
    _write_json(CAMP_ROOT / "observe_summary.json", summary)
    run["steps"]["observe_summary"] = {"strategy_row_count": summary["strategy_row_count"]}

    # --- PREREGISTER H1-H3 (immutable; discovery vs holdout recorded) ---
    prereg_dir = CAMP_ROOT / "preregistration"
    prereg_records = []
    for h in campaign_lib.FTMO_GAP_HYPOTHESES:
        spec_text = campaign_lib.build_hypothesis_card(h)
        record = preregister.build_preregistration(
            research_id=f"{CAMPAIGN_ID}:{h.hid}",
            hypothesis=h.claim,
            mechanical_spec=spec_text,
            parameter_ranges=h.parameter_ranges,
            discovery_sample=h.discovery_sample,
            validation_sample=h.validation_sample,
            holdout_logic="discovery on in-sample years; validation years never touched at discovery",
            expected_behaviour=h.title,
            success_criteria="improves simulated FTMO first-passage / daily-loss survival out of sample",
            failure_criteria=h.refutation,
            known_risks=h.known_risks or "data-snooping; symbol/period concentration",
        )
        preregister.write_preregistration(prereg_dir / h.hid, record,
                                          ledger_path=CAMP_ROOT / "preregistration_ledger.jsonl")
        prereg_records.append({"hid": h.hid, "record_sha256": record["record_sha256"]})
        # search-history ledger: one row per preregistered family (holdout untouched).
        try:
            search_history_ledger.append_search(SEARCH_LEDGER, {
                "campaign_id": CAMPAIGN_ID,
                "hypothesis_family": h.family,
                "dataset_id": manifest["dataset_id"],
                "period": h.discovery_sample,
                "instruments": ["EURUSD", "XAUUSD", "GBPUSD", "USDJPY"],
                "feature_families": ["session", "volatility_regime", "mean_reversion"],
                "parameter_space_size": _param_space_size(h.parameter_ranges),
                "holdout_id": f"{CAMPAIGN_ID}:{h.hid}:2021-2024",
                "holdout_touched": False,
                "outcome": "preregistered",
            })
        except Exception as exc:  # noqa: BLE001
            run["blockers"].append(f"search_ledger:{h.hid}:{type(exc).__name__}:{exc}")
    run["steps"]["preregister"] = prereg_records

    # --- DISCOVER: real Kimi call ---
    kimi_out = CAMP_ROOT / "kimi"
    kimi_out.mkdir(parents=True, exist_ok=True)
    prompt = build_kimi_prompt(manifest, summary)
    (CAMP_ROOT / "kimi_prompt.md").write_text(prompt, encoding="utf-8", newline="\n")
    kimi_result: dict[str, Any] = {}
    try:
        import kimi_adapter  # imported here so the module stays importable without Kimi
        kimi_result = kimi_adapter.run_kimi(
            prompt, role="research", capability="research", task_id=CAMPAIGN_ID,
            cwd=kimi_out, add_dirs=[observe_dir], timeout_s=kimi_timeout, out_dir=kimi_out,
        )
        run["steps"]["kimi"] = {
            "status": kimi_result.get("status"),
            "latency_s": kimi_result.get("latency_s"),
            "cli_version": kimi_result.get("cli_version"),
            "prompt_sha256": kimi_result.get("prompt_sha256"),
            "output_sha256": kimi_result.get("output_sha256"),
            "protected_write": kimi_result.get("protected_write"),
            "changed_paths": kimi_result.get("changed_paths"),
            "error": kimi_result.get("error"),
        }
        kimi_text = kimi_result.get("text") or ""
        (CAMP_ROOT / "kimi_answer.md").write_text(kimi_text, encoding="utf-8", newline="\n")
        if kimi_result.get("status") not in ("ok", "protected_write") or not kimi_text.strip():
            run["blockers"].append(f"kimi:{kimi_result.get('status')}:{kimi_result.get('error')}")
    except Exception as exc:  # noqa: BLE001
        run["blockers"].append(f"kimi:{type(exc).__name__}:{exc}")
        kimi_text = ""

    # --- governor telemetry after the (token-refreshing) call ---
    try:
        import kimi_governor
        info = kimi_governor.evaluate(kimi_governor.load_config(), dry_run=True, fetch=True)
        run["steps"]["kimi_governor"] = {
            "state": info.get("state"),
            "usage_source": info.get("usage_source"),
            "quota_fetch_status": info.get("quota_fetch_status"),
            "real": info.get("real") or info.get("quota_state"),
        }
    except Exception as exc:  # noqa: BLE001
        run["blockers"].append(f"kimi_governor:{type(exc).__name__}:{exc}")

    # --- MECHANIZE each preregistered card ---
    mech: dict[str, Any] = {}
    for h in campaign_lib.FTMO_GAP_HYPOTHESES:
        card_text = campaign_lib.build_hypothesis_card(h)
        card_path = kimi_out / f"{h.hid}_card.md"
        card_path.write_text(card_text, encoding="utf-8", newline="\n")
        res = mechanization_check.check_spec(card_path)
        mech[h.hid] = {"verdict": res["verdict"], "findings": res["findings"],
                       "mechanizable": h.mechanizable}
    run["steps"]["mechanization"] = mech

    _write_json(CAMP_ROOT / "campaign_run.json", run)
    return run


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_run = sub.add_parser("run", help="phase 1: OBSERVE -> preregister -> Kimi -> mechanize")
    p_run.add_argument("--kimi-timeout", type=int, default=1500)
    args = parser.parse_args(argv)
    if args.cmd == "run":
        run = phase1(kimi_timeout=args.kimi_timeout)
        print(json.dumps({"campaign_id": run["campaign_id"], "blockers": run["blockers"],
                          "steps": list(run["steps"].keys())}, indent=2))
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
