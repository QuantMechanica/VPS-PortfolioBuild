"""Artifact builder contracts using temporary files and a fake compiler only.

Known provenance gaps are explicit xfails, not silently treated as verified.
No MetaEditor, terminal, account, deployment, or factory operation is executed.
"""

from pathlib import Path
from types import SimpleNamespace

import pytest

from tools.strategy_farm import console_canary_build as canary
from tools.strategy_farm import console_design_build as design


HELPERS = """
bool QM11421_ConsoleNewsKeyMatches(const int sample)
  { if(sample>0) { return true; } return false; }
QM_ConsoleGateState QM11421_ConsoleNewsObservation(const bool enabled)
  { return enabled?QM_GATE_PASS:QM_GATE_OFF; }
void QM11421_ConsoleGateAlerts(QM_ConsoleSnapshot &snapshot)
  { snapshot.alert_reason=""; }
"""


@pytest.fixture
def build_env(tmp_path, monkeypatch):
    repo = tmp_path / "repo"
    include = repo / "framework/include/QM"
    tests = repo / "framework/tests/mql5"
    include.mkdir(parents=True)
    tests.mkdir(parents=True)
    source = tests / "QM_Console_Visual_QA.mq5"
    source.write_text("#property strict\nvoid OnTick() {}\n", encoding="utf-8")
    for name in ("QM_ConsoleData_selftests.mqh", "QM_ChartPresentationV2_selftests.mqh",
                 "QM11421_ConsoleNews_selftests.mqh"):
        (tests / name).write_text("// " + name, encoding="utf-8")
    names = ("QM_ChartPanel.mqh", "QM_ConsoleModel.mqh", "QM_StrategyConsoleV2.mqh",
             "QM_ChartPresentationV2.mqh", "QM_ChartPanelCompare.mqh")
    for name in names:
        (include / name).write_text("// current " + name, encoding="utf-8")
    ea = repo / "framework/EA11421.mq5"
    ea.write_text(HELPERS, encoding="utf-8")
    ea.with_suffix(".ex5").write_bytes(b"factory-ex5-preserve")
    metaeditor = tmp_path / "MetaEditor64.exe"
    metaeditor.write_bytes(b"never-execute-this-fixture")
    allowed = tmp_path / "artifact-roots"
    allowed.mkdir()
    frozen = tmp_path / "frozen/MQL5"
    frozen_qm = frozen / "Include/QM"
    frozen_qm.mkdir(parents=True)
    (frozen_qm / "Trading.mqh").write_text("// pinned trading behavior", encoding="utf-8")
    (frozen_qm / "QM_ChartPanel.mqh").write_text("// old UI", encoding="utf-8")
    frozen_ex5 = frozen / "Experts/EA11421.ex5"
    frozen_ex5.parent.mkdir()
    frozen_ex5.write_bytes(b"installed-v4-ex5")
    for module in (design, canary):
        monkeypatch.setattr(module, "EA_SOURCE", ea)
        monkeypatch.setattr(module, "INCLUDE_ROOT", include)
        monkeypatch.setattr(module, "METAEDITOR", metaeditor)
    monkeypatch.setattr(design, "REPO", repo)
    monkeypatch.setattr(design, "SOURCE", source)
    monkeypatch.setattr(design, "NEWS_TESTS", tests / "QM11421_ConsoleNews_selftests.mqh")
    monkeypatch.setattr(design, "ALLOWED_ROOT", allowed)
    monkeypatch.setattr(design, "DEPENDENCIES", names[:2])
    monkeypatch.setattr(canary, "OVERRIDES", names)
    monkeypatch.setattr(canary, "FROZEN", frozen)
    monkeypatch.setattr(canary, "FROZEN_EXPERT", frozen_ex5)
    monkeypatch.setattr(canary, "FROZEN_EX5_SHA256", design.digest(frozen_ex5))
    calls = []

    def fake_compile(argv, **kwargs):
        calls.append((argv, kwargs))
        expert = Path(next(arg.removeprefix("/compile:") for arg in argv if arg.startswith("/compile:")))
        expert.with_suffix(".log").write_text("Result: 0 errors, 0 warnings\n", encoding="utf-16")
        expert.with_suffix(".ex5").write_bytes(b"mock-compiler-artifact")
        # MetaEditor native success can use returncode 1; its fresh log is key.
        return SimpleNamespace(returncode=1)

    monkeypatch.setattr(design.subprocess, "run", fake_compile)
    return SimpleNamespace(repo=repo, include=include, source=source, ea=ea, allowed=allowed,
                           frozen=frozen, frozen_ex5=frozen_ex5, calls=calls)


