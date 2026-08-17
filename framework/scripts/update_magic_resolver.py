#!/usr/bin/env python3
"""Regenerate framework/include/QM/QM_MagicResolver.mqh from magic_numbers.csv.

WHY THIS EXISTS
---------------
Codex EA builds used to hand-edit the baked static arrays in
QM_MagicResolver.mqh. On 2026-05-16 a QM5_1050 build regenerated the file
and silently dropped the 1047 rows that were already in magic_numbers.csv,
so QM5_1047 smoke failed with EA_MAGIC_NOT_REGISTERED even though the CSV
was correct. The .ex5 had been compiled against an array missing those
rows.

This script is the single canonical regenerator. Reading magic_numbers.csv
is the source of truth; the .mqh is a derived artifact.

INPUTS
- framework/registry/magic_numbers.csv (ea_id, slug, slot, symbol, magic,
  registered_at, owner, status)
- framework/EAs/ (only EAs in QM5_<NNNN>_<slug> dirs OR in active EA dirs are
  kept; entries whose EA dir is under _obsolete_* are skipped unless
  --keep-obsolete is passed; rows with status=retired are also skipped)

OUTPUTS
- framework/include/QM/QM_MagicResolver.mqh — rewritten in-place
  - QM_MAGIC_REG_EA_ID / SLOT / SYMBOL / MAGIC arrays regenerated in strict
    composite-key order (ea_id * 10000 + symbol_slot)
  - QM_MAGIC_REGISTRY_ROWS bumped
  - QM_MAGIC_REGISTRY_SHA256 set to sha256 of the Git-canonical LF bytes

USAGE
    python framework/scripts/update_magic_resolver.py
    python framework/scripts/update_magic_resolver.py --dry-run
    python framework/scripts/update_magic_resolver.py --keep-obsolete
    python framework/scripts/update_magic_resolver.py --allow-dropped

Idempotent: running twice produces identical output. Safe for Codex to call
on every build — no merge logic, no row preservation needed by the caller.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_CSV = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
EA_ID_REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
RESOLVER_MQH = REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
EA_ROOT = REPO_ROOT / "framework" / "EAs"


def registered_ea_ids_by_slug() -> dict[str, int]:
    """Canonical active/reserved ea_id lookup used by named master directories."""
    result: dict[str, int] = {}
    if not EA_ID_REGISTRY.is_file():
        return result
    with EA_ID_REGISTRY.open(encoding="utf-8-sig", newline="") as f:
        for raw in csv.DictReader(f):
            slug = (raw.get("slug") or "").strip()
            ea_id_raw = (raw.get("ea_id") or "").strip()
            status = (raw.get("status") or "").strip().lower()
            if not slug or not ea_id_raw.isdigit() or status == "retired":
                continue
            result[slug] = int(ea_id_raw)
    return result


def active_ea_ids(*, keep_obsolete: bool) -> set[int]:
    """Set of ea_id ints whose dir exists under framework/EAs (not _obsolete_*).

    Normal EAs encode the numeric ID in ``QM5_<id>_<slug>``. Symbol masters use
    the class-style ``QM5_M<symbol>_<slug>`` name required by the consolidation
    plan, so their canonical ID is resolved from ea_id_registry.csv by slug.
    """
    if keep_obsolete:
        return None  # type: ignore[return-value]
    ids: set[int] = set()
    ea_ids_by_slug = registered_ea_ids_by_slug()
    if not EA_ROOT.is_dir():
        return ids
    for entry in EA_ROOT.iterdir():
        if not entry.is_dir():
            continue
        if entry.name.startswith("_obsolete_"):
            continue
        m = re.match(r"^QM5_(\d{4,5})(?:_|$)", entry.name)
        if m:
            ids.add(int(m.group(1)))
            continue
        master = re.match(r"^QM5_M[A-Z0-9]+_(?P<slug>[a-z0-9][a-z0-9-]*[a-z0-9])$", entry.name)
        if master:
            ea_id = ea_ids_by_slug.get(master.group("slug"))
            if ea_id is not None:
                ids.add(ea_id)
    return ids


def row_composite_key(row: dict) -> int:
    """The runtime binary-search key for one generated resolver row."""
    return int(row["ea_id"]) * 10_000 + int(row["slot"])


def validate_row_order(rows: list[dict]) -> None:
    """Require unique rows in strict runtime composite-key order."""
    previous_key: int | None = None
    for index, row in enumerate(rows):
        key = row_composite_key(row)
        if previous_key is not None and key <= previous_key:
            raise ValueError(
                "magic resolver rows must be unique and strictly increasing by "
                f"composite key; index={index} previous={previous_key} current={key}"
            )
        previous_key = key


def load_rows(*, keep_obsolete: bool) -> tuple[list[dict], list[int]]:
    """Return rows sorted by the runtime composite key plus dropped EA IDs.

    dropped_ea_ids: distinct ea_ids whose EA dir is missing under framework/EAs/.
    Only populated when keep_obsolete=False (the normal path).
    """
    if not REGISTRY_CSV.exists():
        sys.exit(f"[FATAL] {REGISTRY_CSV} not found")

    active = active_ea_ids(keep_obsolete=keep_obsolete)
    rows: list[dict] = []
    dropped: set[int] = set()
    with REGISTRY_CSV.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for raw in reader:
            try:
                ea_id = int((raw.get("ea_id") or "").strip())
                slot = int((raw.get("symbol_slot") or raw.get("slot") or "").strip())
                magic = int((raw.get("magic") or "").strip())
            except ValueError:
                continue
            symbol = (raw.get("symbol") or "").strip()
            status = (raw.get("status") or "").strip().lower()
            if not symbol or magic <= 0:
                continue
            if status == "retired":
                continue
            if active is not None and ea_id not in active:
                dropped.add(ea_id)
                continue
            rows.append({
                "ea_id": ea_id,
                "slot": slot,
                "symbol": symbol,
                "magic": magic,
            })

    rows.sort(key=row_composite_key)
    try:
        validate_row_order(rows)
    except ValueError as exc:
        sys.exit(f"[FATAL] {exc}")
    return rows, sorted(dropped)


def csv_sha256_upper() -> str:
    # Git checks this text file out as LF or CRLF depending on worktree config.
    # The resolver is a tracked derived artifact, so its embedded identity must
    # not churn merely because a linked Windows worktree uses autocrlf.
    canonical = REGISTRY_CSV.read_bytes().replace(b"\r\n", b"\n")
    return hashlib.sha256(canonical).hexdigest().upper()


def render_mqh(rows: list[dict]) -> str:
    n = len(rows)
    if n == 0:
        sys.exit("[FATAL] no magic-registry rows survive filtering — refusing to write empty resolver")
    validate_row_order(rows)

    def arr(values: list, fmt: callable) -> str:
        return "{" + ", ".join(fmt(v) for v in values) + "}"

    ea_ids   = arr([r["ea_id"]  for r in rows], lambda v: str(v))
    slots    = arr([r["slot"]   for r in rows], lambda v: str(v))
    symbols  = arr([r["symbol"] for r in rows], lambda v: f"\"{v}\"")
    magics   = arr([r["magic"]  for r in rows], lambda v: str(v))
    sha = csv_sha256_upper()

    return f"""#ifndef QM_MAGIC_RESOLVER_MQH
