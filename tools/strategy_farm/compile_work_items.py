"""Governed COMPILE_EA enqueue, candidate guards, and worker execution."""

from __future__ import annotations

import csv
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import uuid
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable

try:
    from artifact_identity import extract_identity, identity_update_clause
except ModuleNotFoundError:
    from tools.strategy_farm.artifact_identity import extract_identity, identity_update_clause

try:
    from include_mirror import running_terminal_names
except ModuleNotFoundError:
    from tools.strategy_farm.include_mirror import running_terminal_names


COMPILE_WORK_ITEM_KIND = "compile"
COMPILE_EA_PHASE = "COMPILE_EA"
COMPILE_CONTRACT_VERSION = "qm.compile-ea-work-item/v1"
BUILD_TASK_BINDING_CONTRACT_VERSION = "qm.compile-ea-build-task-binding/v1"
COMPILE_ACTIVATION_HOLD_CODE = "COMPILE_EA_WORKER_ROLLOUT_PENDING"
COMPILE_ACTIVATION_HOLD_REASON = (
    "COMPILE_EA rows require the reviewed worker version on the full terminal fleet; "
    "release only through the governed release-on-restart ceremony"
)
R11_REVIVAL_CONTRACT_VERSION = "qm.r11-compile-ea-revival/v1"
R11_REVIVAL_AUTHORITY_TASK_ID = "83be33f3-a45d-453b-bb70-79d10a7841e9"
R11_REVIVAL_REASON = "R11_FALSE_INVALID_EX5_MISSING"
R11_INCIDENT_HANDLER = "R11_pending_unclaimable_work_item"
R11_INCIDENT_REASON = "ex5_missing"
COMPILE_RECHECK_RETRY_CONTRACT_VERSION = "qm.compile-ea-candidate-recheck-retry/v1"
COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID = "1fb9943f-1b87-4515-b2b4-f5ca3ffb56f8"
COMPILE_RECHECK_FAILURE_CLASS = "CANDIDATE_RECHECK_REFUSED"
COMPILE_BINDING_RETRY_CONTRACT_VERSION = "qm.compile-ea-build-binding-retry/v1"
COMPILE_BINDING_FAILURE_CLASS = "BUILD_CHECK_FAILED"
SOURCE_REPAIR_CONTRACT_VERSION = "qm.compile-ea-source-repair/v1"
SOURCE_REPAIR_AUTHORITY = "router_ops_issue:50467e7e"
SOURCE_REPAIR_EA_LABELS = frozenset({
    "QM5_41104_xauxag-mmedian-shift-rv",
    "QM5_41109_xauxag-mmean-median-rv",
    "QM5_41110_xauxag-moutside-res-rv",
    "QM5_41111_wti-mdaybreadth-mom",
    "QM5_41112_xauxag-mdaybreadth-rv",
    "QM5_41113_xauxag-mhalfagree-rv",
    "QM5_41116_xauxag-mthirdvote-rv",
    "QM5_41118_xauxag-mlatehalf-dom-rv",
    "QM5_41119_xauxag-mclose-quartile-rv",
    "QM5_41120_xauxag-mopen-residence-rv",
    "QM5_41121_xauxag-mseqdom-rv",
    "QM5_41123_xauxag-mpath-eff-rv",
    "QM5_41124_wti-mrms-coherence-mom",
    "QM5_41125_xauxag-mrms-coherence-rv",
    "QM5_41126_wti-mpath-eff-mom",
    "QM5_41127_wti-mdaily-persist-mom",
    "QM5_41128_xauxag-mdaily-persist-rv",
    "QM5_41130_wti-mopen-residence-mom",
    "QM5_41131_wti-mdaily-tailtrim-mom",
    "QM5_41132_wti-mweekday-med-mom",
})
HYGIENE_BURN_SOURCE_REPAIR_AUTHORITY = "ticket:rb-hygiene-burn"
HYGIENE_BURN_SOURCE_REPAIR_EA_LABELS = frozenset({
    "QM5_41136_xng-mdaily-iqrmean-mom",
})
# Exact RECYCLE authority for rework-33007. The existing EX5 belongs to the
# rejected source, so the ordinary no-overwrite classifier must stay closed
# everywhere except this router-task/EA binding.
REWORK_33007_SOURCE_REPAIR_AUTHORITY = (
    "router_review_rework:85fd5256-cd48-4486-9f2b-64d343f9b3e3"
)
REWORK_33007_SOURCE_REPAIR_EA_LABELS = frozenset({
    "QM5_33007_george-pruitt-king-keltner-trend-buster",
})
# Exact paced-fleet authority for the pre-existing QM5_11900 Q02
# infrastructure-repair task.  The June binary predates its governed magic
# allocation, so the ordinary no-overwrite classifier correctly refuses it;
# this single label/task binding authorizes an append-only, source-hash-bound
# compile successor without weakening the default guard for any other EA.
Q02_INFRA_SOURCE_REPAIR_AUTHORITY = (
    "router_q02_infra_repair:46e34047-c661-462c-96d5-b4f9d76914db"
)
Q02_INFRA_SOURCE_REPAIR_EA_LABELS = frozenset({
    "QM5_11900_kobasfx-4ema-macd-sentiment-h1",
})
# Exact paced-fleet authority for the QM5_1252 FX Q02 infrastructure recovery.
# The existing binary predates the current MAE-hook and bounded-buffer build
# contracts, while the historical EURUSD/GBPUSD rows never produced an
# economic verdict. This one task/label binding permits only an append-only,
# source-hash-bound compile successor; it grants no gate-verdict authority.
QM5_1252_Q02_INFRA_REPAIR_AUTHORITY = (
    "router_ops_issue:25d7265a-332b-4d4c-8c5e-6518c7caa52a"
)
QM5_1252_Q02_INFRA_REPAIR_EA_LABELS = frozenset({
    "QM5_1252_carver-handcraft-ens",
})
# Exact review-rework authority for QM5_35005. The accepted source remediation
# changed the MQ5 after the existing EX5 was produced, so the normal immutable
# build guards correctly refuse an overwrite. This router-task/label pair
# permits only an append-only, source-hash-bound COMPILE_EA successor.
QM5_35005_REVIEW_REPAIR_AUTHORITY = (
    "router_review_ea:3281881e-4597-4243-9a2b-e8d7c4fa6360"
)
QM5_35005_REVIEW_REPAIR_EA_LABELS = frozenset({
    "QM5_35005_sma-crossover-pullback-system",
})
# Exact review-rework authorities for review tasks that accepted repaired
# source while rejecting the stale binary/source package. Each permits one
# append-only COMPILE_EA successor bound to the repaired source hash; it grants
# no backtest or gate authority and cannot be used for another EA.
REVIEW_REWORK_SOURCE_REPAIR_AUTHORITY = (
    "router_review_ea:cd6442dd-4ad9-4845-862a-2ef6e3ec0172"
)
REVIEW_REWORK_SOURCE_REPAIR_AUTHORITIES = {
    "QM5_9468_connors-rsi4-3day-d1": REVIEW_REWORK_SOURCE_REPAIR_AUTHORITY,
    "QM5_9909_bandy-lrchannel-breakout-trend": (
        "router_review_ea:d6ea3abe-d44b-4861-b466-475a28899eaa"
    ),
    "QM5_41011_tokyo-london-bank-flow-handover": (
        "router_review_ea:86e63523-90c7-47e7-bd41-b220e70042e7"
    ),
}
REVIEW_REWORK_SOURCE_REPAIR_EA_LABELS = frozenset(
    REVIEW_REWORK_SOURCE_REPAIR_AUTHORITIES
)
# Exact router authority for the QM5_41163 Pattern-Permission sibling MAE-hook
# retrofit. The original governed compile row 16f86fe7 failed only the current
# Q08 sampler requirement; this one-task/one-label binding permits an append-only
# source-hash-bound successor and grants no backtest or pipeline authority.
QM5_41163_MAE_REPAIR_AUTHORITY = (
    "router_ops_issue:1353730a-c94c-47fe-9a6d-ba09c4d48469"
)
QM5_41163_MAE_REPAIR_EA_LABELS = frozenset({
    "QM5_41163_williams-18ma-outside-bar-entry-d1-opt",
})
# Exact follow-up authority for the same sibling after its governed compiler
# failed closed because the scheduled Windows PowerShell environment could not
# autoload Get-FileHash. This permits one append-only, source-hash-bound compile
# successor under router task 9f304e74 and grants no backtest/gate authority.
QM5_41163_SETFILE_REPAIR_AUTHORITY = (
    "router_ops_issue:9f304e74-5be4-4a6b-8921-d1b65875e241"
)
QM5_41163_SETFILE_REPAIR_EA_LABELS = frozenset({
    "QM5_41163_williams-18ma-outside-bar-entry-d1-opt",
})
# Exact continuation authority for the QM5_41194 DL-089 measurement sibling.
# Its first governed compile produced zero compiler errors/warnings but failed
# the current raw-series and Q08 MAE-hook build contracts. This permits only an
# append-only, source-hash-bound COMPILE_EA successor for the repaired label;
# it grants no backtest, gate, or setfile-unbinding authority.
QM5_41194_DL089_BUILD_REPAIR_AUTHORITY = (
    "router_ops_issue:4ea27950-fab1-49ee-a183-bf78967e8447"
)
QM5_41194_DL089_BUILD_REPAIR_EA_LABELS = frozenset({
    "QM5_41194_brent-tom-mom-opt",
})
# Exact authority for the two DL-089 measurement siblings whose initial compile
# receipts preceded the final source normalization commit.  The P0 dispatch
# repair requires current source-bound binaries before it may enqueue any real
# matrix cell; this grants only append-only COMPILE_EA successors for those two
# labels and no gate/backtest authority.
DL089_MATRIX_DISPATCH_REPAIR_AUTHORITY = (
    "router_ops_issue:78f6404a-cfc5-43da-befb-1d0b6fa58376"
)
DL089_MATRIX_DISPATCH_REPAIR_EA_LABELS = frozenset({
    "QM5_41161_tv-mon-ls-opt",
    "QM5_41162_ohlc-daily-squeeze-reversal-d1-opt",
})
# Exact P95 executability authority for the three DL-089 pilot siblings.  It is
# usable only when a source-matched COMPILE_OK receipt has lost its bound EX5
# bytes (for example, the 2026-08-27 quarantine of QM5_41163).  A present,
# hash-matched binary remains a usable compile verdict and cannot be rebuilt.
DL089_PILOT_BINARY_RECOVERY_AUTHORITY = (
    "router_ops_issue:ac80262f-97e7-4179-abb9-bc4166ecdcb1"
)
DL089_PILOT_BINARY_RECOVERY_EA_LABELS = frozenset({
    "QM5_41161_tv-mon-ls-opt",
    "QM5_41162_ohlc-daily-squeeze-reversal-d1-opt",
    "QM5_41163_williams-18ma-outside-bar-entry-d1-opt",
})
# Exact paced-fleet authority for the QM5_11465 FX diversity recovery.  Its
# current-source COMPILE_OK receipt survives, but the bound EX5 bytes do not;
# the stale older open row is source-hash mismatched.  This one task/label
# binding permits only an append-only, current-source COMPILE_EA successor and
# grants no gate verdict, strategy change, or authority for another EA.
QM5_11465_Q02_BINARY_RECOVERY_AUTHORITY = (
    "router_ops_issue:6c02cfce-b008-4b65-8fa0-161202e25ebe"
)
QM5_11465_Q02_BINARY_RECOVERY_EA_LABELS = frozenset({
    "QM5_11465_suhr-bank-trading-stop-run-fade-h1",
})
# Exact remediation authority for the 2026-08-24 ROT-violation revert
# (router task b63eaead-7890-4be4-b8e7-0edea3fe6a85). Both EAs had ad-hoc
# EX5 binaries committed after an explicit LIVE_FACTORY_AD_HOC_COMPILE_REFUSED
# interlock refusal; the ad-hoc binaries were removed/reverted in the same
# remediation commit that adds this authority. This permits exactly one
# append-only, source-hash-bound COMPILE_EA successor per label through the
# governed compiler; it grants no backtest, gate, or overwrite authority for
# any other EA.
ROT_REMEDIATION_39001_38001_AUTHORITY = (
    "router_ops_issue:b63eaead-7890-4be4-b8e7-0edea3fe6a85"
)
ROT_REMEDIATION_39001_38001_EA_LABELS = frozenset({
    "QM5_39001_forexfactory-trading-made-simple-tms",
    "QM5_38001_codetrading-vwap-bollinger-rsi-scalper",
})
# Exact, self-expiring authority for the stale rollout-hold reconciliation.
# Initial enqueue is authorized only while the same EA still has an active
# COMPILE_EA_WORKER_ROLLOUT_PENDING predecessor bound to a different source
# hash. Worker recheck survives hold closure only through a canonical
# work_item_supersedes edge back to that historical predecessor.
ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY = (
    "router_ops_issue:e9944090-1e0f-4dea-af90-e74f8079d1c8"
)
# Exact OWNER-approved requalification authority for the nine Category-A EAs
# whose historical PASS chain was built through the defective QM_HMA helper.
# This contract is deliberately self-expiring: enqueue and worker recheck both
# require the decision, approved census, and fixed shared include to retain the
# reviewed hashes below. It grants no authority outside these nine labels.
HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY = (
    "router_ops_issue:c29fddf8-fab7-4909-a506-499f6ab78f37"
)
HMA_CATA_REQUAL_OWNER_DECISION_ID = "OWNER-DEC-HMA-CATA"
HMA_CATA_REQUAL_EA_LABELS = frozenset({
    "QM5_10251_tv-nova-rev",
    "QM5_10593_mql5-adxhull",
    "QM5_10602_mql5-oshma",
    "QM5_10833_tv-autobot12",
    "QM5_10960_ftmo-hma-rsi",
    "QM5_12742_nnfx-configurable-engine",
    "QM5_12958_nnfx-hma-wae-swing",
    "QM5_2002_nnfx-qqe-trend",
    "QM5_9998_tv-hull-suite-hma-color-flip",
})
HMA_CATA_REQUAL_ARTIFACT_SHA256 = {
    "decisions/2026-08-25_owner_hma_requal_ftmo_park_q02_dead16.md": (
        "ec484d61c5d7a103522572d91fcee7adb50a899678e34e536087b593428c5bdd"
    ),
    "docs/ops/evidence/2026-08-24_qm_hma_ea_census.csv": (
        "d5393e1b51c6a43e693933142b384dcc88495b5e5dbc8fc611f0bf36df606d87"
    ),
    "framework/include/QM/QM_Indicators.mqh": (
        "50d47f901236ed0a827fd9e74e82e781f52c7c9a45ff3097630b2e497686bca4"
    ),
}
# Exact router authority for the six energy/metals COMPILE_FAIL rework
# siblings whose EA_INDICATOR_BUFFER_UNBOUNDED failures were source-repaired
# (explicit ArraySize bounds guards ahead of already-in-bounds dynamic buffer
# accesses; no strategy logic changed) after the prior refusal
# 57ab1771-c43a-4fda-b51f-38a25597b08b found no open governed build_ea parent.
# This one router-task/label-cohort binding permits only append-only,
# source-hash-bound COMPILE_EA successors; it grants no backtest, gate, or
# overwrite authority for any other EA.
QM5_41164_41191_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "router_ops_issue:e173b7a8-9702-4ea1-9144-e3d153329db1"
)
QM5_41164_41191_COMPILE_FAIL_REPAIR_EA_LABELS = frozenset({
    "QM5_41164_xauxag-mrepmedian-rv",
    "QM5_41165_wti-mrobust3-agree-tr",
    "QM5_41166_xauxag-mrobust3-agree-rv",
    "QM5_41168_xauxag-mcoxstuart-rv",
    "QM5_41172_wti-mpettitt-shift-tr",
    "QM5_41191_wti-samecal-srank",
})
# Exact append-only authority for the first governed QM5_41201 compile. The
# predecessor compiled with 0 errors / 0 warnings but failed Q01 only because
# its 15-element Hodges-Lehmann buffer bound was not mechanically visible to
# build_gate_hardening. The authority is bound below to that immutable failed
# row, its rejected source hash, and the one reviewed source-repair hash. It
# grants no backtest, gate-verdict, or general EX5-overwrite authority.
QM5_41201_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "652a5e63-1a1f-4845-9c78-b729b52870a3"
)
QM5_41201_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:652a5e63-1a1f-4845-9c78-b729b52870a3"
)
QM5_41201_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_41201_wti-samecal-hl5"
QM5_41201_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "b7d4fec61479d0b7c305a325d395f67b603a87e7986d09865c3180fff8c53010"
)
QM5_41201_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "fe9bbff92592ceb71f74640bb49cb41d312467b0af9b7faa5615239a1e4065e9"
)
# Exact append-only authority for the first governed QM5_41203 compile. The
# predecessor compiled with 0 errors / 0 warnings but failed Q01 because the
# framework MAE hook was absent and the already-bounded paired-return write did
# not expose an ArraySize guard to build_gate_hardening. This binding authorizes
# only the reviewed two-line contract repair for that immutable failed row.
QM5_41203_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "eb70f232-b874-4816-8243-dd12f4dc145f"
)
QM5_41203_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:eb70f232-b874-4816-8243-dd12f4dc145f"
)
QM5_41203_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_41203_xauxag-samecal-srank"
QM5_41203_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "345ef611140ddce556cf85ed5a5dc911f996b92b17442510e4844fbb9e22f1ed"
)
QM5_41203_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "aabcac8d22ceebfa75960c877e8078bfd85e657e4c5b37bdca4dbaff540f75ea"
)
# Exact append-only authority for the QM5_41207 pre-Q02 execution-contract
# repair.  Its first governed compile was mechanically clean, but the strict
# build receipt carried BUILD_CHECK_DWX_ADVISORY_DWX_SPREAD_FAILCLOSED: the
# original source rejected Ask==Bid even though .DWX tester quotes legitimately
# model zero spread.  This binding authorizes only the reviewed Ask<Bid repair,
# against the immutable advisory receipt and successor source hash.  It grants
# no backtest, gate-verdict, or general EX5-overwrite authority.
QM5_41207_COMPILE_ADVISORY_REPAIR_PREDECESSOR_ID = (
    "673f05ea-b106-4de1-8607-3df23d51e2d6"
)
QM5_41207_COMPILE_ADVISORY_REPAIR_AUTHORITY = (
    "governed_compile_advisory:673f05ea-b106-4de1-8607-3df23d51e2d6"
)
QM5_41207_COMPILE_ADVISORY_REPAIR_EA_LABEL = "QM5_41207_xauxag-corrbreak-rv"
QM5_41207_COMPILE_ADVISORY_REJECTED_SOURCE_SHA256 = (
    "5fb24a43d232fb4bfba613d02735ad4b8ad7a01a89824847fef013d3fb3c0f1e"
)
QM5_41207_COMPILE_ADVISORY_REPAIRED_SOURCE_SHA256 = (
    "ffbfc3e4845ccbc87c73adb6e6ddf6f8a1cd8e4ecec78b6382c96fd920b8812a"
)
QM5_41207_COMPILE_ADVISORY_PREDECESSOR_EX5_SHA256 = (
    "957f2774a66c4afc501a310b518cf308d80170af03be688855f2ba6c7902493d"
)
QM5_41207_COMPILE_ADVISORY_EVIDENCE_SHA256 = (
    "90f8a719f54d41efe13c2abd705d44ebc4d36e37c63bbb51c7f1a9a4e90cff2a"
)
COMPILE_PROFILE_STDLIB_FAILURE_CLASS = "COMPILE_PROFILE_STDLIB_MISSING"
VALID_TIMEFRAMES = (
    # Kept exactly aligned with gen_setfile.ps1's ValidateSet: a candidate
    # must be generatable, not merely a valid MetaTrader period literal.
    "MN1", "W1", "D1", "H12", "H8", "H6", "H4", "H3", "H2", "H1",
    "M30", "M15", "M10", "M5", "M2", "M1",
)
_TF_ALTERNATION = "|".join(VALID_TIMEFRAMES)
_EA_LABEL_RE = re.compile(r"^(QM5_([0-9]+)_([A-Za-z0-9][A-Za-z0-9_-]*))$")
_BOUND_HASH_RE = re.compile(r"^[0-9a-fA-F]{64}$")

