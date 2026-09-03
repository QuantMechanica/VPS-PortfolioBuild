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
RECHECK_SUCCESSOR_CONTRACT_VERSION = (
    "qm.compile-ea-stale-build-binding-successor/v1"
)
RECHECK_SUCCESSOR_AUTHORITY = "compile_work_items:stale-build-binding-successor"
RECHECK_SUCCESSOR_FAILURE_REASON = "BUILD_TASK_BINDING_NOT_OPEN"

# One exact operator-ordering incident: QM5_41245's initial source-fresh
# COMPILE_EA row was released after its setfile header had already been bound
# to the source SHA. Candidate recheck correctly refused it before MetaEditor.
# The append-only successor contract below sanctions only that immutable row,
# source hash, evidence hash, EA identity, and failure reason. It does not
# waive compile/build checks, an EX5, any other work history, or a bound
# setfile on the successor.
QM5_41245_SETFILE_UNBIND_RETRY_CONTRACT_VERSION = (
    "qm.compile-ea-qm5-41245-setfile-unbind-retry/v1"
)
QM5_41245_SETFILE_UNBIND_RETRY_AUTHORITY = (
    "OWNER_COMMODITY_SLEEVE_2026-08-31_QM5_41245_COMPILE_RETRY"
)
QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID = (
    "072ded8e-84b9-4ada-b714-b333701e3d71"
)
QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL = (
    "QM5_41245_wti-mcusum-shift-tr"
)
QM5_41245_SETFILE_UNBIND_RETRY_SOURCE_SHA256 = (
    "e5fc833b3782f03af153ed9737a0f82c94ea508cf094af7c54b42b240c616258"
)
QM5_41245_SETFILE_UNBIND_RETRY_EVIDENCE_SHA256 = (
    "54c3640faea96b567e8722c5b30b90fc825ba15f1b754eea0bcf5b88253d0aba"
)
COMPILE_BINDING_RETRY_CONTRACT_VERSION = "qm.compile-ea-build-binding-retry/v1"
COMPILE_BINDING_FAILURE_CLASS = "BUILD_CHECK_FAILED"
QM5_41285_UNBOUND_COMPILE_RETRY_CONTRACT_VERSION = (
    "qm.compile-ea-unbound-build-task-retry/v1"
)
QM5_41285_UNBOUND_COMPILE_RETRY_AUTHORITY = (
    "OWNER_COMMODITY_SLEEVE_2026-09-02_QM5_41285_UNBOUND_COMPILE_RETRY"
)
QM5_41285_UNBOUND_COMPILE_RETRY_PREDECESSOR_ID = (
    "e313ef05-f345-477a-9a15-6eed458afb27"
)
QM5_41285_UNBOUND_COMPILE_RETRY_EA_LABEL = "QM5_41285_xauxag-mjt-rv"
QM5_41285_UNBOUND_COMPILE_RETRY_SOURCE_SHA256 = (
    "94954df95dc79b7bc2c653df9b4980428295af1a7f05566d58f8a03548519f43"
)
SOURCE_REPAIR_CONTRACT_VERSION = "qm.compile-ea-source-repair/v1"
REPAIR_SUCCESSOR_CONTRACT_VERSION = "qm.compile-ea-repair-successor/v1"
REPAIR_SUCCESSOR_AUTHORITY = "farmctl:repair-successor-of"
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
# Exact paced-fleet authority for the QM5_10850 EURUSD Q02 infrastructure
# recovery.  Its June binary embeds the pre-MNT-045 tester-news initializer,
# which can reject OnInit when the calendar CSVs are unavailable; the current
# framework preserves that condition as an auditable degraded run.  Binding
# the authority to the sealed failing Q02 predecessor permits one append-only,
# source-hash-bound compile successor and grants no backtest or gate authority.
QM5_10850_Q02_STALE_BINARY_REPAIR_AUTHORITY = (
    "q02_infra_predecessor:133f2023-7786-40ea-ba08-83ccd02a93bd"
)
QM5_10850_Q02_STALE_BINARY_REPAIR_EA_LABELS = frozenset({
    "QM5_10850_tv-bbmr-long",
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
# Exact paced-fleet authority for the QM5_10718 logical FX8 basket rebuild.
# Its existing binary predates the hard current-build MAE hook contract.  The
# sealed legacy Q02 predecessor proves the intended logical-basket identity,
# but carries no artifact hashes, so any repaired source must requalify at Q02.
# This authority accepts only the one MAE-hook source hash below and permits
# one append-only COMPILE_EA successor; it grants no backtest, gate-verdict,
# portfolio-admission, or live-use authority.
QM5_10718_MAE_BUILD_REPAIR_PREDECESSOR_ID = (
    "92ba2ca6-1147-4432-af19-929a45993f4a"
)
QM5_10718_MAE_BUILD_REPAIR_AUTHORITY = (
    "q02_pass_predecessor:92ba2ca6-1147-4432-af19-929a45993f4a"
)
QM5_10718_MAE_BUILD_REPAIR_EA_LABEL = (
    "QM5_10718_edgelab-regime-filtered-carry"
)
QM5_10718_MAE_BUILD_REPAIRED_SOURCE_SHA256 = (
    "92fa06a272aa4805e31c6caac4f1ad9feeaf91fec18c349a616bf2cae00f8f00"
)
# Exact paced-fleet authority for the QM5_10717 logical FX8 basket repair.
# The open logical Q02 row is still unclaimed, but its immutable artifact
# bindings predate the current hardening contract and point to a host-only
# order path that cannot execute the card's selected cross-symbol legs.  This
# authority accepts only the repaired source hash and that exact pending Q02
# binding, then permits one append-only COMPILE_EA successor.  It grants no
# backtest, gate-verdict, portfolio-admission, or live-use authority.
QM5_10717_BASKET_BUILD_REPAIR_PREDECESSOR_ID = (
    "7dd70134-a2a0-4ecf-a706-5f4609a094be"
)
QM5_10717_BASKET_BUILD_REPAIR_AUTHORITY = (
    "q02_pending_predecessor:7dd70134-a2a0-4ecf-a706-5f4609a094be"
)
QM5_10717_BASKET_BUILD_REPAIR_EA_LABEL = (
    "QM5_10717_edgelab-xsec-fx-momentum"
)
QM5_10717_BASKET_BUILD_REPAIRED_SOURCE_SHA256 = (
    "91819cbcac68dcc28d204d53b2b5aaeecbfdd6981c5c0e8678d3cf2de4c69596"
)
QM5_10717_BASKET_BUILD_PREDECESSOR_SOURCE_SHA256 = (
    "1fa4d2fdceaba1fb727ca5d8962964be400490a9546fcb77a8b8579d345e9f7e"
)
QM5_10717_BASKET_BUILD_PREDECESSOR_EX5_SHA256 = (
    "72c118b0a30fc32d0b6bcf921a632bfd8175048431b0547b87f249b841053f0a"
)
QM5_10717_BASKET_BUILD_PREDECESSOR_SETFILE_SHA256 = (
    "4d34f1a3ab50cee7154f979977428e8462b5a9d3ab0f84c41be3b453dc81087c"
)
# Exact append-only authority for the first governed QM5_10717 rebuild.  That
# immutable attempt proved the basket-order include was missing: MetaEditor
# reported COMPILE_ERRORS before a replacement EX5 existed.  The repair adds
# only the explicit shared helper include.  This binding accepts its one new
# source hash against the failed row and grants no backtest, gate-verdict,
# portfolio-admission, or live-use authority.
QM5_10717_BASKET_INCLUDE_REPAIR_PREDECESSOR_ID = (
    "eaa447b1-a990-49a5-83eb-274575b825ab"
)
QM5_10717_BASKET_INCLUDE_REPAIR_AUTHORITY = (
    "governed_compile_fail:eaa447b1-a990-49a5-83eb-274575b825ab"
)
QM5_10717_BASKET_INCLUDE_REPAIR_EA_LABEL = (
    "QM5_10717_edgelab-xsec-fx-momentum"
)
QM5_10717_BASKET_INCLUDE_REJECTED_SOURCE_SHA256 = (
    "91819cbcac68dcc28d204d53b2b5aaeecbfdd6981c5c0e8678d3cf2de4c69596"
)
QM5_10717_BASKET_INCLUDE_REPAIRED_SOURCE_SHA256 = (
    "0278b5ddef713e76617c4ae4bc9c97b21217e88578e36a1a09d5ebe10faef970"
)
QM5_10717_BASKET_INCLUDE_FAILURE_CLASSES = (
    "COMPILE_ERRORS",
    "BUILD_CHECK_COMPILE_FAILED",
)
# Exact paced-fleet authority for the instrumented QM5_10025 USDJPY Q02
# zero-trade recovery. The immutable predecessor proves a valid model-4 run,
# synchronized seven-symbol history, and zero trades while the old binary had
# no pair-selection/signal decision markers. This authority accepts only the
# default-off diagnostic source hash below, including the mechanical bounds
# proof required after COMPILE_EA b94b03b4-abee-4cfc-888f-2c48f4cd2960,
# and permits one append-only compile successor. It grants no economic-rule,
# backtest, gate-verdict, or live-use authority and self-expires on any further
# source edit.
QM5_10025_Q02_ZERO_TRADE_REPAIR_PREDECESSOR_ID = (
    "050dd2ea-e9d0-475f-b5ad-40c2206867ff"
)
QM5_10025_Q02_ZERO_TRADE_REPAIR_AUTHORITY = (
    "q02_zero_trade_predecessor:050dd2ea-e9d0-475f-b5ad-40c2206867ff"
)
QM5_10025_Q02_ZERO_TRADE_REPAIR_EA_LABEL = (
    "QM5_10025_rw-fx-broad-pairs"
)
QM5_10025_Q02_ZERO_TRADE_REPAIRED_SOURCE_SHA256 = (
    "db7424efcba0a8df90184240e277e1a7546e8030672eec88a4c72a89c32a5a61"
)
QM5_10025_Q02_ZERO_TRADE_REJECTED_SOURCE_SHA256 = (
    "fd0a18d8710dc8bd0d089ab34b9c881de65e971f0916ba540b34c53b2aa120ff"
)
QM5_10025_Q02_ZERO_TRADE_REJECTED_EX5_SHA256 = (
    "9bf2691d4af0a57d553711c37ffceadb513b303e710a25f455c8f2e211eecfcc"
)
QM5_10025_Q02_ZERO_TRADE_REJECTED_SETFILE_SHA256 = (
    "2d8a1ba1871c229d00b49458dcbd6dbd152d24c170d76404bace39cdea3be53c"
)
QM5_10025_Q02_ZERO_TRADE_EVIDENCE_SHA256 = (
    "37084386dd4a8c5e3011c8a86d9cd3c4201a5d5424bccadb29b90455393e0a09"
)
# Exact paced-fleet authority for the post-review QM5_38002 EURUSD Q02
# recovery.  Its existing binary predates the approved card-faithful source
# repair, while the only Q02 attempt ended in the farm taxonomy writer before
# a tester result existed.  This one router-task/label binding permits only an
# append-only, current-source-hash-bound COMPILE_EA successor; it grants no
# backtest, gate-verdict, or live authority.
QM5_38002_Q02_STALE_BINARY_REPAIR_AUTHORITY = (
    "router_ops_issue:29b52146-a3ec-4967-b2a7-8a834a444fe8"
)
QM5_38002_Q02_STALE_BINARY_REPAIR_EA_LABELS = frozenset({
    "QM5_38002_codetrading-macd-ema-trend-pullback",
})
# Exact blocked-build triage authority for QM5_38005.  The first governed
# compiler attempt wrote its candidate EX5/setfile side effects, then lost the
# receipt to SQLITE_BUSY; the retry correctly refused those unreceipted side
# effects.  Router task d8fb391d explicitly authorizes the smallest append-only
# recovery.  This one-task/one-label binding permits only a current-source
# COMPILE_EA successor and grants no backtest, gate-verdict, or live authority.
QM5_38005_BLOCKED_BUILD_RECOVERY_AUTHORITY = (
    "router_ops_issue:d8fb391d-b18b-4954-8620-c40297559f15"
)
QM5_38005_BLOCKED_BUILD_RECOVERY_EA_LABELS = frozenset({
    "QM5_38005_codetrading-ascending-triangle-breakout",
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
# Exact review-rework authority for QM5_36005. The accepted source repair is
# complete, but review task ddb87b6b rejected the package because its three
# presets declared a transient/non-committed source hash and no governed
# current-source binary existed. This one task/label binding permits only an
# append-only, source-hash-bound COMPILE_EA successor; it grants no backtest or
# gate-verdict authority and cannot authorize another EA.
QM5_36005_REVIEW_REPAIR_AUTHORITY = (
    "router_review_ea:ddb87b6b-a6db-4f8d-be8f-337341238a8c"
)
QM5_36005_REVIEW_REPAIR_EA_LABELS = frozenset({
    "QM5_36005_nnfx-coral-trendlord-woodies-harvester",
})
# Exact Q01 recycle authority for QM5_12929. Router task 7b431d7a was
# reviewer-recycled only for source annotations and SPEC completion; its
# repaired source was then committed and the task closed solely because the
# live factory/CPU ceiling refused compilation. The existing presets still
# carry historical build hashes while no EX5 exists. This one task/label
# binding permits only an append-only, current-source-hash-bound COMPILE_EA
# successor; it grants no backtest or gate-verdict authority.
QM5_12929_Q01_RECYCLE_REPAIR_AUTHORITY = (
    "router_build_ea:7b431d7a-a902-4947-a932-ffa8ef3a54d7"
)
QM5_12929_Q01_RECYCLE_REPAIR_EA_LABELS = frozenset({
    "QM5_12929_brooks-expanded-micro-channel-h1",
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
    "QM5_41229_wti-samecal-trimean5": (
        "router_review_ea:0c39bc3c-df80-41fd-9ec1-5b7be49129dd"
    ),
}
REVIEW_REWORK_SOURCE_REPAIR_EA_LABELS = frozenset(
    REVIEW_REWORK_SOURCE_REPAIR_AUTHORITIES
)
# Exact ops authority for the post-review QM5_38006 rework compile. The
# reviewed source contains the required drawdown and fail-closed history fixes,
# while its existing EX5 is bound to the pre-rework source. This one
# router-task/label binding permits only an append-only, source-hash-bound
# COMPILE_EA successor and grants no backtest or gate-verdict authority.
QM5_38006_REVIEW_REPAIR_AUTHORITY = (
    "router_ops_issue:81811459-7f67-4799-b906-a3448ec69652"
)
QM5_38006_REVIEW_REPAIR_EA_LABELS = frozenset({
    "QM5_38006_codetrading-doji-hammer-pivot-rejection",
})
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
# Exact Treasure Phase 2A authority for the fresh QM5_41272 recovery identity.
# Its first governed compile succeeded in MetaEditor but failed the current
# raw-series annotation and explicit MAE-hook checks.  This task/label binding
# permits one append-only, source-hash-bound repair compile and no backtest,
# gate-verdict, live, or cross-EA authority.
QM5_41272_TREASURE_BUILD_REPAIR_AUTHORITY = (
    "router_ops_issue:2e0bc944-0f47-47e2-b6c2-e7b83db89147"
)
QM5_41272_TREASURE_BUILD_REPAIR_EA_LABELS = frozenset({
    "QM5_41272_turn-of-month-index-long-restart-r1",
})
# OWNER-approved, append-only sibling-first-compile ceremony.  Unlike an
# ordinary source repair this authority permits the two named siblings to keep
# their immutable parent-era setfiles in ``sets/`` while compiling against one
# freshly generated setfile in the task-specific nested directory below.  The
# worker and build checker bind only that fresh file; no other task id or label
# can select the ceremony path.
DL089_SIBLING_REBIND_AUTHORITY = (
    "router_ops_issue:da2c006e-e5ab-4f85-845f-2925f90dd68d"
)
# Exact repair continuation after both ceremony compiles failed current Q01
# source-conformance checks. It retains the same two-label scope but uses a new
# task-specific unbound setfile directory, so the immutable first-attempt
# receipts and their now-bound ceremony setfiles remain append-only evidence.
DL089_SIBLING_REPAIR_AUTHORITY = (
    "router_ops_issue:e8ed1e85-a8db-4345-9785-2e0ccf1f6997"
)
DL089_SIBLING_Q02_REPAIR_AUTHORITY = (
    "router_ops_issue:6b66b181-2031-4f7f-ab4a-51e91f0dda3b"
)
DL089_SIBLING_REBIND_EA_LABELS = frozenset({
    "QM5_41195_aa-vol-sma10-opt",
    "QM5_41196_qs-kama-trend-xau-opt",
})
DL089_SIBLING_REBIND_CONTRACT_VERSION = "qm.dl089-sibling-rebind/v1"
DL089_SIBLING_REBIND_DIRECTORY = "sibling_rebind_da2c006e"
DL089_SIBLING_REPAIR_DIRECTORY = "sibling_rebind_e8ed1e85"
DL089_SIBLING_REPAIR_41196_RETRY_DIRECTORY = "sibling_rebind_e8ed1e85_r2"
DL089_SIBLING_Q02_REPAIR_DIRECTORY = "sibling_rebind_6b66b181_r2"
# Exact append-only first-build repair authority for the eight identities in
# OWNER-DEC-Q09HOLD-REQUAL-8-20260829.  Each initial compile can expose current
# mechanical Q01 checks that its faithful parent predates.  The repair compiles
# bind one fresh task-specific setfile and retain the failed row/setfile bytes.
Q09_REQUAL8_BUILD_REPAIR_AUTHORITY = (
    "router_ops_issue:1b57e398-3709-44b3-a53a-21e20fdb5d7b"
)
Q09_REQUAL8_BUILD_REPAIR_EA_LABELS = frozenset({
    "QM5_41215_pre-fomc-drift-ndx-requal8",
    "QM5_41216_grimes-nested-pb-v2-requal8",
    "QM5_41217_tv-post-vwap-requal8",
    "QM5_41218_demark-td-reverse-sequential-h4-requal8",
    "QM5_41219_cum-rsi2-commodity-requal8",
    "QM5_41220_grimes-context-pb-requal8",
    "QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8",
    "QM5_41222_lien-k-double-bb-trend-h1-requal8",
})
Q09_REQUAL8_BUILD_REPAIR_DIRECTORY = "requal8_repair_1b57e398"
Q09_REQUAL8_41215_RETRY_AUTHORITY = (
    "governed_compile_fail:b838f751-14e0-452a-b49f-8ba7b904bca4"
)
Q09_REQUAL8_41215_RETRY_DIRECTORY = "requal8_repair_1b57e398_r2"
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
# Exact paced-fleet authority for the stalled QM5_36002 multi-FX build.  Its
# current-source COMPILE_OK receipt survives, but the canonical EX5 bytes do
# not; the only open compile row is an older, superseded source identity.  This
# existing build-task/label binding permits only an append-only, current-source
# COMPILE_EA successor and grants no strategy, backtest, gate-verdict, or
# cross-EA authority.
QM5_36002_Q02_BINARY_RECOVERY_AUTHORITY = (
    "build_task:a48f0404-cbba-4611-9eaa-bbd9e4f82a75"
)
QM5_36002_Q02_BINARY_RECOVERY_EA_LABELS = frozenset({
    "QM5_36002_nnfx-kijunsen-absolute-strength-damiani",
})
# Exact paced-fleet authority for the QM5_41192 XTI/XNG diversity recovery.
# Its source, card, and fixed-risk basket setfiles still match the sealed Q02
# receipt, but the untracked compiled binary disappeared while the logical Q02
# row remained pending. This one router-task/label binding permits only an
# append-only, current-source COMPILE_EA successor; it grants no strategy,
# backtest, gate-verdict, or cross-EA authority.
QM5_41192_Q02_BINARY_RECOVERY_AUTHORITY = (
    "router_ops_issue:000bb713-5f0f-4e2e-b4bf-558fcbc86d7c"
)
QM5_41192_Q02_BINARY_RECOVERY_EA_LABELS = frozenset({
    "QM5_41192_xtixng-mdaily-hl-rv",
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
# Exact append-only authority for the failed QM5_1538 compile repaired under
# build task b8761494-8807-41d8-b4a0-f1d4141588c4.  The predecessor failed
# both MetaEditor compilation and the current raw-indicator/CopyBuffer
# framework contracts.  This binding accepts only the reviewed replacement
# source hash against that immutable failed row and grants no backtest or gate
# verdict authority.
QM5_1538_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "19918515-e8f4-460f-b9b8-136be81d5b13"
)
QM5_1538_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:19918515-e8f4-460f-b9b8-136be81d5b13"
)
QM5_1538_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_1538_aa-tsmom-1-3-12"
QM5_1538_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "9d3647ac1ec3aeec6f1f2a981f64bfee4a687239b9cc10f1b0b25312b63ef50e"
)
QM5_1538_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "78c02c2f7342cdf1b8af0e88ae05dadbd0e1c765ff9a801f9e89b5ef7054f7f7"
)
QM5_1538_COMPILE_FAIL_FAILURE_CLASSES = (
    "COMPILE_ERRORS",
    "BUILD_CHECK_COMPILE_FAILED",
    "EA_PERF_RAW_INDICATOR_CALL",
    "EA_FRAMEWORK_RAW_COPYBUFFER",
)
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
# Exact append-only authority for the first governed QM5_41223 compile. The
# predecessor compiled with 0 errors / 0 warnings but failed Q01 only because
# one fixed-capacity age-buffer write did not expose an explicit ArraySize
# guard to build_gate_hardening. The authority is bound below to that immutable
# failed row, its rejected source hash, and the reviewed guard-only repair. It
# grants no backtest, gate-verdict, or general EX5-overwrite authority.
QM5_41223_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "ebbd3a51-2660-43df-b669-bdf0adfb0275"
)
QM5_41223_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:ebbd3a51-2660-43df-b669-bdf0adfb0275"
)
QM5_41223_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_41223_wti-samecal-expw4"
QM5_41223_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "010a74f922d6796b522c655733c7d98b50f840d7abab4a5c6b3ef6866f051fd3"
)
QM5_41223_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "b3b25a8179ffc8f2f35562d3494e529cff530758625fd951acb752ee88131081"
)
# Exact append-only authority for the first governed QM5_41246 compile. The
# predecessor compiled with zero errors and warnings but failed Q01 because
# the static bounds gate could not prove two dynamic ratio-buffer accesses.
# The reviewed repair uses fixed 13-element arrays and also seals the card's
# historical entry-direction reconstruction on restart. This binding accepts
# only that repaired source hash against the immutable failed row and grants
# no backtest, gate-verdict, or general binary-overwrite authority.
QM5_41246_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "d5dfceea-71f3-4ee2-8ab4-9ec4742dbbd8"
)
QM5_41246_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:d5dfceea-71f3-4ee2-8ab4-9ec4742dbbd8"
)
QM5_41246_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_41246_xauxag-mturnpoint-rv"
QM5_41246_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "65bb2c490a5f18213b03a5824db13dd1272f2af1bdd7a85491c5b28ecb69e4e1"
)
QM5_41246_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "f44971a52ef6ae725b80515c7a4c1cbf88d06b51c07c229d2ef9deedfbf1a85a"
)
# Exact append-only authority for the first governed QM5_41251 compile. The
# predecessor compiled with zero errors and warnings but failed Q01 because
# the static bounds gate could not infer the fixed ten-element old-sample
# buffer bound. The repair replaces all four formula buffers with card-fixed
# dimensions and adds literal local bounds. This binding accepts only that
# repaired source hash against the immutable failed row and grants no
# backtest, gate-verdict, or general binary-overwrite authority.
QM5_41251_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "0c0de557-39a6-4460-9b8d-a185af0a21a7"
)
QM5_41251_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:0c0de557-39a6-4460-9b8d-a185af0a21a7"
)
QM5_41251_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_41251_wti-mbrunner-shift-tr"
QM5_41251_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "0a35575ec1e02a1c6542a5cddc32262bbbeac00d8d9ab73bb5ff8ca7eee79d00"
)
QM5_41251_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "8d6f05a4eec46c178a4c48dd1c85d48fa3293088601f542dc62c3d2e25b6f888"
)
# Exact append-only authority for the first governed QM5_41253 compile. The
# predecessor compiled with zero errors and warnings but failed Q01 because
# four dynamic weekend-gap buffer accesses did not expose resize-count bounds
# that build_gate_hardening could prove. The repair adds only local bounds
# proofs; it does not change the approved signal or lifecycle. This binding
# accepts only that repaired source hash against the immutable failed row and
# grants no backtest, gate-verdict, or general binary-overwrite authority.
QM5_41253_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "96bc9e68-3359-40d3-b52c-fd1ae1663ac2"
)
QM5_41253_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:96bc9e68-3359-40d3-b52c-fd1ae1663ac2"
)
QM5_41253_COMPILE_FAIL_REPAIR_EA_LABEL = (
    "QM5_41253_gbpusd-weekend-tail-fade"
)
QM5_41253_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "8be932f2b351e506247acbd2610701889d2a778b04e773845fd40836725d81a8"
)
QM5_41253_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "b25cef9ce1a45c9f130f059cf9f657f6f1193ab97215809ce6f4924a22034f93"
)
# Exact append-only authority for the first governed QM5_41264 compile. The
# predecessor compiled with zero errors and warnings but failed Q01 because
# three card-fixed Yuen working-buffer accesses did not expose local ArraySize
# proofs to build_gate_hardening. The repair adds only those bounds proofs and
# matching reference assertions. This binding accepts only that repaired
# source hash against the immutable failed row and grants no backtest,
# gate-verdict, or general binary-overwrite authority.
QM5_41264_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "cb8bbc1b-770a-46fb-a9d7-a1e28c7d2bc7"
)
QM5_41264_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:cb8bbc1b-770a-46fb-a9d7-a1e28c7d2bc7"
)
QM5_41264_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_41264_wti-myuen20-shift-tr"
QM5_41264_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "3f211d8b4fd63c833c61fdbbca4417d14272d5c27d5df99e13b93fcfd1fb5fd2"
)
QM5_41264_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "e6df55738c6e4639738e46f2c4a21a9c9014133f81f00ea958b1fd519553e35b"
)
# Exact append-only authority for the second governed QM5_41264 compile. The
# predecessor again compiled with zero errors and warnings, then D10 rejected
# the Winsor source read because a preceding guard contained another
# ArraySize expression. The repair only splits the two existing bounds checks
# so each dynamic array access has its own mechanically local proof.
QM5_41264_COMPILE_FAIL_REPAIR_2_PREDECESSOR_ID = (
    "7d9e3da3-78b4-4a59-b5bc-a52a7fc2bdb7"
)
QM5_41264_COMPILE_FAIL_REPAIR_2_AUTHORITY = (
    "governed_compile_fail:7d9e3da3-78b4-4a59-b5bc-a52a7fc2bdb7"
)
QM5_41264_COMPILE_FAIL_REPAIR_2_REJECTED_SOURCE_SHA256 = (
    "e6df55738c6e4639738e46f2c4a21a9c9014133f81f00ea958b1fd519553e35b"
)
QM5_41264_COMPILE_FAIL_REPAIR_2_REPAIRED_SOURCE_SHA256 = (
    "8977bed13f550482cf7be8c14b05605623a3c796ab16399908f9c85dc2b31e07"
)
# Exact append-only authority for the first governed QM5_41274 compile. The
# predecessor compiled with zero errors and warnings but failed Q01 because
# two already-bounded completed-month buffer reads did not expose resize-count
# proofs that build_gate_hardening could prove. The repair adds only explicit
# local bounds; it does not alter the approved signal or lifecycle. This
# binding accepts only that repaired source hash against the immutable failed
# row and grants no backtest, gate-verdict, or general binary-overwrite
# authority.
QM5_41274_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "8fa48f19-98dc-47f5-adba-9c712998b7ce"
)
QM5_41274_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:8fa48f19-98dc-47f5-adba-9c712998b7ce"
)
QM5_41274_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_41274_wti-m3block-rank-tr"
QM5_41274_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "1d7541951d1c3ad7223f3d1b42e5fec53d77fa5bf21d20e721285dad4cfb031f"
)
QM5_41274_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "01357e78417024d0719350511a8549c42d42a0fde315571158777e5291f1efd4"
)
# Exact append-only authority for the first governed QM5_41228 compile. The
# predecessor compiled with zero errors and warnings but failed Q01 only
# because two already-bounded shortest-half buffer accesses lacked the local
# ArraySize proof required by build_gate_hardening. This binding permits only
# the reviewed guard-only source hash against that immutable failed row; it
# grants no backtest, gate-verdict, or general binary-overwrite authority.
QM5_41228_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "80f56663-abe7-4ebf-8da9-b37a7ced0a94"
)
QM5_41228_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:80f56663-abe7-4ebf-8da9-b37a7ced0a94"
)
QM5_41228_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_41228_wti-samecal-shorth5"
QM5_41228_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "b25bab960cb6d8aef751b7e25a981fc83a59a20ce6b3ab1e552608eb2d12d978"
)
QM5_41228_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "5cd3fd3501ce3255f4f047a590b46be34f052a4f16dba145bf172276566540fa"
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
# Exact append-only authority for the first governed QM5_41185 compile. The
# predecessor compiled with 0 errors / 0 warnings but failed Q01 only because
# the conservative no-ML scanner matched the generic local name ``weights``
# used for formula-locked fractional-difference coefficients. This binding
# authorizes only the reviewed identifier-only repair against that immutable
# failed row; it grants no backtest, gate-verdict, or general EX5-overwrite
# authority.
QM5_41185_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = (
    "527e07ee-51ee-404d-acdc-76a01bbd4f51"
)
QM5_41185_COMPILE_FAIL_REPAIR_AUTHORITY = (
    "governed_compile_fail:527e07ee-51ee-404d-acdc-76a01bbd4f51"
)
QM5_41185_COMPILE_FAIL_REPAIR_EA_LABEL = "QM5_41185_xauxag-fracd-rv"
QM5_41185_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = (
    "f72bafe2028ca8020e4837b4f12719fcc84f64379007827ffa1217197129e605"
)
QM5_41185_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = (
    "371a4e20dfaf6aefb1e9b5e976b5087f28d528538d60e972b176df1847f65eab"
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


def _sibling_rebind_authorized(label: str, authority: str | None) -> bool:
    return bool(
        (
            authority in {
                DL089_SIBLING_REBIND_AUTHORITY,
                DL089_SIBLING_REPAIR_AUTHORITY,
            }
            and label in DL089_SIBLING_REBIND_EA_LABELS
        )
        or (
            authority == DL089_SIBLING_Q02_REPAIR_AUTHORITY
            and label == "QM5_41195_aa-vol-sma10-opt"
        )
        or (
            authority == Q09_REQUAL8_BUILD_REPAIR_AUTHORITY
            and label in Q09_REQUAL8_BUILD_REPAIR_EA_LABELS
        )
        or (
            authority == Q09_REQUAL8_41215_RETRY_AUTHORITY
            and label == "QM5_41215_pre-fomc-drift-ndx-requal8"
        )
    )


def _sibling_rebind_directory(
    authority: str | None, label: str
) -> str | None:
    if authority == DL089_SIBLING_REBIND_AUTHORITY:
        return DL089_SIBLING_REBIND_DIRECTORY
    if authority == DL089_SIBLING_REPAIR_AUTHORITY:
        if label == "QM5_41196_qs-kama-trend-xau-opt":
            return DL089_SIBLING_REPAIR_41196_RETRY_DIRECTORY
        return DL089_SIBLING_REPAIR_DIRECTORY
    if authority == DL089_SIBLING_Q02_REPAIR_AUTHORITY:
        return DL089_SIBLING_Q02_REPAIR_DIRECTORY
    if authority == Q09_REQUAL8_BUILD_REPAIR_AUTHORITY:
        return Q09_REQUAL8_BUILD_REPAIR_DIRECTORY
    if authority == Q09_REQUAL8_41215_RETRY_AUTHORITY:
        return Q09_REQUAL8_41215_RETRY_DIRECTORY
    return None


def _sibling_rebind_setfile_path(
    ea_dir: Path,
    label: str,
    symbol: str,
    timeframe: str,
    authority: str | None,
) -> Path:
    directory = _sibling_rebind_directory(authority, label)
    if directory is None:
        raise ValueError("SIBLING_REBIND_AUTHORITY_INVALID")
    return (
        ea_dir
        / "sets"
        / directory
        / f"{label}_{symbol}_{timeframe}_backtest.set"
    )


def _sibling_rebind_setfile_check(
    path: Path, authority: str | None = None
) -> tuple[bool, list[str]]:
    """Validate the pre-compile sibling set without changing its bytes."""

    findings: list[str] = []
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError:
        return False, ["SIBLING_REBIND_CURRENT_SETFILE_MISSING"]
    build_match = re.search(
        r"(?im)^\s*;\s*build_hash\s*:\s*(\S+)\s*$", text
    )
    if not build_match or build_match.group(1).lower() != "pending":
        findings.append("SIBLING_REBIND_CURRENT_SETFILE_NOT_UNBOUND")
    assignments: dict[str, str] = {}
    for match in re.finditer(
        r"(?m)^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^\r\n]*)$", text
    ):
        assignments[match.group(1)] = match.group(2).strip()
    if assignments.get("RISK_FIXED") not in {"1000", "1000.0"}:
        findings.append("SIBLING_REBIND_RISK_FIXED_INVALID")
    if assignments.get("RISK_PERCENT") not in {"0", "0.0"}:
        findings.append("SIBLING_REBIND_RISK_PERCENT_INVALID")
    if authority not in {
        Q09_REQUAL8_BUILD_REPAIR_AUTHORITY,
        Q09_REQUAL8_41215_RETRY_AUTHORITY,
    }:
        for name in (
            "opt_pp_buy1", "opt_pp_buy2", "opt_pp_buy3",
            "opt_pp_sell1", "opt_pp_sell2", "opt_pp_sell3",
        ):
            if assignments.get(name) != "0":
                findings.append(f"SIBLING_REBIND_NEUTRAL_INPUT_INVALID:{name}")
    return not findings, findings

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

# Pre-0803 news-provenance recompile wave (OWNER decision 2026-09-03,
# OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903). Every .ex5 compiled
# before commit f0102fbcf (2026-08-03, QM_NewsFilter.mqh provenance inputs
# qm_news_calendar_bundle_id / _expected_sha256 / _common_relative_path) fails
# every Q10_NEWS cell with an effective-input bundle-id mismatch, so these EAs
# can never close a chain without a rebuild. The rebuilt EX5 is a NEW identity
# from Q02 (23.08. identity rule); the old rows stay as append-only evidence.
# Batch 1 = 11910 / 10700 / 12710, batch 2 = 10815 / 12580 - one list, the
# execution order is the CEO's. This is NOT a general .ex5-overwrite path.
PRE0803_NEWS_PROVENANCE_FORCE_REBUILD_OWNER_REFERENCE = (
    "OWNER_DECISION_2026-09-03_PRE0803_NEWS_PROVENANCE_RECOMPILE"
)
PRE0803_NEWS_PROVENANCE_DECISION_DOC = (
    "docs/ops/evidence/"
    "2026-09-03_owner_dec_pre0803_recompile_slot_order_amendment_b.md"
)
PRE0803_FORCE_REBUILD_EA_IDS = frozenset({
    "QM5_11910", "QM5_10700", "QM5_12710",  # batch 1
    "QM5_10815", "QM5_12580",               # batch 2
})
PRE0803_FORCE_REBUILD_NUMERIC_EA_IDS = frozenset(
    value.split("_", 1)[1] if value.upper().startswith("QM5_") else value
    for value in PRE0803_FORCE_REBUILD_EA_IDS
)


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


def pre0803_force_rebuild_allowlist(repo_root: Path) -> frozenset[str]:
    """Return the numeric EA ids authorized by the 2026-09-03 pre-0803 wave.

    Fail-closed in the same shape as dl089_force_rebuild_allowlist: an id only
    clears the bypass when the hardcoded PRE0803_FORCE_REBUILD_EA_IDS name AND
    the OWNER decision document in this checkout agree. The document must carry
    the exact owner reference and name the EA, so a checkout without the
    decision (or an OWNER revocation that removes/rewrites it) turns the bypass
    back off without a code change.
    """
    try:
        text = (repo_root / PRE0803_NEWS_PROVENANCE_DECISION_DOC).read_text(
            encoding="utf-8-sig"
        )
    except OSError:
        return frozenset()
    if PRE0803_NEWS_PROVENANCE_FORCE_REBUILD_OWNER_REFERENCE not in text:
        return frozenset()
    authorized: set[str] = set()
    for numeric_ea_id in PRE0803_FORCE_REBUILD_NUMERIC_EA_IDS:
        if not numeric_ea_id.isdigit():
            continue
        if re.search(rf"QM5_{numeric_ea_id}(?![0-9])", text):
            authorized.add(numeric_ea_id)
    return frozenset(authorized)


def force_rebuild_allowlist(root: Path, repo_root: Path) -> frozenset[str]:
    return (
        dl089_force_rebuild_allowlist(repo_root)
        | mae_hook_force_rebuild_allowlist(root)
        | pre0803_force_rebuild_allowlist(repo_root)
    )


def force_rebuild_owner_reference(ea_id: str) -> str:
    if ea_id in MAE_HOOK_FORCE_REBUILD_EA_IDS:
        return MAE_HOOK_FORCE_REBUILD_OWNER_REFERENCE
    if ea_id in PRE0803_FORCE_REBUILD_NUMERIC_EA_IDS:
        return PRE0803_NEWS_PROVENANCE_FORCE_REBUILD_OWNER_REFERENCE
    return DL089_FORCE_REBUILD_OWNER_REFERENCE


def force_rebuild_evidence_note(ea_id: str) -> str | None:
    """Repo-relative decision document backing a document-bound rebuild wave.

    Returns None for the DL-089 and MAE-hook waves so their compile payloads
    stay byte-identical to what they were before the pre-0803 wave existed.
    """
    if ea_id in PRE0803_FORCE_REBUILD_NUMERIC_EA_IDS:
        return PRE0803_NEWS_PROVENANCE_DECISION_DOC
    return None


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


def _qm5_1538_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_1538 framework repair to one failed row/source delta."""
    if (
        authority != QM5_1538_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_1538_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "1538"
        or str(source_sha or "").lower()
        != QM5_1538_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_1538_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
        ),
        None,
    )
    if predecessor is None:
        return False
    payload = _json_object(predecessor.get("payload_json"))
    compile_result = payload.get("compile_result")
    expected_failures = list(QM5_1538_COMPILE_FAIL_FAILURE_CLASSES)
    return bool(
        predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "failed"
        and predecessor.get("verdict") == "COMPILE_FAIL"
        and payload.get("ea_label") == ea_label
        and str(payload.get("mq5_sha256") or "").lower()
        == QM5_1538_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == ";".join(expected_failures)
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "FAIL"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes") == expected_failures
    )


def _qm5_41223_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41223 guard repair to one failed row and source delta."""
    if (
        authority != QM5_41223_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41223_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41223"
        or str(source_sha or "").lower()
        != QM5_41223_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41223_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
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
        == QM5_41223_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "EA_INDICATOR_BUFFER_UNBOUNDED"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes")
        == ["EA_INDICATOR_BUFFER_UNBOUNDED"]
    )


def _qm5_41246_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41246 bounds/direction repair to one failed compile."""
    if (
        authority != QM5_41246_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41246_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41246"
        or str(source_sha or "").lower()
        != QM5_41246_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41246_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
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
        == QM5_41246_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "EA_INDICATOR_BUFFER_UNBOUNDED"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes")
        == ["EA_INDICATOR_BUFFER_UNBOUNDED"]
    )


def _qm5_41251_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41251 static-buffer repair to one failed compile."""
    if (
        authority != QM5_41251_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41251_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41251"
        or str(source_sha or "").lower()
        != QM5_41251_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41251_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
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
        == QM5_41251_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "EA_INDICATOR_BUFFER_UNBOUNDED"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes")
        == ["EA_INDICATOR_BUFFER_UNBOUNDED"]
    )


def _qm5_41253_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41253 bounds-proof repair to one failed compile."""
    if (
        authority != QM5_41253_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41253_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41253"
        or str(source_sha or "").lower()
        != QM5_41253_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41253_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
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
        == QM5_41253_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "EA_INDICATOR_BUFFER_UNBOUNDED"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes")
        == ["EA_INDICATOR_BUFFER_UNBOUNDED"]
    )


def _qm5_41264_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41264 bounds-proof repair to one failed compile."""
    if (
        authority != QM5_41264_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41264_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41264"
        or str(source_sha or "").lower()
        != QM5_41264_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41264_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
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
        == QM5_41264_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "EA_INDICATOR_BUFFER_UNBOUNDED"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes")
        == ["EA_INDICATOR_BUFFER_UNBOUNDED"]
    )


def _qm5_41264_compile_fail_repair_2_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the second QM5_41264 bounds-proof repair to one failed compile."""
    if (
        authority != QM5_41264_COMPILE_FAIL_REPAIR_2_AUTHORITY
        or ea_label != QM5_41264_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41264"
        or str(source_sha or "").lower()
        != QM5_41264_COMPILE_FAIL_REPAIR_2_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41264_COMPILE_FAIL_REPAIR_2_PREDECESSOR_ID
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
        == QM5_41264_COMPILE_FAIL_REPAIR_2_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "EA_INDICATOR_BUFFER_UNBOUNDED"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes")
        == ["EA_INDICATOR_BUFFER_UNBOUNDED"]
    )


def _qm5_41274_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41274 bounds-proof repair to one failed compile."""
    if (
        authority != QM5_41274_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41274_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41274"
        or str(source_sha or "").lower()
        != QM5_41274_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41274_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
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
        == QM5_41274_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "EA_INDICATOR_BUFFER_UNBOUNDED"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes")
        == ["EA_INDICATOR_BUFFER_UNBOUNDED"]
    )


def _qm5_41228_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41228 bounds repair to one failed row and source delta."""
    if (
        authority != QM5_41228_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41228_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41228"
        or str(source_sha or "").lower()
        != QM5_41228_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41228_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
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
        == QM5_41228_COMPILE_FAIL_REJECTED_SOURCE_SHA256
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


def _qm5_41185_compile_fail_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the QM5_41185 identifier repair to one failed row/source delta."""
    if (
        authority != QM5_41185_COMPILE_FAIL_REPAIR_AUTHORITY
        or ea_label != QM5_41185_COMPILE_FAIL_REPAIR_EA_LABEL
        or ea_id != "41185"
        or str(source_sha or "").lower()
        != QM5_41185_COMPILE_FAIL_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_41185_COMPILE_FAIL_REPAIR_PREDECESSOR_ID
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
        == QM5_41185_COMPILE_FAIL_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == "EA_ML_FORBIDDEN"
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "PASS"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes") == ["EA_ML_FORBIDDEN"]
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
    if authority == QM5_10717_BASKET_INCLUDE_REPAIR_AUTHORITY:
        return _qm5_10717_basket_include_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_10717_BASKET_BUILD_REPAIR_AUTHORITY:
        return _qm5_10717_basket_build_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
            current_work_item_id=current_work_item_id,
        )
    if authority == QM5_10718_MAE_BUILD_REPAIR_AUTHORITY:
        return _qm5_10718_mae_build_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
            current_work_item_id=current_work_item_id,
        )
    if authority == QM5_10025_Q02_ZERO_TRADE_REPAIR_AUTHORITY:
        return _qm5_10025_q02_zero_trade_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
            current_work_item_id=current_work_item_id,
        )
    if authority == QM5_1538_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_1538_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41201_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41201_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41223_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41223_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41246_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41246_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41251_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41251_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41253_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41253_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41264_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41264_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41264_COMPILE_FAIL_REPAIR_2_AUTHORITY:
        return _qm5_41264_compile_fail_repair_2_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41274_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41274_compile_fail_repair_authorized(
            ea_label,
            authority,
            ea_id=ea_id,
            source_sha=source_sha,
            inventory=inventory,
        )
    if authority == QM5_41228_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41228_compile_fail_repair_authorized(
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
    if authority == QM5_41185_COMPILE_FAIL_REPAIR_AUTHORITY:
        return _qm5_41185_compile_fail_repair_authorized(
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
            authority == QM5_10850_Q02_STALE_BINARY_REPAIR_AUTHORITY
            and ea_label in QM5_10850_Q02_STALE_BINARY_REPAIR_EA_LABELS
        )
        or (
            authority == QM5_1252_Q02_INFRA_REPAIR_AUTHORITY
            and ea_label in QM5_1252_Q02_INFRA_REPAIR_EA_LABELS
        )
        or (
            authority == QM5_38002_Q02_STALE_BINARY_REPAIR_AUTHORITY
            and ea_label in QM5_38002_Q02_STALE_BINARY_REPAIR_EA_LABELS
        )
        or (
            authority == QM5_38005_BLOCKED_BUILD_RECOVERY_AUTHORITY
            and ea_label in QM5_38005_BLOCKED_BUILD_RECOVERY_EA_LABELS
        )
        or (
            authority == QM5_35005_REVIEW_REPAIR_AUTHORITY
            and ea_label in QM5_35005_REVIEW_REPAIR_EA_LABELS
        )
        or (
            authority == QM5_36005_REVIEW_REPAIR_AUTHORITY
            and ea_label in QM5_36005_REVIEW_REPAIR_EA_LABELS
        )
        or (
            authority == QM5_12929_Q01_RECYCLE_REPAIR_AUTHORITY
            and ea_label in QM5_12929_Q01_RECYCLE_REPAIR_EA_LABELS
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
            authority == QM5_38006_REVIEW_REPAIR_AUTHORITY
            and ea_label in QM5_38006_REVIEW_REPAIR_EA_LABELS
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
            authority == QM5_41272_TREASURE_BUILD_REPAIR_AUTHORITY
            and ea_label in QM5_41272_TREASURE_BUILD_REPAIR_EA_LABELS
        )
        or _sibling_rebind_authorized(ea_label, authority)
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
            authority == QM5_36002_Q02_BINARY_RECOVERY_AUTHORITY
            and ea_label in QM5_36002_Q02_BINARY_RECOVERY_EA_LABELS
        )
        or (
            authority == QM5_41192_Q02_BINARY_RECOVERY_AUTHORITY
            and ea_label in QM5_41192_Q02_BINARY_RECOVERY_EA_LABELS
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
            and row.get("status") == "pending"
            and row.get("claimed_by") is None
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


def _qm5_10718_mae_build_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
    current_work_item_id: str | None,
) -> bool:
    """Bind one current-build compile to the sealed logical FX8 Q02 row."""
    if (
        authority != QM5_10718_MAE_BUILD_REPAIR_AUTHORITY
        or ea_label != QM5_10718_MAE_BUILD_REPAIR_EA_LABEL
        or ea_id != "10718"
        or str(source_sha or "").lower()
        != QM5_10718_MAE_BUILD_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_10718_MAE_BUILD_REPAIR_PREDECESSOR_ID
        ),
        None,
    )
    if predecessor is None:
        return False
    payload = _json_object(predecessor.get("payload_json"))
    if not (
        predecessor.get("phase") == "Q02"
        and predecessor.get("status") == "done"
        and predecessor.get("verdict") == "PASS"
        and payload.get("logical_symbol") == "QM5_10718_FX8_BASKET_D1"
        and payload.get("portfolio_scope") == "basket"
        and payload.get("host_symbol") == "EURUSD.DWX"
        and payload.get("host_timeframe") == "D1"
        and payload.get("basket_symbol_count") == 28
        and payload.get("ea_dir_name")
        == "QM5_10718_edgelab-regime-filtered-carry"
        and str(payload.get("basket_manifest") or "").replace("\\", "/").endswith(
            "/QM5_10718_edgelab-regime-filtered-carry/basket_manifest.json"
        )
    ):
        return False
    if current_work_item_id is None:
        return True
    current_row = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id")) == str(current_work_item_id)
        ),
        None,
    )
    current_payload = _json_object(
        current_row.get("payload_json") if current_row else None
    )
    return bool(
        current_row
        and current_row.get("phase") == COMPILE_EA_PHASE
        and current_payload.get("append_only_source_repair") is True
        and current_payload.get("compile_source_repair_authority") == authority
        and str(current_payload.get("mq5_sha256") or "").lower()
        == QM5_10718_MAE_BUILD_REPAIRED_SOURCE_SHA256
        and QM5_10718_MAE_BUILD_REPAIR_PREDECESSOR_ID
        in current_payload.get("source_repair_predecessor_work_item_ids", [])
    )


