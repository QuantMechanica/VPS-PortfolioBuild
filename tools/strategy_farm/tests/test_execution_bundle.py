from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
STRATEGY_FARM = HERE.parent
sys.path.insert(0, str(STRATEGY_FARM))

import execution_bundle as eb  # noqa: E402


FILES = {
    "cards/QM5_TEST.md": b"strategy-card-v1\n",
    "src/QM5_TEST.mq5": b"#property strict\n",
    "include/Zeta.mqh": b"zeta\n",
    "include/nested/Alpha.mqh": b"alpha\n",
    "bin/QM5_TEST.ex5": b"compiled-ea\x00\x01",
    "sets/QM5_TEST.set": b"ENV=backtest\r\nRISK_FIXED=1000\r\n",
    "bin/metaeditor64.exe": b"compiler-binary",
    "bin/terminal64.exe": b"terminal-binary",
    "snapshots/symbol_spec.json": b'{"digits":5}\n',
    "snapshots/history.bin": b"history-snapshot",
    "models/cost_model.json": b'{"spread_points":"12"}\n',
    "calendar/calendar_bundle.json": b'{"coverage_end":"2026-12-31"}\n',
    "rulepacks/FTMO_V1.json": b'{"target":"FTMO"}\n',
}


def _populate(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    for relative, data in FILES.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def _kwargs(root: Path) -> dict[str, object]:
    return {
        "artifact_root": root,
        "git_commit_sha": "1" * 40,
        "git_tree_sha": "2" * 40,
        "strategy_card_path": Path("cards/QM5_TEST.md"),
        "mq5_path": Path("src/QM5_TEST.mq5"),
        "include_root": Path("include"),
        "ex5_path": Path("bin/QM5_TEST.ex5"),
        "setfile_path": Path("sets/QM5_TEST.set"),
        "effective_tester_inputs": {
            "deposit": "100000",
            "execution_mode": "EVERY_TICK_BASED_ON_REAL_TICKS",
            "from": "2021-01-01",
            "symbol": "EURUSD",
            "timeframe": "M15",
            "to": "2025-12-31",
        },
        "compiler_build": 5320,
        "compiler_version": "MetaEditor 5.00 build 5320",
        "compiler_binary_path": Path("bin/metaeditor64.exe"),
        "terminal_build": 5320,
        "terminal_version": "MetaTrader 5 build 5320",
        "terminal_binary_path": Path("bin/terminal64.exe"),
        "symbol_spec_snapshot_path": Path("snapshots/symbol_spec.json"),
        "history_snapshot_path": Path("snapshots/history.bin"),
        "cost_model_path": Path("models/cost_model.json"),
        "calendar_bundle_path": Path("calendar/calendar_bundle.json"),
        "rulepack_version": "FTMO_2S_100K_SWING_V1",
        "rulepack_path": Path("rulepacks/FTMO_V1.json"),
    }


@pytest.fixture
def built(tmp_path: Path) -> tuple[Path, dict[str, object], dict[str, object]]:
    root = tmp_path / "artifacts"
    _populate(root)
    kwargs = _kwargs(root)
    return root, kwargs, eb.build_execution_bundle(**kwargs)


def _resign(bundle: dict[str, object]) -> None:
    bundle["bundle_id"] = eb.canonical_sha256(
        {key: value for key, value in bundle.items() if key != "bundle_id"}
    )


def test_builder_binds_every_required_identity_and_sorts_recursively(built) -> None:
    root, _, bundle = built

    assert bundle["schema_version"] == eb.SCHEMA_VERSION
    assert bundle["git"] == {"commit_sha": "1" * 40, "tree_sha": "2" * 40}
    assert bundle["strategy_card"]["path"] == "cards/QM5_TEST.md"
    assert bundle["source"]["mq5"]["path"] == "src/QM5_TEST.mq5"
    assert bundle["source"]["ex5"]["path"] == "bin/QM5_TEST.ex5"
    assert bundle["tester"]["setfile"]["path"] == "sets/QM5_TEST.set"
    assert bundle["tester"]["compiler"]["build"] == 5320
    assert bundle["tester"]["terminal"]["build"] == 5320
    assert bundle["rulepack"]["version"] == "FTMO_2S_100K_SWING_V1"

    include_paths = [row["path"] for row in bundle["source"]["include_tree"]["files"]]
    assert include_paths == sorted(include_paths)
    assert include_paths == ["include/Zeta.mqh", "include/nested/Alpha.mqh"]
    assert len(bundle["source"]["include_tree"]["tree_sha256"]) == 64
    assert len(bundle["tester"]["effective_inputs"]["sha256"]) == 64
    assert len(bundle["bundle_id"]) == 64
    eb.verify_referenced_artifacts(bundle, root)


def test_identical_logical_inputs_are_byte_deterministic_across_roots(tmp_path: Path) -> None:
    left = tmp_path / "left"
    right = tmp_path / "right"
    _populate(left)
    _populate(right)

    first = eb.build_execution_bundle(**_kwargs(left))
    second_kwargs = _kwargs(right)
    second_kwargs["effective_tester_inputs"] = dict(
        reversed(list(second_kwargs["effective_tester_inputs"].items()))
    )
    second = eb.build_execution_bundle(**second_kwargs)

    assert first == second
    assert eb.canonical_json_bytes(first) == eb.canonical_json_bytes(second)


@pytest.mark.parametrize(
    "relative",
    [
        "cards/QM5_TEST.md",
        "src/QM5_TEST.mq5",
        "include/Zeta.mqh",
        "include/nested/Alpha.mqh",
        "bin/QM5_TEST.ex5",
        "sets/QM5_TEST.set",
        "bin/metaeditor64.exe",
        "bin/terminal64.exe",
        "snapshots/symbol_spec.json",
        "snapshots/history.bin",
        "models/cost_model.json",
        "calendar/calendar_bundle.json",
        "rulepacks/FTMO_V1.json",
    ],
)
def test_every_bound_artifact_byte_change_changes_bundle_id(
    built, relative: str
) -> None:
    root, kwargs, original = built
    path = root / relative
    path.write_bytes(path.read_bytes() + b"changed")

    changed = eb.build_execution_bundle(**kwargs)

    assert changed["bundle_id"] != original["bundle_id"]


@pytest.mark.parametrize(
    ("field", "changed"),
    [
        ("git_commit_sha", "3" * 40),
        ("git_tree_sha", "4" * 40),
        ("compiler_build", 5321),
        ("compiler_version", "MetaEditor 5.00 build 5321"),
        ("terminal_build", 5321),
        ("terminal_version", "MetaTrader 5 build 5321"),
        ("rulepack_version", "FTMO_2S_100K_SWING_V2"),
    ],
)
def test_every_bound_version_or_git_identity_changes_bundle_id(
    built, field: str, changed: object
) -> None:
    _, kwargs, original = built
    modified = dict(kwargs)
    modified[field] = changed

    assert eb.build_execution_bundle(**modified)["bundle_id"] != original["bundle_id"]


def test_effective_input_value_and_include_membership_change_bundle_id(built) -> None:
    root, kwargs, original = built
    changed_inputs = dict(kwargs)
    changed_inputs["effective_tester_inputs"] = {
        **kwargs["effective_tester_inputs"],
        "deposit": "200000",
    }
    input_changed = eb.build_execution_bundle(**changed_inputs)

    added = root / "include" / "new" / "More.mqh"
    added.parent.mkdir()
    added.write_bytes(b"new include")
    tree_changed = eb.build_execution_bundle(**kwargs)

    assert input_changed["bundle_id"] != original["bundle_id"]
    assert tree_changed["bundle_id"] != original["bundle_id"]


def test_create_new_writer_round_trips_and_never_overwrites(built, tmp_path: Path) -> None:
    root, _, bundle = built
    destination = tmp_path / "execution_bundle.json"

    assert eb.write_execution_bundle_create_new(bundle, destination) == destination
    original_bytes = destination.read_bytes()
    assert original_bytes == eb.canonical_json_bytes(bundle) + b"\n"
    assert eb.load_execution_bundle(destination, artifact_root=root) == bundle

    with pytest.raises(FileExistsError):
        eb.write_execution_bundle_create_new(bundle, destination)
    assert destination.read_bytes() == original_bytes


def test_loader_rejects_duplicate_keys_floats_constants_and_bom(built, tmp_path: Path) -> None:
    _, _, bundle = built
    canonical = eb.canonical_json_bytes(bundle).decode("utf-8")
    variants = {
        "duplicate": canonical.replace(
            '"schema_version":"qm.execution-bundle/v1"',
            '"schema_version":"qm.execution-bundle/v1","schema_version":"bad"',
            1,
        ),
        "float": canonical.replace('"build":5320', '"build":5320.5', 1),
        "nan": canonical.replace('"build":5320', '"build":NaN', 1),
        "bom": "\ufeff" + canonical,
    }

    for name, raw in variants.items():
        path = tmp_path / f"{name}.json"
        path.write_text(raw, encoding="utf-8")
        with pytest.raises(eb.ExecutionBundleError):
            eb.load_execution_bundle(path)


@pytest.mark.parametrize(
    "mutate",
    [
        lambda b: b.__setitem__("unexpected", True),
        lambda b: b["git"].__setitem__("unexpected", True),
        lambda b: b["source"]["mq5"].__setitem__("size", 123),
        lambda b: b["source"]["include_tree"].__setitem__("count", 2),
        lambda b: b["tester"].__setitem__("broker", "DXZ"),
        lambda b: b["tester"]["effective_inputs"]["parameters"][0].__setitem__(
            "type", "string"
        ),
        lambda b: b["tester"]["compiler"].__setitem__("path", "unhashed.exe"),
        lambda b: b["rulepack"].__setitem__("target", "FTMO"),
    ],
)
def test_extra_keys_fail_closed_even_with_recomputed_bundle_id(built, mutate) -> None:
    _, _, source = built
    bundle = copy.deepcopy(source)
    mutate(bundle)
    _resign(bundle)

    with pytest.raises(eb.ExecutionBundleError, match="key set mismatch"):
        eb.validate_execution_bundle(bundle)


def test_all_internal_and_outer_hashes_are_revalidated(built) -> None:
    _, _, source = built

    effective = copy.deepcopy(source)
    effective["tester"]["effective_inputs"]["parameters"][0]["value"] = "changed"
    _resign(effective)
    with pytest.raises(eb.ExecutionBundleError, match="effective_inputs.sha256 mismatch"):
        eb.validate_execution_bundle(effective)

    tree = copy.deepcopy(source)
    tree["source"]["include_tree"]["files"][0]["sha256"] = "0" * 64
    _resign(tree)
    with pytest.raises(eb.ExecutionBundleError, match="tree_sha256 mismatch"):
        eb.validate_execution_bundle(tree)

    outer = copy.deepcopy(source)
    outer["git"]["commit_sha"] = "3" * 40
    with pytest.raises(eb.ExecutionBundleError, match="bundle_id mismatch"):
        eb.validate_execution_bundle(outer)


def test_artifact_verification_detects_byte_drift_missing_and_extra_include(built) -> None:
    root, _, bundle = built
    (root / "models/cost_model.json").write_bytes(b"drift")
    with pytest.raises(eb.ExecutionBundleError, match="artifact SHA-256 mismatch"):
        eb.verify_referenced_artifacts(bundle, root)

    (root / "models/cost_model.json").write_bytes(FILES["models/cost_model.json"])
    (root / "calendar/calendar_bundle.json").unlink()
    with pytest.raises(eb.ExecutionBundleError, match="does not exist"):
        eb.verify_referenced_artifacts(bundle, root)

    (root / "calendar/calendar_bundle.json").write_bytes(
        FILES["calendar/calendar_bundle.json"]
    )
    (root / "include/Undeclared.mqh").write_bytes(b"extra")
    with pytest.raises(eb.ExecutionBundleError, match="include-tree membership"):
        eb.verify_referenced_artifacts(bundle, root)


@pytest.mark.parametrize(
    "path",
    [
        "/absolute/file",
        "C:/absolute/file",
        "dir\\file",
        "dir/../file",
        "dir/./file",
        "dir//file",
        "dir/",
    ],
)
def test_non_normalized_or_absolute_logical_paths_fail_closed(built, path: str) -> None:
    _, _, source = built
    bundle = copy.deepcopy(source)
    bundle["strategy_card"]["path"] = path
    _resign(bundle)
    with pytest.raises(eb.ExecutionBundleError, match="path"):
        eb.validate_execution_bundle(bundle)


def test_builder_rejects_outside_root_non_string_inputs_and_bool_build(
    built, tmp_path: Path
) -> None:
    _, kwargs, _ = built
    outside = tmp_path / "outside.md"
    outside.write_text("outside", encoding="utf-8")

    modified = dict(kwargs)
    modified["strategy_card_path"] = outside
    with pytest.raises(eb.ExecutionBundleError, match="outside artifact_root"):
        eb.build_execution_bundle(**modified)

    modified = dict(kwargs)
    modified["effective_tester_inputs"] = {"deposit": 100000}
    with pytest.raises(eb.ExecutionBundleError, match="exact string"):
        eb.build_execution_bundle(**modified)

    modified = dict(kwargs)
    modified["compiler_build"] = True
    with pytest.raises(eb.ExecutionBundleError, match="positive integer"):
        eb.build_execution_bundle(**modified)


def test_unsorted_duplicate_and_float_in_memory_values_fail_closed(built) -> None:
    _, _, source = built
    unsorted = copy.deepcopy(source)
    parameters = unsorted["tester"]["effective_inputs"]["parameters"]
    parameters[0], parameters[1] = parameters[1], parameters[0]
    unsorted["tester"]["effective_inputs"]["sha256"] = eb.canonical_sha256(parameters)
    _resign(unsorted)
    with pytest.raises(eb.ExecutionBundleError, match="uniquely sorted"):
        eb.validate_execution_bundle(unsorted)

    duplicate = copy.deepcopy(source)
    parameters = duplicate["tester"]["effective_inputs"]["parameters"]
    parameters[1]["name"] = parameters[0]["name"]
    duplicate["tester"]["effective_inputs"]["sha256"] = eb.canonical_sha256(parameters)
    _resign(duplicate)
    with pytest.raises(eb.ExecutionBundleError, match="uniquely sorted"):
        eb.validate_execution_bundle(duplicate)

    floating = copy.deepcopy(source)
    floating["tester"]["compiler"]["build"] = 5320.0
    with pytest.raises(eb.ExecutionBundleError, match="floating-point"):
        eb.validate_execution_bundle(floating)


def test_hash_and_git_formats_are_lowercase_and_exact(built) -> None:
    _, _, source = built

    uppercase_git = copy.deepcopy(source)
    uppercase_git["git"]["commit_sha"] = "A" * 40
    _resign(uppercase_git)
    with pytest.raises(eb.ExecutionBundleError, match="Git object ID"):
        eb.validate_execution_bundle(uppercase_git)

    short_hash = copy.deepcopy(source)
    short_hash["strategy_card"]["sha256"] = "0" * 63
    _resign(short_hash)
    with pytest.raises(eb.ExecutionBundleError, match="SHA-256"):
        eb.validate_execution_bundle(short_hash)


def test_schema_is_strict_and_every_object_shape_is_closed() -> None:
    schema_path = STRATEGY_FARM / "schemas" / "execution_bundle.v1.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))

    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["$id"] == eb.SCHEMA_VERSION
    assert schema["additionalProperties"] is False

    object_schemas: list[dict[str, object]] = []

    def visit(value: object) -> None:
        if isinstance(value, dict):
            if value.get("type") == "object":
                object_schemas.append(value)
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(schema)
    assert len(object_schemas) >= 10
    assert all(item.get("additionalProperties") is False for item in object_schemas)