# DL-089 Wave 1 live-book requalification: an explicit, named force-rebuild
# allowlist for the 16 EAs still stuck behind the default "no existing .ex5"
# classifier guard. Overwriting the old .ex5 is the entire point of a
# requalification rebuild for these EAs specifically - this is NOT a general
# .ex5-overwrite path; every other candidate keeps the default guards.
DL089_FORCE_REBUILD_OWNER_REFERENCE = "OWNER_DECISION_2026-08-21_DL-089_LIVE_BOOK_REQUALIFICATION"
DL089_FORCE_REBUILD_EA_IDS = frozenset({
    "1556", "1567", "10919", "10939", "11132", "11165", "11421", "11708",
    "12567", "12778", "12969", "12989", "13117", "13128", "13213", "13301",
})
FORCE_REBUILD_WAIVABLE_REASONS = frozenset({
    "EX5_ALREADY_PRESENT", "WORK_ITEMS_EXIST", "BOUND_SETFILE_HASH_EXISTS",
    "BUILD_TASK_EXISTS",
})
MAE_HOOK_FORCE_REBUILD_OWNER_REFERENCE = (
    "OWNER_TASK_8fe2a461_2026-08-22_MAE_HOOK_EMERGENCY_REBUILD"
)
MAE_HOOK_FORCE_REBUILD_AUTHORITY_TASK_ID = "8fe2a461-f70e-489f-ab54-a9ea7d15914c"
MAE_HOOK_FORCE_REBUILD_EA_IDS = frozenset({
    "12947", "12948", "12949", "12950", "12951", "12952",
})