def _qm5_10717_basket_build_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
    current_work_item_id: str | None,
) -> bool:
    """Bind one current-build compile to the exact unclaimed logical Q02 row."""
    if (
        authority != QM5_10717_BASKET_BUILD_REPAIR_AUTHORITY
        or ea_label != QM5_10717_BASKET_BUILD_REPAIR_EA_LABEL
        or ea_id != "10717"
        or str(source_sha or "").lower()
        != QM5_10717_BASKET_BUILD_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_10717_BASKET_BUILD_REPAIR_PREDECESSOR_ID
        ),
        None,
    )
    if predecessor is None:
        return False
    payload = _json_object(predecessor.get("payload_json"))
    basket_symbols = payload.get("basket_symbols")
    if not (
        predecessor.get("phase") == "Q02"
        and predecessor.get("status") == "pending"
        and predecessor.get("verdict") is None
        and str(predecessor.get("mq5_sha256") or "").lower()
        == QM5_10717_BASKET_BUILD_PREDECESSOR_SOURCE_SHA256
        and str(predecessor.get("ex5_sha256") or "").lower()
        == QM5_10717_BASKET_BUILD_PREDECESSOR_EX5_SHA256
        and payload.get("logical_symbol") == "FX8_BASKET_D1"
        and payload.get("host_symbol") == "EURUSD.DWX"
        and payload.get("host_timeframe") == "D1"
        and payload.get("expected_period") == "D1"
        and isinstance(basket_symbols, list)
        and len(basket_symbols) == 28
        and payload.get("priority_track") is True
        and payload.get("risk_fixed") == 1000.0
        and payload.get("risk_percent") == 0.0
        and str(payload.get("expected_mq5_sha256") or "").lower()
        == QM5_10717_BASKET_BUILD_PREDECESSOR_SOURCE_SHA256
        and str(payload.get("expected_ex5_sha256") or "").lower()
        == QM5_10717_BASKET_BUILD_PREDECESSOR_EX5_SHA256
        and str(payload.get("expected_setfile_sha256") or "").lower()
        == QM5_10717_BASKET_BUILD_PREDECESSOR_SETFILE_SHA256
        and str(payload.get("basket_manifest") or "").replace("\\", "/").endswith(
            "/QM5_10717_edgelab-xsec-fx-momentum/basket_manifest.json"
        )
    ):
        return False
    if current_work_item_id is None:
        return True
    current_row = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id")) == str(current_work_item_id)
        ),
        None,
    )
    current_payload = _json_object(
        current_row.get("payload_json") if current_row else None
    )
    return bool(
        current_row
        and current_row.get("phase") == COMPILE_EA_PHASE
        and current_payload.get("append_only_source_repair") is True
        and current_payload.get("compile_source_repair_authority") == authority
        and str(current_payload.get("mq5_sha256") or "").lower()
        == QM5_10717_BASKET_BUILD_REPAIRED_SOURCE_SHA256
        and QM5_10717_BASKET_BUILD_REPAIR_PREDECESSOR_ID
        in current_payload.get("source_repair_predecessor_work_item_ids", [])
    )


