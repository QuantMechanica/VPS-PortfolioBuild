"""Rotate strategy_farm logs safely.

Compresses plain log files older than 30 days under D:/QM/strategy_farm/logs
to .gz and deletes compressed logs older than 90 days. Re-running is safe:
existing .gz files are left in place unless they exceed retention.
"""

from __future__ import annotations

import argparse
import gzip
import os
import shutil
import time
from pathlib import Path


DEFAULT_LOG_DIR = Path(r"D:\QM\strategy_farm\logs")


def rotate_logs(log_dir: Path = DEFAULT_LOG_DIR, compress_days: int = 30,
                delete_gz_days: int = 90) -> dict:
    now = time.time()
    compress_cutoff = now - compress_days * 86400
    delete_cutoff = now - delete_gz_days * 86400
    result = {"compressed": [], "deleted": [], "skipped": []}
    if not log_dir.exists():
        return result

    for path in sorted(log_dir.rglob("*")):
        if not path.is_file():
            continue
        try:
            mtime = path.stat().st_mtime
        except OSError:
            result["skipped"].append(str(path))
            continue

        if path.suffix == ".gz":
            if mtime < delete_cutoff:
                try:
                    path.unlink()
                    result["deleted"].append(str(path))
                except OSError:
                    result["skipped"].append(str(path))
            continue

        if mtime >= compress_cutoff:
            continue
        gz_path = path.with_name(path.name + ".gz")
        if gz_path.exists():
            result["skipped"].append(str(path))
            continue
        try:
            with path.open("rb") as src, gzip.open(gz_path, "wb") as dst:
                shutil.copyfileobj(src, dst)
            os.utime(gz_path, (mtime, mtime))
            path.unlink()
            result["compressed"].append(str(path))
        except OSError:
            result["skipped"].append(str(path))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Rotate strategy_farm logs.")
    parser.add_argument("--log-dir", type=Path, default=DEFAULT_LOG_DIR)
    parser.add_argument("--compress-days", type=int, default=30)
    parser.add_argument("--delete-gz-days", type=int, default=90)
    args = parser.parse_args()
    result = rotate_logs(args.log_dir, args.compress_days, args.delete_gz_days)
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
