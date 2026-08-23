"""Deploy the OWNER-approved (option (a), 2026-08-23) preset provenance repair to T_Live.

Fail-closed: every source must match the manifest sha256, every target must still carry the
expected pre-deploy sha256, each target is backed up before it is overwritten, and every copy is
re-hashed.  Presets are only read by MT5 when an EA is (re)attached; running sleeves are not
touched and AutoTrading is never changed.  Run from C:/QM/repo:

    python tools/strategy_farm/deploy_tlive_preset_repair.py --apply

(without --apply it is a dry-run).  Afterwards:

    python tools/strategy_farm/verify_tlive_preset_repair.py --manifest \
        docs/ops/evidence/2026-08-23_tlive_preset_repair_manifest.json --require-deployed
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import time

MANIFEST = "docs/ops/evidence/2026-08-23_tlive_preset_repair_manifest.json"
RECEIPT = "docs/ops/evidence/2026-08-23_tlive_preset_repair_deploy_receipt.json"
BACKUP_ROOT = "D:/QM/strategy_farm/backups"


def sha256(path: str) -> str:
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--manifest", default=MANIFEST)
    args = ap.parse_args()
    with open(args.manifest, encoding="utf-8") as fh:
        manifest = json.load(fh)
    plan = []
    for item in manifest["presets"]:
        src, tgt = item["source_path"], item["target_tlive_path"]
        if item.get("regeneration_status") != "REGENERABLE":
            print(f"SKIP {item['ea_label']}: {item.get('regeneration_status')}")
            continue
        s_sha, t_sha = sha256(src), sha256(tgt)
        if s_sha != item["source_sha256"]:
            print(f"REFUSE {item['ea_label']}: source drift {s_sha[:12]} != {item['source_sha256'][:12]}")
            return 2
        if t_sha != item["expected_pre_deploy_sha256"]:
            print(f"REFUSE {item['ea_label']}: target drift {t_sha[:12]} != {item['expected_pre_deploy_sha256'][:12]}")
            return 2
        plan.append((item["ea_label"], src, tgt, s_sha))
    print(f"preflight OK: {len(plan)} presets")
    if not args.apply:
        for label, src, tgt, _ in plan:
            print(f"  would copy {src} -> {tgt}")
        print("dry-run only; re-run with --apply")
        return 0
    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    backup_dir = os.path.join(BACKUP_ROOT, f"tlive_presets_pre_repair_{ts}")
    os.makedirs(backup_dir, exist_ok=True)
    receipt = {"deployed_at_utc": ts, "backup_dir": backup_dir, "manifest": args.manifest, "presets": []}
    for label, src, tgt, s_sha in plan:
        bak = os.path.join(backup_dir, os.path.basename(tgt))
        shutil.copy2(tgt, bak)
        shutil.copyfile(src, tgt)
        post = sha256(tgt)
        if post != s_sha:
            print(f"FAIL {label}: post-copy sha {post[:12]} != {s_sha[:12]}; restoring backup")
            shutil.copyfile(bak, tgt)
            return 3
        receipt["presets"].append({"ea_label": label, "target": tgt, "sha256": post, "backup": bak})
        print(f"DEPLOYED {label} -> {tgt} sha={post[:12]}")
    with open(RECEIPT, "w", encoding="utf-8") as fh:
        json.dump(receipt, fh, indent=1)
    print(f"receipt: {RECEIPT}; backup: {backup_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
