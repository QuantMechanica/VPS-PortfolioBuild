"""D1 batch-2 wiki verification — ZERO_D1_ATTRIBUTABLE_DRIFT per-cohort standard.

For each of the 8 amended EAs:
  1. governed refresh: strategy_wiki_sync.py build --only <EA> (writes the node for the
     amended card hash when stale; recorded written/skipped)
  2. per-node check (module's own resolve logic): node present at expected path (missing=0),
     inputs_sha256 current (not stale), card_hash == live card content hash, no invalid_link /
     unresolved_source / unresolved_lineage for the key, not duplicated, not orphaned
  3. full governed lint for the ambient record (owner clarification: global AMBER from
     unrelated stale historical nodes does NOT block; the cohort must be clean)
Writes wiki_build_batch2.txt and wiki_lint_batch2.json (+ per-node detail inside it).
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO / "tools/strategy_farm"))
import vault_paths  # noqa: E402
import strategy_wiki_sync as sws  # noqa: E402

OUT_DIR = Path(__file__).parent
CARDS_D = Path("D:/QM/strategy_farm/artifacts/cards_approved")
EAS = ["QM5_10287", "QM5_9576", "QM5_1230", "QM5_9973", "QM5_13012", "QM5_11882", "QM5_10269", "QM5_10280"]


def main() -> int:
    build_lines = []
    for ea in EAS:
        r = subprocess.run(
            [sys.executable, str(REPO / "tools/strategy_farm/strategy_wiki_sync.py"), "build", "--only", ea],
            cwd=REPO, capture_output=True, text=True, timeout=300)
        try:
            j = json.loads(r.stdout)
            build_lines.append(f"{ea}: written={j['written']} skipped={j['skipped']} pruned={j['pruned']} only={j['only']}")
        except Exception:  # noqa: BLE001
            build_lines.append(f"{ea}: UNPARSEABLE stdout={r.stdout[:200]!r} stderr={r.stderr[:200]!r}")
    (OUT_DIR / "wiki_build_batch2.txt").write_text("\n".join(build_lines) + "\n", encoding="utf-8")
    for line in build_lines:
        print(line)

    sources = sws.default_sources()
    cards = sws.scan_cards(sources)
    registry = sws.load_registry(sources)
    pipeline = sws.load_pipeline(sources)
    dxz = sws._book_membership(sources.book_dxz)
    ftmo = sws._book_membership(sources.book_ftmo)
    lineage = sws.load_lineage(sources)
    handwritten = sws._hand_written_index(sources)
    live_pnl = sws.load_live_pnl(sources.live_attribution)
    records = sws.build_records(sources, cards, registry, pipeline, dxz, ftmo, lineage)
    existing = sws._scan_generated_nodes(sources)
    existing_by_path = {Path(n["_path"]).resolve(): n for n in existing}
    sc_register = sws.load_second_chance(sources)
    hand_stems = {p.stem for p in sources.strategies_dir.glob("*.md")} if sources.strategies_dir.is_dir() else set()

    seen: dict[str, int] = {}
    for n in existing:
        eid = str(n.get("ea_id") or "")
        key = eid if eid.startswith("QM5_") else f"slug:{n.get('slug') or ''}"
        seen[key] = seen.get(key, 0) + 1

    per_node = {}
    all_ok = True
    for ea in EAS:
        key = sws.normalize_ea_key(ea)
        rec = records.get(key)
        if rec is None:
            per_node[ea] = {"ok": False, "reason": "no_record"}
            all_ok = False
            continue
        fields = sws.resolve_fields(rec, sources, handwritten, live_pnl=live_pnl)
        expected_path = sources.generated_dir / fields["projection_class"] / sws.node_filename(rec)
        node = existing_by_path.get(expected_path.resolve())
        card_file = rec.card.path if rec.card is not None else CARDS_D / f"{key}.md"
        live_card_hash = vault_paths.card_content_sha256(card_file.read_text(encoding="utf-8"))
        checks = {
            "missing": node is None,
            "stale": bool(node) and node.get("inputs_sha256") != fields["inputs_sha256"],
            "card_hash_current": (not node) or node.get("card_hash") == live_card_hash == fields["card_hash"],
            "duplicate": seen.get(key, 0) > 1,
            "orphan": expected_path.resolve() not in {p.resolve() for p in existing_by_path} and node is not None,
            "invalid_link": False,
            "unresolved_source": False,
            "unresolved_lineage": False,
        }
        if node is not None:
            hw = fields["handwritten_node"]
            if hw.startswith("[[strategies/") and hw.endswith("]]"):
                checks["invalid_link"] = hw[len("[[strategies/"):-2] not in hand_stems
            if fields["source_hash"] == sws.EVIDENCE_MISSING and fields["source_id"] not in (
                sws.NOT_APPLICABLE, sws.EVIDENCE_MISSING, "") and fields["source_id"].upper().startswith("QM-RESEARCH"):
                checks["unresolved_source"] = True
            if fields["parent_lineage"] not in (sws.NOT_APPLICABLE, sws.EVIDENCE_MISSING):
                for token in fields["parent_lineage"].split(","):
                    token = token.strip()
                    if ":" in token:
                        ref = token.split(":", 1)[1].strip()
                        if sws.normalize_ea_key(ref) and sws.normalize_ea_key(ref) not in records:
                            checks["unresolved_lineage"] = True
                            break
        ok = (node is not None and not checks["missing"] and not checks["stale"]
              and checks["card_hash_current"] and not checks["duplicate"] and not checks["orphan"]
              and not checks["invalid_link"] and not checks["unresolved_source"] and not checks["unresolved_lineage"])
        # build-vs-lint digest asymmetry (pre-existing tool quirk, NOT D1-attributable):
        # build() folds the second-chance register into inputs_sha256; lint() omits it.
        # For register-carrying (REJECTED-population) nodes the two models disagree forever,
        # so lint-model stale=true here means "matches the writer exactly". Record both.
        fields_with_sc = sws.resolve_fields(rec, sources, handwritten, sc_register, live_pnl)
        build_model_match = bool(node) and node.get("inputs_sha256") == fields_with_sc["inputs_sha256"]
        stale_is_sc_asymmetry = checks["stale"] and (rec.ea_key or "") in sc_register and build_model_match
        all_ok = all_ok and (ok or stale_is_sc_asymmetry)
        per_node[ea] = {"ok": ok, "stale_is_sc_asymmetry": stale_is_sc_asymmetry,
                        "build_model_match": build_model_match,
                        "node": str(expected_path), "class": fields["projection_class"], **checks}

    health = sws.lint(sources)  # governed ambient lint (writes the health read-model, as batch-1 did)
    out = {
        "schema": "qm.q08-batch2-wiki-cohort/v1",
        "standard": "ZERO_D1_ATTRIBUTABLE_DRIFT (per-cohort: card hash current, missing=0, "
                    "duplicate/orphan/invalid_link/unresolved_source/unresolved_lineage=0, not stale)",
        "cohort_all_ok": all_ok,
        "per_node": per_node,
        "ambient_health": {
            "STRATEGY_WIKI_SYNC": health["STRATEGY_WIKI_SYNC"],
            "generated_at_utc": health["generated_at_utc"],
            "counts": health["counts"],
            "canonical_records": health["canonical_records"],
            "class_counts": health["class_counts"],
            "samples": health["samples"],
        },
    }
    (OUT_DIR / "wiki_lint_batch2.json").write_text(json.dumps(out, indent=2), encoding="utf-8")
    print("COHORT", "ALL OK" if all_ok else "FAILURES PRESENT")
    print("AMBIENT", health["STRATEGY_WIKI_SYNC"], health["counts"])
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