def dl089_force_rebuild_allowlist(repo_root: Path) -> frozenset[str]:
    """Return the numeric EA ids authorized for a COMPILE_EA force-rebuild.

    Fail-closed: an id only clears the bypass when the hardcoded
    DL089_FORCE_REBUILD_EA_IDS name AND a live owner_priority_tracks.json row
    bound to the exact DL-089 owner_reference both agree. Removing the
    registry row (e.g. an OWNER revocation) silently turns the bypass back
    off for that EA without a code change.
    """
    tracks_path = repo_root / "framework" / "registry" / "owner_priority_tracks.json"
    try:
        document = json.loads(tracks_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return frozenset()
    entries = document.get("entries") if isinstance(document, dict) else None
    if not isinstance(entries, list):
        return frozenset()
    authorized: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        if entry.get("owner_reference") != DL089_FORCE_REBUILD_OWNER_REFERENCE:
            continue
        ea_id = _numeric_ea_reference(entry.get("ea_id"))
        if ea_id and ea_id in DL089_FORCE_REBUILD_EA_IDS:
            authorized.add(ea_id)
    return frozenset(authorized)


def mae_hook_force_rebuild_allowlist(root: Path) -> frozenset[str]:
    """Honor only the exact routed OWNER emergency rebuild ticket.

    Existing binaries/set bindings remain a default refusal everywhere else.
    The ticket identity and its explicit six-EA goal are both required, so a
    copied/stale checkout cannot manufacture a general overwrite capability.
    """
    try:
        with _connect(root) as conn:
            row = conn.execute(
                "SELECT payload_json FROM agent_tasks WHERE id=?",
                (MAE_HOOK_FORCE_REBUILD_AUTHORITY_TASK_ID,),
            ).fetchone()
    except (OSError, sqlite3.Error):
        return frozenset()
    if row is None:
        return frozenset()
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except json.JSONDecodeError:
        return frozenset()
    goal = str(payload.get("goal") or "")
    title = str(payload.get("title") or "")
    if "12947-12952" not in goal or "MAE-Hook" not in title:
        return frozenset()
    return MAE_HOOK_FORCE_REBUILD_EA_IDS


def force_rebuild_allowlist(root: Path, repo_root: Path) -> frozenset[str]:
    return dl089_force_rebuild_allowlist(repo_root) | mae_hook_force_rebuild_allowlist(root)


def force_rebuild_owner_reference(ea_id: str) -> str:
    if ea_id in MAE_HOOK_FORCE_REBUILD_EA_IDS:
        return MAE_HOOK_FORCE_REBUILD_OWNER_REFERENCE
    return DL089_FORCE_REBUILD_OWNER_REFERENCE


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="seconds")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _numeric_ea_reference(value: Any) -> str | None:
    match = re.match(r"^(?:QM5_)?([0-9]+)(?:_|$)", str(value or "").strip(), re.I)
    if not match or int(match.group(1)) <= 0:
        return None
    return str(int(match.group(1)))


def _hma_cata_requal_artifact_bindings() -> list[dict[str, str]]:
    return [
        {"path": path, "sha256": expected_sha}
        for path, expected_sha in sorted(HMA_CATA_REQUAL_ARTIFACT_SHA256.items())
    ]


def _hma_cata_requal_authorized(
    repo_root: Path | None,
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None = None,
    source_sha: str | None = None,
    inventory: dict[str, Any] | None = None,
    current_work_item_id: str | None = None,
) -> bool:
    if (
        authority != HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY
        or ea_label not in HMA_CATA_REQUAL_EA_LABELS
        or repo_root is None
    ):
        return False
    for relative_path, expected_sha in HMA_CATA_REQUAL_ARTIFACT_SHA256.items():
        artifact = repo_root / Path(relative_path)
        if not artifact.is_file() or sha256_file(artifact).lower() != expected_sha:
            return False
    if current_work_item_id is None:
        return True
    if not ea_id or not source_sha or inventory is None:
        return False
    current_row = _work_row_by_id(inventory, ea_id, current_work_item_id)
    current_payload = _json_object(
        current_row.get("payload_json") if current_row else None
    )
    return bool(
        current_row
        and current_payload.get("append_only_source_repair") is True
        and current_payload.get("compile_source_repair_authority") == authority
        and str(current_payload.get("mq5_sha256") or "").lower()
        == str(source_sha).lower()
        and current_payload.get("owner_decision_id")
        == HMA_CATA_REQUAL_OWNER_DECISION_ID
        and current_payload.get("source_repair_artifact_bindings")
        == _hma_cata_requal_artifact_bindings()
    )


def _qm5_41201_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41201 repair to one exact failed row and source delta."""
    if (
        authority != QM5_41201_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41201_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41201"
        or str(source_sha or "").lower()
        != QM5_41201_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41201_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
        ),
        None,
    )
    if predecessor is None:
        return False
    payload = _json_object(predecessor.get("payload_json"))
    compile_result = payload.get("compile_result")
    return bool(
        predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "failed"
        and predecessor.get("verdict") == "COMPILE_FAIL"
        and payload.get("ea_label") == ea_label
        and str(payload.get("mq5_sha256") or "").lower()
        == QM5_41201_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "EA_INDICATOR_BUFFER_UNBOUNDED"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes")
        == ["EA_INDICATOR_BUFFER_UNBOUNDED"]
    )


def _qm5_41203_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41203 contract repair to one failed row and source delta."""
    if (
        authority != QM5_41203_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41203_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41203"
        or str(source_sha or "").lower()
        != QM5_41203_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41203_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
        ),
        None,
    )
    if predecessor is None:
        return False
    payload = _json_object(predecessor.get("payload_json"))
    compile_result = payload.get("compile_result")
    expected_failures = [
        "EA_Q08_MAE_HOOK_MISSING",
        "EA_INDICATOR_BUFFER_UNBOUNDED",
    ]
    return bool(
        predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "failed"
        and predecessor.get("verdict") == "COMPILE_FAIL"
        and payload.get("ea_label") == ea_label
        and str(payload.get("mq5_sha256") or "").lower()
        == QM5_41203_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == ";".join(expected_failures)
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes") == expected_failures
    )


