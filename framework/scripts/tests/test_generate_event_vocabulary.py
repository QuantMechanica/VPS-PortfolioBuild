from __future__ import annotations

import json
from pathlib import Path

from framework.scripts import generate_event_vocabulary as generator


def _write_source(repo_root: Path, relative: str, text: str) -> None:
    path = repo_root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def test_resolves_literal_const_ternary_and_logfatal(tmp_path: Path) -> None:
    _write_source(
        tmp_path,
        "framework/include/QM/QM_Errors.mqh",
        'const string CONST_EVENT = "CONST_EVENT";\n'
        'const string FATAL_EVENT = "FATAL_EVENT";\n',
    )
    _write_source(
        tmp_path,
        "framework/EAs/QM5_9999_fixture/QM5_9999_fixture.mq5",
        """
void Emit(const bool ok, const string dynamic_event)
  {
   QM_LogEvent(QM_INFO, "LITERAL_EVENT", "{}");
   QM_LogEvent(QM_INFO, CONST_EVENT, "{}");
   QM_LogEvent(ok ? QM_INFO : QM_WARN,
               ok ? "TERNARY_OK" : "TERNARY_WARN", "{}");
   QM_LogFatal(FATAL_EVENT, "{}");
   QM_LogEvent(QM_WARN, dynamic_event, "{}");
   // QM_LogEvent(QM_INFO, "COMMENTED_OUT", "{}");
  }
""",
    )

    registry = generator.generate_registry(tmp_path)

    assert registry["streams"]["qm_events"]["event_names"] == [
        "CONST_EVENT",
        "FATAL_EVENT",
        "LITERAL_EVENT",
        "TERNARY_OK",
        "TERNARY_WARN",
    ]
    assert registry["streams"]["q08_trades"]["event_names"] == ["TRADE_CLOSED"]
    assert registry["streams"]["q08_trades"]["envelope"] == "bare_trade_record"
    assert registry["unresolved_calls"] == [
        {
            "path": "framework/EAs/QM5_9999_fixture/QM5_9999_fixture.mq5",
            "line": 9,
            "callee": "QM_LogEvent",
            "event_expression": "dynamic_event",
        }
    ]


def test_render_is_deterministic_and_check_detects_drift(tmp_path: Path) -> None:
    _write_source(
        tmp_path,
        "framework/templates/fixture.mq5",
        'void Emit() { QM_LogEvent(QM_INFO, "Z_EVENT", "{}"); }\n',
    )
    output = tmp_path / "framework/registry/event_vocabulary.json"

    assert generator.main(["--repo-root", str(tmp_path), "--output", str(output)]) == 0
    first = output.read_bytes()
    assert generator.main(
        ["--repo-root", str(tmp_path), "--output", str(output), "--check"]
    ) == 0
    assert output.read_bytes() == first

    payload = json.loads(first)
    payload["streams"]["qm_events"]["event_names"] = []
    output.write_text(json.dumps(payload), encoding="utf-8")
    assert generator.main(
        ["--repo-root", str(tmp_path), "--output", str(output), "--check"]
    ) == 1


def test_same_file_const_wins_over_ambiguous_global_name(tmp_path: Path) -> None:
    _write_source(
        tmp_path,
        "framework/include/one.mqh",
        'const string SHARED_EVENT = "ONE";\n',
    )
    _write_source(
        tmp_path,
        "framework/include/two.mqh",
        'const string SHARED_EVENT = "TWO";\n'
        'void Emit() { QM_LogEvent(QM_INFO, SHARED_EVENT, "{}"); }\n',
    )

    registry = generator.generate_registry(tmp_path)

    assert registry["streams"]["qm_events"]["event_names"] == ["TWO"]
    assert registry["unresolved_calls"] == []
