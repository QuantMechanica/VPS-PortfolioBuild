"""Reproduce the code tests and diagnostic evidence without terminal/farm writes."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

CODE = Path("C:/QM/worktrees/codex")
EVIDENCE = Path(__file__).resolve().parent


def main():
    commands = [
        [sys.executable, "-m", "pytest", "tools/strategy_farm/tests/test_pattern_fire_count.py", "-q"],
        [sys.executable, "tools/strategy_farm/research/verify_pattern_fire_count.py", "--output-dir",
         str(EVIDENCE / "2026-09-04_pattern_fire_count_data")],
        [sys.executable, str(EVIDENCE / "2026-09-04_pattern_fire_count_bar_probe.py")],
    ]
    runs = []
    for cmd in commands:
        run = subprocess.run(cmd, cwd=CODE, text=True, capture_output=True, check=False)
        runs.append({"argv": cmd, "returncode": run.returncode, "stdout": run.stdout, "stderr": run.stderr})
    files = ["tools/strategy_farm/research/pattern_fire_count.py",
             "tools/strategy_farm/research/verify_pattern_fire_count.py",
             "tools/strategy_farm/tests/test_pattern_fire_count.py"]
    result = {"code_checkout": str(CODE), "code_hashes": {p: hashlib.sha256((CODE / p).read_bytes()).hexdigest() for p in files},
              "runs": runs, "expected_returncodes": [0, 2, 0],
              "explanation": "Harness exit 2 is mandatory non-acceptance, despite matching measured cells: raw tick/tester parity is unverified."}
    EVIDENCE.joinpath("2026-09-04_pattern_fire_count_validation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"returncodes": [r["returncode"] for r in runs], "test_stdout": runs[0]["stdout"]}, indent=2))
    return 0 if [r["returncode"] for r in runs] == [0, 2, 0] else 1


if __name__ == "__main__":
    raise SystemExit(main())