#define QM_MAGIC_RESOLVER_MQH

// AUTO-GENERATED by framework/scripts/update_magic_resolver.py from
// framework/registry/magic_numbers.csv — do NOT hand-edit. Re-run the
// regenerator after CSV changes (and Codex MUST do so before recompile).

#include "QM_Errors.mqh"

#define QM_MAGIC_EA_ID_MIN 1000
#define QM_MAGIC_EA_ID_MAX 99999
#define QM_MAGIC_SLOT_MIN  0
#define QM_MAGIC_SLOT_MAX  9999

// SHA256 of framework/registry/magic_numbers.csv at regeneration time.
#define QM_MAGIC_REGISTRY_SHA256 "{sha}"

#define QM_MAGIC_REGISTRY_ROWS {n}
static const int    QM_MAGIC_REG_EA_ID[QM_MAGIC_REGISTRY_ROWS]   = {ea_ids};
static const int    QM_MAGIC_REG_SLOT[QM_MAGIC_REGISTRY_ROWS]    = {slots};
static const string QM_MAGIC_REG_SYMBOL[QM_MAGIC_REGISTRY_ROWS]  = {symbols};
static const int    QM_MAGIC_REG_MAGIC[QM_MAGIC_REGISTRY_ROWS]   = {magics};

int QM_Magic(const int ea_id, const int symbol_slot)
  {{
   static int cache_ea_id = -1;
   static int cache_slot  = -1;
   static int cache_magic = -1;
   // Log-bomb guard (2026-06-21, ops f6769583): a misconfigured slot is hit on
   // EVERY tick, so an unguarded PrintFormat writes a 50GB+ tester journal and
   // burns the disk. Warn ONCE per (ea_id,slot) and suppress the per-tick
   // repeat. Paired with the worker journal-size guard in terminal_worker.py.
   static int warn_ea    = -2147483647;
   static int warn_slot  = -2147483647;

   if(ea_id == cache_ea_id && symbol_slot == cache_slot)
     {{
      return cache_magic;
     }}

   const bool warn_new = (ea_id != warn_ea || symbol_slot != warn_slot);

   if(ea_id < QM_MAGIC_EA_ID_MIN || ea_id > QM_MAGIC_EA_ID_MAX)
     {{
      if(warn_new) {{ PrintFormat("%s: invalid ea_id=%d", EA_MAGIC_NOT_REGISTERED, ea_id); warn_ea = ea_id; warn_slot = symbol_slot; }}
      return -1;
     }}

   if(symbol_slot < QM_MAGIC_SLOT_MIN || symbol_slot > QM_MAGIC_SLOT_MAX)
     {{
      if(warn_new) {{ PrintFormat("%s: invalid symbol_slot=%d", EA_MAGIC_NOT_REGISTERED, symbol_slot); warn_ea = ea_id; warn_slot = symbol_slot; }}
      return -1;
     }}

   const long magic64 = (long)ea_id * 10000L + (long)symbol_slot;
   if(magic64 <= 0 || magic64 > 2147483647L)
     {{
      if(warn_new) {{ PrintFormat("%s: magic out of range ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot); warn_ea = ea_id; warn_slot = symbol_slot; }}
      return -1;
     }}

   const int magic = (int)magic64;
   if(magic == 0)
     {{
      if(warn_new) {{ PrintFormat("%s: computed magic is zero ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot); warn_ea = ea_id; warn_slot = symbol_slot; }}
      return -1;
     }}

   cache_ea_id = ea_id;
   cache_slot  = symbol_slot;
   cache_magic = magic;
   return magic;
  }}

// Rows are generated in strict order by ea_id * 10000 + symbol_slot. Search
// the existing parallel arrays directly: no runtime allocation and O(log n).
int QM_MagicRegistryFindIndex(const int ea_id, const int symbol_slot)
  {{
   const long target_key = (long)ea_id * 10000L + (long)symbol_slot;
   int low = 0;
   int high = QM_MAGIC_REGISTRY_ROWS - 1;

   while(low <= high)
     {{
      const int middle = low + (high - low) / 2;
      const long middle_key = (long)QM_MAGIC_REG_EA_ID[middle] * 10000L
                              + (long)QM_MAGIC_REG_SLOT[middle];
      if(middle_key == target_key)
        {{
         return middle;
        }}
      if(middle_key < target_key)
        {{
         low = middle + 1;
        }}
      else
        {{
         high = middle - 1;
        }}
     }}

   return -1;
  }}

bool QM_MagicRegistered(const int ea_id, const int symbol_slot)
  {{
   const int computed_magic = QM_Magic(ea_id, symbol_slot);
   if(computed_magic <= 0)
     {{
      return false;
     }}

   const int registry_index = QM_MagicRegistryFindIndex(ea_id, symbol_slot);
   return (registry_index >= 0 && QM_MAGIC_REG_MAGIC[registry_index] == computed_magic);
  }}

// R-069/18954866: the registry symbol bound to (ea_id, symbol_slot). "" if the
// pair is not registered. Callers use this to fail closed when the caller's
// actual _Symbol disagrees with what the slot is registered for, instead of
// silently trading under a foreign symbol's magic (host-slot conflation).
string QM_MagicRegisteredSymbol(const int ea_id, const int symbol_slot)
  {{
   const int registry_index = QM_MagicRegistryFindIndex(ea_id, symbol_slot);
   return (registry_index >= 0 ? QM_MAGIC_REG_SYMBOL[registry_index] : "");
  }}

string QM_MagicRegistryHash()
  {{
   return QM_MAGIC_REGISTRY_SHA256;
  }}

bool QM_MagicCollisionWithForeignOpenPositions(const int magic, const string expected_symbol = "")
  {{
   if(magic <= 0)
     {{
      return true;
     }}

   const ulong restore_ticket = (ulong)PositionGetInteger(POSITION_TICKET);

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {{
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
        {{
         continue;
        }}

      const long position_magic = PositionGetInteger(POSITION_MAGIC);
      if((int)position_magic != magic)
        {{
         continue;
        }}

      const string position_symbol = PositionGetString(POSITION_SYMBOL);
      if(expected_symbol != "" && position_symbol == expected_symbol)
        {{
         continue;
        }}

      PrintFormat("%s: magic=%d conflicts with ticket=%I64u symbol=%s expected_symbol=%s",
                  EA_MAGIC_COLLISION_DETECTED,
                  magic,
                  ticket,
                  position_symbol,
                  expected_symbol);
      if(restore_ticket > 0)
         PositionSelectByTicket(restore_ticket);
      return true;
     }}

   if(restore_ticket > 0)
      PositionSelectByTicket(restore_ticket);
   return false;
  }}

int QM_MagicChecked(const int ea_id, const int symbol_slot, const string expected_symbol = "")
  {{
   // Log-bomb guard: dedupe the per-tick "not registered"/"resolution failed" warnings (see QM_Magic).
   static int chk_warn_ea   = -2147483647;
   static int chk_warn_slot = -2147483647;
   const int magic = QM_Magic(ea_id, symbol_slot);
   if(magic <= 0)
     {{
      return -1;
     }}

   // One indexed lookup serves both the registration and symbol checks.
   const int registry_index = QM_MagicRegistryFindIndex(ea_id, symbol_slot);
   if(registry_index < 0 || QM_MAGIC_REG_MAGIC[registry_index] != magic)
     {{
      if(ea_id != chk_warn_ea || symbol_slot != chk_warn_slot)
        {{
         PrintFormat("%s: ea_id=%d slot=%d magic=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot, magic);
         chk_warn_ea = ea_id; chk_warn_slot = symbol_slot;
        }}
      return -1;
     }}

   // R-069/18954866 host-slot magic conflation fix: the registry maps
   // (ea_id, symbol_slot) to a specific symbol. If the caller's actual symbol
   // disagrees, this slot belongs to a DIFFERENT symbol's assignment and must
   // fail closed rather than silently hand back that foreign symbol's magic.
   if(expected_symbol != "")
     {{
      const string registered_symbol = QM_MAGIC_REG_SYMBOL[registry_index];
      if(registered_symbol != "" && registered_symbol != expected_symbol)
        {{
         if(ea_id != chk_warn_ea || symbol_slot != chk_warn_slot)
           {{
            PrintFormat("%s: ea_id=%d slot=%d registered_symbol=%s expected_symbol=%s magic=%d",
                        EA_MAGIC_RESOLUTION_FAILED, ea_id, symbol_slot, registered_symbol, expected_symbol, magic);
            chk_warn_ea = ea_id; chk_warn_slot = symbol_slot;
           }}
         return -1;
        }}
     }}

   if(QM_MagicCollisionWithForeignOpenPositions(magic, expected_symbol))
     {{
      return -1;
     }}

   return magic;
  }}

#endif // QM_MAGIC_RESOLVER_MQH
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="print result, do not write")
    ap.add_argument("--keep-obsolete", action="store_true",
                    help="include rows whose EA dir is under _obsolete_* (default: skip)")
    ap.add_argument(
        "--allow-dropped",
        action="store_true",
        help=(
            "OWNER/recovery escape hatch: allow active registry rows to be omitted "
            "when their EA directory is missing (default: fail closed before writing)"
        ),
    )
    # Kept as a compatibility no-op for existing automation. Strict behaviour is
    # now the default; callers must opt out explicitly with --allow-dropped.
    ap.add_argument("--strict", action="store_true", help=argparse.SUPPRESS)
    args = ap.parse_args()

    rows, dropped = load_rows(keep_obsolete=args.keep_obsolete)

    if dropped:
        print(
            f"\n[WARNING] {len(dropped)} ea_id(s) in magic_numbers.csv dropped from resolver "
            f"because their EA dir is missing under {EA_ROOT}:",
            file=sys.stderr,
        )
        for ea_id in dropped:
            print(f"  ea_id={ea_id}  (expected: {EA_ROOT}/QM5_{ea_id}_*)", file=sys.stderr)
        print(
            "[WARNING] Run update_magic_resolver.py from the canonical checkout "
            "(C:/QM/repo) where framework/EAs/ is fully materialised, "
            "or investigate whether the EA dir was deleted without retiring the magic.\n",
            file=sys.stderr,
        )

    strict = not args.allow_dropped
    if dropped and strict:
        sys.stderr.write(
            f"[strict-default] {len(dropped)} active ea_id(s) would be dropped; "
            "refusing to generate or replace QM_MagicResolver.mqh. "
            "Use --allow-dropped only for an explicitly reviewed recovery.\n"
        )
        return 2

    content = render_mqh(rows)

    if args.dry_run:
        sys.stdout.write(content)
        sys.stderr.write(f"\n[dry-run] {len(rows)} rows kept, {len(dropped)} dropped, "
                         f"sha={csv_sha256_upper()[:16]}...\n")
        return 0

    RESOLVER_MQH.write_text(content, encoding="utf-8", newline="\n")
    print(f"[OK] wrote {RESOLVER_MQH.relative_to(REPO_ROOT)} — "
          f"{len(rows)} rows kept, {len(dropped)} dropped, sha={csv_sha256_upper()[:16]}...")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
