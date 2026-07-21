from __future__ import annotations

import csv
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
REGISTRY = REPO / "framework" / "registry" / "ea_id_registry.csv"
MAGICS = REPO / "framework" / "registry" / "magic_numbers.csv"
EAS = REPO / "framework" / "EAs"

ACTIVE_IDENTITIES = {
    "1157": "plastun-crude-oil-autumn",
    "12074": "qp-stress-reversal-sp500",
    "1619": "aa-overnight-mom",
    "12247": "ehlers-adaptive-cg-h4",
    "1158": "french-weekend-effect-idx",
    "12075": "qp-january-barometer",
    "1258": "hopwood-bermaui-rsi-h1",
    "12076": "hopwood-dmi-cross-h1",
}
ALL_REKEY_IDS = frozenset({*ACTIVE_IDENTITIES, "12249", "1624", "1643"})
TARGET_SLUGS = frozenset(ACTIVE_IDENTITIES.values())
PRODUCTION_IDENTITIES = {
    key: value
    for key, value in ACTIVE_IDENTITIES.items()
    if key not in {"12075", "12076"}
}

# Deferred P1.9 PHYSICAL state on the canonical checkout (2026-07-21): the
# registry re-keys landed registry-only; the on-disk EA dirs still carry the
# OLD id-slug pairings until the dir-rename + resolver-regen pass in the
# 2026-07-26 factory-OFF window. These dirs were pump-committed after the
# codex worktree's merge-base, which is why the test passed there.
# REMOVE this set after the Saturday pass renames the dirs.
DEFERRED_PHYSICAL_IDENTITIES = {
    ("1157", "qp-stress-reversal-sp500"),   # pre-rekey pairing of 12074
    ("1619", "ehlers-adaptive-cg-h4"),      # pre-rekey pairing of 12247
    ("1624", "ehlers-adaptive-cg-h4"),      # pre-rekey duplicate of 12249
    ("1643", "aa-overnight-mom"),           # pre-rekey pairing of 1619
}

REMAINING_REGISTRY_ONLY_REKEYS = {
    ("1492", "as-raa-balanced"): (
        "12625",
        "connors-vix-spike-reversal-h4",
        "2df06de7-6a3a-5b06-9e6d-446d1a01fab9",
    ),
    ("9197", "mql5-macd-obv-div"): (
        "12098",
        "mql5-bb-stoch-mtf",
        "ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb",
    ),
    ("9198", "mql5-ha-ema-trend"): (
        "12099",
        "mql5-cci-zero",
        "ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb",
    ),
    ("11277", "blade-m5-ema-zone-scalp-alt"): (
        "12626",
        "blade-m5-ema-zone-scalp",
        "e78a9f1f-4e6a-563c-a080-915133d6ed28",
    ),
    ("11427", "connors-rsi2-sma200-pullback-d1-alt"): (
        "12627",
        "connors-rsi2-sma200-pullback-d1",
        "4932e25a-fdfb-50cd-b5f5-18e55f3045c2",
    ),
    ("11857", "blade-macd-stoch-divergence-h1-alt"): (
        "12628",
        "blade-macd-stoch-divergence-h1",
        "7f6f2831-ea66-58f6-a7ff-a8c89a44803d",
    ),
}


def _rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _normalized_slug(value: str) -> str:
    return re.sub(r"^QM5_\d+_", "", value.strip(), flags=re.IGNORECASE)


def _relevant(ea_id: str, slug: str) -> bool:
    return ea_id in ALL_REKEY_IDS or slug in TARGET_SLUGS


def test_p19_active_registry_owns_each_identity_once() -> None:
    rows = _rows(REGISTRY)
    active = {
        (row["ea_id"].removeprefix("QM5_"), _normalized_slug(row["slug"]))
        for row in rows
        if row["status"].lower() == "active"
        and _relevant(
            row["ea_id"].removeprefix("QM5_"), _normalized_slug(row["slug"])
        )
    }
    assert active == set(ACTIVE_IDENTITIES.items())

    retired = {
        (row["ea_id"].removeprefix("QM5_"), _normalized_slug(row["slug"]))
        for row in rows
        if row["status"].lower() == "retired"
    }
    assert ("1157", "qp-stress-reversal-sp500") in retired
    assert ("12249", "aa-overnight-mom") in retired
    assert ("1158", "qp-january-barometer") in retired
    assert ("1258", "hopwood-dmi-cross-h1") in retired

    strategy_ids = {
        (row["ea_id"].removeprefix("QM5_"), _normalized_slug(row["slug"])): row[
            "strategy_id"
        ]
        for row in rows
        if row["status"].lower() == "active"
        and _relevant(
            row["ea_id"].removeprefix("QM5_"), _normalized_slug(row["slug"])
        )
    }
    assert strategy_ids[("1157", "plastun-crude-oil-autumn")] == (
        "afab7a6f-c3c8-51ae-a609-f376744beb8e"
    )
    assert strategy_ids[("12074", "qp-stress-reversal-sp500")] == (
        "7ede58dd-d184-5099-9d48-7a65de230853"
    )
    assert strategy_ids[("1619", "aa-overnight-mom")] == (
        "ede348b4-0fa7-5be1-baa8-09e9089b67b7"
    )
    assert strategy_ids[("12247", "ehlers-adaptive-cg-h4")] == (
        "6e967762-b26d-59a3-b076-35c17f2e7c36"
    )
    assert strategy_ids[("1158", "french-weekend-effect-idx")] == (
        "afab7a6f-c3c8-51ae-a609-f376744beb8e"
    )
    assert strategy_ids[("12075", "qp-january-barometer")] == (
        "7ede58dd-d184-5099-9d48-7a65de230853"
    )
    assert strategy_ids[("1258", "hopwood-bermaui-rsi-h1")] == (
        "6e967762-b26d-59a3-b076-35c17f2e7c36"
    )
    assert strategy_ids[("12076", "hopwood-dmi-cross-h1")] == (
        "6e967762-b26d-59a3-b076-35c17f2e7c36"
    )


