from __future__ import annotations

import dataclasses
import json
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_as_live_requal as subject


def _artifacts(tmp_path: Path, token: str) -> tuple[Path, Path]:
    ex5 = tmp_path / f"{token}.ex5"
    preset = tmp_path / f"{token}.set"
    ex5.write_bytes(f"ex5:{token}".encode("ascii"))
    preset.write_text("ENV=live\n", encoding="utf-8")
    return ex5, preset


def _override_row(
    tmp_path: Path,
    *,
    timeframe: str,
    variant_id: str | None,
) -> dict:
    token = f"{timeframe}_{variant_id or 'default'}"
    ex5, preset = _artifacts(tmp_path, token)
    return {
        "ea_id": 7001,
        "symbol": "EURUSD.DWX",
        "timeframe": timeframe,
        "variant_id": variant_id,
        "ea_label": "QM5_7001_test",
        "ex5_path": ex5,
        "ex5_sha256": subject.sha256_file(ex5),
        "set_path": preset,
        "set_sha256": subject.sha256_file(preset),
    }


def _manifest(path: Path, sleeves: list[dict]) -> Path:
    path.write_text(
        json.dumps({"n_sleeves": len(sleeves), "sleeves": sleeves}),
        encoding="utf-8",
    )
    return path


def _sleeve(**extra: object) -> dict:
    return {
        "ea_id": 7001,
        "symbol": "EURUSD.DWX",
        "ea_label": "QM5_7001_test",
        "trades": 1,
        **extra,
    }


def test_artifact_override_index_uses_timeframe_and_optional_variant(
    tmp_path: Path,
) -> None:
    rows = [
        _override_row(tmp_path, timeframe="H1", variant_id="VARIANT_A"),
        _override_row(tmp_path, timeframe="H4", variant_id="VARIANT_A"),
        _override_row(tmp_path, timeframe="H1", variant_id="VARIANT_B"),
    ]
    payload_rows = []
    for row in rows:
        payload_rows.append(
            {
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "timeframe": row["timeframe"],
                "variant_id": row["variant_id"],
                "ea_label": row["ea_label"],
                "ex5": {
                    "path": str(row["ex5_path"]),
                    "sha256": row["ex5_sha256"],
                },
                "set": {
                    "path": str(row["set_path"]),
                    "sha256": row["set_sha256"],
                },
            }
        )
    override = tmp_path / "override.json"
    override.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "qualification_mode": "DISCOVERY_COMPLETE_UNREFERENCED",
                "artifacts": payload_rows,
            }
        ),
        encoding="utf-8",
    )

    metadata, indexed = subject.load_artifact_override_manifest(override)

    assert metadata["rows"] == 3
    assert set(indexed) == {
        "7001:EURUSD.DWX:H1:VARIANT_A",
        "7001:EURUSD.DWX:H4:VARIANT_A",
        "7001:EURUSD.DWX:H1:VARIANT_B",
    }


def test_build_jobs_matches_exact_identity_and_legacy_fallback_is_unique_only(
    tmp_path: Path,
) -> None:
    h1 = _override_row(tmp_path, timeframe="H1", variant_id="VARIANT_A")
    h4 = _override_row(tmp_path, timeframe="H4", variant_id="VARIANT_A")
    overrides = {
        subject.promotion_identity_key(7001, "EURUSD.DWX", "H1", "VARIANT_A"): h1,
        subject.promotion_identity_key(7001, "EURUSD.DWX", "H4", "VARIANT_A"): h4,
    }
    exact_manifest = _manifest(
        tmp_path / "exact.json",
        [
            _sleeve(timeframe="H1", variant_id="VARIANT_A"),
            _sleeve(timeframe="H4", variant_id="VARIANT_A"),
        ],
    )

    _payload, jobs = subject.build_jobs(
        exact_manifest,
        tmp_path,
        None,
        overrides,
        qualification_mode="DISCOVERY_COMPLETE_UNREFERENCED",
    )
    assert [job.key for job in jobs] == [
        "7001:EURUSD.DWX:H1:VARIANT_A",
        "7001:EURUSD.DWX:H4:VARIANT_A",
    ]

    legacy_manifest = _manifest(tmp_path / "legacy.json", [_sleeve()])
    with pytest.raises(subject.RequalError, match="ambiguous"):
        subject.build_jobs(
            legacy_manifest,
            tmp_path,
            None,
            overrides,
            qualification_mode="DISCOVERY_COMPLETE_UNREFERENCED",
        )

    _payload, [legacy_job] = subject.build_jobs(
        legacy_manifest,
        tmp_path,
        None,
        {next(iter(overrides)): h1},
        qualification_mode="DISCOVERY_COMPLETE_UNREFERENCED",
    )
    assert legacy_job.key == "7001:EURUSD.DWX:H1:VARIANT_A"


