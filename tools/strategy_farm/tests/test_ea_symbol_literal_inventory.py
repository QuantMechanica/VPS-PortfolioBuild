from pathlib import Path
import subprocess

from tools.strategy_farm.ea_symbol_literal_inventory import scan


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)


def test_symbol_literal_classification_and_cutover(tmp_path: Path):
    repo = tmp_path
    ea_root = repo / "framework/EAs/QM5_1000_fixture"
    include_root = repo / "framework/include/QM"
    ea_root.mkdir(parents=True)
    include_root.mkdir(parents=True)
    existing = ea_root / "QM5_1000_fixture.mq5"
    existing.write_text('string traded = "EURUSD.DWX";\n', encoding="utf-8")
    _git(repo, "init")
    _git(repo, "config", "user.email", "test@example.invalid")
    _git(repo, "config", "user.name", "test")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "cutover")
    baseline = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"], check=True, capture_output=True, text=True
    ).stdout.strip()

    existing.write_text(
        'input string strategy_symbol_1 = "EURUSD";\n'
        'string traded = "EURUSD.DWX";\n'
        '// QM_SYMBOL_LITERAL_ALLOW: GENERATED_SLOT_TABLE_BEGIN\n'
        'string slots[1] = {"GBPUSD.DWX"};\n'
        '// QM_SYMBOL_LITERAL_ALLOW: GENERATED_SLOT_TABLE_END\n',
        encoding="utf-8",
    )
    new_root = repo / "framework/EAs/QM5_1001_new"
    new_root.mkdir()
    (new_root / "QM5_1001_new.mq5").write_text(
        'void f(){ CopyRates("USDJPY", PERIOD_D1, 0, 2, rates); }\n', encoding="utf-8"
    )
    report = scan(repo, None, baseline, [1001])
    by_class = {(row["symbol"], row["classification"]): row for row in report["findings"]}
    assert by_class[("EURUSD", "symbol_input_default")]["severity"] == "ALLOW"
    assert by_class[("GBPUSD.DWX", "generated_slot_table")]["severity"] == "ALLOW"
    assert by_class[("EURUSD.DWX", "trading_logic_literal")]["severity"] == "WARN"
    assert by_class[("USDJPY", "trading_logic_literal")]["severity"] == "FAIL"
    assert report["summary"]["non_chart_market_data_sources"] == 1
    assert report["multi_symbol_sources"][0]["priority_candidate"] is True


def test_build_check_calls_single_file_based_scanner():
    source = Path("C:/QM/repo/framework/scripts/build_check.ps1").read_text(encoding="utf-8")
    assert "EA_SYMBOL_HARDCODED" in source
    assert "ea_symbol_literal_inventory.py" in source
    assert source.count("ea_symbol_literal_inventory.py") == 1
