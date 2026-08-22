from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import sys

import pytest


ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "tools" / "strategy_farm"
sys.path.insert(0, str(TOOLS))

import news_calendar_repin as subject  # noqa: E402


HEADER = "datetime,currency,event_name,impact"
SECONDARY_HEADER = "Date,DateTime_UTC,Currency,Impact,Event"


def _write_calendar(path: Path, dates: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [HEADER]
    secondary_lines = [SECONDARY_HEADER]
    for index, value in enumerate(dates, start=1):
        lines.append(f"{value} 08:30:00,USD,Event {index},high")
        dotted = value.replace("-", ".")
        secondary_lines.append(f"{dotted},{dotted} 08:30,USD,High,Event {index}")
    path.write_text("\r\n".join(lines) + "\r\n", encoding="ascii", newline="")
    (path.parent / subject.SECONDARY_NAME).write_text(
        "\r\n".join(secondary_lines) + "\r\n", encoding="ascii", newline=""
    )


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _coverage(dates: list[str]) -> tuple[str | None, str | None]:
    return (min(dates), max(dates)) if dates else (None, None)


def _write_registry(path: Path, calendar: Path, dates: list[str]) -> bytes:
    start, end = _coverage(dates)
    pin = _sha(calendar)
    secondary = calendar.parent / subject.SECONDARY_NAME
    secondary_pin = _sha(secondary)
    payload = {
        "schema_version": "test",
        "policy": {"stale_max_hours": 336, "byte_hash_required": True},
        "contracts": [
            {
                "calendar": {
                    "sources": [
                        {
                            "role": "SHARED_PRIMARY",
                            "path": str(calendar.resolve()),
                            "sha256": pin,
                            "coverage_start": start,
                            "coverage_end": end,
                        },
                        {
                            "role": "COMMON_PRIMARY",
                            "path": str((calendar.parent / "common" / calendar.name).resolve()),
                            "sha256": pin,
                            "coverage_start": start,
                            "coverage_end": end,
                        },
                        {
                            "role": "SHARED_SECONDARY",
                            "path": str(secondary.resolve()),
                            "sha256": secondary_pin,
                            "coverage_start": start,
                            "coverage_end": end,
                        },
                        {
                            "role": "COMMON_SECONDARY",
                            "path": str(
                                (calendar.parent / "common" / secondary.name).resolve()
                            ),
                            "sha256": secondary_pin,
                            "coverage_start": start,
                            "coverage_end": end,
                        },
                    ]
                }
            }
        ],
    }
    raw = json.dumps(payload, indent=2).encode("utf-8") + b"\n"
    path.write_bytes(raw)
    return raw


def _publication_proof(
    base: Path,
    *,
    calendar: Path,
    refresh_script: Path,
    operation_id: str,
) -> tuple[Path, Path]:
    bundle = base / f"bundle-{operation_id[:8]}"
    bundle.mkdir(parents=True)
    (bundle / calendar.name).write_bytes(calendar.read_bytes())
    secondary = calendar.parent / subject.SECONDARY_NAME
    (bundle / secondary.name).write_bytes(secondary.read_bytes())
    receipt_path = base / f"publication-receipt-{operation_id[:8]}.json"
    journal_path = base / f"publication-journal-{operation_id[:8]}.json"
    plan_sha = hashlib.sha256((operation_id + "plan").encode()).hexdigest()
    bundle_id = "news-calendar-" + hashlib.sha256(
        (operation_id + "bundle").encode()
    ).hexdigest()
    receipt = {
        "ok": True,
        "status": "committed",
        "published": True,
        "committed": True,
        "lock_release_succeeded": True,
        "operation_id": operation_id,
        "plan_sha256": plan_sha,
        "bundle_id": bundle_id,
        "source_dir": str(calendar.parent.resolve()),
        "receipt_path": str(receipt_path.resolve()),
        "journal_path": str(journal_path.resolve()),
        "bundle_dirs": {str(calendar.parent.resolve()): str(bundle.resolve())},
        "preflights": [
            {
                "ok": True,
                "mismatches": [],
                "missing_common_paths": [],
            }
        ],
    }
    journal = {
        "committed": True,
        "state": "COMMITTED_RECEIPTED",
        "operation_id": operation_id,
        "plan_sha256": plan_sha,
        "bundle_id": bundle_id,
        "source_dir": str(calendar.parent.resolve()),
        "receipt_path": str(receipt_path.resolve()),
        "provenance": {
            "kind": "scheduled-refresh-script",
            "path": str(refresh_script.resolve()),
            "sha256": _sha(refresh_script),
        },
    }
    receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
    journal_path.write_text(json.dumps(journal), encoding="utf-8")
    return receipt_path, journal_path


def _fixture(tmp_path: Path, dates: list[str]) -> dict[str, Path]:
    calendar = tmp_path / "calendar" / subject.PRIMARY_NAME
    _write_calendar(calendar, dates)
    registry = tmp_path / "dxz23_execution_contracts.json"
    _write_registry(registry, calendar, dates)
    bundle_root = tmp_path / "old-bundles"
    old = bundle_root / "initial" / subject.PRIMARY_NAME
    old.parent.mkdir(parents=True)
    old.write_bytes(calendar.read_bytes())
    (old.parent / subject.SECONDARY_NAME).write_bytes(
        (calendar.parent / subject.SECONDARY_NAME).read_bytes()
    )
    refresh_script = tmp_path / "refresh_news_calendar.ps1"
    refresh_script.write_text("Write-Output 'refresh'\n", encoding="ascii")
    lock = tmp_path / "locks" / "repin.lock"
    lock.parent.mkdir(parents=True)
    return {
        "calendar": calendar,
        "registry": registry,
        "bundle_root": bundle_root,
        "refresh_script": refresh_script,
        "receipt_dir": tmp_path / "receipts",
        "lock": lock,
        "proof_dir": tmp_path / "proof",
    }


def _record(paths: dict[str, Path], *, operation_id: str) -> dict[str, object]:
    paths["proof_dir"].mkdir(exist_ok=True)
    receipt, journal = _publication_proof(
        paths["proof_dir"],
        calendar=paths["calendar"],
        refresh_script=paths["refresh_script"],
        operation_id=operation_id,
    )
    return subject.record_repin(
        publication_receipt_path=receipt,
        publication_journal_path=journal,
        calendar_path=paths["calendar"],
        registry_path=paths["registry"],
        receipt_dir=paths["receipt_dir"],
        bundle_root=paths["bundle_root"],
        refresh_script_path=paths["refresh_script"],
        lock_path=paths["lock"],
        expected_operation_id=operation_id,
        reason="scheduled_news_calendar_refresh",
    )


def test_record_repin_and_verify_two_receipt_chain(tmp_path: Path) -> None:
    paths = _fixture(tmp_path, ["2026-08-20", "2026-08-21"])
    original_registry = json.loads(paths["registry"].read_text())
    _write_calendar(
        paths["calendar"], ["2026-08-20", "2026-08-21", "2026-08-22"]
    )
    first = _record(paths, operation_id="a" * 64)
    assert first["status"] == "REPINNED"
    assert first["chain_verification"] == "PASS"
    after_first = json.loads(paths["registry"].read_text())
    assert after_first["policy"] == original_registry["policy"]
    assert {
        source["role"]: source["sha256"]
        for source in after_first["contracts"][0]["calendar"]["sources"]
    } == {
        "SHARED_PRIMARY": _sha(paths["calendar"]),
        "COMMON_PRIMARY": _sha(paths["calendar"]),
        "SHARED_SECONDARY": _sha(paths["calendar"].parent / subject.SECONDARY_NAME),
        "COMMON_SECONDARY": _sha(paths["calendar"].parent / subject.SECONDARY_NAME),
    }

    _write_calendar(
        paths["calendar"],
        ["2026-08-20", "2026-08-21", "2026-08-22", "2026-08-23"],
    )
    second = _record(paths, operation_id="b" * 64)
    assert second["status"] == "REPINNED"
    verified = subject.verify_chain(
        receipt_dir=paths["receipt_dir"],
        registry_path=paths["registry"],
        calendar_path=paths["calendar"],
    )
    assert verified["status"] == "PASS"
    assert verified["receipt_count"] == 2
    assert verified["coverage_end"] == "2026-08-23"


@pytest.mark.parametrize("mutation", ["shrink", "coverage_recedes"])
def test_implausible_calendar_refuses_without_repin(
    tmp_path: Path, mutation: str
) -> None:
    paths = _fixture(tmp_path, ["2026-08-20", "2026-08-22"])
    before = paths["registry"].read_bytes()
    if mutation == "shrink":
        dates = ["2026-08-20"]
    else:
        dates = ["2026-08-19", "2026-08-21"]
    _write_calendar(paths["calendar"], dates)
    with pytest.raises(subject.RepinError, match="shrank|backward"):
        _record(paths, operation_id="c" * 64)
    assert paths["registry"].read_bytes() == before
    assert not list(paths["receipt_dir"].glob("*.json")) if paths["receipt_dir"].exists() else True


def test_edited_or_removed_receipt_breaks_chain(tmp_path: Path) -> None:
    paths = _fixture(tmp_path, ["2026-08-20"])
    _write_calendar(paths["calendar"], ["2026-08-20", "2026-08-21"])
    _record(paths, operation_id="d" * 64)
    _write_calendar(
        paths["calendar"], ["2026-08-20", "2026-08-21", "2026-08-22"]
    )
    _record(paths, operation_id="e" * 64)
    receipts = sorted(paths["receipt_dir"].glob("*.json"))

    original = receipts[0].read_bytes()
    edited = json.loads(original)
    edited["sources"][0]["after"]["row_count"] += 1
    receipts[0].write_text(json.dumps(edited), encoding="utf-8")
    with pytest.raises(subject.RepinError, match="signature mismatch"):
        subject.verify_chain(
            receipt_dir=paths["receipt_dir"],
            registry_path=paths["registry"],
            calendar_path=paths["calendar"],
        )

    receipts[0].write_bytes(original)
    receipts[0].unlink()
    with pytest.raises(subject.RepinError, match="missing or invalid sequence"):
        subject.verify_chain(
            receipt_dir=paths["receipt_dir"],
            registry_path=paths["registry"],
            calendar_path=paths["calendar"],
        )


def test_registry_pin_drift_breaks_verification(tmp_path: Path) -> None:
    paths = _fixture(tmp_path, ["2026-08-20"])
    _write_calendar(paths["calendar"], ["2026-08-20", "2026-08-21"])
    _record(paths, operation_id="f" * 64)
    text = paths["registry"].read_text(encoding="utf-8")
    text = text.replace(_sha(paths["calendar"]), "0" * 64)
    paths["registry"].write_text(text, encoding="utf-8")
    with pytest.raises(subject.RepinError, match="registry pin"):
        subject.verify_chain(
            receipt_dir=paths["receipt_dir"],
            registry_path=paths["registry"],
            calendar_path=paths["calendar"],
        )


def test_record_cli_refuses_without_refresh_parent_proof(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    paths = _fixture(tmp_path, ["2026-08-20"])
    _write_calendar(paths["calendar"], ["2026-08-20", "2026-08-21"])
    paths["proof_dir"].mkdir()
    receipt, journal = _publication_proof(
        paths["proof_dir"],
        calendar=paths["calendar"],
        refresh_script=paths["refresh_script"],
        operation_id="1" * 64,
    )
    monkeypatch.delenv("QM_NEWS_CALENDAR_REFRESH_PARENT_PID", raising=False)
    monkeypatch.delenv("QM_NEWS_CALENDAR_REFRESH_OPERATION_ID", raising=False)
    result = subject.main(
        [
            "record",
            "--publication-receipt",
            str(receipt),
            "--publication-journal",
            str(journal),
            "--calendar",
            str(paths["calendar"]),
            "--registry",
            str(paths["registry"]),
            "--receipt-dir",
            str(paths["receipt_dir"]),
            "--bundle-root",
            str(paths["bundle_root"]),
            "--refresh-script",
            str(paths["refresh_script"]),
            "--lock",
            str(paths["lock"]),
            "--operation-id",
            "1" * 64,
            "--reason",
            "scheduled_news_calendar_refresh",
        ]
    )
    assert result == 2
    assert "internal to the live refresh process" in capsys.readouterr().out
