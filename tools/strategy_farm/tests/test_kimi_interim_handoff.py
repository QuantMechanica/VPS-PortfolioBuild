"""Consistency lint for the consolidated Kimi interim handoff.

Hermetic: parses only the markdown handoff and its machine-readable JSON twin
(``D:/QM/reports/state/kimi_interim_handoff.json``). No DB, no git, no network.

Lint rules:
 1. exactly one ``# CURRENT SNAPSHOT`` heading;
 2. the canonical HEAD appears exactly once as the authoritative value;
 3. no decision is listed both open and closed;
 4. no FTMO candidate carries a contradictory prescreen verdict (md vs json);
 5. the factory numbers in the markdown machine-readable block equal the JSON;
 6. every referenced high-priority path exists — the two IN-FLIGHT agent outputs
    (agent-38 critic-prep dir, agent-39 RAM-479 analysis) may be pending, but
    only when both files mark them IN-FLIGHT and ``handoff_ready`` is false;
 7. 'economically validated' may only appear negated (candidates are never so
    described positively).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
MD_PATH = REPO / "docs" / "ops" / "KIMI_INTERIM_HANDOFF_2026-09-18.md"
JSON_PATH = Path("D:/QM/reports/state/kimi_interim_handoff.json")

IN_FLIGHT_PATHS = [
    "docs/ops/evidence/2026-09-17_critic_prep",
    "docs/ops/RAM479_ANALYSIS_2026-09-16.md",
]

EXTRA_REQUIRED_PATHS = [
    "docs/ops/CRITIC_TO_Q00_TRANSITION_2026-09-16.md",
    "docs/ops/FTMO_CHALLENGE_READINESS.md",
    "docs/ops/OWNER_DECISION_PACKAGE_D6_DSR_REMAINDER_2026-09-16.md",
    "docs/ops/evidence/2026-09-16_e1c_optionb/REPORT.md",
    "docs/ops/evidence/2026-09-15_news_calendar_repin_repair/prepared_registry_patch.md",
    "docs/ops/evidence/2026-09-16_seal_41478/RECEIPT_D5.md",
    "docs/ops/evidence/2026-09-16_requeue_lifts/",
    "docs/ops/evidence/2026-09-16_dsr_remainder/AUDIT.md",
    "docs/ops/evidence/2026-09-16_deterministic_repairs/2026-09-16_q09_sealed_plan_derivation_owner_package.md",
    "docs/research/SECOND_CHANCE_SHORTLIST_2026-09-16.md",
    "docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md",
    "docs/research/PATTERN_ABLATION_PROGRAMME_2026-09-16.md",
    "docs/ops/BOOK_SPRINT_2026-09-20.md",
    "D:/QM/reports/state/factory_population.json",
    "D:/QM/reports/state/second_chance_register.json",
    "D:/QM/reports/state/second_chance_funnel.json",
]


@pytest.fixture(scope="module")
def md_text() -> str:
    assert MD_PATH.exists(), f"missing handoff markdown: {MD_PATH}"
    return MD_PATH.read_text(encoding="utf-8")


@pytest.fixture(scope="module")
def handoff() -> dict:
    assert JSON_PATH.exists(), f"missing machine-readable handoff: {JSON_PATH}"
    return json.loads(JSON_PATH.read_text(encoding="utf-8"))


def _section(text: str, heading: str, next_heading_prefix: str = "\n# ") -> str:
    start = text.index(heading)
    rest = text[start + len(heading):]
    end = rest.index(next_heading_prefix)
    return rest[:end]


def test_exactly_one_current_snapshot(md_text: str) -> None:
    lines = [l for l in md_text.splitlines() if l.strip() == "# CURRENT SNAPSHOT"]
    assert len(lines) == 1, f"expected exactly one '# CURRENT SNAPSHOT', found {len(lines)}"


def test_head_appears_once_as_authoritative(md_text: str, handoff: dict) -> None:
    head = handoff["canonical_head"]
    assert len(head) == 40, "canonical_head must be a full sha1"
    assert md_text.count(head) == 1, "canonical HEAD must appear exactly once (the authoritative snapshot line)"


def test_no_decision_both_open_and_closed(md_text: str) -> None:
    open_sec = _section(md_text, "# OPEN DECISIONS", "\n# RECENT OWNER DECISIONS")
    closed_marker = "\n# RECENT OWNER DECISIONS"
    closed_start = md_text.index(closed_marker)
    nxt = re.compile(r"\n# ", re.M).search(md_text, closed_start + len(closed_marker))
    closed_sec = md_text[closed_start:nxt.start()]
    open_markers = ["D6 / V4+6b", "RAM-479", "Q09 sealed-plan", "News receipt-chain", "E1-C next-pass drift"]
    closed_markers = ["D1 (V3", "D2A", "D2B", "D3 → D5", "E1-C Option B", "Clarification 6"]
    for m in closed_markers:
        assert m not in open_sec, f"closed decision marker '{m}' leaked into OPEN DECISIONS"
    for m in open_markers:
        assert m not in closed_sec, f"open decision marker '{m}' leaked into CLOSED decisions"


def _candidate_section(md_text: str, ea_id: str) -> str:
    pat = re.compile(rf"^### {re.escape(ea_id)} .*$", re.M)
    m = pat.search(md_text)
    assert m, f"missing candidate section for {ea_id}"
    start = m.start()
    nxt = re.compile(r"^### QM5_", re.M).search(md_text, m.end())
    end = nxt.start() if nxt else md_text.index("\n# SECOND-CHANCE PROGRAMME")
    return md_text[start:end]


def test_no_ftmo_candidate_contradictory(md_text: str, handoff: dict) -> None:
    for cand in handoff["ftmo_candidates"]:
        ea = cand["ea_id"]
        sec = _candidate_section(md_text, ea)
        prescreen_lines = [l for l in sec.splitlines() if "Prescreen" in l]
        assert prescreen_lines, f"{ea}: no prescreen line in markdown"
        line = prescreen_lines[0]
        verdict = cand["prescreen_verdict"]
        if verdict == "KEEP":
            assert re.search(r"\*\*KEEP\b", line) and not re.search(r"\*\*REJECT\b", line), f"{ea}: md/json prescreen mismatch"
        elif verdict == "REJECT":
            assert re.search(r"\*\*REJECT\b", line), f"{ea}: md/json prescreen mismatch"
        else:
            assert "store only" in verdict and "store-only" in sec, f"{ea}: store-only state drifted"
        assert not (re.search(r"\*\*KEEP\b", line) and re.search(r"\*\*REJECT\b", line)), f"{ea}: contradictory prescreen line"


def test_markdown_json_factory_numbers_match(md_text: str, handoff: dict) -> None:
    m = re.search(r"```json\n(\{.*?\n\})\n```", md_text, re.S)
    assert m, "no machine-readable json block found in CURRENT FACTORY STATE"
    block = json.loads(m.group(1))
    fac = handoff["factory"]
    mapping = {
        "OPEN_PIPELINE_ROWS": ("open_pipeline_rows", block["four_counts"]["OPEN_PIPELINE_ROWS"]),
        "SELECTOR_CLAIMABLE_ROWS": ("selector_claimable_rows", block["four_counts"]["SELECTOR_CLAIMABLE_ROWS"]),
        "TRUE_CLAIMABLE_WORK": ("true_claimable_work", block["four_counts"]["TRUE_CLAIMABLE_WORK"]),
        "RESOURCE_FEASIBLE_RUNNABLE_WORK": ("resource_feasible_runnable_work", block["four_counts"]["RESOURCE_FEASIBLE_RUNNABLE_WORK"]),
        "ACTIVE_ECONOMIC_BACKTESTS": ("active_economic_backtests", block["four_counts"]["ACTIVE_ECONOMIC_BACKTESTS"]),
    }
    for name, (jkey, mdval) in mapping.items():
        assert fac[jkey] == mdval, f"factory number drift {name}: md={mdval} json={fac[jkey]}"
    assert fac["forecast_runnable_hours"] == block["forecast_runnable_hours"]
    assert fac["parked_rows"] == block["parked_rows"]


def _resolve(path: str) -> Path:
    p = Path(path)
    return p if p.is_absolute() else REPO / p


def test_required_paths_exist(md_text: str, handoff: dict) -> None:
    referenced: list[str] = list(EXTRA_REQUIRED_PATHS)
    for cand in handoff["ftmo_candidates"]:
        for key in ("card_path",):
            if cand.get(key):
                referenced.append(cand[key])
        if cand.get("provenance_id"):
            referenced.append(f"strategy-seeds/sources/{cand['provenance_id']}/")
    sc = handoff.get("second_chance", {})
    for key in ("register_path", "funnel_path", "shortlist_path"):
        if sc.get(key):
            referenced.append(sc[key])
    for dec in handoff.get("open_decisions", []):
        if dec.get("evidence_path"):
            referenced.append(dec["evidence_path"])
    for act in handoff.get("human_actions", []):
        for key in ("package", "doc"):
            if act.get(key):
                referenced.append(act[key])

    in_flight = set(IN_FLIGHT_PATHS)
    for raw in sorted(set(referenced)):
        p = _resolve(raw)
        if raw in in_flight or any(seg in raw for seg in ("RAM479_ANALYSIS", "2026-09-17_critic_prep")):
            if p.exists():
                continue
            assert handoff.get("handoff_ready") is False, f"{raw} missing but handoff_ready=true"
            agents = handoff.get("active_agents", [])
            assert any(a.get("status") == "IN_FLIGHT" for a in agents), f"{raw} missing and no IN_FLIGHT agent recorded"
            assert "IN-FLIGHT" in md_text or "IN_FLIGHT" in md_text, f"{raw} missing and markdown does not mark it in-flight"
        else:
            assert p.exists(), f"required referenced path does not exist: {raw}"


def test_never_described_as_economically_validated(md_text: str) -> None:
    for m in re.finditer(r"economically validated", md_text):
        window = md_text[max(0, m.start() - 24):m.end() + 16].lower()
        assert re.search(r"(none( is)?|not|no) economically validated", window), (
            f"'economically validated' must only appear negated; context: ...{window}..."
        )
