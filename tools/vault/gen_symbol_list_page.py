#!/usr/bin/env python3
"""Deterministic generator for the vault page '06 Infrastructure/Symbol List'.

The canonical source of truth for the tradable `.DWX` symbol universe is
`framework/registry/dwx_symbol_matrix.csv`. The vault page used to be
hand-maintained and drifted (36 vs 37 symbols, missing SP500) unnoticed for
3.5 months. This script derives the whole symbol inventory from the matrix CSV
so the page can never silently diverge again.

Determinism contract: the same CSV bytes produce a byte-identical page. There
are NO wall-clock timestamps in the output — provenance is a sha256 of the CSV
bytes embedded in a GENERATED marker. A pytest (test_gen_symbol_list_page.py)
regenerates the page and asserts it matches the committed vault file, so a
matrix change fails the test until the page is regenerated.

Usage (run with cwd = C:\\QM\\repo, plain `python`):

    python tools/vault/gen_symbol_list_page.py --check   # non-zero if drifted
    python tools/vault/gen_symbol_list_page.py --write    # rewrite vault page
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import sys
from pathlib import Path

# --- Paths ---------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]
MATRIX_CSV = REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"
SCRIPT_REL = "tools/vault/gen_symbol_list_page.py"
MATRIX_REL = "framework/registry/dwx_symbol_matrix.csv"

VAULT_PAGE = Path(
    r"G:\My Drive\QuantMechanica - Company Reference"
    r"\06 Infrastructure\Symbol List.md"
)

# --- Static, code-pinned annotation (deterministic; NOT wall-clock) -------

# Human-readable display names for non-forex symbols. Pinned in code so the
# rendering stays deterministic; a new symbol without an entry still renders
# (just without a parenthetical), and the drift test catches the addition.
DISPLAY_NAME = {
    "GDAXI.DWX": "DAX",
    "NDX.DWX": "Nasdaq 100",
    "SP500.DWX": "S&P 500",
    "UK100.DWX": "FTSE 100",
    "WS30.DWX": "Dow Jones",
    "XAUUSD.DWX": "Gold",
    "XAGUSD.DWX": "Silber",
    "XTIUSD.DWX": "WTI Crude",
    "XNGUSD.DWX": "Natural Gas",
}

CROSSES_PER_LINE = 7


# --- CSV parsing ----------------------------------------------------------


def read_matrix_bytes(csv_path: Path = MATRIX_CSV) -> bytes:
    return csv_path.read_bytes()


def parse_rows(csv_bytes: bytes) -> list[dict[str, str]]:
    text = csv_bytes.decode("utf-8")
    reader = csv.DictReader(io.StringIO(text))
    return [row for row in reader]


def _stem(symbol: str) -> str:
    return symbol[:-4] if symbol.endswith(".DWX") else symbol


def classify(rows: list[dict[str, str]]) -> dict[str, list[dict[str, str]]]:
    """Split symbols into deterministic groups, preserving CSV row order.

    Forex majors = forex pairs whose stem contains 'USD'; crosses = the rest.
    Indices / commodities come straight from the asset_class column.
    """
    majors, crosses, indices, commodities = [], [], [], []
    for row in rows:
        symbol = row["symbol"].strip()
        asset = row["asset_class"].strip()
        if asset == "forex":
            (majors if "USD" in _stem(symbol) else crosses).append(row)
        elif asset == "indices":
            indices.append(row)
        elif asset == "commodities":
            commodities.append(row)
        else:  # pragma: no cover - guards against a new asset_class
            raise ValueError(f"unknown asset_class {asset!r} for {symbol!r}")
    return {
        "majors": majors,
        "crosses": crosses,
        "indices": indices,
        "commodities": commodities,
    }


# --- Rendering ------------------------------------------------------------


def _annotated(symbol: str) -> str:
    name = DISPLAY_NAME.get(symbol)
    return f"{symbol} ({name})" if name else symbol


def _sym_line(rows: list[dict[str, str]]) -> str:
    return " · ".join(r["symbol"].strip() for r in rows)


def _sym_line_annotated(rows: list[dict[str, str]]) -> str:
    return " · ".join(_annotated(r["symbol"].strip()) for r in rows)


def _chunk_lines(rows: list[dict[str, str]], per_line: int) -> str:
    syms = [r["symbol"].strip() for r in rows]
    lines = [
        " · ".join(syms[i : i + per_line]) for i in range(0, len(syms), per_line)
    ]
    return "\n".join(lines)


def _sp500_note(indices: list[dict[str, str]]) -> str | None:
    for row in indices:
        if row["symbol"].strip() != "SP500.DWX":
            continue
        if row.get("live_order_status", "").strip() != "ORDER_ROUTABLE_CONFIRMED":
            return None
        live_sym = row.get("live_order_symbol", "").strip() or "SP500"
        status = row["live_order_status"].strip()
        ref = row.get("routing_evidence_ref", "").strip()
        return (
            f"> **SP500.DWX** ist der T1–T5-Backtest-Alias mit OWNER-Ticks; Live-Orders routen über das\n"
            f"> exakte Broker-Symbol **{live_sym}** (`live_order_status = {status}`, akzeptierter\n"
            f"> Entry + Close auf Darwinex-Live). Evidence:\n"
            f"> `{ref}` — **hebt die\n"
            f"> 2026-05-16-Nicht-Routbarkeits-Aussage auf**."
        )
    return None


def render_page(csv_bytes: bytes) -> str:
    """Return the full markdown page for the given matrix CSV bytes.

    Deterministic: identical csv_bytes -> identical string (LF newlines, no
    wall-clock content).
    """
    rows = parse_rows(csv_bytes)
    groups = classify(rows)
    majors = groups["majors"]
    crosses = groups["crosses"]
    indices = groups["indices"]
    commodities = groups["commodities"]

    forex_total = len(majors) + len(crosses)
    total = forex_total + len(indices) + len(commodities)
    digest = hashlib.sha256(csv_bytes).hexdigest()

    parts: list[str] = []
    parts.append("# Kanonische Symbol-Liste")
    parts.append("")
    parts.append(
        f"<!-- GENERATED — do not hand-edit; regenerate via {SCRIPT_REL} -->"
    )
    parts.append(
        f"<!-- source: {MATRIX_REL} · sha256: {digest} -->"
    )
    parts.append("")
    parts.append(
        "**Quelle der Wahrheit:** `framework/registry/dwx_symbol_matrix.csv` "
        "(Filesystem ist Wahrheit, HR1)."
    )
    parts.append(
        "**Generiert — nicht von Hand pflegen.** Bei Symboländerung zuerst die "
        f"CSV ändern, dann `python {SCRIPT_REL} --write` ausführen. Die Zahlen und "
        "Listen unten werden vollständig aus der Matrix abgeleitet."
    )
    parts.append("")
    parts.append(
        "Alle Symbole tragen `.DWX`-Suffix (Custom Symbol). **Niemals den "
        "Raw-Broker-Namen ohne Suffix verwenden** — MT5 unterscheidet zwischen "
        "`EURUSD` (broker-native) und `EURUSD.DWX` (Custom Symbol). Falsche "
        "Verwendung = NO_REPORT."
    )
    parts.append("")
    parts.append("---")
    parts.append("")
    parts.append(f"## Aktive Symbole ({total})")
    parts.append("")
    parts.append(f"### Forex ({forex_total})")
    parts.append("")
    parts.append(f"**Majors ({len(majors)}):**")
    parts.append(_sym_line(majors))
    parts.append("")
    parts.append(f"**Crosses / Minors ({len(crosses)}):**")
    parts.append(_chunk_lines(crosses, CROSSES_PER_LINE))
    parts.append("")
    parts.append(f"### Indices ({len(indices)})")
    parts.append("")
    parts.append(_sym_line_annotated(indices))

    note = _sp500_note(indices)
    if note is not None:
        parts.append("")
        parts.append(note)

    parts.append("")
    parts.append(f"### Commodities / Energies ({len(commodities)})")
    parts.append("")
    parts.append(_sym_line_annotated(commodities))
    parts.append("")
    parts.append("---")
    parts.append("")
    parts.append("## Veraltete / falsche Symbol-Namen (NICHT verwenden)")
    parts.append("")
    parts.append("| Falsch | Korrekt | Hintergrund |")
    parts.append("|--------|---------|-------------|")
    parts.append(
        "| `NDXm.DWX` | `NDX.DWX` | DL-059 Rename 2026-05-06: das `m` war ein "
        "TDS-Filename-Artefakt, nicht der Broker-Name. |"
    )
    parts.append(
        "| `GDAXIm.DWX` | `GDAXI.DWX` | DL-059 Rename 2026-05-06: gleicher Grund. |"
    )
    parts.append("")
    parts.append(
        "**Achtung:** Die alten Ordner `bases/Custom/history/NDXm.DWX/` und "
        "`…/GDAXIm.DWX/` können auf **T2–T5** noch als Disk-Relikte liegen (das "
        "DL-059-Cleanup wurde nur auf T1 ausgeführt). Diese sind **nicht** Teil "
        "der aktiven Symbol-Liste — Pipeline-Op behandelt sie als legacy und "
        "löscht sie nach erfolgreicher T2–T5-Propagation des neuen Targets."
    )
    parts.append("")
    parts.append("Der `gen_setfile.ps1`-Generator schließt die alten Namen automatisch aus.")
    parts.append("")
    parts.append("---")
    parts.append("")
    parts.append("## Wichtige Regeln")
    parts.append("")
    parts.append(
        "1. **Immer `.DWX`-Suffix.** Falsche Verwendung führt zu NO_REPORT "
        "(≠ EA-Schwäche, sondern Setup-Fehler — HR7)."
    )
    parts.append(
        "2. **`bases/` niemals löschen** (HR6). Enthält Custom Symbol "
        "Tick-Daten-Struktur. Löschen zerstört alle Symbole permanent."
    )
    parts.append("3. **Setfile-Namensschema:** `<ea_label>_<SYMBOL>_<PERIOD>_<MODE>.set`")
    parts.append("   - Beispiel: `QM5_1003_davey_baseline_3bar_EURUSD.DWX_H1_backtest.set`")
    parts.append(
        "4. **Indices besonders prüfen** — `WS30.DWX` und `GDAXI.DWX` haben "
        "manchmal fehlende Tick-Daten-Lücken um DST-Übergänge."
    )
    parts.append(
        "5. **Liste pflegen:** Wenn ein Symbol hinzukommt oder entfernt wird, "
        "muss das *zuerst* in `framework/registry/dwx_symbol_matrix.csv` "
        f"passieren — diese Vault-Seite ist generierter Mirror (`{SCRIPT_REL}`), "
        "nicht Quelle."
    )
    parts.append("")
    parts.append("---")
    parts.append("")
    parts.append("## Wo wird die Liste verwendet?")
    parts.append("")
    parts.append("| Verbraucher | Nutzung |")
    parts.append("|-------------|---------|")
    parts.append("| `gen_setfile.ps1` | Generiert pro EA × Symbol × Timeframe ein Setfile |")
    parts.append("| `p2_baseline.py` | Iteriert über Matrix für Baseline-Sweep |")
    parts.append("| `Compile_Custom_Bars_QM_v2.mq5` | `g_symbols`-Liste für Tick-Daten-Compile |")
    parts.append("| `framework/registry/magic_numbers.csv` | `(ea_id, symbol_slot)` → Magic |")
    parts.append(
        f"| Data Integrity Agent (geplant) | Tägl. Health-Check ob alle {total} "
        "Symbole in Market Watch sind |"
    )
    parts.append("")
    parts.append("---")
    parts.append("")
    parts.append(
        "*Kanonische Quelle: `framework/registry/dwx_symbol_matrix.csv` · "
        "`framework/scripts/gen_setfile.ps1` · "
        "`decisions/DL-059_custom_symbol_rename_NDX_GDAXI.md`*"
    )

    return "\n".join(parts) + "\n"


# --- CLI ------------------------------------------------------------------


def _write_lf(path: Path, text: str) -> None:
    # Preserve LF newlines on Windows: write bytes, never text-mode translation.
    path.write_bytes(text.encode("utf-8"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--write", action="store_true", help="rewrite the vault page")
    group.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if the vault page differs from the generated output",
    )
    parser.add_argument(
        "--stdout", action="store_true", help="print generated page to stdout"
    )
    parser.add_argument(
        "--matrix", type=Path, default=MATRIX_CSV, help="matrix CSV path override"
    )
    parser.add_argument(
        "--page", type=Path, default=VAULT_PAGE, help="vault page path override"
    )
    args = parser.parse_args(argv)

    csv_bytes = read_matrix_bytes(args.matrix)
    page = render_page(csv_bytes)

    if args.stdout:
        sys.stdout.write(page)

    if args.write:
        _write_lf(args.page, page)
        print(f"wrote {args.page}")
        return 0

    if args.check:
        if not args.page.exists():
            print(f"CHECK FAIL: page missing: {args.page}")
            return 1
        current = args.page.read_bytes()
        if current != page.encode("utf-8"):
            print("CHECK FAIL: vault page drifted from matrix; run --write")
            return 1
        print("CHECK PASS: vault page matches matrix")
        return 0

    # default: print to stdout
    if not args.stdout:
        sys.stdout.write(page)
    return 0


if __name__ == "__main__":
    sys.exit(main())
