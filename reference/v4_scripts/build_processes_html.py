#!/usr/bin/env python3
"""
Build processes.html from Company/Processes markdown specs.

QUAA-150 deliverables:
1) Aggregate markdown docs into one HTML page.
2) Write output to G:/Meine Ablage/QuantMechanica/Processes/processes.html.
3) Patch Dashboard v3 HTML with a link to the generated process page.
"""

from __future__ import annotations

import argparse
import html
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


DEFAULT_ROOT = Path(r"G:/Meine Ablage/QuantMechanica")
TERMINAL_DASHBOARD_PATH = Path(
    r"C:/Users/fabia/AppData/Roaming/MetaQuotes/Terminal/"
    r"6C3C6A11D1C3791DD4DBF45421BF8028/MQL5/Files/edge_validation/output/project_dashboard.html"
)
PROCESSES_FILE_URI = "file:///G:/Meine%20Ablage/QuantMechanica/Processes/processes.html"
DASHBOARD_FILE_URI = "file:///G:/Meine%20Ablage/QuantMechanica/project_dashboard.html"

LINK_BLOCK_START = "<!-- QM_PROCESSES_LINK_START -->"
LINK_BLOCK_END = "<!-- QM_PROCESSES_LINK_END -->"
LINK_BLOCK = (
    f"{LINK_BLOCK_START}\n"
    "<style id=\"qm-processes-link-style\">\n"
    ".qm-processes-link{margin:18px auto 0;max-width:1680px;padding:0 24px 20px}\n"
    ".qm-processes-link a{display:inline-flex;align-items:center;gap:8px;"
    "padding:8px 12px;border-radius:10px;border:1px solid #2a424b;"
    "background:#0b151a;color:#bbffe7;font:600 12px/1.2 'Source Code Pro',monospace;"
    "text-decoration:none;letter-spacing:.03em}\n"
    ".qm-processes-link a:hover{border-color:#4f727f;background:#10232b}\n"
    "</style>\n"
    "<div class=\"qm-processes-link\">"
    f"<a href=\"{PROCESSES_FILE_URI}\" target=\"_blank\" rel=\"noopener noreferrer\">"
    "Open Process Landscape (Mermaid)"
    "</a></div>\n"
    f"{LINK_BLOCK_END}"
)

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n?", re.S)
H1_RE = re.compile(r"^#\s+(.+)$", re.M)
H2_RE = re.compile(r"^##\s+(.+)$", re.M)
BOLD_RE = re.compile(r"\*\*([^*]+)\*\*")
ITALIC_RE = re.compile(r"(?<!\*)\*([^*\n]+)\*(?!\*)")
INLINE_CODE_RE = re.compile(r"`([^`]+)`")
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


@dataclass
class ProcessDoc:
    path: Path
    slug: str
    title: str
    owner: str
    last_updated: str
    intro_markdown: str
    sections: list[tuple[str, str]]


