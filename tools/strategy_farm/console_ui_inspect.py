"""Read-only inspection of one explicitly selected native MT5 window.

No terminal initialization, chart mutation, orders, keypresses, or clicks.
Captures the window with PrintWindow without changing foreground focus.
"""
from __future__ import annotations

import argparse
import ctypes as c
from ctypes import wintypes as w
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--screenshot", type=Path)
    parser.add_argument("--tree", action="store_true", help="Include visible child-window metadata")
    args = parser.parse_args()
    user = c.WinDLL("user32", use_last_error=True)
    gdi = c.WinDLL("gdi32", use_last_error=True)
    user.SetProcessDPIAware()
    callback_type = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
    user.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
    user.GetWindowTextW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
    user.GetClassNameW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
    user.GetWindowRect.argtypes = [w.HWND, c.POINTER(w.RECT)]
    user.IsWindowVisible.argtypes = [w.HWND]
    rows = []

    def inspect(hwnd, parent):
        pid = w.DWORD()
        user.GetWindowThreadProcessId(hwnd, c.byref(pid))
        if pid.value != args.pid:
            return True
        title, cls, rect = c.create_unicode_buffer(1024), c.create_unicode_buffer(256), w.RECT()
        user.GetWindowTextW(hwnd, title, 1024)
        user.GetClassNameW(hwnd, cls, 256)
        user.GetWindowRect(hwnd, c.byref(rect))
        rows.append(dict(hwnd=int(hwnd), parent=parent, title=title.value,
                         class_name=cls.value, visible=bool(user.IsWindowVisible(hwnd)),
                         rect=[rect.left, rect.top, rect.right, rect.bottom]))
        return True

    top_callback = callback_type(lambda hwnd, _: inspect(hwnd, 0))
    user.EnumWindows(top_callback, 0)
    top = list(rows)
    for window in top:
        if not window["visible"]:
            continue
        child_callback = callback_type(lambda hwnd, _, p=window["hwnd"]: inspect(hwnd, p))
        user.EnumChildWindows(w.HWND(window["hwnd"]), child_callback, 0)
    print(json.dumps([row for row in (rows if args.tree else top) if row["visible"]], indent=2))
    if not args.screenshot:
        return
    candidates = [r for r in top if r["visible"] and r["rect"][2] - r["rect"][0] > 600]
    if len(candidates) != 1:
        raise SystemExit(f"Expected one visible main window, found {len(candidates)}")
    window = candidates[0]
    hwnd = w.HWND(window["hwnd"])
    width, height = window["rect"][2] - window["rect"][0], window["rect"][3] - window["rect"][1]
    user.GetWindowDC.argtypes, user.GetWindowDC.restype = [w.HWND], w.HDC
    user.ReleaseDC.argtypes = [w.HWND, w.HDC]
    gdi.CreateCompatibleDC.argtypes, gdi.CreateCompatibleDC.restype = [w.HDC], w.HDC
    gdi.CreateCompatibleBitmap.argtypes, gdi.CreateCompatibleBitmap.restype = [w.HDC, c.c_int, c.c_int], w.HBITMAP
    gdi.SelectObject.argtypes, gdi.SelectObject.restype = [w.HDC, w.HANDLE], w.HANDLE
    gdi.DeleteObject.argtypes = [w.HANDLE]
    gdi.DeleteDC.argtypes = [w.HDC]
    user.PrintWindow.argtypes = [w.HWND, w.HDC, w.UINT]

    class BitmapInfoHeader(c.Structure):
        _fields_ = [("size", w.DWORD), ("width", w.LONG), ("height", w.LONG),
                    ("planes", w.WORD), ("bits", w.WORD), ("compression", w.DWORD),
                    ("image_size", w.DWORD), ("xppm", w.LONG), ("yppm", w.LONG),
                    ("used", w.DWORD), ("important", w.DWORD)]

    dc = user.GetWindowDC(hwnd)
    memory = gdi.CreateCompatibleDC(dc)
    bitmap = gdi.CreateCompatibleBitmap(dc, width, height)
    previous = gdi.SelectObject(memory, bitmap)
    try:
        if not user.PrintWindow(hwnd, memory, 2):
            raise OSError("PrintWindow failed")
        info = BitmapInfoHeader(c.sizeof(BitmapInfoHeader), width, -height, 1, 32, 0, 0, 0, 0, 0, 0)
        pixels = c.create_string_buffer(width * height * 4)
        gdi.GetDIBits.argtypes = [w.HDC, w.HBITMAP, w.UINT, w.UINT, w.LPVOID, w.LPVOID, w.UINT]
        # GetDIBits requires the bitmap not to be selected into any DC.
        gdi.SelectObject(memory, previous)
        previous = None
        if not gdi.GetDIBits(memory, bitmap, 0, height, pixels, c.byref(info), 0):
            raise OSError("GetDIBits failed")
        from PIL import Image
        args.screenshot.parent.mkdir(parents=True, exist_ok=True)
        Image.frombuffer("RGB", (width, height), pixels, "raw", "BGRX", 0, 1).save(args.screenshot)
        print(json.dumps({"screenshot": str(args.screenshot), "size": [width, height]}))
    finally:
        if previous:
            gdi.SelectObject(memory, previous)
        gdi.DeleteObject(bitmap)
        gdi.DeleteDC(memory)
        user.ReleaseDC(hwnd, dc)


if __name__ == "__main__":
    main()
