from __future__ import annotations

from types import SimpleNamespace

from framework.scripts import q07_multiseed


def test_completed_seed_cleanup_invokes_scoped_busy_mode(monkeypatch) -> None:
    seen = {}

    def fake_run(args, **kwargs):
        seen["args"] = args
        seen["kwargs"] = kwargs
        return SimpleNamespace(
            returncode=0,
            stdout="BUSY_SCRATCH_SUMMARY mode=APPLY reclaimed_gb=6.00",
            stderr="",
        )

    monkeypatch.setattr(q07_multiseed.subprocess, "run", fake_run)
    q07_multiseed._reclaim_completed_seed_scratch("T6")

    args = seen["args"]
    assert args[args.index("-Mode") + 1] == "BusyScratch"
    assert args[args.index("-Terminal") + 1] == "T6"
    assert args[args.index("-MinAgeMinutes") + 1] == "5"
    assert "-DryRun" not in args
    assert seen["kwargs"]["timeout"] == 120
