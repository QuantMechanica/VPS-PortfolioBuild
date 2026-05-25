"""compile_ea.py — orchestrate EA compilation.

Wraps framework/scripts/compile_one.ps1 with:
  * Idempotent caching (skip if .ex5 newer than .mq5)
  * Structured JSON verdict at D:/QM/reports/compile/<ea_label>/result.json
  * Pre-compile static symbol-scope validation (refuse to stamp COMPILED
    if MULTI_SYMBOL_LEAK_NOT_DECLARED)
  * Verdict gate for Q02 entry: callers check verdict == COMPILED before
    enqueueing backtest work_items.

Verdicts:
  COMPILED               — fresh ex5 with non-zero size, 0 errors
  COMPILED_CACHED        — ex5 already current vs .mq5, no rebuild needed
  COMPILE_FAILED         — compile_one.ps1 exit != 0 or errors > 0
  EX5_MISSING_POST_BUILD — compile_one exited 0 but no ex5 was produced
                           (silent failure path at compile_one.ps1:272-281)
  SYMBOL_SCOPE_LEAK      — validate_symbol_scope returned MULTI_SYMBOL_LEAK_*
  NO_MQ5                 — EA dir exists but has no .mq5
  NO_EA_DIR              — EA label does not exist under framework/EAs/

Usage:
    python compile_ea.py --ea-label QM5_10026_rw-fx-squeeze-mr
    python compile_ea.py --ea-id 10026                       # resolves label
    python compile_ea.py --ea-label <name> --force           # ignore cache
    python compile_ea.py --ea-label <name> --skip-validator  # skip symbol-scope
    python compile_ea.py --all                               # every EA
    python compile_ea.py --all --json                        # machine-readable
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EAS_DIR = REPO_ROOT / "framework" / "EAs"
COMPILE_ONE_PS1 = REPO_ROOT / "framework" / "scripts" / "compile_one.ps1"
REPORT_ROOT = Path("D:/QM/reports/compile")

VALIDATOR = REPO_ROOT / "tools" / "strategy_farm" / "validate_symbol_scope.py"


@dataclass
class CompileResult:
    ea_label: str
    verdict: str
    reason: str = ""
    ex5_path: str = ""
    ex5_size_bytes: int = 0
    ex5_mtime_utc: str = ""
    mq5_mtime_utc: str = ""
    compile_one_exit_code: int | None = None
    compile_one_errors: int | None = None
    compile_one_warnings: int | None = None
    compile_log_path: str = ""
    symbol_scope_verdict: str = ""
    elapsed_seconds: float = 0.0
    timestamp_utc: str = ""
    cached: bool = False


def utc_now_iso() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def file_mtime_iso(p: Path) -> str:
    try:
        return dt.datetime.fromtimestamp(p.stat().st_mtime, dt.UTC).replace(microsecond=0).isoformat()
    except OSError:
        return ""


def find_ea_dir_by_id(ea_id: int) -> Path | None:
    matches = sorted(EAS_DIR.glob(f"QM5_{ea_id}_*"))
    return matches[0] if matches else None


def run_validator(ea_label: str) -> tuple[str, str]:
    """Return (verdict, note). verdict in {SINGLE_SYMBOL_OK, BASKET_OK,
    MULTI_SYMBOL_LEAK_NOT_DECLARED, MULTI_SYMBOL_LEAK_NOT_IN_MANIFEST,
    VALIDATOR_ERROR}."""
    try:
        proc = subprocess.run(
            [sys.executable, str(VALIDATOR), "--ea-label", ea_label, "--json"],
            capture_output=True, text=True, timeout=60,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        if proc.returncode != 0 and not proc.stdout.strip():
            return "VALIDATOR_ERROR", (proc.stderr or "")[:200]
        data = json.loads(proc.stdout)
        if not data:
            return "VALIDATOR_ERROR", "empty result"
        r = data[0]
        return r["verdict"], r.get("note", "")
    except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError) as exc:
        return "VALIDATOR_ERROR", repr(exc)


def parse_compile_one_kv(stdout: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in stdout.splitlines():
        if line.startswith("compile_one."):
            key, _, val = line.partition("=")
            out[key.strip()] = val.strip()
    return out


def write_result(result: CompileResult) -> Path:
    ea_report_dir = REPORT_ROOT / result.ea_label
    ea_report_dir.mkdir(parents=True, exist_ok=True)
    out_path = ea_report_dir / "result.json"
    out_path.write_text(json.dumps(asdict(result), indent=2), encoding="utf-8")
    return out_path


def compile_ea(ea_label: str, force: bool = False, skip_validator: bool = False) -> CompileResult:
    started = dt.datetime.now(dt.UTC)
    ea_dir = EAS_DIR / ea_label
    if not ea_dir.is_dir():
        return CompileResult(ea_label=ea_label, verdict="NO_EA_DIR",
                             reason=f"directory not found: {ea_dir}",
                             timestamp_utc=utc_now_iso())
    mq5 = ea_dir / f"{ea_label}.mq5"
    if not mq5.exists():
        return CompileResult(ea_label=ea_label, verdict="NO_MQ5",
                             reason=f"{mq5.name} not found",
                             timestamp_utc=utc_now_iso())
    ex5 = ea_dir / f"{ea_label}.ex5"
    mq5_mtime = mq5.stat().st_mtime

    # Cache check
    if not force and ex5.exists():
        ex5_stat = ex5.stat()
        if ex5_stat.st_size > 0 and ex5_stat.st_mtime >= mq5_mtime:
            r = CompileResult(
                ea_label=ea_label, verdict="COMPILED_CACHED",
                reason="ex5 is newer than mq5 and non-empty; no rebuild needed",
                ex5_path=str(ex5), ex5_size_bytes=ex5_stat.st_size,
                ex5_mtime_utc=file_mtime_iso(ex5), mq5_mtime_utc=file_mtime_iso(mq5),
                cached=True, timestamp_utc=utc_now_iso(),
                elapsed_seconds=round((dt.datetime.now(dt.UTC) - started).total_seconds(), 2),
            )
            write_result(r)
            return r

    # Pre-compile validator
    if not skip_validator:
        scope_verdict, scope_note = run_validator(ea_label)
        if scope_verdict.startswith("MULTI_SYMBOL_LEAK"):
            r = CompileResult(
                ea_label=ea_label, verdict="SYMBOL_SCOPE_LEAK",
                reason=f"validate_symbol_scope: {scope_verdict} — {scope_note}",
                mq5_mtime_utc=file_mtime_iso(mq5),
                symbol_scope_verdict=scope_verdict,
                timestamp_utc=utc_now_iso(),
                elapsed_seconds=round((dt.datetime.now(dt.UTC) - started).total_seconds(), 2),
            )
            write_result(r)
            return r
    else:
        scope_verdict = "SKIPPED"

    # Invoke compile_one.ps1
    cmd = [
        "pwsh.exe", "-NoProfile", "-File", str(COMPILE_ONE_PS1),
        "-EAPath", str(mq5), "-EALabel", ea_label,
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True,
                               timeout=120, creationflags=creationflags)
    except subprocess.TimeoutExpired:
        r = CompileResult(
            ea_label=ea_label, verdict="COMPILE_FAILED",
            reason="compile_one.ps1 timeout after 120s",
            mq5_mtime_utc=file_mtime_iso(mq5),
            compile_one_exit_code=-1,
            symbol_scope_verdict=scope_verdict,
            timestamp_utc=utc_now_iso(),
            elapsed_seconds=round((dt.datetime.now(dt.UTC) - started).total_seconds(), 2),
        )
        write_result(r)
        return r

    kv = parse_compile_one_kv(proc.stdout)
    errors = int(kv.get("compile_one.errors", "-1") or "-1")
    warnings = int(kv.get("compile_one.warnings", "-1") or "-1")
    log_path = kv.get("compile_one.log", "")
    reason_class = kv.get("compile_one.reason_class", "")

    if proc.returncode != 0 or errors > 0:
        r = CompileResult(
            ea_label=ea_label, verdict="COMPILE_FAILED",
            reason=f"compile_one.ps1 reason_class={reason_class} errors={errors} warnings={warnings}",
            mq5_mtime_utc=file_mtime_iso(mq5),
            compile_one_exit_code=proc.returncode,
            compile_one_errors=errors,
            compile_one_warnings=warnings,
            compile_log_path=log_path,
            symbol_scope_verdict=scope_verdict,
            timestamp_utc=utc_now_iso(),
            elapsed_seconds=round((dt.datetime.now(dt.UTC) - started).total_seconds(), 2),
        )
        write_result(r)
        return r

    # compile_one says success — verify ex5 actually exists
    if not ex5.exists() or ex5.stat().st_size == 0:
        r = CompileResult(
            ea_label=ea_label, verdict="EX5_MISSING_POST_BUILD",
            reason=("compile_one.ps1 returned exit 0 with 0 errors but no .ex5 produced "
                    "(or ex5 is empty) — silent build failure at compile_one.ps1:272-281"),
            mq5_mtime_utc=file_mtime_iso(mq5),
            compile_one_exit_code=proc.returncode,
            compile_one_errors=errors,
            compile_one_warnings=warnings,
            compile_log_path=log_path,
            symbol_scope_verdict=scope_verdict,
            timestamp_utc=utc_now_iso(),
            elapsed_seconds=round((dt.datetime.now(dt.UTC) - started).total_seconds(), 2),
        )
        write_result(r)
        return r

    ex5_stat = ex5.stat()
    r = CompileResult(
        ea_label=ea_label, verdict="COMPILED",
        reason=f"fresh build, {warnings} warnings",
        ex5_path=str(ex5), ex5_size_bytes=ex5_stat.st_size,
        ex5_mtime_utc=file_mtime_iso(ex5), mq5_mtime_utc=file_mtime_iso(mq5),
        compile_one_exit_code=proc.returncode,
        compile_one_errors=errors,
        compile_one_warnings=warnings,
        compile_log_path=log_path,
        symbol_scope_verdict=scope_verdict,
        timestamp_utc=utc_now_iso(),
        elapsed_seconds=round((dt.datetime.now(dt.UTC) - started).total_seconds(), 2),
    )
    write_result(r)
    return r


def compile_all(force: bool, skip_validator: bool) -> list[CompileResult]:
    results: list[CompileResult] = []
    for ea_dir in sorted(EAS_DIR.glob("QM5_*")):
        if not ea_dir.is_dir():
            continue
        results.append(compile_ea(ea_dir.name, force=force, skip_validator=skip_validator))
    return results


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--ea-label", help="e.g. QM5_10026_rw-fx-squeeze-mr")
    g.add_argument("--ea-id", type=int, help="numeric ea_id; label resolved by glob")
    g.add_argument("--all", action="store_true", help="compile every EA under framework/EAs/")
    ap.add_argument("--force", action="store_true", help="ignore ex5/mq5 mtime cache")
    ap.add_argument("--skip-validator", action="store_true",
                    help="skip the validate_symbol_scope pre-check")
    ap.add_argument("--json", action="store_true", help="JSON output to stdout")
    ap.add_argument("--fail-on-error", action="store_true",
                    help="exit 1 if any verdict is not COMPILED or COMPILED_CACHED")
    args = ap.parse_args(argv)

    if args.ea_id is not None:
        ea_dir = find_ea_dir_by_id(args.ea_id)
        if ea_dir is None:
            print(f"no EA dir matching QM5_{args.ea_id}_*", file=sys.stderr)
            return 2
        args.ea_label = ea_dir.name

    if args.all:
        results = compile_all(force=args.force, skip_validator=args.skip_validator)
    else:
        results = [compile_ea(args.ea_label, force=args.force,
                              skip_validator=args.skip_validator)]

    if args.json:
        print(json.dumps([asdict(r) for r in results], indent=2))
    else:
        from collections import Counter
        c = Counter(r.verdict for r in results)
        print(f"=== compile_ea — {len(results)} EAs ===")
        for v, n in sorted(c.items(), key=lambda x: -x[1]):
            print(f"  {v:<28}  {n}")
        print()
        for r in results:
            if r.verdict in ("COMPILED", "COMPILED_CACHED"):
                continue
            print(f"{r.ea_label}")
            print(f"  verdict: {r.verdict}")
            print(f"  reason:  {r.reason}")
            if r.compile_log_path:
                print(f"  log:     {r.compile_log_path}")
            print()

    if args.fail_on_error:
        bad = sum(1 for r in results if r.verdict not in ("COMPILED", "COMPILED_CACHED"))
        if bad:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
