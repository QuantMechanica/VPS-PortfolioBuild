"""Read-only acceptance of three native QA bundles in V2 -> V1 -> V2 order.

Usage: python -m tools.strategy_farm.console_ab_acceptance qa_501.csv qa_502.csv qa_503.csv
No GUI/terminal/trading library is imported, no capture is triggered, and no
file is written. PASS covers the supplied presentation evidence only: it is
not a strategy certification, trading authorization or proof of trade absence.
Full-frame screenshot proof requires screenshot_calibrated=1 and explicit
screenshot_width/height. Plot dimensions remain the geometry/census boundary;
old plot-sized PNGs are not silently promoted to full-frame visual evidence.
Final release evidence also requires native failed-target-start rollback,
render-failure recovery and initial-start explicit-retry receipts from the same
chart initialization. The permanently invalid-prefix initial-start fixture
does not prove transient capture-failure recovery or recovery from every
possible chart-property restoration failure.

PNG structure: https://www.w3.org/TR/png-3/ (IHDR, IDAT, IEND and chunk CRC).
Compressed image pixels are not decoded or assessed for visual attractiveness.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import struct
from typing import Any
import zlib

from tools.strategy_farm.console_census import _read_csv, analyze_census, verify_selftests


CHART_PROPERTIES = frozenset({
    'CHART_COLOR_BACKGROUND', 'CHART_COLOR_FOREGROUND', 'CHART_COLOR_GRID',
    'CHART_COLOR_CHART_UP', 'CHART_COLOR_CHART_DOWN', 'CHART_COLOR_CANDLE_BULL',
    'CHART_COLOR_CANDLE_BEAR', 'CHART_COLOR_CHART_LINE', 'CHART_COLOR_VOLUME',
    'CHART_COLOR_BID', 'CHART_COLOR_ASK', 'CHART_COLOR_LAST', 'CHART_MODE',
    'CHART_FOREGROUND', 'CHART_SHOW_GRID', 'CHART_SHOW_VOLUMES',
    'CHART_SHOW_BID_LINE', 'CHART_SHOW_ASK_LINE', 'CHART_SHOW_LAST_LINE',
    'CHART_SHIFT', 'CHART_SCALE', 'CHART_AUTOSCROLL', 'CHART_SHOW_TRADE_LEVELS',
    'CHART_DRAG_TRADE_LEVELS', 'CHART_SHOW_TRADE_HISTORY', 'CHART_SHIFT_SIZE',
})
UNTOUCHED_PROPERTIES = frozenset({'CHART_SCALE', 'CHART_AUTOSCROLL', 'CHART_SHOW_TRADE_LEVELS',
                                 'CHART_DRAG_TRADE_LEVELS', 'CHART_SHOW_TRADE_HISTORY'})
IDENTICAL_METADATA = (
    'chart_id', 'init_run_id', 'scenario', 'mode', 'mode_name', 'requested_mode',
    'scale', 'chart_width', 'chart_height', 'dpi', 'fixture_bar', 'prefix', 'panel_name',
    'expert_name', 'qa_trade_allowed', 'terminal_trade_allowed', 'cached_bid', 'quote_observed_at',
    'screenshot_calibrated', 'screenshot_width', 'screenshot_height',
)
SCREENSHOT_METADATA = ('screenshot_calibrated', 'screenshot_width', 'screenshot_height')
OVERLAY_PREFIX = 'QM_CHART_V2_QM_QA_'
SHIFT_TOLERANCE = 1e-6
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


class EvidenceError(ValueError):
    def __init__(self, code: str, detail: str, *, retryable: bool = False):
        super().__init__(detail)
        self.code = code
        self.retryable = retryable


def png_dimensions(data: bytes) -> tuple[int, int]:
    """Check complete chunk framing/CRC and return IHDR dimensions, not pixels."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError('Missing or malformed PNG signature')
    offset, dimensions, image_bytes = 8, None, 0
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError('PNG chunk is not completely written')
        length, kind = struct.unpack('>I4s', data[offset:offset + 8])
        if not all(65 <= char <= 90 or 97 <= char <= 122 for char in kind):
            raise ValueError('Invalid PNG chunk name')
        end = offset + 12 + length
        if end > len(data):
            raise ValueError('PNG chunk payload is not completely written')
        payload = data[offset + 8:end - 4]
        crc = struct.unpack('>I', data[end - 4:end])[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError(f'PNG {kind!r} checksum mismatch')
        if dimensions is None and kind != b'IHDR':
            raise ValueError('PNG must begin with IHDR')
        if kind == b'IHDR':
            if dimensions is not None or length != 13:
                raise ValueError('Invalid or duplicate PNG IHDR')
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            depths = {0: {1, 2, 4, 8, 16}, 2: {8, 16}, 3: {1, 2, 4, 8}, 4: {8, 16}, 6: {8, 16}}
            if (not 0 < width < 2**31 or not 0 < height < 2**31 or depth not in depths.get(color, set())
                    or compression != 0 or filtering != 0 or interlace not in (0, 1)):
                raise ValueError('Invalid PNG dimensions or IHDR format')
            dimensions = (width, height)
        elif kind == b'IDAT':
            image_bytes += length
        elif kind == b'IEND':
            if length or not image_bytes or end != len(data):
                raise ValueError('PNG has invalid IEND, missing IDAT or trailing bytes')
            return dimensions
        offset = end
    raise ValueError('PNG IEND is missing; capture may still be writing')


def _stamp(path: Path) -> tuple[int, int]:
    stat = path.stat()
    return stat.st_size, stat.st_mtime_ns


def _calibrated_dimensions(meta: dict[str, str]) -> tuple[int, int]:
    missing = [field for field in SCREENSHOT_METADATA if field not in meta]
    if missing:
        raise EvidenceError('missing_screenshot_calibration',
                            'Full-frame PNG proof requires native client calibration; missing: '
                            + ', '.join(missing) + '. Recapture with calibration. Existing geometry/lifecycle evidence is separate.')
    if meta['screenshot_calibrated'] != '1':
        raise EvidenceError('uncalibrated_screenshot',
                            'Full-frame PNG proof requires screenshot_calibrated=1; plot-size fallback may clip axes/footer. Recapture after native client calibration.')
    try:
        width, height = int(meta['screenshot_width']), int(meta['screenshot_height'])
        plot_width, plot_height = int(meta['chart_width']), int(meta['chart_height'])
    except (KeyError, TypeError, ValueError) as error:
        raise EvidenceError('invalid_screenshot_calibration', 'Calibrated client and plot dimensions must be explicit integers') from error
    if not (0 < plot_width <= width < 2**31 and 0 < plot_height <= height < 2**31):
        raise EvidenceError('invalid_screenshot_calibration',
                            'Calibrated client dimensions must be positive and contain the complete plot area')
    return width, height


def _native_receipt(rows: list[dict[str, str]], meta: dict[str, str], expected: set[str]) -> None:
    if len(rows) != len(expected) or {row.get('suite') for row in rows} != expected:
        raise EvidenceError('invalid_native_receipt', f'Expected exactly these native suites: {sorted(expected)}')
    for row in rows:
        if row.get('init_run_id') != meta['init_run_id'] or row.get('chart_id') != meta['chart_id']:
            raise EvidenceError('receipt_binding_mismatch', 'Native receipt belongs to another initialization or chart')
        if row.get('status') != 'PASS':
            raise EvidenceError('native_selftest_failed', f'Native suite {row.get("suite")} is not PASS')
        if row['suite'] == 'news_observation' and row.get('expected_cases') != '24':
            raise EvidenceError('invalid_news_count', 'Native news receipt must prove the 24-case suite')


def _chart_properties(rows: list[dict[str, str]], meta: dict[str, str]) -> dict[str, int | float]:
    names = [row.get('property') for row in rows]
    if len(names) != len(CHART_PROPERTIES) or set(names) != CHART_PROPERTIES:
        raise EvidenceError('incomplete_chart_properties', 'All 26 unique native chart properties are required')
    values: dict[str, int | float] = {}
    for row in rows:
        if row.get('serial') != meta['serial'] or row.get('chart_id') != meta['chart_id']:
            raise EvidenceError('chart_receipt_binding_mismatch', 'Chart-property row does not match its capture')
        name = row['property']
        try:
            value = float(row['value']) if name == 'CHART_SHIFT_SIZE' else int(row['value'])
        except (KeyError, TypeError, ValueError) as error:
            raise EvidenceError('invalid_chart_property', f'Invalid numeric property {name}') from error
        if (isinstance(value, int) and not -2**63 <= value < 2**63) or (isinstance(value, float) and not math.isfinite(value)):
            raise EvidenceError('invalid_chart_property', f'Non-finite native property {name}')
        values[name] = value
    return values


def _load_capture(path: Path) -> dict[str, Any]:
    try:
        initial_objects = _stamp(path)
        initial_metadata = _stamp(path.with_suffix('.meta.csv'))
    except OSError as error:
        raise EvidenceError('missing_or_unreadable_proof', f'{error}; wait for native capture completion and retry', retryable=True) from error
    census = analyze_census(path)
    if census['status'] != 'PASS' or not census.get('selftests_verified'):
        raise EvidenceError('census_failed', json.dumps(census.get('issues', []), ensure_ascii=False))
    meta = census['metadata']
    expected_screenshot = _calibrated_dimensions(meta)
    missing = [field for field in IDENTICAL_METADATA if field not in meta]
    if missing:
        raise EvidenceError('missing_ab_metadata', 'New native A/B capture required; missing: ' + ', '.join(missing))
    if meta['expert_name'] != 'QM_Console_Visual_QA' or meta['qa_trade_allowed'] != '0':
        raise EvidenceError('unsafe_qa_binding', 'Expected QM_Console_Visual_QA with per-EA trading permission OFF')
    if meta['terminal_trade_allowed'] not in {'0', '1'}:
        raise EvidenceError('invalid_terminal_permission', 'Terminal trading permission must be explicitly recorded as 0 or 1')
    token = meta['init_run_id']
    if not re.fullmatch(r'\d+(?:_\d+)+', token):
        raise EvidenceError('invalid_init_token', 'Native init token is missing, malformed or unsafe as a filename')
    files = {
        'objects': path, 'metadata': path.with_suffix('.meta.csv'),
        'chart': path.with_suffix('.chart.csv'), 'png': path.with_suffix('.png'),
        'data': path.parent / f'selftests_{token}.csv',
        'news': path.parent / f'news_selftests_{token}.csv',
        'chart_selftests': path.parent / f'chart_selftests_{token}.csv',
        'compare_selftests': path.parent / f'compare_selftests_{token}.csv',
    }
    try:
        stamps = {name: _stamp(file) for name, file in files.items()}
        if stamps['objects'] != initial_objects or stamps['metadata'] != initial_metadata:
            raise EvidenceError('capture_changed_while_reading', 'Census or metadata changed during validation; wait and retry', retryable=True)
        rows = _read_csv(files['objects'])
        properties = _chart_properties(_read_csv(files['chart']), meta)
        # Recheck the linked data proof inside this same file-stability window.
        verify_selftests(meta, _read_csv(files['data']))
        _native_receipt(_read_csv(files['news']), meta, {'news_observation'})
        _native_receipt(_read_csv(files['chart_selftests']), meta,
                        {'chart_geometry', 'chart_property_roundtrip', 'chart_zoom_roundtrip'})
        _native_receipt(_read_csv(files['compare_selftests']), meta,
                        {'compare_start_failure_rollback', 'compare_render_failure_recovery',
                         'initial_start_failure_retry'})
        if stamps['png'][0] > 64 * 1024 * 1024:
            raise EvidenceError('png_invalid', 'Screenshot exceeds bounded 64 MiB reader limit')
        png = files['png'].read_bytes()
        try:
            dimensions = png_dimensions(png)
        except ValueError as error:
            raise EvidenceError('png_incomplete_or_invalid', f'{error}; wait for native capture completion and retry', retryable=True) from error
        if dimensions != expected_screenshot:
            raise EvidenceError('png_dimensions_mismatch',
                                f'PNG is {dimensions}, calibrated native client is {expected_screenshot}; recapture after viewport settles', retryable=True)
        if any(_stamp(file) != stamps[name] for name, file in files.items()):
            raise EvidenceError('capture_changed_while_reading', 'A capture file changed during validation; wait and retry', retryable=True)
    except OSError as error:
        raise EvidenceError('missing_or_unreadable_proof', f'{error}; wait for native capture completion and retry', retryable=True) from error
    except (ValueError, csv.Error) as error:
        if isinstance(error, EvidenceError):
            raise
        raise EvidenceError('malformed_native_proof', str(error), retryable=True) from error
    identities = {row['name']: (row['type_name'], row['type']) for row in rows}
    return {'metadata': meta, 'properties': properties, 'identities': identities,
            'summary': {'path': str(path), 'serial': meta['serial'], 'design': meta['design'],
                        'census_status': census['status'], 'objects': len(rows),
                        'plot_dimensions': (int(meta['chart_width']), int(meta['chart_height'])),
                        'screenshot_calibrated': True,
                        'png_dimensions': dimensions, 'png_sha256': hashlib.sha256(png).hexdigest(),
                        'native_suites': ['formatter:1', 'model:1', 'data:11', 'news:24',
                                          'chart_geometry:PASS', 'chart_property_roundtrip:PASS', 'chart_zoom_roundtrip:PASS',
                                          'compare_start_failure_rollback:PASS',
                                          'compare_render_failure_recovery:PASS',
                                          'initial_start_failure_retry:PASS']}}


def accept_ab(first: str | Path, middle: str | Path, last: str | Path) -> dict[str, Any]:
    """Verify named V2/V1/V2 bundles without creating or modifying evidence."""
    paths = [Path(first), Path(middle), Path(last)]
    result: dict[str, Any] = {
        'status': 'FAIL', 'scope': 'supplied calibrated full-frame native presentation A/B evidence only',
        'trading_strategy_certified': False, 'issues': [], 'captures': [],
        'limits': ['No trading authorization or proof of trade absence.',
                   'Only objects recorded in the allowlisted census are inventoried.',
                   'PNG framing, CRC and dimensions are checked; image pixels are not decoded.',
                   'Full-frame extent relies on native guard-validated client calibration metadata.',
                   'Native failed-start recovery proof does not cover every chart-property restoration failure.',
                   'Initial-start retry proof uses a permanently invalid prefix; it proves safe retry/refusal, not transient capture-failure recovery.',
                   'Fixture configuration and cached quote are compared, not a serialized full strategy snapshot.'],
    }

    def issue(code: str, detail: str, capture: str | None = None, retryable: bool = False) -> None:
        result['issues'].append({'code': code, 'detail': detail, 'capture': capture, 'retryable': retryable})

    captures = []
    for path in paths:
        try:
            capture = _load_capture(path)
            captures.append(capture)
            result['captures'].append(capture['summary'])
        except EvidenceError as error:
            issue(error.code, str(error), str(path), error.retryable)
    if len(captures) != 3:
        return result
    metas = [capture['metadata'] for capture in captures]
    result['reference_context'] = {field: metas[0][field] for field in IDENTICAL_METADATA}
    result['compared_chart_properties'] = len(CHART_PROPERTIES)
    result['protected_chart_properties'] = sorted(UNTOUCHED_PROPERTIES)
    result['v2_png_bytes_equal'] = captures[0]['summary']['png_sha256'] == captures[2]['summary']['png_sha256']
    if [meta['design'] for meta in metas] != ['V2', 'V1', 'V2']:
        issue('wrong_design_sequence', 'Required order is V2 -> V1 -> V2')
    serials = [int(meta['serial']) for meta in metas]
    if not serials[0] < serials[1] < serials[2]:
        issue('non_monotonic_captures', 'Three distinct, increasing native capture serials are required')
    for field in IDENTICAL_METADATA:
        values = [meta[field] for meta in metas]
        if len(set(values)) != 1:
            code = 'cached_quote_changed' if field in {'cached_bid', 'quote_observed_at'} else 'capture_context_changed'
            issue(code, f'{field} differs across A/B captures: {values!r}')
    properties = [capture['properties'] for capture in captures]
    for name in sorted(CHART_PROPERTIES):
        a, b = properties[0][name], properties[2][name]
        equal = abs(a - b) <= SHIFT_TOLERANCE if name == 'CHART_SHIFT_SIZE' else a == b
        if not equal:
            issue('v2_property_roundtrip_mismatch', f'{name} first={a!r}, last={b!r}')
    for name in sorted(UNTOUCHED_PROPERTIES):
        values = [props[name] for props in properties]
        if len(set(values)) != 1:
            issue('protected_chart_property_changed', f'{name} changed across A/B: {values!r}')
    identities = [capture['identities'] for capture in captures]
    if any(name.startswith(OVERLAY_PREFIX) for name in identities[1]):
        issue('v1_overlay_orphans', 'V1 still contains objects owned by the V2 chart renderer')
    if not any(name.startswith(OVERLAY_PREFIX) for name in identities[0]):
        issue('insufficient_overlay_evidence', 'First V2 capture has no owned chart object; lifecycle proof would be vacuous')
    if identities[0] != identities[2]:
        removed = sorted(set(identities[0]) - set(identities[2]))
        added = sorted(set(identities[2]) - set(identities[0]))
        changed = sorted(name for name in set(identities[0]) & set(identities[2])
                         if identities[0][name] != identities[2][name])
        issue('v2_object_roundtrip_mismatch', f'Removed={removed!r}, added={added!r}, changed types={changed!r}')
    result['status'] = 'FAIL' if result['issues'] else 'PASS'
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs=3, metavar='CSV')
    args = parser.parse_args(argv)
    result = accept_ab(*args.captures)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
