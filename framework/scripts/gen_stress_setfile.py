"""Generate Q05 MEDIUM / Q06 HARSH stress setfile variants from a baseline.

Per 2026-05-23 pipeline rewrite (Vault: Q05 Stress MEDIUM, Q06 Stress HARSH).

Stress dimensions:
- Slippage: tester option (set in the .ini, not the .set) — passed to runner
- Spread multiplier: tester option (set in the .ini) — passed to runner
- Commission multiplier: framework/registry/tester_defaults.json baseline * multiplier
- Trade-rejection probability: EA input qm_stress_reject_probability — IN the .set file

This script handles the .set-file side: takes a baseline backtest .set and
emits a stress-level variant with the rejection-probability input set and
the header annotated. The companion tester .ini generator (for slip/spread)
lives elsewhere (q05/q06 runner — TODO under the gate code rewrite).

Usage:
    python gen_stress_setfile.py BASELINE.set --level MED  --out OUT.set
    python gen_stress_setfile.py BASELINE.set --level HARSH --out OUT.set
    python gen_stress_setfile.py BASELINE.set --level MED  --in-place  # rewrite alongside baseline

Stress level → rejection probability:
    OFF    : 0.00  (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 — baseline)
    MED    : 0.00  (Q05 — slip/spread/commission stressed via tester only)
    HARSH  : 0.10  (Q06 — slip/spread/commission stressed via tester + 10% rejection)
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path

LEVEL_REJECT_PROB = {
    "OFF":   0.00,
    "MED":   0.00,
    "HARSH": 0.10,
}

LEVEL_LABEL = {
    "OFF":   "q00_off_baseline",
    "MED":   "q05_stress_medium",
    "HARSH": "q06_stress_harsh",
}

REJECT_KEY = "qm_stress_reject_probability"
ENV_HEADER_RE = re.compile(r"^(;\s*environment:\s*)(\w+)", re.IGNORECASE)
SET_VERSION_RE = re.compile(r"^(;\s*set_version:\s*)(\S+)", re.IGNORECASE)
DATE_HEADER_RE = re.compile(r"^(;\s*date:\s*)(\S+)", re.IGNORECASE)


def stress_setfile_text(baseline_text: str, level: str) -> str:
    if level not in LEVEL_REJECT_PROB:
        raise ValueError(f"unknown level {level}; expected one of {list(LEVEL_REJECT_PROB)}")
    reject_prob = LEVEL_REJECT_PROB[level]
    today = dt.date.today().isoformat()

    out_lines: list[str] = []
    env_rewritten = False
    set_version_rewritten = False
    date_rewritten = False
    reject_key_seen = False

    for raw in baseline_text.splitlines():
        line = raw

        m = ENV_HEADER_RE.match(line)
        if m and not env_rewritten:
            line = f"{m.group(1)}{LEVEL_LABEL[level]}"
            env_rewritten = True

        m = SET_VERSION_RE.match(line)
        if m and not set_version_rewritten:
            line = f"{m.group(1)}s{dt.date.today().strftime('%Y%m%d')}-stress-{level.lower()}"
            set_version_rewritten = True

        m = DATE_HEADER_RE.match(line)
        if m and not date_rewritten:
            line = f"{m.group(1)}{today}"
            date_rewritten = True

        if line.strip().startswith(f"{REJECT_KEY}="):
            line = f"{REJECT_KEY}={reject_prob:.4f}"
            reject_key_seen = True

        out_lines.append(line)

    # If the baseline didn't have qm_stress_reject_probability= (old setfiles
    # before FW2), append it right after the framework block. Find the line
    # after PORTFOLIO_WEIGHT= and inject there.
    if not reject_key_seen:
        injected: list[str] = []
        injected_done = False
        for line in out_lines:
            injected.append(line)
            if (not injected_done) and line.strip().startswith("PORTFOLIO_WEIGHT="):
                injected.append(f"{REJECT_KEY}={reject_prob:.4f}")
                injected_done = True
        if not injected_done:
            # Fallback: just append at end
            injected.append(f"{REJECT_KEY}={reject_prob:.4f}")
        out_lines = injected

    return "\n".join(out_lines) + ("\n" if not out_lines[-1].endswith("\n") else "")


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate Q05/Q06 stress setfile variants")
    ap.add_argument("baseline", type=Path, help="baseline backtest .set file")
    ap.add_argument("--level", choices=list(LEVEL_REJECT_PROB), required=True,
                    help="stress level")
    ap.add_argument("--out", type=Path, help="output path (default: alongside baseline)")
    ap.add_argument("--in-place", action="store_true",
                    help="write variant next to baseline with suffix `_qNNlevel`")
    args = ap.parse_args()

    if not args.baseline.exists():
        print(f"baseline not found: {args.baseline}", file=sys.stderr)
        return 2

    src = args.baseline.read_text(encoding="utf-8", errors="replace")
    stressed = stress_setfile_text(src, args.level)

    if args.out:
        out_path = args.out
    elif args.in_place:
        stem = args.baseline.stem
        # Strip a trailing `_backtest` if present; we'll re-tag.
        if stem.endswith("_backtest"):
            stem = stem[: -len("_backtest")]
        tag = LEVEL_LABEL[args.level]
        out_path = args.baseline.with_name(f"{stem}_{tag}.set")
    else:
        print("must specify --out or --in-place", file=sys.stderr)
        return 2

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(stressed, encoding="utf-8")
    print(f"wrote {out_path}  (level={args.level}, reject_prob={LEVEL_REJECT_PROB[args.level]:.4f})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
