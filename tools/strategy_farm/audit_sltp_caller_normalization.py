#!/usr/bin/env python3
"""Audit and mechanically normalize stop-trailing caller comparisons.

The server stores SL at symbol digits and QM_TM_MoveSL sends a digit-normalized
target.  A caller must therefore normalize its candidate before comparing it
with POSITION_SL.  This utility inventories every direct EA call and can wrap
the nearest local candidate assignment with QM_TM_NormalizePrice.

It intentionally does not compile or rebuild any EA.
"""

from __future__ import annotations

import argparse
import bisect
import json
import re
import subprocess
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path


CALL_RE = re.compile(r"\b(QM_TM_MoveSL|QM_TM_TrailATR)\s*\(")
SL_ASSIGN_RE = re.compile(
    r"\b(?:(?:const\s+)?double\s+)?(\w+)\s*=\s*"
    r"PositionGetDouble\s*\(\s*POSITION_SL\s*\)"
)
SL_NAME_RE = re.compile(
    r"\b(current_sl|cur_sl|curr_sl|sl|sl_price|sl_px|stop_loss|pos_sl|psl|cs)\b"
)
NORMALIZE_RE = re.compile(r"\b\w*[Nn]ormali[sz]\w*\s*\(")
SIMPLE_IDENTIFIER_RE = re.compile(r"^[A-Za-z_]\w*$")
REFERENCE_RE = re.compile(r"^[A-Za-z_]\w*(?:(?:\.[A-Za-z_]\w*)|(?:\[[^\]]+\]))*$")
RELATION = r"(?:<=|>=|<|>)"
FUNCTION_START_RE = re.compile(
    r"(?ms)^[ \t]*(?:(?:virtual|static|inline|const)\s+)*"
    r"[A-Za-z_]\w*(?:\s*[*&])?\s+([A-Za-z_]\w*)\s*"
    r"\([^;{}]*?\)\s*\{"
)


@dataclass(frozen=True)
class CallSite:
    path: str
    line: int
    call: str
    ticket_expression: str
    candidate_expression: str
    verdict: str
    comparison_variables: tuple[str, ...]


def _read_source(path: Path) -> tuple[str, str]:
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig"), "utf-8-sig"
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.decode("cp1252"), "cp1252"


def _write_source(path: Path, text: str, encoding: str) -> None:
    path.write_bytes(text.encode(encoding))


def _mask_comments_and_strings(text: str) -> str:
    out = list(text)
    i = 0
    mode = "code"
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if mode == "code":
            if ch == "/" and nxt == "/":
                out[i] = out[i + 1] = " "
                i += 2
                mode = "line_comment"
                continue
            if ch == "/" and nxt == "*":
                out[i] = out[i + 1] = " "
                i += 2
                mode = "block_comment"
                continue
            if ch == '"':
                out[i] = " "
                i += 1
                mode = "string"
                continue
        elif mode == "line_comment":
            if ch == "\n":
                mode = "code"
            else:
                out[i] = " "
        elif mode == "block_comment":
            if ch == "*" and nxt == "/":
                out[i] = out[i + 1] = " "
                i += 2
                mode = "code"
                continue
            if ch != "\n":
                out[i] = " "
        else:
            if ch == "\\" and i + 1 < len(text):
                out[i] = out[i + 1] = " "
                i += 2
                continue
            if ch == '"':
                out[i] = " "
                mode = "code"
            elif ch != "\n":
                out[i] = " "
        i += 1
    return "".join(out)


def _balanced_call_arguments(masked: str, original: str, call_start: int) -> list[str]:
    open_paren = masked.find("(", call_start)
    depth = 0
    close_paren = -1
    for pos in range(open_paren, len(masked)):
        if masked[pos] == "(":
            depth += 1
        elif masked[pos] == ")":
            depth -= 1
            if depth == 0:
                close_paren = pos
                break
    if close_paren < 0:
        return []

    inner_masked = masked[open_paren + 1 : close_paren]
    inner_original = original[open_paren + 1 : close_paren]
    starts = [0]
    depth = 0
    for index, ch in enumerate(inner_masked):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            starts.append(index + 1)
    ends = [start - 1 for start in starts[1:]] + [len(inner_original)]
    return [inner_original[start:end].strip() for start, end in zip(starts, ends)]


def _line_starts(text: str) -> list[int]:
    return [0] + [match.end() for match in re.finditer("\n", text)]


def _function_floor(masked: str, before: int) -> int:
    floor = 0
    for match in FUNCTION_START_RE.finditer(masked, 0, before):
        if match.group(1) not in {"if", "for", "while", "switch", "catch"}:
            floor = match.start()
    return floor


