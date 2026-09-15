"""Unit tests for research_source (QM-RESEARCH internal source tooling).

Covers the contract Section 9.1 subcommand behaviours and the directive Section
14 verify matrix at the module level.  All paths are injected into temp dirs;
nothing touches D:/QM (contract Section 12).
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import research_source as rs  # noqa: E402


EXAMPLE_ID = "QM-RESEARCH-2026-0000"
EXAMPLE_DIR = Path(rs.__file__).resolve().parents[2] / "strategy-seeds" / "sources" / EXAMPLE_ID


def _store_and_ledger(tmp_path: Path) -> tuple[Path, Path, Path]:
    store = tmp_path / "store"
    store.mkdir(exist_ok=True)
    ledger = tmp_path / "ledger.jsonl"
    search = tmp_path / "search.jsonl"  # deliberately absent unless a test writes it
    return store, ledger, search


def _valid_reviewed_source(tmp_path: Path, research_id: str = EXAMPLE_ID) -> tuple[Path, Path, Path]:
    """Copy the committed worked example into a temp store and seal it reviewed."""
    store, ledger, search = _store_and_ledger(tmp_path)
    dst = store / research_id
    shutil.copytree(EXAMPLE_DIR, dst)
    rs.seal(research_id, status="reviewed", store_root=store, ledger_path=ledger)
    return store, ledger, search


# --------------------------------------------------------------------------- #
# mint / resolve
# --------------------------------------------------------------------------- #
def test_mint_creates_dir_and_draft_ledger_row(tmp_path: Path) -> None:
    store, ledger, _ = _store_and_ledger(tmp_path)
    result = rs.mint(
        author="Kimi", model="kimi-code/kimi-for-coding", task_id="T-1",
        year="2026", store_root=store, ledger_path=ledger,
    )
    directory = store / result["id"]
    assert directory.is_dir()
    for name in (rs.SOURCE_MD, rs.RESEARCH_JSON, rs.LINEAGE_JSON, rs.CRITIC_JSON):
        assert (directory / name).is_file()
    rows = rs.read_ledger(ledger)
    assert len(rows) == 1
    assert rows[0]["status"] == "draft"
    assert rows[0]["event"] == "mint"
    assert rows[0]["sha256"] == rs.source_hash(directory)
    # The skeleton manifest is self-consistent.
    manifest = rs.parse_manifest((directory / rs.SOURCE_MD).read_text(encoding="utf-8"))
    for name in rs.CORE_MANIFEST_FILES:
        assert manifest[name] == rs.sha256_file(directory / name)


def test_mint_refuses_existing_id(tmp_path: Path) -> None:
    store, ledger, _ = _store_and_ledger(tmp_path)
    rs.mint(author="Kimi", model="m", task_id="T", research_id="QM-RESEARCH-2026-0001",
            store_root=store, ledger_path=ledger)
    with pytest.raises(rs.ResearchSourceError, match="id_exists"):
        rs.mint(author="Kimi", model="m", task_id="T", research_id="QM-RESEARCH-2026-0001",
                store_root=store, ledger_path=ledger)


def test_mint_requires_author_model_task(tmp_path: Path) -> None:
    store, ledger, _ = _store_and_ledger(tmp_path)
    with pytest.raises(rs.ResearchSourceError, match="mint_requires"):
        rs.mint(author="", model="m", task_id="T", store_root=store, ledger_path=ledger)


def test_resolve_reference_and_not_found(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    paths = rs.resolve_paths(store, ledger, search)
    resolved = rs.resolve("QM-RESEARCH://2026-0000", paths)
    assert resolved == store / EXAMPLE_ID
    with pytest.raises(rs.ResearchSourceError, match=rs.REASON_NOT_FOUND):
        rs.resolve("QM-RESEARCH://2026-9999", paths)


# --------------------------------------------------------------------------- #
# verify — happy path (directive T3)
# --------------------------------------------------------------------------- #
def test_verify_valid_reviewed_source_passes(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    result = rs.verify(research_id=EXAMPLE_ID, store_root=store, ledger_path=ledger,
                       search_ledger_path=search)
    assert result.ok, result.reasons


def test_verify_card_binding_matches(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    digest = rs.source_hash(store / EXAMPLE_ID)
    fm = {
        "source_id": EXAMPLE_ID,
        "source_type": "internal_research",
        "source_artifact": "QM-RESEARCH://2026-0000",
        "source_hash": digest,
        "research_trial_count": "7",
    }
    result = rs.verify(card_frontmatter=fm, store_root=store, ledger_path=ledger,
                       search_ledger_path=search)
    assert result.ok, result.reasons


# --------------------------------------------------------------------------- #
# verify — fail-closed cases (directive T4/T5/T8/T9/T10)
# --------------------------------------------------------------------------- #
def test_verify_no_artifact_is_not_found(tmp_path: Path) -> None:
    store, ledger, search = _store_and_ledger(tmp_path)
    fm = {"source_type": "internal_research", "source_id": "QM-RESEARCH-2026-0777"}
    result = rs.verify(card_frontmatter=fm, store_root=store, ledger_path=ledger,
                       search_ledger_path=search)
    assert not result.ok
    assert rs.REASON_NOT_FOUND in result.reasons


def test_verify_card_hash_mismatch(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    fm = {"source_id": EXAMPLE_ID, "source_hash": "0" * 64, "research_trial_count": "7"}
    result = rs.verify(card_frontmatter=fm, store_root=store, ledger_path=ledger,
                       search_ledger_path=search)
    assert not result.ok
    assert rs.REASON_HASH_MISMATCH in result.reasons


def test_verify_manifest_sibling_tamper_fails_closed(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    # Tamper a sibling WITHOUT re-sealing: manifest hash no longer matches.
    (store / EXAMPLE_ID / rs.RESEARCH_JSON).write_text("{}\n", encoding="utf-8")
    result = rs.verify(research_id=EXAMPLE_ID, store_root=store, ledger_path=ledger,
                       search_ledger_path=search)
    assert not result.ok
    assert any(r.startswith(rs.REASON_HASH_MISMATCH + ":research.json") for r in result.reasons)


def test_verify_critic_kimi_on_kimi_and_repo_write(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    directory = store / EXAMPLE_ID
    critic = json.loads((directory / rs.CRITIC_JSON).read_text(encoding="utf-8"))
    critic["plan"]["critic"]["vendor"] = "kimi"
    critic["critic_seat_final"] = "kimi-critic"
    critic["repo_write"] = True
    (directory / rs.CRITIC_JSON).write_text(json.dumps(critic, indent=2), encoding="utf-8")
    rs.seal(EXAMPLE_ID, status="reviewed", store_root=store, ledger_path=ledger)
    result = rs.verify(research_id=EXAMPLE_ID, store_root=store, ledger_path=ledger,
                       search_ledger_path=search)
    assert not result.ok
    assert rs.REASON_CRITIC_KIMI_ON_KIMI in result.reasons
    assert rs.REASON_CRITIC_WROTE in result.reasons


def test_verify_numeric_claim_requires_computed_output(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    directory = store / EXAMPLE_ID
    research = json.loads((directory / rs.RESEARCH_JSON).read_text(encoding="utf-8"))
    research["computed_outputs"] = []  # strip the backing evidence
    (directory / rs.RESEARCH_JSON).write_text(json.dumps(research, indent=2), encoding="utf-8")
    rs.seal(EXAMPLE_ID, status="reviewed", store_root=store, ledger_path=ledger)
    result = rs.verify(research_id=EXAMPLE_ID, store_root=store, ledger_path=ledger,
                       search_ledger_path=search)
    assert not result.ok
    assert rs.REASON_NUMERIC_UNBACKED in result.reasons


def test_verify_trial_count_understated(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    # Research-layer ledger shows more searches than the card/research declares.
    search.write_text(
        json.dumps({"hypothesis_family": "SHREF-XAU-GAPFADE-2026-0000", "search_count": 99}) + "\n",
        encoding="utf-8",
    )
    fm = {"source_id": EXAMPLE_ID, "research_trial_count": "3",
          "source_hash": rs.source_hash(store / EXAMPLE_ID)}
    result = rs.verify(card_frontmatter=fm, store_root=store, ledger_path=ledger,
                       search_ledger_path=search)
    assert not result.ok
    assert any(r.startswith(rs.REASON_TRIAL_COUNT_UNDERSTATED) for r in result.reasons)


def test_verify_draft_status_not_admissible(tmp_path: Path) -> None:
    store, ledger, search = _store_and_ledger(tmp_path)
    # A freshly minted (draft) source must not be admissible.
    result = rs.mint(author="Kimi", model="m", task_id="T",
                     research_id="QM-RESEARCH-2026-0002", store_root=store, ledger_path=ledger)
    vr = rs.verify(research_id=result["id"], store_root=store, ledger_path=ledger,
                   search_ledger_path=search)
    assert not vr.ok
    assert any(r.startswith(rs.REASON_LEDGER_STATUS_BAD) for r in vr.reasons)


# --------------------------------------------------------------------------- #
# ledger append-only / edit-after-seal / re-mint (directive T13)
# --------------------------------------------------------------------------- #
def test_edit_after_seal_fails_until_resealed_and_remint_is_append_only(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    directory = store / EXAMPLE_ID
    assert rs.verify(research_id=EXAMPLE_ID, store_root=store, ledger_path=ledger,
                     search_ledger_path=search).ok

    ledger_before = ledger.read_text(encoding="utf-8").splitlines()

    # Edit source.md after seal -> sha256(source.md) drifts from the ledger.
    source_md = directory / rs.SOURCE_MD
    source_md.write_text(source_md.read_text(encoding="utf-8") + "\nappended edit.\n",
                         encoding="utf-8")
    broken = rs.verify(research_id=EXAMPLE_ID, store_root=store, ledger_path=ledger,
                       search_ledger_path=search)
    assert not broken.ok
    assert any(r.startswith(rs.REASON_HASH_MISMATCH) for r in broken.reasons)

    # Re-seal re-anchors the SAME version -> verify passes again.
    rs.seal(EXAMPLE_ID, status="reviewed", store_root=store, ledger_path=ledger)
    assert rs.verify(research_id=EXAMPLE_ID, store_root=store, ledger_path=ledger,
                     search_ledger_path=search).ok

    # A genuine new version is a fresh id with a parent link.
    remint = rs.remint(EXAMPLE_ID, store_root=store, ledger_path=ledger)
    assert remint["id"] != EXAMPLE_ID
    child_lineage = json.loads((store / remint["id"] / rs.LINEAGE_JSON).read_text(encoding="utf-8"))
    assert child_lineage["parent_version_id"] == EXAMPLE_ID
    assert child_lineage["version"] == 2

    # Append-only: the original first line is byte-identical; the ledger only grew.
    ledger_after = ledger.read_text(encoding="utf-8").splitlines()
    assert ledger_after[: len(ledger_before)] == ledger_before
    assert len(ledger_after) > len(ledger_before)


def test_verify_cli_exit_codes(tmp_path: Path) -> None:
    store, ledger, search = _valid_reviewed_source(tmp_path)
    ok = rs.main(["verify", "--id", EXAMPLE_ID, "--store-root", str(store),
                  "--ledger", str(ledger), "--search-ledger", str(search)])
    assert ok == 0
    bad = rs.main(["verify", "--id", "QM-RESEARCH-2026-0404", "--store-root", str(store),
                   "--ledger", str(ledger), "--search-ledger", str(search)])
    assert bad == 1
