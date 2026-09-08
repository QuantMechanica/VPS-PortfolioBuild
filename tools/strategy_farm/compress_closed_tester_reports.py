"""Lossless NTFS compression of old native HTML reports, never history or live files.

Dry-run default. Exact file targets, >=48h age, single link, no reparse paths,
exclusive write/delete denial, SHA-256 before/after and timestamp verification.
No report is removed, renamed, reparsed, or granted a new verdict.
"""
from __future__ import annotations
import argparse
import ctypes
from ctypes import wintypes as wt
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import time

REPARSE = 0x400
COMPRESSED = 0x800


def candidates(mt5_root: Path, *, now: float) -> list[dict]:
    result = []
    for n in range(1, 11):
        root = mt5_root / f'T{n}'
        if not root.is_dir() or root.lstat().st_file_attributes & REPARSE:
            continue
        for path in root.glob('QM5_*.htm'):
            try:
                s = path.stat(follow_symlinks=False)
                if (s.st_file_attributes & (REPARSE | COMPRESSED) or s.st_nlink != 1
                    or s.st_size < 10 * 1024**2 or now - s.st_mtime < 48 * 3600
                    or not path.resolve().is_relative_to(root.resolve())):
                    continue
                result.append({'path': str(path), 'bytes': s.st_size, 'mtime_ns': s.st_mtime_ns})
            except OSError:
                continue
    return sorted(result, key=lambda r: r['bytes'], reverse=True)


def digest(handle) -> str:
    handle.seek(0)
    h = hashlib.sha256()
    for block in iter(lambda: handle.read(4 * 1024**2), b''):
        h.update(block)
    return h.hexdigest()


def compress(row: dict) -> dict:
    import msvcrt
    path = Path(row['path'])
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateFileW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, wt.LPVOID, wt.DWORD, wt.DWORD, wt.HANDLE]
    kernel.CreateFileW.restype = wt.HANDLE
    kernel.DeviceIoControl.argtypes = [wt.HANDLE, wt.DWORD, wt.LPVOID, wt.DWORD, wt.LPVOID, wt.DWORD, ctypes.POINTER(wt.DWORD), wt.LPVOID]
    kernel.DeviceIoControl.restype = wt.BOOL
    kernel.CloseHandle.argtypes = [wt.HANDLE]
    # GENERIC_READ|WRITE, FILE_SHARE_READ only: existing or new writers/deleters
    # cannot overlap the metadata operation or either hash pass.
    h = kernel.CreateFileW(str(path), 0xC0000000, 1, None, 3, 0x00200000, None)
    if h == wt.HANDLE(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        fd = msvcrt.open_osfhandle(h, os.O_RDONLY | os.O_BINARY)
    except Exception:
        kernel.CloseHandle(h); raise
    with os.fdopen(fd, 'rb') as handle:
        s = os.fstat(handle.fileno())
        if s.st_size != row['bytes'] or s.st_mtime_ns != row['mtime_ns'] or s.st_nlink != 1:
            raise RuntimeError(f'Candidate changed: {path}')
        if path.lstat().st_file_attributes & REPARSE:
            raise RuntimeError(f'Reparse target refused: {path}')
        before = digest(handle)
        fmt = wt.WORD(1)  # COMPRESSION_FORMAT_DEFAULT
        returned = wt.DWORD()
        if not kernel.DeviceIoControl(h, 0x0009C040, ctypes.byref(fmt), ctypes.sizeof(fmt),
                                      None, 0, ctypes.byref(returned), None):
            raise ctypes.WinError(ctypes.get_last_error())
        after = digest(handle)
        s2 = os.fstat(handle.fileno())
        if before != after or s2.st_size != row['bytes'] or s2.st_mtime_ns != row['mtime_ns']:
            raise RuntimeError(f'Compression content/timestamp verification failed: {path}')
        return {**row, 'sha256': before, 'hash_unchanged': True,
                'compressed': bool(path.stat().st_file_attributes & COMPRESSED)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--target-free-gib', type=float, default=150)
    parser.add_argument('--max-logical-gib', type=float, default=40)
    args = parser.parse_args()
    if os.name != 'nt' or not 0 < args.max_logical_gib <= 80:
        raise RuntimeError('Windows and a bounded <=80 GiB batch required')
    rows = candidates(Path('D:/QM/mt5'), now=time.time())
    selected = []; logical = 0
    for row in rows:
        if logical + row['bytes'] > args.max_logical_gib * 1024**3:
            continue
        selected.append(row); logical += row['bytes']
    receipt = {'started_at': dt.datetime.now(dt.UTC).isoformat(), 'apply': args.apply,
               'free_before_gib': shutil.disk_usage('D:/').free / 1024**3,
               'planned_logical_gib': logical / 1024**3, 'selected': selected, 'verified': [], 'skipped': []}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    def publish():
        receipt['free_after_gib'] = shutil.disk_usage('D:/').free / 1024**3
        args.out.write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    publish()
    print(json.dumps({k:v for k,v in receipt.items() if k not in ('selected','verified','skipped')}), flush=True)
    print('SELECTED', len(selected), flush=True)
    if not args.apply:
        return 0
    for row in selected:
        if shutil.disk_usage('D:/').free / 1024**3 >= args.target_free_gib:
            break
        try:
            receipt['verified'].append(compress(row))
        except OSError as exc:
            if getattr(exc, 'winerror', None) not in (2, 3, 32, 33):
                publish(); raise
            receipt['skipped'].append({'path': row['path'], 'error': str(exc)})
        publish()
        print('VERIFIED', len(receipt['verified']), 'FREE_GIB', round(receipt['free_after_gib'], 2), flush=True)
    receipt['finished_at'] = dt.datetime.now(dt.UTC).isoformat(); publish()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
