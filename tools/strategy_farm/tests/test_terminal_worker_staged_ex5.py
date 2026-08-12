import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import terminal_worker  # noqa: E402


class StagedEx5Tests(unittest.TestCase):
    def _dispatch_fixture(
        self,
        root: Path,
        *,
        payload: dict,
        ea_label: str = "QM5_11421_fixture",
    ) -> tuple[dict, Path, Path]:
        ea_dir = root / "repo" / "framework" / "EAs" / ea_label
        setfile = ea_dir / "sets" / f"{ea_label}_EURUSD.DWX_D1_backtest.set"
        setfile.parent.mkdir(parents=True)
        setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
        source = ea_dir / f"{ea_label}.ex5"
        source.write_bytes(b"required canonical binary")
        item = {
            "ea_id": "QM5_11421",
            "setfile_path": str(setfile),
            "payload_json": json.dumps(payload),
        }
        return item, ea_dir, source

    def test_dispatch_gate_restages_known_dormant_divergent_terminals_serially(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            item, ea_dir, source = self._dispatch_fixture(root, payload={})
            required = hashlib.sha256(source.read_bytes()).hexdigest()
            item["payload_json"] = json.dumps(
                {"expected_ex5_sha256": required}
            )
            mt5_root = root / "mt5"
            divergent_terminals = ("T2", "T7", "T8", "T9")
            prior_hashes: dict[str, str] = {}
            for index, terminal in enumerate(divergent_terminals, start=1):
                destination = (
                    mt5_root
                    / terminal
                    / "MQL5"
                    / "Experts"
                    / "QM"
                    / f"{ea_dir.name}.ex5"
                )
                destination.parent.mkdir(parents=True)
                destination.write_bytes(f"stale-{index}".encode("ascii"))
                prior_hashes[terminal] = hashlib.sha256(
                    destination.read_bytes()
                ).hexdigest()

            with (
                patch.object(
                    terminal_worker.farmctl,
                    "_ea_dir_from_setfile_path",
                    return_value=ea_dir,
                ),
                patch.object(terminal_worker.farmctl, "MT5_ROOT", mt5_root),
            ):
                results = {
                    terminal: terminal_worker._prepare_staged_ex5(item, terminal)
                    for terminal in divergent_terminals
                }

            for terminal, result in results.items():
                destination = Path(result["destination_path"])
                self.assertEqual(destination.read_bytes(), source.read_bytes())
                self.assertEqual(result["required_sha256"], required)
                self.assertEqual(result["pre_run_sha256"], required)
                self.assertEqual(
                    result["preexisting_destination_sha256"],
                    prior_hashes[terminal],
                )
                self.assertTrue(result["copied"])
                self.assertTrue(result["restaged"])
                self.assertTrue(result["verified"])
                self.assertEqual(
                    result["binding_source"],
                    "work_item_expected_ex5_sha256",
                )

    def test_dispatch_gate_fails_closed_before_replacing_on_source_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            item, ea_dir, _source = self._dispatch_fixture(
                root,
                payload={"expected_ex5_sha256": "0" * 64},
            )
            mt5_root = root / "mt5"
            destination = (
                mt5_root
                / "T2"
                / "MQL5"
                / "Experts"
                / "QM"
                / f"{ea_dir.name}.ex5"
            )
            destination.parent.mkdir(parents=True)
            destination.write_bytes(b"preserve divergent evidence")

            with (
                patch.object(
                    terminal_worker.farmctl,
                    "_ea_dir_from_setfile_path",
                    return_value=ea_dir,
                ),
                patch.object(terminal_worker.farmctl, "MT5_ROOT", mt5_root),
                self.assertRaisesRegex(
                    ValueError, "dispatch_ex5_source_sha256_mismatch"
                ),
            ):
                terminal_worker._prepare_staged_ex5(item, "T2")

            self.assertEqual(destination.read_bytes(), b"preserve divergent evidence")

    def test_spawn_boundary_rechecks_worker_staged_destination_hash(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            item, ea_dir, source = self._dispatch_fixture(root, payload={})
            required = hashlib.sha256(source.read_bytes()).hexdigest()
            item["payload_json"] = json.dumps(
                {"expected_ex5_sha256": required}
            )
            mt5_root = root / "mt5"
            with (
                patch.object(
                    terminal_worker.farmctl,
                    "_ea_dir_from_setfile_path",
                    return_value=ea_dir,
                ),
                patch.object(terminal_worker.farmctl, "MT5_ROOT", mt5_root),
            ):
                staging = terminal_worker._prepare_staged_ex5(item, "T7")
                payload = {"staged_ex5": staging}
                self.assertIsNone(
                    terminal_worker.farmctl._worker_staged_ex5_spawn_failure(
                        payload,
                        terminal="T7",
                        ea_dir_name=ea_dir.name,
                    )
                )
                Path(staging["destination_path"]).write_bytes(b"late drift")
                failure = (
                    terminal_worker.farmctl._worker_staged_ex5_spawn_failure(
                        payload,
                        terminal="T7",
                        ea_dir_name=ea_dir.name,
                    )
                )

            self.assertEqual(
                failure["reason"],
                "worker_staged_ex5_destination_sha256_mismatch",
            )
            self.assertEqual(failure["expected_ex5_sha256"], required)

    def test_artifact_setfile_phase_runner_uses_registered_staged_ex5_basename(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            repo_root = root / "repo"
            ea_dir = (
                repo_root
                / "framework"
                / "EAs"
                / "QM5_12567_cum-rsi2-commodity"
            )
            ea_dir.mkdir(parents=True)
            (
                repo_root
                / "framework"
                / "EAs"
                / "QM5_12567_unregistered-decoy"
            ).mkdir()
            registry = repo_root / "framework" / "registry" / "magic_numbers.csv"
            registry.parent.mkdir(parents=True)
            registry.write_text(
                "ea_id,ea_slug,status\n12567,cum-rsi2-commodity,active\n",
                encoding="utf-8",
            )
            source = ea_dir / "QM5_12567_cum-rsi2-commodity.ex5"
            source.write_bytes(b"manifest-pinned diagnostic binary")
            required = hashlib.sha256(source.read_bytes()).hexdigest()

            setfile = (
                root
                / "strategy_farm"
                / "artifacts"
                / "q09_live_news_backfill_20260805"
                / "03_QM5_12567_XAUUSD"
                / "baseline"
                / "live_derived_diagnostic.set"
            )
            setfile.parent.mkdir(parents=True)
            setfile.write_text(
                "RISK_FIXED=1000\nRISK_PERCENT=0\n",
                encoding="utf-8",
            )
            mt5_root = root / "mt5"
            destination = (
                mt5_root
                / "T1"
                / "MQL5"
                / "Experts"
                / "QM"
                / "QM5_12567_cum-rsi2-commodity.ex5"
            )
            destination.parent.mkdir(parents=True)
            destination.write_bytes(source.read_bytes())
            item = {
                "id": "4f80a8cf-2cf9-53dd-b59c-414674f24f16",
                "phase": "Q09_NEWS",
                "ea_id": "QM5_12567",
                "symbol": "XAUUSD.DWX",
                "setfile_path": str(setfile),
                "payload_json": json.dumps(
                    {
                        "staged_ex5_path": str(source),
                        "staged_ex5_sha256": required,
                        "staged_ex5": {
                            "binding_source": "manifest_pinned_staged_ex5",
                            "source_path": str(source),
                            "destination_path": str(destination),
                            "required_sha256": required,
                            "pre_run_sha256": required,
                            "verified": True,
                        },
                    }
                ),
            }
            commands: list[list[str]] = []
            spawned_env: dict[str, str] = {}

            class FakeProc:
                pid = 12567

                def __init__(self, cmd, **kwargs):
                    commands.append([str(part) for part in cmd])
                    spawned_env.update(kwargs["env"])

            real_path = Path

            def path_proxy(value) -> Path:
                if str(value) == r"D:\QM\reports\work_items":
                    return root / "reports" / "work_items"
                return real_path(value)

            process_identity = {
                "process_creation_key": "test-creation-key",
                "process_image_path": sys.executable,
                "process_started_at_epoch": 1.0,
            }
            with (
                patch.object(terminal_worker.farmctl, "REPO_ROOT", repo_root),
                patch.object(terminal_worker.farmctl, "MT5_ROOT", mt5_root),
                patch.object(terminal_worker.farmctl, "Path", path_proxy),
                patch.object(
                    terminal_worker.farmctl,
                    "_ensure_phase_runner_inputs",
                    return_value=None,
                ),
                patch.object(
                    terminal_worker.farmctl,
                    "_phase_runner_inputs",
                    return_value={},
                ),
                patch.object(
                    terminal_worker.farmctl,
                    "_phase_runner_cmd_for_work_item",
                    return_value=[sys.executable, "q09_news_runner.py"],
                ),
                patch.object(
                    terminal_worker.farmctl,
                    "_work_item_artifact_repo_root",
                    return_value=repo_root,
                ),
                patch.object(
                    terminal_worker.farmctl,
                    "reap_finished_job_objects",
                    return_value=None,
                ),
                patch.object(
                    terminal_worker.farmctl,
                    "suspended_runner_creation_flags",
                    return_value=0,
                ),
                patch.object(
                    terminal_worker.farmctl,
                    "bind_spawned_process_to_kill_job",
                    return_value=process_identity,
                ),
                patch.object(terminal_worker.farmctl.subprocess, "Popen", FakeProc),
            ):
                result = terminal_worker.farmctl._spawn_phase_runner_for_work_item(
                    root / "strategy_farm",
                    item,
                    "T1",
                )

            self.assertTrue(result["spawned"])
            self.assertEqual(result["ea_dir_name"], ea_dir.name)
            self.assertNotEqual(
                result.get("reason"),
                "worker_staged_ex5_destination_path_mismatch",
            )
            self.assertEqual(len(commands), 1)
            self.assertEqual(spawned_env["QM_EXPECTED_EX5_SHA256"], required)

    def test_manifest_pinned_drift_keeps_existing_recovery_signature(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            pinned = root / "artifacts" / "pinned.ex5"
            pinned.parent.mkdir(parents=True)
            pinned.write_bytes(b"drifted pinned binary")
            item, ea_dir, _source = self._dispatch_fixture(root, payload={})
            item["payload_json"] = json.dumps(
                {
                    "staged_ex5_path": str(pinned.resolve()),
                    "staged_ex5_sha256": "0" * 64,
                }
            )
            mt5_root = root / "mt5"
            with (
                patch.object(
                    terminal_worker.farmctl,
                    "_ea_dir_from_setfile_path",
                    return_value=ea_dir,
                ),
                patch.object(terminal_worker.farmctl, "MT5_ROOT", mt5_root),
                self.assertRaisesRegex(
                    ValueError,
                    r"^staged_ex5_source_sha256_mismatch:[0-9a-f]{64}$",
                ),
            ):
                terminal_worker._prepare_staged_ex5(item, "T3")

    def test_legacy_row_acquires_binding_only_at_verified_dispatch_gate(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            item, ea_dir, source = self._dispatch_fixture(root, payload={})
            mt5_root = root / "mt5"
            with (
                patch.object(
                    terminal_worker.farmctl,
                    "_ea_dir_from_setfile_path",
                    return_value=ea_dir,
                ),
                patch.object(terminal_worker.farmctl, "MT5_ROOT", mt5_root),
            ):
                result = terminal_worker._prepare_staged_ex5(item, "T10")

            required = hashlib.sha256(source.read_bytes()).hexdigest()
            self.assertEqual(result["required_sha256"], required)
            self.assertEqual(result["source_sha256"], required)
            self.assertEqual(result["pre_run_sha256"], required)
            self.assertEqual(result["binding_source"], "canonical_ex5_at_dispatch")

    def test_run_smoke_skip_path_requires_and_verifies_expected_hash(self) -> None:
        script = (
            REPO / "framework" / "scripts" / "run_smoke.ps1"
        ).read_text(encoding="utf-8-sig")
        self.assertIn(
            "[string]$ExpectedExpertSha256 = $env:QM_EXPECTED_EX5_SHA256",
            script,
        )
        self.assertIn(
            "SkipExpertDeploy requires ExpectedExpertSha256",
            script,
        )
        self.assertIn("required/deployed SHA256 mismatch", script)

    def test_post_run_hashes_are_persisted_in_summary(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            binary = root / "probe.ex5"
            binary.write_bytes(b"historical binary")
            digest = hashlib.sha256(binary.read_bytes()).hexdigest()
            summary = root / "reports" / "QM5_9936" / "run" / "summary.json"
            summary.parent.mkdir(parents=True)
            summary.write_text('{"verdict":"PASS"}', encoding="utf-8")
            payload = {
                "report_root": str(root / "reports"),
                "staged_ex5": {
                    "source_path": str(binary),
                    "destination_path": str(binary),
                    "required_sha256": digest,
                    "pre_run_sha256": digest,
                },
            }

            result = terminal_worker._verify_and_record_staged_ex5(payload)

            self.assertTrue(result["verified"])
            recorded = json.loads(summary.read_text(encoding="utf-8"))
            self.assertEqual(recorded["staged_ex5"]["pre_run_sha256"], digest)
            self.assertEqual(recorded["staged_ex5"]["post_run_sha256"], digest)

    def test_post_run_hash_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            binary = Path(tmp) / "probe.ex5"
            binary.write_bytes(b"changed binary")
            payload = {
                "staged_ex5": {
                    "destination_path": str(binary),
                    "required_sha256": "0" * 64,
                    "pre_run_sha256": "0" * 64,
                },
            }
            with self.assertRaisesRegex(ValueError, "post_run_sha256_mismatch"):
                terminal_worker._verify_and_record_staged_ex5(payload)


if __name__ == "__main__":
    unittest.main()
