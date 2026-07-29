import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]


def test_strategy_farm_modules_import_from_repo_package_namespace() -> None:
    modules = [
        "tools.strategy_farm.q09_news_contract",
        "tools.strategy_farm.q09_news_calendar",
        "tools.strategy_farm.q09_news_schema",
        "tools.strategy_farm.q09_news_runner",
        "tools.strategy_farm.q09_news_migration",
        "tools.strategy_farm.q10_confirmation_contract",
        "tools.strategy_farm.news_calendar_gate",
        "tools.strategy_farm.farmctl",
        "tools.strategy_farm.agent_router",
    ]
    script = "\n".join(
        [f"import sys; sys.path.insert(0, {str(REPO)!r})"]
        + [f"import {module}" for module in modules]
    )

    completed = subprocess.run(
        [sys.executable, "-I", "-c", script],
        cwd=REPO,
        capture_output=True,
        text=True,
        timeout=30,
    )

    assert completed.returncode == 0, completed.stderr
