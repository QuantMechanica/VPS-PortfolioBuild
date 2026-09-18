"""Governed rebind of the QM5_13206 FTMO account-governor allow-list (GAPS G3/B2).

Three artifacts have to move together or the set-derivation path breaks:

1. ``..._ACCOUNT_TIMER_M13_demo_active.set``   (allowed_magics_csv, governed_ea_ids_csv,
2. ``..._ACCOUNT_TIMER_M13_demo_bootstrap.set``  governed_symbols_csv, challenge_id,
                                                 challenge_start_utc)
3. ``tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json`` ->
   ``governor.active_preset_sha256`` / ``bootstrap_preset_sha256``

``trial_setpath.load_binding()`` re-checks both the pinned shas AND every policy value
inside the presets, so this rewrites ONLY the roster-derived keys, re-pins both shas in
the same commit-or-rollback step, and then re-runs ``load_binding()`` as the acceptance
proof. Any failure restores all three files to their original bytes.

Refusals (fail-closed):
  roster_magic_collision        two roster rows claim the same magic
  magic_not_in_registry         a roster magic has no active framework/registry row
  registry_symbol_mismatch      the registry row's symbol is not the roster's dxz_symbol
  governor_key_missing          a preset does not carry a key we are asked to rebind
  rebind_binding_incoherent     load_binding() refuses after the write (rolled back)

This tool never attaches a chart, never toggles AutoTrading, and never writes the
terminal. governed_symbols_csv semantics (coverage gate vs display filter) remain an
OWNER open item — this tool only keeps it symmetric with allowed_magics_csv.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import sys

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.strategy_farm.ftmo import trial_setpath

REPO_ROOT = Path(__file__).resolve().parents[3]
BINDING = REPO_ROOT / "tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json"
MAGIC_REGISTRY = REPO_ROOT / "framework/registry/magic_numbers.csv"
RECEIPT_SCHEMA = "qm.ftmo-governor-rebind/v1"
REBOUND_KEYS = ("allowed_magics_csv", "governed_ea_ids_csv", "governed_symbols_csv")


class Refusal(RuntimeError):
    pass


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_magic_registry(path: Path = MAGIC_REGISTRY) -> dict[int, dict[str, str]]:
    """magic -> row, active rows only."""
    rows: dict[int, dict[str, str]] = {}
    with Path(path).open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            if (row.get("status") or "").strip() != "active":
                continue
            try:
                magic = int(row["magic"])
            except (KeyError, TypeError, ValueError):
                continue
            rows[magic] = row
    return rows


def roster_csvs(roster: dict, registry: dict[int, dict[str, str]]) -> dict[str, str]:
    """Derive the three governed CSVs from a roster, verified against the registry."""
    magics: set[int] = set()
    ea_ids: set[int] = set()
    symbols: set[str] = set()
    for row in roster["candidates"]:
        magic = int(row["magic"])
        if magic in magics:
            raise Refusal(f"roster_magic_collision:{magic}")
        registry_row = registry.get(magic)
        if registry_row is None:
            raise Refusal(f"magic_not_in_registry:{magic}")
        if int(registry_row["ea_id"]) != int(row["ea_id"]) or int(registry_row["symbol_slot"]) != int(row["slot"]):
            raise Refusal(f"magic_not_in_registry:{magic}")
        expected_symbol = f"{row['dxz_symbol']}{trial_setpath.FACTORY_SUFFIX}"
        if (registry_row.get("symbol") or "").strip() != expected_symbol:
            raise Refusal(f"registry_symbol_mismatch:{magic}:{registry_row.get('symbol')}!={expected_symbol}")
        magics.add(magic)
        ea_ids.add(int(row["ea_id"]))
        symbols.add(str(row["ftmo_symbol"]))
    return {
        "allowed_magics_csv": ",".join(str(m) for m in sorted(magics)),
        "governed_ea_ids_csv": ",".join(str(e) for e in sorted(ea_ids)),
        "governed_symbols_csv": ",".join(sorted(symbols)),
    }


def rewrite_preset(raw: bytes, updates: dict[str, str]) -> bytes:
    """Replace only the named keys, preserving every other byte (incl. CRLF)."""
    text = raw.decode("utf-8")
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(newline)
    seen: set[str] = set()
    out = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or "=" not in stripped:
            out.append(line)
            continue
        key = stripped.split("=", 1)[0].strip()
        if key in updates:
            out.append(f"{key}={updates[key]}")
            seen.add(key)
        else:
            out.append(line)
    missing = sorted(set(updates) - seen)
    if missing:
        raise Refusal(f"governor_key_missing:{','.join(missing)}")
    return newline.join(out).encode("utf-8")


def rebind(roster_path: Path, *, binding_path: Path = BINDING,
           registry_path: Path = MAGIC_REGISTRY, challenge_id: str | None = None,
           challenge_start_utc: str | None = None, apply: bool = False,
           receipt_path: Path | None = None, verify=trial_setpath.load_binding) -> dict:
    roster = trial_setpath.load_roster(roster_path)
    registry = load_magic_registry(registry_path)
    csvs = roster_csvs(roster, registry)
    updates = dict(csvs)
    if challenge_id is not None:
        updates["challenge_id"] = challenge_id
    if challenge_start_utc is not None:
        updates["challenge_start_utc"] = challenge_start_utc

    binding_raw = Path(binding_path).read_bytes()
    binding = json.loads(binding_raw.decode("utf-8"))
    governor = binding.get("governor") or {}
    if governor.get("ea_id") != 13206:
        raise Refusal("wrong_governor_binding")

    presets: dict[str, dict] = {}
    for role in ("bootstrap", "active"):
        path = (REPO_ROOT / governor[f"{role}_preset_path"]).resolve()
        if not path.is_file():
            raise Refusal(f"governor_preset_missing:{role}")
        raw = path.read_bytes()
        if sha(raw) != governor[f"{role}_preset_sha256"]:
            raise Refusal(f"{role}_preset_hash_drift_before_rebind")
        new_raw = rewrite_preset(raw, updates)
        presets[role] = {"path": path, "before": raw, "after": new_raw,
                         "sha256_before": sha(raw), "sha256_after": sha(new_raw)}

    new_binding = json.loads(binding_raw.decode("utf-8"))
    for role in ("bootstrap", "active"):
        new_binding["governor"][f"{role}_preset_sha256"] = presets[role]["sha256_after"]
    new_binding_raw = (json.dumps(new_binding, indent=2, ensure_ascii=False) + "\n").encode("utf-8")

    result = {
        "schema": RECEIPT_SCHEMA,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "applied": False,
        "roster_path": str(Path(roster_path).resolve()),
        "roster_sha256": sha(Path(roster_path).read_bytes()),
        "roster_label": roster.get("label"),
        "sleeve_count": len(roster["candidates"]),
        "updates": updates,
        "magic_registry": {"path": str(Path(registry_path).resolve()),
                           "sha256": sha(Path(registry_path).read_bytes())},
        "presets": {role: {"path": str(item["path"]),
                           "sha256_before": item["sha256_before"],
                           "sha256_after": item["sha256_after"]}
                    for role, item in presets.items()},
        "binding": {"path": str(Path(binding_path).resolve()),
                    "sha256_before": sha(binding_raw),
                    "sha256_after": sha(new_binding_raw)},
        "autotrading_changed": False, "charts_changed": False, "terminal_written": False,
    }
    if not apply:
        return result

    written: list[tuple[Path, bytes]] = []
    try:
        for role in ("bootstrap", "active"):
            _atomic_write(presets[role]["path"], presets[role]["after"])
            written.append((presets[role]["path"], presets[role]["before"]))
        _atomic_write(Path(binding_path), new_binding_raw)
        written.append((Path(binding_path), binding_raw))
        verify(Path(binding_path))
    except Exception as exc:  # rollback: all three or none
        for path, original in reversed(written):
            _atomic_write(path, original)
        raise Refusal(f"rebind_binding_incoherent:{type(exc).__name__}:{exc}") from exc
    result["applied"] = True
    if receipt_path is not None:
        receipt_path = Path(receipt_path)
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        receipt_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        result["receipt_path"] = str(receipt_path)
    return result


def _atomic_write(path: Path, data: bytes) -> None:
    tmp = path.with_name(path.name + f".rebind-{os.getpid()}.tmp")
    tmp.write_bytes(data)
    os.replace(tmp, path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--roster", required=True)
    parser.add_argument("--binding", default=str(BINDING))
    parser.add_argument("--challenge-id")
    parser.add_argument("--challenge-start-utc", help="broker-time stamp, e.g. '2026.09.18 06:17:00'")
    parser.add_argument("--receipt", help="where to write the rebind receipt (with --apply)")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--apply", action="store_true")
    group.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    result = rebind(
        Path(args.roster), binding_path=Path(args.binding),
        challenge_id=args.challenge_id, challenge_start_utc=args.challenge_start_utc,
        apply=args.apply, receipt_path=Path(args.receipt) if args.receipt else None,
    )
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
