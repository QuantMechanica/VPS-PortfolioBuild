"""Validate and bundle pattern-permission predicate fixtures.

The 77 predicates in framework/include/QM/QM_PatternPermission.mqh are pure
functions of a QM_PPBars window, so they can be tested exhaustively without any
market data: hand-built bar windows in, boolean out. This script is the bridge.

It reads the per-group fixture JSON files, validates them hard, expands them to
the bar count each predicate actually requires, and emits one flat CSV that the
MQL5 runner (framework/tests/QM_pattern_permission_fixture_runner.mq5) consumes.
The runner calls the REAL QM_PP_Evaluate; nothing here re-implements a predicate,
because a second implementation would only test itself.

Single source of truth for ids and bar requirements is the .mqh itself: both the
QM_PatternId enum and the QM_PP_RequiredBars switch are parsed out of it, so a
fixture naming an unknown predicate, or one too short for its window, fails here
rather than silently evaluating to false in the runner.

Usage:
    python framework/scripts/build_pattern_fixture_bundle.py            # validate
    python framework/scripts/build_pattern_fixture_bundle.py --emit     # + write CSV
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
HEADER = REPO_ROOT / "framework" / "include" / "QM" / "QM_PatternPermission.mqh"
FIXTURE_DIR = REPO_ROOT / "framework" / "tests" / "fixtures" / "pattern_permission"
BUNDLE_CSV = FIXTURE_DIR / "_bundle" / "pattern_fixtures.csv"

VALID_CASES = {"positive", "negative", "boundary"}
# `pattern_definition`  — expected value derived from what the pattern IS.
# `implementation_threshold` — expected value derived from a numeric threshold
#   declared in the source. Legitimate ONLY for boundary cases: a boundary is
#   not definable without the threshold it sits on. Anything else claiming this
#   basis is circular (writing the test from the code it tests) and is rejected.
VALID_BASES = {"pattern_definition", "implementation_threshold"}
DEFAULT_ANCHOR = "2026-06-15"
MAX_LOOKBACK = 120


class FixtureError(Exception):
    pass


def _strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", " ", text)


def parse_predicate_ids(src: str) -> dict[str, int]:
    m = re.search(r"enum QM_PatternId\s*\{(.*?)\};", src, re.S)
    if not m:
        raise FixtureError("QM_PatternId enum not found in header")
    ids = {n: int(v) for n, v in
           re.findall(r"(QM_PP_[A-Z0-9_]+)\s*=\s*(\d+)", m.group(1))}
    ids.pop("QM_PP_NONE", None)
    return ids


def parse_required_bars(src: str) -> tuple[dict[str, int], int]:
    """Parse the QM_PP_RequiredBars switch -> {predicate: bars}, default."""
    m = re.search(r"int QM_PP_RequiredBars\(.*?\)\s*\{(.*?)\n  \}", src, re.S)
    if not m:
        raise FixtureError("QM_PP_RequiredBars not found in header")
    body = m.group(1)
    mapping: dict[str, int] = {}
    pending: list[str] = []
    default = None
    for line in body.splitlines():
        line = line.strip()
        case = re.match(r"case\s+(QM_PP_[A-Z0-9_]+)\s*:\s*(?:return\s+(\d+)\s*;)?", line)
        if case:
            pending.append(case.group(1))
            if case.group(2):
                for name in pending:
                    mapping[name] = int(case.group(2))
                pending = []
            continue
        dflt = re.match(r"default\s*:\s*return\s+(\d+)\s*;", line)
        if dflt:
            default = int(dflt.group(1))
    if default is None:
        raise FixtureError("QM_PP_RequiredBars has no default branch")
    return mapping, default


def _validate_bar(bar, where: str) -> tuple[float, float, float, float, int]:
    if not isinstance(bar, (list, tuple)) or len(bar) != 5:
        raise FixtureError(f"{where}: bar must be [open, high, low, close, tick_volume]")
    try:
        o, h, low, c = (float(bar[0]), float(bar[1]), float(bar[2]), float(bar[3]))
        v = int(bar[4])
    except (TypeError, ValueError) as exc:
        raise FixtureError(f"{where}: non-numeric bar value ({exc})") from None
    # Physically impossible bars would make a fixture meaningless: the predicate
    # would be judged on a candle that no market can produce.
    if h < low:
        raise FixtureError(f"{where}: high {h} < low {low}")
    if h < max(o, c) - 1e-12:
        raise FixtureError(f"{where}: high {h} below body top {max(o, c)}")
    if low > min(o, c) + 1e-12:
        raise FixtureError(f"{where}: low {low} above body bottom {min(o, c)}")
    if v <= 0:
        raise FixtureError(f"{where}: tick_volume must be > 0 (QM_PP_LoadBars "
                           f"treats real bars as always having ticks)")
    return o, h, low, c, v


def expand_fixture(fx: dict, required: int, where: str,
                   group_filler: list | None = None) -> list[tuple]:
    bars = fx.get("bars")
    if not isinstance(bars, list) or not bars:
        raise FixtureError(f"{where}: 'bars' must be a non-empty list")
    rows = [_validate_bar(b, f"{where} bars[{i}]") for i, b in enumerate(bars)]

    # Most predicates read only the first few bars but the include still demands
    # a minimum window. A group-level default filler keeps 231 fixtures from
    # repeating the same padding; a fixture may override it when the padding
    # itself is part of what is being tested.
    filler = fx.get("filler_series") or group_filler
    if len(rows) < required:
        if not filler:
            raise FixtureError(
                f"{where}: predicate needs {required} bars, fixture supplies "
                f"{len(rows)} and declares no filler_series. A short window makes "
                f"QM_PP_Evaluate return false for the window length, not for the "
                f"pattern -- the test would pass for the wrong reason.")
        if not isinstance(filler, list) or not filler:
            raise FixtureError(f"{where}: filler_series must be a non-empty list")
        fill_rows = [_validate_bar(b, f"{where} filler_series[{i}]")
                     for i, b in enumerate(filler)]
        i = 0
        while len(rows) < required:
            rows.append(fill_rows[i % len(fill_rows)])
            i += 1
    if len(rows) > MAX_LOOKBACK:
        raise FixtureError(f"{where}: {len(rows)} bars exceeds QM_PP_MAX_LOOKBACK "
                           f"({MAX_LOOKBACK})")
    return rows


def load_group(path: Path, ids: dict[str, int], req_map: dict[str, int],
               req_default: int) -> list[dict]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise FixtureError(f"{path.name}: invalid JSON ({exc})") from None
    group = data.get("group")
    if not group:
        raise FixtureError(f"{path.name}: missing 'group'")
    fixtures = data.get("fixtures")
    if not isinstance(fixtures, list) or not fixtures:
        raise FixtureError(f"{path.name}: 'fixtures' must be a non-empty list")
    group_filler = data.get("default_filler_series")
    if group_filler is not None and (not isinstance(group_filler, list) or not group_filler):
        raise FixtureError(f"{path.name}: default_filler_series must be a non-empty list")

    out: list[dict] = []
    for fx in fixtures:
        fid = fx.get("id")
        if not fid:
            raise FixtureError(f"{path.name}: a fixture is missing 'id'")
        where = f"{path.name}:{fid}"

        pred = fx.get("predicate")
        if pred not in ids:
            raise FixtureError(f"{where}: unknown predicate {pred!r}")
        case = fx.get("case")
        if case not in VALID_CASES:
            raise FixtureError(f"{where}: case must be one of {sorted(VALID_CASES)}")
        if not isinstance(fx.get("expected"), bool):
            raise FixtureError(f"{where}: 'expected' must be a JSON boolean")
        basis = fx.get("basis")
        if basis not in VALID_BASES:
            raise FixtureError(f"{where}: basis must be one of {sorted(VALID_BASES)}")
        if basis == "implementation_threshold" and case != "boundary":
            raise FixtureError(
                f"{where}: basis 'implementation_threshold' is only permitted for "
                f"boundary cases. A positive or negative case written from the "
                f"source it tests proves nothing.")
        rationale = (fx.get("rationale") or "").strip()
        if len(rationale) < 20:
            raise FixtureError(f"{where}: 'rationale' must explain why this window "
                               f"does or does not exhibit the pattern (>= 20 chars)")

        anchor = fx.get("anchor_date", DEFAULT_ANCHOR)
        try:
            anchor_date = dt.date.fromisoformat(anchor)
        except (TypeError, ValueError):
            raise FixtureError(f"{where}: anchor_date must be YYYY-MM-DD") from None

        required = req_map.get(pred, req_default)
        rows = expand_fixture(fx, required, where, group_filler)
        out.append({
            "group": group, "id": fid, "predicate": pred,
            "predicate_id": ids[pred], "case": case,
            "expected": fx["expected"], "basis": basis,
            "rationale": rationale, "anchor": anchor_date,
            "required": required, "rows": rows,
        })
    return out


def collect(emit: bool) -> int:
    src = HEADER.read_text(encoding="utf-8")
    code = _strip_comments(src)
    ids = parse_predicate_ids(code)
    req_map, req_default = parse_required_bars(code)

    files = sorted(p for p in FIXTURE_DIR.glob("*.json"))
    if not files:
        print(f"no fixture files under {FIXTURE_DIR}", file=sys.stderr)
        return 1

    all_fx: list[dict] = []
    seen: dict[str, str] = {}
    errors: list[str] = []
    for path in files:
        try:
            group = load_group(path, ids, req_map, req_default)
        except FixtureError as exc:
            errors.append(str(exc))
            continue
        for fx in group:
            if fx["id"] in seen:
                errors.append(f"duplicate fixture id {fx['id']!r} "
                              f"({seen[fx['id']]} and {path.name})")
                continue
            seen[fx["id"]] = path.name
            all_fx.append(fx)

    if errors:
        for e in errors:
            print(f"FIXTURE_ERROR: {e}", file=sys.stderr)
        return 1

    by_pred: dict[str, set[str]] = {}
    for fx in all_fx:
        by_pred.setdefault(fx["predicate"], set()).add(fx["case"])

    print(f"predicates in header: {len(ids)}")
    print(f"fixtures loaded:      {len(all_fx)} from {len(files)} group file(s)")
    print(f"predicates covered:   {len(by_pred)}")
    missing = sorted(set(ids) - set(by_pred))
    if missing:
        print(f"predicates with NO fixture ({len(missing)}): {missing}")
    incomplete = sorted(p for p, cs in by_pred.items() if cs != VALID_CASES)
    if incomplete:
        print(f"predicates missing a case class ({len(incomplete)}):")
        for p in incomplete:
            print(f"   {p}: has {sorted(by_pred[p])}, "
                  f"missing {sorted(VALID_CASES - by_pred[p])}")

    if emit:
        BUNDLE_CSV.parent.mkdir(parents=True, exist_ok=True)
        with BUNDLE_CSV.open("w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh, lineterminator="\n")
            w.writerow(["fixture_id", "predicate", "predicate_id", "case",
                        "expected", "bar_index", "time_epoch",
                        "open", "high", "low", "close", "tick_volume"])
            for fx in sorted(all_fx, key=lambda f: f["id"]):
                for i, (o, h, low, c, v) in enumerate(fx["rows"]):
                    bar_date = fx["anchor"] - dt.timedelta(days=i)
                    epoch = int(dt.datetime.combine(
                        bar_date, dt.time(), tzinfo=dt.timezone.utc).timestamp())
                    w.writerow([fx["id"], fx["predicate"], fx["predicate_id"],
                                fx["case"], "1" if fx["expected"] else "0",
                                i, epoch,
                                repr(o), repr(h), repr(low), repr(c), v])
        print(f"wrote {BUNDLE_CSV}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--emit", action="store_true",
                    help="write the flat CSV bundle for the MQL5 runner")
    args = ap.parse_args()
    try:
        return collect(args.emit)
    except FixtureError as exc:
        print(f"FIXTURE_ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
