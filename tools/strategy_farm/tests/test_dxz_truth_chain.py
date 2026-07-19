import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import dxz_truth_chain  # noqa: E402


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write(path: Path, content: str | bytes) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(content, bytes):
        path.write_bytes(content)
    else:
        path.write_text(content, encoding="utf-8")
    return path


def _fixture(tmp_path: Path, *, bind: bool = True, live_binary: bytes = b"qualified-ex5") -> dict[str, Path]:
    repo = tmp_path / "repo"
    label = "QM5_4242_truth-test"
    ea_dir = repo / "framework" / "EAs" / label
    cards = tmp_path / "cards"
    stream_root = tmp_path / "streams"
    history_root = tmp_path / "T6"
    live_root = tmp_path / "T_Live"
    terminal = live_root / "MT5_Base"
    include_root = repo / "framework" / "Include"

    card = _write(cards / f"{label}.md", "# approved card\n")
    include = _write(include_root / "QM" / "QM_Common.mqh", "// include\n")
    mq5 = _write(
        ea_dir / f"{label}.mq5",
        '#include <QM/QM_Common.mqh>\nstring dependency="EURJPY.DWX";\n',
    )
    ex5 = _write(ea_dir / f"{label}.ex5", b"qualified-ex5")
    set_path = _write(
        ea_dir / "sets" / f"{label}_AUDUSD.DWX_H1_backtest.set",
        "strategy_tf=PERIOD_H1\n",
    )
    stream = _write(
        stream_root / "4242_AUDUSD_DWX.jsonl",
        "\n".join(
            [
                json.dumps(
                    {
                        "event": "TRADE_CLOSED",
                        "entry_time": 1577836800,
                        "time": 1577923200,
                        "net": 12.5,
                        "symbol": "AUDUSD.DWX",
                    }
                ),
                json.dumps(
                    {
                        "event": "TRADE_CLOSED",
                        "entry_time": 1609459200,
                        "time": 1609545600,
                        "net": -2.5,
                        "symbol": "AUDUSD.DWX",
                    }
                ),
            ]
        )
        + "\n",
    )
    live_ex5 = _write(
        terminal / "MQL5" / "Experts" / "Live EAs" / f"{label}.ex5",
        live_binary,
    )
    live_preset = _write(
        terminal
        / "MQL5"
        / "Presets"
        / "slot0_AUDUSD_H1_QM5_4242_truth-test_magic42420000_dxz_live.set",
        "RISK_PERCENT=0.25\nRISK_FIXED=0\n",
    )
    for symbol in ("AUDUSD.DWX", "EURJPY.DWX"):
        _write(
            history_root / "Tester" / "bases" / "Darwinex-Live" / "history" / symbol / "2020.hcs",
            f"bars-{symbol}".encode(),
        )
        _write(
            history_root / "Tester" / "bases" / "Darwinex-Live" / "ticks" / symbol / "202001.tkc",
            f"ticks-{symbol}".encode(),
        )
    cost = _write(tmp_path / "cost.json", '{"model":"test"}\n')

    sleeve = {
        "ea_id": 4242,
        "ea_label": label,
        "symbol": "AUDUSD.DWX",
        "magic_number": 42420000,
        "ex5_path": str(ex5),
        "backtest_set": str(set_path),
        "q08_stream": str(stream),
        "trades": 2,
        "set_file_expectation": {"RISK_PERCENT": "0.25", "RISK_FIXED": 0},
    }
    if bind:
        sleeve.update(
            {
                "strategy_card": str(card),
                "strategy_card_sha256": _sha(card),
                "qualified_ex5_sha256": _sha(ex5),
                "qualified_set_sha256": _sha(set_path),
                "qualified_stream_sha256": _sha(stream),
                "qualified_live_preset_sha256": _sha(live_preset),
            }
        )
    manifest = _write(
        tmp_path / "book.json",
        json.dumps({"book": "DXZ", "status": "FROZEN", "n_sleeves": 1, "sleeves": [sleeve]}),
    )
    return {
        "repo": repo,
        "cards": cards,
        "stream_root": stream_root,
        "history_root": history_root,
        "live_root": live_root,
        "terminal": terminal,
        "include_root": include_root,
        "cost": cost,
        "card": card,
        "include": include,
        "mq5": mq5,
        "ex5": ex5,
        "live_ex5": live_ex5,
        "live_preset": live_preset,
        "set": set_path,
        "stream": stream,
        "manifest": manifest,
    }


