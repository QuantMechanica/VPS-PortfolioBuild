#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Deterministic identity-equivalence proof for rebuilt QuantMechanica EAs.

Context / Hard Rule
-------------------
A rebuilt ``.ex5`` is a NEW identity and re-enters the pipeline at Q02
("rebuilt EX5 = new identity from Q02"). It never inherits gate *verdict rows*.

Some rebuilds change *nothing behavioural* -- they only replace hard-coded
".DWX" symbol literals by inputs (Hard Rule "symbols are inputs"). OWNER
2026-09-13 ordered a mechanism by which a rebuilt identity whose full-window Q02
replay is *provably behaviour-identical* to its original may inherit the
original's DEPLOYABILITY for the book -- WITHOUT manufacturing any gate verdict
rows for the new identity. Its own Q03..Q10 chain keeps running normally.

This module produces that PROOF ARTIFACT only. It:

* reads farm_state.sqlite **read-only** and never mutates anything;
* never creates a verdict, never touches the pipeline, never starts a terminal;
* compares two Q02 backtest work-items deal-by-deal and records a machine- and
  human-checkable proof.json (+ proof.sha256).

The proof is deal-exact on (time, symbol, type, direction, price, comment).
Volume and PnL are checked *lot-normalised*: RISK_FIXED lot sizing depends on
the symbol's tick value at tester time, which for JPY pairs moves with the
USDJPY quote (Aug vs Sep) -- so an "exact" volume proof is impossible for such
symbols. See the README and ``PROOF_TOLERANCES`` below.

Verdicts
--------
* ``EQUIVALENT_EXACT``            -- everything identical, including volume.
* ``EQUIVALENT_LOT_NORMALISED``  -- only volume/PnL scale differ, within tol.
* ``NOT_EQUIVALENT``             -- listed structural reasons.

CLI
---
    prove  --original <work_item_id> --rebuilt <work_item_id>
           [--out-root D:/QM/reports/identity_equivalence]
    verify --proof <path/to/proof.json>