def _qm5_10717_basket_include_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
) -> bool:
    """Bind the missing basket-include repair to its governed compile failure."""
    if (
        authority != QM5_10717_BASKET_INCLUDE_REPAIR_AUTHORITY
        or ea_label != QM5_10717_BASKET_INCLUDE_REPAIR_EA_LABEL
        or ea_id != "10717"
        or str(source_sha or "").lower()
        != QM5_10717_BASKET_INCLUDE_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_10717_BASKET_INCLUDE_REPAIR_PREDECESSOR_ID
        ),
        None,
    )
    if predecessor is None:
        return False
    payload = _json_object(predecessor.get("payload_json"))
    compile_result = payload.get("compile_result")
    expected_failures = list(QM5_10717_BASKET_INCLUDE_FAILURE_CLASSES)
    return bool(
        predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "failed"
        and predecessor.get("verdict") == "COMPILE_FAIL"
        and payload.get("ea_label") == ea_label
        and str(payload.get("mq5_sha256") or "").lower()
        == QM5_10717_BASKET_INCLUDE_REJECTED_SOURCE_SHA256
        and payload.get("verdict_reason") == ";".join(expected_failures)
        and payload.get("compile_source_repair_authority")
        == QM5_10717_BASKET_BUILD_REPAIR_AUTHORITY
        and QM5_10717_BASKET_BUILD_REPAIR_PREDECESSOR_ID
        in payload.get("source_repair_predecessor_work_item_ids", [])
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") == "FAIL"
        and compile_result.get("build_check_result") == "FAIL"
        and compile_result.get("failure_classes") == expected_failures
        and compile_result.get("setfile_count") == 29
        and compile_result.get("success") is False
        and compile_result.get("ex5_sha256") is None
    )


