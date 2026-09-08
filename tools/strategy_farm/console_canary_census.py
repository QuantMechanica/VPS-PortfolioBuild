"""Read-only integrity/geometry census of a pinned live_canary_observation.

Usage: python -m tools.strategy_farm.console_canary_census canary_<id>.objects.csv
PASS is limited to these supplied files and measured presentation geometry.
It is not synthetic QA, a native selftest, trading authorization or a strategy
approval. No file is written and no MT5, GUI or trading library is imported.
"""
from __future__ import annotations

import argparse
import csv
from dataclasses import asdict
from datetime import datetime
import hashlib
from itertools import combinations
import json
import math
from pathlib import Path
import re
import struct
from typing import Any
import zlib

from tools.strategy_farm.console_census import Box, bounding_box, _read_csv


ACCOUNT = '1514536732'
CHART = '40880270757609'
HWND = '182059870'
EXPERT = 'QM5_11421_ohlc-daily-squeeze-reversal-d1'
PREFIX = 'QM_SIG_11421_114210000_'
OVERLAY = 'QM_CHART_V2_' + PREFIX
RETRY = 'QM_RETRY_' + PREFIX
# Exact text emitted by the two renderers for this pinned EA's version="5.0".
# V1 includes the version; V2 keeps it in a tooltip. Never accept a substring
# or an arbitrary version suffix as equivalent live presentation evidence.
FOOTERS = {'01': '© QuantMechanica  v5.0', '02': '© QuantMechanica'}
PIXEL_TYPES = {'OBJ_LABEL': 102, 'OBJ_BUTTON': 103, 'OBJ_RECTANGLE_LABEL': 110}
TIME_PRICE_TYPES = frozenset({'OBJ_HLINE', 'OBJ_TREND', 'OBJ_RECTANGLE', 'OBJ_ARROW',
                              'OBJ_ARROW_BUY', 'OBJ_ARROW_SELL'})
ANCHORS = dict(zip(('ANCHOR_LEFT_UPPER', 'ANCHOR_LEFT', 'ANCHOR_LEFT_LOWER', 'ANCHOR_LOWER',
                    'ANCHOR_RIGHT_LOWER', 'ANCHOR_RIGHT', 'ANCHOR_RIGHT_UPPER', 'ANCHOR_UPPER', 'ANCHOR_CENTER'), range(9)))
CORNERS = dict(zip(('CORNER_LEFT_UPPER', 'CORNER_LEFT_LOWER', 'CORNER_RIGHT_LOWER', 'CORNER_RIGHT_UPPER'), range(4)))
CHART_PROPERTIES = frozenset({
    'CHART_COLOR_BACKGROUND', 'CHART_COLOR_FOREGROUND', 'CHART_COLOR_GRID', 'CHART_COLOR_CHART_UP',
    'CHART_COLOR_CHART_DOWN', 'CHART_COLOR_CANDLE_BULL', 'CHART_COLOR_CANDLE_BEAR', 'CHART_COLOR_CHART_LINE',
    'CHART_COLOR_VOLUME', 'CHART_COLOR_BID', 'CHART_COLOR_ASK', 'CHART_COLOR_LAST', 'CHART_MODE',
    'CHART_FOREGROUND', 'CHART_SHOW_GRID', 'CHART_SHOW_VOLUMES', 'CHART_SHOW_BID_LINE', 'CHART_SHOW_ASK_LINE',
    'CHART_SHOW_LAST_LINE', 'CHART_SHIFT', 'CHART_SCALE', 'CHART_AUTOSCROLL', 'CHART_SHOW_TRADE_LEVELS',
    'CHART_DRAG_TRADE_LEVELS', 'CHART_SHOW_TRADE_HISTORY', 'CHART_FIRST_VISIBLE_BAR', 'CHART_WIDTH_IN_BARS',
    'CHART_SHIFT_SIZE',
})
BBOX_FIELDS = ('bbox_left', 'bbox_top', 'bbox_right', 'bbox_bottom')
OBJECT_COLUMNS = frozenset({'audit_id', 'chart_id', 'name', 'type', 'type_name', 'scope', 'subwindow',
                            'x', 'y', 'width', 'height', 'anchor', 'anchor_name', 'corner', 'corner_name',
                            'angle', 'bbox_available', *BBOX_FIELDS, 'text', 'tooltip', 'read_complete'})
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