def _mask_management_calls(text: str) -> str:
    out = list(text)
    for match in CALL_RE.finditer(text):
        open_paren = text.find("(", match.start())
        depth = 0
        close_paren = -1
        for pos in range(open_paren, len(text)):
            if text[pos] == "(":
                depth += 1
            elif text[pos] == ")":
                depth -= 1
                if depth == 0:
                    close_paren = pos
                    break
        if close_paren < 0:
            continue
        for pos in range(match.start(), close_paren + 1):
            if out[pos] != "\n":
                out[pos] = " "
    return "".join(out)


def _normalizer_inner_reference(candidate: str) -> str | None:
    masked = _mask_comments_and_strings(candidate)
    match = NORMALIZE_RE.match(masked)
    if match is None or match.start() != 0:
        return None
    args = _balanced_call_arguments(masked, candidate, match.start())
    if not args:
        return None
    inner = " ".join(args[-1].split())
    return inner if REFERENCE_RE.fullmatch(inner) else None


def _inside_normalizer(clause: str, position: int) -> bool:
    for match in reversed(list(NORMALIZE_RE.finditer(clause, 0, position))):
        open_paren = clause.find("(", match.start())
        if open_paren < 0:
            continue
        depth = 0
        for char in clause[open_paren:position]:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
        if depth > 0:
            return True
    return False


def _target_matches_in_price_comparison(
    clause: str, candidate_re: re.Pattern[str], sl_vars: set[str]
) -> list[re.Match[str]]:
    target_matches = list(candidate_re.finditer(clause))
    if not target_matches:
        return []
    relation_matches = list(re.finditer(RELATION, clause))
    if not relation_matches:
        return []
    sl_matches = [
        match
        for sl_var in sl_vars
        for match in re.finditer(rf"\b{re.escape(sl_var)}\b", clause)
    ]
    accepted: dict[tuple[int, int], re.Match[str]] = {}
    for target in target_matches:
        for sl_match in sl_matches:
            left, right = sorted((target, sl_match), key=lambda item: item.start())
            between = clause[left.end() : right.start()]
            if any(token in between for token in ("?", ":")):
                continue
            without_comparators = re.sub(r"<=|>=|==|!=", "", between)
            if "=" in without_comparators:
                continue
            if any(left.end() <= relation.start() < right.start() for relation in relation_matches):
                accepted[(target.start(), target.end())] = target

            # Difference-to-threshold idioms place both prices on the same side
            # of the relational operator, for example:
            #   candidate - current_sl + tick * 0.1 >= step
            #   MathAbs(current_sl - candidate) <= point
            # Treat these as comparisons only when the two price operands are
            # explicitly subtracted and the next relation is in the same
            # ternary branch.
            if "-" in between:
                later_end = right.end()
                for relation in relation_matches:
                    if relation.start() < later_end:
                        continue
                    suffix = clause[later_end : relation.start()]
                    if any(token in suffix for token in ("?", ":", ",", "=")):
                        break
                    accepted[(target.start(), target.end())] = target
                    break

        # Difference-to-threshold idiom: MathAbs(current_sl - target) > epsilon.
        for abs_match in re.finditer(r"\bMathAbs\s*\(([^()]*)\)", clause):
            if not (abs_match.start() <= target.start() < abs_match.end()):
                continue
            body = abs_match.group(1)
            if not any(re.search(rf"\b{re.escape(sl_var)}\b", body) for sl_var in sl_vars):
                continue
            if any(relation.start() >= abs_match.end() for relation in relation_matches):
                accepted[(target.start(), target.end())] = target
    return list(accepted.values())


def _comparison_details(
    prefix: str, candidate: str, sl_vars: set[str]
) -> tuple[tuple[str, ...], bool]:
    # A direct Normalize(symbol, reference) call still needs its *inner* raw
    # reference audited: normalizing only at send time is the defect in scope.
    comparison_target = candidate
    inner_reference = _normalizer_inner_reference(candidate)
    if inner_reference is not None:
        comparison_target = inner_reference

    if REFERENCE_RE.fullmatch(comparison_target):
        candidate_re = re.compile(
            rf"(?<!\w){re.escape(comparison_target)}(?!\w)"
        )
    else:
        whitespace_flexible = re.sub(r"\\\s+", r"\\s+", re.escape(comparison_target))
        candidate_re = re.compile(whitespace_flexible)

    hits: set[str] = set()
    saw_raw = False
    saw_normalized = False
    clauses = re.split(r"[;{}]|&&|\|\|", _mask_management_calls(prefix))
    for sl_var in sl_vars:
        if comparison_target == sl_var:
            continue
        for clause in clauses:
            matches = _target_matches_in_price_comparison(clause, candidate_re, {sl_var})
            if not matches:
                continue
            hits.add(comparison_target)
            for match in matches:
                if _inside_normalizer(clause, match.start()):
                    saw_normalized = True
                else:
                    saw_raw = True
    return tuple(sorted(hits)), bool(saw_normalized and not saw_raw)


