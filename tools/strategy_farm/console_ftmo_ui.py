"""Bounded visual QA navigation in the already-running FTMO demo terminal.

Uses native control messages, so no unlocked RDP desktop or mouse movement is
required. No process start/stop, account operation, AutoTrading toggle, template,
timeframe change, or trading-EA attach is implemented here.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import site
import time

import psutil

site.addsitedir("D:/QM/console_design_20260907/python_deps")
from pywinauto import Application, win32defines  # noqa: E402

TERMINAL = r"C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe"
DATA = Path("C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850")
# IDs observed from FTMO's native Navigator context menu on 2026-09-07.
# UI Automation's owner-drawn popup Invoke did not dispatch reliably; these are
# the same normal WM_COMMAND operations after selection is independently read.
ATTACH_TO_CHART = 33021
REFRESH_NAVIGATOR = 33416


def connect():
    matches = [p for p in psutil.process_iter(["pid", "exe"])
               if (p.info["exe"] or "").casefold() == TERMINAL.casefold()]
    if len(matches) != 1:
        raise RuntimeError("Expected exactly one already-running FTMO terminal")
    app = Application(backend="win32").connect(process=matches[0].pid)
    window = app.window(class_name="MetaQuotes::MetaTrader::5.00")
    title = window.window_text()
    if "1514536732 - FTMO-Demo: Demo Account" not in title:
        raise RuntimeError("Wrong account or non-demo terminal; refusing UI action")
    return app, window


def select_node(window, path):
    tree = window.child_window(class_name="SysTreeView32")
    node = tree.get_item(["FTMO", *path], exact=True)
    node.click()  # Message-based selection; never click_input / global mouse.
    selected = tree.send_message(win32defines.TVM_GETNEXTITEM, win32defines.TVGN_CARET, 0)
    if selected != node.elem:
        raise RuntimeError("Navigator selection did not match the requested QA node")


def command(window, command_id):
    window.send_message(win32defines.WM_CANCELMODE)
    window.post_message(win32defines.WM_COMMAND, command_id, 0)


def check_default_template():
    # ChartOpen may apply default.tpl including its EA. Refuse such templates
    # before the MQL script creates its first fixture, not merely afterwards.
    for root in (DATA, Path(TERMINAL).parent):
        template = root / "MQL5/Profiles/Templates/default.tpl"
        if not template.exists():
            continue
        raw = template.read_bytes()
        encoding = "utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-16-le" if b"\x00" in raw[:80] else "utf-8"
        content = raw.decode(encoding, errors="strict").casefold()
        if "<chart>" not in content or "<expert>" in content:
            raise RuntimeError("Default template not verified EA-free; no fixture creation")


def fixture_frame(app, window):
    import win32gui
    import win32process
    marker = DATA / "MQL5/Files/QM_Console_QA/fixture_window.txt"
    if time.time() - marker.stat().st_mtime > 30:
        raise RuntimeError("Fresh successful launcher binding required within 30 seconds")
    view = int(marker.read_text().strip())
    if win32process.GetWindowThreadProcessId(view)[1] != app.process:
        raise RuntimeError("Fixture HWND belongs to another terminal")
    frame = win32gui.GetParent(view)
    mdi = win32gui.GetParent(frame)
    if (win32gui.GetClassName(mdi) != "MDIClient" or
            win32gui.GetParent(mdi) != window.handle or
            win32gui.GetWindowText(frame) != "EURUSD,Daily"):
        raise RuntimeError("Unexpected fixture window hierarchy")
    return frame, mdi


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["inspect", "refresh", "launch-probe", "fixture-binding", "attach-fixture"])
    parser.add_argument("--sha256", help="Required installed QA binary hash for attach-fixture")
    args = parser.parse_args()
    app, window = connect()
    if args.action == "refresh":
        select_node(window, ["Scripts"])
        command(window, REFRESH_NAVIGATOR)
        print("Requested Navigator refresh; terminal/trading untouched")
    elif args.action == "launch-probe":
        check_default_template()
        select_node(window, ["Scripts", "QM_Design_QA", "QM_Console_ProbeLauncher"])
        command(window, ATTACH_TO_CHART)
        print("Requested read-only audit / empty QA chart script")
    elif args.action == "fixture-binding":
        import win32gui
        import win32process
        native = int((DATA / "MQL5/Files/QM_Console_QA/fixture_window.txt").read_text().strip())
        pid = win32process.GetWindowThreadProcessId(native)[1]
        if pid != app.process:
            raise RuntimeError("Fixture HWND does not belong to the pinned terminal")
        chain = []
        while native:
            chain.append((native, win32gui.GetClassName(native), win32gui.GetWindowText(native)))
            native = win32gui.GetParent(native)
        print(chain)
    elif args.action == "attach-fixture":
        import win32gui
        binary = DATA / "MQL5/Experts/QM_Design_QA/QM_Console_Visual_QA.ex5"
        digest = hashlib.sha256(binary.read_bytes()).hexdigest()
        if not args.sha256 or digest != args.sha256.lower():
            raise RuntimeError("Exact compiled no-trade QA binary hash required")
        frame, mdi = fixture_frame(app, window)
        win32gui.SendMessage(mdi, win32defines.WM_MDIACTIVATE, frame, 0)
        select_node(window, ["Expert Advisors", "QM_Design_QA", "QM_Console_Visual_QA"])
        if win32gui.SendMessage(mdi, win32defines.WM_MDIGETACTIVE, 0, 0) != frame:
            raise RuntimeError("Active chart drifted away from the bound empty QA fixture")
        command(window, ATTACH_TO_CHART)
        print("Requested QA properties on independently bound empty fixture; no OK/replace confirmation automated")
    else:
        tree = window.child_window(class_name="SysTreeView32")
        for branch in ("Scripts", "Expert Advisors"):
            parent = tree.get_item(["FTMO", branch], exact=True)
            print(branch, [(i.text(), [j.text() for j in i.children()]) for i in parent.children()
                           if i.text() == "QM_Design_QA"])
        print("Visible dialogs:", [(x.handle, x.class_name(), x.window_text()) for x in app.windows()
                                   if x.is_visible()])


if __name__ == "__main__":
    main()