def _build(paths: dict[str, Path]) -> dict:
    return dxz_truth_chain.build_evidence(
        paths["manifest"],
        repo_root=paths["repo"],
        live_root=paths["live_root"],
        cards_roots=[paths["cards"]],
        stream_root=paths["stream_root"],
        history_roots=[paths["history_root"]],
        include_roots=[paths["include_root"]],
        cost_models=[paths["cost"]],
        generated_at=datetime(2026, 7, 15, tzinfo=timezone.utc),
    )


def test_build_evidence_closes_only_hash_bound_same_binary_chain(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)

    evidence = _build(paths)

    assert evidence["verdict"] == "PASS"
    assert evidence["summary"] == {
        "declared_sleeve_count": 1,
        "processed_sleeve_count": 1,
        "closed_count": 1,
        "unbound_count": 0,
        "failed_count": 0,
        "sleeves_with_unbound_bindings": 0,
        "unbound_binding_count": 0,
        "current_path_live_ex5_match_count": 1,
        "current_path_live_ex5_mismatch_count": 0,
        "unique_history_symbol_count": 2,
    }
    sleeve = evidence["sleeves"][0]
    assert sleeve["status"] == "CLOSED"
    assert sleeve["bindings"]["live_ex5_vs_qualified"]["status"] == "MATCH"
    assert sleeve["includes"]["file_count"] == 1
    assert sleeve["includes"]["aggregate_sha256"]
    assert sleeve["history_symbols"] == ["AUDUSD.DWX", "EURJPY.DWX"]
    assert all(row["aggregate_sha256"] for row in sleeve["history"])
    assert sleeve["q08_stream_stats"]["trade_count"] == 2
    assert sleeve["q08_stream_stats"]["net_sum"] == 10.0
    assert sleeve["q08_stream_stats"]["entry_from_utc"] == "2020-01-01T00:00:00Z"
    assert sleeve["q08_stream_stats"]["exit_to_utc"] == "2021-01-02T00:00:00Z"


def test_current_paths_without_declared_qualification_hashes_are_unbound(tmp_path: Path) -> None:
    paths = _fixture(tmp_path, bind=False)

    evidence = _build(paths)

    assert evidence["verdict"] == "UNBOUND"
    sleeve = evidence["sleeves"][0]
    assert sleeve["status"] == "UNBOUND"
    assert sleeve["bindings"]["live_ex5_vs_current_qualified_path_snapshot"]["status"] == "MATCH"
    assert sleeve["bindings"]["live_ex5_vs_qualified"]["status"] == "UNBOUND"
    assert "live_ex5_vs_qualified" in sleeve["unbound"]


def test_live_binary_mismatch_fails_bound_chain(tmp_path: Path) -> None:
    paths = _fixture(tmp_path, live_binary=b"different-live-ex5")

    evidence = _build(paths)

    assert evidence["verdict"] == "FAIL"
    sleeve = evidence["sleeves"][0]
    assert sleeve["status"] == "FAIL"
    assert sleeve["bindings"]["live_ex5_vs_qualified"]["status"] == "MISMATCH"
    assert "binding_live_ex5_vs_qualified_mismatch" in sleeve["issues"]


