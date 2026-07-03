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
  - QM_MAGIC_REG_EA_ID / SLOT / SYMBOL / MAGIC arrays regenerated
  - QM_MAGIC_REGISTRY_ROWS bumped
  - QM_MAGIC_REGISTRY_SHA256 set to sha256(magic_numbers.csv bytes)

USAGE
    python framework/scripts/update_magic_resolver.py
    python framework/scripts/update_magic_resolver.py --dry-run
    python framework/scripts/update_magic_resolver.py --keep-obsolete

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
RESOLVER_MQH = REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
EA_ROOT = REPO_ROOT / "framework" / "EAs"


def active_ea_ids(*, keep_obsolete: bool) -> set[int]:
    """Set of ea_id ints whose dir exists under framework/EAs (not _obsolete_*)."""
    if keep_obsolete:
        return None  # type: ignore[return-value]
    ids: set[int] = set()
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
    return ids


def load_rows(*, keep_obsolete: bool) -> tuple[list[dict], list[dict]]:
    """Return (kept_rows, dropped_rows) from magic_numbers.csv, sorted by (ea_id, slot).

    dropped_rows are CSV entries whose EA directory is missing (not under framework/EAs)
    and therefore filtered out.  In --strict mode the caller prints them as loud warnings
    and exits nonzero so the race condition (build A appends CSV after build B wiped
    resolver) is immediately visible instead of silently shrinking the registry.
    """
    if not REGISTRY_CSV.exists():
        sys.exit(f"[FATAL] {REGISTRY_CSV} not found")

    active = active_ea_ids(keep_obsolete=keep_obsolete)
    rows: list[dict] = []
    dropped: list[dict] = []
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
            row = {"ea_id": ea_id, "slot": slot, "symbol": symbol, "magic": magic}
            if active is not None and ea_id not in active:
                slug = (raw.get("ea_slug") or raw.get("slug") or "").strip()
                dropped.append({**row, "slug": slug, "reason": "ea_dir_missing"})
                continue
            rows.append(row)

    rows.sort(key=lambda r: (r["ea_id"], r["slot"]))
    return rows, dropped


def csv_sha256_upper() -> str:
    return hashlib.sha256(REGISTRY_CSV.read_bytes()).hexdigest().upper()


def render_mqh(rows: list[dict]) -> str:
    n = len(rows)
    if n == 0:
        sys.exit("[FATAL] no magic-registry rows survive filtering — refusing to write empty resolver")

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

   if(ea_id == cache_ea_id && symbol_slot == cache_slot)
     {{
      return cache_magic;
     }}

   if(ea_id < QM_MAGIC_EA_ID_MIN || ea_id > QM_MAGIC_EA_ID_MAX)
     {{
      PrintFormat("%s: invalid ea_id=%d", EA_MAGIC_NOT_REGISTERED, ea_id);
      return -1;
     }}

   if(symbol_slot < QM_MAGIC_SLOT_MIN || symbol_slot > QM_MAGIC_SLOT_MAX)
     {{
      PrintFormat("%s: invalid symbol_slot=%d", EA_MAGIC_NOT_REGISTERED, symbol_slot);
      return -1;
     }}

   const long magic64 = (long)ea_id * 10000L + (long)symbol_slot;
   if(magic64 <= 0 || magic64 > 2147483647L)
     {{
      PrintFormat("%s: magic out of range ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot);
      return -1;
     }}

   const int magic = (int)magic64;
   if(magic == 0)
     {{
      PrintFormat("%s: computed magic is zero ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot);
      return -1;
     }}

   cache_ea_id = ea_id;
   cache_slot  = symbol_slot;
   cache_magic = magic;
   return magic;
  }}

bool QM_MagicRegistered(const int ea_id, const int symbol_slot)
  {{
   const int computed_magic = QM_Magic(ea_id, symbol_slot);
   if(computed_magic <= 0)
     {{
      return false;
     }}

   for(int i = 0; i < QM_MAGIC_REGISTRY_ROWS; ++i)
     {{
      if(QM_MAGIC_REG_EA_ID[i] == ea_id && QM_MAGIC_REG_SLOT[i] == symbol_slot)
        {{
         return (QM_MAGIC_REG_MAGIC[i] == computed_magic);
        }}
     }}

   return false;
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
      return true;
     }}

   return false;
  }}

int QM_MagicChecked(const int ea_id, const int symbol_slot, const string expected_symbol = "")
  {{
   const int magic = QM_Magic(ea_id, symbol_slot);
   if(magic <= 0)
     {{
      return -1;
     }}

   if(!QM_MagicRegistered(ea_id, symbol_slot))
     {{
      PrintFormat("%s: ea_id=%d slot=%d magic=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot, magic);
      return -1;
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
    ap.add_argument("--strict", action="store_true",
                    help="exit nonzero and print a loud WARNING if any rows are dropped "
                         "due to missing EA directories (detects resolver race conditions)")
    args = ap.parse_args()

    rows, dropped = load_rows(keep_obsolete=args.keep_obsolete)

    if dropped:
        print(
            f"\n{'='*72}\n"
            f"WARNING: {len(dropped)} magic-registry row(s) DROPPED — EA directory missing.\n"
            f"This can indicate a build-race (EA built but dir not yet committed) or an\n"
            f"orphaned registry entry.  Review and either commit the EA dir or retire the row.\n"
            f"{'='*72}",
            file=sys.stderr,
        )
        for d in dropped:
            print(
                f"  DROPPED ea_id={d['ea_id']} slot={d['slot']} symbol={d['symbol']} "
                f"magic={d['magic']} slug={d['slug']!r} reason={d['reason']}",
                file=sys.stderr,
            )
        print(f"{'='*72}\n", file=sys.stderr)

    content = render_mqh(rows)

    if args.dry_run:
        sys.stdout.write(content)
        sys.stderr.write(f"\n[dry-run] {len(rows)} kept, {len(dropped)} dropped, sha={csv_sha256_upper()[:16]}...\n")
        if args.strict and dropped:
            return 1
        return 0

    RESOLVER_MQH.write_text(content, encoding="utf-8", newline="\n")
    print(
        f"[OK] wrote {RESOLVER_MQH.relative_to(REPO_ROOT)} — "
        f"{len(rows)} rows kept, {len(dropped)} dropped, sha={csv_sha256_upper()[:16]}..."
    )

    if args.strict and dropped:
        print(f"[STRICT] exiting nonzero: {len(dropped)} row(s) dropped.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
