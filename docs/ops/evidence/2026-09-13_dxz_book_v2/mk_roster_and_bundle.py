#!/usr/bin/env python3
"""Build roster_v2.json (+ variant) and the builder stream root (pool bundle UNION incumbent bundle).

Writes only under D:/QM/reports/portfolio/dxz_v2_20260913/. READ-ONLY everywhere else.
"""
from __future__ import annotations
import csv, datetime as dt, hashlib, json, shutil, sys
from pathlib import Path

sys.path.insert(0, r"C:\QM\repo")
from tools.strategy_farm.portfolio.book_builder_common import load_magic_registry, resolve_setfile

REPO = Path(r"C:\QM\repo")
BASE = Path(r"D:\QM\reports\portfolio\dxz_v2_20260913")
POOL_BUNDLE = BASE / "streams" / "QM" / "q08_trades"
INC_BUNDLE = Path(r"D:\QM\reports\portfolio\dxz_final_20260719\QM\q08_trades")
INC_MANIFEST = Path(r"D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json")

pool = json.loads((BASE / "pool.json").read_text(encoding="utf-8"))["pairs"]
bundle = json.loads((BASE / "streams" / "bundle_manifest.json").read_text(encoding="utf-8"))
bound = {}
for r in bundle["results"]:
    if r.get("outcome") == "bound":
        bound[(int(str(r["ea_id"]).replace("QM5_", "")), r["symbol"])] = r
inc = json.loads(INC_MANIFEST.read_text(encoding="utf-8"))
inc_keys = [(int(s["ea_id"]), s["symbol"]) for s in inc["sleeves"]]
inc_by_key = {(int(s["ea_id"]), s["symbol"]): s for s in inc["sleeves"]}

magics = load_magic_registry(REPO / "framework" / "registry" / "magic_numbers.csv")


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def fname(key):
    return f"{key[0]}_{key[1].replace('.', '_')}.jsonl"


def mk_stream_root(name: str, roster_keys: list[tuple[int, str]], extra_src: dict) -> Path:
    """Copy the roster streams + every incumbent stream into <BASE>/<name>/QM/q08_trades."""
    dest = BASE / name / "QM" / "q08_trades"
    dest.mkdir(parents=True, exist_ok=True)
    prov = []
    for key in sorted(set(roster_keys) | set(inc_keys)):
        n = fname(key)
        if key in roster_keys and key in extra_src:
            src = extra_src[key]
            tag = "INCUMBENT_SEALED_BUNDLE_20260719_NOT_CURRENT_IDENTITY"
        elif (POOL_BUNDLE / n).is_file():
            src = POOL_BUNDLE / n
            tag = "Q14_IDENTITY_SEALED_Q08_STREAM"
        elif (INC_BUNDLE / n).is_file():
            src = INC_BUNDLE / n
            tag = "INCUMBENT_SEALED_BUNDLE_20260719"
        else:
            raise SystemExit(f"no stream for {key}")
        shutil.copyfile(src, dest / n)
        prov.append({
            "ea_id": key[0], "symbol": key[1], "file": n,
            "source": str(src), "source_sha256": sha256_file(src),
            "provenance": tag,
            "in_roster": key in roster_keys, "in_incumbent": key in inc_keys,
        })
    (BASE / name / "stream_provenance.json").write_text(
        json.dumps({"schema": "qm.dxz_v2_stream_provenance/v1", "root": str(BASE / name),
                    "generated_utc": dt.datetime.now(dt.UTC).isoformat(),
                    "streams": prov}, indent=2) + "\n", encoding="utf-8")
    return BASE / name


def roster_rows(keys):
    rows = []
    for key in sorted(keys):
        ea, sym = key
        p = next(p for p in pool
                 if int(str(p["ea_id"]).replace("QM5_", "")) == ea and p["symbol"] == sym)
        setfile, risk_fixed, risk_percent = resolve_setfile(REPO, key)
        ea_dir = setfile.parent.parent.name
        magic = magics[key]
        live = inc_by_key.get(key)
        rows.append({
            "ea_id": ea,
            "ea_label": ea_dir,
            "symbol": sym,
            "magic_number": magic,
            "magic_slot": magic - ea * 10000,
            "magic_slot_status": "REGISTERED_ACTIVE",
            "proposed_slot": None if live else magic - ea * 10000,
            "already_live": bool(live),
            "live_magic_number": (live or {}).get("magic_number"),
            "live_deployed_preset": (live or {}).get("deployed_preset"),
            "live_risk_percent": (live or {}).get("risk_percent"),
            "q14_terminal_verdict": p["terminal_verdict"],
            "q14_work_item_id": p["terminal_work_item_id"],
            "q14_evidence_path": p["terminal_evidence_path"],
            "backtest_setfile": str(setfile.relative_to(REPO)).replace("\\", "/"),
            "backtest_risk_fixed": risk_fixed,
            "backtest_risk_percent": risk_percent,
            "stream_file": fname(key),
        })
    return rows


A_KEYS = sorted(bound)
B_EXTRA = {(10403, "XAUUSD.DWX"): INC_BUNDLE / "10403_XAUUSD_DWX.jsonl",
           (10513, "XAUUSD.DWX"): INC_BUNDLE / "10513_XAUUSD_DWX.jsonl"}
B_KEYS = sorted(set(A_KEYS) | set(B_EXTRA))

for name, keys, extra, label in (
    ("streams_build_A", A_KEYS, {}, "roster_v2.json"),
    ("streams_build_B", B_KEYS, B_EXTRA, "roster_v2_variantB.json"),
):
    root = mk_stream_root(name, keys, extra)
    doc = {
        "schema": "qm.dual-book-roster-input/v1-manifest-compatible",
        "book": "DXZ_4000090541",
        "lane": "Q11_DXZ",
        "as_of": "2026-09-12",
        "status": "PROPOSAL_DRY_RUN",
        "generated_utc": dt.datetime.now(dt.UTC).isoformat(),
        "order_artifact": "decisions/2026-09-13_owner_book_order_dxz.md",
        "pool_source": str(BASE / "pool.json"),
        "stream_root": str(root),
        "n_sleeves": len(keys),
        "sleeves": roster_rows(keys),
    }
    (BASE / label).write_text(json.dumps(doc, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{label}: {len(keys)} sleeves; stream root {root}")