def _qm5_41207_compile_advisory_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41207 zero-spread repair to one exact advisory receipt."""
    if (
        authority != QM5_41207_COMPILE_ADVISORY_REPAIR_AUTHORITY
        or ea_label != QM5_41207_COMPILE_ADVISORY_REPAIR_EA_LABEL
        or ea_id != "41207"
        or str(source_sha or "").lower()
        != QM5_41207_COMPILE_ADVISORY_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41207_COMPILE_ADVISORY_REPAIR_PREDECESSOR_ID
        ),
        None,
    )
    if predecessor is None:
        return False
    evidence_path = Path(str(predecessor.get("evidence_path") or ""))
    if (
        not evidence_path.is_file()
        or sha256_file(evidence_path).lower()
        != QM5_41207_COMPILE_ADVISORY_EVIDENCE_SHA256
    ):
        return False
    try:
        evidence = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return False
    output_tail = str(evidence.get("build_check_output_tail") or "")
    payload = _json_object(predecessor.get("payload_json"))
    compile_result = payload.get("compile_result")
    predecessor_ex5_sha = str(
        predecessor.get("ex5_sha256")
        or (compile_result or {}).get("ex5_sha256")
        or ""
    ).lower()
    return bool(
        predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "done"
        and predecessor.get("verdict") == "COMPILE_OK"
        and payload.get("ea_label") == ea_label
        and str(payload.get("mq5_sha256") or "").lower()
        == QM5_41207_COMPILE_ADVISORY_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "COMPILE_ARTIFACT_READY"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "PASS"
        and compile_result.get("failure_classes") == []
        and compile_result.get("success") is True
        and predecessor_ex5_sha
        == QM5_41207_COMPILE_ADVISORY_PREDECESSOR_EX5_SHA256
        and evidence.get("build_check_result") == "PASS"
        and evidence.get("compile_result") == "PASS"
        and "BUILD_CHECK_DWX_ADVISORY_DWX_SPREAD_FAILCLOSED" in output_tail
        and "build_check.warnings=1" in output_tail
    )


def _source_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    repo_root: Path | None = None,
    ea_id: str | None = None,
    source_sha: str | None = None,
    inventory: dict[str, Any] | None = None,
    current_work_item_id: str | None = None,
) -> bool:
    if authority == QM5_41201_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41201_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41203_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41203_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41207_COMPILE_ADVISORY_REPAIR_AUTHORITY:
        return _qm5_41207_compile_advisory_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY:
        return _hma_cata_requal_authorized(
            repo_root,
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
            current_work_item_id=current_work_item_id,
        )
    statically_authorized = bool(
        (
            authority == SOURCE_REPAIR_AUTHORITY
            and ea_label in SOURCE_REPAIR_EA_LABELS
        )
        or (
            authority == HYGIENE_BURN_SOURCE_REPAIR_AUTHORITY
            and ea_label in HYGIENE_BURN_SOURCE_REPAIR_EA_LABELS
        )
        or (
            authority == REWORK_33007_SOURCE_REPAIR_AUTHORITY
            and ea_label in REWORK_33007_SOURCE_REPAIR_EA_LABELS
        )
        or (
            authority == Q02_INFRA_SOURCE_REPAIR_AUTHORITY
            and ea_label in Q02_INFRA_SOURCE_REPAIR_EA_LABELS
        )
        or (
            authority == QM5_1252_Q02_INFRA_REPAIR_AUTHORITY
            and ea_label in QM5_1252_Q02_INFRA_REPAIR_EA_LABELS
        )
        or (
            authority == QM5_35005_REVIEW_REPAIR_AUTHORITY
            and ea_label in QM5_35005_REVIEW_REPAIR_EA_LABELS
        )
        or (
            authority is not None
            and authority == REVIEW_REWORK_SOURCE_REPAIR_AUTHORITIES.get(ea_label)
        )
        or (
            authority == ROT_REMEDIATION_39001_38001_AUTHORITY
            and ea_label in ROT_REMEDIATION_39001_38001_EA_LABELS
        )
        or (
            authority == QM5_41163_MAE_REPAIR_AUTHORITY
            and ea_label in QM5_41163_MAE_REPAIR_EA_LABELS
        )
        or (
            authority == QM5_41163_SETFILE_REPAIR_AUTHORITY
            and ea_label in QM5_41163_SETFILE_REPAIR_EA_LABELS
        )
        or (
            authority == QM5_41194_DL089_BUILD_REPAIR_AUTHORITY
            and ea_label in QM5_41194_DL089_BUILD_REPAIR_EA_LABELS
        )
        or (
            authority == DL089_MATRIX_DISPATCH_REPAIR_AUTHORITY
            and ea_label in DL089_MATRIX_DISPATCH_REPAIR_EA_LABELS
        )
        or (
            authority == DL089_PILOT_BINARY_RECOVERY_AUTHORITY
            and ea_label in DL089_PILOT_BINARY_RECOVERY_EA_LABELS
        )
        or (
            authority == QM5_11465_Q02_BINARY_RECOVERY_AUTHORITY
            and ea_label in QM5_11465_Q02_BINARY_RECOVERY_EA_LABELS
        )
        or (
            authority == QM5_41164_41191_COMPILE_FAIL_REPAIR_AUTHORITY
            and ea_label in QM5_41164_41191_COMPILE_FAIL_REPAIR_EA_LABELS
        )
    )
    if statically_authorized:
        return True
    if (
        authority != ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY
        or not ea_id
        or not source_sha
        or inventory is None
    ):
        return False

    source_sha = str(source_sha).lower()
    rollout_rows = inventory.get("rollout_holds", {}).get(ea_id, [])
    if current_work_item_id is None:
        return any(
            int(row.get("active") or 0) == 1
            and str(_json_object(row.get("payload_json")).get("ea_label") or "")
            == ea_label
            and str(_json_object(row.get("payload_json")).get("mq5_sha256") or "").lower()
            != source_sha
            for row in rollout_rows
        )

    current_row = _work_row_by_id(inventory, ea_id, current_work_item_id)
    current_payload = _json_object(
        current_row.get("payload_json") if current_row else None
    )
    predecessor_ids = {
        str(value)
        for value in current_payload.get("source_repair_predecessor_work_item_ids", [])
        if str(value or "")
    }
    if not (
        current_row
        and current_payload.get("append_only_source_repair") is True
        and current_payload.get("compile_source_repair_authority") == authority
        and str(current_payload.get("mq5_sha256") or "").lower() == source_sha
        and predecessor_ids
    ):
        return False
    superseded_by = inventory.get("superseded_by", {})
    return any(
        str(row.get("id")) in predecessor_ids
        and current_work_item_id in superseded_by.get(str(row.get("id")), set())
        for row in rollout_rows
    )


def _active_stale_rollout_hold_exists(
    conn: sqlite3.Connection,
    *,
    ea_id: str,
    ea_label: str,
    source_sha: str,
) -> bool:
    rows = conn.execute(
        """SELECT w.payload_json
           FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
           WHERE w.ea_id=? AND w.phase=? AND h.hold_code=? AND h.active=1""",
        (ea_id, COMPILE_EA_PHASE, COMPILE_ACTIVATION_HOLD_CODE),
    ).fetchall()
    return any(
        str(_json_object(row["payload_json"]).get("ea_label") or "") == ea_label
        and str(_json_object(row["payload_json"]).get("mq5_sha256") or "").lower()
        != source_sha.lower()
        for row in rows
    )


def _label_parts(label: str) -> tuple[str, str, str] | None:
    match = _EA_LABEL_RE.fullmatch(str(label or "").strip())
    if not match:
        return None
    return match.group(1), str(int(match.group(2))), match.group(3)


def _connect(root: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(root / "state" / "farm_state.sqlite", timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _bound_setfile_hashes(ea_dir: Path) -> list[dict[str, str]]:
    sets_dir = ea_dir / "sets"
    if not sets_dir.is_dir():
        return []
    bound: list[dict[str, str]] = []
    pattern = re.compile(r"^\s*;\s*build_hash\s*:\s*(\S+)", re.I | re.M)
    for setfile in sorted(sets_dir.glob("*.set")):
        match = pattern.search(
            setfile.read_text(encoding="utf-8-sig", errors="ignore")
        )
        if match and _BOUND_HASH_RE.fullmatch(match.group(1)):
            bound.append({"path": str(setfile), "build_hash": match.group(1).lower()})
    return bound


def _approved_card_path(root: Path, repo_root: Path, label: str) -> Path | None:
    candidates = [
        root / "artifacts" / "cards_approved" / f"{label}.md",
        repo_root / "artifacts" / "cards_approved" / f"{label}.md",
        repo_root / "strategy-seeds" / "cards" / "approved" / f"{label}.md",
        repo_root / "strategy-seeds" / "cards" / f"{label}.md",
    ]
    return next((path for path in candidates if path.is_file()), None)


def infer_timeframe(root: Path, repo_root: Path, ea_dir: Path) -> dict[str, Any]:
    """Infer a host timeframe without silently defaulting to H1."""
    label = ea_dir.name
    sets_dir = ea_dir / "sets"
    set_pattern = re.compile(r"_(" + _TF_ALTERNATION + r")_", re.I)
    set_values = sorted({
        match.group(1).upper()
        for path in (sets_dir.glob("*.set") if sets_dir.is_dir() else [])
        if (match := set_pattern.search(path.name))
    })
    if len(set_values) == 1:
        return {"timeframe": set_values[0], "source": "existing_setfiles", "candidates": set_values}

    card_path = _approved_card_path(root, repo_root, label)
    card_text = (
        card_path.read_text(encoding="utf-8-sig", errors="ignore")
        if card_path else ""
    )
    frontmatter = card_text.split("---", 2)[1] if card_text.startswith("---") and card_text.count("---") >= 2 else ""
    for key in ("period", "timeframe", "primary_timeframe", "host_timeframe"):
        match = re.search(
            rf"(?im)^\s*{key}\s*:\s*({_TF_ALTERNATION})\s*$",
            frontmatter,
        )
        if match:
            return {
                "timeframe": match.group(1).upper(),
                "source": f"card_frontmatter:{key}",
                "card_path": str(card_path),
                "candidates": [match.group(1).upper()],
            }

    label_values = [
        value.upper()
        for value in re.findall(
            r"(?:^|[-_])(" + _TF_ALTERNATION + r")(?=[-_]|$)",
            label,
            flags=re.I,
        )
    ]
    label_values = list(dict.fromkeys(label_values))
    if len(label_values) == 1:
        return {"timeframe": label_values[0], "source": "ea_label", "candidates": label_values}

    source = ea_dir / f"{label}.mq5"
    source_text = source.read_text(encoding="utf-8-sig", errors="ignore") if source.is_file() else ""
    source_values = sorted({
        value.upper()
        for value in re.findall(r"\bPERIOD_(" + _TF_ALTERNATION + r")\b", source_text, re.I)
    })
    if len(source_values) == 1:
        return {"timeframe": source_values[0], "source": "mq5_period_literal", "candidates": source_values}

    explicit_card_patterns = (
        r"(?im)^\s*-?\s*Timeframe\s*:\s*(`?)(" + _TF_ALTERNATION + r")\1\b",
        r"(?im)\b(" + _TF_ALTERNATION + r")\s+primary\b",
        r"(?im)\bEvaluate\s+on\b[^\n]{0,80}\b(" + _TF_ALTERNATION + r")\s+bar\b",
        r"(?im)\b(" + _TF_ALTERNATION + r")\s+timeframe\b",
    )
    for pattern in explicit_card_patterns:
        match = re.search(pattern, card_text)
        if match:
            value = match.group(match.lastindex or 1).upper()
            return {
                "timeframe": value,
                "source": "card_explicit_host_timeframe",
                "card_path": str(card_path),
                "candidates": [value],
            }

    card_values = sorted({
        value.upper()
        for value in re.findall(r"\b(" + _TF_ALTERNATION + r")\b", card_text, re.I)
    })
    if len(card_values) == 1:
        return {
            "timeframe": card_values[0],
            "source": "card_unique_timeframe",
            "card_path": str(card_path),
            "candidates": card_values,
        }
    return {
        "timeframe": None,
        "source": "unresolved",
        "card_path": str(card_path) if card_path else None,
        "candidates": {
            "setfiles": set_values,
            "label": label_values,
            "source": source_values,
            "card": card_values,
        },
    }


def _inventory(root: Path, repo_root: Path) -> dict[str, Any]:
    registry_rows = _read_csv(repo_root / "framework" / "registry" / "ea_id_registry.csv")
    magic_rows = _read_csv(repo_root / "framework" / "registry" / "magic_numbers.csv")
    registry_by_id: dict[str, list[dict[str, str]]] = defaultdict(list)
    active_magics: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in registry_rows:
        if (ea_id := _numeric_ea_reference(row.get("ea_id"))):
            registry_by_id[ea_id].append(row)
    for row in magic_rows:
        if (
            (ea_id := _numeric_ea_reference(row.get("ea_id")))
            and str(row.get("status") or "").strip().lower() == "active"
        ):
            active_magics[ea_id].append(row)
    with _connect(root) as conn:
        work_rows: dict[str, list[dict[str, Any]]] = defaultdict(list)
        open_compile: dict[str, list[dict[str, Any]]] = defaultdict(list)
        rollout_holds: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for row in conn.execute(
            "SELECT id,ea_id,phase,status,verdict,evidence_path,payload_json,"
            "ex5_sha256,mq5_sha256 FROM work_items"
        ):
            ea_id = _numeric_ea_reference(row["ea_id"])
            if not ea_id:
                continue
            item = dict(row)
            work_rows[ea_id].append(item)
            if row["phase"] == COMPILE_EA_PHASE and row["status"] in ("pending", "active"):
                open_compile[ea_id].append(item)
        for row in conn.execute(
            """SELECT w.id,w.ea_id,w.status,w.verdict,w.payload_json,h.active
               FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
               WHERE w.phase=? AND h.hold_code=?""",
            (COMPILE_EA_PHASE, COMPILE_ACTIVATION_HOLD_CODE),
        ):
            ea_id = _numeric_ea_reference(row["ea_id"])
            if ea_id:
                rollout_holds[ea_id].append(dict(row))
        superseded_by: dict[str, set[str]] = defaultdict(set)
        for row in conn.execute(
            "SELECT work_item_id,superseded_by_work_item_id FROM work_item_supersedes "
            "WHERE superseded_by_work_item_id IS NOT NULL"
        ):
            superseded_by[str(row["work_item_id"])].add(
                str(row["superseded_by_work_item_id"])
            )
        build_tasks_by_id: dict[str, dict[str, Any]] = {}
        build_tasks_by_ea: dict[str, list[dict[str, Any]]] = defaultdict(list)
        build_ids: set[str] = set()
        for row in conn.execute(
            "SELECT id,status,card_id,payload_json FROM tasks WHERE kind='build_ea'"
        ):
            item = dict(row)
            build_tasks_by_id[str(row["id"])] = item
            ea_id = _numeric_ea_reference(row["card_id"])
            if not ea_id:
                continue
            build_tasks_by_ea[ea_id].append(item)
            if row["status"] in ("pending", "active", "done"):
                build_ids.add(ea_id)
    return {
        "registry_by_id": registry_by_id,
        "active_magics": active_magics,
        "work_rows": work_rows,
        "open_compile": open_compile,
        "rollout_holds": rollout_holds,
        "superseded_by": superseded_by,
        "build_ids": build_ids,
        "build_tasks_by_id": build_tasks_by_id,
        "build_tasks_by_ea": build_tasks_by_ea,
    }


def _build_task_binding(
    repo_root: Path,
    canonical_label: str,
    ea_id: str,
    build_task_id: str | None,
    inventory: dict[str, Any],
) -> dict[str, Any]:
    """Validate a single open build task as compile authority for its own EA.

    The ordinary classifier refuses every EA represented in the build backlog.
    A standard build running while the factory is live must nevertheless use a
    governed COMPILE_EA row.  This binding is deliberately narrow: it waives
    only BUILD_TASK_EXISTS, only for one exact open task, and only when the task
    payload still names the canonical EA id, slug, and directory.
    """
    requested_id = str(build_task_id or "").strip()
    result: dict[str, Any] = {
        "contract_version": BUILD_TASK_BINDING_CONTRACT_VERSION,
        "requested": bool(requested_id),
        "authorized": False,
        "build_task_id": requested_id or None,
    }
    if not requested_id:
        return {**result, "reason": "BUILD_TASK_BINDING_NOT_REQUESTED"}

    row = inventory.get("build_tasks_by_id", {}).get(requested_id)
    if not row:
        return {**result, "reason": "BUILD_TASK_BINDING_NOT_FOUND"}
    status = str(row.get("status") or "")
    result["build_task_status"] = status
    if status not in {"pending", "active"}:
        return {**result, "reason": "BUILD_TASK_BINDING_NOT_OPEN"}

    parts = _label_parts(canonical_label)
    if not parts:
        return {**result, "reason": "BUILD_TASK_BINDING_IDENTITY_MISMATCH"}
    _label, _numeric_id, slug = parts
    payload = _json_object(row.get("payload_json"))
    expected_dir = repo_root / "framework" / "EAs" / canonical_label
    try:
        payload_dir_matches = (
            Path(str(payload.get("ea_dir") or "")).resolve()
            == expected_dir.resolve()
        )
    except (OSError, RuntimeError):
        payload_dir_matches = False
    identity_matches = bool(
        _numeric_ea_reference(row.get("card_id")) == ea_id
        and _numeric_ea_reference(payload.get("ea_id")) == ea_id
        and str(payload.get("slug") or "") == slug
        and payload_dir_matches
    )
    if not identity_matches:
        return {**result, "reason": "BUILD_TASK_BINDING_IDENTITY_MISMATCH"}

    open_rows = [
        task
        for task in inventory.get("build_tasks_by_ea", {}).get(ea_id, [])
        if str(task.get("status") or "") in {"pending", "active"}
    ]
    if len(open_rows) != 1 or str(open_rows[0].get("id")) != requested_id:
        return {**result, "reason": "BUILD_TASK_BINDING_AMBIGUOUS"}
    return {**result, "authorized": True, "reason": "AUTHORIZED"}


def classify_candidate(
    root: Path,
    repo_root: Path,
    label: str,
    inventory: dict[str, Any],
    *,
    current_work_item_id: str | None = None,
    sanctioned_predecessor_ids: Iterable[str] = (),
    force_rebuild_ea_ids: frozenset[str] = frozenset(),
    source_repair_authority: str | None = None,
    bound_build_task_id: str | None = None,
) -> dict[str, Any]:
    parts = _label_parts(label)
    if not parts:
        return {"ea_label": label, "eligible": False, "reason": "EA_LABEL_INVALID"}
    canonical_label, ea_id, _slug = parts
    repair_requested = source_repair_authority is not None
    sanctioned_ids = {
        str(value) for value in sanctioned_predecessor_ids if str(value or "")
    }
    ea_dir = repo_root / "framework" / "EAs" / canonical_label
    source = ea_dir / f"{canonical_label}.mq5"
    source_sha = sha256_file(source) if source.is_file() else None
    ex5 = ea_dir / f"{canonical_label}.ex5"
    ex5_sha = sha256_file(ex5) if ex5.is_file() else None
    repair_authorized = _source_repair_authorized(
        canonical_label,
        source_repair_authority,
        repo_root=repo_root,
        ea_id=ea_id,
        source_sha=source_sha,
        inventory=inventory,
        current_work_item_id=current_work_item_id,
    )
    prior_compile_rows = [
        row
        for row in inventory["work_rows"].get(ea_id, [])
        if row.get("phase") == COMPILE_EA_PHASE
        and str(row.get("id")) != str(current_work_item_id or "")
    ]
    current_compile_ok = []
    for row in prior_compile_rows:
        prior_payload = _json_object(row.get("payload_json"))
        if (
            row.get("verdict") == "COMPILE_OK"
            and source_sha
            and ex5_sha
            and str(prior_payload.get("mq5_sha256") or "").lower()
            == source_sha.lower()
            and str(row.get("ex5_sha256") or prior_payload.get("ex5_sha256") or "").lower()
            == ex5_sha.lower()
        ):
            current_compile_ok.append(str(row.get("id")))
    open_rows = [
        row for row in inventory["open_compile"].get(ea_id, [])
        if str(row.get("id")) != str(current_work_item_id or "")
        and str(row.get("id")) not in sanctioned_ids
    ]
    if repair_authorized and source_sha:
        open_rows = [
            row
            for row in open_rows
            if str(_json_object(row.get("payload_json")).get("mq5_sha256") or "").lower()
            == source_sha.lower()
        ]
    if open_rows:
        return {
            "ea_label": canonical_label,
            "ea_id": f"QM5_{ea_id}",
            "eligible": False,
            "idempotent_open": True,
            "reason": "OPEN_COMPILE_EA_EXISTS",
            "work_item_ids": [row["id"] for row in open_rows],
        }
    reasons: list[str] = []
    if repair_requested and not repair_authorized:
        reasons.append("SOURCE_REPAIR_AUTHORITY_INVALID")
    if repair_authorized and current_compile_ok:
        reasons.append("USABLE_CURRENT_COMPILE_VERDICT_EXISTS")
    if not ea_dir.is_dir():
        reasons.append("EA_DIRECTORY_MISSING")
    if not source.is_file():
        reasons.append("MQ5_SOURCE_MISSING")
    if ex5.exists():
        reasons.append("EX5_ALREADY_PRESENT")
    registry_rows = inventory["registry_by_id"].get(ea_id, [])
    if len(registry_rows) != 1:
        reasons.append("EA_ID_REGISTRY_IDENTITY_INVALID")
    elif str(registry_rows[0].get("status") or "").strip().lower() != "active":
        reasons.append("EA_ID_REGISTRY_NOT_ACTIVE")
    magic_rows = inventory["active_magics"].get(ea_id, [])
    symbols = sorted({
        str(row.get("symbol") or "").strip()
        for row in magic_rows
        if str(row.get("symbol") or "").strip()
    })
    if not magic_rows:
        reasons.append("ACTIVE_MAGIC_ROWS_MISSING")
    if not symbols:
        reasons.append("ACTIVE_MAGIC_SYMBOLS_MISSING")
    invalid_symbols = [
        symbol for symbol in symbols
        if not re.fullmatch(r"[A-Z0-9._]+\.DWX", symbol, re.I)
    ]
    if invalid_symbols:
        reasons.append("SETFILE_SYMBOL_UNSUPPORTED")
    ignored_ids = sanctioned_ids | {str(current_work_item_id or "")}
    other_work = [
        row for row in inventory["work_rows"].get(ea_id, [])
        if str(row.get("id")) not in ignored_ids
    ]
    if other_work:
        reasons.append("WORK_ITEMS_EXIST")
    build_task_binding = _build_task_binding(
        repo_root,
        canonical_label,
        ea_id,
        bound_build_task_id,
        inventory,
    )
    if build_task_binding["requested"] and not build_task_binding["authorized"]:
        reasons.append(str(build_task_binding["reason"]))
    if ea_id in inventory["build_ids"] and not build_task_binding["authorized"]:
        reasons.append("BUILD_TASK_EXISTS")
    bound_hashes = _bound_setfile_hashes(ea_dir) if ea_dir.is_dir() else []
    if bound_hashes:
        reasons.append("BOUND_SETFILE_HASH_EXISTS")
    timeframe = infer_timeframe(root, repo_root, ea_dir) if source.is_file() else {
        "timeframe": None,
        "source": "source_missing",
        "candidates": [],
    }
    if source.is_file() and not timeframe.get("timeframe"):
        reasons.append("TIMEFRAME_UNRESOLVED")

    force_rebuild_authorized = ea_id in force_rebuild_ea_ids
    force_rebuild_waived_reasons: list[str] = []
    if force_rebuild_authorized:
        force_rebuild_waived_reasons = sorted(
            reason for reason in reasons if reason in FORCE_REBUILD_WAIVABLE_REASONS
        )
        reasons = [
            reason for reason in reasons if reason not in FORCE_REBUILD_WAIVABLE_REASONS
        ]
    source_repair_waived_reasons: list[str] = []
    if repair_authorized and not current_compile_ok:
        source_repair_waived_reasons = sorted(
            reason for reason in reasons if reason in FORCE_REBUILD_WAIVABLE_REASONS
        )
        reasons = [
            reason for reason in reasons if reason not in FORCE_REBUILD_WAIVABLE_REASONS
        ]

    return {
        "ea_label": canonical_label,
        "ea_id": f"QM5_{ea_id}",
        "numeric_ea_id": ea_id,
        "ea_dir": str(ea_dir),
        "mq5_path": str(source),
        "mq5_sha256": source_sha,
        "eligible": not reasons,
        "reason": "ELIGIBLE" if not reasons else reasons[0],
        "reasons": reasons,
        "symbols": symbols,
        "unsupported_symbols": invalid_symbols,
        "active_magic_row_count": len(magic_rows),
        "bound_setfile_hashes": bound_hashes,
        "timeframe": timeframe,
        "build_task_binding": build_task_binding,
        "build_task_binding_authorized": build_task_binding["authorized"],
        "sanctioned_predecessor_ids": sorted(sanctioned_ids),
        "force_rebuild_authorized": force_rebuild_authorized,
        "force_rebuild_waived_reasons": force_rebuild_waived_reasons,
        "source_repair_authorized": repair_authorized and not current_compile_ok,
        "source_repair_authority": source_repair_authority,
        "source_repair_contract_version": SOURCE_REPAIR_CONTRACT_VERSION,
        "source_repair_waived_reasons": source_repair_waived_reasons,
        "source_repair_predecessor_work_item_ids": sorted(
            str(row.get("id")) for row in prior_compile_rows
        ),
        "source_repair_stale_open_work_item_ids": sorted(
            str(row.get("id"))
            for row in inventory["open_compile"].get(ea_id, [])
            if str(row.get("id")) != str(current_work_item_id or "")
            and str(_json_object(row.get("payload_json")).get("mq5_sha256") or "").lower()
            != str(source_sha or "").lower()
        ),
        "source_repair_artifact_bindings": (
            _hma_cata_requal_artifact_bindings()
            if repair_authorized
            and source_repair_authority == HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY
            else []
        ),
        "current_compile_ok_work_item_ids": current_compile_ok,
    }


def _json_object(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _work_row_by_id(
    inventory: dict[str, Any], ea_id: str, work_item_id: str
) -> dict[str, Any] | None:
    return next(
        (
            row
            for row in inventory["work_rows"].get(ea_id, [])
            if str(row.get("id")) == str(work_item_id)
        ),
        None,
    )


def _sanctioned_compile_predecessor_ids(
    payload: dict[str, Any],
    inventory: dict[str, Any],
    ea_id: str,
    *,
    seen: frozenset[str] = frozenset(),
) -> set[str]:
    """Return only incident-authorized immutable COMPILE_EA lineage.

    COMPILE_EA normally refuses an EA with *any* prior work. The R11 repair
    incident necessarily leaves one immutable failed COMPILE_EA predecessor,
    and the first post-revival canary left a second immutable failure before
    this check was corrected. Those two exact lineages are the only exception;
    malformed provenance fails closed and ordinary Q work is never ignored.
    """

    source_sha = str(payload.get("mq5_sha256") or "").lower()
    if not _BOUND_HASH_RE.fullmatch(source_sha):
        return set()

    if (
        payload.get("compile_retry_contract_version")
        == COMPILE_BINDING_RETRY_CONTRACT_VERSION
        and payload.get("compile_retry_authority_task_id")
        == COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID
        and payload.get("append_only_retry") is True
    ):
        predecessor_id = str(payload.get("retry_of_work_item_id") or "")
        if not predecessor_id or predecessor_id in seen:
            return set()
        predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
        if not predecessor:
            return set()
        predecessor_payload = _json_object(predecessor.get("payload_json"))
        compile_result = predecessor_payload.get("compile_result")
        failure_classes = (
            compile_result.get("failure_classes", [])
            if isinstance(compile_result, dict)
            else []
        )
        if not (
            predecessor.get("phase") == COMPILE_EA_PHASE
            and predecessor.get("status") == "failed"
            and predecessor.get("verdict") == "COMPILE_FAIL"
            and predecessor_payload.get("verdict_reason")
            == COMPILE_BINDING_FAILURE_CLASS
            and failure_classes == [COMPILE_BINDING_FAILURE_CLASS]
            and predecessor_payload.get("compile_retry_contract_version")
            == COMPILE_RECHECK_RETRY_CONTRACT_VERSION
            and predecessor_payload.get("compile_retry_authority_task_id")
            == COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID
            and predecessor_payload.get("append_only_retry") is True
            and str(predecessor_payload.get("mq5_sha256") or "").lower()
            == source_sha
        ):
            return set()
        earlier = _sanctioned_compile_predecessor_ids(
            predecessor_payload,
            inventory,
            ea_id,
            seen=seen | {predecessor_id},
        )
        if not earlier:
            return set()
        return {predecessor_id, *earlier}

    if (
        payload.get("compile_retry_contract_version")
        == COMPILE_RECHECK_RETRY_CONTRACT_VERSION
        and payload.get("compile_retry_authority_task_id")
        == COMPILE_RECHECK_RETRY_AUTHORITY_TASK_ID
        and payload.get("append_only_retry") is True
    ):
        predecessor_id = str(payload.get("retry_of_work_item_id") or "")
        if not predecessor_id or predecessor_id in seen:
            return set()
        predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
        if not predecessor:
            return set()
        predecessor_payload = _json_object(predecessor.get("payload_json"))
        compile_result = predecessor_payload.get("compile_result")
        failure_classes = (
            compile_result.get("failure_classes", [])
            if isinstance(compile_result, dict)
            else []
        )
        if not (
            predecessor.get("phase") == COMPILE_EA_PHASE
            and predecessor.get("status") == "failed"
            and predecessor.get("verdict") == "COMPILE_FAIL"
            and predecessor_payload.get("verdict_reason")
            == COMPILE_RECHECK_FAILURE_CLASS
            and failure_classes == [COMPILE_RECHECK_FAILURE_CLASS]
            and str(predecessor_payload.get("mq5_sha256") or "").lower()
            == source_sha
        ):
            return set()
        earlier = _sanctioned_compile_predecessor_ids(
            predecessor_payload,
            inventory,
            ea_id,
            seen=seen | {predecessor_id},
        )
        # A retry is valid only when its failed predecessor itself has the exact
        # R11 revival lineage. This prevents a forged retry marker from hiding
        # arbitrary historical work.
        if not earlier:
            return set()
        return {predecessor_id, *earlier}

    if not (
        payload.get("revival_contract_version") == R11_REVIVAL_CONTRACT_VERSION
        and payload.get("revival_authority_task_id") == R11_REVIVAL_AUTHORITY_TASK_ID
        and payload.get("revival_reason") == R11_REVIVAL_REASON
        and payload.get("append_only_revival") is True
        and str(payload.get("revival_source_mq5_sha256") or "").lower()
        == source_sha
    ):
        return set()
    predecessor_id = str(payload.get("revived_from_work_item_id") or "")
    if not predecessor_id or predecessor_id in seen:
        return set()
    predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
    if not predecessor:
        return set()
    predecessor_payload = _json_object(predecessor.get("payload_json"))
    if not (
        predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "failed"
        and predecessor.get("verdict") == "INVALID"
        and predecessor_payload.get("repair_handler") == R11_INCIDENT_HANDLER
        and predecessor_payload.get("verdict_reason") == R11_INCIDENT_REASON
        and str(predecessor_payload.get("mq5_sha256") or "").lower()
        == source_sha
    ):
        return set()
    return {predecessor_id}


def load_labels(explicit: Iterable[str], from_file: str | None, repo_root: Path) -> tuple[list[str], dict[str, Any]]:
    labels = [str(value).strip() for value in explicit if str(value).strip()]
    metadata: dict[str, Any] = {"from_file": None, "from_file_sha256": None}
    if from_file:
        path = Path(from_file).expanduser()
        if not path.is_absolute():
            path = repo_root / path
        path = path.resolve()
        if not path.is_file():
            raise ValueError(f"compile label input does not exist: {path}")
        metadata.update({"from_file": str(path), "from_file_sha256": sha256_file(path)})
        if path.suffix.lower() == ".csv":
            with path.open(encoding="utf-8-sig", newline="") as handle:
                reader = csv.DictReader(handle)
                fields = reader.fieldnames or []
                column = next((key for key in ("ea_label", "label") if key in fields), None)
                if not column:
                    raise ValueError("compile CSV requires an ea_label or label column")
                labels.extend(str(row.get(column) or "").strip() for row in reader)
        else:
            labels.extend(
                line.strip()
                for line in path.read_text(encoding="utf-8-sig").splitlines()
                if line.strip() and not line.lstrip().startswith("#")
            )
    unique = list(dict.fromkeys(label for label in labels if label))
    unique.sort(key=lambda label: (
        int(_label_parts(label)[1]) if _label_parts(label) else 10**12,
        label,
    ))
    metadata["requested_count"] = len(unique)
    return unique, metadata


def enqueue_compile_eas(
    root: Path,
    repo_root: Path,
    explicit_labels: Iterable[str],
    *,
    from_file: str | None = None,
    apply: bool = False,
    source_repair_authority: str | None = None,
    build_task_id: str | None = None,
) -> dict[str, Any]:
    labels, input_metadata = load_labels(explicit_labels, from_file, repo_root)
    if not labels:
        return {"ok": False, "reason": "NO_EA_LABELS", "enqueued_count": 0}
    bound_build_task_id = str(build_task_id or "").strip() or None
    if bound_build_task_id and (from_file or len(labels) != 1):
        return {
            "ok": False,
            "reason": "BUILD_TASK_BINDING_REQUIRES_ONE_EXPLICIT_EA_LABEL",
            "enqueued_count": 0,
        }
    # Explicit labels are an intentionally narrow single/manual form.  A file
    # is the batch form and remains dry-run until --apply is present.
    apply_effective = bool(apply or not from_file)
    inventory = _inventory(root, repo_root)
    force_rebuild_ea_ids = force_rebuild_allowlist(root, repo_root)
    classified = [
        classify_candidate(
            root, repo_root, label, inventory,
            force_rebuild_ea_ids=force_rebuild_ea_ids,
            source_repair_authority=source_repair_authority,
            bound_build_task_id=bound_build_task_id,
        )
        for label in labels
    ]
    eligible = [row for row in classified if row.get("eligible")]
    idempotent = [row for row in classified if row.get("idempotent_open")]
    refused = [row for row in classified if not row.get("eligible") and not row.get("idempotent_open")]
    enqueued: list[dict[str, Any]] = []
    if apply_effective and eligible:
        now = utc_now()
        with _connect(root) as conn:
            conn.execute("BEGIN IMMEDIATE")
            for candidate in eligible:
                if bound_build_task_id:
                    current_build_tasks_by_id: dict[str, dict[str, Any]] = {}
                    current_build_tasks_by_ea: dict[str, list[dict[str, Any]]] = (
                        defaultdict(list)
                    )
                    for task_row in conn.execute(
                        "SELECT id,status,card_id,payload_json FROM tasks "
                        "WHERE kind='build_ea'"
                    ):
                        task = dict(task_row)
                        current_build_tasks_by_id[str(task_row["id"])] = task
                        task_ea_id = _numeric_ea_reference(task_row["card_id"])
                        if task_ea_id:
                            current_build_tasks_by_ea[task_ea_id].append(task)
                    current_binding = _build_task_binding(
                        repo_root,
                        str(candidate["ea_label"]),
                        str(candidate["numeric_ea_id"]),
                        bound_build_task_id,
                        {
                            "build_tasks_by_id": current_build_tasks_by_id,
                            "build_tasks_by_ea": current_build_tasks_by_ea,
                        },
                    )
                    if not current_binding["authorized"]:
                        refused.append({
                            **candidate,
                            "eligible": False,
                            "reason": "BUILD_TASK_BINDING_INVALID_AT_APPLY",
                            "reasons": ["BUILD_TASK_BINDING_INVALID_AT_APPLY"],
                            "build_task_binding": current_binding,
                        })
                        continue
                if (
                    source_repair_authority
                    == HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY
                    and not _hma_cata_requal_authorized(
                        repo_root,
                        str(candidate["ea_label"]),
                        source_repair_authority,
                    )
                ):
                    refused.append({
                        **candidate,
                        "eligible": False,
                        "reason": "SOURCE_REPAIR_AUTHORITY_INVALID_AT_APPLY",
                        "reasons": ["SOURCE_REPAIR_AUTHORITY_INVALID_AT_APPLY"],
                    })
                    continue
                if (
                    source_repair_authority
                    == ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY
                    and not _active_stale_rollout_hold_exists(
                        conn,
                        ea_id=str(candidate["ea_id"]),
                        ea_label=str(candidate["ea_label"]),
                        source_sha=str(candidate["mq5_sha256"]),
                    )
                ):
                    refused.append({
                        **candidate,
                        "eligible": False,
                        "reason": "SOURCE_REPAIR_AUTHORITY_INVALID_AT_APPLY",
                        "reasons": ["SOURCE_REPAIR_AUTHORITY_INVALID_AT_APPLY"],
                    })
                    continue
                existing_rows = conn.execute(
                    "SELECT id,payload_json FROM work_items WHERE ea_id=? AND phase=? "
                    "AND status IN ('pending','active') ORDER BY created_at,id",
                    (candidate["ea_id"], COMPILE_EA_PHASE),
                ).fetchall()
                if existing_rows:
                    current_hash = str(candidate.get("mq5_sha256") or "").lower()
                    current_hash_rows = [
                        row
                        for row in existing_rows
                        if str(
                            _json_object(row["payload_json"]).get("mq5_sha256") or ""
                        ).lower() == current_hash
                    ]
                    if (
                        not candidate.get("source_repair_authorized")
                        or current_hash_rows
                    ):
                        blocking_rows = (
                            current_hash_rows
                            if candidate.get("source_repair_authorized")
                            else existing_rows
                        )
                        idempotent.append({
                            **candidate,
                            "eligible": False,
                            "idempotent_open": True,
                            "reason": "OPEN_COMPILE_EA_EXISTS",
                            "work_item_ids": [row["id"] for row in blocking_rows],
                        })
                        continue
                if (
                    not candidate.get("force_rebuild_authorized")
                    and not candidate.get("source_repair_authorized")
                ):
                    any_work = conn.execute(
                        "SELECT id FROM work_items WHERE ea_id=? LIMIT 1",
                        (candidate["ea_id"],),
                    ).fetchone()
                    if any_work:
                        refused.append({
                            **candidate,
                            "eligible": False,
                            "reason": "WORK_ITEMS_EXIST_AT_APPLY",
                            "reasons": ["WORK_ITEMS_EXIST_AT_APPLY"],
                        })
                        continue
                work_item_id = str(uuid.uuid4())
                payload = {
                    "compile_contract_version": COMPILE_CONTRACT_VERSION,
                    "compile_activation_state": "AWAITING_REVIEWED_WORKER_ROLLOUT",
                    "compile_activation_hold_code": COMPILE_ACTIVATION_HOLD_CODE,
                    "ea_label": candidate["ea_label"],
                    "ea_dir": candidate["ea_dir"],
                    "mq5_path": candidate["mq5_path"],
                    "mq5_sha256": candidate["mq5_sha256"],
                    "symbols": candidate["symbols"],
                    "timeframe": candidate["timeframe"],
                    "risk_contract": {"RISK_FIXED": 1000.0, "RISK_PERCENT": 0.0},
                    "utility_phase": True,
                    "no_gate_verdict": True,
                    "enqueued_at": now,
                }
                if candidate.get("build_task_binding_authorized"):
                    payload.update({
                        "compile_build_task_binding_contract_version": (
                            BUILD_TASK_BINDING_CONTRACT_VERSION
                        ),
                        "bound_build_task_id": bound_build_task_id,
                        "bound_build_task_ea_id": candidate["ea_id"],
                    })
                if candidate.get("force_rebuild_authorized"):
                    payload.update({
                        "force_rebuild": True,
                        "force_rebuild_owner_reference": force_rebuild_owner_reference(
                            str(candidate["numeric_ea_id"])
                        ),
                        "force_rebuild_waived_reasons": candidate.get(
                            "force_rebuild_waived_reasons", []
                        ),
                    })
                if candidate.get("source_repair_authorized"):
                    payload.update({
                        "compile_source_repair_contract_version": (
                            SOURCE_REPAIR_CONTRACT_VERSION
                        ),
                        "compile_source_repair_authority": source_repair_authority,
                        "append_only_source_repair": True,
                        "source_repair_predecessor_work_item_ids": candidate.get(
                            "source_repair_predecessor_work_item_ids", []
                        ),
                        "source_repair_stale_open_work_item_ids": candidate.get(
                            "source_repair_stale_open_work_item_ids", []
                        ),
                        "source_repair_waived_reasons": candidate.get(
                            "source_repair_waived_reasons", []
                        ),
                        "source_repair_artifact_bindings": candidate.get(
                            "source_repair_artifact_bindings", []
                        ),
                    })
                    if (
                        source_repair_authority
                        == HMA_CATA_REQUAL_SOURCE_REPAIR_AUTHORITY
                    ):
                        payload.update({
                            "owner_decision_id": HMA_CATA_REQUAL_OWNER_DECISION_ID,
                            "requalification_scope": "QM_HMA_CATEGORY_A",
                            "requalification_new_identity_from_phase": "Q02",
                        })
                conn.execute(
                    "INSERT INTO work_items "
                    "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,"
                    "payload_json,created_at,updated_at) "
                    "VALUES (?,?,?,?,?,'','pending',0,?,?,?)",
                    (
                        work_item_id,
                        COMPILE_WORK_ITEM_KIND,
                        COMPILE_EA_PHASE,
                        candidate["ea_id"],
                        "",
                        json.dumps(payload, sort_keys=True),
                        now,
                        now,
                    ),
                )
                conn.execute(
                    "INSERT INTO work_item_holds "
                    "(work_item_id,hold_code,reason,active,release_on_restart,"
                    "created_at,updated_at,released_at,release_note) "
                    "VALUES (?,?,?,1,1,?,?,NULL,NULL)",
                    (
                        work_item_id,
                        COMPILE_ACTIVATION_HOLD_CODE,
                        COMPILE_ACTIVATION_HOLD_REASON,
                        now,
                        now,
                    ),
                )
                enqueued.append({
                    "work_item_id": work_item_id,
                    "ea_id": candidate["ea_id"],
                    "ea_label": candidate["ea_label"],
                    "symbol_count": len(candidate["symbols"]),
                    "timeframe": candidate["timeframe"],
                    "status": "pending",
                    "compiled": False,
                    "failed": False,
                    "failure_classes": [],
                    "activation_hold_code": COMPILE_ACTIVATION_HOLD_CODE,
                })
            conn.commit()
    return {
        "ok": not refused,
        "mode": "apply" if apply_effective else "dry_run",
        "batch_form": bool(from_file),
        "input_metadata": input_metadata,
        "requested_count": len(labels),
        "eligible_count": len(eligible),
        "enqueued_count": len(enqueued),
        "activation_held_count": len(enqueued),
        "idempotent_open_count": len(idempotent),
        "refused_count": len(refused),
        "enqueued": enqueued,
        "idempotent_open": idempotent,
        "refused": refused,
        "candidate_classification": classified if not apply_effective else None,
        "no_gate_verdict": True,
        "source_repair_authority": source_repair_authority,
        "build_task_id": bound_build_task_id,
    }


def compile_batch_status(
    root: Path,
    repo_root: Path,
    explicit_labels: Iterable[str],
    *,
    from_file: str | None = None,
) -> dict[str, Any]:
    """Report the latest COMPILE_EA outcome per requested EA label."""
    labels, input_metadata = load_labels(explicit_labels, from_file, repo_root)
    if not labels:
        return {"ok": False, "reason": "NO_EA_LABELS", "results": []}
    results: list[dict[str, Any]] = []
    with _connect(root) as conn:
        for label in labels:
            parts = _label_parts(label)
            if not parts:
                results.append({
                    "ea_label": label,
                    "status": "NOT_FOUND",
                    "compiled": False,
                    "failed": False,
                    "failure_classes": ["EA_LABEL_INVALID"],
                })
                continue
            ea_id = f"QM5_{parts[1]}"
            row = conn.execute(
                "SELECT w.*,h.hold_code,h.active AS hold_active "
                "FROM work_items w LEFT JOIN work_item_holds h ON h.work_item_id=w.id "
                "WHERE w.ea_id=? AND w.phase=? "
                "ORDER BY w.created_at DESC,w.id DESC LIMIT 1",
                (ea_id, COMPILE_EA_PHASE),
            ).fetchone()
            if row is None:
                results.append({
                    "ea_label": label,
                    "ea_id": ea_id,
                    "status": "NOT_ENQUEUED",
                    "compiled": False,
                    "failed": False,
                    "failure_classes": [],
                })
                continue
            payload = json.loads(row["payload_json"] or "{}")
            compile_result = payload.get("compile_result") or {}
            status = str(row["status"] or "")
            verdict = str(row["verdict"] or "")
            results.append({
                "ea_label": label,
                "ea_id": ea_id,
                "work_item_id": row["id"],
                "status": status,
                "verdict": verdict or None,
                "compiled": status == "done" and verdict == "COMPILE_OK",
                "failed": status == "failed" or verdict == "COMPILE_FAIL",
                "failure_classes": list(compile_result.get("failure_classes") or []),
                "ex5_sha256": compile_result.get("ex5_sha256"),
                "setfile_count": compile_result.get("setfile_count", 0),
                "build_check_result": compile_result.get("build_check_result"),
                "evidence_path": row["evidence_path"],
                "activation_hold": (
                    row["hold_code"] if row["hold_active"] == 1 else None
                ),
            })
    counts = {
        "compiled": sum(1 for row in results if row["compiled"]),
        "failed": sum(1 for row in results if row["failed"]),
        "pending": sum(1 for row in results if row["status"] == "pending"),
        "active": sum(1 for row in results if row["status"] == "active"),
        "not_enqueued": sum(
            1 for row in results if row["status"] in {"NOT_ENQUEUED", "NOT_FOUND"}
        ),
        "activation_held": sum(1 for row in results if row.get("activation_hold")),
    }
    return {
        "ok": counts["not_enqueued"] == 0,
        "input_metadata": input_metadata,
        "requested_count": len(labels),
        "counts": counts,
        "results": results,
        "no_gate_verdict": True,
    }


def _atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with temp.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass


def _output_value(output: str, key: str) -> str | None:
    match = re.search(rf"(?m)^\s*{re.escape(key)}=(.*)$", output)
    return match.group(1).strip() if match else None


def _output_bool(output: str, key: str) -> bool | None:
    value = _output_value(output, key)
    if value is None:
        return None
    normalized = value.strip().lower()
    if normalized == "true":
        return True
    if normalized == "false":
        return False
    return None


def _failure_classes(output: str, exit_code: int) -> list[str]:
    classes: list[str] = []
    reason = _output_value(output, "compile_one.reason_class")
    if reason and reason != "OK":
        classes.append(reason)
    for match in re.finditer(r"(?m)^ERROR:\s*([A-Z][A-Z0-9_]+)", output):
        classes.append(match.group(1))
    if exit_code != 0 and not classes:
        classes.append("BUILD_CHECK_FAILED")
    return list(dict.fromkeys(classes))


def _complete_work_item(
    root: Path,
    work_item_id: str,
    terminal: str,
    evidence_path: Path,
    evidence: dict[str, Any],
) -> None:
    success = bool(evidence.get("success"))
    failure_classes = list(evidence.get("failure_classes") or [])
    infra_failure = COMPILE_PROFILE_STDLIB_FAILURE_CLASS in failure_classes
    status = "done" if success else "failed"
    verdict = "COMPILE_OK" if success else ("INFRA_FAIL" if infra_failure else "COMPILE_FAIL")
    now = utc_now()
    with _connect(root) as conn:
        row = conn.execute(
            "SELECT payload_json,status,claimed_by FROM work_items WHERE id=?",
            (work_item_id,),
        ).fetchone()
        if not row or row["status"] != "active" or str(row["claimed_by"]).upper() != terminal.upper():
            raise RuntimeError(
                f"COMPILE_EA ownership changed before completion: {work_item_id}"
            )
        payload = json.loads(row["payload_json"] or "{}")
        payload.update({
            "compile_completed_at": now,
            "compile_result": {
                "success": success,
                "failure_classes": failure_classes,
                "compile_result": evidence.get("compile_result"),
                "build_check_result": evidence.get("build_check_result"),
                "ex5_sha256": evidence.get("ex5_sha256"),
                "setfile_count": evidence.get("setfile_count", 0),
                "evidence_path": str(evidence_path),
                "no_gate_verdict": True,
            },
            "verdict_reason": (
                "COMPILE_ARTIFACT_READY"
                if success
                else (
                    COMPILE_PROFILE_STDLIB_FAILURE_CLASS
                    if infra_failure
                    else ";".join(failure_classes or ["COMPILE_FAILED"])
                )
            ),
            "verdict_taxonomy": "infra" if infra_failure else ("build" if not success else "artifact"),
        })
        taxonomy = str(payload["verdict_taxonomy"])
        identity = extract_identity(evidence, payload)
        identity_sql, identity_values = identity_update_clause(conn, identity, taxonomy)
        identity_sql = ("," + identity_sql) if identity_sql else ""
        cur = conn.execute(
            "UPDATE work_items SET status=?,verdict=?,evidence_path=?,claimed_by=NULL,"
            f"payload_json=?,updated_at=?{identity_sql} "
            "WHERE id=? AND status='active' AND upper(claimed_by)=upper(?)",
            (
                status,
                verdict,
                str(evidence_path),
                json.dumps(payload, sort_keys=True),
                now,
                *identity_values,
                work_item_id,
                terminal,
            ),
        )
        if cur.rowcount != 1:
            conn.rollback()
            raise RuntimeError(f"COMPILE_EA completion CAS failed: {work_item_id}")
        conn.commit()


def run_compile_work_item(
    root: Path,
    repo_root: Path,
    item: sqlite3.Row | dict[str, Any],
    terminal: str,
) -> dict[str, Any]:
    """Run one already-claimed COMPILE_EA row without launching terminal64."""
    # A narrowly commissioned runtime-equivalence utility reuses the compile
    # work-item dispatch class so a resident worker owns an idle terminal, but
    # it is not a compile and must not pass through candidate classification or
    # emit a pipeline verdict.  Keep this import lazy: ordinary COMPILE_EA
    # workers retain their small, terminal-free execution path unchanged.
    try:
        dispatch_payload = json.loads(item["payload_json"] or "{}")
    except (json.JSONDecodeError, TypeError):
        dispatch_payload = {}
    if dispatch_payload.get("equivalence_contract_version") == (
        "qm.qm5-35005-pattern-include-equivalence/v1"
    ):
        try:
            from tools.strategy_farm import qm5_35005_equivalence
        except ModuleNotFoundError:
            import qm5_35005_equivalence
        return qm5_35005_equivalence.run_work_item(
            root,
            repo_root,
            item,
            terminal,
        )

    work_item_id = str(item["id"])
    report_dir = (
        Path(r"D:\QM\reports\work_items")
        / work_item_id
        / str(item["ea_id"])
        / COMPILE_EA_PHASE
    )
    evidence_path = report_dir / "compile_evidence.json"
    started_at = utc_now()
    evidence: dict[str, Any] = {
        "schema_version": "qm.compile-ea-evidence/v1",
        "work_item_id": work_item_id,
        "ea_id": str(item["ea_id"]),
        "phase": COMPILE_EA_PHASE,
        "terminal_claim": terminal,
        "started_at": started_at,
        "no_gate_verdict": True,
        "failure_classes": [],
        "setfile_generation": [],
    }
    try:
        inventory = _inventory(root, repo_root)
        payload = json.loads(item["payload_json"] or "{}")
        evidence["claim_admission_mode"] = payload.get("claim_admission_mode")
        evidence["claim_admission_commit_headroom_gb"] = payload.get(
            "claim_admission_commit_headroom_gb"
        )
        evidence["claim_admission_commit_reserved_gb"] = payload.get(
            "claim_admission_commit_reserved_gb"
        )
        evidence["claim_admission_effective_commit_headroom_gb"] = payload.get(
            "claim_admission_effective_commit_headroom_gb"
        )
        label = str(payload.get("ea_label") or "")
        parts = _label_parts(label)
        sanctioned_predecessors = (
            _sanctioned_compile_predecessor_ids(
                payload,
                inventory,
                parts[1],
            )
            if parts
            else set()
        )
        candidate = classify_candidate(
            root,
            repo_root,
            label,
            inventory,
            current_work_item_id=work_item_id,
            sanctioned_predecessor_ids=sanctioned_predecessors,
            force_rebuild_ea_ids=force_rebuild_allowlist(root, repo_root),
            source_repair_authority=(
                str(payload.get("compile_source_repair_authority") or "")
                if payload.get("append_only_source_repair") is True
                and payload.get("compile_source_repair_contract_version")
                == SOURCE_REPAIR_CONTRACT_VERSION
                else None
            ),
            bound_build_task_id=(
                str(payload.get("bound_build_task_id") or "")
                if payload.get("compile_build_task_binding_contract_version")
                == BUILD_TASK_BINDING_CONTRACT_VERSION
                else None
            ),
        )
        evidence["ea_label"] = label
        evidence["candidate_recheck"] = candidate
        if not candidate.get("eligible"):
            raise RuntimeError("CANDIDATE_RECHECK_REFUSED:" + ";".join(candidate.get("reasons") or [candidate.get("reason")]))
        if candidate.get("mq5_sha256") != payload.get("mq5_sha256"):
            raise RuntimeError("SOURCE_CHANGED_AFTER_ENQUEUE")
        running = running_terminal_names()
        evidence["running_terminals_at_worker_start"] = sorted(running)
        if terminal.upper() in running:
            raise RuntimeError("COMPILE_CLAIMED_TERMINAL_RUNNING")
        timeframe = str((candidate.get("timeframe") or {}).get("timeframe") or "")
        if not timeframe:
            raise RuntimeError("TIMEFRAME_UNRESOLVED")
        ea_dir = Path(candidate["ea_dir"])
        symbols = list(candidate["symbols"])
        env = os.environ.copy()
        env["QM_COMPILE_WORK_ITEM_ID"] = work_item_id
        env["QM_COMPILE_CLAIMED_TERMINAL"] = terminal.upper()
        creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        generator = repo_root / "framework" / "scripts" / "gen_setfile.ps1"
        for symbol in symbols:
            command = [
                "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", str(generator),
                "-EaSlug", label,
                "-Symbol", symbol,
                "-TF", timeframe,
                "-Env", "backtest",
                "-RiskFixed", "1000",
                "-RiskPercent", "0",
            ]
            generated = subprocess.run(
                command,
                cwd=repo_root,
                env=env,
                capture_output=True,
                text=True,
                timeout=300,
                creationflags=creationflags,
                check=False,
            )
            output = (generated.stdout or "") + (generated.stderr or "")
            setfile = ea_dir / "sets" / f"{label}_{symbol}_{timeframe}_backtest.set"
            generation = {
                "symbol": symbol,
                "exit_code": generated.returncode,
                "setfile_path": str(setfile),
                "setfile_exists": setfile.is_file(),
                "setfile_sha256": sha256_file(setfile) if setfile.is_file() else None,
                "output_tail": output[-4000:],
            }
            evidence["setfile_generation"].append(generation)
            if generated.returncode != 0 or not setfile.is_file():
                raise RuntimeError(f"SETFILE_GENERATION_FAILED:{symbol}")

        build_check = repo_root / "framework" / "scripts" / "build_check.ps1"
        build_command = [
            "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", str(build_check),
            "-EALabel", label,
            "-Strict",
            "-CompileWorkItemId", work_item_id,
            "-ClaimedTerminal", terminal.upper(),
        ]
        checked = subprocess.run(
            build_command,
            cwd=repo_root,
            env=env,
            capture_output=True,
            text=True,
            timeout=1800,
            creationflags=creationflags,
            check=False,
        )
        build_output = (checked.stdout or "") + (checked.stderr or "")
        evidence.update({
            "build_check_exit_code": checked.returncode,
            "build_check_result": _output_value(build_output, "build_check.result"),
            "build_check_report": _output_value(build_output, "build_check.report"),
            "compile_result": _output_value(build_output, "compile_one.result"),
            "compile_reason_class": _output_value(build_output, "compile_one.reason_class"),
            "compile_errors": _output_value(build_output, "compile_one.errors"),
            "compile_warnings": _output_value(build_output, "compile_one.warnings"),
            "compile_log": _output_value(build_output, "compile_one.log"),
            "compile_summary": _output_value(build_output, "compile_one.summary"),
            "include_sync_targets": _output_value(build_output, "compile_one.include_sync_targets"),
            "include_sync_deferred_targets": _output_value(build_output, "compile_one.include_sync_deferred_targets"),
            "include_mirror_mutex": _output_value(build_output, "compile_one.include_mirror_mutex"),
            "include_mirror_atomic_replace": _output_bool(
                build_output,
                "compile_one.include_mirror_atomic_replace",
            ),
            "compile_profile_stdlib_source": _output_value(
                build_output, "compile_one.compile_profile_stdlib_source"
            ),
            "compile_profile_stdlib_missing": _output_value(
                build_output, "compile_one.compile_profile_stdlib_missing"
            ),
            "compile_profile_stdlib_repair": _output_value(
                build_output, "compile_one.compile_profile_stdlib_repair"
            ),
            "build_check_output_tail": build_output[-20000:],
        })
        ex5 = ea_dir / f"{label}.ex5"
        setfiles = sorted((ea_dir / "sets").glob("*.set"))
        evidence["ex5_path"] = str(ex5)
        evidence["ex5_sha256"] = sha256_file(ex5) if ex5.is_file() else None
        evidence["setfile_count"] = len(setfiles)
        evidence["failure_classes"] = _failure_classes(build_output, checked.returncode)
        evidence["success"] = bool(
            checked.returncode == 0
            and evidence["build_check_result"] == "PASS"
            and evidence["compile_result"] == "PASS"
            and evidence["ex5_sha256"]
            and evidence["setfile_count"] > 0
        )
        if not evidence["success"] and not evidence["failure_classes"]:
            evidence["failure_classes"] = ["COMPILE_ARTIFACT_CONTRACT_INCOMPLETE"]
    except subprocess.TimeoutExpired as exc:
        evidence.update({
            "success": False,
            "failure_classes": ["COMPILE_WORKER_TIMEOUT"],
            "exception": repr(exc),
        })
    except Exception as exc:
        detail = str(exc)
        failure_class = detail.split(":", 1)[0] if detail else "COMPILE_WORKER_EXCEPTION"
        evidence.update({
            "success": False,
            "failure_classes": [failure_class],
            "exception": repr(exc),
        })
    evidence["completed_at"] = utc_now()
    evidence["verdict_taxonomy"] = (
        "infra"
        if COMPILE_PROFILE_STDLIB_FAILURE_CLASS in evidence.get("failure_classes", [])
        else ("artifact" if evidence.get("success") else "build")
    )
    _atomic_write_json(evidence_path, evidence)
    _complete_work_item(root, work_item_id, terminal, evidence_path, evidence)
    return {
        "action": "compile_ea_finished",
        "item_id": work_item_id,
        "ea_id": str(item["ea_id"]),
        "ea_label": evidence.get("ea_label"),
        "success": evidence.get("success", False),
        "failure_classes": evidence.get("failure_classes", []),
        "compile_result": evidence.get("compile_result"),
        "build_check_result": evidence.get("build_check_result"),
        "ex5_sha256": evidence.get("ex5_sha256"),
        "setfile_count": evidence.get("setfile_count", 0),
        "evidence_path": str(evidence_path),
        "no_gate_verdict": True,
    }
