"""Read-only dependency census for the SP-D1 G: corpus manifest.

The audit never opens G:, mutates the farm database, or proposes a file action.
It searches the canonical repository and selected strategy-farm text surfaces,
then emits a machine-readable census plus an evidence document with one row for
every manifest entry.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import sqlite3
import subprocess
import tempfile
import unicodedata
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_MANIFEST = Path("D:/QM/reports/state/g_corpus_manifest_2026-08-22.json")
DEFAULT_REPO = Path("C:/QM/repo")
DEFAULT_ARTIFACTS = Path("D:/QM/strategy_farm/artifacts")
DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
MAX_TEXT_BYTES = 4 * 1024 * 1024

TEXT_SUFFIXES = {
    ".cfg",
    ".csv",
    ".ini",
    ".json",
    ".log",
    ".md",
    ".mq5",
    ".mqh",
    ".ps1",
    ".py",
    ".set",
    ".toml",
    ".txt",
    ".yaml",
    ".yml",
}

GENERIC_TITLE_TOKENS = {
    "a",
    "all",
    "an",
    "and",
    "as",
    "best",
    "by",
    "day",
    "for",
    "forex",
    "from",
    "how",
    "in",
    "is",
    "made",
    "method",
    "my",
    "of",
    "on",
    "only",
    "simple",
    "strategy",
    "system",
    "the",
    "this",
    "to",
    "trade",
    "trader",
    "trading",
    "with",
}


@dataclass(frozen=True)
class SearchDocument:
    path: Path
    display_path: str
    category: str
    lines: tuple[str, ...]
    normalized_lines: tuple[str, ...]
    line_numbers: tuple[int, ...]


def normalize(text: str) -> str:
    folded = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", folded.lower()).strip()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rg_json_text(value: dict) -> str:
    if "text" in value:
        return str(value["text"])
    if "bytes" in value:
        return base64.b64decode(value["bytes"]).decode("utf-8", errors="replace")
    raise ValueError(f"unsupported ripgrep JSON string representation: {sorted(value)}")


def title_tokens(relative_path: str) -> tuple[list[str], list[str]]:
    stem = Path(relative_path).stem
    stem = re.sub(r"^ff_\d+_?", "", stem, flags=re.I)
    stem = re.sub(r"^forexfactory_\d+_?", "", stem, flags=re.I)
    stem = re.sub(r"^forums\.babypips\.com_(?:t|r)_", "", stem, flags=re.I)
    stem = re.sub(r"^www\.babypips\.com_blogs_art-of-automation_", "", stem, flags=re.I)
    stem = re.sub(r"^(?:forex-sma|forex-system)-\d{8}\.html$", r"\g<0>", stem)
    stem = re.sub(r"_p\d+(?:-\d+)?$", "", stem, flags=re.I)
    stem = re.sub(r"_\d+(?:-[^.]+)?$", "", stem)
    tokens = normalize(stem).split()
    salient = [token for token in tokens if token not in GENERIC_TITLE_TOKENS and not token.isdigit()]
    return tokens, salient


def page_ids(relative_path: str) -> list[str]:
    stem = Path(relative_path).stem
    return sorted(set(re.findall(r"(?<!\d)(\d{4,})(?!\d)", stem)))


def category_for(path: Path, repo: Path, artifacts: Path) -> str:
    posix = path.as_posix().lower()
    if posix.startswith((artifacts / "cards_").as_posix().lower()):
        return "CARD"
    if any(part in posix for part in ("/research/", "/research_work/", "/extracted/")):
        return "CANDIDATE"
    if any(part in posix for part in ("/sources/", "/source_notes/")):
        return "SOURCE"
    if "/framework/eas/" in posix:
        return "EA"
    if "/decisions/" in posix:
        return "DECISION"
    if "/test" in posix:
        return "TEST"
    if any(part in posix for part in ("/docs/ops/evidence/", "/ops/", "/ops_issues/", "/reviews/")):
        return "EVIDENCE"
    if posix.startswith(repo.as_posix().lower()):
        return "REPO_OTHER"
    return "ARTIFACT_OTHER"


def display_path(path: Path, repo: Path, artifacts: Path) -> str:
    try:
        return path.relative_to(repo).as_posix()
    except ValueError:
        pass
    try:
        return "D:/QM/strategy_farm/artifacts/" + path.relative_to(artifacts).as_posix()
    except ValueError:
        return path.as_posix()


def search_roots(repo: Path, artifacts: Path) -> list[Path]:
    roots = [
        repo / "docs" / "ops" / "evidence",
        repo / "decisions",
        repo / "framework" / "EAs",
        repo / "tools" / "strategy_farm" / "tests",
        repo / "framework" / "scripts" / "tests",
        repo / "artifacts",
    ]
    for name in (
        "cards_approved",
        "cards_blocked_r3_data",
        "cards_draft",
        "cards_recovery",
        "cards_rejected",
        "cards_review",
        "extracted",
        "ops",
        "ops_issues",
        "research",
        "research_work",
        "reviews",
        "source_notes",
        "sources",
    ):
        roots.append(artifacts / name)
    return roots


def search_patterns(entries: list[dict]) -> list[str]:
    patterns: set[str] = set()
    for entry in entries:
        relative_path = str(entry["relative_path"])
        patterns.add(Path(relative_path).name)
        patterns.add(relative_path.replace("\\", "/"))
        patterns.add(str(entry["sha256"]))
        if entry["ledger_binding"] == "FILE":
            patterns.add(str(entry["source_id"]))
        patterns.update(page_ids(relative_path))
        tokens, salient = title_tokens(relative_path)
        if len(tokens) >= 3 and len(salient) >= 2:
            for separator in (" ", "-", "_"):
                patterns.add(separator.join(tokens))
    return sorted(pattern for pattern in patterns if pattern)


def load_documents(
    repo: Path,
    artifacts: Path,
    excluded: set[Path],
    entries: list[dict],
) -> tuple[list[SearchDocument], dict]:
    roots = [root for root in search_roots(repo, artifacts) if root.exists()]
    patterns = search_patterns(entries)
    matches: dict[str, dict] = {}
    matched_lines = 0
    stats_max = {"searches": 0, "searches_with_match": 0, "bytes_searched": 0}
    pattern_chunks = [patterns] if patterns else []
    for chunk in pattern_chunks:
        pattern_path: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", suffix=".patterns", delete=False
            ) as handle:
                handle.write("\n".join(chunk) + "\n")
                pattern_path = Path(handle.name)
            command = [
                "rg",
                "--json",
                "--fixed-strings",
                "--line-number",
                "--ignore-case",
                "--no-messages",
                "--stats",
                "--max-filesize",
                "4M",
                "-f",
                str(pattern_path),
            ]
            for suffix in sorted(TEXT_SUFFIXES):
                command.extend(["-g", f"*{suffix}"])
            command.extend(str(root) for root in roots)
            proc = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            if proc.returncode not in (0, 1):
                raise RuntimeError(f"rg dependency search failed: {proc.stderr.strip()}")
        finally:
            if pattern_path is not None:
                pattern_path.unlink(missing_ok=True)

        for raw in proc.stdout.splitlines():
            event = json.loads(raw)
            if event.get("type") == "summary":
                chunk_stats = event.get("data", {}).get("stats", {})
                for key in stats_max:
                    stats_max[key] = max(stats_max[key], int(chunk_stats.get(key, 0)))
                continue
            if event.get("type") != "match":
                continue
            data = event["data"]
            path = Path(rg_json_text(data["path"])).resolve()
            if path in excluded:
                continue
            line = rg_json_text(data["lines"]).rstrip("\r\n")
            line_number = int(data["line_number"])
            key = str(path).lower()
            record = matches.setdefault(
                key,
                {
                    "path": path,
                    "lines": [],
                    "normalized": [],
                    "line_numbers": [],
                },
            )
            if line_number not in record["line_numbers"]:
                record["lines"].append(line)
                record["normalized"].append(normalize(line))
                record["line_numbers"].append(line_number)
                matched_lines += 1

    documents = [
        SearchDocument(
            path=record["path"],
            display_path=display_path(record["path"], repo, artifacts),
            category=category_for(record["path"], repo, artifacts),
            lines=tuple(record["lines"]),
            normalized_lines=tuple(record["normalized"]),
            line_numbers=tuple(record["line_numbers"]),
        )
        for record in sorted(matches.values(), key=lambda item: item["path"].as_posix().lower())
    ]
    return documents, {
        "engine": "ripgrep fixed-string multi-pattern anchor search + exact second-stage classification",
        "patterns": len(patterns),
        "pattern_chunks": len(pattern_chunks),
        "roots": [root.as_posix() for root in roots],
        "documents_with_matches": len(documents),
        "matched_lines": matched_lines,
        "searches_per_chunk_max": stats_max["searches"],
        "searches_with_match_per_chunk_max": stats_max["searches_with_match"],
        "bytes_searched_per_chunk_max": stats_max["bytes_searched"],
        "max_text_file_bytes": MAX_TEXT_BYTES,
    }


def source_rows() -> dict[str, dict]:
    conn = sqlite3.connect(DB_RO, uri=True)
    conn.row_factory = sqlite3.Row
    try:
        return {str(row["id"]): dict(row) for row in conn.execute("SELECT * FROM sources")}
    finally:
        conn.close()


def site_context(relative_path: str, line: str) -> bool:
    lowered = line.lower()
    rel = relative_path.lower()
    if rel.startswith(("web-sources/ff_", "web-sources/forexfactory_")):
        return "forexfactory" in lowered or "forex factory" in lowered
    if "babypips.com" in rel or Path(rel).name.startswith(("forex-sma", "forex-system")):
        return "babypips" in lowered
    return False


def add_hit(hits: list[dict], *, category: str, kind: str, location: str, excerpt: str) -> None:
    record = {
        "category": category,
        "kind": kind,
        "location": location,
        "excerpt": excerpt.strip()[:240],
    }
    key = (record["category"], record["kind"], record["location"])
    if key not in {(row["category"], row["kind"], row["location"]) for row in hits}:
        hits.append(record)


def prepare_entry(entry: dict) -> dict:
    relative_path = str(entry["relative_path"])
    basename = Path(relative_path).name
    basename_lower = basename.lower()
    relative_lower = relative_path.replace("\\", "/").lower()
    digest = str(entry["sha256"]).lower()
    source_id = str(entry["source_id"])
    ids = page_ids(relative_path)
    tokens, salient = title_tokens(relative_path)
    title_phrase = " ".join(tokens)
    title_searchable = len(tokens) >= 3 and len(salient) >= 2

    return {
        "relative_path": relative_path,
        "sha256": digest,
        "size_bytes": int(entry["size_bytes"]),
        "media_type": entry["media_type"],
        "source_id": source_id,
        "ledger_binding": entry["ledger_binding"],
        "manifest_candidate_ids": list(entry.get("candidate_ids") or []),
        "manifest_card_ids": list(entry.get("card_ids") or []),
        "derived_title": title_phrase,
        "derived_page_ids": ids,
        "_basename_lower": basename_lower,
        "_relative_lower": relative_lower,
        "_title_searchable": title_searchable,
        "_title_anchor": max(salient, key=len) if salient else None,
        "_exact_references": [],
        "_title_only_references": [],
    }


def audit_entries(entries: list[dict], documents: list[SearchDocument], ledger: dict[str, dict]) -> list[dict]:
    rows = [prepare_entry(entry) for entry in entries]
    basename_indexes = list(range(len(rows)))
    digest_map = {row["sha256"]: index for index, row in enumerate(rows) if row["sha256"]}
    source_id_map = {
        row["source_id"].lower(): index
        for index, row in enumerate(rows)
        if row["ledger_binding"] == "FILE"
    }
    page_id_map: dict[str, list[int]] = {}
    title_anchor_map: dict[str, list[int]] = {}
    for index, row in enumerate(rows):
        for page_id in row["derived_page_ids"]:
            page_id_map.setdefault(page_id, []).append(index)
        if row["_title_searchable"] and row["_title_anchor"]:
            title_anchor_map.setdefault(row["_title_anchor"], []).append(index)

    for document in documents:
        for line_number, line, normalized_line in zip(
            document.line_numbers, document.lines, document.normalized_lines
        ):
            lowered = line.lower().replace("\\", "/")
            location = f"{document.display_path}:{line_number}"

            if ".pdf" in lowered or ".mq5" in lowered:
                for row_index in basename_indexes:
                    row = rows[row_index]
                    if row["_relative_lower"] in lowered:
                        add_hit(
                            row["_exact_references"],
                            category=document.category,
                            kind="EXACT_RELATIVE_PATH",
                            location=location,
                            excerpt=line,
                        )
                    elif row["_basename_lower"] in lowered:
                        add_hit(
                            row["_exact_references"],
                            category=document.category,
                            kind="EXACT_BASENAME",
                            location=location,
                            excerpt=line,
                        )

            for candidate_digest in re.findall(r"(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])", lowered):
                row_index = digest_map.get(candidate_digest)
                if row_index is not None:
                    add_hit(
                        rows[row_index]["_exact_references"],
                        category=document.category,
                        kind="CONTENT_SHA256",
                        location=location,
                        excerpt=line,
                    )

            for candidate_uuid in re.findall(
                r"(?<![0-9a-f])[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(?![0-9a-f])",
                lowered,
            ):
                row_index = source_id_map.get(candidate_uuid)
                if row_index is not None:
                    add_hit(
                        rows[row_index]["_exact_references"],
                        category=document.category,
                        kind="FILE_SOURCE_ID",
                        location=location,
                        excerpt=line,
                    )

            for candidate_id in set(re.findall(r"(?<!\d)\d{4,}(?!\d)", line)):
                for row_index in page_id_map.get(candidate_id, []):
                    row = rows[row_index]
                    if site_context(row["relative_path"], line):
                        add_hit(
                            row["_exact_references"],
                            category=document.category,
                            kind="SOURCE_PAGE_ID",
                            location=location,
                            excerpt=line,
                        )

            candidate_rows: set[int] = set()
            for token in set(normalized_line.split()):
                candidate_rows.update(title_anchor_map.get(token, []))
            for row_index in candidate_rows:
                row = rows[row_index]
                if row["derived_title"] in normalized_line:
                    add_hit(
                        row["_title_only_references"],
                        category=document.category,
                        kind="EXACT_NORMALIZED_TITLE",
                        location=location,
                        excerpt=line,
                    )

    for row in rows:
        ledger_row = ledger.get(row["source_id"])
        ledger_evidence = None
        if ledger_row:
            ledger_evidence = {
                "binding": row["ledger_binding"],
                "location": f"sqlite:sources:{row['source_id']}",
                "title": ledger_row.get("title"),
                "uri": ledger_row.get("uri"),
            }
            if row["ledger_binding"] == "FILE":
                add_hit(
                    row["_exact_references"],
                    category="SOURCE",
                    kind="FILE_LEDGER_BINDING",
                    location=f"sqlite:sources:{row['source_id']}",
                    excerpt=f"{ledger_row.get('title') or ''} | {ledger_row.get('uri') or ''}",
                )

        exact_keys = {hit["location"] for hit in row["_exact_references"]}
        title_hits = [hit for hit in row["_title_only_references"] if hit["location"] not in exact_keys]
        exact_hits = row["_exact_references"]
        if exact_hits:
            disposition = "REFERENCED_EXACT"
        elif title_hits:
            disposition = "REFERENCED_TITLE_ONLY"
        else:
            disposition = "NOT_DEMONSTRABLY_REFERENCED"
        row["disposition"] = disposition
        row["exact_references"] = sorted(
            exact_hits, key=lambda hit: (hit["category"], hit["location"], hit["kind"])
        )
        row["title_only_references"] = sorted(
            title_hits, key=lambda hit: (hit["category"], hit["location"])
        )
        row["ledger_evidence"] = ledger_evidence
        for key in [name for name in row if name.startswith("_")]:
            del row[key]
    return rows


def markdown_escape(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")


def reference_summary(row: dict) -> str:
    if row["disposition"] == "REFERENCED_EXACT":
        refs = row["exact_references"]
        prefix = "referenced — "
    elif row["disposition"] == "REFERENCED_TITLE_ONLY":
        refs = row["title_only_references"]
        prefix = "title-only reference (byte identity unproved) — "
    else:
        binding = row["ledger_binding"]
        return (
            "not demonstrably referenced beyond SP-D1; "
            + ("collection-level ledger coverage only" if binding == "COLLECTION" else "no downstream exact reference")
        )
    rendered = [f"{ref['category']}:{ref['kind']}@`{ref['location']}`" for ref in refs]
    return prefix + "; ".join(rendered)


def render_markdown(result: dict, manifest_path: Path) -> str:
    summary = result["summary"]
    chunk_word = "chunk" if result["scan"]["pattern_chunks"] == 1 else "chunks"
    lines = [
        "# SP-D9 — 130-file corpus dependency / retention dry-run",
        "",
        "Date: 2026-08-23 UTC",
        "",
        "Router task: `c65592c7-c8f4-4579-baf6-0ec7d9429319`",
        "",
        "Verdict: **DEPENDENCY_CENSUS_COMPLETE — report only; no file action is proposed or authorized**",
        "",
        "## Boundary and result",
        "",
        f"The input is `{manifest_path.as_posix()}` (SHA-256 `{result['manifest_sha256']}`).",
        "The headless session has no `G:` drive, so the audit used the manifest and did not open, move, rename, or alter any archive file.",
        "The input manifest and both outputs were excluded from dependency matching so the census does not count its own catalog rows as downstream consumers.",
        "",
        f"All **{summary['entries']}** manifest entries received a row: **{summary['referenced_exact']}** entries have at least one exact file/path/hash/source-page/file-ledger reference; **{summary['referenced_title_only']}** entry has title-only discoverability evidence whose byte identity is unproved; **{summary['not_demonstrably_referenced']}** entries have no downstream reference demonstrated by this method.",
        "A missing reference is not evidence of irrelevance. The 127 PDFs remain collection-bound reproducibility evidence, and the three raw MQ5 files remain quarantined.",
        "",
        "## Reproducible search method",
        "",
        "`tools/strategy_farm/audit_g_corpus_dependencies.py` performed one bounded, read-only pass over:",
        "",
        "- canonical Cards, EAs, evidence documents, decisions, and test text under `C:/QM/repo`;",
        "- selected Card/Candidate/Research/Source/Ops text surfaces under `D:/QM/strategy_farm/artifacts`;",
        "- the `sources` ledger through SQLite URI `mode=ro`.",
        "",
        "It used fixed-string anchors for exact relative paths, basenames, per-file SHA-256 values, FILE-level source IDs, thread/page IDs, and full title phrases with space, hyphen, or underscore separators. A second-stage classifier required exact site context for a page ID and the complete normalized phrase for a title. Exact and title-only evidence are separated because a shared title does not prove shared bytes or even document identity. The source ledger's COLLECTION row is reported as coverage, never promoted to a per-file dependency.",
        "",
        f"Coverage: ripgrep evaluated {result['scan']['patterns']} search expressions in {result['scan']['pattern_chunks']} bounded {chunk_word}. Each chunk scanned up to {result['scan']['searches_per_chunk_max']} eligible text files / {result['scan']['bytes_searched_per_chunk_max']} bytes; the union contained {result['scan']['documents_with_matches']} matching files and {result['scan']['matched_lines']} distinct matching lines. Files over 4 MiB were excluded by the declared boundary. Manifest arrays contain zero candidate IDs and zero card IDs for all 130 entries.",
        "",
        "### Limits",
        "",
        "- No PDF body, embedded metadata, OCR text, or raw MQ5 body on `G:` was searchable in this headless security context; filename/title and manifest metadata are the only per-file inputs.",
        "- Dynamic references assembled at runtime, references inside binaries/databases other than the read-only `sources` table, renamed documents, paraphrases, screenshots, and external-system links cannot be found by this lexical method.",
        "- Files above 4 MiB and non-text suffixes were excluded from text scanning. Ripgrep suppresses unreadable/binary content rather than proving it reference-free. Title-only matches are deliberately not represented as content-addressed dependencies.",
        "- The corpus manifest records the archive as retrieved at one instant; it does not prove that `G:` is unchanged after `2026-08-22T19:30:00Z`.",
        "",
        "## Rules a future ROT-9 retention policy must define",
        "",
        "A retention decision is not currently decidable. A signed ROT-9 policy would need, at minimum:",
        "",
        "1. policy identity, version, OWNER authority, effective date, and an immutable decision hash;",
        "2. retention classes with minimum durations, legal/license/confidentiality constraints, and a rule for superseded versions;",
        "3. a default that unresolved, collection-only, title-only, or unsearchable dependencies remain retained until positively resolved;",
        "4. acceptable dependency evidence and confidence thresholds, including whether exact hashes, exact paths, source IDs, or semantic lineage are required;",
        "5. duplicate-content rules that preserve one authenticated canonical byte copy plus every required provenance/path receipt;",
        "6. reproducibility tests proving Cards, Candidates, EAs, evidence, decisions, and tests still resolve to identical inputs after any future action;",
        "7. absolute-path/link migration rules, collision handling, cross-volume semantics, and signed before/after receipts;",
        "8. backup/version-history prerequisites, recovery ownership, rollback windows, and restoration tests;",
        "9. permanent `RAW_UNTRUSTED` / `DO_NOT_DEPLOY` treatment for external MQ5, with adoption only through a Strategy Card, V5 reimplementation, and Q00-Q13;",
        "10. exception/hold handling, periodic review cadence, and an explicit `apply_authorized` gate separate from this dry-run.",
        "",
        "## Per-file dependency census",
        "",
        "The result column stops at observed dependency status. It is not an action or disposition column.",
        "",
        "| # | Manifest file | SHA-256 (prefix) | Dependency result and location |",
        "|---:|---|---|---|",
    ]
    for index, row in enumerate(result["entries"], start=1):
        lines.append(
            f"| {index} | `{markdown_escape(row['relative_path'])}` | `{row['sha256'][:12]}` | {markdown_escape(reference_summary(row))} |"
        )
    lines.extend(
        [
            "",
            "## Non-action conclusion",
            "",
            "This completes the dependency census required after SP-D1. It does not supply the still-missing ROT-9 authority and does not authorize or recommend any archive mutation. No source was ingested, no Card or EA identity was created, no task or work item was enqueued, and no live/factory control was touched.",
            "",
            "Machine-readable companion: `docs/ops/evidence/2026-08-23_sp_d9_corpus_dependency_dry_run.json`.",
            "",
        ]
    )
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACTS)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--output-md", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest_path = args.manifest.resolve()
    repo = args.repo_root.resolve()
    artifacts = args.artifact_root.resolve()
    output_json = args.output_json.resolve()
    output_md = args.output_md.resolve()

    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    entries = list(manifest.get("entries") or [])
    if manifest.get("schema") != "qm.g_corpus_manifest/v1" or len(entries) != 130:
        raise SystemExit("refusing: expected qm.g_corpus_manifest/v1 with exactly 130 entries")
    manifest_sha = sha256_file(manifest_path)
    if manifest_sha != "e7f256db275de92d0a0fc14ab57310de77d978d3264e7ab027f59c7ef3f5e8ae":
        raise SystemExit(f"refusing: unexpected manifest SHA-256 {manifest_sha}")

    documents, scan = load_documents(
        repo, artifacts, {output_json, output_md, manifest_path}, entries
    )
    ledger = source_rows()
    audited = audit_entries(entries, documents, ledger)
    dispositions = {name: sum(row["disposition"] == name for row in audited) for name in (
        "REFERENCED_EXACT",
        "REFERENCED_TITLE_ONLY",
        "NOT_DEMONSTRABLY_REFERENCED",
    )}
    result = {
        "schema": "qm.g_corpus_dependency_dry_run/v1",
        "task_id": "c65592c7-c8f4-4579-baf6-0ec7d9429319",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "apply_authorized": False,
        "manifest_path": manifest_path.as_posix(),
        "manifest_sha256": manifest_sha,
        "search_boundary": "manifest metadata + named local text surfaces + sources ledger mode=ro; G: not accessed",
        "scan": scan,
        "summary": {
            "entries": len(audited),
            "referenced_exact": dispositions["REFERENCED_EXACT"],
            "referenced_title_only": dispositions["REFERENCED_TITLE_ONLY"],
            "not_demonstrably_referenced": dispositions["NOT_DEMONSTRABLY_REFERENCED"],
            "manifest_candidate_ids_nonempty": sum(bool(row["manifest_candidate_ids"]) for row in audited),
            "manifest_card_ids_nonempty": sum(bool(row["manifest_card_ids"]) for row in audited),
        },
        "entries": audited,
    }
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_md.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    output_md.write_text(render_markdown(result, manifest_path), encoding="utf-8")
    print(json.dumps(result["summary"], indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
