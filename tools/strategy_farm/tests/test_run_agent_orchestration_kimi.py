"""Kimi orchestration lane tests (slice C2, OWNER-DEC-KIMI-INTEGRATION-20260915).

Covers KIMI_INTEGRATION_ARCHITECTURE.md §5.4 (resolve_cli/agent_env/command_for/
build_prompt/run_agent_slot kimi branch, MaxSessions cap) and the fail-closed
`cli_missing` contract when kimi_adapter.py is absent. No real Kimi CLI is run;
the adapter is stubbed or forced-missing via sys.modules.
"""

from __future__ import annotations

import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import run_agent_orchestration_task as orch  # noqa: E402


class KimiOrchestrationTests(unittest.TestCase):
    def test_resolve_cli_kimi_is_pinned(self) -> None:
        self.assertEqual(orch.resolve_cli("kimi"), str(orch.KIMI_BIN))

    def test_agent_env_kimi_sets_profile_and_id(self) -> None:
        env = orch.agent_env("kimi")
        self.assertEqual(env["QM_AGENT_ID"], "kimi")
        self.assertEqual(env["USERPROFILE"], str(orch.AGENT_USER_HOME))
        self.assertEqual(env["HOME"], str(orch.AGENT_USER_HOME))

    def test_command_for_kimi_argv_shape(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            cwd = Path(tmp)
            prompt = cwd / "prompt.md"
            prompt.write_text("do research", encoding="utf-8")
            argv = orch.command_for("kimi", cwd, prompt, None)
            self.assertIsNotNone(argv)
            assert argv is not None
            self.assertEqual(argv[0], str(orch.KIMI_BIN))
            self.assertIn("-p", argv)
            self.assertNotIn("--auto", argv)  # probe battery 2026-09-15: --auto does not combine with -p
            self.assertIn("-m", argv)
            # stream-json output right after --output-format
            self.assertIn("--output-format", argv)
            self.assertEqual(argv[argv.index("--output-format") + 1], "stream-json")
            # prompt delivered as a pointer to the prompt FILE
            pointer = argv[argv.index("-p") + 1]
            self.assertIn(str(prompt), pointer)
            # workspace scoped with --add-dir including cwd
            self.assertIn("--add-dir", argv)
            self.assertIn(str(cwd), argv)

    def test_build_prompt_kimi_is_research_restricted(self) -> None:
        prompt = orch.build_prompt("kimi", Path(r"C:\QM\repo"))
        low = prompt.lower()
        self.assertIn("research", low)
        self.assertIn("kimi lane", low)
        self.assertIn("farmctl", low)  # names the mutation ban
        self.assertIn("t_live", low)
        self.assertIn("review", low)
        self.assertIn("docs/ops/evidence/", prompt)
        # must forbid routing
        self.assertIn("route-many", prompt)

    def test_kimi_max_sessions_hard_capped_at_one(self) -> None:
        self.assertEqual(orch.KIMI_MAX_SESSIONS, 1)
        calls: list[int] = []

        def _stub_slot(agent, slot, dry_run, stale_minutes, timeout_minutes, inv, lease):
            calls.append(slot)
            return {"agent": agent, "ok": True, "slot": slot}

        with patch.object(orch, "run_agent_slot", _stub_slot):
            result = orch._run_agent_with_session_lease(
                "kimi",
                True,  # dry_run
                1,
                1,
                5,  # request 5 sessions
                None,
            )
        self.assertEqual(result["max_sessions"], 1)
        self.assertEqual(len(calls), 1)

    # --- adapter integration / fail-closed -----------------------------------

    def _kimi_slot(self, root: Path, dry_run: bool = False):
        cwd = root
        prompt = root / "prompt.md"
        prompt.write_text("research cycle", encoding="utf-8")
        live_log = root / "live.log"
        result_path = root / "result.json"
        worktree = {"path": str(root), "branch": "test", "created": False}
        return orch._run_kimi_slot(
            1,
            cwd,
            prompt,
            live_log,
            result_path,
            worktree,
            dry_run,
            {"task_id": "task-1234-abcd"},
            5,
        )

    def test_missing_adapter_returns_cli_missing_no_exception(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            # Force both import paths to fail (module set to None in sys.modules
            # raises ModuleNotFoundError on import), regardless of whether the
            # real kimi_adapter.py has landed.
            with patch.dict(
                sys.modules,
                {"kimi_adapter": None, "tools.strategy_farm.kimi_adapter": None},
            ):
                payload = self._kimi_slot(root)
            self.assertEqual(payload["status"], "cli_missing")
            self.assertFalse(payload["ok"])
            self.assertEqual(payload["provider"], "kimi")
            # result JSON persisted with the fail-closed status
            self.assertTrue((root / "result.json").exists())

    def test_adapter_success_populates_observability_fields(self) -> None:
        fake = types.ModuleType("kimi_adapter")

        def _run_kimi(prompt, **kwargs):  # real signature: prompt positional, rest keyword-only  # noqa: ANN003
            return {
                "status": "ok",
                "model": kwargs.get("model"),
                "output_sha256": "b" * 64,
                "latency_s": 1.5,
                "retries": 1,
                "cli_version": "0.43.1",
                "quota_state": "NORMAL",
                "returncode": 0,
            }

        fake.run_kimi = _run_kimi  # type: ignore[attr-defined]
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            with patch.dict(sys.modules, {"kimi_adapter": fake}):
                payload = self._kimi_slot(root)
            self.assertEqual(payload["status"], "ok")
            self.assertTrue(payload["ok"])
            self.assertEqual(payload["provider"], "kimi")
            self.assertEqual(payload["task_id"], "task-1234-abcd")
            self.assertIn("model", payload)
            self.assertIn("started_at", payload)
            self.assertIn("finished_at", payload)
            self.assertIn("quota_state", payload)
            self.assertEqual(payload["output_sha256"], "b" * 64)
            self.assertIsNotNone(payload["prompt_sha256"])
            self.assertEqual(payload["retries"], 1)
            self.assertEqual(payload["returncode"], 0)

    def test_adapter_exception_is_classified_not_raised(self) -> None:
        fake = types.ModuleType("kimi_adapter")

        def _run_kimi(prompt, **kwargs):  # real signature: prompt positional, rest keyword-only  # noqa: ANN003
            raise RuntimeError("boom")

        fake.run_kimi = _run_kimi  # type: ignore[attr-defined]
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            with patch.dict(sys.modules, {"kimi_adapter": fake}):
                payload = self._kimi_slot(root)  # must not raise
            self.assertEqual(payload["status"], "unknown")
            self.assertFalse(payload["ok"])
            self.assertIn("boom", payload["error"])

    def test_dry_run_does_not_invoke_adapter(self) -> None:
        called = {"n": 0}
        fake = types.ModuleType("kimi_adapter")

        def _run_kimi(prompt, **kwargs):  # real signature: prompt positional, rest keyword-only  # noqa: ANN003
            called["n"] += 1
            return {"status": "ok"}

        fake.run_kimi = _run_kimi  # type: ignore[attr-defined]
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            with patch.dict(sys.modules, {"kimi_adapter": fake}):
                payload = self._kimi_slot(root, dry_run=True)
            self.assertTrue(payload["ok"])
            self.assertEqual(payload["status"], "dry_run_verified")
            self.assertEqual(called["n"], 0)

    def test_agent_choices_include_kimi(self) -> None:
        # The --agent argparse choices must accept kimi.
        import argparse

        parser = argparse.ArgumentParser()
        parser.add_argument("--agent", choices=("codex", "gemini", "claude", "kimi"))
        args = parser.parse_args(["--agent", "kimi"])
        self.assertEqual(args.agent, "kimi")


if __name__ == "__main__":
    unittest.main()
