from pathlib import Path


SOURCE = (
    Path(__file__).resolve().parents[3]
    / "framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1"
    / "QM5_11421_ohlc-daily-squeeze-reversal-d1.mq5"
)


def test_signature_panel_is_presentation_only_and_lifecycle_bound():
    text = SOURCE.read_text(encoding="utf-8")
    assert '#include <QM/QM_ChartPanel.mqh>' in text
    assert 'input bool   qm_show_chart_panel        = true;' in text
    assert 'input string qm_panel_build_hash        = "UNBOUND";' in text
    assert text.index("QM_FrameworkDeclareExecutionContract") < text.index(
        "g_qm_signature_panel.Initialize"
    )
    assert "EventSetTimer(5)" in text
    assert text.index("g_qm_signature_panel.Shutdown();") < text.index(
        'QM_LogEvent(QM_INFO, "DEINIT"'
    )
    assert text.count("g_qm_signature_panel.Refresh(snapshot)") == 1
    refresh_call = text.index("QM11421_RefreshChartPanel();")
    timer = text.index("void OnTimer()")
    trade = text.index("void OnTradeTransaction")
    assert timer < refresh_call < trade


def test_snapshot_uses_existing_framework_governance_state():
    text = SOURCE.read_text(encoding="utf-8")
    for token in (
        "g_qm_news_active", "g_qm_news_available", "g_qm_news_cache_verdict",
        "QM_FrameworkFridayCloseNow", "g_qm_ks_halted", "g_qm_risk_mode",
        "g_qm_risk_percent", "g_qm_risk_fixed", "g_qm_fw_initialized",
    ):
        assert token in text
