"""Review 5f860f79 item-1 regression: KS persisted state must survive the
documented Init + SetDayAnchor restart sequence under NON-default anchor
configuration.

Defect (Codex independent review, 2026-07-20): QM_KillSwitchInit restored,
REJECTED a valid same-day file on config mismatch (globals still at defaults
pre-setter), then unconditionally saved — truncating the configured file with a
default-config fresh anchor. The later QM_KillSwitchSetDayAnchor restore saw
init's clobber, so the daily halt and depletion baseline were lost on the exact
restart path item 1 claims to protect.

Fix under test: QM_KillSwitchRestoreState returns an outcome; a valid
same-magic file under a FOREIGN anchor configuration is preserved (init skips
its save), and the config check runs BEFORE the day-key check (day_key is
computed under the anchor offset, so a foreign-config file cannot be judged
stale under our boundary).

Two layers, same file: structural assertions pin the source shape so the
python behavioural model below cannot silently drift from the .mqh.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

MQH = Path(__file__).resolve().parents[3] / "framework" / "include" / "QM" / "QM_KillSwitch.mqh"
SRC = MQH.read_text(encoding="utf-8", errors="replace")

KS_DAILY_LOSS = "KS_DAILY_LOSS"


def _func_body(name: str) -> str:
    m = re.search(rf"\b{name}\s*\([^)]*\)\s*\n\{{", SRC)
    assert m, f"{name} not found in {MQH}"
    depth, i = 0, SRC.index("{", m.start())
    for j in range(i, len(SRC)):
        if SRC[j] == "{":
            depth += 1
        elif SRC[j] == "}":
            depth -= 1
            if depth == 0:
                return SRC[i:j + 1]
    raise AssertionError(f"unbalanced braces in {name}")


# ── structural assertions (pin the source to the modelled semantics) ──────


def test_restore_returns_outcome_enum():
    assert "#define QM_KS_RESTORE_APPLIED" in SRC
    assert "#define QM_KS_RESTORE_NONE" in SRC
    assert "#define QM_KS_RESTORE_FOREIGN_CONFIG" in SRC
    assert re.search(r"\bint\s+QM_KillSwitchRestoreState\s*\(", SRC), \
        "RestoreState must return the outcome (int), not void"


def test_restore_checks_config_before_day_key():
    body = _func_body("int QM_KillSwitchRestoreState")
    cfg = body.index("saved_anchor_offset != g_qm_ks_day_anchor_offset_hours")
    day = body.index("saved_day_key != g_qm_ks_day_key")
    assert cfg < day, ("config-mismatch must be judged BEFORE staleness — "
                       "day_key is only comparable under matching anchor config")
    assert "QM_KS_RESTORE_FOREIGN_CONFIG" in body
    assert "KS_STATE_FOREIGN_CONFIG_PRESERVED" in body


def test_init_save_is_guarded_by_foreign_config():
    body = _func_body("bool QM_KillSwitchInit")
    assert re.search(
        r"if\s*\(\s*QM_KillSwitchRestoreState\s*\(\s*\)\s*!=\s*QM_KS_RESTORE_FOREIGN_CONFIG\s*\)\s*\n\s*QM_KillSwitchSaveState\s*\(\s*\)\s*;",
        body,
    ), "init must skip SaveState when restore reports a foreign-config file"


def test_setter_still_restores_then_saves():
    body = _func_body("bool QM_KillSwitchSetDayAnchor")
    r = body.index("QM_KillSwitchRestoreState")
    s = body.index("QM_KillSwitchSaveState")
    assert r < s, "setter must restore (now config-matching) before persisting"


# ── behavioural model (transcribed semantics; day_key depends on offset) ──


def _key(day: str, offset: int) -> tuple:
    return (day, offset)


class KsModel:
    """In-memory transcription of Save/Restore/Init/SetDayAnchor."""

    def __init__(self, store: dict | None):
        self.file = dict(store) if store else None
        self.magic = 111320001
        self.offset = 0
        self.max_be = False
        self.day = "2026-07-20"
        self.day_key = None
        self.anchor = 0.0
        self.halted = False
        self.reason = ""
        self.halt_day_key = None

    def save(self):
        self.file = {
            "magic": self.magic, "day_key": self.day_key, "anchor": self.anchor,
            "halted": self.halted, "reason": self.reason,
            "halt_day_key": self.halt_day_key,
            "offset": self.offset, "max_be": self.max_be,
        }

    def restore(self) -> int:
        f = self.file
        if f is None:
            return 0
        if f["magic"] != self.magic or f["anchor"] <= 0.0:
            return 0
        if f["offset"] != self.offset or f["max_be"] != self.max_be:
            return -1                       # FOREIGN_CONFIG — file preserved
        if f["day_key"] != self.day_key:
            return 0                        # stale same-config
        self.anchor = f["anchor"]
        if f["halted"] and f["halt_day_key"] == self.day_key and f["reason"] == KS_DAILY_LOSS:
            self.halted = True
            self.reason = f["reason"]
            self.halt_day_key = f["halt_day_key"]
        return 1

    def init(self, fresh_equity: float):
        self.offset, self.max_be = 0, False
        self.halted, self.reason, self.halt_day_key = False, "", None
        self.day_key = _key(self.day, self.offset)
        self.anchor = fresh_equity
        if self.restore() != -1:
            self.save()

    def set_day_anchor(self, offset: int, max_be: bool, fresh_equity: float):
        self.offset, self.max_be = offset, max_be
        self.day_key = _key(self.day, self.offset)
        self.anchor = fresh_equity
        if self.halted:
            self.halt_day_key = self.day_key
        self.restore()
        self.save()


def _configured_same_day_file(anchor=94321.50, halted=True) -> dict:
    return {
        "magic": 111320001, "day_key": _key("2026-07-20", -1), "anchor": anchor,
        "halted": halted, "reason": KS_DAILY_LOSS,
        "halt_day_key": _key("2026-07-20", -1), "offset": -1, "max_be": True,
    }


def test_configured_restart_retains_halt_and_baseline():
    """THE review scenario: offset=-1/max_be/halted state across Init+SetDayAnchor."""
    m = KsModel(_configured_same_day_file())
    m.init(fresh_equity=100_000.0)
    assert m.file["offset"] == -1 and m.file["halted"] is True, \
        "init clobbered the configured state file (the 5f860f79 defect)"
    m.set_day_anchor(-1, True, fresh_equity=100_000.0)
    assert m.halted is True, "daily halt lost across restart"
    assert m.anchor == pytest.approx(94321.50), "day-start depletion baseline lost"
    assert m.file["halted"] is True and m.file["anchor"] == pytest.approx(94321.50)


def test_default_restart_still_restores_halt():
    """Regression guard for existing default-anchor users."""
    f = _configured_same_day_file()
    f.update({"offset": 0, "max_be": False,
              "day_key": _key("2026-07-20", 0), "halt_day_key": _key("2026-07-20", 0)})
    m = KsModel(f)
    m.init(fresh_equity=100_000.0)
    assert m.halted is True and m.anchor == pytest.approx(94321.50)


def test_stale_previous_day_is_superseded():
    f = _configured_same_day_file()
    f.update({"offset": 0, "max_be": False,
              "day_key": _key("2026-07-19", 0), "halt_day_key": _key("2026-07-19", 0)})
    m = KsModel(f)
    m.init(fresh_equity=100_000.0)
    assert m.halted is False and m.anchor == pytest.approx(100_000.0)
    assert m.file["day_key"] == _key("2026-07-20", 0), "stale file must be rewritten"


def test_init_alone_preserves_foreign_file():
    """No setter call: the foreign-config file must survive init byte-for-byte."""
    original = _configured_same_day_file()
    m = KsModel(original)
    m.init(fresh_equity=100_000.0)
    assert m.file == original, "init must not rewrite a foreign-config state file"
    assert m.halted is False and m.anchor == pytest.approx(100_000.0)