class EvidenceError(ValueError):
    def __init__(self, code: str, detail: str, *, retryable: bool = False):
        super().__init__(detail)
        self.code, self.retryable = code, retryable


def _int(row: dict[str, str], key: str) -> int:
    value = row.get(key, '')
    if not re.fullmatch(r'-?\d+', value):
        raise ValueError(f'{key}: missing or invalid integer')
    return int(value)


def _float(row: dict[str, str], key: str) -> float:
    value = float(row.get(key, ''))
    if not math.isfinite(value):
        raise ValueError(f'{key}: non-finite number')
    return value


def _stamp(path: Path) -> tuple[int, int, int, int, int]:
    stat = path.stat()
    return stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns


def _bytes(path: Path, limit: int) -> bytes:
    with path.open('rb') as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise ValueError(f'File exceeds bounded reader size: {path.name}')
    return data


def _stable_read(path: Path, *, png: bool = False) -> tuple[Any, str, tuple[int, int, int, int, int]]:
    limit = (64 if png else 20) * 1024 * 1024
    before = _stamp(path)
    data = _bytes(path, limit)
    parsed = data if png else _read_csv(path)
    if before != _stamp(path) or data != _bytes(path, limit):
        raise EvidenceError('files_changed', f'{path.name} changed while being read; retry after capture completes', retryable=True)
    return parsed, hashlib.sha256(data).hexdigest(), before