@pytest.mark.parametrize("name", ["compile_probe_test", "compile_probe_v2_123"])
def test_destination_accepts_only_a_fresh_direct_child(build_env, name):
    target = build_env.allowed / name
    assert design.validate_destination(target) == target.resolve()
    assert not target.exists()


@pytest.mark.parametrize("relative", ["other_name", "nested/compile_probe_test", "../compile_probe_escape"])
def test_destination_rejects_wrong_targets(build_env, relative):
    with pytest.raises(ValueError):
        design.validate_destination(build_env.allowed / relative)
    assert build_env.calls == []


def test_destination_rejects_reuse_without_overwriting(build_env):
    target = build_env.allowed / "compile_probe_existing"
    target.mkdir()
    marker = target / "preserve.txt"
    marker.write_text("preserve", encoding="utf-8")
    with pytest.raises(FileExistsError):
        design.validate_destination(target)
    assert marker.read_text(encoding="utf-8") == "preserve"


@pytest.mark.parametrize("variant", ["v1", "v2"])
def test_fixture_build_is_isolated_hidden_and_records_the_snapshot(build_env, variant):
    root = build_env.allowed / ("compile_probe_" + variant)
    receipt = design.compile_fixture(variant, root)
    assert receipt["status"] == "PASS" and receipt["artifact_only"]
    assert not receipt["installed"] and not receipt["terminal_started"]
    expert = Path(receipt["source"])
    source = expert.read_text(encoding="utf-8")
    assert "#define QM_CONSOLE_NEWS_SELFTEST" in source
    assert ("#define QM_CONSOLE_DESIGN_COMPARE" in source) == (variant == "v2")
    assert receipt["source_sha256"] == design.digest(expert)
    assert receipt["snapshot_hashes"]
    argv, kwargs = build_env.calls[0]
    assert "/portable" in argv and f"/include:{root / 'MQL5'}" in argv
    assert kwargs["startupinfo"].wShowWindow == 0
    assert kwargs["creationflags"] == design.subprocess.CREATE_NO_WINDOW
    assert build_env.ea.with_suffix(".ex5").read_bytes() == b"factory-ex5-preserve"


def test_production_helper_extraction_is_exact_and_rejects_missing_or_unbalanced():
    extracted = design.exact_news_helpers(HELPERS)
    assert extracted.split("\n\n", 1)[1].replace("\n\n", "\n").strip() == HELPERS.strip()
    with pytest.raises(ValueError, match="Missing exact production helper"):
        design.exact_news_helpers("void unrelated() {}")
    with pytest.raises(ValueError, match="Unbalanced production helper"):
        design.exact_news_helpers(HELPERS.rstrip().removesuffix("}"))


def test_canary_preserves_factory_binary_and_nested_non_ui_dependencies(build_env):
    root = build_env.allowed / "compile_probe_canary"
    receipt = canary.compile_canary(root)
    assert receipt["status"] == "PASS"
    assert receipt["factory_ex5_unchanged"] and not receipt["factory_invoked"]
    assert not receipt["installed"] and not receipt["terminal_started"]
    assert (root / "MQL5/Include/QM/Trading.mqh").read_bytes() == (build_env.frozen / "Include/QM/Trading.mqh").read_bytes()
    for name in canary.OVERRIDES:
        assert (root / "MQL5/Include/QM" / name).read_bytes() == (build_env.include / name).read_bytes()
    assert build_env.ea.with_suffix(".ex5").read_bytes() == b"factory-ex5-preserve"


