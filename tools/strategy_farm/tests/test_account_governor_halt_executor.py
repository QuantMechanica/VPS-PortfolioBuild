"""Tests for the file-based, EA-native governor enforcement executor.

Every test runs against a tmp "fake filesystem" (tmp FILE_COMMON + tmp sandbox
halt root + tmp manifest + tmp decisions dir). No test resolves, reads or writes
a real ``C:\\QM\\mt5\\T_Live`` path, the real live manifest, or the real receipt
dir. The contract asserted here:

- the halt file NAME the executor writes is exactly the one the deployed kill
  switch polls (parsed out of QM_KillSwitch.mqh at test time, so a rename of the
  MQL constant breaks this test rather than the live book);
- L1 is refused (the channel cannot express an entry freeze without a flatten),
  L2 is refused unless the over-action is explicitly authorized, L3 acts;
- writes are atomic, idempotent and latching, and refusals never partial-write;
- the halt latch is releasable only through an OWNER artifact carrying an exact
  written line;
- the adapter refusal matrix: policy / activation JSON / OWNER order / executor
  selection must ALL be present before anything executes.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
from pathlib import Path

from tools.strategy_farm import account_governor_action_adapter as adapter
from tools.strategy_farm import account_governor_halt_executor as halt
from tools.strategy_farm import account_portfolio_governor as governor


LOGIN = 4000090541
T0 = dt.datetime(2026, 9, 13, 8, 0, tzinfo=dt.UTC)
MQH = Path(__file__).resolve().parents[3] / "framework" / "include" / "QM" / "QM_KillSwitch.mqh"


# --------------------------------------------------------------------------- #
# fixtures: a fake filesystem + a real level-2/level-3 governor decision
# --------------------------------------------------------------------------- #
def _write_manifest(path: Path, sleeves: list[tuple[int, int, str]]) -> Path:
    payload = {
        "book": "DXZ_TEST",
        "status": "LIVE",
        "n_sleeves": len(sleeves),
        "sleeves": [
            {
                "ea_id": ea_id,
                "magic_number": magic,
                "symbol": symbol,
                "ea_label": f"QM5_{ea_id}_test",
            }
            for ea_id, magic, symbol in sleeves
        ],
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def _fake_fs(tmp_path: Path) -> dict[str, Path]:
    sandbox = tmp_path / "T_Live_fake" / "MQL5" / "Files" / "QM" / "halt"
    common = tmp_path / "Common_fake" / "Files" / "QM" / "halt"
    sandbox.mkdir(parents=True)
    common.mkdir(parents=True)
    manifest = _write_manifest(
        tmp_path / "manifest.json",
        [
            (13301, 133010010, "GDAXI.DWX"),
            (11165, 111650000, "EURUSD.DWX"),
            (11165, 111650003, "GBPUSD.DWX"),  # same ea_id on two symbols
        ],
    )
    return {
        "sandbox": sandbox,
        "common": common,
        "manifest": manifest,
        "receipts": tmp_path / "receipts",
        "decisions": tmp_path / "decisions",
    }


def _executor(fs: dict[str, Path], **kwargs) -> halt.HaltFileExecutor:
    params = {
        "manifest_path": fs["manifest"],
        "halt_dirs": (fs["sandbox"], fs["common"]),
        "receipt_dir": fs["receipts"],
        "book": "DXZ_TEST",
        "now_fn": lambda: T0,
    }
    params.update(kwargs)
    return halt.HaltFileExecutor(**params)


def _instruction(level: int, name: str = "CONTROLLED_FLATTEN_AUTHORIZED_DRY_RUN") -> dict:
    return {
        "decision_id": f"decision-{level}",
        "entry_freeze": True,
        "entry_freeze_signal_path": "unused-by-halt-executor",
        "cancel_order_tickets": [201],
        "flatten_position_tickets": [101] if level >= 3 else [],
        "decision_level": level,
        "decision_name": name,
    }


# --------------------------------------------------------------------------- #
# 1. the file NAME must be the one the deployed EA polls
# --------------------------------------------------------------------------- #
def test_halt_file_name_matches_the_deployed_kill_switch_constants() -> None:
    """Parse the MQL constants; the executor must write exactly those names."""
    src = MQH.read_text(encoding="utf-8", errors="replace")
    manual = re.search(r'StringFormat\("QM\\\\halt\\\\%d\.halt",\s*ea_id\)', src)
    portfolio = re.search(r'"QM\\\\halt\\\\portfolio_dd\.signal"', src)
    assert manual is not None, "manual halt template moved in QM_KillSwitch.mqh"
    assert portfolio is not None, "portfolio_dd signal name moved in QM_KillSwitch.mqh"

    # %d -> the ea_id, and the directory is QM\halt.
    assert halt.HALT_FILE_TEMPLATE.format(ea_id=13301) == "13301.halt"
    assert halt.HALT_DIR_RELPATH.replace("/", "\\") == "QM\\halt"
    assert halt.PORTFOLIO_DD_SIGNAL_RELPATH == "QM/halt/portfolio_dd.signal"

    # The kill switch trips on EXISTENCE of the manual halt file; it never reads
    # it (QM_KillSwitchFileExists). Body is forensic only, but must be ASCII.
    body = halt.halt_file_body(
        ea_id=13301,
        book="DXZ_TEST",
        decision_id="d",
        decision_level=3,
        decision_name="X",
        written_at_utc="2026-09-13T08:00:00+00:00",
    )
    body.encode("ascii")
    assert body.endswith("\r\n")
    assert "ea_id=13301" in body


def test_executor_never_writes_the_dd_guard_signal(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    receipt = _executor(fs).apply(_instruction(3))
    assert receipt["outcome"] == "EXECUTOR_APPLIED"
    for directory in (fs["sandbox"], fs["common"]):
        assert not (directory / "portfolio_dd.signal").exists()


# --------------------------------------------------------------------------- #
# 2. L1 / L2 / L3 mapping
# --------------------------------------------------------------------------- #
def test_level_1_entry_freeze_is_refused_and_writes_nothing(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    receipt = _executor(fs).apply(_instruction(1, "ENTRY_FREEZE"))
    assert receipt["refused"] is True
    assert receipt["refusal_reason"] == halt.LEVEL_L1_REFUSAL
    assert list(fs["sandbox"].glob("*.halt")) == []
    assert list(fs["common"].glob("*.halt")) == []


def test_level_2_over_action_refused_unless_explicitly_authorized(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    refused = _executor(fs).apply(_instruction(2, "PENDING_CANCEL_AND_ENTRY_FREEZE"))
    assert refused["refused"] is True
    assert refused["refusal_reason"] == halt.LEVEL_L2_REFUSAL
    assert list(fs["sandbox"].glob("*.halt")) == []

    allowed = _executor(fs, l2_over_action_authorized=True).apply(
        _instruction(2, "PENDING_CANCEL_AND_ENTRY_FREEZE")
    )
    assert allowed["outcome"] == "EXECUTOR_APPLIED"
    assert allowed["over_action_vs_decision"] is True


def test_level_3_writes_one_halt_file_per_distinct_ea_id_per_dir(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    receipt = _executor(fs).apply(_instruction(3))
    assert receipt["outcome"] == "EXECUTOR_APPLIED"
    # 3 manifest rows but only 2 distinct ea_ids: the manual halt file is keyed
    # on ea_id alone, so both slots of 11165 halt together.
    assert receipt["sleeve_count"] == 2
    assert receipt["target_count"] == 4  # 2 ea_ids x 2 halt dirs
    assert sorted(p.name for p in fs["sandbox"].glob("*.halt")) == ["11165.halt", "13301.halt"]
    assert sorted(p.name for p in fs["common"].glob("*.halt")) == ["11165.halt", "13301.halt"]
    for row in receipt["files_written"]:
        blob = Path(row["path"]).read_bytes()
        assert hashlib.sha256(blob).hexdigest() == row["sha256"]
    assert receipt["over_action_vs_decision"] is False
    assert Path(receipt["receipt_path"]).exists()
    assert b".tmp" not in b"".join(p.name.encode() for p in fs["sandbox"].iterdir())


# --------------------------------------------------------------------------- #
# 3. idempotence + latching
# --------------------------------------------------------------------------- #
def test_apply_is_idempotent_and_never_rewrites_an_existing_halt(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    ex = _executor(fs)
    first = ex.apply(_instruction(3))
    shas = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in fs["sandbox"].iterdir()}

    second = ex.apply(_instruction(3))
    assert second["idempotent_skip"] is True
    assert second["outcome"] == "EXECUTOR_IDEMPOTENT_NOOP"
    assert second["files_written"] == []
    assert len(second["files_already_latched"]) == len(first["files_written"])
    after = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in fs["sandbox"].iterdir()}
    assert after == shas


def test_pre_existing_halt_content_is_latched_not_overwritten(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    foreign = fs["sandbox"] / "13301.halt"
    foreign.write_text("source=QM5_13206\r\n", encoding="ascii", newline="")
    receipt = _executor(fs).apply(_instruction(3))
    assert foreign.read_bytes() == b"source=QM5_13206\r\n"
    latched_paths = {row["path"] for row in receipt["files_already_latched"]}
    assert str(foreign) in latched_paths
    assert receipt["outcome"] == "EXECUTOR_APPLIED"  # the other targets still got written


# --------------------------------------------------------------------------- #
# 4. fail-safe refusals: never a partial write
# --------------------------------------------------------------------------- #
def test_unreadable_manifest_refuses_and_writes_nothing(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    fs["manifest"].write_text("{ not json", encoding="utf-8")
    receipt = _executor(fs).apply(_instruction(3))
    assert receipt["refused"] is True
    assert receipt["refusal_reason"].startswith("manifest_unreadable:")
    assert list(fs["sandbox"].iterdir()) == []
    assert list(fs["common"].iterdir()) == []


def test_manifest_count_mismatch_and_bad_magic_are_refused(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    payload = json.loads(fs["manifest"].read_text(encoding="utf-8"))
    payload["n_sleeves"] = 99
    fs["manifest"].write_text(json.dumps(payload), encoding="utf-8")
    assert _executor(fs).apply(_instruction(3))["refusal_reason"].startswith(
        "manifest_sleeve_count_mismatch:"
    )

    payload["n_sleeves"] = len(payload["sleeves"])
    payload["sleeves"][0]["magic_number"] = 42  # not ea_id*10000+slot
    fs["manifest"].write_text(json.dumps(payload), encoding="utf-8")
    assert _executor(fs).apply(_instruction(3))["refusal_reason"].startswith(
        "manifest_magic_not_derived_from_ea_id:"
    )
    assert list(fs["sandbox"].iterdir()) == []


def test_missing_decision_level_is_refused(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    bad = _instruction(3)
    bad.pop("decision_level")
    receipt = _executor(fs).apply(bad)
    assert receipt["refused"] is True
    assert receipt["refusal_reason"].startswith("decision_level_not_int:")
    assert list(fs["sandbox"].iterdir()) == []


# --------------------------------------------------------------------------- #
# 5. OWNER-only clear
# --------------------------------------------------------------------------- #
def _owner_clear_order(fs: dict[str, Path], *, date: str = "2026-09-13", line: str | None) -> Path:
    fs["decisions"].mkdir(parents=True, exist_ok=True)
    path = fs["decisions"] / f"{date}_owner_governor_halt_clear_dxz.md"
    body = "# OWNER clearance\n"
    if line is not None:
        body += line + "\n"
    path.write_text(body, encoding="utf-8")
    return path


def test_clear_requires_the_exact_owner_line(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    ex = _executor(fs)
    ex.apply(_instruction(3))
    assert len(list(fs["sandbox"].glob("*.halt"))) == 2

    no_line = _owner_clear_order(fs, line=None)
    refused = ex.clear(owner_clearance=no_line, today=dt.date(2026, 9, 13))
    assert refused["outcome"] == "CLEAR_REFUSED"
    assert refused["refusal_reason"].startswith("owner_clear_order_line_missing:")
    assert len(list(fs["sandbox"].glob("*.halt"))) == 2  # latch intact

    good = _owner_clear_order(fs, line="GOVERNOR-HALT: CLEAR DXZ 2026-09-13")
    applied = ex.clear(owner_clearance=good, today=dt.date(2026, 9, 13))
    assert applied["outcome"] == "CLEAR_APPLIED"
    assert len(applied["files_removed"]) == 4
    assert list(fs["sandbox"].glob("*.halt")) == []
    assert list(fs["common"].glob("*.halt")) == []


def test_clear_refuses_a_future_dated_or_misnamed_artifact(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    ex = _executor(fs)
    ex.apply(_instruction(3))

    future = _owner_clear_order(fs, date="2026-09-20", line="GOVERNOR-HALT: CLEAR DXZ 2026-09-20")
    assert ex.clear(owner_clearance=future, today=dt.date(2026, 9, 13))[
        "refusal_reason"
    ].startswith("owner_clear_order_future_dated:")

    misnamed = fs["decisions"] / "clearance.md"
    misnamed.write_text("GOVERNOR-HALT: CLEAR DXZ 2026-09-13\n", encoding="utf-8")
    assert ex.clear(owner_clearance=misnamed, today=dt.date(2026, 9, 13))[
        "refusal_reason"
    ].startswith("owner_clear_order_name_invalid:")
    assert len(list(fs["sandbox"].glob("*.halt"))) == 2


def test_clear_lists_but_never_deletes_the_ks_state_files(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    ex = _executor(fs)
    ex.apply(_instruction(3))
    state = fs["sandbox"] / "ks_state_13301_133010010.state"
    state.write_text("halted=1\n", encoding="ascii")
    good = _owner_clear_order(fs, line="GOVERNOR-HALT: CLEAR DXZ 2026-09-13")
    receipt = ex.clear(owner_clearance=good, today=dt.date(2026, 9, 13))
    assert str(state) in receipt["residual_ks_state_files_not_touched"]
    assert state.exists()


# --------------------------------------------------------------------------- #
# 6. read-only plan + CLI never applies
# --------------------------------------------------------------------------- #
def test_plan_is_read_only(tmp_path: Path) -> None:
    fs = _fake_fs(tmp_path)
    plan = _executor(fs).plan()
    assert plan["outcome"] == "PLAN_ONLY"
    assert plan["already_latched"] == 0
    assert plan["min_actionable_level"] == 3
    assert list(fs["sandbox"].iterdir()) == []


def test_cli_status_writes_nothing(tmp_path: Path, capsys) -> None:
    fs = _fake_fs(tmp_path)
    rc = halt.main(
        [
            "--status",
            "--manifest",
            str(fs["manifest"]),
            "--halt-dir",
            str(fs["sandbox"]),
            "--receipt-dir",
            str(fs["receipts"]),
        ]
    )
    assert rc == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["outcome"] == "PLAN_ONLY"
    assert list(fs["sandbox"].iterdir()) == []


# --------------------------------------------------------------------------- #
# 7. adapter refusal matrix through the real CLI, against the fake fs
# --------------------------------------------------------------------------- #
def _policy(path: Path, *, gross_ceiling: float) -> tuple[governor.BoundPolicy, str]:
    payload = {
        "schema": governor.POLICY_SCHEMA,
        "status": "OWNER_SIGNED",
        "authorized_by": "OWNER fixture",
        "account_login": LOGIN,
        "valid_from_utc": "2026-09-13T00:00:00Z",
        "valid_until_utc": "2026-09-14T00:00:00Z",
        "stage2_cancel_pending_authorized": True,
        "thresholds": {
            "min_free_margin_account": 1_000.0,
            "max_gross_leverage": gross_ceiling,
            "max_abs_currency_net_leverage": 5.0,
            "max_planned_stop_loss_account": 10_000.0,
        },
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    bound = governor._load_bound_policy(
        path, sha, schema=governor.POLICY_SCHEMA, now_utc=T0,
        expected_login=LOGIN, label="policy",
    )
    return bound, sha


def _activation(path: Path, *, trigger_sha: str) -> str:
    payload = {
        "schema": adapter.ACTIVATION_SCHEMA,
        "status": "OWNER_SIGNED",
        "authorized_by": "OWNER fixture",
        "account_login": LOGIN,
        "valid_from_utc": "2026-09-13T00:00:00Z",
        "valid_until_utc": "2026-09-14T00:00:00Z",
        "enforce_authorized": True,
        "trigger_policy_sha256": trigger_sha,
        "activation_decision_ref": "decisions/2026-09-13_owner_governor_enforce_dxz.md",
        "emergency_policy_sha256": None,
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _emergency(path: Path, *, trigger_sha: str) -> str:
    payload = {
        "schema": governor.EMERGENCY_SCHEMA,
        "status": "OWNER_SIGNED",
        "authorized_by": "OWNER fixture",
        "account_login": LOGIN,
        "valid_from_utc": "2026-09-13T00:00:00Z",
        "valid_until_utc": "2026-09-14T00:00:00Z",
        "flatten_authorized": True,
        "trigger_policy_sha256": trigger_sha,
        "incident_id": "INC-TEST-1",
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _snapshot(observed_at: str) -> dict:
    position = {
        "ticket": 101,
        "identifier": 1101,
        "magic": 133010010,
        "symbol": "GDAXI",
        "type": "BUY",
        "volume": 1.0,
        "price_open": 100.0,
        "price_current": 101.0,
        "sl": 95.0,
        "tp": 110.0,
        "profit": 100.0,
        "swap": 0.0,
        "base_currency": "EUR",
        "profit_currency": "USD",
        "notional_account_ok": True,
        "signed_notional_account": 10_000.0,
        "stop_loss_account_ok": True,
        "remaining_loss_to_sl_account": 250.0,
    }
    order = {"ticket": 201, "magic": 111650000, "symbol": "EURUSD", "type": "BUY_STOP"}
    return {
        "schema": governor.SNAPSHOT_SCHEMA,
        "account_login": LOGIN,
        "time_utc": observed_at,
        "equity": 100_000.0,
        "balance": 99_500.0,
        "margin": 5_000.0,
        "free_margin": 95_000.0,
        "open_positions": 1,
        "pending_orders": 1,
        "reconciled_positions": 1,
        "reconciled_orders": 1,
        "reconciliation_complete": True,
        "gross_notional_account": 10_000.0,
        "net_directional_notional_account": 10_000.0,
        "planned_stop_loss_account": 250.0,
        "unpriced_positions": 0,
        "positions_without_stop": 0,
        "write_ok": True,
        "positions": [position],
        "orders": [order],
    }


def _enforce_scenario(tmp_path: Path) -> dict:
    """A fresh level-3 decision plus every OWNER artifact, all in tmp."""
    fs = _fake_fs(tmp_path)
    fs["decisions"].mkdir(parents=True, exist_ok=True)
    policy_path = tmp_path / "policy.json"
    bound, policy_sha = _policy(policy_path, gross_ceiling=0.01)  # trivially breached
    activation_path = tmp_path / "activation.json"
    activation_sha = _activation(activation_path, trigger_sha=policy_sha)
    emergency_path = tmp_path / "emergency.json"
    emergency_sha = _emergency(emergency_path, trigger_sha=policy_sha)

    snapshot = _snapshot((T0 - dt.timedelta(seconds=30)).strftime("%Y-%m-%dT%H:%M:%SZ"))
    emergency_bound = governor._load_bound_policy(
        emergency_path, emergency_sha, schema=governor.EMERGENCY_SCHEMA,
        now_utc=T0, expected_login=LOGIN, label="emergency_policy",
    )
    decision = governor.evaluate(
        snapshot, now_utc=T0, expected_login=LOGIN, max_age_seconds=90,
        policy=bound, emergency_policy=emergency_bound,
    )
    assert decision["decision"]["level"] == 3  # guard the fixture
    decision_path = tmp_path / "decision.json"
    decision_path.write_text(json.dumps(decision), encoding="utf-8")

    order_path = fs["decisions"] / "2026-09-13_owner_governor_enforce_dxz.md"
    order_path.write_text(
        "# OWNER enforce order\n\nGOVERNOR-ENFORCE: ACTIVATE DXZ 2026-09-13\n",
        encoding="utf-8",
    )
    fs.update(
        {
            "policy": policy_path,
            "policy_sha": policy_sha,
            "activation": activation_path,
            "activation_sha": activation_sha,
            "decision_json": decision_path,
            "order": order_path,
            "out": tmp_path / "adapter_receipts",
        }
    )
    return fs


def _cli(fs: dict, *extra: str) -> list[str]:
    return [
        "--enforce",
        "--decision", str(fs["decision_json"]),
        "--expected-login", str(LOGIN),
        "--now-utc", T0.isoformat(),
        "--out", str(fs["out"]),
        "--halt-manifest", str(fs["manifest"]),
        "--halt-dir", str(fs["sandbox"]),
        "--halt-dir", str(fs["common"]),
        "--halt-receipt-dir", str(fs["receipts"]),
        "--halt-book", "DXZ_TEST",
        *extra,
    ]


def _run(argv: list[str], capsys) -> dict:
    rc = adapter.main(argv)
    payload = json.loads(capsys.readouterr().out)
    payload["_rc"] = rc
    return payload


def test_adapter_refuses_without_bound_policy(tmp_path: Path, capsys) -> None:
    fs = _enforce_scenario(tmp_path)
    out = _run(
        _cli(fs, "--executor", "halt-file", "--enforce-order", str(fs["order"])), capsys
    )
    assert out["_rc"] == 3
    assert out["outcome"] == "ENFORCE_REFUSED"
    assert out["refusal_reason"] == "enforce_requires_bound_owner_policy"
    assert list(fs["sandbox"].iterdir()) == []


def test_adapter_refuses_without_activation_artifact(tmp_path: Path, capsys) -> None:
    fs = _enforce_scenario(tmp_path)
    out = _run(
        _cli(
            fs,
            "--policy", str(fs["policy"]),
            "--trusted-policy-sha256", fs["policy_sha"],
            "--executor", "halt-file",
            "--enforce-order", str(fs["order"]),
        ),
        capsys,
    )
    assert out["refusal_reason"] == "enforce_activation_artifact_absent"
    assert list(fs["sandbox"].iterdir()) == []


def test_adapter_refuses_without_owner_enforce_order(tmp_path: Path, capsys) -> None:
    fs = _enforce_scenario(tmp_path)
    out = _run(
        _cli(
            fs,
            "--policy", str(fs["policy"]),
            "--trusted-policy-sha256", fs["policy_sha"],
            "--activation", str(fs["activation"]),
            "--trusted-activation-sha256", fs["activation_sha"],
            "--executor", "halt-file",
        ),
        capsys,
    )
    assert out["outcome"] == "ENFORCE_REFUSED"
    assert out["refusal_reason"] == "enforce_order_artifact_absent"
    assert list(fs["sandbox"].iterdir()) == []


def test_adapter_refuses_an_enforce_order_without_the_exact_line(
    tmp_path: Path, capsys
) -> None:
    fs = _enforce_scenario(tmp_path)
    fs["order"].write_text("# OWNER enforce order\n\nplease activate\n", encoding="utf-8")
    out = _run(
        _cli(
            fs,
            "--policy", str(fs["policy"]),
            "--trusted-policy-sha256", fs["policy_sha"],
            "--activation", str(fs["activation"]),
            "--trusted-activation-sha256", fs["activation_sha"],
            "--executor", "halt-file",
            "--enforce-order", str(fs["order"]),
        ),
        capsys,
    )
    assert out["refusal_reason"].startswith("enforce_order_line_missing:")
    assert list(fs["sandbox"].iterdir()) == []


def test_adapter_refuses_when_the_executor_is_not_selected(tmp_path: Path, capsys) -> None:
    fs = _enforce_scenario(tmp_path)
    out = _run(
        _cli(
            fs,
            "--policy", str(fs["policy"]),
            "--trusted-policy-sha256", fs["policy_sha"],
            "--activation", str(fs["activation"]),
            "--trusted-activation-sha256", fs["activation_sha"],
            "--enforce-order", str(fs["order"]),
        ),
        capsys,
    )
    assert out["refusal_reason"] == "no_execution_adapter_present:executor_not_selected"
    assert out["execution_adapter_present"] is False
    assert list(fs["sandbox"].iterdir()) == []


def test_adapter_executes_when_all_four_gates_are_present(tmp_path: Path, capsys) -> None:
    fs = _enforce_scenario(tmp_path)
    argv = _cli(
        fs,
        "--policy", str(fs["policy"]),
        "--trusted-policy-sha256", fs["policy_sha"],
        "--activation", str(fs["activation"]),
        "--trusted-activation-sha256", fs["activation_sha"],
        "--executor", "halt-file",
        "--enforce-order", str(fs["order"]),
    )
    out = _run(argv, capsys)
    assert out["_rc"] == 0
    assert out["outcome"] == "ENFORCE_APPLIED"
    assert out["executed"] is True
    assert out["enforcement_activated"] is True
    assert out["execution_adapter_present"] is True
    action = out["actions_executed"][0]
    assert action["action_class"] == "SLEEVE_HALT_FLATTEN_CANCEL_AND_ENTRY_FREEZE"
    assert sorted(p.name for p in fs["sandbox"].glob("*.halt")) == [
        "11165.halt",
        "13301.halt",
    ]

    # rerun: same decision -> idempotent no-op, nothing rewritten
    again = _run(argv, capsys)
    assert again["outcome"] == "ENFORCE_APPLIED_IDEMPOTENT_NOOP"
    assert again["actions_executed"][0]["files_written"] == []


def test_adapter_reports_an_executor_refusal_as_a_refusal(tmp_path: Path, capsys) -> None:
    """A level-3 decision downgraded to level 1 must not read as 'applied'."""
    fs = _enforce_scenario(tmp_path)
    decision = json.loads(fs["decision_json"].read_text(encoding="utf-8"))
    decision["decision"]["level"] = 1
    decision["decision"]["name"] = "ENTRY_FREEZE"
    fs["decision_json"].write_text(json.dumps(decision), encoding="utf-8")
    out = _run(
        _cli(
            fs,
            "--policy", str(fs["policy"]),
            "--trusted-policy-sha256", fs["policy_sha"],
            "--activation", str(fs["activation"]),
            "--trusted-activation-sha256", fs["activation_sha"],
            "--executor", "halt-file",
            "--enforce-order", str(fs["order"]),
        ),
        capsys,
    )
    assert out["_rc"] == 3
    assert out["outcome"] == "ENFORCE_REFUSED_BY_EXECUTOR"
    assert out["refusal_reason"] == halt.LEVEL_L1_REFUSAL
    assert out["executed"] is False
    assert list(fs["sandbox"].iterdir()) == []


def test_default_dry_run_still_touches_no_halt_file(tmp_path: Path, capsys) -> None:
    fs = _enforce_scenario(tmp_path)
    out = _run(
        [
            "--dry-run",
            "--decision", str(fs["decision_json"]),
            "--expected-login", str(LOGIN),
            "--now-utc", T0.isoformat(),
            "--out", str(fs["out"]),
            "--executor", "halt-file",
            "--enforce-order", str(fs["order"]),
            "--halt-dir", str(fs["sandbox"]),
        ],
        capsys,
    )
    assert out["_rc"] == 0
    assert out["outcome"] == "DRY_RUN_PLAN"
    assert out["execution_adapter_present"] is False
    assert list(fs["sandbox"].iterdir()) == []
