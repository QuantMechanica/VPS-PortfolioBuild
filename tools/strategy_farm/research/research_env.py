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
   * the *research scratch volume* (the volume that actually hosts research
     scratch/dataset/cache output) has < ``RESEARCH_DISK_MIN_FREE_GB`` (20 GB)
     free, OR
   * research scratch lives on the factory drive (D:) AND D: free has fallen
     below the tester-cache purge low-water (``TESTER_PURGE_LOW_WATER_GB``,
     60 GB, read from the shared config so it can never drift from the purge),
     so research yields to a disk-pressured factory, OR
   * the scratch volume's free space cannot be measured (unknown/unavailable
     volume -> fail closed), OR
   * the farm mutation lock shows a *live* owner (a state mutation is in flight).

   It also pins research to below-normal OS priority and caps concurrency at
   ``MAX_WORKER_PROCESSES`` (2). Every refusal carries its machine-readable
   reason; this is the gate, not a judgement call.

   **Why the guard was recalibrated (OWNER master directive 2026-09-15 §34,
   OWNER-DEC-CBE-20260915; audit ``research_disk_guard.md``).** The original flat
   ``D: < 80 GB`` floor permanently disabled research: the tester-cache purge
   deliberately parks D: at its 60 GB low-water, so 80 > 60 meant the floor was
   above the disk's own steady-state operating band and the live guard returned
   ``DISK_LOW:61.2GB<80.0GB`` on every call. The 80 GB number was not
   evidence-based -- research's measured D: footprint is ~0.3 GB (the venv,
   already provisioned) and its dataset output writes to C:
   (``observe_projector.DEFAULT_OUT_ROOT = C:\\QM\\repo\\artifacts\\research_datasets``,
   small few-MB CSVs). So the guard now watches the volume research actually
   uses with a measured floor (``max(measured need ~0.3 GB x 2, 20 GB safety
   margin)`` = 20 GB), and only imposes the 60 GB factory-yield floor when
   scratch is on D:. The layering invariant is preserved:
   ``worker_disk_floor (40) <= purge_low_water (60) <= research floor on D:``.

   Configuration (OWNER/ops-tunable without a code change):

   * ``QM_RESEARCH_SCRATCH`` -- research scratch root (default the current
     dataset output location on C:); the guard watches its volume.
   * ``QM_RESEARCH_MIN_FREE_GB`` -- scratch-volume free floor (default 20).
   * ``QM_FACTORY_MIN_FREE_GB`` -- factory-drive (D:) yield floor (default the
     shared ``tester_cache_purge_low_water_gb`` = 60).
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

# Shared factory disk-space policy: the tester-cache purge low-water lives in one
# place (config/factory_disk_policy.v1.json) so research_env and the purge can
# never disagree on the number.
_CONFIG_DIR = _SF / "config"
_FACTORY_DISK_POLICY_PATH = _CONFIG_DIR / "factory_disk_policy.v1.json"

# Fallback if the shared config is missing/unreadable (matches the committed
# config and the live scheduled task -LowWaterGB value).
_FALLBACK_TESTER_PURGE_LOW_WATER_GB = 60.0