def test_canary_rejects_wrong_reference_binary_before_any_compile(build_env):
    build_env.frozen_ex5.write_bytes(b"wrong-v4")
    with pytest.raises(ValueError, match="Frozen dependency reference"):
        canary.compile_canary(build_env.allowed / "compile_probe_wrong_reference")
    assert build_env.calls == []


@pytest.mark.parametrize("kind", ["source", "ui"])
def test_canary_detects_mutation_while_snapshotting(build_env, monkeypatch, kind):
    original = canary.shutil.copy2
    victim = build_env.ea if kind == "source" else build_env.include / canary.OVERRIDES[0]

    def mutate_after_copy(src, dst, *args, **kwargs):
        result = original(src, dst, *args, **kwargs)
        if Path(src) == victim:
            victim.write_text("// concurrent change", encoding="utf-8")
        return result

    monkeypatch.setattr(canary.shutil, "copy2", mutate_after_copy)
    with pytest.raises(RuntimeError, match="changed while snapshotting"):
        canary.compile_canary(build_env.allowed / ("compile_probe_race_" + kind))
    assert build_env.calls == []


def test_canary_detects_non_ui_copy_drift(build_env, monkeypatch):
    original = canary.shutil.copytree

    def mutate_tree(src, dst, *args, **kwargs):
        result = original(src, dst, *args, **kwargs)
        if Path(src) == build_env.frozen / "Include":
            (Path(dst) / "QM/Trading.mqh").write_text("// wrong copied bytes", encoding="utf-8")
        return result

    monkeypatch.setattr(canary.shutil, "copytree", mutate_tree)
    with pytest.raises(RuntimeError, match="Non-UI frozen dependency drifted"):
        canary.compile_canary(build_env.allowed / "compile_probe_copy_drift")
    assert build_env.calls == []


def test_canary_rejects_unrecorded_added_non_ui_dependency(build_env, monkeypatch):
    original = canary.shutil.copytree

    def inject_tree(src, dst, *args, **kwargs):
        result = original(src, dst, *args, **kwargs)
        if Path(src) == build_env.frozen / "Include":
            (Path(dst) / "QM/Unrecorded.mqh").write_text("// absent from reference census", encoding="utf-8")
        return result

    monkeypatch.setattr(canary.shutil, "copytree", inject_tree)
    with pytest.raises(RuntimeError):
        canary.compile_canary(build_env.allowed / "compile_probe_added_dependency")


def test_canary_reports_historical_header_binding_as_unattested(build_env):
    (build_env.frozen / "Include/QM/Trading.mqh").write_text("// changed after v4 build", encoding="utf-8")
    assert design.digest(build_env.frozen_ex5) == canary.FROZEN_EX5_SHA256
    receipt = canary.compile_canary(build_env.allowed / "compile_probe_baseline_capture")
    # A historical manifest does not exist. Accept the artifact-only capture,
    # but never imply the unchanged EX5 authenticates neighboring header bytes.
    assert receipt["status"] == "PASS"
    assert receipt["historical_v4_include_binding"].startswith("not_attested:")
    assert receipt["non_ui_dependencies_match_captured_snapshot"]
    assert "non_ui_dependencies_unchanged" not in receipt


def test_fixture_rejects_copied_header_mismatch_even_if_repository_hash_stays_stable(build_env, monkeypatch):
    original = design.shutil.copy2
    victim = build_env.include / design.DEPENDENCIES[0]

    def corrupt_copy(src, dst, *args, **kwargs):
        result = original(src, dst, *args, **kwargs)
        if Path(src) == victim:
            Path(dst).write_text("// not the recorded input", encoding="utf-8")
        return result

    monkeypatch.setattr(design.shutil, "copy2", corrupt_copy)
    with pytest.raises(RuntimeError):
        design.compile_fixture("v2", build_env.allowed / "compile_probe_fixture_snapshot_drift")