def _png_dimensions(data: bytes) -> tuple[int, int]:
    """Verify framing/CRC/IHDR, not decompress or assess image pixels."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError('Invalid PNG signature')
    offset, dimensions, image_bytes, idat_ended = 8, None, 0, False
    palette = False
    color = -1
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError('Incomplete PNG chunk')
        size, kind = struct.unpack('>I4s', data[offset:offset + 8])
        end = offset + size + 12
        if end > len(data) or not all(65 <= c <= 90 or 97 <= c <= 122 for c in kind):
            raise ValueError('Invalid PNG chunk framing')
        payload = data[offset + 8:end - 4]
        if zlib.crc32(kind + payload) & 0xffffffff != struct.unpack('>I', data[end - 4:end])[0]:
            raise ValueError('PNG chunk CRC mismatch')
        if dimensions is None and kind != b'IHDR':
            raise ValueError('IHDR must be first')
        if kind == b'IHDR':
            if dimensions is not None or size != 13:
                raise ValueError('Invalid or duplicate IHDR')
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            depths = {0: {1, 2, 4, 8, 16}, 2: {8, 16}, 3: {1, 2, 4, 8}, 4: {8, 16}, 6: {8, 16}}
            if (not 0 < width < 2**31 or not 0 < height < 2**31 or depth not in depths.get(color, set())
                    or compression or filtering or interlace not in (0, 1)):
                raise ValueError('Invalid IHDR format')
            dimensions = width, height
        elif kind == b'PLTE':
            if palette or image_bytes or not 0 < size <= 768 or size % 3:
                raise ValueError('Invalid palette')
            palette = True
        elif kind == b'IDAT':
            if idat_ended or (color == 3 and not palette):
                raise ValueError('Invalid image data ordering')
            image_bytes += size
        elif kind == b'IEND':
            if size or not image_bytes or end != len(data):
                raise ValueError('Missing IDAT, invalid IEND or trailing bytes')
            return dimensions
        elif kind[0] & 32 == 0:
            raise ValueError('Unsupported critical PNG chunk')
        if image_bytes and kind != b'IDAT':
            idat_ended = True
        offset = end
    raise ValueError('PNG is missing IEND')


def _metadata(meta: dict[str, str], audit_id: str, count: int) -> tuple[int, int, int, int]:
    expected = {'schema_version': '1', 'artifact_kind': 'live_canary_observation', 'audit_id': audit_id,
                'account_login': ACCOUNT, 'server': 'FTMO-Demo', 'account_mode': 'DEMO', 'chart_id': CHART,
                'hwnd': HWND, 'symbol': 'EURUSD', 'timeframe': 'D1', 'expert': EXPERT,
                'prefix': PREFIX, 'overlay_prefix': OVERLAY, 'objects_complete': '1', 'properties_complete': '1',
                'binding_stable': '1', 'capture_non_atomic': '1', 'screenshot_calibrated': '1',
                'screenshot_ok': '1', 'observation_complete': '1'}
    wrong = [key for key, value in expected.items() if meta.get(key) != value]
    if wrong:
        raise ValueError('Missing/mismatched live observation fields: ' + ', '.join(wrong))
    if meta.get('design') not in {'01', '02'} or meta.get('view') not in {'Full', 'Compact', 'Minimal'}:
        raise ValueError('Unobserved or invalid native Design/View values')
    width, height = _int(meta, 'plot_width'), _int(meta, 'plot_height')
    sw, sh = _int(meta, 'screenshot_width'), _int(meta, 'screenshot_height')
    if (min(width, height, _int(meta, 'dpi')) <= 0 or not width <= sw <= width + 512
            or not height <= sh <= height + 512 or _int(meta, 'object_count') != count):
        raise ValueError('Invalid plot/calibration dimensions or object count')
    started = datetime.strptime(meta['started_utc'], '%Y.%m.%d %H:%M:%S UTC')
    finished = datetime.strptime(meta['finished_utc'], '%Y.%m.%d %H:%M:%S UTC')
    if finished < started:
        raise ValueError('Observation timestamps run backwards')
    return width, height, sw, sh


def _properties(rows: list[dict[str, str]], audit_id: str) -> dict[str, int | float]:
    if len(rows) != 28 or {row.get('property') for row in rows} != CHART_PROPERTIES:
        raise ValueError('Exactly the 28 native chart properties are required, without duplicates')
    result: dict[str, int | float] = {}
    for row in rows:
        if row.get('audit_id') != audit_id or row.get('chart_id') != CHART or row.get('read_complete') != '1':
            raise ValueError('Chart property row has wrong observation binding or failed native read')
        key = row['property']
        value = _float(row, 'value') if key == 'CHART_SHIFT_SIZE' else _int(row, 'value')
        if key.startswith('CHART_COLOR_'):
            valid = 0 <= value <= 0xffffff
        elif key in {'CHART_MODE', 'CHART_SHOW_VOLUMES'}:
            valid = value in {0, 1, 2}
        elif key == 'CHART_SCALE':
            valid = 0 <= value <= 5
        elif key == 'CHART_SHIFT_SIZE':
            valid = 0 <= value <= 50
        elif key == 'CHART_FIRST_VISIBLE_BAR':
            valid = value >= 0
        elif key == 'CHART_WIDTH_IN_BARS':
            valid = value > 0
        else:
            valid = value in {0, 1}
        if not valid:
            raise ValueError(f'Invalid native property value: {key}={value}')
        result[key] = value
    return result


def _geometry(rows: list[dict[str, str]], meta: dict[str, str], result: dict[str, Any]) -> None:
    width, height = int(meta['plot_width']), int(meta['plot_height'])
    chart, tolerance = Box(0, 0, width, height), 1.0
    seen: set[str] = set()
    measured: dict[str, tuple[dict[str, str], Box, str]] = {}

    def issue(code: str, name: str, detail: str) -> None:
        result['issues'].append({'code': code, 'objects': [name], 'detail': detail, 'retryable': False})

    for row in rows:
        name = row.get('name', '')
        if not name or len(name) > 63 or name in seen or not name.startswith((PREFIX, OVERLAY, RETRY)):
            issue('object_identity', name, 'Duplicate, overlong or foreign object name')
            continue
        seen.add(name)
        scope = 'overlay' if name.startswith(OVERLAY) else 'recovery' if name.startswith(RETRY) else 'dashboard'
        if scope == 'recovery':
            issue('unexpected_recovery', name, 'Canary is exposing a display-recovery control, not a ready dashboard')
        if ((meta['design'] == '01' and scope == 'overlay') or
                (meta['design'] == '02' and name.startswith((PREFIX + 'range_', PREFIX + 'trade_')))):
            issue('mixed_design_objects', name, 'Overlay objects belong to the other dashboard design')
        try:
            if not OBJECT_COLUMNS <= row.keys():
                raise ValueError('Native object observation columns are incomplete')
            if (row.get('audit_id') != meta['audit_id'] or row.get('chart_id') != CHART
                    or row.get('scope') != scope or row.get('read_complete') != '1'):
                raise ValueError('Row/audit/chart/scope binding or native read_complete mismatch')
            kind = row.get('type_name', '')
            if _int(row, 'type') < 0:
                raise ValueError('Invalid native object type number')
            if kind in TIME_PRICE_TYPES:
                if row.get('bbox_available') != '0' or any(row.get(key) for key in BBOX_FIELDS):
                    raise ValueError('Time/price overlay must not claim a measured pixel box')
                result['time_price_overlays'].append({'name': name, 'type_name': kind, 'geometry_checked': False})
                continue
            if kind not in PIXEL_TYPES or _int(row, 'type') != PIXEL_TYPES[kind]:
                raise ValueError('Unsupported/mismatched native pixel object type')
            if (row.get('bbox_available') != '1' or ANCHORS.get(row.get('anchor_name')) != _int(row, 'anchor')
                    or CORNERS.get(row.get('corner_name')) != _int(row, 'corner')):
                raise ValueError('Missing native pixel bbox or inconsistent enum names/numbers')
            box = bounding_box(row, width, height)
            for key, value in zip(BBOX_FIELDS, (box.left, box.top, box.right, box.bottom)):
                if abs(_float(row, key) - value) > 0.011:
                    raise ValueError('Exported native bbox differs from anchor/corner reconstruction')
            role = 'overlay' if scope == 'overlay' or name.startswith((PREFIX + 'range_', PREFIX + 'trade_')) else 'panel'
            measured[name] = row, box, role
            result['boxes'].append({'name': name, 'type_name': kind, 'scope': scope, **asdict(box)})
            if not chart.contains(box, tolerance):
                issue('outside_chart', name, 'Measured pixel object exceeds plot boundaries')
        except (KeyError, TypeError, ValueError) as error:
            issue('invalid_object', name, str(error))
    panel = measured.get(PREFIX + 'bg')
    if panel is None or panel[0]['type_name'] != 'OBJ_RECTANGLE_LABEL':
        issue('missing_panel', PREFIX + 'bg', 'Measured native panel rectangle required')
    else:
        for name, (_, box, role) in measured.items():
            if role == 'panel' and not panel[1].contains(box, tolerance):
                issue('outside_panel', name, 'Measured dashboard object exceeds its panel bounds')
    required = {'footer': ('OBJ_LABEL', FOOTERS[meta['design']]),
                'design_version': ('OBJ_BUTTON', meta['design']), 'view': ('OBJ_BUTTON', meta['view'])}
    for suffix in ('state_headline', 'state_reason', 'state_next'):
        required[suffix] = 'OBJ_LABEL', None
    for suffix, (kind, value) in required.items():
        observed = measured.get(PREFIX + suffix)
        if (observed is None or observed[0]['type_name'] != kind or not observed[0].get('text', '').strip()
                or (value is not None and observed[0]['text'] != value)):
            issue('missing_or_wrong_control', PREFIX + suffix, 'Required native state/footer/control text or type does not match')
    labels = [(name, box) for name, (row, box, _) in measured.items()
              if row['type_name'] == 'OBJ_LABEL' and row.get('text', '').strip()]
    for (first, a), (second, b) in combinations(labels, 2):
        if a.overlaps(b, tolerance):
            result['issues'].append({'code': 'text_overlap', 'objects': [first, second],
                                     'detail': 'Measured labels overlap beyond 1 physical pixel', 'retryable': False})
    result['counts'] = {'objects': len(rows), 'measured_pixel_objects': len(measured),
                        'measured_labels': len(labels), 'time_price_overlays': len(result['time_price_overlays'])}


def analyze_canary(objects_path: str | Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        'status': 'FAIL', 'scope': 'pinned live canary observation integrity and measured pixel geometry only',
        'trading_authorized': False, 'strategy_certified': False, 'native_selftests_verified': False,
        'tolerance_pixels': 1.0, 'issues': [], 'boxes': [], 'time_price_overlays': [],
        'limits': ['Live EA capture is non-atomic; concurrent value changes are not frozen.',
                   'Time/price overlay geometry is not checked.',
                   'PNG chunk framing/CRC/IHDR are checked; compressed pixels are not decoded or visually assessed.',
                   'Full-frame extent relies on the pinned native audit calibration metadata.',
                   'No synthetic QA, native selftest, strategy or trading approval is inferred.'],
    }
    try:
        path = Path(objects_path)
        match = re.fullmatch(r'canary_(' + CHART + r'_\d+)\.objects\.csv', path.name)
        if not match:
            raise EvidenceError('filename_binding', 'Expected canary_<pinned-chart>_<native-tick-id>.objects.csv')
        audit_id = match[1]
        stem = 'canary_' + audit_id
        files = {'objects': path, 'metadata': path.with_name(stem + '.meta.csv'),
                 'chart': path.with_name(stem + '.chart.csv'), 'png': path.with_name(stem + '.png')}
        initial = {name: _stamp(file) for name, file in files.items()}
        loaded = {name: _stable_read(file, png=name == 'png') for name, file in files.items()}
        rows, metadata_rows, properties_rows = (loaded[key][0] for key in ('objects', 'metadata', 'chart'))
        if len(metadata_rows) != 1:
            raise ValueError('Exactly one live observation metadata row is required')
        meta = metadata_rows[0]
        width, height, sw, sh = _metadata(meta, audit_id, len(rows))
        properties = _properties(properties_rows, audit_id)
        try:
            png_dimensions = _png_dimensions(loaded['png'][0])
        except ValueError as error:
            raise EvidenceError('png_invalid', str(error), retryable=True) from error
        if png_dimensions != (sw, sh):
            raise EvidenceError('png_dimensions', 'PNG extent differs from native calibrated full client dimensions', retryable=True)
        result.update(metadata=meta, chart_properties=properties, plot_dimensions=[width, height],
                      screenshot_dimensions=list(png_dimensions), capture_non_atomic=True)
        _geometry(rows, meta, result)
        for name, file in files.items():
            _, digest, stamp = loaded[name]
            limit = (64 if name == 'png' else 20) * 1024 * 1024
            if (initial[name] != stamp or _stamp(file) != stamp
                    or hashlib.sha256(_bytes(file, limit)).hexdigest() != digest):
                raise EvidenceError('files_changed', 'Bundle changed during validation; wait and retry', retryable=True)
        result['files'] = {name: {'path': str(file), 'sha256': loaded[name][1]} for name, file in files.items()}
        result['status'] = 'FAIL' if result['issues'] else 'PASS'
    except (OSError, UnicodeError, csv.Error, KeyError, TypeError, ValueError) as error:
        result['issues'].append({'code': error.code if isinstance(error, EvidenceError) else 'invalid_bundle',
                                 'objects': [], 'detail': str(error),
                                 'retryable': error.retryable if isinstance(error, EvidenceError) else isinstance(error, OSError)})
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('objects', type=Path)
    args = parser.parse_args(argv)
    result = analyze_canary(args.objects)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
