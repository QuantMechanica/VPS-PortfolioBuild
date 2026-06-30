#!/usr/bin/env python3
"""QuantMechanica - agy (Antigravity/Gemini) Quota Governor.

The "control" half of OWNER's 2026-06-30 ask (track + control agy usage). agy's
quota is a ~5h rolling window on a small free tier; a video-heavy harvest run
burns it fast and then WALLS (7/13 batches, then instant ~13s fails) — wasting
partial runs. This governor paces agy: when the remaining quota drops below a
floor, it raises a gate flag that the agy consumers (the channel harvest; future:
the gemini orchestration) honor — they stop launching NEW agy work until the
window resets, instead of grinding into the wall. After reset the quota recovers
and the flag auto-clears.

Pull mechanism = tools/strategy_farm/agy_quota.py (Credential Manager token ->
Gemini Code Assist API). MUST run in the Administrator context (the credential
vault is DPAPI-protected for that user; SYSTEM/S4U cannot decrypt it) -> the
scheduled task uses LogonType Interactive (install_agy_governor_scheduled_task.ps1).

  python agy_governor.py            # pull + apply gate
  python agy_governor.py --dry-run  # decide only, no flag writes

Lever (honored by antigravity_channel_harvest.py):
  D:/QM/strategy_farm/AGY_LOW_QUOTA.flag  -> harvest stops launching new batches
Ownership-tracked: only clears a flag THIS governor set (agy_governor_state.json),
never one set manually.
"""
from __future__ import annotations
import argparse, datetime as dt, json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agy_quota  # noqa: E402

ROOT = Path(r"D:/QM/strategy_farm")
FLAG = ROOT / "AGY_LOW_QUOTA.flag"
QUOTA_STATE = Path(r"D:/QM/reports/state/agy_quota.json")
STATE = Path(r"D:/QM/reports/state/agy_governor_state.json")
LOG = Path(r"D:/QM/reports/state/agy_governor.log")

FLOOR_PCT = 20.0   # gate below this remaining% (a video batch needs ~>15-20% headroom or it times out)


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _log(msg: str) -> None:
    line = f"{_now().strftime('%Y-%m-%dT%H:%M:%SZ')} {msg}"
    print(line)
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except Exception:
        pass


def _parse_iso(s):
    if not s:
        return None
    try:
        x = dt.datetime.fromisoformat(str(s).replace("Z", "+00:00"))
        return x if x.tzinfo else x.replace(tzinfo=dt.timezone.utc)
    except Exception:
        return None


def _load_owned() -> bool:
    try:
        return bool(json.loads(STATE.read_text(encoding="utf-8")).get("flag_owned"))
    except Exception:
        return False


def _save_owned(owned: bool, extra: dict | None = None) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps({"flag_owned": owned, "updated_at": _now().isoformat(), **(extra or {})}, indent=2), encoding="utf-8")


def _set_flag(remaining, reset, dry: bool) -> None:
    if dry:
        _log(f"[dry-run] would GATE agy ({remaining}% < {FLOOR_PCT}, reset {reset})")
        return
    ROOT.mkdir(parents=True, exist_ok=True)
    FLAG.write_text(json.dumps({
        "owner": "agy_governor", "reason": "low_quota",
        "remaining_pct": remaining, "reset": reset,
        "release_floor_pct": FLOOR_PCT, "set_at": _now().isoformat(),
    }, indent=2), encoding="utf-8")
    _save_owned(True, {"reset": reset, "remaining_pct": remaining})
    _log(f"GATE agy: {remaining}% < {FLOOR_PCT}% -> {FLAG.name} (reset {reset})")


def _clear_flag(reason: str, dry: bool) -> None:
    if dry:
        _log(f"[dry-run] would RELEASE agy ({reason})")
        return
    try:
        FLAG.unlink(missing_ok=True)
    except Exception:
        pass
    _save_owned(False)
    _log(f"RELEASE agy: {reason} -> removed {FLAG.name}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)

    res = agy_quota.pull()
    res["checked_at"] = res.get("checked_at") or _now().isoformat()
    try:
        QUOTA_STATE.parent.mkdir(parents=True, exist_ok=True)
        QUOTA_STATE.write_text(json.dumps(res, indent=2), encoding="utf-8")
    except Exception:
        pass

    owned = _load_owned()
    flag_exists = FLAG.exists()

    if res.get("ok"):
        rem = res.get("binding_remaining_pct")
        reset = res.get("binding_reset")
        if rem is None:
            _log("agy pull ok but no quota fraction returned; no action")
            return 0
        if rem < FLOOR_PCT:
            if not flag_exists:
                _set_flag(rem, reset, args.dry_run)
            else:
                _log(f"agy still gated: {rem}% < {FLOOR_PCT}% (reset {reset})")
        else:
            if flag_exists and owned:
                _clear_flag(f"recovered to {rem}% >= {FLOOR_PCT}%", args.dry_run)
            elif flag_exists:
                _log(f"agy {rem}% ok but flag not owned by governor -> leaving it")
            else:
                _log(f"agy ok: {rem}% remaining (reset {reset}); no gate")
        return 0

    # pull failed — usually a stale access_token while agy is idle (refreshes on next agy run)
    err = str(res.get("error"))[:120]
    if flag_exists and owned:
        fl = {}
        try:
            fl = json.loads(FLAG.read_text(encoding="utf-8"))
        except Exception:
            pass
        reset = _parse_iso(fl.get("reset"))
        if reset and _now() >= reset:
            _clear_flag(f"window reset passed ({fl.get('reset')}); stale-token pull, auto-clear", args.dry_run)
        else:
            _log(f"agy pull failed ({err}); keeping owned gate until reset {fl.get('reset')}")
    else:
        _log(f"agy pull failed ({err}); no owned gate -> no action (agy likely idle/token stale)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