def _comparison_replacement_spans(
    masked: str,
    candidate: str,
    before: int,
    floor: int,
    sl_vars: set[str],
) -> list[tuple[int, int]]:
    target = _normalizer_inner_reference(candidate)
    if target is None:
        return []
    prefix = masked[floor:before]
    searchable = _mask_management_calls(prefix)
    target_re = re.compile(rf"(?<!\w){re.escape(target)}(?!\w)")
    delimiters = list(re.finditer(r"[;{}]|&&|\|\|", searchable))
    bounds: list[tuple[int, int]] = []
    start = 0
    for delimiter in delimiters:
        bounds.append((start, delimiter.start()))
        start = delimiter.end()
    bounds.append((start, len(searchable)))

    replacements: list[tuple[int, int]] = []
    for start, end in bounds:
        clause = searchable[start:end]
        for match in _target_matches_in_price_comparison(clause, target_re, sl_vars):
            if not _inside_normalizer(clause, match.start()):
                replacements.append((floor + start + match.start(), floor + start + match.end()))
    return replacements


def _nearest_assignment(
    masked: str, candidate: str, before: int, floor: int
) -> tuple[int, int, int, int] | None:
    escaped = re.escape(candidate)
    pattern = re.compile(
        rf"(?m)^[ \t]*(?:(?:const\s+)?double\s+)?\b{escaped}\b[ \t]*=[ \t]*([^;]+);",
        re.DOTALL,
    )
    found = None
    for match in pattern.finditer(masked, floor, before):
        found = (match.start(), match.end(), match.start(1), match.end(1))
    return found


def scan_source(
    path: Path, repo: Path, original: str
) -> tuple[list[CallSite], list[dict[str, object]]]:
    masked = _mask_comments_and_strings(original)
    starts = _line_starts(original)
    calls: list[CallSite] = []
    fix_rows: list[dict[str, object]] = []

    for call_match in CALL_RE.finditer(masked):
        # Function declarations are definitions, not caller sites.
        line_prefix = masked[masked.rfind("\n", 0, call_match.start()) + 1 : call_match.start()]
        if re.search(r"\b(?:bool|void)\s*$", line_prefix):
            continue
        call_name = call_match.group(1)
        args = _balanced_call_arguments(masked, original, call_match.start())
        if len(args) < 2:
            continue
        ticket = " ".join(args[0].split())
        candidate = " ".join(args[1].split())
        line = bisect.bisect_right(starts, call_match.start())
        floor = max(_function_floor(masked, call_match.start()), starts[max(0, line - 121)])
        prefix = masked[floor : call_match.start()]
        sl_vars = set(SL_ASSIGN_RE.findall(prefix))
        sl_vars.update(SL_NAME_RE.findall(prefix))
        # QM_TM_TrailATR computes and normalizes its target internally.  Its caller
        # has no target-price comparison to audit.
        compared, comparison_normalized = (
            ((), False)
            if call_name == "QM_TM_TrailATR"
            else _comparison_details(prefix, candidate, sl_vars)
        )
        assignment = None
        assignment_normalized = False
        if SIMPLE_IDENTIFIER_RE.fullmatch(candidate):
            assignment = _nearest_assignment(masked, candidate, call_match.start(), floor)
            if assignment is not None:
                rhs = original[assignment[2] : assignment[3]]
                assignment_normalized = bool(NORMALIZE_RE.search(rhs))

        if not compared:
            verdict = "not a comparison"
        elif comparison_normalized or assignment_normalized:
            verdict = "already normalized"
        else:
            verdict = "raw comparison"
            fix_rows.append(
                {
                    "path": path,
                    "line": line,
                    "ticket": ticket,
                    "candidate": candidate,
                    "assignment": assignment,
                }
            )
        calls.append(
            CallSite(
                path=path.relative_to(repo).as_posix(),
                line=line,
                call=call_name,
                ticket_expression=ticket,
                candidate_expression=candidate,
                verdict=verdict,
                comparison_variables=compared,
            )
        )
    return calls, fix_rows