def test_target_job_requires_and_propagates_hash_bound_card_contract(
    tmp_path: Path,
) -> None:
    override = _override_row(tmp_path, timeframe="H1", variant_id="POLICY_REPAIR")
    overrides = {
        subject.promotion_identity_key(
            7001, "EURUSD.DWX", "H1", "POLICY_REPAIR"
        ): override
    }
    missing = _manifest(
        tmp_path / "target_missing_card.json",
        [
            _sleeve(
                timeframe="H1",
                variant_id="POLICY_REPAIR",
                magic_number=70010001,
            )
        ],
    )
    with pytest.raises(subject.RequalError, match="requires card_contract"):
        subject.build_jobs(
            missing,
            tmp_path,
            None,
            overrides,
            qualification_mode=subject.TARGET_BINARY_REQUAL,
        )

    card = tmp_path / "card.md"
    card.write_text(
        "---\n"
        "card_schema_version: 2\n"
        "status: APPROVED\n"
        "g0_status: APPROVED\n"
        "execution_contract_status: APPROVED\n"
        "ea_id: QM5_7001\n"
        "symbol: EURUSD.DWX\n"
        "timeframe: H1\n"
        "variant_id: POLICY_REPAIR\n"
        "---\n"
        "# Approved immutable card contract\n",
        encoding="utf-8",
    )
    bound = _manifest(
        tmp_path / "target_bound_card.json",
        [
            _sleeve(
                timeframe="H1",
                variant_id="POLICY_REPAIR",
                magic_number=70010001,
                card_contract={
                    "path": str(card),
                    "sha256": subject.sha256_file(card),
                },
            )
        ],
    )
    _payload, [job] = subject.build_jobs(
        bound,
        tmp_path,
        None,
        overrides,
        qualification_mode=subject.TARGET_BINARY_REQUAL,
    )
    plan = subject.build_plan([job], [tmp_path / "DXZ_Truth_1"])
    receipt = subject.preflight_blocked_receipt(
        job,
        ["REFERENCE_NOT_READY"],
        qualification_mode=subject.TARGET_BINARY_REQUAL,
    )
    assert plan["jobs"][0]["variant_id"] == "POLICY_REPAIR"
    assert plan["jobs"][0]["expected_magic"] == 70010001
    assert plan["jobs"][0]["expected_magic_source"]["manifest_sha256"] == (
        subject.sha256_file(bound)
    )
    assert plan["jobs"][0]["card_contract"] == job.card_contract
    assert receipt["job"]["variant_id"] == "POLICY_REPAIR"
    assert receipt["job"]["expected_magic"] == 70010001
    assert receipt["identity"]["expected_magic"] == 70010001
    assert receipt["card_contract"] == job.card_contract
    unsigned_receipt = dict(receipt)
    declared_receipt_sha = unsigned_receipt.pop("receipt_sha256")
    assert declared_receipt_sha == subject.canonical_json_sha(unsigned_receipt)

    card.write_text("tampered\n", encoding="utf-8")
    with pytest.raises(subject.RequalError, match="changed after preflight"):
        subject.verify_card_contract_binding(job.card_contract, identity_label=job.key)


