import json
import os
import sqlite3
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import r_eval_drain  # noqa: E402
import recover_r1_source_rejections as r1_recovery  # noqa: E402


def _ready_frontmatter(r1: str = "TIER_A", **updates: str) -> dict[str, str]:
    frontmatter = {
        "ea_id": "QM5_20061",
        "slug": "demo",
        "source_id": "SOURCE-DEMO",
        "g0_status": "APPROVED",
        "r1_track_record": r1,
        "r2_mechanical": "PASS",
        "r3_data_available": "PASS",
        "r4_ml_forbidden": "PASS",
        "expected_trades_per_year_per_symbol": "12",
    }
    frontmatter.update(updates)
    return frontmatter


def _write_card(path: Path, frontmatter: dict[str, str]) -> None:
    yaml = "\n".join(f"{key}: {value}" for key, value in frontmatter.items())
    path.write_text(f"---\n{yaml}\n---\n\n# Demo strategy\n", encoding="utf-8")


class RGateBuildReadinessTests(unittest.TestCase):
    def test_r1_classifications_and_lineaged_unknown_are_non_blocking(self) -> None:
        for value in ("PASS", "TIER_A", "TIER_B", "TIER_C", " tier_c "):
            with self.subTest(value=value):
                self.assertTrue(farmctl._card_r_gate_ready(_ready_frontmatter(value)))

        self.assertTrue(
            farmctl._card_r_gate_ready(_ready_frontmatter("UNKNOWN"))
        )
        self.assertFalse(
            farmctl._card_r_gate_ready(
                _ready_frontmatter("UNKNOWN", source_id="")
            )
        )
        self.assertFalse(
            farmctl._card_r_gate_ready(
                _ready_frontmatter("TIER_A", source_id="")
            )
        )
        self.assertTrue(farmctl._card_r_gate_ready(_ready_frontmatter("FAIL")))
        self.assertTrue(farmctl._card_r_gate_ready(_ready_frontmatter("")))

    def test_r2_through_r4_remain_strict_pass_gates(self) -> None:
        for key in farmctl.R_STRICT_PASS_FIELDS:
            with self.subTest(key=key):
                self.assertFalse(
                    farmctl._card_r_gate_ready(
                        _ready_frontmatter("TIER_C", **{key: "UNKNOWN"})
                    )
                )

    def test_priority_counts_tier_and_lineaged_unknown_like_legacy_pass(self) -> None:
        priorities = []
        for r1 in ("PASS", "TIER_A", "TIER_B", "TIER_C", "UNKNOWN"):
            row = {
                "payload_json": json.dumps(
                    {"frontmatter": _ready_frontmatter(r1)}
                ),
                "updated_at": "2026-07-23T00:00:00+00:00",
            }
            priorities.append(farmctl._card_build_priority(Path("."), row))
        self.assertEqual({priority[1] for priority in priorities}, {-4})

    def test_unbuilt_scan_accepts_five_digit_tiered_card(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            cards = root / "artifacts" / "cards_approved"
            eas = Path(tmp) / "repo" / "framework" / "EAs"
            cards.mkdir(parents=True)
            eas.mkdir(parents=True)
            card = cards / "QM5_20061_demo.md"
            _write_card(card, _ready_frontmatter())

            with mock.patch.object(farmctl, "FRAMEWORK_EAS_DIR", eas):
                detected = farmctl._detect_unbuilt_cards(root)

        self.assertEqual([item["ea_id"] for item in detected], ["QM5_20061"])

    def test_prebuild_normalizes_qm5_registry_ids_and_blocks_slug_conflicts(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            card_dir = root / "artifacts" / "cards_approved"
            registry_dir = Path(tmp) / "repo" / "framework" / "registry"
            card_dir.mkdir(parents=True)
            registry_dir.mkdir(parents=True)
            card = card_dir / "QM5_11897_demo.md"
            fm = _ready_frontmatter(
                ea_id="QM5_11897",
                slug="demo",
            )
            _write_card(card, fm)
            (registry_dir / "ea_id_registry.csv").write_text(
                "ea_id,slug,strategy_id,status,owner,created_at\n"
                "11897,other-slug,S1,active,Research,2026-07-23\n"
                "11377,demo,S2,active,Research,2026-07-23\n",
                encoding="utf-8",
            )
            (registry_dir / "magic_numbers.csv").write_text(
                "ea_id,magic\n",
                encoding="utf-8",
            )

            with mock.patch.object(farmctl, "REPO_ROOT", Path(tmp) / "repo"):
                result = farmctl.prebuild_validate_card(root, card, fm)

        self.assertIn(
            "ea_id_registry_slug_mismatch:QM5_11897:registry=other-slug:card=demo",
            result["errors"],
        )
        self.assertIn(
            "ea_slug_registry_owned_by_other_id:demo:owners=11377:card=QM5_11897",
            result["errors"],
        )


class LowTokenBuildRoutingTests(unittest.TestCase):
    def test_claude_g0_fallback_runs_only_with_real_free_capacity(self) -> None:
        self.assertTrue(
            farmctl._claude_g0_fallback_allowed(
                codex_unavailable=True,
                claude_disabled=False,
                claude_review_spawned=False,
                active_claude=1,
                claude_builds_spawned=1,
                max_parallel_claude=3,
            )
        )
        self.assertFalse(
            farmctl._claude_g0_fallback_allowed(
                codex_unavailable=True,
                claude_disabled=False,
                claude_review_spawned=False,
                active_claude=2,
                claude_builds_spawned=1,
                max_parallel_claude=3,
            )
        )
        self.assertFalse(
            farmctl._claude_g0_fallback_allowed(
                codex_unavailable=True,
                claude_disabled=False,
                claude_review_spawned=True,
                active_claude=1,
                claude_builds_spawned=1,
                max_parallel_claude=3,
            )
        )

    def test_free_claude_capacity_emits_tickets_when_codex_budget_is_zero(self) -> None:
        self.assertEqual(
            farmctl._auto_build_creation_slots(
                codex_spawn_budget=0,
                codex_builds_spawned=0,
                claude_fallback=True,
                claude_build_budget=2,
                claude_pending_eligible=0,
            ),
            2,
        )

    def test_existing_claude_candidates_reserve_capacity(self) -> None:
        self.assertEqual(
            farmctl._auto_build_creation_slots(
                codex_spawn_budget=0,
                codex_builds_spawned=0,
                claude_fallback=True,
                claude_build_budget=3,
                claude_pending_eligible=2,
            ),
            1,
        )
        self.assertEqual(
            farmctl._auto_build_creation_slots(
                codex_spawn_budget=0,
                codex_builds_spawned=0,
                claude_fallback=True,
                claude_build_budget=0,
                claude_pending_eligible=0,
            ),
            0,
        )

    def test_normal_codex_capacity_is_preserved_and_globally_capped(self) -> None:
        self.assertEqual(
            farmctl._auto_build_creation_slots(
                codex_spawn_budget=2,
                codex_builds_spawned=1,
                claude_fallback=False,
                claude_build_budget=9,
                claude_pending_eligible=0,
            ),
            1,
        )
        self.assertEqual(
            farmctl._auto_build_creation_slots(
                codex_spawn_budget=9,
                codex_builds_spawned=0,
                claude_fallback=False,
                claude_build_budget=0,
                claude_pending_eligible=0,
            ),
            farmctl.MAX_AUTO_CREATED_BUILDS_PER_PUMP,
        )

    def test_gemini_spawns_do_not_consume_codex_creation_capacity(self) -> None:
        # The caller deliberately passes only Codex spawns. A Gemini build uses
        # Gemini capacity and must not shrink the two free Codex slots.
        self.assertEqual(
            farmctl._auto_build_creation_slots(
                codex_spawn_budget=2,
                codex_builds_spawned=0,
                claude_fallback=False,
                claude_build_budget=0,
                claude_pending_eligible=0,
            ),
            2,
        )

    def test_claude_candidates_are_unique_and_require_card_path(self) -> None:
        def row(ea_id: str, **payload_updates: str) -> dict[str, str]:
            payload = {"ea_id": ea_id, "card_path": f"C:/{ea_id}.md"}
            payload.update(payload_updates)
            return {"payload_json": json.dumps(payload)}

        rows = [
            row("QM5_1"),
            row("QM5_1"),
            row("QM5_2", card_path=""),
            row("QM5_3"),
            row("QM5_4"),
        ]
        candidates = farmctl._claude_buildable_pending_rows(
            rows,
            excluded_eas={"QM5_3"},
            perma_blocked_eas={"QM5_4"},
        )
        payloads = [json.loads(item["payload_json"]) for item in candidates]
        self.assertEqual([payload["ea_id"] for payload in payloads], ["QM5_1"])

    def test_fresh_codex_log_excludes_task_from_claude_lane(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            logs = root / "logs"
            logs.mkdir(exist_ok=True)
            row = {
                "id": "task-live",
                "card_id": "QM5_20080",
                "payload_json": json.dumps({
                    "ea_id": "QM5_20080",
                    "card_path": "C:/QM5_20080.md",
                }),
            }
            (logs / "codex_build_task-live.live.log").write_text(
                "still running\n",
                encoding="utf-8",
            )
            in_flight = farmctl._in_flight_build_task_ids(root, [row])
            candidates = farmctl._claude_buildable_pending_rows(
                [row],
                in_flight_task_ids=in_flight,
            )

        self.assertEqual(in_flight, {"task-live"})
        self.assertEqual(candidates, [])

    def test_in_flight_ea_excludes_duplicate_sibling_task(self) -> None:
        rows = [
            {
                "id": "task-live",
                "card_id": "QM5_20081",
                "payload_json": json.dumps({
                    "ea_id": "QM5_20081",
                    "card_path": "C:/first.md",
                }),
            },
            {
                "id": "task-sibling",
                "card_id": "QM5_20081",
                "payload_json": json.dumps({
                    "ea_id": "QM5_20081",
                    "card_path": "C:/second.md",
                }),
            },
        ]
        candidates = farmctl._claude_buildable_pending_rows(
            rows,
            in_flight_task_ids={"task-live"},
        )
        self.assertEqual(candidates, [])

    def test_build_dispatch_claim_is_exclusive_per_ea(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            first = farmctl._acquire_build_dispatch_claim(
                root,
                ea_id="QM5_20082",
                task_id="task-a",
                agent="codex",
            )
            second = farmctl._acquire_build_dispatch_claim(
                root,
                ea_id="QM5_20082",
                task_id="task-b",
                agent="claude",
            )
            farmctl._release_build_dispatch_claim(first)
            third = farmctl._acquire_build_dispatch_claim(
                root,
                ea_id="QM5_20082",
                task_id="task-b",
                agent="claude",
            )
            farmctl._release_build_dispatch_claim(third)

        self.assertIsNotNone(first)
        self.assertIsNone(second)
        self.assertIsNotNone(third)

    def test_stale_malformed_dispatch_claim_is_reclaimable(self) -> None:
        for malformed in ("{truncated", "[]", "null", '"partial"'):
            with self.subTest(malformed=malformed):
                with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
                    root = Path(tmp)
                    claim_dir = root / "state" / "build_dispatch_claims"
                    claim_dir.mkdir(parents=True)
                    claim_path = claim_dir / "STRATEGY_FARM_GLOBAL_PUMP.lock"
                    claim_path.write_text(malformed, encoding="utf-8")
                    stale_time = time.time() - 7200
                    os.utime(claim_path, (stale_time, stale_time))

                    claim = farmctl._acquire_build_dispatch_claim(
                        root,
                        ea_id="STRATEGY_FARM_GLOBAL_PUMP",
                        task_id="pump-after-crash",
                        agent="controller",
                        stale_sec=60,
                    )
                    farmctl._release_build_dispatch_claim(claim)

                self.assertIsNotNone(claim)

    def test_global_pump_claim_skips_overlapping_cycle(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            claim = farmctl._acquire_build_dispatch_claim(
                root,
                ea_id="STRATEGY_FARM_GLOBAL_PUMP",
                task_id="pump-test-holder",
                agent="controller",
            )
            try:
                result = farmctl.pump(root)
            finally:
                farmctl._release_build_dispatch_claim(claim)

        self.assertIn("another strategy-farm pump", result["skipped"])

    def test_spawn_recheck_detects_in_flight_sibling_for_same_ea(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            with farmctl.connect(root) as conn:
                first_id = farmctl.create_task(
                    conn,
                    kind="build_ea",
                    source_id=None,
                    card_id="QM5_20083",
                    payload={
                        "ea_id": "QM5_20083",
                        "card_path": "C:/first.md",
                    },
                )
                second_id = farmctl.create_task(
                    conn,
                    kind="build_ea",
                    source_id=None,
                    card_id="QM5_20083",
                    payload={
                        "ea_id": "QM5_20083",
                        "card_path": "C:/second.md",
                    },
                )
                conn.commit()
                second = conn.execute(
                    "SELECT * FROM tasks WHERE id=?",
                    (second_id,),
                ).fetchone()
            logs = root / "logs"
            logs.mkdir(exist_ok=True)
            (logs / f"codex_build_{first_id}.live.log").write_text(
                "running\n",
                encoding="utf-8",
            )

            sibling = farmctl._other_in_flight_build_for_ea(root, second)

        self.assertEqual(sibling["task_id"], first_id)

    def test_dispatch_wrapper_does_not_spawn_stale_completed_task(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            with farmctl.connect(root) as conn:
                task_id = farmctl.create_task(
                    conn,
                    kind="build_ea",
                    source_id=None,
                    card_id="QM5_20084",
                    payload={
                        "ea_id": "QM5_20084",
                        "card_path": "C:/completed.md",
                    },
                )
                conn.commit()
                stale_row = conn.execute(
                    "SELECT * FROM tasks WHERE id=?",
                    (task_id,),
                ).fetchone()
                conn.execute(
                    "UPDATE tasks SET status='done' WHERE id=?",
                    (task_id,),
                )
                conn.commit()

            spawn_fn = mock.Mock(return_value={"spawned": True})
            result = farmctl._spawn_with_build_dispatch_claim(
                root,
                stale_row,
                agent="claude",
                spawn_fn=spawn_fn,
            )

        self.assertFalse(result["spawned"])
        self.assertEqual(result["reason"], "task_no_longer_pending:done")
        spawn_fn.assert_not_called()


class REvalCompatibilityTests(unittest.TestCase):
    def test_g0_candidates_include_identity_recovery_and_skip_terminal_status(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            recovery_dir = root / "artifacts" / "cards_recovery"
            draft_dir = root / "artifacts" / "cards_draft"
            recovery_dir.mkdir(parents=True)
            draft_dir.mkdir(parents=True)
            recovery = recovery_dir / "QM5_20090_recovery.md"
            covered = recovery_dir / "QM5_20091_covered.md"
            draft = draft_dir / "QM5_20092_draft.md"
            _write_card(
                recovery,
                _ready_frontmatter(
                    ea_id="QM5_20090",
                    slug="recovery",
                    g0_status="PENDING",
                ),
            )
            _write_card(
                covered,
                _ready_frontmatter(
                    ea_id="QM5_20091",
                    slug="covered",
                    g0_status="COVERED_DUPLICATE",
                ),
            )
            _write_card(
                draft,
                _ready_frontmatter(
                    ea_id="QM5_20092",
                    slug="draft",
                    g0_status="PENDING",
                ),
            )

            candidates = farmctl._g0_candidate_cards(root)

        self.assertEqual(candidates, [recovery, draft])

    def test_tier_and_lineaged_unknown_are_not_rewritten_as_unknown(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            tiered = root / "QM5_20061_tiered.md"
            legacy_unknown = root / "QM5_20062_unknown.md"
            missing_lineage = root / "QM5_20063_missing.md"
            strict_unknown = root / "QM5_20064_strict.md"

            _write_card(tiered, _ready_frontmatter("TIER_A"))
            _write_card(
                legacy_unknown,
                _ready_frontmatter(
                    "UNKNOWN", ea_id="QM5_20062", slug="unknown"
                ),
            )
            _write_card(
                missing_lineage,
                _ready_frontmatter(
                    "UNKNOWN",
                    ea_id="QM5_20063",
                    slug="missing",
                    source_id="",
                ),
            )
            _write_card(
                strict_unknown,
                _ready_frontmatter(
                    "TIER_C",
                    ea_id="QM5_20064",
                    slug="strict",
                    r3_data_available="UNKNOWN",
                ),
            )

            self.assertFalse(r_eval_drain.card_unknown(tiered))
            self.assertFalse(r_eval_drain.card_unknown(legacy_unknown))
            self.assertTrue(r_eval_drain.card_unknown(missing_lineage))
            self.assertTrue(r_eval_drain.card_unknown(strict_unknown))
            self.assertFalse(farmctl._card_has_unknown_r_eval(legacy_unknown))
            self.assertTrue(farmctl._card_has_unknown_r_eval(missing_lineage))

    def test_owner_lineage_backfill_is_active_bucket_only_and_idempotent(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            draft_dir = root / "artifacts" / "cards_draft"
            approved_dir = root / "artifacts" / "cards_approved"
            rejected_dir = root / "artifacts" / "cards_rejected"
            for directory in (draft_dir, approved_dir, rejected_dir):
                directory.mkdir(parents=True)

            draft = draft_dir / "QM5_20070_draft.md"
            approved = approved_dir / "QM5_20071_approved.md"
            nonapproved = approved_dir / "QM5_20072_stale.md"
            rejected = rejected_dir / "QM5_20073_rejected.md"
            attributed = approved_dir / "QM5_20074_attributed.md"
            existing_source = approved_dir / "QM5_20075_existing.md"
            recovered_supporting = approved_dir / "QM5_20076_recovered.md"
            _write_card(
                draft,
                _ready_frontmatter(
                    "UNKNOWN",
                    ea_id="QM5_20070",
                    slug="draft",
                    source_id="",
                    g0_status="PENDING",
                ),
            )
            _write_card(
                approved,
                _ready_frontmatter(
                    "FAIL",
                    ea_id="QM5_20071",
                    slug="approved",
                    source_id="",
                ),
            )
            _write_card(
                nonapproved,
                _ready_frontmatter(
                    "FAIL",
                    ea_id="QM5_20072",
                    slug="stale",
                    source_id="",
                    g0_status="REJECTED",
                ),
            )
            _write_card(
                rejected,
                _ready_frontmatter(
                    "FAIL",
                    ea_id="QM5_20073",
                    slug="rejected",
                    source_id="",
                    g0_status="REJECTED",
                ),
            )
            _write_card(
                attributed,
                _ready_frontmatter(
                    "FAIL",
                    ea_id="QM5_20074",
                    slug="attributed",
                    source_id=farmctl.OWNER_SOURCE_RECOVERY_ID,
                ),
            )
            attributed.write_text(
                attributed.read_text(encoding="utf-8")
                + "\nSource: https://example.com/original-strategy\n",
                encoding="utf-8",
            )
            _write_card(
                existing_source,
                _ready_frontmatter(
                    "FAIL",
                    ea_id="QM5_20075",
                    slug="existing",
                    source_id="REAL-SOURCE-ID",
                ),
            )
            _write_card(
                recovered_supporting,
                _ready_frontmatter(
                    "PASS",
                    ea_id="QM5_20076",
                    slug="recovered",
                    source_id="AUTO-SUPPORTING-ID",
                    source_citation='"https://example.com/supporting"',
                    source_lineage_recovery=(
                        '"Canonical source lineage repaired on 2026-07-23 '
                        'from recovered_url; source reputation is informational."'
                    ),
                ),
            )
            recovered_supporting.write_text(
                recovered_supporting.read_text(encoding="utf-8")
                + """
# Source
- Primary Author (2015), "Primary Strategy Paper", Journal of Tests 4, 1-20.
- Supporting: background page, https://example.com/supporting
""",
                encoding="utf-8",
            )

            repaired = farmctl._backfill_owner_source_lineage(root)
            self.assertEqual(
                {item["ea_id"] for item in repaired},
                {
                    "QM5_20070",
                    "QM5_20071",
                    "QM5_20072",
                    "QM5_20074",
                    "QM5_20075",
                    "QM5_20076",
                },
            )
            self.assertEqual(
                farmctl.parse_card_frontmatter(draft)["source_id"],
                farmctl.OWNER_SOURCE_RECOVERY_ID,
            )
            self.assertEqual(
                farmctl.parse_card_frontmatter(approved)["source_id"],
                farmctl.OWNER_SOURCE_RECOVERY_ID,
            )
            self.assertEqual(
                farmctl.parse_card_frontmatter(draft)["r1_track_record"],
                "TIER_C",
            )
            self.assertEqual(
                farmctl.parse_card_frontmatter(approved)["r1_track_record"],
                "TIER_C",
            )
            self.assertEqual(
                farmctl.parse_card_frontmatter(nonapproved)["source_id"],
                farmctl.OWNER_SOURCE_RECOVERY_ID,
            )
            self.assertEqual(
                farmctl.parse_card_frontmatter(nonapproved)["g0_status"],
                "REJECTED",
            )
            self.assertNotIn(
                "source_id", farmctl.parse_card_frontmatter(rejected)
            )
            attributed_fm = farmctl.parse_card_frontmatter(attributed)
            self.assertNotEqual(
                attributed_fm["source_id"],
                farmctl.OWNER_SOURCE_RECOVERY_ID,
            )
            self.assertEqual(
                attributed_fm["source_citation"],
                "https://example.com/original-strategy",
            )
            existing_fm = farmctl.parse_card_frontmatter(existing_source)
            self.assertEqual(existing_fm["source_id"], "REAL-SOURCE-ID")
            self.assertEqual(existing_fm["r1_track_record"], "TIER_C")
            corrected_fm = farmctl.parse_card_frontmatter(recovered_supporting)
            self.assertNotEqual(
                corrected_fm["source_id"],
                "AUTO-SUPPORTING-ID",
            )
            self.assertIn(
                "Primary Author",
                corrected_fm["source_citation"],
            )
            self.assertNotIn(
                "example.com/supporting",
                corrected_fm["source_citation"],
            )
            self.assertEqual(farmctl._backfill_owner_source_lineage(root), [])

    def test_source_only_rejection_recovery_preserves_audit_original(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            rejected_dir = root / "artifacts" / "cards_rejected"
            rejected_dir.mkdir(parents=True)
            repo_root = Path(tmp) / "repo"
            registry_dir = repo_root / "framework" / "registry"
            registry_dir.mkdir(parents=True)
            (registry_dir / "ea_id_registry.csv").write_text(
                "ea_id,slug,strategy_id,status,owner,created_at\n"
                "11212,demo,S1,active,Research,2026-07-23\n",
                encoding="utf-8",
            )
            rejected = rejected_dir / "QM5_11212_demo.md"
            fm = _ready_frontmatter(
                "TIER_A",
                ea_id="QM5_11212",
                slug="demo",
                target_symbols="[EURUSD.DWX]",
                source_citation=(
                    '"Original Author, Original Book, '
                    'https://example.com/original"'
                ),
                g0_status="REJECTED",
                g0_rejection_reason=(
                    '"R1 FAIL: missing source_citation formatting despite '
                    'otherwise mechanical rules."'
                ),
            )
            yaml = "\n".join(f"{key}: {value}" for key, value in fm.items())
            rejected.write_text(
                f"""---
{yaml}
---

# Demo

Entry: enter on the next D1 bar.
Exit: exit after five bars.
Stop: one ATR.
Target symbols: EURUSD.DWX.
Expected 12 trades per year per symbol.
""",
                encoding="utf-8",
            )

            with (
                mock.patch.object(farmctl, "REPO_ROOT", repo_root),
                mock.patch.object(
                    farmctl,
                    "FRAMEWORK_EAS_DIR",
                    repo_root / "framework" / "EAs",
                ),
            ):
                dry_run = r1_recovery.recover(root, apply=False)
                self.assertEqual(
                    dry_run["actions"][0]["action"],
                    "would_recover_to_approved",
                )
                self.assertFalse((root / "artifacts" / "cards_approved" / rejected.name).exists())

                applied = r1_recovery.recover(root, apply=True)
                approved = (
                    root / "artifacts" / "cards_approved" / rejected.name
                )
                reidentified = approved.with_name(
                    "QM5_29999_reidentified-after-recovery.md"
                )
                approved.rename(reidentified)
                with farmctl.connect(root) as conn:
                    conn.execute("UPDATE sources SET status='done'")
                    conn.commit()
                second = r1_recovery.recover(root, apply=True)

            approved = reidentified
            self.assertTrue(rejected.exists())
            self.assertTrue(approved.exists())
            self.assertFalse(
                (
                    root / "artifacts" / "cards_approved" / rejected.name
                ).exists()
            )
            recovered_fm = farmctl.parse_card_frontmatter(approved)
            self.assertEqual(recovered_fm["g0_status"], "APPROVED")
            self.assertEqual(recovered_fm["r1_track_record"], "TIER_A")
            self.assertIn(
                "Original Author",
                recovered_fm["source_citation"],
            )
            self.assertEqual(recovered_fm["r2_mechanical"], "PASS")
            self.assertEqual(recovered_fm["r3_data_available"], "PASS")
            self.assertEqual(recovered_fm["r4_ml_forbidden"], "PASS")
            self.assertEqual(applied["summary"]["recovered_to_approved"], 1)
            self.assertEqual(second["actions"][0]["action"], "already_recovered")
            self.assertTrue(
                all(
                    item["action"] == "existing_source_done"
                    for item in second["source_omissions"]
                )
            )
            with sqlite3.connect(root / "state" / "farm_state.sqlite") as conn:
                count = conn.execute(
                    "SELECT COUNT(*) FROM events WHERE event='r1_source_recovered'"
                ).fetchone()[0]
            self.assertEqual(count, 1)
            manifest = json.loads(
                (root / "state" / "r1_source_recovery_20260723.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(len(manifest["runs"]), 2)
            self.assertIn(str(rejected), manifest["recovered_cards"])

    def test_contract_recovery_remains_marked_incomplete_for_g0_repair(self) -> None:
        updates = r1_recovery._target_recovery_updates(
            Path("QM5_20085_legacy.md"),
            _ready_frontmatter(
                "FAIL",
                ea_id="QM5_20085",
                slug="legacy",
                g0_status="REJECTED",
            ),
            source_lineage={
                "source_id": "SOURCE-LEGACY",
                "citation": "Legacy Book",
                "kind": "existing",
            },
            approve_directly=False,
            contract_repair=True,
        )

        self.assertEqual(updates["card_body_incomplete"], "true")
        self.assertEqual(
            json.loads(updates["card_body_missing"]),
            "legacy_contract_repair",
        )
        self.assertEqual(updates["legacy_contract_repair"], "true")

    def test_reidentify_recovery_card_moves_card_and_active_claim_together(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            recovery_dir = root / "artifacts" / "cards_recovery"
            registry_dir = repo_root / "framework" / "registry"
            ea_dir = repo_root / "framework" / "EAs"
            recovery_dir.mkdir(parents=True)
            registry_dir.mkdir(parents=True)
            ea_dir.mkdir(parents=True)
            (registry_dir / "ea_id_registry.csv").write_text(
                "ea_id,slug,strategy_id,status,owner,created_at\n"
                "29998,new-recovery-slug,S1,reserved,Research,2026-07-23\n",
                encoding="utf-8",
            )
            source = recovery_dir / "QM5_1650_legacy.md"
            _write_card(
                source,
                _ready_frontmatter(
                    "TIER_C",
                    ea_id="QM5_1650",
                    slug="legacy",
                    g0_status="PENDING",
                    identity_repair_required="true",
                ),
            )
            old_claim = farmctl._g0_claim_path(source)
            old_claim.write_text(
                "reviewer=codex\ntimestamp=2026-07-23T00:00:00Z\n",
                encoding="utf-8",
            )

            with (
                mock.patch.object(farmctl, "REPO_ROOT", repo_root),
                mock.patch.object(farmctl, "FRAMEWORK_EAS_DIR", ea_dir),
            ):
                result = farmctl.reidentify_recovery_card(
                    root,
                    str(source),
                    "QM5_29998",
                    "new-recovery-slug",
                )

            target = (
                root
                / "artifacts"
                / "cards_draft"
                / "QM5_29998_new-recovery-slug.md"
            )
            self.assertTrue(result["moved"])
            self.assertFalse(source.exists())
            self.assertFalse(old_claim.exists())
            self.assertTrue(target.exists())
            self.assertTrue(farmctl._g0_claim_path(target).exists())
            target_fm = farmctl.parse_card_frontmatter(target)
            self.assertEqual(target_fm["ea_id"], "QM5_29998")
            self.assertEqual(target_fm["slug"], "new-recovery-slug")
            self.assertEqual(target_fm["recovery_status"], "IDENTITY_REPAIRED")

    def test_reidentify_publish_failure_keeps_original_identity_intact(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp) / "farm"
            repo_root = Path(tmp) / "repo"
            recovery_dir = root / "artifacts" / "cards_recovery"
            registry_dir = repo_root / "framework" / "registry"
            ea_dir = repo_root / "framework" / "EAs"
            recovery_dir.mkdir(parents=True)
            registry_dir.mkdir(parents=True)
            ea_dir.mkdir(parents=True)
            (registry_dir / "ea_id_registry.csv").write_text(
                "ea_id,slug,strategy_id,status,owner,created_at\n"
                "29997,new-failure-slug,S1,reserved,Research,2026-07-23\n",
                encoding="utf-8",
            )
            source = recovery_dir / "QM5_1650_legacy.md"
            _write_card(
                source,
                _ready_frontmatter(
                    "TIER_C",
                    ea_id="QM5_1650",
                    slug="legacy",
                    g0_status="PENDING",
                    identity_repair_required="true",
                ),
            )
            old_claim = farmctl._g0_claim_path(source)
            old_claim.write_text("reviewer=codex\n", encoding="utf-8")

            with (
                mock.patch.object(farmctl, "REPO_ROOT", repo_root),
                mock.patch.object(farmctl, "FRAMEWORK_EAS_DIR", ea_dir),
                mock.patch.object(
                    farmctl.os,
                    "replace",
                    side_effect=OSError("simulated publish failure"),
                ),
            ):
                result = farmctl.reidentify_recovery_card(
                    root,
                    str(source),
                    "QM5_29997",
                    "new-failure-slug",
                )

            target = (
                root
                / "artifacts"
                / "cards_draft"
                / "QM5_29997_new-failure-slug.md"
            )
            self.assertFalse(result["moved"])
            self.assertTrue(source.exists())
            self.assertTrue(old_claim.exists())
            self.assertFalse(target.exists())
            self.assertFalse(farmctl._g0_claim_path(target).exists())
            original_fm = farmctl.parse_card_frontmatter(source)
            self.assertEqual(original_fm["ea_id"], "QM5_1650")
            self.assertEqual(original_fm["slug"], "legacy")

    def test_source_recovery_apply_is_globally_serialized(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            claim = farmctl._acquire_build_dispatch_claim(
                root,
                ea_id="R1_SOURCE_RECOVERY_APPLY",
                task_id="holder",
                agent="controller",
            )
            try:
                with self.assertRaisesRegex(
                    RuntimeError,
                    "already running",
                ):
                    r1_recovery.recover(root, apply=True)
            finally:
                farmctl._release_build_dispatch_claim(claim)


if __name__ == "__main__":
    unittest.main()