def read_text(path: Path) -> str:
    for encoding in ("utf-8", "utf-8-sig", "cp1252"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("utf-8", b"", 0, 1, f"Could not decode {path}")


def parse_frontmatter(markdown: str) -> tuple[dict[str, str], str]:
    match = FRONTMATTER_RE.match(markdown)
    if not match:
        return {}, markdown
    data: dict[str, str] = {}
    for raw_line in match.group(1).splitlines():
        if ":" not in raw_line:
            continue
        key, value = raw_line.split(":", 1)
        data[key.strip().lower()] = value.strip()
    body = markdown[match.end() :]
    return data, body


def slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug or "process"


def split_intro_and_sections(body: str) -> tuple[str, list[tuple[str, str]], str]:
    matches = list(H2_RE.finditer(body))
    h1_match = H1_RE.search(body)
    h1_title = h1_match.group(1).strip() if h1_match else ""

    intro_source = body[: matches[0].start()] if matches else body
    intro_lines: list[str] = []
    for line in intro_source.splitlines():
        if line.strip().startswith("#"):
            continue
        intro_lines.append(line)
    intro = "\n".join(intro_lines).strip()

    sections: list[tuple[str, str]] = []
    for idx, match in enumerate(matches):
        name = match.group(1).strip()
        start = match.end()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(body)
        content = body[start:end].strip()
        sections.append((name, content))

    return intro, sections, h1_title


def render_inline(text: str) -> str:
    placeholders: dict[str, str] = {}

    def stash(value: str) -> str:
        key = f"@@INLINE_{len(placeholders)}@@"
        placeholders[key] = value
        return key

    text = INLINE_CODE_RE.sub(lambda m: stash(f"<code>{html.escape(m.group(1))}</code>"), text)
    text = LINK_RE.sub(
        lambda m: stash(
            f'<a href="{html.escape(m.group(2), quote=True)}" '
            f'target="_blank" rel="noopener noreferrer">{html.escape(m.group(1))}</a>'
        ),
        text,
    )
    text = html.escape(text)
    text = BOLD_RE.sub(r"<strong>\1</strong>", text)
    text = ITALIC_RE.sub(r"<em>\1</em>", text)
    for key, value in placeholders.items():
        text = text.replace(key, value)
        text = text.replace(html.escape(key), value)
    return text


def is_table_separator(line: str) -> bool:
    cleaned = line.replace("|", "").replace(" ", "")
    return bool(cleaned) and all(ch in "-:" for ch in cleaned)


def split_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def render_table(lines: list[str], index: int) -> tuple[str, int]:
    header = split_table_row(lines[index])
    index += 2  # skip separator line
    rows: list[list[str]] = []
    while index < len(lines):
        raw = lines[index].strip()
        if not raw.startswith("|"):
            break
        rows.append(split_table_row(lines[index]))
        index += 1

    header_html = "".join(f"<th>{render_inline(cell)}</th>" for cell in header)
    body_rows = []
    for row in rows:
        cells = "".join(f"<td>{render_inline(cell)}</td>" for cell in row)
        body_rows.append(f"<tr>{cells}</tr>")
    body_html = "".join(body_rows)
    table_html = (
        "<div class=\"table-wrap\"><table>"
        f"<thead><tr>{header_html}</tr></thead>"
        f"<tbody>{body_html}</tbody>"
        "</table></div>"
    )
    return table_html, index


def render_list(lines: list[str], index: int, ordered: bool) -> tuple[str, int]:
    items: list[str] = []
    pattern = r"^\s*\d+\.\s+(.*)$" if ordered else r"^\s*-\s+(.*)$"
    while index < len(lines):
        match = re.match(pattern, lines[index])
        if not match:
            break
        items.append(f"<li>{render_inline(match.group(1).strip())}</li>")
        index += 1
    tag = "ol" if ordered else "ul"
    return f"<{tag}>{''.join(items)}</{tag}>", index


def render_mermaid_block(diagram_id: str, code: str) -> str:
    escaped = html.escape(code)
    return (
        f'<div class="diagram-shell" data-diagram-id="{diagram_id}">'
        '<div class="diagram-toolbar">'
        "<span>Mermaid Diagram</span>"
        '<div class="diagram-actions">'
        '<button type="button" data-action="zoom-in">Zoom +</button>'
        '<button type="button" data-action="zoom-out">Zoom -</button>'
        '<button type="button" data-action="reset">Reset</button>'
        '<button type="button" data-action="export">Export SVG</button>'
        "</div></div>"
        '<div class="diagram-canvas">'
        f'<pre class="mermaid">{escaped}</pre>'
        "</div></div>"
    )


def render_markdown(markdown: str, slug: str, diagram_counter: list[int]) -> str:
    lines = markdown.strip().splitlines()
    if not lines:
        return '<div class="empty-note">No details provided.</div>'

    rendered: list[str] = []
    i = 0
    while i < len(lines):
        raw_line = lines[i]
        stripped = raw_line.strip()

        if not stripped:
            i += 1
            continue

        if stripped.startswith("```"):
            lang = stripped[3:].strip().lower()
            i += 1
            code_lines: list[str] = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_lines.append(lines[i])
                i += 1
            if i < len(lines):
                i += 1
            code = "\n".join(code_lines).strip("\n")
            if lang == "mermaid":
                diagram_id = f"{slug}-diagram-{diagram_counter[0]}"
                diagram_counter[0] += 1
                rendered.append(render_mermaid_block(diagram_id, code))
            else:
                rendered.append(f"<pre><code>{html.escape(code)}</code></pre>")
            continue

        if stripped.startswith("|") and i + 1 < len(lines) and is_table_separator(lines[i + 1]):
            table_html, i = render_table(lines, i)
            rendered.append(table_html)
            continue

        if re.match(r"^\s*-\s+", raw_line):
            list_html, i = render_list(lines, i, ordered=False)
            rendered.append(list_html)
            continue

        if re.match(r"^\s*\d+\.\s+", raw_line):
            list_html, i = render_list(lines, i, ordered=True)
            rendered.append(list_html)
            continue

        if stripped.startswith("### "):
            rendered.append(f"<h5>{render_inline(stripped[4:])}</h5>")
            i += 1
            continue

        paragraph_lines: list[str] = []
        while i < len(lines):
            check = lines[i].strip()
            if not check:
                break
            if (
                check.startswith("```")
                or check.startswith("### ")
                or check.startswith("|")
                or re.match(r"^\s*-\s+", lines[i])
                or re.match(r"^\s*\d+\.\s+", lines[i])
            ):
                break
            paragraph_lines.append(check)
            i += 1
        if paragraph_lines:
            rendered.append(f"<p>{render_inline(' '.join(paragraph_lines))}</p>")
        else:
            i += 1

    return "\n".join(rendered) if rendered else '<div class="empty-note">No details provided.</div>'


def parse_process_doc(path: Path, used_slugs: set[str]) -> ProcessDoc:
    raw = read_text(path)
    frontmatter, body = parse_frontmatter(raw)
    intro, sections, h1_title = split_intro_and_sections(body)

    fallback_title = h1_title or path.stem
    title = frontmatter.get("title", "").strip() or fallback_title
    owner = frontmatter.get("owner", "unknown")
    last_updated = frontmatter.get("last-updated", "unknown")

    base_slug = slugify(path.stem)
    slug = base_slug
    suffix = 2
    while slug in used_slugs:
        slug = f"{base_slug}-{suffix}"
        suffix += 1
    used_slugs.add(slug)

    return ProcessDoc(
        path=path,
        slug=slug,
        title=title,
        owner=owner,
        last_updated=last_updated,
        intro_markdown=intro,
        sections=sections,
    )


def list_process_markdown_paths(processes_dir: Path) -> list[Path]:
    paths = sorted(
        [
            p
            for p in processes_dir.glob("*.md")
            if p.name.lower() != "readme.md" and re.match(r"^\d{2}-", p.name)
        ]
    )
    if not paths:
        raise FileNotFoundError(f"No process markdown files found in {processes_dir}")
    return paths


def load_docs(paths: Iterable[Path]) -> list[ProcessDoc]:
    used_slugs: set[str] = set()
    return [parse_process_doc(path, used_slugs) for path in paths]


def render_docs(docs: Iterable[ProcessDoc]) -> tuple[str, str]:
    nav_items: list[str] = []
    cards: list[str] = []
    diagram_counter = [1]

    for doc in docs:
        nav_items.append(f'        <a class="nav-link" href="#{doc.slug}">{html.escape(doc.title)}</a>')

        intro_html = ""
        if doc.intro_markdown:
            intro_html = (
                '<section class="section"><h4>Overview</h4>'
                f"{render_markdown(doc.intro_markdown, doc.slug, diagram_counter)}"
                "</section>"
            )

        section_blocks: list[str] = []
        preferred_order = ["Trigger", "Actors", "Steps", "Exits", "SLA"]
        seen: set[str] = set()

        section_map = {name: content for name, content in doc.sections}
        ordered_names = [name for name in preferred_order if name in section_map]
        ordered_names.extend(name for name, _ in doc.sections if name not in ordered_names)

        for section_name in ordered_names:
            if section_name in seen:
                continue
            seen.add(section_name)
            body_html = render_markdown(section_map[section_name], doc.slug, diagram_counter)
            section_blocks.append(
                f'<section class="section"><h4>{html.escape(section_name)}</h4>{body_html}</section>'
            )

        cards.append(
            f'<article class="process-card" id="{doc.slug}">'
            '<header class="process-head">'
            f"<h3>{html.escape(doc.title)}</h3>"
            '<div class="process-meta">'
            f'<span class="chip"><strong>Owner</strong>{html.escape(doc.owner)}</span>'
            f'<span class="chip"><strong>Updated</strong>{html.escape(doc.last_updated)}</span>'
            f'<span class="chip"><strong>Source</strong>{html.escape(doc.path.name)}</span>'
            "</div></header>"
            '<div class="process-body">'
            f"{intro_html}{''.join(section_blocks)}"
            "</div></article>"
        )

    return "\n".join(nav_items), "\n".join(cards)


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text(content, encoding="utf-8", newline="\n")
    os.replace(temp_path, path)


def patch_dashboard_file(path: Path, dry_run: bool = False) -> bool:
    if not path.exists():
        return False
    original = read_text(path)

    block_re = re.compile(re.escape(LINK_BLOCK_START) + r".*?" + re.escape(LINK_BLOCK_END), re.S)
    if block_re.search(original):
        patched = block_re.sub(LINK_BLOCK, original)
    else:
        lower = original.lower()
        body_index = lower.rfind("</body>")
        if body_index != -1:
            patched = original[:body_index] + "\n" + LINK_BLOCK + "\n" + original[body_index:]
        else:
            patched = original.rstrip() + "\n\n" + LINK_BLOCK + "\n"

    if patched == original:
        return False
    if not dry_run:
        atomic_write(path, patched)
    return True


def patch_dashboards(root: Path, skip_dashboard_patch: bool, dry_run: bool) -> list[Path]:
    if skip_dashboard_patch:
        return []

    patched_dashboards: list[Path] = []
    for candidate in [root / "project_dashboard.html", TERMINAL_DASHBOARD_PATH]:
        if patch_dashboard_file(candidate, dry_run=dry_run):
            patched_dashboards.append(candidate)
    return patched_dashboards


def is_output_stale(output_path: Path, input_paths: Iterable[Path]) -> bool:
    if not output_path.exists():
        return True
    output_mtime = output_path.stat().st_mtime
    newest_input_mtime = max(path.stat().st_mtime for path in input_paths)
    return output_mtime < newest_input_mtime


def build_page(root: Path, skip_dashboard_patch: bool, dry_run: bool, guardrail: bool) -> int:
    processes_dir = root / "Company" / "Processes"
    template_path = root / "Company" / "Templates" / "processes_template.html"
    output_path = root / "Processes" / "processes.html"

    if not template_path.exists():
        raise FileNotFoundError(f"Template not found: {template_path}")
    if not processes_dir.exists():
        raise FileNotFoundError(f"Process source folder not found: {processes_dir}")

    markdown_paths = list_process_markdown_paths(processes_dir)
    input_paths = [template_path, *markdown_paths]
    if guardrail and not is_output_stale(output_path, input_paths):
        patched_dashboards = patch_dashboards(root, skip_dashboard_patch, dry_run)
        print(
            f"Guardrail: {output_path} is fresh against {len(input_paths)} input files; "
            "skipping rebuild."
        )
        if skip_dashboard_patch:
            print("Dashboard patch skipped (--skip-dashboard-patch).")
        elif patched_dashboards:
            print("Patched dashboard link in:")
            for path in patched_dashboards:
                print(f"  - {path}")
        else:
            print("No dashboard files needed patching.")
        return 0

    docs = load_docs(markdown_paths)
    nav_html, sections_html = render_docs(docs)
    template = read_text(template_path)

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    replacements = {
        "{{generated_at}}": generated_at,
        "{{source_dir}}": "Company/Processes/*.md",
        "{{process_count}}": str(len(docs)),
        "{{sidebar_items}}": nav_html,
        "{{process_sections}}": sections_html,
        "{{dashboard_link}}": DASHBOARD_FILE_URI,
    }
    page = template
    for placeholder, value in replacements.items():
        page = page.replace(placeholder, value)

    if not dry_run:
        atomic_write(output_path, page)

    patched_dashboards = patch_dashboards(root, skip_dashboard_patch, dry_run)

    print(f"Built {output_path} from {len(docs)} process documents.")
    if skip_dashboard_patch:
        print("Dashboard patch skipped (--skip-dashboard-patch).")
    elif patched_dashboards:
        print("Patched dashboard link in:")
        for path in patched_dashboards:
            print(f"  - {path}")
    else:
        print("No dashboard files needed patching.")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build processes.html from Company/Processes docs.")
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help="QuantMechanica root folder. Default: G:/Meine Ablage/QuantMechanica",
    )
    parser.add_argument(
        "--skip-dashboard-patch",
        action="store_true",
        help="Do not patch dashboard HTML with process-link footer.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and render in memory but do not write files.",
    )
    parser.add_argument(
        "--guardrail",
        action="store_true",
        help="Only rebuild when Processes/processes.html is stale versus template/process sources.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        return build_page(
            root=args.root,
            skip_dashboard_patch=args.skip_dashboard_patch,
            dry_run=args.dry_run,
            guardrail=args.guardrail,
        )
    except Exception as exc:  # pragma: no cover - shell-visible failure path
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