def _qm5_10025_q02_zero_trade_repair_authorized(
    ea_label: str,
    authority: str | None,
    *,
    ea_id: str | None,
    source_sha: str | None,
    inventory: dict[str, Any] | None,
    current_work_item_id: str | None,
) -> bool:
    """Bind one diagnostic compile to the exact valid USDJPY zero-trade run."""
    if (
        authority != QM5_10025_Q02_ZERO_TRADE_REPAIR_AUTHORITY
        or ea_label != QM5_10025_Q02_ZERO_TRADE_REPAIR_EA_LABEL
        or ea_id != "10025"
        or str(source_sha or "").lower()
        != QM5_10025_Q02_ZERO_TRADE_REPAIRED_SOURCE_SHA256
        or inventory is None
    ):
        return False
    predecessor = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id"))
            == QM5_10025_Q02_ZERO_TRADE_REPAIR_PREDECESSOR_ID
        ),
        None,
    )
    if predecessor is None:
        return False
    payload = _json_object(predecessor.get("payload_json"))
    evidence_path = Path(str(predecessor.get("evidence_path") or ""))
    try:
        evidence_valid = (
            evidence_path.is_file()
            and sha256_file(evidence_path).lower()
            == QM5_10025_Q02_ZERO_TRADE_EVIDENCE_SHA256
        )
    except OSError:
        evidence_valid = False
    if not (
        predecessor.get("phase") == "Q02"
        and predecessor.get("status") == "done"
        and predecessor.get("verdict") == "ZERO_TRADES"
        and payload.get("verdict_reason") == "Q02_ZERO_TRADES"
        and payload.get("priority_reason")
        == "board_advisor_fx_existing_market_neutral_q02_after_exhausted_66_pair_frontier"
        and payload.get("expected_symbol") == "USDJPY.DWX"
        and payload.get("expected_period") == "H4"
        and str(payload.get("expected_mq5_sha256") or "").lower()
        == QM5_10025_Q02_ZERO_TRADE_REJECTED_SOURCE_SHA256
        and str(payload.get("expected_ex5_sha256") or "").lower()
        == QM5_10025_Q02_ZERO_TRADE_REJECTED_EX5_SHA256
        and str(payload.get("expected_setfile_sha256") or "").lower()
        == QM5_10025_Q02_ZERO_TRADE_REJECTED_SETFILE_SHA256
        and evidence_valid
    ):
        return False
    if current_work_item_id is None:
        return True
    current_row = next(
        (
            row
            for row in inventory.get("work_rows", {}).get(ea_id, [])
            if str(row.get("id")) == str(current_work_item_id)
        ),
        None,
    )
    current_payload = _json_object(
        current_row.get("payload_json") if current_row else None
    )
    return bool(
        current_row
        and current_row.get("phase") == COMPILE_EA_PHASE
        and current_payload.get("append_only_source_repair") is True
        and current_payload.get("compile_source_repair_authority") == authority
        and str(current_payload.get("mq5_sha256") or "").lower()
        == QM5_10025_Q02_ZERO_TRADE_REPAIRED_SOURCE_SHA256
        and QM5_10025_Q02_ZERO_TRADE_REPAIR_PREDECESSOR_ID
        in current_payload.get("source_repair_predecessor_work_item_ids", [])
    )


