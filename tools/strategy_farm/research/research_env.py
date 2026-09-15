"""Research environment: uv venv provisioning + the fail-closed resource guard.

Two responsibilities (design doc sec 2.2, sec 2.3):

1. :func:`provision_venv` creates the uv-managed research venv at
   ``D:/QM/research/venv`` and installs pandas/duckdb/scipy/scikit-learn/
   statsmodels(/pyarrow). This is the ONLY runtime write this whole package
   performs. The farm Python311 (the live MT5 worker runtime, numpy-only) is
   never pip-installed into. If wheels cannot be resolved offline the function
   reports the failure and stops there.

2. :func:`research_guard` is the deterministic pre-batch gate. Research is
   strictly subordinate to MT5 backtests (never throttled). The guard REFUSES to
   start a research job when any of:

   * fleet CPU load > the worker ``cpu_high_pause`` threshold
     (``terminal_worker.CPU_MAX_LOAD_PERCENT``), OR
   * the research output drive has < ``RESEARCH_DISK_MIN_FREE_GB`` (80 GB) free, OR
   * the farm mutation lock shows a *live* owner (a state mutation is in flight).

   It also pins research to below-normal OS priority and caps concurrency at
   ``MAX_WORKER_PROCESSES`` (2). Every refusal carries its machine-readable
   reason; this is the gate, not a judgement call.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

_SF = Path(__file__).resolve().parents[1]
if str(_SF) not in sys.path:
    sys.path.insert(0, str(_SF))

import terminal_worker  # noqa: E402  (safe: conftest + the suite import it too)
import factory_mutation_lock  # noqa: E402


# --- Guard constants ---------------------------------------------------------

# Research output/state drive free-space floor. The task fixes this at 80 GB
# (design doc sec 2.3 D6 gate). It stays well above the DISK_MIN_FREE_GB=40 worker
# floor that already protects backtests, so research yields first.
RESEARCH_DISK_MIN_FREE_GB = 80.0

# At most two research worker processes on <=1-2 cores (design doc sec 2.3).
MAX_WORKER_PROCESSES = 2

# The CPU refuse line is READ from the worker constant, never redefined here, so
# it can never drift from the line the workers themselves pause on.
CPU_HIGH_PAUSE_PERCENT = float(terminal_worker.CPU_MAX_LOAD_PERCENT)

# RAM headroom is a soft companion latch (design doc sec 2.3): a batch should not
# start while free RAM is already at the worker deferral floor.
RAM_MIN_FREE_GB = float(terminal_worker.RAM_MIN_FREE_GB)
RAM_RESUME_FREE_GB = float(terminal_worker.RAM_RESUME_FREE_GB)

DEFAULT_VENV_PATH = Path(r"D:\QM\research\venv")
DEFAULT_RESEARCH_DRIVE = Path("D:/")
RESEARCH_PACKAGES = (
    "pandas",
    "duckdb",
    "scipy",
    "scikit-learn",
    "statsmodels",
    "pyarrow",
)


@dataclass
class GuardResult:
    """Outcome of :func:`research_guard`."""

    allowed: bool
    reasons: list[str] = field(default_factory=list)
    measurements: dict[str, Any] = field(default_factory=dict)
    max_worker_processes: int = MAX_WORKER_PROCESSES

    def as_dict(self) -> dict[str, Any]:
        return {
            "schema": "qm.research-guard/v1",
            "allowed": self.allowed,
            "reasons": list(self.reasons),
            "measurements": dict(self.measurements),
            "max_worker_processes": self.max_worker_processes,
        }


def _default_cpu_percent() -> float:
    return float(terminal_worker._cpu_load_percent())


def _default_free_ram_gb() -> float:
    return float(terminal_worker._free_ram_gb())


def _default_disk_free_gb(root: Path) -> float:
    return float(terminal_worker._disk_free_gb(Path(root)))


def _default_lock_status(lock_path: Path | None) -> str:
    path = lock_path or factory_mutation_lock.DEFAULT_PATH
    snapshot = factory_mutation_lock.inspect_factory_mutation_lock(Path(path))
    return str(snapshot.get("status") or "unknown")


def research_guard(
    *,
    research_drive: Path | str = DEFAULT_RESEARCH_DRIVE,
    mutation_lock_path: Path | str | None = None,
    disk_min_free_gb: float = RESEARCH_DISK_MIN_FREE_GB,
    cpu_high_pause_percent: float = CPU_HIGH_PAUSE_PERCENT,
    ram_min_free_gb: float = RAM_MIN_FREE_GB,
    # Injection seams for tests: pass explicit values / callables to simulate.
    cpu_percent: float | Callable[[], float] | None = None,
    disk_free_gb: float | Callable[[Path], float] | None = None,
    free_ram_gb: float | Callable[[], float] | None = None,
    lock_status: str | None = None,
) -> GuardResult:
    """Return a fail-closed decision on whether a research batch may start."""

    drive = Path(research_drive)

    def _resolve(value, default_call):
        if value is None:
            return default_call()
        if callable(value):
            return value()
        return value

    cpu = float(_resolve(cpu_percent, _default_cpu_percent))
    disk = float(
        disk_free_gb(drive)
        if callable(disk_free_gb)
        else (_default_disk_free_gb(drive) if disk_free_gb is None else disk_free_gb)
    )
    ram = float(_resolve(free_ram_gb, _default_free_ram_gb))
    lock = lock_status if lock_status is not None else _default_lock_status(
        Path(mutation_lock_path) if mutation_lock_path is not None else None
    )

    reasons: list[str] = []
    if cpu > cpu_high_pause_percent:
        reasons.append(
            f"CPU_HIGH:{cpu:.1f}%>{cpu_high_pause_percent:.1f}% (worker cpu_high_pause line)"
        )
    if disk < disk_min_free_gb:
        reasons.append(
            f"DISK_LOW:{disk:.1f}GB<{disk_min_free_gb:.1f}GB free on {drive}"
        )
    if ram < ram_min_free_gb:
        reasons.append(
            f"RAM_LOW:{ram:.1f}GB<{ram_min_free_gb:.1f}GB free"
        )
    if str(lock).lower() == "live":
        reasons.append("MUTATION_LOCK_LIVE: a farm state mutation is in flight")

    return GuardResult(
        allowed=not reasons,
        reasons=reasons,
        measurements={
            "cpu_percent": cpu,
            "disk_free_gb": disk,
            "free_ram_gb": ram,
            "mutation_lock_status": lock,
            "cpu_high_pause_percent": cpu_high_pause_percent,
            "disk_min_free_gb": disk_min_free_gb,
            "ram_min_free_gb": ram_min_free_gb,
        },
    )


def set_below_normal_priority() -> str:
    """Drop this process to below-normal OS priority. Best effort, non-fatal."""

    try:
        if os.name == "nt":
            import ctypes

            below_normal = 0x00004000  # BELOW_NORMAL_PRIORITY_CLASS
            handle = ctypes.windll.kernel32.GetCurrentProcess()
            if ctypes.windll.kernel32.SetPriorityClass(handle, below_normal):
                return "below_normal"
            return "unchanged"
        os.nice(10)  # POSIX
        return "niced"
    except Exception as exc:  # pragma: no cover - platform dependent
        return f"error:{type(exc).__name__}"


def worker_process_cap() -> int:
    """Hard cap on concurrent research worker processes."""

    return MAX_WORKER_PROCESSES


# --- venv provisioning -------------------------------------------------------


def _uv_executable() -> str | None:
    return shutil.which("uv")


def provision_venv(
    venv_path: Path | str = DEFAULT_VENV_PATH,
    *,
    packages: tuple[str, ...] = RESEARCH_PACKAGES,
    offline: bool = False,
    timeout: int = 1800,
) -> dict[str, Any]:
    """Create the uv-managed research venv and install ``packages``.

    Returns a receipt dict. On any failure (uv missing, venv create failure,
    wheels unresolvable) it records the failure and stops — it never falls back
    to pip-installing into the farm Python311.
    """

    venv_path = Path(venv_path)
    receipt: dict[str, Any] = {
        "schema": "qm.research-venv-receipt/v1",
        "venv_path": str(venv_path),
        "requested_packages": list(packages),
        "offline": offline,
        "ok": False,
        "steps": [],
    }

    uv = _uv_executable()
    if uv is None:
        receipt["error"] = "uv executable not found on PATH"
        return receipt
    receipt["uv_path"] = uv

    try:
        version = subprocess.run(
            [uv, "--version"], capture_output=True, text=True, timeout=60, check=False
        )
        receipt["uv_version"] = (version.stdout or version.stderr or "").strip()
    except (OSError, subprocess.SubprocessError) as exc:
        receipt["error"] = f"uv --version failed: {exc}"
        return receipt

    # 1) create the venv
    create_cmd = [uv, "venv", str(venv_path)]
    try:
        created = subprocess.run(
            create_cmd, capture_output=True, text=True, timeout=timeout, check=False
        )
    except (OSError, subprocess.SubprocessError) as exc:
        receipt["error"] = f"uv venv failed to launch: {exc}"
        return receipt
    receipt["steps"].append(
        {
            "cmd": " ".join(create_cmd),
            "returncode": created.returncode,
            "stderr_tail": (created.stderr or "").strip()[-800:],
        }
    )
    if created.returncode != 0:
        receipt["error"] = "uv venv creation failed"
        return receipt

    # 2) install packages into that venv only
    install_cmd = [uv, "pip", "install", "--python", str(venv_path)]
    if offline:
        install_cmd.append("--offline")
    install_cmd.extend(packages)
    try:
        installed = subprocess.run(
            install_cmd, capture_output=True, text=True, timeout=timeout, check=False
        )
    except (OSError, subprocess.SubprocessError) as exc:
        receipt["error"] = f"uv pip install failed to launch: {exc}"
        return receipt
    receipt["steps"].append(
        {
            "cmd": " ".join(install_cmd),
            "returncode": installed.returncode,
            "stderr_tail": (installed.stderr or "").strip()[-1600:],
        }
    )
    if installed.returncode != 0:
        receipt["error"] = (
            "uv pip install failed (wheels may be unresolvable offline) — stopping; "
            "the farm Python311 is left untouched"
        )
        return receipt

    # 3) freeze to hash the resolved set
    freeze_cmd = [uv, "pip", "freeze", "--python", str(venv_path)]
    try:
        frozen = subprocess.run(
            freeze_cmd, capture_output=True, text=True, timeout=300, check=False
        )
        receipt["pip_freeze"] = (frozen.stdout or "").strip()
    except (OSError, subprocess.SubprocessError) as exc:
        receipt["pip_freeze"] = f"freeze failed: {exc}"

    receipt["ok"] = True
    return receipt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    guard = sub.add_parser("guard", help="print the current research guard decision")
    guard.add_argument("--research-drive", type=Path, default=DEFAULT_RESEARCH_DRIVE)

    prov = sub.add_parser("provision-venv", help="create the uv research venv")
    prov.add_argument("--venv-path", type=Path, default=DEFAULT_VENV_PATH)
    prov.add_argument("--offline", action="store_true")

    args = parser.parse_args(argv)
    if args.cmd == "guard":
        result = research_guard(research_drive=args.research_drive)
        print(json.dumps(result.as_dict(), indent=2, sort_keys=True))
        return 0 if result.allowed else 3
    if args.cmd == "provision-venv":
        receipt = provision_venv(args.venv_path, offline=args.offline)
        print(json.dumps(receipt, indent=2, sort_keys=True))
        return 0 if receipt["ok"] else 4
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
