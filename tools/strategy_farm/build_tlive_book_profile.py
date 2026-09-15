#!/usr/bin/env python3
"""Build (and verify) the T_Live chart profile for a book cutover from staged presets.

Why
---
A live MT5 terminal takes every EA input from the chart file (``Profiles/Charts/<profile>/
chartNN.chr``, UTF-16), not from ``MQL5/Presets``.  Re-weighting 24 deployed sleeves and
adding 4 new ones therefore needs a NEW profile whose charts carry the staged inputs.  The
July ceremony built that profile by hand in the terminal; this tool builds it from the
staged package so the cutover is reproducible, hash-bound and verifiable.

What it does (dry-run by default, ``--apply`` writes the profile INTO THE STAGING DIR
only; copying it to T_Live is a separate ceremony step):

* existing sleeves: the template chart of the same (ea_id, symbol) from the current live
  profile is copied byte-for-byte except the ``RISK_PERCENT=`` line inside ``<inputs>``,
  which takes the staged preset's value (``presets/existing``);
* replaced sleeves (``--repair-delta``): the template chart keeps its symbol/period/window,
  the expert name/path and the whole ``<inputs>`` block come from the repair preset;
* new sleeves: a template chart of the same symbol (else the same asset class, else the
  first chart) supplies the chart skeleton; symbol, period, expert name/path and the
  ``<inputs>`` block are replaced.  Inputs = framework keys of the template (everything
  that is not ``strategy_*``) overridden and extended by the staged burn-in preset, so
  the news/friday-close/chart-ui contract of the live book carries over and the sleeve's
  own parameters come from the preset.  Keys taken from the template are listed in the
  manifest so the ceremony's INIT-log check can confirm them;
* the read-only QM_AccountMonitor chart of the template profile is appended last;
* ``profile_manifest.json`` binds every chart (sha256, symbol, period, expert path, ea_id,
  slot, magic, RISK_PERCENT, sources) and the totals; ``--verify <dir>`` re-parses a profile
  on disk (e.g. after MT5 saved it) and compares it semantically to that manifest.

Never touches T_Live, never starts a terminal, never changes AutoTrading.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

SCHEMA = "qm.tlive_book_profile.v1"
DEFAULT_TEMPLATE_PROFILE = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Profiles\Charts\DarwinexZero_V2_LiveOps")
MONITOR_NAME = "QM_AccountMonitor"
LIVE_EXPERT_DIR = r"Experts\Live EAs"
PERIOD_BY_TF = {"M1": (0, 1), "M5": (0, 5), "M15": (0, 15), "M30": (0, 30), "H1": (1, 1), "H4": (1, 4), "D1": (1, 24), "W1": (2, 1)}
ASSET_CLASS = {
    "XAGUSD": "metal", "XAUUSD": "metal", "WS30": "index", "NDX": "index", "SP500": "index", "GDAXI": "index",
    "UK100": "index", "XTIUSD": "energy", "XBRUSD": "energy", "XNGUSD": "energy",
}
DESCRIPTION = {"XAGUSD": "Silver vs US Dollar", "WS30": "Wall Street 30 Index", "XAUUSD": "Gold vs US Dollar", "NDX": "US Tech 100 Index"}
DIGITS = {"XAGUSD": 3, "WS30": 1, "XAUUSD": 2, "NDX": 1, "SP500": 1, "GDAXI": 1}
PRESET_RE = re.compile(r"^(?P<n>\d{2})_(?P<sym>[A-Z0-9]+)_(?P<tf>[MHDW]\d+)_QM5_(?P<ea>\d+)_(?P<slug>.+)\.set$")


class ProfileError(ValueError):
    """The inputs are inconsistent or a safety invariant would break."""


# --------------------------------------------------------------------------- chart file grammar

def read_chart(path: Path) -> str:
    raw = path.read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    return raw.decode("utf-8")


def write_chart(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.encode("utf-16"))  # BOM + UTF-16 LE, like MT5


def _line_ending(text: str) -> str:
    return "\r\n" if "\r\n" in text else "\n"


def _field(text: str, key: str) -> str:
    m = re.search(rf"^{re.escape(key)}=(.*?)\r?$", text, re.M)
    return m.group(1) if m else ""


def _set_field(text: str, key: str, value: str, *, section: str | None = None) -> str:
    """Replace the first ``key=`` line (optionally only inside the first <section>...</section>)."""
    if section:
        start = text.index(f"<{section}>")
        end = text.index(f"</{section}>", start)
        head, body, tail = text[:start], text[start:end], text[end:]
        body, n = re.subn(rf"^{re.escape(key)}=.*?(\r?)$", lambda m: f"{key}={value}{m.group(1)}", body, count=1, flags=re.M)
        if n != 1:
            raise ProfileError(f"{key}= not found inside <{section}>")
        return head + body + tail
    text, n = re.subn(rf"^{re.escape(key)}=.*?(\r?)$", lambda m: f"{key}={value}{m.group(1)}", text, count=1, flags=re.M)
    if n != 1:
        raise ProfileError(f"{key}= not found")
    return text


def parse_inputs(text: str) -> list[tuple[str, str]]:
    start = text.index("<inputs>") + len("<inputs>")
    end = text.index("</inputs>")
    pairs: list[tuple[str, str]] = []
    for line in text[start:end].splitlines():
        line = line.rstrip("\r")
        if "=" in line:
            k, v = line.split("=", 1)
            pairs.append((k, v))
    return pairs


def replace_inputs(text: str, pairs: list[tuple[str, str]]) -> str:
    eol = _line_ending(text)
    start = text.index("<inputs>") + len("<inputs>")
    end = text.index("</inputs>")
    body = eol + eol.join(f"{k}={v}" for k, v in pairs) + eol
    return text[:start] + body + text[end:]


def chart_record(path: Path) -> dict[str, Any]:
    text = read_chart(path)
    inputs = dict(parse_inputs(text)) if "<inputs>" in text else {}
    expert_start = text.find("<expert>")
    expert = text[expert_start:text.find("</expert>", expert_start)] if expert_start >= 0 else ""
    return {
        "file": path.name,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "chart_id": _field(text, "id"),
        "symbol": _field(text, "symbol"),
        "period_type": _field(text, "period_type"),
        "period_size": _field(text, "period_size"),
        "expert_name": _field(expert, "name"),
        "expert_path": _field(expert, "path"),
        "ea_id": inputs.get("qm_ea_id", ""),
        "slot": inputs.get("qm_magic_slot_offset", ""),
        "risk_percent": inputs.get("RISK_PERCENT", ""),
        "risk_fixed": inputs.get("RISK_FIXED", ""),
        "is_monitor": _field(expert, "name") == MONITOR_NAME,
        "input_count": len(inputs),
    }


# --------------------------------------------------------------------------- presets

def parse_preset(path: Path) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for line in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith(";"):
            continue
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        v = v.split("||", 1)[0]  # optimisation suffix never belongs in a live chart
        pairs.append((k.strip(), v.strip()))
    return pairs


def preset_meta(path: Path) -> dict[str, Any]:
    m = PRESET_RE.match(path.name)
    if not m:
        raise ProfileError(f"preset name off-contract: {path.name}")
    return {"n": int(m["n"]), "symbol": m["sym"], "tf": m["tf"], "ea_id": int(m["ea"]), "slug": m["slug"]}


def find_preset(directory: Path, ea_id: int, symbol: str) -> Path | None:
    hits = [p for p in sorted(directory.glob("*.set")) if PRESET_RE.match(p.name)
            and preset_meta(p)["ea_id"] == ea_id and preset_meta(p)["symbol"] == symbol]
    if len(hits) > 1:
        raise ProfileError(f"ambiguous presets for QM5_{ea_id}/{symbol} in {directory}: {[p.name for p in hits]}")
    return hits[0] if hits else None


# --------------------------------------------------------------------------- build

def _bare(symbol: str) -> str:
    return symbol.replace(".DWX", "")


def _template_for_new(symbol: str, templates: list[dict[str, Any]]) -> dict[str, Any]:
    same = [t for t in templates if t["symbol"] == symbol and not t["is_monitor"]]
    if same:
        return same[0]
    cls = ASSET_CLASS.get(symbol)
    same_cls = [t for t in templates if ASSET_CLASS.get(t["symbol"]) == cls and not t["is_monitor"]] if cls else []
    if same_cls:
        return same_cls[0]
    return next(t for t in templates if not t["is_monitor"])


def _merge_inputs(template_pairs: list[tuple[str, str]], preset_pairs: list[tuple[str, str]]) -> tuple[list[tuple[str, str]], list[str]]:
    preset = dict(preset_pairs)
    merged: list[tuple[str, str]] = []
    from_template: list[str] = []
    seen: set[str] = set()
    for k, v in template_pairs:
        if k.startswith("strategy_"):
            continue  # EA-specific parameters of ANOTHER EA never carry over
        if k in preset:
            merged.append((k, preset[k]))
        else:
            merged.append((k, v))
            if v != "" or not k[:1].isupper():  # group labels ("Risk=") are cosmetic, not inputs
                from_template.append(k) if v != "" else None
        seen.add(k)
    for k, v in preset_pairs:
        if k not in seen:
            merged.append((k, v))
            seen.add(k)
    return merged, from_template


def build_profile(
    *,
    manifest: dict[str, Any],
    staging: Path,
    template_profile: Path,
    out_dir: Path,
    profile_name: str,
    repair_delta: dict[str, Any] | None = None,
    apply: bool = False,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    now = now or dt.datetime.now(dt.timezone.utc)
    sleeves = list(manifest.get("sleeves") or [])
    if not sleeves:
        raise ProfileError("manifest carries no sleeves")
    templates = [chart_record(p) for p in sorted(template_profile.glob("chart*.chr"))]
    if not templates:
        raise ProfileError(f"template profile has no charts: {template_profile}")
    monitor = [t for t in templates if t["is_monitor"]]
    if len(monitor) != 1:
        raise ProfileError(f"template profile must carry exactly one {MONITOR_NAME} chart, found {len(monitor)}")
    by_key = {(int(t["ea_id"]), t["symbol"]): t for t in templates if t["ea_id"]}

    replaced: dict[tuple[int, str], dict[str, Any]] = {}
    if repair_delta:
        s = repair_delta["sleeve"]
        rep = s["replaces"] if isinstance(s.get("replaces"), dict) else repair_delta.get("replaces") or {}
        old_ea = int(rep.get("ea_id") or 0)
        if not old_ea:
            raise ProfileError("repair delta without replaces.ea_id")
        replaced[(old_ea, _bare(rep.get("symbol") or s["symbol"]))] = s

    charts: list[dict[str, Any]] = []
    used_ids: set[str] = set()
    next_id = max(int(t["chart_id"] or 0) for t in templates) + 1
    chart_no = 0
    problems: list[str] = []
    seen_keys: set[tuple[int, str]] = set()
    for sl in sleeves:
        ea_id = int(sl["ea_id"])
        symbol = _bare(str(sl["symbol"]))
        key = (ea_id, symbol)
        if key in seen_keys:
            problems.append(f"duplicate sleeve {key}")
            continue
        seen_keys.add(key)
        is_new = bool(sl.get("is_new_sleeve"))
        chart_no += 1
        rec: dict[str, Any] = {"chart_no": chart_no, "ea_id": ea_id, "symbol": symbol, "is_new": is_new}
        if key in replaced:
            delta = replaced[key]
            new_ea = int(delta["ea_id"])
            preset = find_preset(staging / "repair_v2" / "presets", new_ea, symbol)
            tmpl = by_key.get(key)
            if preset is None or tmpl is None:
                problems.append(f"repair {key}->{new_ea}: preset={preset} template={tmpl and tmpl['file']}")
                continue
            text = read_chart(template_profile / tmpl["file"])
            pairs = parse_preset(preset)
            ex5 = f"QM5_{new_ea}_{delta.get('ea_slug') or preset_meta(preset)['slug']}"
            name = preset_meta(preset)["slug"]
            expert_name = f"QM5_{new_ea}_{name}"
            text = _set_field(text, "name", expert_name, section="expert")
            text = _set_field(text, "path", f"{LIVE_EXPERT_DIR}\\{expert_name}.ex5", section="expert")
            text = replace_inputs(text, pairs)
            rec.update({"kind": "replaced", "replaces_ea_id": ea_id, "ea_id": new_ea, "template": tmpl["file"],
                        "preset": str(preset), "expert_name": expert_name})
            _ = ex5
        elif not is_new:
            tmpl = by_key.get(key)
            preset = find_preset(staging / "presets" / "existing", ea_id, symbol)
            if tmpl is None or preset is None:
                problems.append(f"existing {key}: template={tmpl and tmpl['file']} preset={preset}")
                continue
            pairs = dict(parse_preset(preset))
            if "RISK_PERCENT" not in pairs:
                problems.append(f"existing {key}: staged preset has no RISK_PERCENT")
                continue
            text = read_chart(template_profile / tmpl["file"])
            text = _set_field(text, "RISK_PERCENT", pairs["RISK_PERCENT"], section="inputs")
            rec.update({"kind": "reweighted", "template": tmpl["file"], "preset": str(preset),
                        "expert_name": tmpl["expert_name"], "old_risk_percent": tmpl["risk_percent"]})
        else:
            preset = find_preset(staging / "presets" / "new_burnin", ea_id, symbol)
            if preset is None:
                problems.append(f"new {key}: no burn-in preset")
                continue
            meta = preset_meta(preset)
            tmpl = _template_for_new(symbol, templates)
            text = read_chart(template_profile / tmpl["file"])
            ptype, psize = PERIOD_BY_TF[meta["tf"]]
            text = _set_field(text, "id", str(next_id)); next_id += 1
            text = _set_field(text, "symbol", symbol)
            text = _set_field(text, "description", DESCRIPTION.get(symbol, symbol))
            text = _set_field(text, "period_type", str(ptype))
            text = _set_field(text, "period_size", str(psize))
            if symbol in DIGITS:
                text = _set_field(text, "digits", str(DIGITS[symbol]))
            expert_name = f"QM5_{ea_id}_{meta['slug']}"
            text = _set_field(text, "name", expert_name, section="expert")
            text = _set_field(text, "path", f"{LIVE_EXPERT_DIR}\\{expert_name}.ex5", section="expert")
            merged, from_template = _merge_inputs(parse_inputs(text), parse_preset(preset))
            text = replace_inputs(text, merged)
            rec.update({"kind": "new", "template": tmpl["file"], "preset": str(preset), "expert_name": expert_name,
                        "timeframe": meta["tf"], "inputs_from_template": from_template})
        # invariants
        inputs = dict(parse_inputs(text))
        if inputs.get("RISK_FIXED", "0") not in {"0", "0.0"}:
            problems.append(f"{key}: RISK_FIXED={inputs.get('RISK_FIXED')} (live must be RISK_PERCENT mode)")
        if str(inputs.get("qm_ea_id")) != str(rec["ea_id"]):
            problems.append(f"{key}: chart qm_ea_id={inputs.get('qm_ea_id')} != {rec['ea_id']}")
        cid = _field(text, "id")
        if cid in used_ids:
            problems.append(f"{key}: duplicate chart id {cid}")
        used_ids.add(cid)
        slot = int(inputs.get("qm_magic_slot_offset") or 0)
        expected_magic = sl.get("magic")
        if expected_magic not in (None, "") and key not in replaced and int(expected_magic) != int(rec["ea_id"]) * 10000 + slot:
            problems.append(f"{key}: chart magic {int(rec['ea_id']) * 10000 + slot} != manifest magic {expected_magic}")
        if key in replaced and replaced[key].get("magic") not in (None, "") and int(replaced[key]["magic"]) != int(rec["ea_id"]) * 10000 + slot:
            problems.append(f"{key}: replaced chart magic {int(rec['ea_id']) * 10000 + slot} != delta magic {replaced[key]['magic']}")
        rec.update({
            "file": f"chart{chart_no:02d}.chr", "chart_id": cid, "symbol_in_chart": _field(text, "symbol"),
            "period": f"{_field(text, 'period_type')}/{_field(text, 'period_size')}",
            "expert_path": _field(text[text.find('<expert>'):], "path"),
            "slot": slot, "magic": int(rec["ea_id"]) * 10000 + slot,
            "risk_percent": inputs.get("RISK_PERCENT", ""), "risk_fixed": inputs.get("RISK_FIXED", ""),
            "preset_sha256": hashlib.sha256(Path(rec["preset"]).read_bytes()).hexdigest() if rec.get("preset") else None,
            "text": text,
        })
        charts.append(rec)
    # monitor last
    chart_no += 1
    mon = monitor[0]
    mon_text = read_chart(template_profile / mon["file"])
    charts.append({"chart_no": chart_no, "kind": "monitor", "file": f"chart{chart_no:02d}.chr", "template": mon["file"],
                   "expert_name": mon["expert_name"], "expert_path": mon["expert_path"], "symbol": mon["symbol"],
                   "ea_id": None, "slot": None, "magic": None, "risk_percent": None, "text": mon_text,
                   "chart_id": mon["chart_id"], "symbol_in_chart": mon["symbol"], "period": f"{mon['period_type']}/{mon['period_size']}"})
    magics = [c["magic"] for c in charts if c.get("magic")]
    if len(magics) != len(set(magics)):
        problems.append(f"duplicate magics: {sorted(m for m in magics if magics.count(m) > 1)}")
    sleeve_charts = [c for c in charts if c["kind"] != "monitor"]
    total_risk = sum(float(c["risk_percent"]) for c in sleeve_charts if c.get("risk_percent"))
    result: dict[str, Any] = {
        "schema": SCHEMA, "profile_name": profile_name, "generated_at_utc": now.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "apply": bool(apply), "out_dir": str(out_dir / profile_name), "template_profile": str(template_profile),
        "manifest_variant": manifest.get("variant"), "owner_decision": manifest.get("owner_decision"),
        "n_sleeves": len(sleeve_charts), "n_charts": len(charts), "total_risk_percent_at_cutover": round(total_risk, 6),
        "kinds": {k: sum(1 for c in charts if c["kind"] == k) for k in ("reweighted", "replaced", "new", "monitor")},
        "problems": problems,
        "charts": [],
    }
    for c in charts:
        entry = {k: v for k, v in c.items() if k != "text"}
        entry["sha256"] = hashlib.sha256(c["text"].encode("utf-16")).hexdigest()
        result["charts"].append(entry)
    if problems:
        result["status"] = "BLOCKED"
        return result
    result["status"] = "APPLIED" if apply else "DRY_RUN"
    if apply:
        target = out_dir / profile_name
        if target.exists() and any(target.iterdir()):
            raise ProfileError(f"refusing to overwrite a non-empty profile dir: {target} (delete it explicitly first)")
        for c in charts:
            write_chart(target / c["file"], c["text"])
        (target / "profile_manifest.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        (target / "profile_sha256.txt").write_text(
            "".join(f"{c['sha256']}  {c['file']}\n" for c in result["charts"]), encoding="utf-8")
    return result


# --------------------------------------------------------------------------- verify

def verify_profile(profile_dir: Path, manifest_path: Path) -> dict[str, Any]:
    """Semantic comparison of an on-disk profile with the build manifest (MT5 may re-save window state)."""
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected = {c["file"]: c for c in manifest["charts"]}
    found = {p.name: chart_record(p) for p in sorted(profile_dir.glob("chart*.chr"))}
    mismatches: list[str] = []
    for name, exp in expected.items():
        got = found.get(name)
        if got is None:
            mismatches.append(f"{name}: missing")
            continue
        if got["sha256"] == exp["sha256"]:
            continue  # byte-identical
        for k_exp, k_got in (("symbol_in_chart", "symbol"), ("expert_path", "expert_path")):
            if str(exp.get(k_exp)) != str(got.get(k_got)):
                mismatches.append(f"{name}: {k_got} {got.get(k_got)!r} != {exp.get(k_exp)!r}")
        if exp["kind"] != "monitor":
            if str(exp["ea_id"]) != str(got["ea_id"]) or str(exp["slot"]) != str(got["slot"]):
                mismatches.append(f"{name}: ea/slot {got['ea_id']}/{got['slot']} != {exp['ea_id']}/{exp['slot']}")
            try:
                if abs(float(got["risk_percent"]) - float(exp["risk_percent"])) > 1e-9:
                    mismatches.append(f"{name}: RISK_PERCENT {got['risk_percent']} != {exp['risk_percent']}")
            except ValueError:
                mismatches.append(f"{name}: RISK_PERCENT unparsable {got['risk_percent']!r}")
            if got["risk_fixed"] not in {"0", "0.0"}:
                mismatches.append(f"{name}: RISK_FIXED={got['risk_fixed']}")
        if got["period_type"] + "/" + got["period_size"] != exp["period"]:
            mismatches.append(f"{name}: period {got['period_type']}/{got['period_size']} != {exp['period']}")
    extra = sorted(set(found) - set(expected))
    if extra:
        mismatches.append(f"unexpected charts: {extra}")
    return {"schema": SCHEMA + ".verify", "profile_dir": str(profile_dir), "manifest": str(manifest_path),
            "charts_expected": len(expected), "charts_found": len(found), "mismatches": mismatches,
            "status": "OK" if not mismatches else "MISMATCH"}


# --------------------------------------------------------------------------- CLI

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--manifest", type=Path, required=True)
    b.add_argument("--staging", type=Path, required=True)
    b.add_argument("--template-profile", type=Path, default=DEFAULT_TEMPLATE_PROFILE)
    b.add_argument("--out-dir", type=Path, default=None, help="default: <staging>/profile")
    b.add_argument("--name", required=True)
    b.add_argument("--repair-delta", type=Path, default=None)
    b.add_argument("--apply", action="store_true")
    b.add_argument("--json", type=Path, default=None)
    v = sub.add_parser("verify")
    v.add_argument("--profile-dir", type=Path, required=True)
    v.add_argument("--manifest", type=Path, required=True)
    args = ap.parse_args(argv)
    if args.cmd == "build":
        manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
        delta = json.loads(args.repair_delta.read_text(encoding="utf-8-sig")) if args.repair_delta else None
        result = build_profile(manifest=manifest, staging=args.staging, template_profile=args.template_profile,
                               out_dir=args.out_dir or (args.staging / "profile"), profile_name=args.name,
                               repair_delta=delta, apply=bool(args.apply))
        summary = {k: v for k, v in result.items() if k != "charts"}
        summary["charts"] = [{k: c.get(k) for k in ("file", "kind", "ea_id", "symbol", "period", "risk_percent", "magic", "template")}
                             for c in result["charts"]]
        print(json.dumps(summary, indent=2, ensure_ascii=False))
        if args.json:
            args.json.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 0 if result["status"] in {"DRY_RUN", "APPLIED"} else 1
    result = verify_profile(args.profile_dir, args.manifest)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result["status"] == "OK" else 1


if __name__ == "__main__":
    raise SystemExit(main())