def test_strategy_card_hash_drift_fails_bound_chain(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    paths["card"].write_text("# changed after qualification\n", encoding="utf-8")

    evidence = _build(paths)

    assert evidence["verdict"] == "FAIL"
    sleeve = evidence["sleeves"][0]
    assert sleeve["bindings"]["strategy_card"]["status"] == "MISMATCH"
    assert "binding_strategy_card_mismatch" in sleeve["issues"]


def test_non_dwx_symbol_is_rejected(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    manifest = json.loads(paths["manifest"].read_text(encoding="utf-8"))
    manifest["sleeves"][0]["symbol"] = "AUDUSD"
    paths["manifest"].write_text(json.dumps(manifest), encoding="utf-8")

    evidence = _build(paths)

    assert evidence["verdict"] == "FAIL"
    assert "symbol_not_literal_dwx" in evidence["sleeves"][0]["issues"]


def test_bundle_is_atomic_refuses_overwrite_and_never_writes_under_live(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    evidence = _build(paths)
    before = {path: path.read_bytes() for path in paths["terminal"].rglob("*") if path.is_file()}
    output = tmp_path / "evidence" / "run-001"

    bundle = dxz_truth_chain.write_bundle(
        output,
        evidence,
        paths["manifest"],
        [paths["live_root"], paths["terminal"]],
    )

    assert Path(bundle["truth_chain"]).is_file()
    assert Path(bundle["sha256sums"]).is_file()
    assert {path: path.read_bytes() for path in paths["terminal"].rglob("*") if path.is_file()} == before
    with pytest.raises(FileExistsError):
        dxz_truth_chain.write_bundle(output, evidence, paths["manifest"], [paths["live_root"]])
    with pytest.raises(ValueError, match="inside live terminal tree"):
        dxz_truth_chain.write_bundle(
            paths["terminal"] / "forbidden",
            evidence,
            paths["manifest"],
            [paths["live_root"], paths["terminal"]],
        )


def test_history_fingerprint_detects_cross_sandbox_drift(tmp_path: Path) -> None:
    roots = [tmp_path / "DXZ_Truth_1", tmp_path / "DXZ_Truth_2"]
    for root in roots:
        _write(
            root / "Tester" / "bases" / "Darwinex-Live" / "history" / "EURUSD.DWX" / "2025.hcs",
            b"same-bars",
        )
        _write(
            root / "Tester" / "bases" / "Darwinex-Live" / "ticks" / "EURUSD.DWX" / "202501.tkc",
            b"same-ticks",
        )
    hasher = dxz_truth_chain.ArtifactHasher()

    matching = dxz_truth_chain.history_fingerprint("EURUSD.DWX", roots, hasher)

    assert matching["location_count"] == 2
    assert matching["consistent_across_roots"] is True
    _write(
        roots[1]
        / "Tester"
        / "bases"
        / "Darwinex-Live"
        / "ticks"
        / "EURUSD.DWX"
        / "202501.tkc",
        b"drifted-ticks",
    )
    drifted = dxz_truth_chain.history_fingerprint(
        "EURUSD.DWX", roots, dxz_truth_chain.ArtifactHasher()
    )
    assert drifted["consistent_across_roots"] is False


def test_live_preset_tag_selects_current_deployment_among_archives(tmp_path: Path) -> None:
    terminal = tmp_path / "T_Live" / "MT5_Base"
    old = _write(
        terminal / "MQL5" / "Presets" / "slot0_EURUSD_H1_QM5_42_x_magic420000_old.set",
        "RISK_FIXED=1\n",
    )
    current = _write(
        terminal / "MQL5" / "Presets" / "slot0_EURUSD_H1_QM5_42_x_magic420000_dxz23_live.set",
        "RISK_FIXED=0\n",
    )

    selected, candidates = dxz_truth_chain.discover_live_preset(
        420000,
        [terminal],
        "dxz23_live",
    )

    assert selected == current
    assert set(candidates) == {str(old), str(current)}
    assert dxz_truth_chain.compare_set_value(0.0, "0") is True
    assert dxz_truth_chain.compare_set_value(0.061407, "0.0614") is False


def _target_pair_fixture(tmp_path: Path) -> dict[str, object]:
    manifest_sha = "a" * 64
    summary = {
        "run_id": "target-run-a",
        "manifest_sha256": manifest_sha,
        "qualification_mode": dxz_truth_chain.TARGET_BINARY_REQUAL,
        "qualification_status": dxz_truth_chain.TARGET_SINGLE_RUN_STATUS,
    }
    summary["summary_sha256"] = dxz_truth_chain.canonical_json_sha(summary)
    summary_path = _write(
        tmp_path / "summary-a.json",
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
    )
    summary_artifact = dxz_truth_chain.ArtifactHasher().artifact(summary_path)
    pair = {
        "artifact_type": dxz_truth_chain.target_pair_gate.ARTIFACT_TYPE,
        "schema_version": dxz_truth_chain.target_pair_gate.SCHEMA_VERSION,
        "status": "PASS",
        "qualification_mode": dxz_truth_chain.TARGET_BINARY_REQUAL,
        "source_manifest_sha256": manifest_sha,
        "summary_a": {
            "path": str(summary_path),
            "file_sha256": summary_artifact["sha256"],
            "payload_sha256": summary["summary_sha256"],
            "run_id": summary["run_id"],
        },
        "summary_b": {
            "path": str(tmp_path / "summary-b.json"),
            "file_sha256": "b" * 64,
            "payload_sha256": "c" * 64,
            "run_id": "target-run-b",
        },
        "compared_sleeves": [
            {
                "ea_id": 1,
                "symbol": "EURUSD.DWX",
                "timeframe": "H1",
                "variant_id": "VARIANT_UNSPECIFIED",
                "status": "PASS",
                "identity_axes": {
                    name: "PASS"
                    for name in dxz_truth_chain.target_pair_gate.REQUIRED_IDENTITY_AXES
                },
            }
        ],
        "contracts": {
            name: {"status": "PASS", "hash_bound": True}
            for name in dxz_truth_chain.TARGET_PAIR_CONTRACTS
        },
        "identity_axes": {
            name: {
                "status": "PASS",
                "matched_sleeves": [
                    "1:EURUSD.DWX:H1:VARIANT_UNSPECIFIED"
                ],
                "missing_sleeves": [],
                "mismatched_sleeves": [],
                "invalid_sleeves": [],
            }
            for name in dxz_truth_chain.target_pair_gate.REQUIRED_IDENTITY_AXES
        },
        "runner_contract_gap": {
            "status": "CLOSED",
            "missing_required_axes": [],
        },
        "run_intervals": {
            "summary_a": {
                "started_utc": "2026-07-16T12:00:00+00:00",
                "finished_utc": "2026-07-16T12:10:00+00:00",
                "receipt_count": 1,
            },
            "summary_b": {
                "started_utc": "2026-07-16T13:00:00+00:00",
                "finished_utc": "2026-07-16T13:10:00+00:00",
                "receipt_count": 1,
            },
            "serial_non_overlapping": True,
        },
        "issues": [],
        "deployment_eligible": False,
    }
    pair["pair_payload_sha256"] = dxz_truth_chain.canonical_json_sha(pair)
    pair_path = _write(
        tmp_path / "target-pair.json",
        json.dumps(pair, indent=2, sort_keys=True) + "\n",
    )
    file_sha = _sha(pair_path)
    pair_sidecar_path = _write(
        pair_path.with_name(pair_path.name + ".sha256"),
        f"{file_sha}  {pair_path.name}\n",
    )
    binding = {
        "path": str(pair_path),
        "artifact_sha256": file_sha,
        "sha256": file_sha,
        "payload_sha256": pair["pair_payload_sha256"],
        "sidecar_path": str(pair_sidecar_path),
        "sidecar_sha256": _sha(pair_sidecar_path),
        "sidecar_declared_sha256": file_sha,
        "status": "PASS",
        "qualification_mode": dxz_truth_chain.TARGET_BINARY_REQUAL,
        "source_manifest_sha256": manifest_sha,
    }
    candidate = {
        "n_source_sleeves": 1,
        "source_manifest": {"sha256": manifest_sha},
        "source_target_reproducibility_pair": dict(binding),
        "evidence": {
            dxz_truth_chain.TARGET_PAIR_EVIDENCE_KEY: dict(binding),
        },
    }
    return {
        "candidate": candidate,
        "summary": summary,
        "summary_path": summary_path,
        "summary_artifact": summary_artifact,
        "pair": pair,
        "pair_path": pair_path,
        "pair_sidecar_path": pair_sidecar_path,
        "binding": binding,
        "manifest_sha": manifest_sha,
    }


def _refresh_target_pair_binding(fixture: dict[str, object]) -> None:
    pair = fixture["pair"]
    pair_path = fixture["pair_path"]
    pair_sidecar_path = fixture["pair_sidecar_path"]
    candidate = fixture["candidate"]
    assert isinstance(pair, dict)
    assert isinstance(pair_path, Path)
    assert isinstance(pair_sidecar_path, Path)
    assert isinstance(candidate, dict)
    pair.pop("pair_payload_sha256", None)
    pair["pair_payload_sha256"] = dxz_truth_chain.canonical_json_sha(pair)
    pair_path.write_text(
        json.dumps(pair, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    pair_sidecar_path.write_text(
        f"{_sha(pair_path)}  {pair_path.name}\n", encoding="utf-8"
    )
    binding = {
        "path": str(pair_path),
        "artifact_sha256": _sha(pair_path),
        "sha256": _sha(pair_path),
        "payload_sha256": pair["pair_payload_sha256"],
        "sidecar_path": str(pair_sidecar_path),
        "sidecar_sha256": _sha(pair_sidecar_path),
        "sidecar_declared_sha256": _sha(pair_path),
        "status": pair["status"],
        "qualification_mode": pair["qualification_mode"],
        "source_manifest_sha256": pair["source_manifest_sha256"],
    }
    candidate["source_target_reproducibility_pair"] = dict(binding)
    candidate["evidence"] = {
        dxz_truth_chain.TARGET_PAIR_EVIDENCE_KEY: dict(binding)
    }
    fixture["binding"] = binding


def _validate_target_pair_fixture(fixture: dict[str, object]) -> list[str]:
    candidate = fixture["candidate"]
    summary = fixture["summary"]
    summary_path = fixture["summary_path"]
    summary_artifact = fixture["summary_artifact"]
    manifest_sha = fixture["manifest_sha"]
    assert isinstance(candidate, dict)
    assert isinstance(summary, dict)
    assert isinstance(summary_path, Path)
    assert isinstance(summary_artifact, dict)
    pair, artifact, binding, issues = (
        dxz_truth_chain._validate_target_reproducibility_pair(
            candidate,
            manifest_path=summary_path,
            repo_root=summary_path.parent,
            hasher=dxz_truth_chain.ArtifactHasher(),
            summary=summary,
            summary_artifact=summary_artifact,
            expected_manifest_sha=manifest_sha,
        )
    )
    assert pair is not None
    assert artifact["exists"] is True
    assert binding is not None
    return issues


def test_target_pair_binding_is_re_read_and_fully_verified(tmp_path: Path) -> None:
    fixture = _target_pair_fixture(tmp_path)

    issues = _validate_target_pair_fixture(fixture)

    assert issues == []
    candidate = fixture["candidate"]
    binding = fixture["binding"]
    assert isinstance(candidate, dict)
    assert isinstance(binding, dict)
    adjudication = {
        "evidence": {
            dxz_truth_chain.TARGET_PAIR_EVIDENCE_KEY: dict(binding),
        }
    }
    assert (
        dxz_truth_chain._target_pair_adjudication_binding_issues(
            candidate["source_target_reproducibility_pair"], adjudication
        )
        == []
    )


def test_target_pair_file_tampering_fails_closed(tmp_path: Path) -> None:
    fixture = _target_pair_fixture(tmp_path)
    pair_path = fixture["pair_path"]
    assert isinstance(pair_path, Path)
    pair_path.write_text(pair_path.read_text(encoding="utf-8") + " ", encoding="utf-8")

    issues = _validate_target_pair_fixture(fixture)

    assert "target_reproducibility_pair_artifact_sha256_mismatch" in issues
    assert "target_pair_file_binding_mismatch" in issues


def test_target_pair_sidecar_is_required_fail_closed(tmp_path: Path) -> None:
    fixture = _target_pair_fixture(tmp_path)
    sidecar_path = fixture["pair_sidecar_path"]
    assert isinstance(sidecar_path, Path)
    sidecar_path.unlink()

    issues = _validate_target_pair_fixture(fixture)

    assert "target_pair_sidecar_missing_or_unreadable" in issues


def test_target_pair_sidecar_tampering_fails_closed(tmp_path: Path) -> None:
    fixture = _target_pair_fixture(tmp_path)
    sidecar_path = fixture["pair_sidecar_path"]
    pair_path = fixture["pair_path"]
    assert isinstance(sidecar_path, Path)
    assert isinstance(pair_path, Path)
    sidecar_path.write_text(f"{'d' * 64}  {pair_path.name}\n", encoding="ascii")

    issues = _validate_target_pair_fixture(fixture)

    assert "target_pair_sidecar_sha256_mismatch" in issues
    assert "target_pair_sidecar_artifact_sha256_mismatch" in issues
    assert "target_pair_sidecar_declared_binding_mismatch" in issues


@pytest.mark.parametrize(
    ("mutation", "expected_issue"),
    [
        ("runner_gap", "target_pair_runner_contract_gap_open"),
        ("run_overlap", "target_pair_run_intervals_not_serial"),
        ("identity_axis", "target_pair_identity_axis_not_pass"),
        ("identity_axis_missing", "target_pair_identity_axis_not_pass"),
        ("contract", "target_pair_contract_not_pass"),
        ("compared_sleeve", "target_pair_compared_sleeves_not_pass"),
        ("current_summary", "target_pair_current_summary_not_bound"),
    ],
)
def test_target_pair_semantic_mutations_fail_closed(
    tmp_path: Path, mutation: str, expected_issue: str
) -> None:
    fixture = _target_pair_fixture(tmp_path)
    pair = fixture["pair"]
    assert isinstance(pair, dict)
    if mutation == "runner_gap":
        pair["runner_contract_gap"] = {
            "status": "OPEN",
            "missing_required_axes": ["mtm"],
        }
    elif mutation == "run_overlap":
        pair["run_intervals"]["serial_non_overlapping"] = False
    elif mutation == "identity_axis":
        pair["identity_axes"]["mtm"]["status"] = "FAIL"
    elif mutation == "identity_axis_missing":
        pair["identity_axes"]["mtm"]["matched_sleeves"] = []
        pair["identity_axes"]["mtm"]["missing_sleeves"] = [
            "1:EURUSD.DWX:H1:VARIANT_UNSPECIFIED"
        ]
    elif mutation == "contract":
        pair["contracts"]["card"]["status"] = "FAIL"
    elif mutation == "compared_sleeve":
        pair["compared_sleeves"][0]["identity_axes"]["mtm"] = "MISSING"
    else:
        pair["summary_a"]["run_id"] = "some-other-run"
    _refresh_target_pair_binding(fixture)

    issues = _validate_target_pair_fixture(fixture)

    assert expected_issue in issues


def test_target_pair_adjudication_binding_must_match_candidate(tmp_path: Path) -> None:
    fixture = _target_pair_fixture(tmp_path)
    binding = fixture["binding"]
    assert isinstance(binding, dict)
    rebound = dict(binding)
    rebound["payload_sha256"] = "f" * 64

    issues = dxz_truth_chain._target_pair_adjudication_binding_issues(
        binding,
        {"evidence": {dxz_truth_chain.TARGET_PAIR_EVIDENCE_KEY: rebound}},
    )

    assert issues == ["adjudication_target_pair_binding_mismatch"]