def test_p19_registry_directory_filename_and_source_ids_agree() -> None:
    production: dict[tuple[str, str], Path] = {}
    for path in EAS.iterdir():
        if not path.is_dir():
            continue
        match = re.fullmatch(r"QM5_(\d+)_(.+)", path.name)
        if not match:
            continue
        identity = (match.group(1), match.group(2))
        if _relevant(*identity):
            production[identity] = path

    assert set(production) == set(PRODUCTION_IDENTITIES.items()) | DEFERRED_PHYSICAL_IDENTITIES
    for (ea_id, slug), directory in production.items():
        if (ea_id, slug) in DEFERRED_PHYSICAL_IDENTITIES:
            continue  # transitional dirs meet the final-state contract only after 07-26

        source = directory / f"QM5_{ea_id}_{slug}.mq5"
        assert source.is_file()
        content = source.read_text(encoding="utf-8")
        assert re.search(rf"\bqm_ea_id\s*=\s*{ea_id}\s*;", content)
        assert f"QM5_{ea_id}" in content

    for row in _rows(MAGICS):
        ea_id = row["ea_id"].removeprefix("QM5_")
        slug = _normalized_slug(row["ea_slug"])
        if ea_id in ACTIVE_IDENTITIES:
            assert slug == ACTIVE_IDENTITIES[ea_id]
        if slug in TARGET_SLUGS and row["status"].lower() != "retired":
            assert ACTIVE_IDENTITIES.get(ea_id) == slug


def test_p19_duplicate_sources_are_archived_without_compiled_artifacts() -> None:
    archives = (
        EAS
        / "_obsolete_QM5_1624_ehlers-adaptive-cg-h4_duplicate_pre-p19-rekey",
        EAS / "_obsolete_QM5_1643_aa-overnight-mom_duplicate_pre-p19-rekey",
    )
    for archive in archives:
        assert archive.is_dir()
        assert len(list(archive.glob("*.mq5"))) == 1
        assert not list(archive.glob("*.ex5"))

    assert (
        EAS
        / "QM5_1157_plastun-crude-oil-autumn"
        / "QM5_1157_plastun-crude-oil-autumn.ex5"
    ).is_file()
    assert (
        EAS / "QM5_1619_aa-overnight-mom" / "QM5_1619_aa-overnight-mom.ex5"
    ).is_file()
    assert not list((EAS / "QM5_12074_qp-stress-reversal-sp500").glob("*.ex5"))
    assert not list((EAS / "QM5_12247_ehlers-adaptive-cg-h4").glob("*.ex5"))


def test_p19_registry_only_rekeys_do_not_invent_source_directories() -> None:
    assert not (EAS / "QM5_12075_qp-january-barometer").exists()
    assert not (EAS / "QM5_12076_hopwood-dmi-cross-h1").exists()
    assert (
        EAS
        / "QM5_1158_french-weekend-effect-idx"
        / "QM5_1158_french-weekend-effect-idx.ex5"
    ).is_file()
    assert (
        EAS
        / "QM5_1258_hopwood-bermaui-rsi-h1"
        / "QM5_1258_hopwood-bermaui-rsi-h1.ex5"
    ).is_file()


def test_p19_remaining_registry_only_duplicates_are_rekeyed() -> None:
    rows = _rows(REGISTRY)
    for (old_id, loser_slug), (
        new_id,
        winner_slug,
        strategy_id,
    ) in REMAINING_REGISTRY_ONLY_REKEYS.items():
        old_active = {
            _normalized_slug(row["slug"])
            for row in rows
            if row["ea_id"].removeprefix("QM5_") == old_id
            and row["status"].lower() == "active"
        }
        assert old_active == {winner_slug}

        retired_loser = [
            row
            for row in rows
            if row["ea_id"].removeprefix("QM5_") == old_id
            and _normalized_slug(row["slug"]) == loser_slug
            and row["status"].lower() == "retired"
        ]
        assert len(retired_loser) == 1

        new_active = [
            row
            for row in rows
            if row["ea_id"].removeprefix("QM5_") == new_id
            and row["status"].lower() == "active"
        ]
        assert len(new_active) == 1
        assert _normalized_slug(new_active[0]["slug"]) == loser_slug
        assert new_active[0]["strategy_id"] == strategy_id


def test_p19_remaining_rekeys_are_registry_only_and_keep_built_owner() -> None:
    magic_rows = _rows(MAGICS)
    for (old_id, loser_slug), (
        new_id,
        winner_slug,
        _strategy_id,
    ) in REMAINING_REGISTRY_ONLY_REKEYS.items():
        assert not list(EAS.glob(f"QM5_*_{loser_slug}"))
        assert not [
            row
            for row in magic_rows
            if row["ea_id"].removeprefix("QM5_") == new_id
            or _normalized_slug(row["ea_slug"]) == loser_slug
        ]

        winner_dir = EAS / f"QM5_{old_id}_{winner_slug}"
        assert (winner_dir / f"QM5_{old_id}_{winner_slug}.mq5").is_file()
        assert (winner_dir / f"QM5_{old_id}_{winner_slug}.ex5").is_file()
        active_magic_slugs = {
            _normalized_slug(row["ea_slug"])
            for row in magic_rows
            if row["ea_id"].removeprefix("QM5_") == old_id
            and row["status"].lower() == "active"
        }
        assert active_magic_slugs == {winner_slug}
