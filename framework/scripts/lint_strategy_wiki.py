#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

DEFAULT_VAULT = Path(r"G:\My Drive\09 Strategy Wiki")

WIKI_LINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n?", re.DOTALL)
INDEX_LINK_RE = re.compile(r"\[\[([^\]]+)\]\]")

REQUIRED_BY_TEMPLATE = {
    "strategies": ("id", "slug", "title"),
}

META_FILE_PREFIXES = ("_",)
TEMPLATE_NAME_PREFIX = "_template "
NODE_DIRS = {"strategies", "sources", "concepts", "indicators"}


@dataclass
class Violation:
    path: Path
    line: int
    code: str
    message: str


def parse_frontmatter(path: Path, text: str) -> tuple[dict[str, str], list[Violation]]:
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}, [Violation(path=path, line=1, code="missing_frontmatter", message="Missing YAML frontmatter")]
    fm: dict[str, str] = {}
    for idx, line in enumerate(m.group(1).splitlines(), start=2):
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        fm[k.strip().lower()] = v.strip().strip('"').strip("'")
    return fm, []


def link_target(raw: str) -> str:
    base = raw.split("|", 1)[0].split("#", 1)[0].strip()
    return Path(base).name.lower()


def is_meta_file(path: Path) -> bool:
    stem = path.stem.lower()
    return stem.startswith(META_FILE_PREFIXES) or stem.startswith(TEMPLATE_NAME_PREFIX)


def is_wiki_node(path: Path, vault: Path) -> bool:
    if is_meta_file(path):
        return False
    try:
        rel = path.relative_to(vault)
    except ValueError:
        return False
    return len(rel.parts) >= 2 and rel.parts[0].lower() in NODE_DIRS


def heading_title(text: str) -> str:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("# "):
            return stripped[2:].strip()
    return ""


def frontmatter_field(fm: dict[str, str], field: str, text: str) -> str:
    if field == "id":
        return fm.get("id", "").strip() or fm.get("ea_id", "").strip()
    if field == "title":
        return fm.get("title", "").strip() or heading_title(text)
    return fm.get(field, "").strip()


def lint_vault(vault: Path) -> list[Violation]:
    if not vault.exists():
        return [Violation(path=vault, line=1, code="vault_missing", message=f"Vault path does not exist: {vault}")]

    md_files = sorted(p for p in vault.rglob("*.md") if is_wiki_node(p, vault))
    if not md_files:
        return []

    name_to_path = {p.stem.lower(): p for p in md_files}
    violations: list[Violation] = []
    seen_ids: dict[str, Path] = {}
    seen_slugs: dict[str, Path] = {}

    for path in md_files:
        text = path.read_text(encoding="utf-8", errors="replace")
        fm, fm_violations = parse_frontmatter(path, text)
        violations.extend(fm_violations)

        template = path.parent.name.lower()
        required = REQUIRED_BY_TEMPLATE.get(template, ())
        for field in required:
            if not frontmatter_field(fm, field, text):
                violations.append(Violation(path=path, line=1, code="missing_field", message=f"Missing required field '{field}'"))

        node_id = frontmatter_field(fm, "id", text)
        if node_id and node_id.upper() != "TBD":
            lower = node_id.lower()
            if lower in seen_ids:
                violations.append(Violation(path=path, line=1, code="duplicate_id", message=f"Duplicate id '{node_id}' (first: {seen_ids[lower]})"))
            else:
                seen_ids[lower] = path

        slug = frontmatter_field(fm, "slug", text).lower()
        if slug:
            if slug in seen_slugs:
                violations.append(Violation(path=path, line=1, code="duplicate_slug", message=f"Duplicate slug '{slug}' (first: {seen_slugs[slug]})"))
            else:
                seen_slugs[slug] = path

        for lineno, line in enumerate(text.splitlines(), start=1):
            for m in WIKI_LINK_RE.finditer(line):
                target = link_target(m.group(1))
                if target and target not in name_to_path:
                    violations.append(Violation(path=path, line=lineno, code="broken_xref", message=f"Broken link target '{m.group(1)}'"))

    index = vault / "_INDEX.md"
    if index.exists():
        index_text = index.read_text(encoding="utf-8", errors="replace")
        index_targets = {link_target(m.group(1)) for m in INDEX_LINK_RE.finditer(index_text) if link_target(m.group(1))}
        non_index_files = {p.stem.lower() for p in md_files if p.name.lower() != "_index.md"}
        for node in sorted(non_index_files - index_targets):
            violations.append(Violation(path=index, line=1, code="index_missing_node", message=f"Node missing from _INDEX.md: {node}"))
        for node in sorted(index_targets - non_index_files):
            violations.append(Violation(path=index, line=1, code="index_stale_node", message=f"_INDEX.md references missing node: {node}"))

    return violations


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lint_strategy_wiki")
    parser.add_argument("--vault", type=Path, default=DEFAULT_VAULT, help=f"Wiki vault root (default: {DEFAULT_VAULT})")
    args = parser.parse_args(argv)

    violations = lint_vault(args.vault)
    if not violations:
        print("OK: no strategy wiki lint violations")
        return 0

    for v in violations:
        print(f"{v.path}:{v.line}: {v.code}: {v.message}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