def _active_stale_rollout_hold_ids(
    conn: sqlite3.Connection,
    *,
    ea_id: str,
    ea_label: str,
    source_sha: str,
) -> list[str]:
    rows = conn.execute(
        """SELECT w.id,w.status,w.claimed_by,w.payload_json
           FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
           WHERE w.ea_id=? AND w.phase=? AND h.hold_code=? AND h.active=1""",
        (ea_id, COMPILE_EA_PHASE, COMPILE_ACTIVATION_HOLD_CODE),
    ).fetchall()
    return sorted(
        str(row["id"])
        for row in rows
        if row["status"] == "pending"
        and row["claimed_by"] is None
        and str(_json_object(row["payload_json"]).get("ea_label") or "") == ea_label
        and str(_json_object(row["payload_json"]).get("mq5_sha256") or "").lower()
        != source_sha.lower()
    )


def _active_stale_rollout_hold_exists(
    conn: sqlite3.Connection,
    *,
    ea_id: str,
    ea_label: str,
    source_sha: str,
) -> bool:
    return bool(
        _active_stale_rollout_hold_ids(
            conn,
            ea_id=ea_id,
            ea_label=ea_label,
            source_sha=source_sha,
        )
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
            "SELECT id,kind,ea_id,phase,status,verdict,attempt_count,claimed_by,"
            "parent_task_id,setfile_path,evidence_path,payload_json,ex5_sha256,"
            "mq5_sha256 FROM work_items"
        ):
            ea_id = _numeric_ea_reference(row["ea_id"])
            if not ea_id:
                continue
            item = dict(row)
            work_rows[ea_id].append(item)
            if row["phase"] == COMPILE_EA_PHASE and row["status"] in ("pending", "active"):
                open_compile[ea_id].append(item)
        for row in conn.execute(
            """SELECT w.id,w.ea_id,w.status,w.verdict,w.claimed_by,
                      w.payload_json,h.active
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
    current_row = (
        _work_row_by_id(inventory, ea_id, str(current_work_item_id))
        if current_work_item_id else None
    )
    current_payload = _json_object(current_row.get("payload_json")) if current_row else {}
    generic_repair = bool(
        current_payload.get("repair_successor_contract_version")
        == REPAIR_SUCCESSOR_CONTRACT_VERSION
        and current_payload.get("compile_source_repair_authority")
        == REPAIR_SUCCESSOR_AUTHORITY
        and current_payload.get("append_only_source_repair") is True
        and str(current_payload.get("repair_successor_of_work_item_id") or "")
        in sanctioned_ids
    )
    repair_authorized = repair_authorized or generic_repair
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

    sibling_rebind_authorized = _sibling_rebind_authorized(
        canonical_label, source_repair_authority
    )
    sibling_rebind_setfile: Path | None = None
    sibling_rebind_setfile_sha: str | None = None
    sibling_rebind_findings: list[str] = []
    if sibling_rebind_authorized:
        if len(symbols) != 1 or not timeframe.get("timeframe"):
            sibling_rebind_findings.append(
                "SIBLING_REBIND_IDENTITY_CARDINALITY_INVALID"
            )
        else:
            sibling_rebind_setfile = _sibling_rebind_setfile_path(
                ea_dir,
                canonical_label,
                symbols[0],
                str(timeframe["timeframe"]),
                source_repair_authority,
            )
            valid, sibling_rebind_findings = _sibling_rebind_setfile_check(
                sibling_rebind_setfile, source_repair_authority
            )
            if valid:
                sibling_rebind_setfile_sha = sha256_file(sibling_rebind_setfile)
        reasons.extend(sibling_rebind_findings)

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
    source_repair_predecessor_ids = {
        str(row.get("id")) for row in prior_compile_rows
    }
    if (
        repair_authorized
        and source_repair_authority
        == QM5_10025_Q02_ZERO_TRADE_REPAIR_AUTHORITY
    ):
        source_repair_predecessor_ids.add(
            QM5_10025_Q02_ZERO_TRADE_REPAIR_PREDECESSOR_ID
        )
    if (
        repair_authorized
        and source_repair_authority == QM5_10718_MAE_BUILD_REPAIR_AUTHORITY
    ):
        source_repair_predecessor_ids.add(
            QM5_10718_MAE_BUILD_REPAIR_PREDECESSOR_ID
        )
    if (
        repair_authorized
        and source_repair_authority == QM5_10717_BASKET_BUILD_REPAIR_AUTHORITY
    ):
        source_repair_predecessor_ids.add(
            QM5_10717_BASKET_BUILD_REPAIR_PREDECESSOR_ID
        )

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
            source_repair_predecessor_ids
        ),
        "source_repair_stale_open_work_item_ids": sorted(
            str(row.get("id"))
            for row in inventory["open_compile"].get(ea_id, [])
            if str(row.get("id")) != str(current_work_item_id or "")
            and str(_json_object(row.get("payload_json")).get("mq5_sha256") or "").lower()
            != str(source_sha or "").lower()
        ),
        "sibling_rebind_authorized": sibling_rebind_authorized,
        "sibling_rebind_contract_version": (
            DL089_SIBLING_REBIND_CONTRACT_VERSION
            if sibling_rebind_authorized else None
        ),
        "sibling_rebind_current_setfile_path": (
            str(sibling_rebind_setfile) if sibling_rebind_setfile else None
        ),
        "sibling_rebind_current_setfile_sha256": sibling_rebind_setfile_sha,
        "sibling_rebind_historical_setfiles": bound_hashes,
        "sibling_rebind_findings": sibling_rebind_findings,
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


def _qm5_41245_setfile_unbind_predecessor_authorized(
    payload: dict[str, Any],
    inventory: dict[str, Any],
    ea_id: str,
    seen: frozenset[str],
) -> str | None:
    """Validate the exact immutable pre-compile setfile-binding incident."""
    source_sha = str(payload.get("mq5_sha256") or "").lower()
    predecessor_id = str(payload.get("retry_of_work_item_id") or "")
    if not (
        ea_id == "41245"
        and payload.get("compile_retry_contract_version")
        == QM5_41245_SETFILE_UNBIND_RETRY_CONTRACT_VERSION
        and payload.get("compile_retry_authority")
        == QM5_41245_SETFILE_UNBIND_RETRY_AUTHORITY
        and payload.get("append_only_retry") is True
        and payload.get("ea_label")
        == QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL
        and source_sha == QM5_41245_SETFILE_UNBIND_RETRY_SOURCE_SHA256
        and predecessor_id
        == QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID
        and predecessor_id not in seen
    ):
        return None

    predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
    if not predecessor:
        return None
    predecessor_payload = _json_object(predecessor.get("payload_json"))
    compile_result = predecessor_payload.get("compile_result")
    failure_classes = (
        compile_result.get("failure_classes", [])
        if isinstance(compile_result, dict)
        else []
    )
    evidence_path = Path(str(predecessor.get("evidence_path") or ""))
    if not (
        predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "failed"
        and predecessor.get("verdict") == "COMPILE_FAIL"
        and predecessor_payload.get("ea_label")
        == QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL
        and str(predecessor_payload.get("mq5_sha256") or "").lower()
        == source_sha
        and predecessor_payload.get("verdict_reason")
        == COMPILE_RECHECK_FAILURE_CLASS
        and failure_classes == [COMPILE_RECHECK_FAILURE_CLASS]
        and isinstance(compile_result, dict)
        and compile_result.get("compile_result") is None
        and compile_result.get("build_check_result") is None
        and compile_result.get("ex5_sha256") is None
        and int(compile_result.get("setfile_count") or 0) == 0
        and evidence_path.is_file()
        and sha256_file(evidence_path).lower()
        == QM5_41245_SETFILE_UNBIND_RETRY_EVIDENCE_SHA256
    ):
        return None
    try:
        evidence = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    candidate = evidence.get("candidate_recheck")
    if not (
        evidence.get("work_item_id") == predecessor_id
        and evidence.get("ea_id") == "QM5_41245"
        and evidence.get("ea_label")
        == QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL
        and evidence.get("success") is False
        and evidence.get("failure_classes")
        == [COMPILE_RECHECK_FAILURE_CLASS]
        and isinstance(candidate, dict)
        and candidate.get("eligible") is False
        and candidate.get("reason") == "BOUND_SETFILE_HASH_EXISTS"
        and candidate.get("reasons") == ["BOUND_SETFILE_HASH_EXISTS"]
        and str(candidate.get("mq5_sha256") or "").lower() == source_sha
    ):
        return None
    return predecessor_id


def _qm5_41285_unbound_compile_predecessor_authorized(
    payload: dict[str, Any],
    inventory: dict[str, Any],
    ea_id: str,
    current_work_item_id: str | None,
    seen: frozenset[str],
) -> str | None:
    """Validate the one immutable enqueue-before-build-task incident.

    The successor is append-only and must be bound to the sole open build task.
    This exception ignores only the exact unclaimed predecessor row; ordinary
    work, source drift, alternate labels, and alternate successor ids remain
    fail-closed.
    """

    predecessor_id = QM5_41285_UNBOUND_COMPILE_RETRY_PREDECESSOR_ID
    successor_id = str(payload.get("unbound_compile_retry_work_item_id") or "")
    source_sha = str(payload.get("mq5_sha256") or "").lower()
    if not (
        ea_id == "41285"
        and current_work_item_id
        and successor_id == str(current_work_item_id)
        and predecessor_id not in seen
        and payload.get("compile_unbound_task_retry_contract_version")
        == QM5_41285_UNBOUND_COMPILE_RETRY_CONTRACT_VERSION
        and payload.get("compile_unbound_task_retry_authority")
        == QM5_41285_UNBOUND_COMPILE_RETRY_AUTHORITY
        and payload.get("retry_of_work_item_id") == predecessor_id
        and payload.get("append_only_unbound_task_retry") is True
        and payload.get("ea_label") == QM5_41285_UNBOUND_COMPILE_RETRY_EA_LABEL
        and source_sha == QM5_41285_UNBOUND_COMPILE_RETRY_SOURCE_SHA256
        and payload.get("compile_build_task_binding_contract_version")
        == BUILD_TASK_BINDING_CONTRACT_VERSION
        and str(payload.get("bound_build_task_id") or "").strip()
        and payload.get("bound_build_task_ea_id") == "QM5_41285"
        and successor_id
        in inventory.get("superseded_by", {}).get(predecessor_id, set())
    ):
        return None

    successor = _work_row_by_id(inventory, ea_id, successor_id)
    predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
    if not successor or not predecessor:
        return None
    predecessor_payload = _json_object(predecessor.get("payload_json"))
    risk = predecessor_payload.get("risk_contract")
    try:
        fixed_risk = float(risk.get("RISK_FIXED")) if isinstance(risk, dict) else 0.0
        percent_risk = float(risk.get("RISK_PERCENT")) if isinstance(risk, dict) else -1.0
    except (TypeError, ValueError):
        return None
    if not (
        str(successor.get("id")) == successor_id
        and successor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("kind") == COMPILE_WORK_ITEM_KIND
        and predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "pending"
        and predecessor.get("verdict") is None
        and int(predecessor.get("attempt_count") or 0) == 0
        and predecessor.get("claimed_by") is None
        and predecessor.get("parent_task_id") is None
        and not str(predecessor.get("setfile_path") or "")
        and predecessor.get("evidence_path") is None
        and predecessor.get("ex5_sha256") is None
        and predecessor_payload.get("compile_contract_version")
        == COMPILE_CONTRACT_VERSION
        and predecessor_payload.get("ea_label")
        == QM5_41285_UNBOUND_COMPILE_RETRY_EA_LABEL
        and str(predecessor_payload.get("mq5_sha256") or "").lower()
        == source_sha
        and not predecessor_payload.get("bound_build_task_id")
        and predecessor_payload.get("utility_phase") is True
        and predecessor_payload.get("no_gate_verdict") is True
        and fixed_risk == 1000.0
        and percent_risk == 0.0
    ):
        return None
    return predecessor_id


def _stale_build_binding_failure_evidence_sha(
    predecessor: dict[str, Any] | None,
    *,
    ea_id: str,
    ea_label: str,
    source_sha: str,
) -> str | None:
    """Authenticate a pre-compiler failure caused only by a closed build task."""

    if not predecessor or not _BOUND_HASH_RE.fullmatch(source_sha):
        return None
    payload = _json_object(predecessor.get("payload_json"))
    compile_result = payload.get("compile_result")
    evidence_path = Path(str(predecessor.get("evidence_path") or ""))
    risk = payload.get("risk_contract")
    try:
        fixed_risk = float(risk.get("RISK_FIXED")) if isinstance(risk, dict) else 0.0
        percent_risk = float(risk.get("RISK_PERCENT")) if isinstance(risk, dict) else -1.0
    except (TypeError, ValueError):
        return None
    if not (
        predecessor.get("kind") == COMPILE_WORK_ITEM_KIND
        and predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "failed"
        and predecessor.get("verdict") == "COMPILE_FAIL"
        and predecessor.get("ea_id") == f"QM5_{ea_id}"
        and payload.get("compile_contract_version") == COMPILE_CONTRACT_VERSION
        and payload.get("compile_build_task_binding_contract_version")
        == BUILD_TASK_BINDING_CONTRACT_VERSION
        and str(payload.get("bound_build_task_id") or "").strip()
        and payload.get("bound_build_task_ea_id") == f"QM5_{ea_id}"
        and payload.get("ea_label") == ea_label
        and str(payload.get("mq5_sha256") or "").lower() == source_sha
        and payload.get("utility_phase") is True
        and payload.get("no_gate_verdict") is True
        and fixed_risk == 1000.0
        and percent_risk == 0.0
        and payload.get("verdict_reason") == COMPILE_RECHECK_FAILURE_CLASS
        and isinstance(compile_result, dict)
        and compile_result.get("success") is False
        and compile_result.get("failure_classes")
        == [COMPILE_RECHECK_FAILURE_CLASS]
        and compile_result.get("compile_result") is None
        and compile_result.get("build_check_result") is None
        and compile_result.get("ex5_sha256") is None
        and int(compile_result.get("setfile_count") or 0) == 0
        and evidence_path.is_file()
    ):
        return None
    try:
        evidence = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    candidate = evidence.get("candidate_recheck")
    binding = candidate.get("build_task_binding") if isinstance(candidate, dict) else None
    if not (
        evidence.get("work_item_id") == str(predecessor.get("id"))
        and evidence.get("ea_id") == f"QM5_{ea_id}"
        and evidence.get("ea_label") == ea_label
        and evidence.get("success") is False
        and evidence.get("failure_classes") == [COMPILE_RECHECK_FAILURE_CLASS]
        and isinstance(candidate, dict)
        and candidate.get("eligible") is False
        and candidate.get("reason") == RECHECK_SUCCESSOR_FAILURE_REASON
        and candidate.get("reasons") == [RECHECK_SUCCESSOR_FAILURE_REASON]
        and str(candidate.get("mq5_sha256") or "").lower() == source_sha
        and isinstance(binding, dict)
        and binding.get("requested") is True
        and binding.get("authorized") is False
        and binding.get("reason") == RECHECK_SUCCESSOR_FAILURE_REASON
        and binding.get("build_task_id") == payload.get("bound_build_task_id")
    ):
        return None
    return sha256_file(evidence_path).lower()


def _sanctioned_compile_predecessor_ids(
    payload: dict[str, Any],
    inventory: dict[str, Any],
    ea_id: str,
    *,
    seen: frozenset[str] = frozenset(),
    current_work_item_id: str | None = None,
) -> set[str]:
    """Return only incident-authorized immutable COMPILE_EA lineage.

    COMPILE_EA normally refuses an EA with *any* prior work. Recognized
    append-only contracts may hide only their authenticated predecessor: the
    historical R11 incidents, or an unchanged-source pre-compiler failure whose
    sole defect was an expired build-task binding. Malformed provenance fails
    closed and ordinary Q work is never ignored.
    """

    source_sha = str(payload.get("mq5_sha256") or "").lower()
    if not _BOUND_HASH_RE.fullmatch(source_sha):
        return set()

    if (
        payload.get("recheck_successor_contract_version")
        == RECHECK_SUCCESSOR_CONTRACT_VERSION
        and payload.get("recheck_successor_authority")
        == RECHECK_SUCCESSOR_AUTHORITY
        and payload.get("append_only_recheck_successor") is True
        and current_work_item_id
    ):
        predecessor_id = str(payload.get("retry_of_work_item_id") or "")
        predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
        current = _work_row_by_id(inventory, ea_id, str(current_work_item_id))
        predecessor_payload = (
            _json_object(predecessor.get("payload_json")) if predecessor else {}
        )
        predecessor_evidence_sha = _stale_build_binding_failure_evidence_sha(
            predecessor,
            ea_id=ea_id,
            ea_label=str(payload.get("ea_label") or ""),
            source_sha=source_sha,
        )
        old_build_task_id = str(
            predecessor_payload.get("bound_build_task_id") or ""
        )
        new_build_task_id = str(payload.get("bound_build_task_id") or "")
        if (
            predecessor_id
            and predecessor_id not in seen
            and current
            and str(current.get("id")) == str(current_work_item_id)
            and current.get("phase") == COMPILE_EA_PHASE
            and current.get("ea_id") == f"QM5_{ea_id}"
            and predecessor_evidence_sha
            and payload.get("predecessor_evidence_sha256")
            == predecessor_evidence_sha
            and payload.get("predecessor_build_task_id") == old_build_task_id
            and old_build_task_id
            and new_build_task_id
            and new_build_task_id != old_build_task_id
            and payload.get("compile_build_task_binding_contract_version")
            == BUILD_TASK_BINDING_CONTRACT_VERSION
            and payload.get("bound_build_task_ea_id") == f"QM5_{ea_id}"
            and str(current_work_item_id)
            in inventory.get("superseded_by", {}).get(predecessor_id, set())
        ):
            return {predecessor_id}
        return set()

    if (
        payload.get("repair_successor_contract_version")
        == REPAIR_SUCCESSOR_CONTRACT_VERSION
        and payload.get("append_only_source_repair") is True
        and current_work_item_id
    ):
        predecessor_id = str(payload.get("repair_successor_of_work_item_id") or "")
        predecessor = _work_row_by_id(inventory, ea_id, predecessor_id)
        predecessor_payload = _json_object(predecessor.get("payload_json")) if predecessor else {}
        old_sha = str(predecessor_payload.get("mq5_sha256") or "").lower()
        if (
            predecessor_id
            and predecessor_id not in seen
            and predecessor
            and predecessor.get("phase") == COMPILE_EA_PHASE
            and predecessor.get("status") == "failed"
            and predecessor.get("verdict") in {"COMPILE_FAIL", "BUILD_CHECK_FAIL"}
            and predecessor.get("ea_id") == f"QM5_{ea_id}"
            and _BOUND_HASH_RE.fullmatch(old_sha)
            and old_sha != source_sha
            and payload.get("repair_predecessor_mq5_sha256") == old_sha
            and str(payload.get("bound_build_task_id") or "")
            == str(predecessor_payload.get("bound_build_task_id") or "")
            and str(current_work_item_id)
            in inventory.get("superseded_by", {}).get(predecessor_id, set())
        ):
            return {predecessor_id}
        return set()

    qm5_41285_predecessor = (
        _qm5_41285_unbound_compile_predecessor_authorized(
            payload,
            inventory,
            ea_id,
            current_work_item_id,
            seen,
        )
    )
    if qm5_41285_predecessor:
        return {qm5_41285_predecessor}

    qm5_41245_predecessor = (
        _qm5_41245_setfile_unbind_predecessor_authorized(
            payload, inventory, ea_id, seen
        )
    )
    if qm5_41245_predecessor:
        return {qm5_41245_predecessor}

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
            current_work_item_id=predecessor_id,
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
            current_work_item_id=predecessor_id,
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
                rollout_predecessor_ids: list[str] = []
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
                if source_repair_authority == (
                    ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY
                ):
                    rollout_predecessor_ids = _active_stale_rollout_hold_ids(
                        conn,
                        ea_id=str(candidate["ea_id"]),
                        ea_label=str(candidate["ea_label"]),
                        source_sha=str(candidate["mq5_sha256"]),
                    )
                    expected_predecessor_ids = sorted(
                        str(value)
                        for value in candidate.get(
                            "source_repair_stale_open_work_item_ids", []
                        )
                        if str(value or "")
                    )
                    if (
                        not rollout_predecessor_ids
                        or rollout_predecessor_ids != expected_predecessor_ids
                    ):
                        refused.append({
                            **candidate,
                            "eligible": False,
                            "reason": "SOURCE_REPAIR_AUTHORITY_INVALID_AT_APPLY",
                            "reasons": [
                                "SOURCE_REPAIR_AUTHORITY_INVALID_AT_APPLY"
                            ],
                            "expected_stale_rollout_predecessor_ids": (
                                expected_predecessor_ids
                            ),
                            "active_stale_rollout_predecessor_ids": (
                                rollout_predecessor_ids
                            ),
                        })
                        continue
                    already_superseded_ids = [
                        predecessor_id
                        for predecessor_id in rollout_predecessor_ids
                        if conn.execute(
                            "SELECT 1 FROM work_item_supersedes "
                            "WHERE work_item_id=? LIMIT 1",
                            (predecessor_id,),
                        ).fetchone()
                    ]
                    if already_superseded_ids:
                        refused.append({
                            **candidate,
                            "eligible": False,
                            "reason": (
                                "SOURCE_REPAIR_PREDECESSOR_ALREADY_SUPERSEDED_AT_APPLY"
                            ),
                            "reasons": [
                                "SOURCE_REPAIR_PREDECESSOR_ALREADY_SUPERSEDED_AT_APPLY"
                            ],
                            "already_superseded_work_item_ids": (
                                already_superseded_ids
                            ),
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
                    force_rebuild_note = force_rebuild_evidence_note(
                        str(candidate["numeric_ea_id"])
                    )
                    if force_rebuild_note:
                        payload["force_rebuild_evidence_note"] = force_rebuild_note
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
                    if candidate.get("sibling_rebind_authorized"):
                        payload.update({
                            "sibling_rebind_contract_version": (
                                DL089_SIBLING_REBIND_CONTRACT_VERSION
                            ),
                            "sibling_rebind_authority": source_repair_authority,
                            "sibling_rebind_current_setfile_path": candidate.get(
                                "sibling_rebind_current_setfile_path"
                            ),
                            "sibling_rebind_current_setfile_sha256": candidate.get(
                                "sibling_rebind_current_setfile_sha256"
                            ),
                            "sibling_rebind_historical_setfiles": candidate.get(
                                "sibling_rebind_historical_setfiles", []
                            ),
                            "append_only_sibling_rebind": True,
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
                for predecessor_id in rollout_predecessor_ids:
                    conn.execute(
                        "INSERT INTO work_item_supersedes "
                        "(work_item_id,superseded_by_work_item_id,reason,"
                        "source_encoding,evidence_path,recorded_by,recorded_at) "
                        "VALUES (?,?,?,?,NULL,?,?)",
                        (
                            predecessor_id,
                            work_item_id,
                            "current-source compile supersedes stale rollout-held compile",
                            ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY,
                            "compile_work_items",
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


def enqueue_repair_successor(
    root: Path,
    repo_root: Path,
    predecessor_id: str,
    *,
    build_task_id: str | None = None,
    apply: bool = False,
) -> dict[str, Any]:
    """Append a held, task-bound successor for a source-repaired compile failure.

    A predecessor normally carries its immutable build-task binding.  An
    initial unbound enqueue can still fail closed on a later source hash before
    a build task exists; in that one case the caller may supply the sole open
    task explicitly.  Existing bindings are never silently replaced.
    """
    inventory = _inventory(root, repo_root)
    predecessor = next(
        (row for rows in inventory["work_rows"].values() for row in rows
         if str(row.get("id")) == str(predecessor_id)),
        None,
    )
    reasons: list[str] = []
    old_payload = _json_object(predecessor.get("payload_json")) if predecessor else {}
    label = str(old_payload.get("ea_label") or "")
    parts = _label_parts(label)
    old_sha = str(old_payload.get("mq5_sha256") or "").lower()
    source = repo_root / "framework" / "EAs" / label / f"{label}.mq5"
    new_sha = sha256_file(source) if source.is_file() else None
    predecessor_build_task_id = str(
        old_payload.get("bound_build_task_id") or ""
    ).strip()
    requested_build_task_id = str(
        build_task_id or predecessor_build_task_id
    ).strip()
    if not predecessor:
        reasons.append("PREDECESSOR_NOT_FOUND")
    elif not (
        predecessor.get("phase") == COMPILE_EA_PHASE
        and predecessor.get("status") == "failed"
        and predecessor.get("verdict") in {"COMPILE_FAIL", "BUILD_CHECK_FAIL"}
    ):
        reasons.append("PREDECESSOR_NOT_TERMINAL_COMPILE_FAILURE")
    if not parts or predecessor and predecessor.get("ea_id") != f"QM5_{parts[1]}":
        reasons.append("PREDECESSOR_EA_IDENTITY_INVALID")
    if not _BOUND_HASH_RE.fullmatch(old_sha):
        reasons.append("PREDECESSOR_MQ5_SHA256_INVALID")
    if not new_sha:
        reasons.append("CURRENT_SOURCE_MISSING")
    elif new_sha.lower() == old_sha:
        reasons.append("SOURCE_NOT_REPAIRED")
    if (
        predecessor_build_task_id
        and build_task_id
        and str(build_task_id).strip() != predecessor_build_task_id
    ):
        reasons.append("PREDECESSOR_BUILD_TASK_REBIND_FORBIDDEN")
    binding = (
        _build_task_binding(
            repo_root,
            label,
            parts[1],
            requested_build_task_id,
            inventory,
        )
        if parts else {"authorized": False, "reason": "EA_LABEL_INVALID"}
    )
    if not binding.get("authorized"):
        reasons.append(str(binding.get("reason") or "BUILD_TASK_BINDING_INVALID"))
    if predecessor_id in inventory.get("superseded_by", {}):
        reasons.append("PREDECESSOR_ALREADY_SUPERSEDED")
    plan = {
        "ok": not reasons,
        "mode": "apply" if apply else "dry_run",
        "eligible": not reasons,
        "reasons": reasons,
        "predecessor_work_item_id": predecessor_id,
        "ea_label": label or None,
        "old_mq5_sha256": old_sha or None,
        "current_mq5_sha256": new_sha,
        "build_task_id": requested_build_task_id or None,
        "build_task_binding": binding,
        "successor_work_item_id": None,
    }
    if reasons or not apply:
        return plan
    assert predecessor and parts and new_sha
    successor_id = str(uuid.uuid4())
    now = utc_now()
    payload = {
        key: value for key, value in old_payload.items()
        if key not in {"compile_completed_at", "compile_result", "verdict_reason", "verdict_taxonomy", "ex5_sha256", "expected_ex5_sha256"}
    }
    payload.update({
        "compile_contract_version": COMPILE_CONTRACT_VERSION,
        "compile_activation_state": "AWAITING_REVIEWED_WORKER_ROLLOUT",
        "compile_activation_hold_code": COMPILE_ACTIVATION_HOLD_CODE,
        "mq5_path": str(source),
        "mq5_sha256": new_sha,
        "compile_source_repair_contract_version": SOURCE_REPAIR_CONTRACT_VERSION,
        "compile_source_repair_authority": REPAIR_SUCCESSOR_AUTHORITY,
        "repair_successor_contract_version": REPAIR_SUCCESSOR_CONTRACT_VERSION,
        "repair_successor_of_work_item_id": predecessor_id,
        "repair_predecessor_mq5_sha256": old_sha,
        "append_only_source_repair": True,
        "source_repair_predecessor_work_item_ids": [predecessor_id],
        "ignore_stale_ex5_and_bound_setfile": True,
        "enqueued_at": now,
    })
    payload.update({
        "compile_build_task_binding_contract_version": (
            BUILD_TASK_BINDING_CONTRACT_VERSION
        ),
        "bound_build_task_id": requested_build_task_id,
        "bound_build_task_ea_id": predecessor["ea_id"],
    })
    with _connect(root) as conn:
        conn.execute("BEGIN IMMEDIATE")
        if conn.execute("SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (predecessor_id,)).fetchone():
            conn.rollback()
            return {**plan, "ok": False, "eligible": False, "reasons": ["PREDECESSOR_ALREADY_SUPERSEDED_AT_APPLY"]}
        conn.execute(
            "INSERT INTO work_items (id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,payload_json,created_at,updated_at) VALUES (?,?,?,?,?,'','pending',0,?,?,?)",
            (successor_id, COMPILE_WORK_ITEM_KIND, COMPILE_EA_PHASE, predecessor["ea_id"], "", json.dumps(payload, sort_keys=True), now, now),
        )
        conn.execute(
            "INSERT INTO work_item_holds (work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at,released_at,release_note) VALUES (?,?,?,1,1,?,?,NULL,NULL)",
            (successor_id, COMPILE_ACTIVATION_HOLD_CODE, COMPILE_ACTIVATION_HOLD_REASON, now, now),
        )
        conn.execute(
            "INSERT INTO work_item_supersedes (work_item_id,superseded_by_work_item_id,reason,source_encoding,evidence_path,recorded_by,recorded_at) VALUES (?,?,?,?,?,?,?)",
            (predecessor_id, successor_id, "source repaired after terminal compile/build-check failure", "farmctl:repair-successor-of", predecessor.get("evidence_path"), "farmctl", now),
        )
        conn.commit()
    return {**plan, "mode": "apply", "successor_work_item_id": successor_id}


def enqueue_recheck_successor(
    root: Path,
    repo_root: Path,
    predecessor_id: str,
    build_task_id: str,
    *,
    apply: bool = False,
) -> dict[str, Any]:
    """Append an unchanged-source retry for an expired build-task binding.

    This path sanctions exactly one immutable predecessor whose worker stopped
    before build-check/compile. The replacement must bind to the sole open
    build task for the same EA, while all ordinary candidate guards remain on.
    """

    inventory = _inventory(root, repo_root)
    predecessor = next(
        (
            row
            for rows in inventory["work_rows"].values()
            for row in rows
            if str(row.get("id")) == str(predecessor_id)
        ),
        None,
    )
    reasons: list[str] = []
    old_payload = _json_object(predecessor.get("payload_json")) if predecessor else {}
    label = str(old_payload.get("ea_label") or "")
    parts = _label_parts(label)
    old_sha = str(old_payload.get("mq5_sha256") or "").lower()
    source = repo_root / "framework" / "EAs" / label / f"{label}.mq5"
    current_sha = sha256_file(source).lower() if source.is_file() else None
    requested_build_task_id = str(build_task_id or "").strip()
    old_build_task_id = str(old_payload.get("bound_build_task_id") or "").strip()
    evidence_sha = None

    if not predecessor:
        reasons.append("PREDECESSOR_NOT_FOUND")
    if not parts or predecessor and predecessor.get("ea_id") != f"QM5_{parts[1]}":
        reasons.append("PREDECESSOR_EA_IDENTITY_INVALID")
    if not current_sha:
        reasons.append("CURRENT_SOURCE_MISSING")
    elif current_sha != old_sha:
        reasons.append("SOURCE_CHANGED_AFTER_RECHECK_FAILURE")
    if not requested_build_task_id:
        reasons.append("BUILD_TASK_BINDING_NOT_REQUESTED")
    elif requested_build_task_id == old_build_task_id:
        reasons.append("BUILD_TASK_BINDING_NOT_RENEWED")
    if parts and predecessor and current_sha:
        evidence_sha = _stale_build_binding_failure_evidence_sha(
            predecessor,
            ea_id=parts[1],
            ea_label=label,
            source_sha=current_sha,
        )
        if not evidence_sha:
            reasons.append("PREDECESSOR_NOT_STALE_BUILD_BINDING_FAILURE")
    binding = (
        _build_task_binding(
            repo_root,
            label,
            parts[1],
            requested_build_task_id,
            inventory,
        )
        if parts and requested_build_task_id
        else {"authorized": False, "reason": "BUILD_TASK_BINDING_NOT_REQUESTED"}
    )
    if requested_build_task_id and not binding.get("authorized"):
        reasons.append(str(binding.get("reason") or "BUILD_TASK_BINDING_INVALID"))
    if predecessor_id in inventory.get("superseded_by", {}):
        reasons.append("PREDECESSOR_ALREADY_SUPERSEDED")

    candidate: dict[str, Any] | None = None
    if not reasons and parts:
        candidate = classify_candidate(
            root,
            repo_root,
            label,
            inventory,
            sanctioned_predecessor_ids={predecessor_id},
            bound_build_task_id=requested_build_task_id,
        )
        if not candidate.get("eligible"):
            reasons.extend(
                str(reason)
                for reason in candidate.get("reasons") or [candidate.get("reason")]
                if reason
            )

    plan = {
        "ok": not reasons,
        "mode": "apply" if apply else "dry_run",
        "eligible": not reasons,
        "reasons": reasons,
        "predecessor_work_item_id": predecessor_id,
        "ea_label": label or None,
        "mq5_sha256": current_sha,
        "predecessor_evidence_sha256": evidence_sha,
        "predecessor_build_task_id": old_build_task_id or None,
        "build_task_id": requested_build_task_id or None,
        "build_task_binding": binding,
        "candidate": candidate,
        "successor_work_item_id": None,
    }
    if reasons or not apply:
        return plan

    assert predecessor and parts and current_sha and evidence_sha and candidate
    successor_id = str(uuid.uuid4())
    now = utc_now()
    with _connect(root) as conn:
        conn.execute("BEGIN IMMEDIATE")
        apply_reasons: list[str] = []
        current_predecessor_row = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (predecessor_id,)
        ).fetchone()
        current_predecessor = (
            dict(current_predecessor_row) if current_predecessor_row else None
        )
        if not current_predecessor or (
            current_predecessor.get("status") != "failed"
            or current_predecessor.get("verdict") != "COMPILE_FAIL"
            or _json_object(current_predecessor.get("payload_json")) != old_payload
        ):
            apply_reasons.append("PREDECESSOR_CHANGED_AT_APPLY")
        if conn.execute(
            "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?",
            (predecessor_id,),
        ).fetchone():
            apply_reasons.append("PREDECESSOR_ALREADY_SUPERSEDED_AT_APPLY")
        if conn.execute(
            "SELECT 1 FROM work_items WHERE ea_id=? AND id<>? LIMIT 1",
            (f"QM5_{parts[1]}", predecessor_id),
        ).fetchone():
            apply_reasons.append("OTHER_WORK_ITEMS_EXIST_AT_APPLY")
        if not source.is_file() or sha256_file(source).lower() != current_sha:
            apply_reasons.append("SOURCE_CHANGED_AT_APPLY")
        elif source.with_suffix(".ex5").exists():
            apply_reasons.append("EX5_ALREADY_PRESENT_AT_APPLY")
        if _bound_setfile_hashes(source.parent):
            apply_reasons.append("BOUND_SETFILE_HASH_EXISTS_AT_APPLY")
        current_evidence_sha = (
            _stale_build_binding_failure_evidence_sha(
                current_predecessor,
                ea_id=parts[1],
                ea_label=label,
                source_sha=current_sha,
            )
            if current_predecessor
            else None
        )
        if current_evidence_sha != evidence_sha:
            apply_reasons.append("PREDECESSOR_EVIDENCE_CHANGED_AT_APPLY")

        current_build_tasks_by_id: dict[str, dict[str, Any]] = {}
        current_build_tasks_by_ea: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for task_row in conn.execute(
            "SELECT id,status,card_id,payload_json FROM tasks WHERE kind='build_ea'"
        ):
            task = dict(task_row)
            current_build_tasks_by_id[str(task_row["id"])] = task
            task_ea_id = _numeric_ea_reference(task_row["card_id"])
            if task_ea_id:
                current_build_tasks_by_ea[task_ea_id].append(task)
        current_binding = _build_task_binding(
            repo_root,
            label,
            parts[1],
            requested_build_task_id,
            {
                "build_tasks_by_id": current_build_tasks_by_id,
                "build_tasks_by_ea": current_build_tasks_by_ea,
            },
        )
        if not current_binding.get("authorized"):
            apply_reasons.append("BUILD_TASK_BINDING_INVALID_AT_APPLY")
        if apply_reasons:
            conn.rollback()
            return {
                **plan,
                "ok": False,
                "eligible": False,
                "reasons": apply_reasons,
                "build_task_binding": current_binding,
            }

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
            "compile_build_task_binding_contract_version": (
                BUILD_TASK_BINDING_CONTRACT_VERSION
            ),
            "bound_build_task_id": requested_build_task_id,
            "bound_build_task_ea_id": candidate["ea_id"],
            "recheck_successor_contract_version": RECHECK_SUCCESSOR_CONTRACT_VERSION,
            "recheck_successor_authority": RECHECK_SUCCESSOR_AUTHORITY,
            "retry_of_work_item_id": predecessor_id,
            "predecessor_build_task_id": old_build_task_id,
            "predecessor_evidence_path": predecessor.get("evidence_path"),
            "predecessor_evidence_sha256": evidence_sha,
            "append_only_recheck_successor": True,
            "enqueued_at": now,
        }
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,"
            "payload_json,created_at,updated_at) "
            "VALUES (?,?,?,?,?,'','pending',0,?,?,?)",
            (
                successor_id,
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
                successor_id,
                COMPILE_ACTIVATION_HOLD_CODE,
                COMPILE_ACTIVATION_HOLD_REASON,
                now,
                now,
            ),
        )
        conn.execute(
            "INSERT INTO work_item_supersedes "
            "(work_item_id,superseded_by_work_item_id,reason,source_encoding,"
            "evidence_path,recorded_by,recorded_at) VALUES (?,?,?,?,?,?,?)",
            (
                predecessor_id,
                successor_id,
                "retry unchanged source after stale build-task binding refusal",
                RECHECK_SUCCESSOR_AUTHORITY,
                predecessor.get("evidence_path"),
                "compile_work_items",
                now,
            ),
        )
        conn.commit()
    return {**plan, "mode": "apply", "successor_work_item_id": successor_id}


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
                current_work_item_id=work_item_id,
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
        sibling_rebind = bool(
            payload.get("append_only_sibling_rebind") is True
            and payload.get("sibling_rebind_contract_version")
            == DL089_SIBLING_REBIND_CONTRACT_VERSION
            and payload.get("sibling_rebind_authority")
            == candidate.get("source_repair_authority")
            and _sibling_rebind_authorized(
                label, str(payload.get("sibling_rebind_authority") or "")
            )
            and candidate.get("sibling_rebind_authorized") is True
        )
        if candidate.get("sibling_rebind_authorized") is True and not sibling_rebind:
            raise RuntimeError("SIBLING_REBIND_PAYLOAD_INVALID")
        sibling_rebind_path: Path | None = None
        if sibling_rebind:
            if (
                candidate.get("sibling_rebind_current_setfile_path")
                != payload.get("sibling_rebind_current_setfile_path")
                or candidate.get("sibling_rebind_current_setfile_sha256")
                != payload.get("sibling_rebind_current_setfile_sha256")
                or candidate.get("sibling_rebind_historical_setfiles")
                != payload.get("sibling_rebind_historical_setfiles")
            ):
                raise RuntimeError("SIBLING_REBIND_BINDING_CHANGED_AFTER_ENQUEUE")
            sibling_rebind_path = Path(
                str(candidate["sibling_rebind_current_setfile_path"])
            )
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
        if sibling_rebind:
            env["QM_SIBLING_REBIND_AUTHORITY"] = str(
                payload["sibling_rebind_authority"]
            )
        creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        generator = repo_root / "framework" / "scripts" / "gen_setfile.ps1"
        for symbol in symbols:
            if sibling_rebind:
                assert sibling_rebind_path is not None
                evidence["setfile_generation"].append({
                    "symbol": symbol,
                    "mode": "pre_generated_append_only_sibling_rebind",
                    "exit_code": 0,
                    "setfile_path": str(sibling_rebind_path),
                    "setfile_exists": sibling_rebind_path.is_file(),
                    "setfile_sha256": (
                        sha256_file(sibling_rebind_path)
                        if sibling_rebind_path.is_file() else None
                    ),
                    "historical_setfiles": payload.get(
                        "sibling_rebind_historical_setfiles", []
                    ),
                })
                if (
                    not sibling_rebind_path.is_file()
                    or sha256_file(sibling_rebind_path)
                    != payload.get("sibling_rebind_current_setfile_sha256")
                ):
                    raise RuntimeError("SIBLING_REBIND_CURRENT_SETFILE_CHANGED")
                continue
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
        if sibling_rebind:
            assert sibling_rebind_path is not None
            build_command.extend([
                "-SiblingRebindSetfilePath", str(sibling_rebind_path),
            ])
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
        setfiles = (
            [sibling_rebind_path]
            if sibling_rebind and sibling_rebind_path is not None
            else sorted((ea_dir / "sets").glob("*.set"))
        )
        evidence["ex5_path"] = str(ex5)
        evidence["ex5_sha256"] = sha256_file(ex5) if ex5.is_file() else None
        evidence["setfile_count"] = len(setfiles)
        if sibling_rebind:
            evidence["sibling_rebind"] = {
                "contract_version": DL089_SIBLING_REBIND_CONTRACT_VERSION,
                "authority": payload.get("sibling_rebind_authority"),
                "current_setfile_path": str(sibling_rebind_path),
                "current_setfile_sha256_after_binding": (
                    sha256_file(sibling_rebind_path)
                    if sibling_rebind_path and sibling_rebind_path.is_file()
                    else None
                ),
                "historical_setfiles_before": payload.get(
                    "sibling_rebind_historical_setfiles", []
                ),
                "historical_setfiles_after": _bound_setfile_hashes(ea_dir),
            }
            if (
                evidence["sibling_rebind"]["historical_setfiles_before"]
                != evidence["sibling_rebind"]["historical_setfiles_after"]
            ):
                raise RuntimeError("SIBLING_REBIND_HISTORICAL_SETFILE_CHANGED")
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