def scan_file(path: Path, repo: Path) -> tuple[list[CallSite], list[dict[str, object]]]:
    original, _ = _read_source(path)
    return scan_source(path, repo, original)


def _target_paths(repo: Path) -> list[Path]:
    paths = list((repo / "framework" / "EAs").glob("*/*.mq5"))
    paths.append(repo / "framework" / "include" / "QM" / "QM_TradeManagement.mqh")
    paths.extend((repo / "framework" / "include" / "QM" / "modules").glob("*.mqh"))
    return sorted(path for path in paths if path.is_file())


def scan(repo: Path) -> tuple[list[CallSite], list[dict[str, object]]]:
    all_calls: list[CallSite] = []
    all_fixes: list[dict[str, object]] = []
    for path in _target_paths(repo):
        calls, fixes = scan_file(path, repo)
        all_calls.extend(calls)
        all_fixes.extend(fixes)
    return all_calls, all_fixes


def scan_revision(repo: Path, revision: str) -> list[CallSite]:
    calls: list[CallSite] = []
    paths = _target_paths(repo)
    proc = subprocess.Popen(
        ["git", "cat-file", "--batch"],
        cwd=repo,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )
    assert proc.stdin is not None
    assert proc.stdout is not None
    for path in paths:
        relative = path.relative_to(repo).as_posix()
        proc.stdin.write(f"{revision}:{relative}\n".encode("utf-8"))
        proc.stdin.flush()
        header = proc.stdout.readline().decode("utf-8", errors="replace").strip()
        if header.endswith(" missing"):
            continue
        parts = header.split()
        if len(parts) != 3 or parts[1] != "blob":
            proc.kill()
            raise RuntimeError(f"unexpected git cat-file header: {header!r}")
        size = int(parts[2])
        raw = proc.stdout.read(size)
        separator = proc.stdout.read(1)
        if separator != b"\n":
            proc.kill()
            raise RuntimeError("malformed git cat-file batch response")
        if raw.startswith(b"\xef\xbb\xbf"):
            original = raw.decode("utf-8-sig")
        else:
            try:
                original = raw.decode("utf-8")
            except UnicodeDecodeError:
                original = raw.decode("cp1252")
        file_calls, _ = scan_source(path, repo, original)
        calls.extend(file_calls)
    proc.stdin.close()
    return_code = proc.wait()
    if return_code != 0:
        raise subprocess.CalledProcessError(return_code, proc.args)
    return calls


