from __future__ import annotations

from pathlib import Path

from tools.strategy_farm import audit_pattern_target_management as audit


def _write_ea(root: Path, name: str, body: str | None) -> None:
    directory = root / "framework" / "EAs" / name
    directory.mkdir(parents=True)
    if body is not None:
        (directory / f"{name}.mq5").write_text(body, encoding="utf-8")


def test_audit_enumerates_every_selected_directory_and_exact_disposition(tmp_path: Path) -> None:
    _write_ea(tmp_path, "QM5_1_alpha-pattern", "void Strategy_ManageOpenPosition() {}")
    _write_ea(
        tmp_path,
        "QM5_2_beta-wave",
        "void Strategy_ManageOpenPosition() { double p=PositionGetDouble(POSITION_PRICE_OPEN); }",
    )
    _write_ea(
        tmp_path,
        "QM5_3_gamma-fib",
        """
        double g_position_D=0.0, g_position_C=0.0;
        bool Strategy_EntrySignal() { g_position_D=2.0; g_position_C=1.0; return true; }
        void Strategy_ManageOpenPosition() {
          double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
          double t1=g_position_D+0.382*(g_position_C-g_position_D);
          if(bid>=t1) QM_TM_PartialClose(1,0.5,QM_EXIT_STRATEGY);
        }
        """,
    )
    _write_ea(tmp_path, "QM5_4_plain", "void Strategy_ManageOpenPosition() {}")
    _write_ea(tmp_path, "QM5_5_no-source-harmonic", None)

    first = audit.build_audit(tmp_path)
    second = audit.build_audit(tmp_path)
    assert audit.render_audit(first) == audit.render_audit(second)
    assert first["counts"]["cohort_directories"] == 4
    assert first["counts"]["source_bearing_cohort_directories"] == 3

    dispositions = {row["ea"]: row["disposition"] for row in first["eas"]}
    assert dispositions == {
        "QM5_1_alpha-pattern": "EMPTY_MANAGEMENT_HOOK",
        "QM5_2_beta-wave": "MANAGEMENT_ANCHORED_TO_FILL",
        "QM5_3_gamma-fib": "UNANCHORED_SIGNAL_PROJECTION_TARGETS",
        "QM5_5_no-source-harmonic": "NO_MQ5_SOURCE",
    }


def test_comments_and_strings_do_not_create_false_defect_signature(tmp_path: Path) -> None:
    _write_ea(
        tmp_path,
        "QM5_10_comment-pattern",
        """
        void Strategy_ManageOpenPosition() {
          // g_position_D g_position_C SYMBOL_BID QM_TM_ClosePosition
          string ignored="POSITION_PRICE_OPEN g_position_D SYMBOL_ASK";
          int bars=1;
        }
        """,
    )
    result = audit.build_audit(tmp_path)
    assert result["eas"][0]["disposition"] == "OTHER_MANAGEMENT_NO_EXACT_SIGNATURE"
