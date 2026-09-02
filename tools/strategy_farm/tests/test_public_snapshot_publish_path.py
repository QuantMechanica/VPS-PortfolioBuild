from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "scripts" / "run_public_snapshot_task.ps1"
EXPORTER = REPO_ROOT / "scripts" / "export_public_snapshot.ps1"
SYNC = REPO_ROOT / "scripts" / "sync_public_data_to_website.ps1"
LOADER = REPO_ROOT / "scripts" / "public_site" / "stats-loader.js"


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_publish_requires_exact_flag_or_exact_environment_value() -> None:
    text = _text(RUNNER)
    assert "[switch]$Publish" in text
    assert "QM_PUBLIC_PUBLISH -ceq '1'" in text
    assert "$publishRequested = [bool]$Publish -or" in text


def test_default_export_remains_no_git_and_staging_cannot_publish() -> None:
    runner = _text(RUNNER)
    exporter = _text(EXPORTER)
    assert "if (-not $publishRequested) { $exportArguments += '-NoGit' }" in runner
    assert "Git publication skipped for non-canonical OutputDir" in exporter
    assert "OrdinalIgnoreCase" in exporter


def test_validation_and_lock_release_precede_any_push() -> None:
    text = _text(RUNNER)
    release = text.index("$mutationLockStream.Dispose()")
    validate = text.index("'scripts\\validate_public_snapshot.ps1'")
    source_push = text.index("-Label 'git push public snapshot'")
    deploy_sync = text.index("'scripts\\sync_public_data_to_website.ps1'")
    assert release < validate < source_push < deploy_sync
    assert "'-Apply', '-Commit'" in text
    assert "if ($publishRequested) { $syncArguments += '-Push' }" in text


def test_deploy_sync_is_closed_allowlist_and_no_netlify_mutation() -> None:
    text = _text(SYNC)
    expected = {
        "public-snapshot.json",
        "process-roadmap.json",
        "strategy-archive.json",
        "company-operating-model.json",
        "stats.json",
        "public-snapshot.schema.v2.json",
        "process-roadmap.schema.json",
        "strategy-archive.schema.v2.json",
        "company-operating-model.schema.json",
        "public-stats.schema.json",
        "Website/scripts/stats-loader.js",
    }
    for name in expected:
        assert name in text
    assert "if ($Commit -and -not $Apply)" in text
    assert "if ($Push -and -not $Commit)" in text
    assert "netlify_toml_changed = $false" in text
    assert "netlify.toml'" not in text


def test_loader_uses_snapshot_first_with_sidecar_and_legacy_fallbacks() -> None:
    text = _text(LOADER)
    assert "const snapshotPath = '/public-data/public-snapshot.json';" in text
    assert "const statsPath = '/public-data/stats.json';" in text
    assert "const fallbackStatsPath = '/data/stats.json';" in text
    assert text.index("fetchJson(snapshotPath)") < text.index("fetchJson(statsPath)")
    assert "backtests_total: data.pipeline.work_items_total" in text
    assert "data.pipeline.by_gate_v4" in text