@pytest.mark.parametrize("magic_number", [None, True, "70010001", 70010001.0, 0, -1])
def test_target_job_requires_exact_positive_integer_manifest_magic(
    tmp_path: Path,
    magic_number: object,
) -> None:
    override = _override_row(tmp_path, timeframe="H1", variant_id="POLICY_REPAIR")
    overrides = {
        subject.promotion_identity_key(
            7001, "EURUSD.DWX", "H1", "POLICY_REPAIR"
        ): override
    }
    sleeve = _sleeve(timeframe="H1", variant_id="POLICY_REPAIR")
    if magic_number is not None:
        sleeve["magic_number"] = magic_number
    manifest = _manifest(tmp_path / f"invalid_magic_{magic_number!s}.json", [sleeve])

    with pytest.raises(subject.RequalError, match="magic_number"):
        subject.build_jobs(
            manifest,
            tmp_path,
            None,
            overrides,
            qualification_mode=subject.TARGET_BINARY_REQUAL,
        )


def test_non_target_job_keeps_manifest_magic_optional(tmp_path: Path) -> None:
    override = _override_row(tmp_path, timeframe="H1", variant_id="VARIANT_A")
    manifest = _manifest(
        tmp_path / "non_target_optional_magic.json",
        [_sleeve(timeframe="H1", variant_id="VARIANT_A")],
    )
    job_key = subject.promotion_identity_key(
        7001, "EURUSD.DWX", "H1", "VARIANT_A"
    )

    _payload, [job] = subject.build_jobs(
        manifest,
        tmp_path,
        None,
        {job_key: override},
        qualification_mode="DISCOVERY_COMPLETE_UNREFERENCED",
    )

    assert job.key == job_key
    assert job.expected_magic is None
    assert job.expected_magic_source is None


def _manifest_magic_job(tmp_path: Path) -> tuple[Path, subject.Job]:
    override = _override_row(tmp_path, timeframe="H1", variant_id="VARIANT_A")
    manifest = _manifest(
        tmp_path / "magic_authority.json",
        [
            _sleeve(
                timeframe="H1",
                variant_id="VARIANT_A",
                magic_number=999,
            )
        ],
    )
    _payload, [job] = subject.build_jobs(
        manifest,
        tmp_path,
        None,
        {
            subject.promotion_identity_key(
                7001, "EURUSD.DWX", "H1", "VARIANT_A"
            ): override
        },
        qualification_mode="DISCOVERY_COMPLETE_UNREFERENCED",
    )
    return manifest, job


def _rebind_manifest_hash(job: subject.Job, manifest: Path) -> subject.Job:
    source = dict(job.expected_magic_source or {})
    source["manifest_sha256"] = subject.sha256_file(manifest)
    return dataclasses.replace(job, expected_magic_source=source)


def test_expected_magic_binding_reads_selected_manifest_sleeve_value(
    tmp_path: Path,
) -> None:
    manifest, job = _manifest_magic_job(tmp_path)
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    payload["sleeves"][0]["magic_number"] = 111
    manifest.write_text(json.dumps(payload), encoding="utf-8")
    job = _rebind_manifest_hash(job, manifest)

    with pytest.raises(subject.RequalError, match="magic_number mismatch"):
        subject.verify_expected_magic_binding(job, required=True)


def test_expected_magic_binding_rejects_wrong_ordinal_and_identity(
    tmp_path: Path,
) -> None:
    manifest, job = _manifest_magic_job(tmp_path)
    wrong_ordinal_source = dict(job.expected_magic_source or {})
    wrong_ordinal_source["sleeve_ordinal"] = 2
    wrong_ordinal = dataclasses.replace(
        job, expected_magic_source=wrong_ordinal_source
    )
    with pytest.raises(subject.RequalError, match="source metadata is invalid"):
        subject.verify_expected_magic_binding(wrong_ordinal, required=True)

    payload = json.loads(manifest.read_text(encoding="utf-8"))
    payload["sleeves"][0]["symbol"] = "GBPUSD.DWX"
    manifest.write_text(json.dumps(payload), encoding="utf-8")
    wrong_identity = _rebind_manifest_hash(job, manifest)
    with pytest.raises(subject.RequalError, match="sleeve identity mismatch"):
        subject.verify_expected_magic_binding(wrong_identity, required=True)


