from __future__ import annotations

import csv
from pathlib import Path

from tools.strategy_farm import scan_host_slot_magic as scan


def _write(path: Path, text: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def _ea(root: Path, ea_id: int, slug: str, body: str) -> None:
    directory = root / "framework" / "EAs" / f"QM5_{ea_id}_{slug}"
    _write(directory / f"QM5_{ea_id}_{slug}.mq5", body)


def _registry(root: Path) -> None:
    path = root / "framework" / "registry" / "magic_numbers.csv"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            (
                "ea_id",
                "ea_slug",
                "symbol_slot",
                "symbol",
                "magic",
                "reserved_at",
                "reserved_by",
                "status",
            )
        )
        for ea_id, slug in (
            (1001, "default"),
            (1002, "included"),
            (1003, "explicit"),
            (1004, "basket"),
        ):
            writer.writerow(
                (ea_id, slug, 0, "EURUSD.DWX", ea_id * 10000, "2026-08-16", "test", "active")
            )
            writer.writerow(
                (ea_id, slug, 2, "GBPUSD.DWX", ea_id * 10000 + 2, "2026-08-16", "test", "active")
            )


def test_scan_resolves_local_includes_and_classifies_actual_entry_calls(
    tmp_path: Path,
) -> None:
    _registry(tmp_path)
    _ea(
        tmp_path,
        1001,
        "default",
        """
        void Tick() {
          QM_EntryRequest req;
          // req.symbol_slot = qm_magic_slot_offset; detector must ignore this.
          string decoy = "req.symbol_slot = qm_magic_slot_offset;";
          ulong ticket = 0;
          QM_TM_OpenPosition(req, ticket);
        }
        """,
    )
    _write(
        tmp_path / "framework" / "EAs" / "_shared_slot.mqh",
        "void Build(QM_EntryRequest &req) { req.symbol_slot = qm_magic_slot_offset; }\n",
    )
    _ea(
        tmp_path,
        1002,
        "included",
        """
        #include "..\\_shared_slot.mqh"
        void Tick() {
          QM_EntryRequest req;
          Build(req);
          ulong ticket = 0;
          QM_TM_OpenPosition(req, ticket);
        }
        """,
    )
    _ea(
        tmp_path,
        1003,
        "explicit",
        """
        void Tick() {
          QM_EntryRequest req;
          ulong ticket = 0;
          QM_TM_OpenPosition(req, ticket, QM_FrameworkMagic());
        }
        """,
    )
    _ea(
        tmp_path,
        1004,
        "basket",
        """
        void Tick() {
          QM_BasketOrderRequest req;
          req.symbol = _Symbol;
          req.symbol_slot = 0;
          ulong ticket = 0;
          QM_BasketOpenPosition(1004, QM_NEWS_OFF, 20, req, ticket);
        }
        """,
    )

    report = scan.build_report(
        tmp_path, generated_at="2026-08-16T00:00:00+00:00"
    )

    assert report["counts"]["sources_scanned"] == 4
    assert report["counts"]["affected_source_paths"] == 2
    assert report["counts"]["affected_pairs"] == 2
    assert report["affected_eas"] == ["QM5_1001", "QM5_1004"]
    assert {(row["ea"], row["slot"]) for row in report["affected_pairs"]} == {
        ("QM5_1001", 2),
        ("QM5_1004", 2),
    }

    removed = {
        row["ea"]: row for row in report["upper_bound_false_positives_removed"]
    }
    assert removed["QM5_1002"]["includes"] == ["_shared_slot.mqh"]
    assert removed["QM5_1002"]["calls"][0]["classification"] == "explicit_slot_wiring"


def test_baseline_comparison_is_exact_pair_set(tmp_path: Path) -> None:
    _registry(tmp_path)
    _ea(
        tmp_path,
        1001,
        "default",
        "void Tick(){QM_EntryRequest req; ulong t=0; QM_Entry(req,t);}",
    )
    baseline = {
        "schema": "old",
        "counts": {"affected_pairs": 2},
        "affected_pairs": [
            {"ea": "QM5_1001", "slot": 2, "symbol": "GBPUSD.DWX"},
            {"ea": "QM5_9999", "slot": 1, "symbol": "XAUUSD.DWX"},
        ],
    }

    report = scan.build_report(tmp_path, baseline=baseline)
    comparison = report["baseline_comparison"]
    assert comparison["removed_pairs"] == [
        {"ea": "QM5_9999", "slot": 1, "symbol": "XAUUSD.DWX"}
    ]
    assert comparison["added_pairs"] == []