def _load_factory_disk_policy() -> dict[str, Any]:
    try:
        return json.loads(_FACTORY_DISK_POLICY_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _tester_purge_low_water_gb() -> float:
    """The factory-drive free-space floor the tester-cache purge parks D: at.

    Single source of truth (config/factory_disk_policy.v1.json); never hardcoded
    a second time next to the purge. Env ``QM_FACTORY_MIN_FREE_GB`` overrides.
    """
    override = os.environ.get(ENV_FACTORY_MIN_FREE_GB)
    if override is not None:
        try:
            return float(override)
        except (TypeError, ValueError):
            pass
    policy = _load_factory_disk_policy()
    value = policy.get("tester_cache_purge_low_water_gb")
    try:
        return float(value)
    except (TypeError, ValueError):
        return _FALLBACK_TESTER_PURGE_LOW_WATER_GB


# Research scratch-volume free-space floor (GB). Recalibrated from a measured
# need (~0.3 GB venv, small CSV dataset output) to max(need x2, 20 GB margin) =
# 20 GB. This is NOT a gate threshold or contract criterion; it is an
# infrastructure yield latch (OWNER directive 2026-09-15 §34).
RESEARCH_DISK_MIN_FREE_GB = 20.0

# Canonical factory drive whose purge low-water research must yield to.
FACTORY_DRIVE = Path("D:/")

# Environment overrides (OWNER/ops-tunable without a code change).
ENV_RESEARCH_SCRATCH = "QM_RESEARCH_SCRATCH"
ENV_RESEARCH_MIN_FREE_GB = "QM_RESEARCH_MIN_FREE_GB"
ENV_FACTORY_MIN_FREE_GB = "QM_FACTORY_MIN_FREE_GB"

# Default research scratch root = where research output actually lands today
# (observe_projector.DEFAULT_OUT_ROOT, on C:); the guard watches this volume.
# Defined as a literal to avoid importing the heavier projector module here.
DEFAULT_RESEARCH_SCRATCH = Path(r"C:\QM\repo\artifacts\research_datasets")

# At most two research worker processes on <=1-2 cores (design doc sec 2.3).
MAX_WORKER_PROCESSES = 2

# The CPU refuse line is READ from the worker constant, never redefined here, so
# it can never drift from the line the workers themselves pause on.
CPU_HIGH_PAUSE_PERCENT = float(terminal_worker.CPU_MAX_LOAD_PERCENT)

# RAM headroom is a soft companion latch (design doc sec 2.3): a batch should not
# start while free RAM is already at the worker deferral floor.
RAM_MIN_FREE_GB = float(terminal_worker.RAM_MIN_FREE_GB)
RAM_RESUME_FREE_GB = float(terminal_worker.RAM_RESUME_FREE_GB)

# The venv is NOT relocated here (OWNER/orchestrator decides relocation). It
# stays a ~0.3 GB one-time footprint; the guard yields for it via the D:
# factory-protection floor only when scratch is placed on D:.
DEFAULT_VENV_PATH = Path(r"D:\QM\research\venv")
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


def _measure_free_gb(root: Path) -> float | None:
    """Free space (GB) on the volume hosting *root*, or None if unmeasurable.

    Deliberately fail-CLOSED (None on any error), unlike
    ``terminal_worker._disk_free_gb`` which fails open for the worker's
    crash-prevention contract. Research is subordinate: an unknown/unavailable
    volume must refuse, never proceed on a guessed 'infinite' free space.
    """
    try:
        anchor = os.path.splitdrive(str(root))[0] or str(root)
        usage = shutil.disk_usage(anchor)
        return float(usage.free) / (1024 ** 3)
    except Exception:
        return None


def _drive_key(path: Path | str) -> str:
    """Upper-cased drive component (e.g. 'D:') or '' when there is none."""
    return os.path.splitdrive(str(path))[0].upper()


def _on_factory_drive(scratch: Path | str, factory_drive: Path | str) -> bool:
    scratch_key = _drive_key(scratch)
    factory_key = _drive_key(factory_drive)
    return bool(scratch_key) and scratch_key == factory_key


def _default_lock_status(lock_path: Path | None) -> str:
    path = lock_path or factory_mutation_lock.DEFAULT_PATH
    snapshot = factory_mutation_lock.inspect_factory_mutation_lock(Path(path))
    return str(snapshot.get("status") or "unknown")


def _resolve_scratch_root(research_scratch: Path | str | None) -> Path:
    if research_scratch is not None:
        return Path(research_scratch)
    env_value = os.environ.get(ENV_RESEARCH_SCRATCH)
    return Path(env_value) if env_value else DEFAULT_RESEARCH_SCRATCH


def _resolve_scratch_min_free_gb(explicit: float | None) -> float:
    if explicit is not None:
        return float(explicit)
    override = os.environ.get(ENV_RESEARCH_MIN_FREE_GB)
    if override is not None:
        try:
            return float(override)
        except (TypeError, ValueError):
            pass
    return RESEARCH_DISK_MIN_FREE_GB


def research_guard(
    *,
    research_scratch: Path | str | None = None,
    factory_drive: Path | str = FACTORY_DRIVE,
    mutation_lock_path: Path | str | None = None,
    scratch_min_free_gb: float | None = None,
    factory_min_free_gb: float | None = None,
    cpu_high_pause_percent: float = CPU_HIGH_PAUSE_PERCENT,
    ram_min_free_gb: float = RAM_MIN_FREE_GB,
    # Injection seams for tests: pass explicit values / callables to simulate.
    cpu_percent: float | Callable[[], float] | None = None,
    # Free GB on the scratch volume (float | callable(Path)->float|None | None).
    disk_free_gb: float | Callable[[Path], float | None] | None = None,
    # Free GB on the factory drive; defaults to the scratch measurement when the
    # scratch volume IS the factory drive.
    factory_free_gb: float | Callable[[Path], float | None] | None = None,
    free_ram_gb: float | Callable[[], float] | None = None,
    lock_status: str | None = None,
) -> GuardResult:
    """Return a fail-closed decision on whether a research batch may start.

    The guard watches the volume that actually hosts research scratch (default
    the C: dataset-output location) with a measured floor
    (``scratch_min_free_gb``, default 20 GB). It additionally requires the
    factory drive (D:) to stay above the tester-cache purge low-water
    (``factory_min_free_gb``, default 60 GB read from the shared config) ONLY
    when scratch is placed on the factory drive, so research yields to a
    disk-pressured factory without being permanently disabled. See the module
    docstring for the evidence behind the recalibration (directive §34).
    """

    scratch = _resolve_scratch_root(research_scratch)
    scratch_floor = _resolve_scratch_min_free_gb(scratch_min_free_gb)
    factory_floor = (
        float(factory_min_free_gb)
        if factory_min_free_gb is not None
        else _tester_purge_low_water_gb()
    )

    def _resolve(value, default_call):
        if value is None:
            return default_call()
        if callable(value):
            return value()
        return value

    def _measure(seam, path: Path) -> float | None:
        if seam is None:
            return _measure_free_gb(path)
        if callable(seam):
            return seam(path)
        return float(seam)

    cpu = float(_resolve(cpu_percent, _default_cpu_percent))
    scratch_free = _measure(disk_free_gb, scratch)
    ram = float(_resolve(free_ram_gb, _default_free_ram_gb))
    lock = lock_status if lock_status is not None else _default_lock_status(
        Path(mutation_lock_path) if mutation_lock_path is not None else None
    )

    on_factory = _on_factory_drive(scratch, factory_drive)

    reasons: list[str] = []
    if cpu > cpu_high_pause_percent:
        reasons.append(
            f"CPU_HIGH:{cpu:.1f}%>{cpu_high_pause_percent:.1f}% (worker cpu_high_pause line)"
        )

    # Scratch-volume floor (fail closed on an unmeasurable/unknown volume).
    if scratch_free is None:
        reasons.append(
            f"DISK_UNMEASURED: cannot measure free space on scratch volume {scratch}"
        )
    elif scratch_free < scratch_floor:
        reasons.append(
            f"DISK_LOW:{scratch_free:.1f}GB<{scratch_floor:.1f}GB free on scratch volume {scratch}"
        )

    # Factory-protection floor: only when scratch lives on the factory drive.
    factory_free: float | None = None
    if on_factory:
        # Same volume: reuse the scratch measurement unless a seam overrides it.
        if factory_free_gb is None and disk_free_gb is not None:
            factory_free = scratch_free
        else:
            factory_free = _measure(factory_free_gb, Path(factory_drive))
        if factory_free is None:
            reasons.append(
                f"FACTORY_DISK_UNMEASURED: cannot measure free space on factory drive {factory_drive}"
            )
        elif factory_free < factory_floor:
            reasons.append(
                f"FACTORY_DISK_LOW:{factory_free:.1f}GB<{factory_floor:.1f}GB free on "
                f"factory drive {factory_drive} (tester-cache purge low-water)"
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
            "scratch_root": str(scratch),
            "scratch_free_gb": scratch_free,
            "scratch_on_factory_drive": on_factory,
            "factory_free_gb": factory_free,
            "free_ram_gb": ram,
            "mutation_lock_status": lock,
            "cpu_high_pause_percent": cpu_high_pause_percent,
            "scratch_min_free_gb": scratch_floor,
            "factory_min_free_gb": factory_floor,
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
    guard.add_argument(
        "--research-scratch",
        type=Path,
        default=None,
        help="research scratch root whose volume is guarded (default env "
        "QM_RESEARCH_SCRATCH or the C: dataset-output location)",
    )
    guard.add_argument(
        "--factory-drive", type=Path, default=FACTORY_DRIVE,
        help="factory drive whose purge low-water research yields to (default D:/)",
    )

    prov = sub.add_parser("provision-venv", help="create the uv research venv")
    prov.add_argument("--venv-path", type=Path, default=DEFAULT_VENV_PATH)
    prov.add_argument("--offline", action="store_true")

    args = parser.parse_args(argv)
    if args.cmd == "guard":
        result = research_guard(
            research_scratch=args.research_scratch, factory_drive=args.factory_drive
        )
        print(json.dumps(result.as_dict(), indent=2, sort_keys=True))
        return 0 if result.allowed else 3
    if args.cmd == "provision-venv":
        receipt = provision_venv(args.venv_path, offline=args.offline)
        print(json.dumps(receipt, indent=2, sort_keys=True))
        return 0 if receipt["ok"] else 4
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
