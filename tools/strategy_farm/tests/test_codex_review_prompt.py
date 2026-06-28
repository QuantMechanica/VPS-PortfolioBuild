from pathlib import Path


PROMPT = (
    Path(__file__).resolve().parents[3]
    / "tools"
    / "strategy_farm"
    / "prompts"
    / "codex_review_ea.md"
)


def test_codex_review_prompt_allows_framework_basket_helper() -> None:
    text = PROMPT.read_text(encoding="utf-8")

    assert "basket_manifest.json" in text
    assert "QM_BasketOpenPosition" in text
    assert "off-chart" in text
    assert "`QM_TM_OpenPosition`/`QM_EntryRequest` are `_Symbol`-only" in text
    assert "raw `OrderSend` = FAIL" in text
    assert "hardcoded" in text.lower()


def test_codex_review_prompt_keeps_entry_new_bar_gate_required() -> None:
    text = PROMPT.read_text(encoding="utf-8")

    assert "New-bar gating uses `QM_IsNewBar()`" in text
    assert "must not gate entries" in text
    assert "replace the framework entry gate" in text
