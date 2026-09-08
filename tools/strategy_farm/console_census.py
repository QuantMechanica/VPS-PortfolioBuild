"""Read-only analysis of native console QA CSV bundles (schema 2).

Usage: python -m tools.strategy_farm.console_census path/to/qa_12.csv
Exit 0 means measured pixel geometry and linked native selftest receipts pass;
it does not certify trading behavior, fonts, screenshot appearance or time/price
overlay placement. Non-pixel overlays are inventoried separately, never assigned
fake zero-sized UI boxes. No MT5, GUI or trading library is imported.

Anchor semantics: https://www.mql5.com/en/docs/constants/objectconstants/enum_anchorpoint
"""

from __future__ import annotations

import argparse
import csv
from dataclasses import asdict, dataclass
from itertools import combinations
import json
import math
from pathlib import Path
from typing import Any, Iterable, Mapping


PIXEL_TYPES = frozenset({'OBJ_LABEL', 'OBJ_BUTTON', 'OBJ_RECTANGLE_LABEL',
                         'OBJ_EDIT', 'OBJ_BITMAP_LABEL', 'OBJ_CHART'})
FIXED_ANCHORS = PIXEL_TYPES - {'OBJ_LABEL', 'OBJ_BITMAP_LABEL'}
ANCHORS = {
    'ANCHOR_LEFT_UPPER': (0.0, 0.0), 'ANCHOR_UPPER': (0.5, 0.0),
    'ANCHOR_RIGHT_UPPER': (1.0, 0.0), 'ANCHOR_LEFT': (0.0, 0.5),
    'ANCHOR_CENTER': (0.5, 0.5), 'ANCHOR_RIGHT': (1.0, 0.5),
    'ANCHOR_LEFT_LOWER': (0.0, 1.0), 'ANCHOR_LOWER': (0.5, 1.0),
    'ANCHOR_RIGHT_LOWER': (1.0, 1.0),
}
CORNERS = {
    'CORNER_LEFT_UPPER': (False, False), 'CORNER_RIGHT_UPPER': (True, False),
    'CORNER_LEFT_LOWER': (False, True), 'CORNER_RIGHT_LOWER': (True, True),
}
MODES = {0: 'QM_CONSOLE_FULL', 1: 'QM_CONSOLE_COMPACT', 2: 'QM_CONSOLE_MINIMAL'}
EXPECTED_SUITES = {'formatter': 1, 'model': 1, 'data': 11}


@dataclass(frozen=True)
class Box:
    left: float
    top: float
    right: float
    bottom: float

    def contains(self, other: Box, tolerance: float) -> bool:
        return (other.left >= self.left - tolerance and other.top >= self.top - tolerance
                and other.right <= self.right + tolerance and other.bottom <= self.bottom + tolerance)

    def overlaps(self, other: Box, tolerance: float) -> bool:
        return (min(self.right, other.right) - max(self.left, other.left) > tolerance
                and min(self.bottom, other.bottom) - max(self.top, other.top) > tolerance)


def _number(row: Mapping[str, str], key: str) -> float:
    try:
        value = float(row[key])
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError(f'{key}: missing or invalid number') from error
    if not math.isfinite(value):
        raise ValueError(f'{key}: non-finite number')
    return value


def _integer(row: Mapping[str, str], key: str) -> int:
    try:
        return int(row[key])
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError(f'{key}: missing or invalid integer') from error


def bounding_box(row: Mapping[str, str], chart_width: int, chart_height: int) -> Box:
    """Convert measured, unrotated native pixel-object properties to a box."""
    kind = row.get('type_name')
    if kind not in PIXEL_TYPES:
        raise ValueError('Not a pixel-positioned UI object')
    width, height = _number(row, 'width'), _number(row, 'height')
    if width <= 0 or height <= 0:
        raise ValueError('Native dimensions are not measured')
    if abs(math.remainder(_number(row, 'angle'), 360.0)) > 1e-8:
        raise ValueError('Rotated objects require a polygon analyzer')
    anchor = 'ANCHOR_LEFT_UPPER' if kind in FIXED_ANCHORS else row.get('anchor_name')
    if anchor not in ANCHORS or row.get('corner_name') not in CORNERS:
        raise ValueError('Unknown symbolic anchor or chart corner')
    if _integer(row, 'subwindow') != 0:
        raise ValueError('Subwindow geometry is not available in this schema')
    x, y = _number(row, 'x'), _number(row, 'y')
    from_right, from_bottom = CORNERS[row['corner_name']]
    ax, ay = chart_width - x if from_right else x, chart_height - y if from_bottom else y
    fx, fy = ANCHORS[anchor]
    left, top = ax - fx * width, ay - fy * height
    return Box(left, top, left + width, top + height)


