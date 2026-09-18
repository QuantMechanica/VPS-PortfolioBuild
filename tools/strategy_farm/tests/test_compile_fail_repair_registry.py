"""Guards for the generic evidence-bound compile-fail repair registry."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import pytest

from tools.strategy_farm import compile_work_items

REPO_ROOT = Path(compile_work_items.__file__).resolve().parents[2]

QM5_41475_AUTHORITY = (
    "compile_fail_repair:20260918:"
    "QM5_41475_cash-window-index-continuation-h1:ceff396d"
)
QM5_41477_AUTHORITY = (
    "compile_fail_repair:20260918:"
    "QM5_41477_fx-session-mean-reversion-m15:512aa887"
)


def _registry() -> dict[str, dict[str, Any]]:
    return compile_work_items.load_compile_fail_repair_authorities()


def _predecessor_row(entry: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": entry["predecessor_work_item_id"],
        "ea_id": f"QM5_{entry['ea_id']}",
        "phase": compile_work_items.COMPILE_EA_PHASE,
        "status": "failed",
        "verdict": "COMPILE_FAIL",
        "payload_json": json.dumps({
            "ea_label": entry["ea_label"],
            "mq5_sha256": entry["rejected_mq5_sha256"],
            "verdict_reason": ";".join(entry["expected_failure_classes"]),
            "compile_result": {
                "compile_result": "PASS",
                "build_check_result": "FAIL",
                "failure_classes": list(entry["expected_failure_classes"]),
                "success": False,
            },
        }),
    }


def _inventory(entry: dict[str, Any]) -> dict[str, Any]:
    return {"work_rows": {entry["ea_id"]: [_predecessor_row(entry)]}}


def _arguments(entry: dict[str, Any]) -> dict[str, Any]:
    return {
        "ea_id": entry["ea_id"],
        "source_sha": entry["repaired_mq5_sha256"],
        "inventory": _inventory(entry),
        "repo_root": REPO_ROOT,
    }


def test_registry_loads_and_validates() -> None:
    registry = _registry()
    assert set(registry) == {QM5_41475_AUTHORITY, QM5_41477_AUTHORITY}
    for authority, entry in registry.items():
        assert entry["authority"] == authority
        assert entry["scope"] == compile_work_items.COMPILE_FAIL_REPAIR_SCOPE
        assert entry["ea_label"].startswith(f"QM5_{entry['ea_id']}_")
        assert entry["expected_failure_classes"]
        evidence = REPO_ROOT / entry["evidence_path"]
        assert evidence.is_file()
        assert (
            compile_work_items.sha256_file(evidence).lower()
            == entry["evidence_sha256"]
        )
        source = (
            REPO_ROOT / "framework" / "EAs" / entry["ea_label"]
            / f"{entry['ea_label']}.mq5"
        )
        assert compile_work_items.sha256_file(source).lower() == (
            entry["repaired_mq5_sha256"]
        )


@pytest.mark.parametrize(
    "authority", [QM5_41475_AUTHORITY, QM5_41477_AUTHORITY]
)
def test_authorizer_accepts_registered_happy_path(authority: str) -> None:
    entry = _registry()[authority]
    assert compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"], authority, **_arguments(entry)
    )
    # The public dispatch must route the registry authority the same way.
    assert compile_work_items._source_repair_authorized(
        entry["ea_label"],
        authority,
        repo_root=REPO_ROOT,
        ea_id=entry["ea_id"],
        source_sha=entry["repaired_mq5_sha256"],
        inventory=_inventory(entry),
    )


def test_authorizer_rejects_wrong_label_id_and_authority() -> None:
    entry = _registry()[QM5_41475_AUTHORITY]
    arguments = _arguments(entry)
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        "QM5_41476_unrelated", QM5_41475_AUTHORITY, **arguments
    )
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"], QM5_41475_AUTHORITY, **{**arguments, "ea_id": "41476"}
    )
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"], "compile_fail_repair:20260918:X:00000000", **arguments
    )
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"], None, **arguments
    )


def test_authorizer_rejects_wrong_source_sha() -> None:
    entry = _registry()[QM5_41475_AUTHORITY]
    arguments = _arguments(entry)
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"],
        QM5_41475_AUTHORITY,
        **{**arguments, "source_sha": entry["rejected_mq5_sha256"]},
    )
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"],
        QM5_41475_AUTHORITY,
        **{**arguments, "source_sha": "0" * 64},
    )


def test_authorizer_rejects_wrong_predecessor_state() -> None:
    entry = _registry()[QM5_41475_AUTHORITY]
    arguments = _arguments(entry)

    missing = {"work_rows": {entry["ea_id"]: []}}
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"], QM5_41475_AUTHORITY, **{**arguments, "inventory": missing}
    )

    for field, value in (
        ("status", "done"),
        ("verdict", "COMPILE_OK"),
        ("phase", "Q02"),
        ("id", "00000000-0000-0000-0000-000000000000"),
    ):
        mutated = copy.deepcopy(arguments["inventory"])
        mutated["work_rows"][entry["ea_id"]][0][field] = value
        assert not compile_work_items._generic_compile_fail_repair_authorized(
            entry["ea_label"],
            QM5_41475_AUTHORITY,
            **{**arguments, "inventory": mutated},
        ), field

    rejected_sha = copy.deepcopy(arguments["inventory"])
    payload = json.loads(
        rejected_sha["work_rows"][entry["ea_id"]][0]["payload_json"]
    )
    payload["mq5_sha256"] = "1" * 64
    rejected_sha["work_rows"][entry["ea_id"]][0]["payload_json"] = json.dumps(payload)
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"],
        QM5_41475_AUTHORITY,
        **{**arguments, "inventory": rejected_sha},
    )


def test_authorizer_rejects_wrong_failure_classes() -> None:
    entry = _registry()[QM5_41477_AUTHORITY]
    arguments = _arguments(entry)
    for classes in (
        ["EA_FRAMEWORK_RAW_SERIES_CALL"],
        ["EA_CARD_LOSS_LIMIT_MISMATCH", "EA_FRAMEWORK_RAW_SERIES_CALL"],
        [],
        None,
    ):
        mutated = copy.deepcopy(arguments["inventory"])
        payload = json.loads(mutated["work_rows"][entry["ea_id"]][0]["payload_json"])
        payload["compile_result"]["failure_classes"] = classes
        mutated["work_rows"][entry["ea_id"]][0]["payload_json"] = json.dumps(payload)
        assert not compile_work_items._generic_compile_fail_repair_authorized(
            entry["ea_label"],
            QM5_41477_AUTHORITY,
            **{**arguments, "inventory": mutated},
        ), classes


def test_authorizer_rejects_tampered_evidence(tmp_path: Path) -> None:
    entry = _registry()[QM5_41475_AUTHORITY]
    arguments = _arguments(entry)
    fake_root = tmp_path / "repo"
    evidence = fake_root / entry["evidence_path"]
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_bytes(b'{"schema": "tampered"}\n')
    assert (
        hashlib.sha256(evidence.read_bytes()).hexdigest()
        != entry["evidence_sha256"]
    )
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"],
        QM5_41475_AUTHORITY,
        **{**arguments, "repo_root": fake_root},
    )
    evidence.unlink()
    assert not compile_work_items._generic_compile_fail_repair_authorized(
        entry["ea_label"],
        QM5_41475_AUTHORITY,
        **{**arguments, "repo_root": fake_root},
    )


def _write_registry(tmp_path: Path, document: Any) -> Path:
    tmp_path.mkdir(parents=True, exist_ok=True)
    path = tmp_path / "compile_fail_repair_authorities.v1.json"
    path.write_text(json.dumps(document), encoding="utf-8")
    return path


def _valid_document() -> dict[str, Any]:
    entry = copy.deepcopy(_registry()[QM5_41475_AUTHORITY])
    return {
        "schema": compile_work_items.COMPILE_FAIL_REPAIR_REGISTRY_SCHEMA,
        "authorities": [entry],
    }


def test_registry_loader_fails_closed(tmp_path: Path) -> None:
    assert compile_work_items.load_compile_fail_repair_authorities(
        tmp_path / "missing.json"
    ) == {}
    assert compile_work_items.load_compile_fail_repair_authorities(
        _write_registry(tmp_path / "a", {"schema": "wrong", "authorities": []})
    ) == {}

    good = _valid_document()
    assert set(
        compile_work_items.load_compile_fail_repair_authorities(
            _write_registry(tmp_path / "b", good)
        )
    ) == {QM5_41475_AUTHORITY}

    for mutate in (
        lambda d: d["authorities"][0].update({"scope": "everything"}),
        lambda d: d["authorities"][0].update({"ea_id": "99999"}),
        lambda d: d["authorities"][0].update({"evidence_sha256": "zz"}),
        lambda d: d["authorities"][0].update({"expected_failure_classes": []}),
        lambda d: d["authorities"][0].update({"authority": "not-a-repair-authority"}),
        lambda d: d["authorities"][0].update({
            "evidence_path": "../../etc/passwd"
        }),
        lambda d: d["authorities"][0].update({
            "repaired_mq5_sha256": d["authorities"][0]["rejected_mq5_sha256"]
        }),
        lambda d: d["authorities"].append(copy.deepcopy(d["authorities"][0])),
    ):
        document = _valid_document()
        mutate(document)
        target = tmp_path / f"case{abs(hash(json.dumps(document))) % 10**8}"
        assert compile_work_items.load_compile_fail_repair_authorities(
            _write_registry(target, document)
        ) == {}


def test_sanctioned_predecessor_is_bound_to_the_registry_row() -> None:
    entry = _registry()[QM5_41477_AUTHORITY]
    inventory = _inventory(entry)
    payload = {
        "ea_label": entry["ea_label"],
        "mq5_sha256": entry["repaired_mq5_sha256"],
        "append_only_source_repair": True,
        "compile_source_repair_contract_version": (
            compile_work_items.SOURCE_REPAIR_CONTRACT_VERSION
        ),
        "compile_source_repair_authority": entry["authority"],
        "source_repair_predecessor_work_item_ids": [
            entry["predecessor_work_item_id"]
        ],
    }
    assert compile_work_items._sanctioned_compile_predecessor_ids(
        payload, inventory, entry["ea_id"], current_work_item_id="new-row"
    ) == {entry["predecessor_work_item_id"]}

    for key, value in (
        ("append_only_source_repair", False),
        ("compile_source_repair_contract_version", "qm.wrong/v1"),
        ("mq5_sha256", entry["rejected_mq5_sha256"]),
        ("source_repair_predecessor_work_item_ids", []),
        ("ea_label", "QM5_41477_other"),
    ):
        assert compile_work_items._sanctioned_compile_predecessor_ids(
            {**payload, key: value},
            inventory,
            entry["ea_id"],
            current_work_item_id="new-row",
        ) == set(), key

    stale = copy.deepcopy(inventory)
    stale["work_rows"][entry["ea_id"]][0]["status"] = "done"
    assert compile_work_items._sanctioned_compile_predecessor_ids(
        payload, stale, entry["ea_id"], current_work_item_id="new-row"
    ) == set()