def test_expected_magic_binding_rejects_duplicate_four_part_identity(
    tmp_path: Path,
) -> None:
    manifest, job = _manifest_magic_job(tmp_path)
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    payload["sleeves"].append(dict(payload["sleeves"][0]))
    payload["n_sleeves"] = 2
    manifest.write_text(json.dumps(payload), encoding="utf-8")
    duplicate = _rebind_manifest_hash(job, manifest)

    with pytest.raises(subject.RequalError, match="identity is not unique"):
        subject.verify_expected_magic_binding(duplicate, required=True)


def test_target_card_contract_rejects_unapproved_or_wrong_identity(
    tmp_path: Path,
) -> None:
    card = tmp_path / "card.md"
    card.write_text(
        "---\n"
        "card_schema_version: 2\n"
        "status: IN_REVIEW\n"
        "g0_status: APPROVED\n"
        "execution_contract_status: APPROVED\n"
        "ea_id: QM5_7001\n"
        "symbol: EURUSD.DWX\n"
        "timeframe: H1\n"
        "variant_id: POLICY_REPAIR\n"
        "---\n",
        encoding="utf-8",
    )
    binding = {"path": str(card), "sha256": subject.sha256_file(card)}
    with pytest.raises(subject.RequalError, match="must have status"):
        subject.resolve_card_contract_binding(
            binding,
            manifest_dir=tmp_path,
            required=True,
            identity_label="7001:EURUSD.DWX:H1:POLICY_REPAIR",
            expected_identity=(7001, "EURUSD.DWX", "H1", "POLICY_REPAIR"),
        )

    card.write_text(
        card.read_text(encoding="utf-8").replace(
            "status: IN_REVIEW", "status: APPROVED"
        ).replace("variant_id: POLICY_REPAIR", "variant_id: WRONG_VARIANT"),
        encoding="utf-8",
    )
    binding["sha256"] = subject.sha256_file(card)
    with pytest.raises(subject.RequalError, match="four-part identity mismatch"):
        subject.resolve_card_contract_binding(
            binding,
            manifest_dir=tmp_path,
            required=True,
            identity_label="7001:EURUSD.DWX:H1:POLICY_REPAIR",
            expected_identity=(7001, "EURUSD.DWX", "H1", "POLICY_REPAIR"),
        )


def test_target_job_requires_explicit_timeframe_and_variant_identity(
    tmp_path: Path,
) -> None:
    override = _override_row(tmp_path, timeframe="H1", variant_id="POLICY_REPAIR")
    overrides = {
        subject.promotion_identity_key(
            7001, "EURUSD.DWX", "H1", "POLICY_REPAIR"
        ): override
    }

    missing_timeframe = _manifest(
        tmp_path / "target_missing_timeframe.json",
        [_sleeve(variant_id="POLICY_REPAIR", magic_number=70010001)],
    )
    with pytest.raises(subject.RequalError, match="explicit manifest timeframe"):
        subject.build_jobs(
            missing_timeframe,
            tmp_path,
            None,
            overrides,
            qualification_mode=subject.TARGET_BINARY_REQUAL,
        )

    missing_variant = _manifest(
        tmp_path / "target_missing_variant.json",
        [_sleeve(timeframe="H1", magic_number=70010001)],
    )
    with pytest.raises(subject.RequalError, match="explicit manifest variant_id"):
        subject.build_jobs(
            missing_variant,
            tmp_path,
            None,
            overrides,
            qualification_mode=subject.TARGET_BINARY_REQUAL,
        )


def test_legacy_reference_identity_fails_closed_for_multiple_timeframes(
    tmp_path: Path,
) -> None:
    ex5, preset = _artifacts(tmp_path, "shared")
    jobs = [
        subject.Job(
            ordinal=index,
            ea_id=7001,
            symbol="EURUSD.DWX",
            ea_label="QM5_7001_test",
            timeframe=timeframe,
            live_ex5=ex5,
            live_preset=preset,
            manifest_trades=1,
            reference_stream=None,
        )
        for index, timeframe in enumerate(("H1", "H4"), start=1)
    ]
    with pytest.raises(subject.RequalError, match="legacy EA/symbol identity is ambiguous"):
        subject.bind_jobs_to_reference_snapshot(
            jobs,
            snapshot={"snapshot_root": str(tmp_path)},
            snapshot_rows={"7001:EURUSD.DWX": {"selected": {}}},
        )