def analyze_rows(objects: Iterable[Mapping[str, str]], metadata: Mapping[str, str],
                 *, tolerance: float = 1.0) -> dict[str, Any]:
    """Pure geometry analysis; callers separately verify bundle/receipt files."""
    rows = list(objects)
    result: dict[str, Any] = {
        'status': 'FAIL', 'scope': 'native pixel geometry; time/price overlays not geometrically checked',
        'metadata': dict(metadata), 'tolerance_pixels': tolerance, 'issues': [],
        'boxes': [], 'time_price_overlays': [], 'selftests_verified': False,
    }

    def issue(code: str, names: Iterable[str], detail: str) -> None:
        result['issues'].append({'code': code, 'objects': list(names), 'detail': detail})

    try:
        if not math.isfinite(tolerance) or not 0 <= tolerance <= 2:
            raise ValueError('Tolerance must be between 0 and 2 physical pixels')
        if _integer(metadata, 'schema_version') != 2:
            raise ValueError('Only schema_version=2 has unambiguous native geometry')
        width, height = _integer(metadata, 'chart_width'), _integer(metadata, 'chart_height')
        if width <= 0 or height <= 0 or _integer(metadata, 'dpi') <= 0:
            raise ValueError('Chart dimensions and DPI must be positive')
        serial = _integer(metadata, 'serial')
        if serial < 0 or _integer(metadata, 'chart_id') <= 0:
            raise ValueError('Invalid capture serial or chart ID')
        mode = _integer(metadata, 'mode')
        if mode not in MODES or metadata.get('mode_name') != MODES[mode]:
            raise ValueError('Invalid effective mode or symbolic mode name')
        if _integer(metadata, 'requested_mode') not in MODES:
            raise ValueError('Invalid requested mode')
        if not 0 <= _integer(metadata, 'scenario') <= 7 or not 80 <= _integer(metadata, 'scale') <= 150:
            raise ValueError('Scenario or scale outside the fixture contract')
        prefix = metadata.get('prefix', '')
        if prefix != 'QM_QA_' or metadata.get('panel_name') != prefix + 'bg':
            raise ValueError('Unexpected fixture namespace or panel identity')
        if metadata.get('design') not in {'V1', 'V2'}:
            raise ValueError('Missing or unsupported design identity')
        if metadata.get('capture_complete') != '1' or metadata.get('screenshot_ok') != '1':
            raise ValueError('Native capture or screenshot did not complete successfully')
        if _integer(metadata, 'object_count') != len(rows):
            raise ValueError('Object count does not match companion metadata')
    except (TypeError, ValueError) as error:
        issue('invalid_metadata', [], str(error))
        return result

    chart = Box(0, 0, width, height)
    measured: dict[str, tuple[Mapping[str, str], Box]] = {}
    names: set[str] = set()
    for row in rows:
        name = row.get('name', '')
        if not name.startswith((prefix, 'QM_CHART_V2_' + prefix)) or name in names:
            issue('invalid_object_identity', [name], 'Foreign namespace or duplicate object name')
            continue
        names.add(name)
        try:
            if _integer(row, 'serial') != serial:
                raise ValueError('Object row and metadata serial differ')
        except ValueError as error:
            issue('capture_mismatch', [name], str(error))
            continue
        kind = row.get('type_name', '')
        if kind not in PIXEL_TYPES:
            if row.get('scope') != 'time_price' or not kind.startswith('OBJ_'):
                issue('invalid_object_scope', [name], 'Non-pixel object must be an explicit time/price overlay')
            else:
                result['time_price_overlays'].append({'name': name, 'type_name': kind,
                                                      'geometry_checked': False})
            continue
        scope = 'overlay' if name.startswith((prefix + 'range_', prefix + 'trade_', 'QM_CHART_V2_' + prefix)) else 'panel'
        if row.get('scope') != scope:
            issue('invalid_object_scope', [name], f'Expected {scope} for this pixel object')
            continue
        try:
            box = bounding_box(row, width, height)
        except ValueError as error:
            code = 'label_not_measured' if kind == 'OBJ_LABEL' and 'not measured' in str(error) else 'invalid_geometry'
            issue(code, [name], str(error))
            continue
        measured[name] = (row, box)
        result['boxes'].append({'name': name, 'type_name': kind, 'scope': scope, **asdict(box)})
        if not chart.contains(box, tolerance):
            issue('outside_chart', [name], 'Measured pixel box exceeds chart bounds')

    panel_name = metadata['panel_name']
    panel = measured.get(panel_name)
    if panel is None or panel[0].get('type_name') != 'OBJ_RECTANGLE_LABEL':
        issue('panel_not_measured', [panel_name], 'A measured rectangle-label panel is required')
    else:
        for name, (row, box) in measured.items():
            if row['scope'] == 'panel' and name != panel_name and not panel[1].contains(box, tolerance):
                issue('outside_panel', [name, panel_name], 'Dashboard object exceeds its panel container')

    labels = [(name, box) for name, (row, box) in measured.items()
              if row.get('type_name') == 'OBJ_LABEL' and row.get('text', '').strip()]
    if not labels:
        issue('no_measured_text', [], 'An empty dashboard cannot establish readable native text geometry')
    for (first, a), (second, b) in combinations(labels, 2):
        if a.overlaps(b, tolerance):
            issue('text_overlap', [first, second], 'Measured label rectangles overlap beyond tolerance')
    result['counts'] = {'objects': len(rows), 'measured_pixel_objects': len(measured),
                        'measured_text_labels': len(labels), 'time_price_overlays': len(result['time_price_overlays'])}
    result['status'] = 'FAIL' if result['issues'] else 'PASS'
    return result


