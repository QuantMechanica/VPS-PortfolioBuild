"""Derive the 8 R2_capped live trial presets into THIS evidence folder.

Uses tools/strategy_farm/ftmo/trial_setpath.derive() verbatim (the same
transformation the 2026-09-06 install used) but with an explicit venue map,
because trial_setpath.LANES/CANDIDATES are hard-bound to the R0 roster.

Read-only everywhere except docs/ops/evidence/2026-09-18_ftmo_demo_recompose_R2/.
Produces INERT REVIEW-ONLY artifacts. Installs nothing.
"""
from __future__ import annotations
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path

REPO = Path(r"C:\QM\repo")
sys.path.insert(0, str(REPO))
from tools.strategy_farm.ftmo import trial_setpath as tsp  # noqa: E402

OUT = REPO / "docs/ops/evidence/2026-09-18_ftmo_demo_recompose_R2"
SETS = OUT / "sets"
DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
RISK = 0.3125

# venue map for R2_capped; evidence recorded per sleeve in PACKAGE.md
VENUE = {"USDJPY": "USDJPY", "GBPUSD": "GBPUSD", "XAUUSD": "XAUUSD",
         "NDX": "US100.cash", "USDCAD": "USDCAD", "XTIUSD": "USOIL.cash"}

R2 = [(13213, "USDJPY"), (10706, "GBPUSD"), (10700, "XAUUSD"), (11660, "NDX"),
      (11422, "USDCAD"), (10145, "XAUUSD"), (20266, "XTIUSD"), (12710, "XTIUSD")]


def sha(b) -> str:
    return hashlib.sha256(b if isinstance(b, bytes) else Path(b).read_bytes()).hexdigest()


def main() -> None:
    SETS.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB.resolve().as_uri() + "?mode=ro", uri=True)
    candidates = []
    for ea, sym in R2:
        logical = sym + ".DWX"
        row = conn.execute(
            "SELECT id,setfile_path,evidence_path,setfile_sha256 FROM work_items "
            "WHERE ea_id=? AND symbol=? AND phase='Q10_NEWS' AND status='done' "
            "AND verdict='CONFIG_LOCKED' ORDER BY updated_at DESC LIMIT 1",
            ("QM5_%d" % ea, logical)).fetchone()
        if row is None:
            raise SystemExit("unsealed_source:%d:%s" % (ea, sym))
        wid, setp, evp, dbsha = row
        src = Path(setp).resolve()
        seal_bytes = Path(evp).read_bytes()
        seal = json.loads(seal_bytes)
        if seal.get("verdict") != "CONFIG_LOCKED":
            raise SystemExit("seal_not_locked:%d" % ea)
        expected = seal.get("identities", {}).get("baseline_setfile_sha256")
        raw = src.read_bytes()
        if not expected or sha(raw) != expected or (dbsha and dbsha != expected):
            raise SystemExit("sealed_source_hash_drift:%d" % ea)
        tf = re.search(r"_((?:M|H)\d+|D1|W1|MN1)(?:_|\.)", src.name)
        if not tf:
            raise SystemExit("source_timeframe_unresolved:%d" % ea)

        data, proof = tsp.derive(raw, RISK)
        venue = VENUE[sym]
        fname = "QM5_%d_%s_%s_live_trial.set" % (ea, venue, tf.group(1))
        (SETS / fname).write_bytes(data)

        before = tsp.values(tsp.decode(raw))
        after = tsp.values(tsp.decode(data))
        candidates.append({
            "ea_id": ea, "symbol": sym, "factory_symbol": logical,
            "native_symbol": venue, "timeframe": tf.group(1),
            "seal_work_item_id": wid, "source_path": str(src),
            "source_sha256": expected, "seal_path": str(evp),
            "seal_sha256": sha(seal_bytes),
            "source_role": "SEALED_BASELINE_STRATEGY_PARAMETERS",
            "original_selected_news_config": seal.get("chosen_config"),
            "ex5_sha256": seal.get("identities", {}).get("ex5_sha256"),
            "output_path": fname, "output_sha256": sha(data),
            "qm_magic_slot_offset": after.get("qm_magic_slot_offset"),
            "qm_ea_id": after.get("qm_ea_id"),
            **proof,
        })

    manifest = {
        "schema": "qm.ftmo-trial-setpath/v2",
        "status": "INERT_REVIEW_ONLY",
        "installed": False, "installable": False, "mode": "DRY_RUN",
        "ENV": "live", "risk_percent": RISK,
        "risk_authority": "PROPOSED_R2_CAPPED_EQUAL_EIGHT_SLEEVE_ALLOCATION_AWAITING_OWNER",
        "account_variant": "STANDARD_2STEP_100K_FREE_TRIAL",
        "duration_cap_calendar_days": 14,
        "roster_label": "R2_capped",
        "roster_source": ("D:\\QM\\reports\\book_evolution\\2026-W38\\ftmo\\"
                          "fable_alt_rosters_20260918\\roster_definitions.json"),
        "book_risk_percent": 2.5,
        "generator": ("docs/ops/evidence/2026-09-18_ftmo_demo_recompose_R2/"
                      "build_sets.py (trial_setpath.derive, explicit venue map)"),
        "generator_note": ("trial_setpath.generate() could NOT be used: CANDIDATES and "
                           "LANES are hard-bound to the R0_demo8 roster and LANES has no "
                           "USDJPY or NDX entry. derive()/values()/decode() are used "
                           "verbatim; the identity proof is unchanged."),
        "constraints": {
            "max_daily_loss_percent": 5.0, "max_total_loss_percent": 10.0,
            "timezone": "Europe/Prague",
            "news_blackout": "PRE30_POST30_PLUS_FTMO_COMPLIANCE",
            "provider_news_restriction": "STANDARD_ACCOUNT_BINDS",
            "weekend_flat": "FRIDAY_CLOSE_21_BROKER",
            "calendar_binding": ("NATIVE_MT5_CALENDAR_LIVE; seed health and execution "
                                 "must be verified before attachment"),
            "governor_enforcement": ("BOUND_TO_QM5_13206_PRESETS; "
                                     "ATTACHMENT_REQUIRES_OWNER_SIGNATURE"),
        },
        "candidates": candidates,
    }
    (SETS / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    # post-write verification: re-read and re-prove each derivation
    for c in candidates:
        blob = (SETS / c["output_path"]).read_bytes()
        if sha(blob) != c["output_sha256"]:
            raise SystemExit("output_hash_mismatch:%s" % c["output_path"])
        tsp.verify_derivation(tsp.decode(Path(c["source_path"]).read_bytes()),
                              tsp.decode(blob))
        vals = tsp.values(tsp.decode(blob))
        required = {"RISK_FIXED": "0", "RISK_PERCENT": "0.3125",
                    "qm_news_temporal": "3", "qm_news_compliance": "2",
                    "qm_friday_close_enabled": "true",
                    "qm_friday_close_hour_broker": "21"}
        bad = {k: vals.get(k) for k, v in required.items() if vals.get(k) != v}
        if bad:
            raise SystemExit("preset_contract_mismatch:%s:%s" % (c["output_path"], bad))
    print(json.dumps({"sets": len(candidates),
                      "manifest_sha256": sha(SETS / "manifest.json"),
                      "dir": str(SETS)}, indent=2))


if __name__ == "__main__":
    main()
