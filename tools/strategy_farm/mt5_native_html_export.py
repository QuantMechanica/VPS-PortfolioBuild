"""Native HTML export from a stopped, exclusively owned MT5 tester.

No keyboard/mouse injection, trading commands, format conversion or clipboard.
Caller must separately fence the terminal executable, creation time and run ID.
All window operations are PID-bound and use native control messages.
"""
from __future__ import annotations

import ctypes as c
from ctypes import wintypes as w
from pathlib import Path
import time
from typing import Callable


def export(pid: int, destination: Path, timeout: float = 20,
           identity_guard: Callable[[], None] | None = None) -> dict:
    if destination.exists() or destination.suffix.lower() not in {'.htm', '.html'}:
        raise ValueError('Native HTML destination must be new')
    if not destination.parent.is_dir():
        raise ValueError('Report parent must already exist')
    u = c.WinDLL('user32', use_last_error=True)
    u.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
    u.GetClassNameW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
    u.GetDlgCtrlID.argtypes = [w.HWND]
    u.GetAncestor.argtypes, u.GetAncestor.restype = [w.HWND, w.UINT], w.HWND
    u.GetParent.argtypes, u.GetParent.restype = [w.HWND], w.HWND
    u.IsWindowEnabled.argtypes = [w.HWND]
    u.IsWindowVisible.argtypes = [w.HWND]
    u.PostMessageW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM]
    u.SendMessageTimeoutW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM, w.UINT, w.UINT, c.POINTER(c.c_size_t)]
    u.SendMessageTimeoutW.restype = c.c_size_t
    callback = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)

    def owned(hwnd):
        if identity_guard:
            identity_guard()
        actual = w.DWORD()
        u.GetWindowThreadProcessId(hwnd, c.byref(actual))
        if actual.value != pid:
            raise RuntimeError('Window ownership changed')

    def message(hwnd, msg, wp=0, lp=0):
        owned(hwnd)
        result = c.c_size_t()
        if not u.SendMessageTimeoutW(hwnd, msg, wp, lp, 2, 3000, c.byref(result)):
            raise RuntimeError('Bounded native window message failed')
        return result.value

    def control_text(hwnd):
        value = c.create_unicode_buffer(32768)
        message(hwnd, 0xD, len(value), c.addressof(value))
        return value.value

    def windows(parent=None):
        values = []
        def visit(hwnd, _):
            actual = w.DWORD()
            u.GetWindowThreadProcessId(hwnd, c.byref(actual))
            if actual.value == pid:
                name = c.create_unicode_buffer(128)
                u.GetClassNameW(hwnd, name, len(name))
                values.append((hwnd, name.value))
            return True
        cb = callback(visit)
        if parent is None:
            u.EnumWindows(cb, 0)
        else:
            u.EnumChildWindows(w.HWND(parent), cb, 0)
        return values

    top = windows()
    mains = [h for h, cls in top if cls == 'MetaQuotes::MetaTrader::5.00']
    if len(mains) != 1 or any(cls == '#32770' and u.IsWindowVisible(h) for h, cls in top):
        raise RuntimeError('Expected one terminal with no pre-existing modal dialog')
    main = mains[0]
    owned(main)
    started = time.monotonic()
    # MCP leaves Settings selected after every new run. The HTML command is
    # unavailable until the tester's Backtest tab has actually been selected.
    # Build-pinned caller + seven-tab layout + tester ledger identify this tab,
    # never the live Toolbox/History or the Market Watch (also ID 10002).
    tabs = [h for h, cls in windows(main) if cls == 'SysTabControl32'
            and u.GetDlgCtrlID(h) == 10002 and message(h, 0x1304) == 7
            and any(cc == 'SysListView32' and u.GetDlgCtrlID(ch) == 10513
                    for ch, cc in windows(u.GetParent(h)))]
    if len(tabs) != 1:
        raise RuntimeError('Native tester tab was not uniquely bound')
    message(tabs[0], 0x1330, 3, 0)  # TCM_SETCURFOCUS/Backtest, no global focus.
    time.sleep(.2)
    # Build 6182: observed native Tester > Report > HTML command.
    if not u.PostMessageW(main, 0x111, 33420, 0):
        raise RuntimeError('Cannot request native HTML export')
    dialog = None
    while time.monotonic() - started < timeout:
        candidates = [h for h, cls in windows() if cls == '#32770' and u.IsWindowVisible(h) and u.IsWindowEnabled(h)]
        if len(candidates) == 1:
            dialog = candidates[0]
            break
        if len(candidates) > 1:
            raise RuntimeError('Ambiguous native save dialog')
        time.sleep(.1)
    if dialog is None:
        raise RuntimeError('Native save dialog did not appear')
    if control_text(dialog) != 'Save As':
        # Do not type into or press a generic IDOK on an unrelated MT5 modal.
        # In particular, never mistake a trading dialog for a report export.
        raise RuntimeError('Expected the English native Save As dialog; no action taken')
    try:
        editors = [h for h, cls in windows(dialog) if cls == 'Edit' and u.GetDlgCtrlID(h) == 1001
                   and u.GetAncestor(h, 2) == dialog]
        if len(editors) != 1:
            raise RuntimeError('Native filename editor was not uniquely bound')
        editor = editors[0]
        value = c.create_unicode_buffer(str(destination.resolve()))
        # WM_SETTEXT changes visible text without updating the shell dialog's
        # pending filename. EM_REPLACESEL performs a real edit (EN_CHANGE).
        message(editor, 0xB1, 0, -1)  # EM_SETSEL: entire current filename.
        message(editor, 0xC2, 1, c.addressof(value))  # EM_REPLACESEL.
        check = c.create_unicode_buffer(32768)
        message(editor, 0xD, len(check), c.addressof(check))
        if check.value != str(destination.resolve()):
            raise RuntimeError('Native filename read-back mismatch')
        if destination.exists():
            raise RuntimeError('Destination appeared concurrently; no overwrite')
        buttons = [h for h, cls in windows(dialog) if cls == 'Button' and u.GetDlgCtrlID(h) == 1
                   and u.GetAncestor(h, 2) == dialog]
        if len(buttons) != 1:
            raise RuntimeError('Native save button was not uniquely bound')
        if control_text(buttons[0]).replace('&', '') != 'Save':
            raise RuntimeError('IDOK is not the native Save button; no action taken')
        # The modern shell dialog commits its filename through the real button;
        # sending bare WM_COMMAND/IDOK can submit the old default filename.
        time.sleep(.2)
        owned(buttons[0])
        u.PostMessageW(buttons[0], 0xF5, 0, 0)  # BM_CLICK; no global input.
        while time.monotonic() - started < timeout:
            if destination.exists():
                if destination.stat().st_size > 64 * 1024**2:
                    raise RuntimeError('Native report exceeds bounded reader size')
                raw = destination.read_bytes()
                text = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
                if '</html>' in text.lower():
                    owned(main)
                    return {'native_html': str(destination), 'elapsed_seconds': time.monotonic()-started,
                            'size_bytes': len(raw), 'terminal_pid': pid}
            time.sleep(.1)
        raise RuntimeError('Native HTML export did not complete')
    finally:
        if dialog and u.IsWindowVisible(dialog):
            owned(dialog)
            u.PostMessageW(dialog, 0x111, 2, 0)