"""
from __future__ import annotations

import argparse
import datetime as _dt
import gzip
import hashlib
import json
import os
import re
import sqlite3
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# --------------------------------------------------------------------------- #
# Ratified constants (OWNER 2026-09-13). Printed into every proof.            #
# --------------------------------------------------------------------------- #
PROOF_TOLERANCES: Dict[str, float] = {
    # |rebuilt/original - 1| must not exceed this for any deal's volume.
    "volume_ratio_abs_tol": 0.02,
    # max |rebuilt_vol - original_vol| across deals, in lots.
    "volume_max_step_lots": 0.01,
    # per-deal profit/volume equality, relative.
    "pnl_per_lot_rel_tol": 0.005,
    # total net-profit ratio band recorded (informational; not a gate here).
    "net_ratio_abs_tol": 0.05,
}

SCHEMA = "qm.identity-equivalence-proof/v1"
DEFAULT_OUT_ROOT = r"D:/QM/reports/identity_equivalence"
DEFAULT_DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"

VERDICT_EXACT = "EQUIVALENT_EXACT"
VERDICT_LOT = "EQUIVALENT_LOT_NORMALISED"
VERDICT_NOT = "NOT_EQUIVALENT"

# tester.ini keys that are *expected* to differ between original and rebuild.
_INI_EXEMPT = {"expert", "report", "expertparameters"}

# set-file parameter keys that carry the identity binding (expected to differ).
_SETFILE_ID_KEYS = {"qm_ea_id"}

# A hard-coded-symbol parent cannot carry this input: introducing it is the
# required transport change that makes the rebuilt identity venue-portable.
# It is non-economic for an identity canary only when its value names the exact
# tester symbol after removing the framework's ``.DWX`` history suffix.  Keep
# this exception deliberately narrower than the general parameter comparison;
# every other newly added or changed strategy input remains disqualifying.
_SETFILE_TRANSPORT_KEYS = {"strategy_host_symbol"}

_EPS = 1e-9


# --------------------------------------------------------------------------- #
# Byte / hashing helpers                                                       #
# --------------------------------------------------------------------------- #
def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def sha256_file(path: str) -> Optional[str]:
    p = Path(path)
    if not p.exists():
        return None
    return sha256_bytes(p.read_bytes())


def read_bytes_maybe_gz(path: str) -> Tuple[bytes, str]:
    """Return (decompressed_bytes, resolved_path).

    Accepts ``path`` or ``path + '.gz'``. MT5 ``report_sha256`` is computed over
    the *decompressed* .htm bytes, so this returns those.
    """
    p = Path(path)
    if p.exists():
        raw = p.read_bytes()
        if p.suffix == ".gz":
            return gzip.decompress(raw), str(p)
        return raw, str(p)
    gz = Path(str(path) + ".gz")
    if gz.exists():
        return gzip.decompress(gz.read_bytes()), str(gz)
    raise FileNotFoundError(f"neither {path} nor {path}.gz exists")


def decode_report(b: bytes) -> str:
    """Decode MT5 HTML: UTF-16LE/BE BOM, UTF-8 BOM, or plain UTF-8."""
    if b[:2] == b"\xff\xfe" or b[:2] == b"\xfe\xff":
        return b.decode("utf-16")
    if b[:3] == b"\xef\xbb\xbf":
        return b[3:].decode("utf-8", "replace")
    return b.decode("utf-8", "replace")


# --------------------------------------------------------------------------- #
# Parsers                                                                      #
# --------------------------------------------------------------------------- #
_TD_RE = re.compile(r"<td[^>]*>(.*?)</td>", re.S | re.I)
_TR_RE = re.compile(r"<tr[^>]*align\s*=\s*[\"']?right[\"']?[^>]*>(.*?)</tr>", re.S | re.I)
_TAG_RE = re.compile(r"<[^>]+>")

_DEAL_FIELDS = [
    "time", "deal", "symbol", "type", "direction", "volume", "price",
    "order", "commission", "swap", "profit", "balance", "comment",
]


def _clean_cell(s: str) -> str:
    s = _TAG_RE.sub("", s)
    s = s.replace("\u00a0", " ").replace("\u202f", " ")
    return s.strip()


def parse_report_deals(text: str) -> List[Dict[str, str]]:
    """Parse the MT5 report 'Deals' table into a list of ordered dicts.

    Row 1 is normally the ``balance`` (deposit) deal: empty symbol/volume.
    Only rows with exactly 13 cells are accepted; the (center-aligned) header
    row is naturally skipped by the right-aligned <tr> filter.
    """
    idx = text.find("<b>Deals</b>")
    if idx < 0:
        idx = text.find(">Deals<")
    if idx < 0:
        return []
    seg = text[idx:]
    out: List[Dict[str, str]] = []
    for m in _TR_RE.finditer(seg):
        cells = [_clean_cell(c) for c in _TD_RE.findall(m.group(1))]
        if len(cells) != 13:
            continue
        out.append(dict(zip(_DEAL_FIELDS, cells)))
    return out


def parse_num(s: str) -> float:
    if s is None:
        return 0.0
    s = s.replace("\u00a0", "").replace("\u202f", "").replace(" ", "").strip()
    if not s:
        return 0.0
    if "," in s and "." not in s:  # comma decimal locale fallback
        s = s.replace(",", ".")
    else:
        s = s.replace(",", "")
    try:
        return float(s)
    except ValueError:
        return 0.0


def parse_tester_ini(text: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(";") or line.startswith("["):
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def parse_setfile(text: str) -> Dict[str, str]:
    """Return KEY=VALUE parameter body; comment (';') and blank lines dropped."""
    out: Dict[str, str] = {}
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith(";"):
            continue
        if "=" in s:
            k, v = s.split("=", 1)
            out[k.strip()] = v.strip()
    return out


# --------------------------------------------------------------------------- #
# Comparison logic                                                             #
# --------------------------------------------------------------------------- #
def _id_tokens(*labels: str) -> List[str]:
    toks: List[str] = []
    for lab in labels:
        if not lab:
            continue
        toks.append(lab)
        # QM5_41470_usdjpy-... -> also the numeric id and the slug
        m = re.match(r"QM5_(\d+)_?(.*)", lab)
        if m:
            toks.append(m.group(1))
            if m.group(2):
                toks.append(m.group(2))
    # de-dup, longest first so substring stripping is stable
    return sorted({t for t in toks if t}, key=len, reverse=True)


def compare_tester_ini(o: Dict[str, str], n: Dict[str, str]) -> Dict[str, Any]:
    mismatches = []
    keys = set(o) | set(n)
    for k in sorted(keys):
        if k.lower() in _INI_EXEMPT:
            continue
        if o.get(k) != n.get(k):
            mismatches.append({"key": k, "original": o.get(k), "rebuilt": n.get(k)})
    core = {}
    for k in ("Symbol", "Period", "Model", "FromDate", "ToDate"):
        core[k] = {"original": o.get(k), "rebuilt": n.get(k),
                   "match": o.get(k) == n.get(k)}
    return {"core": core, "mismatches": mismatches, "match": not mismatches}


def _is_id_bearing(key: str, val: str, tokens: List[str]) -> bool:
    if key.lower() in _SETFILE_ID_KEYS:
        return True
    hay = f"{key} {val}"
    for t in tokens:
        if len(t) >= 3 and t in hay:
            return True
    return False


def _history_symbol_base(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    normalized = value.strip().upper()
    if normalized.endswith(".DWX"):
        normalized = normalized[:-4]
    return normalized or None


def compare_setfiles(o: Dict[str, str], n: Dict[str, str],
                     tokens: List[str], *,
                     tested_symbol: Optional[str] = None) -> Dict[str, Any]:
    mismatches = []
    ignored = []
    ignored_transport = []
    keys = set(o) | set(n)
    for k in sorted(keys):
        ov, nv = o.get(k), n.get(k)
        if _is_id_bearing(k, ov or nv or "", tokens):
            ignored.append({"key": k, "original": ov, "rebuilt": nv})
            continue
        if (
            k.lower() in _SETFILE_TRANSPORT_KEYS
            and ov is None
            and _history_symbol_base(nv) == _history_symbol_base(tested_symbol)
        ):
            ignored_transport.append({
                "key": k,
                "original": ov,
                "rebuilt": nv,
                "tested_symbol": tested_symbol,
                "reason": "required_symbol_transport_input_matches_tester_symbol",
            })
            continue
        if ov != nv:
            mismatches.append({"key": k, "original": ov, "rebuilt": nv})
    return {
        "mismatches": mismatches,
        "ignored_id_bearing": ignored,
        "ignored_transport_inputs": ignored_transport,
        "match": not mismatches,
    }


def compare_deals(od: List[Dict[str, str]], nd: List[Dict[str, str]]) -> Dict[str, Any]:
    count_match = len(od) == len(nd)
    field_keys = ("time", "symbol", "type", "direction", "price", "comment")
    field_mismatches = []
    n_cmp = min(len(od), len(nd))
    for i in range(n_cmp):
        a, b = od[i], nd[i]
        diff = {k: {"original": a[k], "rebuilt": b[k]}
                for k in field_keys if a[k] != b[k]}
        if diff:
            field_mismatches.append({"index": i, "deal": a.get("deal"), "fields": diff})

    # volume
    ratios: List[float] = []
    max_step = 0.0
    vol_rows = 0
    for i in range(n_cmp):
        ov = parse_num(od[i]["volume"])
        nv = parse_num(nd[i]["volume"])
        if ov > 0 and nv > 0:
            ratios.append(nv / ov)
            max_step = max(max_step, abs(nv - ov))
            vol_rows += 1
    if ratios:
        vmin, vmax = min(ratios), max(ratios)
        vmean = sum(ratios) / len(ratios)
        worst_ratio_dev = max(abs(r - 1.0) for r in ratios)
        sign_consistent = all(r <= 1.0 + _EPS for r in ratios) or \
            all(r >= 1.0 - _EPS for r in ratios)
    else:
        vmin = vmax = vmean = 1.0
        worst_ratio_dev = 0.0
        sign_consistent = True
    vol_exact = max_step <= _EPS
    vol_within_tol = (worst_ratio_dev <= PROOF_TOLERANCES["volume_ratio_abs_tol"]
                      and max_step <= PROOF_TOLERANCES["volume_max_step_lots"] + _EPS
                      and sign_consistent)

    # pnl per lot
    worst_pnl_rel = 0.0
    pnl_rows = 0
    pnl_over = 0
    for i in range(n_cmp):
        ov = parse_num(od[i]["volume"])
        nv = parse_num(nd[i]["volume"])
        op = parse_num(od[i]["profit"])
        np_ = parse_num(nd[i]["profit"])
        if ov <= 0 or nv <= 0:
            continue
        if op == 0 and np_ == 0:
            continue
        oppv = op / ov
        nppv = np_ / nv
        if abs(oppv) < _EPS:
            continue
        rel = abs(nppv - oppv) / abs(oppv)
        worst_pnl_rel = max(worst_pnl_rel, rel)
        pnl_rows += 1
        if rel > PROOF_TOLERANCES["pnl_per_lot_rel_tol"]:
            pnl_over += 1
    pnl_within_tol = worst_pnl_rel <= PROOF_TOLERANCES["pnl_per_lot_rel_tol"]
    pnl_exact = worst_pnl_rel <= _EPS

    # net profit = final balance - deposit (first balance row)
    def net(dd: List[Dict[str, str]]) -> float:
        if not dd:
            return 0.0
        return parse_num(dd[-1]["balance"]) - parse_num(dd[0]["balance"])
    onet, nnet = net(od), net(nd)
    net_ratio = (nnet / onet) if abs(onet) > _EPS else None

    return {
        "count_original": len(od),
        "count_rebuilt": len(nd),
        "count_match": count_match,
        "compared_rows": n_cmp,
        "field_keys_checked": list(field_keys),
        "field_mismatch_count": len(field_mismatches),
        "field_mismatches": field_mismatches[:50],
        "field_mismatches_truncated": len(field_mismatches) > 50,
        "field_match": not field_mismatches and count_match,
        "volume": {
            "rows_compared": vol_rows,
            "ratio_min": vmin, "ratio_max": vmax, "ratio_mean": vmean,
            "worst_ratio_deviation": worst_ratio_dev,
            "max_abs_step_lots": max_step,
            "sign_consistent": sign_consistent,
            "exact": vol_exact,
            "within_tolerance": vol_within_tol,
        },
        "pnl": {
            "rows_compared": pnl_rows,
            "worst_per_lot_rel": worst_pnl_rel,
            "rows_over_tolerance": pnl_over,
            "exact": pnl_exact,
            "within_tolerance": pnl_within_tol,
            "net_original": onet, "net_rebuilt": nnet, "net_ratio": net_ratio,
        },
    }


# --------------------------------------------------------------------------- #
# Side gathering                                                               #
# --------------------------------------------------------------------------- #
def gather_side_from_paths(
    *,
    report_path: str,
    tester_ini_path: str,
    setfile_path: str,
    ea_label: str,
    work_item_id: Optional[str] = None,
    ex5_sha256_compile: Optional[str] = None,
    ex5_sha256_workitem: Optional[str] = None,
    summary_path: Optional[str] = None,
    recorded_report_sha256: Optional[str] = None,
) -> Dict[str, Any]:
    rbytes, rresolved = read_bytes_maybe_gz(report_path)
    report_sha = sha256_bytes(rbytes)
    deals = parse_report_deals(decode_report(rbytes))

    tbytes, tresolved = read_bytes_maybe_gz(tester_ini_path)
    ini = parse_tester_ini(decode_report(tbytes))

    sbytes, sresolved = read_bytes_maybe_gz(setfile_path)
    setf = parse_setfile(decode_report(sbytes))

    return {
        "ea_label": ea_label,
        "work_item_id": work_item_id,
        "report_path": rresolved,
        "report_sha256": report_sha,
        "recorded_report_sha256": recorded_report_sha256,
        "report_sha256_matches_summary": (
            recorded_report_sha256 is None or recorded_report_sha256 == report_sha
        ),
        "tester_ini_path": tresolved,
        "tester_ini_sha256": sha256_bytes(tbytes),
        "setfile_path": sresolved,
        "setfile_sha256": sha256_bytes(sbytes),
        "summary_path": summary_path,
        "summary_sha256": sha256_file(summary_path) if summary_path else None,
        "ex5_sha256_compile": ex5_sha256_compile,
        "ex5_sha256_workitem": ex5_sha256_workitem,
        "_deals": deals,
        "_ini": ini,
        "_setfile": setf,
    }


def _load_json_maybe_gz(path: str) -> Dict[str, Any]:
    p = Path(path)
    if p.exists():
        return json.loads(p.read_text(encoding="utf-8"))
    gz = Path(str(path) + ".gz")
    if gz.exists():
        return json.loads(gzip.decompress(gz.read_bytes()).decode("utf-8"))
    raise FileNotFoundError(path)


def _compile_ex5_sha(conn: sqlite3.Connection, ea_id: str) -> Optional[str]:
    try:
        row = conn.execute(
            "SELECT evidence_path FROM work_items "
            "WHERE ea_id=? AND kind='compile' AND status='done' "
            "ORDER BY updated_at DESC LIMIT 1",
            (ea_id,),
        ).fetchone()
        if not row or not row[0]:
            return None
        ev = _load_json_maybe_gz(row[0])
        return ev.get("ex5_sha256")
    except Exception:
        return None


def gather_side_from_db(conn: sqlite3.Connection, work_item_id: str) -> Dict[str, Any]:
    row = conn.execute(
        "SELECT id, ea_id, symbol, phase, evidence_path, setfile_path, ex5_sha256 "
        "FROM work_items WHERE id=?",
        (work_item_id,),
    ).fetchone()
    if not row:
        raise SystemExit(f"work_item not found: {work_item_id}")
    _id, ea_id, symbol, phase, evidence_path, setfile_path, ex5_wi = row
    summary = _load_json_maybe_gz(evidence_path)
    run0 = summary["runs"][0]
    side = gather_side_from_paths(
        report_path=run0["report_canonical_path"],
        tester_ini_path=run0["tester_ini_path"],
        setfile_path=setfile_path,
        ea_label=ea_id,
        work_item_id=work_item_id,
        ex5_sha256_compile=_compile_ex5_sha(conn, ea_id),
        ex5_sha256_workitem=ex5_wi,
        summary_path=evidence_path if Path(evidence_path).exists()
        else evidence_path + ".gz",
        recorded_report_sha256=run0.get("report_sha256"),
    )
    side["ea_id"] = ea_id
    side["symbol"] = symbol
    side["phase"] = phase
    return side


# --------------------------------------------------------------------------- #
# Proof assembly                                                               #
# --------------------------------------------------------------------------- #
def _decide(ini_r, set_r, deal_r) -> Tuple[str, List[str]]:
    reasons: List[str] = []
    if not ini_r["match"]:
        reasons.append("tester.ini fields differ: "
                       + ", ".join(m["key"] for m in ini_r["mismatches"]))
    if not set_r["match"]:
        reasons.append("set-file parameters differ: "
                       + ", ".join(m["key"] for m in set_r["mismatches"]))
    if not deal_r["count_match"]:
        reasons.append(
            f"deal count differs: original={deal_r['count_original']} "
            f"rebuilt={deal_r['count_rebuilt']}")
    if deal_r["field_mismatch_count"]:
        reasons.append(
            f"{deal_r['field_mismatch_count']} deal(s) differ on "
            "time/symbol/type/direction/price/comment")
    vol = deal_r["volume"]
    pnl = deal_r["pnl"]
    if not vol["within_tolerance"]:
        reasons.append(
            f"volume outside tolerance (worst ratio dev={vol['worst_ratio_deviation']:.4f}, "
            f"max step={vol['max_abs_step_lots']:.4f}, sign_consistent={vol['sign_consistent']})")
    if not pnl["within_tolerance"]:
        reasons.append(
            f"per-lot PnL outside tolerance (worst rel={pnl['worst_per_lot_rel']:.4f})")
    if reasons:
        return VERDICT_NOT, reasons
    if vol["exact"] and pnl["exact"]:
        return VERDICT_EXACT, []
    return VERDICT_LOT, []


def tool_self_sha() -> str:
    try:
        return sha256_bytes(Path(__file__).read_bytes())
    except Exception:
        return "unknown"


def _side_public(side: Dict[str, Any]) -> Dict[str, Any]:
    return {k: v for k, v in side.items() if not k.startswith("_")}


def build_proof(original: Dict[str, Any], rebuilt: Dict[str, Any],
                tool_sha: Optional[str] = None) -> Dict[str, Any]:
    ini_r = compare_tester_ini(original["_ini"], rebuilt["_ini"])
    tokens = _id_tokens(original.get("ea_label", ""), rebuilt.get("ea_label", ""))
    set_r = compare_setfiles(
        original["_setfile"],
        rebuilt["_setfile"],
        tokens,
        tested_symbol=original["_ini"].get("Symbol"),
    )
    deal_r = compare_deals(original["_deals"], rebuilt["_deals"])
    verdict, reasons = _decide(ini_r, set_r, deal_r)

    return {
        "schema": SCHEMA,
        "generated_at": _dt.datetime.now(_dt.timezone.utc).isoformat(),
        "tool_sha256": tool_sha or tool_self_sha(),
        "proof_tolerances": PROOF_TOLERANCES,
        "inputs": {
            "original": _side_public(original),
            "rebuilt": _side_public(rebuilt),
        },
        "checks": {
            "tester_ini": ini_r,
            "setfile": set_r,
            "deals": deal_r,
        },
        "verdict": verdict,
        "not_equivalent_reasons": reasons,
    }


def _canon_bytes(obj: Any) -> bytes:
    return json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False).encode("utf-8")


def write_proof(proof: Dict[str, Any], out_root: str,
                symbol: str) -> Tuple[str, str, str]:
    orig = proof["inputs"]["original"].get("ea_id") \
        or proof["inputs"]["original"].get("ea_label")
    reb = proof["inputs"]["rebuilt"].get("ea_id") \
        or proof["inputs"]["rebuilt"].get("ea_label")
    sym = (symbol or "NA").replace("/", "_")
    outdir = Path(out_root) / f"{orig}__{reb}" / sym
    outdir.mkdir(parents=True, exist_ok=True)
    proof_path = outdir / "proof.json"
    data = _canon_bytes(proof)
    proof_path.write_bytes(data)
    proof_sha = sha256_bytes(data)
    sha_path = outdir / "proof.sha256"
    sha_path.write_text(f"{proof_sha}  proof.json\n", encoding="utf-8")
    return str(proof_path), str(sha_path), proof_sha


# --------------------------------------------------------------------------- #
# verify                                                                       #
# --------------------------------------------------------------------------- #
def verify_proof(proof_path: str) -> Dict[str, Any]:
    p = Path(proof_path)
    proof = json.loads(p.read_text(encoding="utf-8"))
    failures: List[str] = []
    warnings: List[str] = []

    # proof.sha256 sidecar binds proof.json bytes.
    sidecar = p.parent / "proof.sha256"
    file_sha = sha256_bytes(p.read_bytes())
    if sidecar.exists():
        recorded = sidecar.read_text(encoding="utf-8").split()[0]
        if recorded != file_sha:
            failures.append(
                f"proof.sha256 mismatch: sidecar={recorded} actual={file_sha}")
    else:
        warnings.append("proof.sha256 sidecar missing")

    cur_tool = tool_self_sha()
    if proof.get("tool_sha256") != cur_tool:
        warnings.append(
            f"tool sha changed since generation ({proof.get('tool_sha256')} -> {cur_tool})")

    for side_name in ("original", "rebuilt"):
        side = proof["inputs"][side_name]
        rp = side.get("report_path")
        if rp and (Path(rp).exists() or Path(rp + ".gz").exists()):
            rbytes, _ = read_bytes_maybe_gz(rp)
            got = sha256_bytes(rbytes)
            if got != side.get("report_sha256"):
                failures.append(
                    f"{side_name} report sha mismatch: recorded={side.get('report_sha256')} "
                    f"actual={got}")
        else:
            warnings.append(f"{side_name} report file missing: {rp}")

        for label, key in (("tester_ini", "tester_ini_path"),
                            ("setfile", "setfile_path"),
                            ("summary", "summary_path")):
            path = side.get(key)
            sha_key = {"tester_ini": "tester_ini_sha256",
                       "setfile": "setfile_sha256",
                       "summary": "summary_sha256"}[label]
            recorded_sha = side.get(sha_key)
            if not path or recorded_sha is None:
                continue
            if label == "summary":
                # summary sha was recorded over the file bytes as-is (gz not
                # decompressed), matching gather_side_from_paths.
                got = sha256_file(path) or (sha256_file(str(path) + ".gz"))
            elif Path(path).exists() or Path(str(path) + ".gz").exists():
                b, _ = read_bytes_maybe_gz(path)
                got = sha256_bytes(b)
            else:
                warnings.append(f"{side_name} {label} file missing: {path}")
                continue
            if got is None:
                warnings.append(f"{side_name} {label} file missing: {path}")
            elif got != recorded_sha:
                failures.append(
                    f"{side_name} {label} sha mismatch: recorded={recorded_sha} actual={got}")

    return {
        "proof_path": str(p),
        "verdict": proof.get("verdict"),
        "ok": not failures,
        "failures": failures,
        "warnings": warnings,
        "proof_sha256": file_sha,
    }


# --------------------------------------------------------------------------- #
# CLI                                                                          #
# --------------------------------------------------------------------------- #
def cmd_prove(args: argparse.Namespace) -> int:
    conn = sqlite3.connect(args.db, uri=True)
    try:
        original = gather_side_from_db(conn, args.original)
        rebuilt = gather_side_from_db(conn, args.rebuilt)
    finally:
        conn.close()
    proof = build_proof(original, rebuilt)
    symbol = original.get("symbol") or rebuilt.get("symbol") or "NA"
    proof_path, sha_path, proof_sha = write_proof(proof, args.out_root, symbol)
    print(json.dumps({
        "verdict": proof["verdict"],
        "reasons": proof["not_equivalent_reasons"],
        "deals": {
            "original": proof["checks"]["deals"]["count_original"],
            "rebuilt": proof["checks"]["deals"]["count_rebuilt"],
            "field_mismatches": proof["checks"]["deals"]["field_mismatch_count"],
        },
        "volume_ratio": {
            "min": proof["checks"]["deals"]["volume"]["ratio_min"],
            "max": proof["checks"]["deals"]["volume"]["ratio_max"],
            "mean": proof["checks"]["deals"]["volume"]["ratio_mean"],
        },
        "net_ratio": proof["checks"]["deals"]["pnl"]["net_ratio"],
        "proof_path": proof_path,
        "proof_sha256": proof_sha,
        "proof_sha256_file": sha_path,
    }, indent=2))
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    result = verify_proof(args.proof)
    print(json.dumps(result, indent=2))
    return 0 if result["ok"] else 1


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(
        prog="identity_equivalence_proof",
        description="Deterministic identity-equivalence proof for rebuilt EAs.")
    sub = ap.add_subparsers(dest="command", required=True)

    pv = sub.add_parser("prove", help="build a proof from two Q02 work-items")
    pv.add_argument("--original", required=True, help="original work_item id")
    pv.add_argument("--rebuilt", required=True, help="rebuilt work_item id")
    pv.add_argument("--out-root", default=DEFAULT_OUT_ROOT)
    pv.add_argument("--db", default=DEFAULT_DB)
    pv.set_defaults(func=cmd_prove)

    vf = sub.add_parser("verify", help="re-check a proof still binds its inputs")
    vf.add_argument("--proof", required=True, help="path to proof.json")
    vf.set_defaults(func=cmd_verify)
    return ap


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