def _dirty_paths(repo: Path, paths: list[Path]) -> list[str]:
    relative = sorted({path.relative_to(repo).as_posix() for path in paths})
    if not relative:
        return []
    result = subprocess.run(
        ["git", "status", "--porcelain", "--", *relative],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def apply_fixes(repo: Path, fixes: list[dict[str, object]]) -> tuple[int, list[str]]:
    by_path: dict[Path, list[dict[str, object]]] = {}
    unresolved: list[str] = []
    for row in fixes:
        path = row["path"]
        assert isinstance(path, Path)
        by_path.setdefault(path, []).append(row)

    dirty = _dirty_paths(repo, list(by_path))
    if dirty:
        raise SystemExit("refusing to touch dirty target sources:\n" + "\n".join(dirty))

    changed = 0
    for path, rows in by_path.items():
        text, encoding = _read_source(path)
        replacements: dict[tuple[int, int], str] = {}
        for row in rows:
            assignment = row["assignment"]
            candidate = str(row["candidate"])
            if assignment is None or not SIMPLE_IDENTIFIER_RE.fullmatch(candidate):
                unresolved.append(
                    f"{path.relative_to(repo).as_posix()}:{row['line']}:{candidate}"
                )
                continue
            _, _, rhs_start, rhs_end = assignment
            key = (int(rhs_start), int(rhs_end))
            rhs = text[key[0] : key[1]].strip()
            replacement = f"QM_TM_NormalizePrice(_Symbol, {rhs})"
            previous = replacements.get(key)
            if previous is not None and previous != replacement:
                unresolved.append(
                    f"{path.relative_to(repo).as_posix()}:{row['line']}:shared-assignment-ticket-conflict"
                )
                continue
            replacements[key] = replacement

        for (start, end), replacement in sorted(replacements.items(), reverse=True):
            text = text[:start] + replacement + text[end:]
            changed += 1
        if replacements:
            _write_source(path, text, encoding)
    return changed, unresolved


def apply_wrapped_comparison_fixes(
    repo: Path, fixes: list[dict[str, object]]
) -> tuple[int, list[str]]:
    plans: dict[Path, dict[tuple[int, int], str]] = {}
    unresolved: list[str] = []
    for row in fixes:
        path = row["path"]
        assert isinstance(path, Path)
        candidate = str(row["candidate"])
        if _normalizer_inner_reference(candidate) is None:
            continue
        original, _ = _read_source(path)
        masked = _mask_comments_and_strings(original)
        starts = _line_starts(original)
        line = int(row["line"])
        floor = max(_function_floor(masked, call_matches[-1].start()), starts[max(0, line - 121)])
        call_matches = [
            match for match in CALL_RE.finditer(masked)
            if bisect.bisect_right(starts, match.start()) == line
        ]
        if not call_matches:
            unresolved.append(f"{path.relative_to(repo).as_posix()}:{line}:call-not-found")
            continue
        before = call_matches[-1].start()
        spans = _comparison_replacement_spans(
            masked,
            candidate,
            before,
            floor,
            set(SL_ASSIGN_RE.findall(masked[floor:before]))
            | set(SL_NAME_RE.findall(masked[floor:before])),
        )
        if not spans:
            unresolved.append(
                f"{path.relative_to(repo).as_posix()}:{line}:comparison-span-not-found"
            )
            continue
        path_plan = plans.setdefault(path, {})
        for span in spans:
            path_plan[span] = candidate

    dirty = _dirty_paths(repo, list(plans))
    if dirty:
        raise SystemExit("refusing to touch dirty target sources:\n" + "\n".join(dirty))

    changed = 0
    for path, replacements in plans.items():
        text_value, encoding = _read_source(path)
        for (start, end), replacement in sorted(replacements.items(), reverse=True):
            text_value = text_value[:start] + replacement + text_value[end:]
            changed += 1
        _write_source(path, text_value, encoding)
    return changed, unresolved


def write_manifest(path: Path, repo: Path, calls: list[CallSite]) -> None:
    baseline_revision = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    baseline_calls = scan_revision(repo, baseline_revision)
    baseline_by_path: dict[str, list[CallSite]] = {}
    for call in baseline_calls:
        baseline_by_path.setdefault(call.path, []).append(call)

    output_rows: list[dict[str, object]] = []
    path_ordinals: Counter[str] = Counter()
    for call in calls:
        ordinal = path_ordinals[call.path]
        path_ordinals[call.path] += 1
        baseline_rows = baseline_by_path.get(call.path, [])
        baseline = baseline_rows[ordinal] if ordinal < len(baseline_rows) else None
        verdict = call.verdict
        if (
            baseline is not None
            and baseline.verdict == "raw comparison"
            and call.verdict == "already normalized"
        ):
            verdict = "fixed here"
        row = asdict(call)
        row["verdict"] = verdict
        output_rows.append(row)

    counts = Counter(str(row["verdict"]) for row in output_rows)
    payload = {
        "schema": "qm.sltp_caller_normalization_audit.v1",
        "scope": (
            "framework/EAs/*/*.mq5 plus QM_TradeManagement.mqh and "
            "framework/include/QM/modules/*.mqh direct QM_TM_MoveSL/QM_TM_TrailATR calls"
        ),
        "repository_head": baseline_revision,
        "counts": dict(sorted(counts.items())),
        "baseline": "HEAD",
        "call_sites": output_rows,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--fix", action="store_true")
    parser.add_argument("--fix-wrapped-comparisons", action="store_true")
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    repo = args.root.resolve()

    calls, fixes = scan(repo)
    unresolved: list[str] = []
    if args.fix:
        changed, unresolved = apply_fixes(repo, fixes)
        print(f"assignments_normalized={changed}")
        calls, fixes = scan(repo)
    if args.fix_wrapped_comparisons:
        changed, wrapper_unresolved = apply_wrapped_comparison_fixes(repo, fixes)
        unresolved.extend(wrapper_unresolved)
        print(f"wrapped_comparisons_normalized={changed}")
        calls, fixes = scan(repo)

    counts = Counter(call.verdict for call in calls)
    print(json.dumps(dict(sorted(counts.items())), sort_keys=True))
    if unresolved:
        print("unresolved_mechanical_fixes:")
        print("\n".join(unresolved))
    if args.manifest:
        manifest = args.manifest
        if not manifest.is_absolute():
            manifest = repo / manifest
        write_manifest(manifest, repo, calls)
        print(f"manifest={manifest}")
    return 1 if fixes or unresolved else 0


if __name__ == "__main__":
    raise SystemExit(main())