def _read_csv(path: Path) -> list[dict[str, str]]:
    if path.stat().st_size > 20 * 1024 * 1024:
        raise ValueError(f'Unexpectedly large census file: {path.name}')
    with path.open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.DictReader(stream, strict=True)
        if not reader.fieldnames or len(set(reader.fieldnames)) != len(reader.fieldnames):
            raise ValueError(f'Missing or duplicate CSV columns: {path.name}')
        rows = list(reader)
    if any(None in row or None in row.values() for row in rows):
        raise ValueError(f'Ragged CSV rows; native text may not have been escaped: {path.name}')
    return rows


def verify_selftests(metadata: Mapping[str, str], rows: Iterable[Mapping[str, str]]) -> None:
    receipts = list(rows)
    if len(receipts) != len(EXPECTED_SUITES) or {r.get('suite') for r in receipts} != set(EXPECTED_SUITES):
        raise ValueError('Native receipt must contain formatter, model and data suites exactly once')
    for row in receipts:
        if row.get('init_run_id') != metadata.get('init_run_id') or row.get('chart_id') != metadata.get('chart_id'):
            raise ValueError('Native receipt belongs to another initialization or chart')
        expected = EXPECTED_SUITES[row['suite']]
        if (row.get('status') != 'PASS' or _integer(row, 'expected_cases') != expected
                or _integer(row, 'passed_cases') != expected):
            raise ValueError(f'Native suite {row["suite"]} did not prove {expected} passing cases')


def analyze_census(objects_path: str | Path, metadata_path: str | Path | None = None,
                   *, tolerance: float = 1.0, verify_receipts: bool = True) -> dict[str, Any]:
    """Read only the named census, companion metadata and linked init receipt."""
    objects_path = Path(objects_path)
    metadata_path = Path(metadata_path) if metadata_path else objects_path.with_suffix('.meta.csv')
    try:
        companion = _read_csv(metadata_path)
        if len(companion) != 1:
            raise ValueError('Exactly one capture-metadata row is required')
        metadata = companion[0]
        result = analyze_rows(_read_csv(objects_path), metadata, tolerance=tolerance)
        if objects_path.name != f'qa_{_integer(metadata, "serial")}.csv':
            raise ValueError('Census filename does not match native capture serial')
        if verify_receipts:
            receipt = metadata.get('selftest_receipt', '')
            token = metadata.get('init_run_id', '')
            if (not token or '/' in receipt or '\\' in receipt
                    or receipt != f'selftests_{token}.csv'):
                raise ValueError('Unsafe or mismatched native receipt filename')
            verify_selftests(metadata, _read_csv(metadata_path.parent / receipt))
            result['selftests_verified'] = True
        return result
    except (OSError, UnicodeError, csv.Error, ValueError) as error:
        return {'status': 'FAIL', 'selftests_verified': False,
                'issues': [{'code': 'invalid_bundle', 'objects': [], 'detail': str(error)}]}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('objects', type=Path)
    parser.add_argument('--metadata', type=Path)
    parser.add_argument('--tolerance', type=float, default=1.0)
    parser.add_argument('--geometry-only', action='store_true', help='Explicitly skip linked native selftest verification')
    args = parser.parse_args(argv)
    result = analyze_census(args.objects, args.metadata, tolerance=args.tolerance,
                            verify_receipts=not args.geometry_only)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
