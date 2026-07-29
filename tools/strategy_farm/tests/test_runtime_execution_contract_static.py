from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
QM = ROOT / "framework" / "include" / "QM"
CONTRACT = (QM / "QM_RuntimeExecutionContract.mqh").read_text(encoding="utf-8")
COMMON = (QM / "QM_Common.mqh").read_text(encoding="utf-8")
ENTRY = (QM / "QM_Entry.mqh").read_text(encoding="utf-8")
BASKET = (QM / "QM_BasketOrder.mqh").read_text(encoding="utf-8")
RUNTIME_SMOKE = (
    ROOT / "framework" / "tests" / "unit" / "runtime_execution_contract_smoke.mq5"
).read_text(encoding="utf-8")
BASKET_SMOKE = (
    ROOT / "framework" / "tests" / "unit" / "basket_order_execution_policy_smoke.mq5"
).read_text(encoding="utf-8")
ENTRY_SMOKE = (
    ROOT / "framework" / "tests" / "unit" / "entry_execution_identity_smoke.mq5"
).read_text(encoding="utf-8")


def _body(source: str, function: str) -> str:
    match = re.search(rf"\b{function}\s*\([^)]*\)\s*\{{", source, re.S)
    assert match, function
    start = match.end() - 1
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(source)):
        char = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]
    raise AssertionError(function)


def test_v3_contract_binds_exact_runtime_and_is_immutable_after_ready() -> None:
    bind = _body(CONTRACT, "QM_RuntimeExecutionBindRequired")
    matches = _body(CONTRACT, "QM_RuntimeExecutionContractMatchesRuntime")
    for field in (
        "contract.ea_id != actual_ea_id",
        "contract.magic != actual_magic",
        "contract.symbol != actual_symbol",
        "contract.chart_timeframe != actual_timeframe",
        "contract.account_login != actual_account_login",
        "contract.account_server != actual_account_server",
        "contract.card_sha256",
        "contract.execution_bundle_sha256",
        "contract.target_rulepack_sha256",
        "contract.magic_registry_sha256",
        "contract.magic_registry_sha256 != actual_magic_registry_sha256",
        "contract.generation != expected_source_generation",
    ):
        assert field in matches
    assert "expected_source_generation <= 0" in matches
    assert "QM_RuntimeExecutionContractMatchesRuntime" in bind
    assert bind.index("IMMUTABLE_REBIND_REFUSED") < bind.index(
        "CONTRACT_BIND_PENDING"
    )
    assert "QM_RUNTIME_EXECUTION_READY" in bind


def test_legacy_state_is_explicit_and_v3_initializer_is_fail_closed() -> None:
    entry_allowed = _body(CONTRACT, "QM_RuntimeExecutionEntryAllowed")
    assert "QM_RUNTIME_EXECUTION_LEGACY_UNDECLARED" in entry_allowed
    assert "QM_RUNTIME_EXECUTION_READY" in entry_allowed

    init_v3 = _body(COMMON, "QM_FrameworkInitV3")
    assert init_v3.index("QM_RuntimeExecutionBeginRequiredInitialization") < init_v3.index(
        "QM_FrameworkInitCoreAfterRuntimeStateArmed"
    ) < init_v3.index(
        "QM_RuntimeExecutionBindRequired"
    )
    assert "expected_source_generation" in init_v3
    assert "return false" in init_v3
    assert "AccountInfoInteger(ACCOUNT_LOGIN)" in init_v3
    assert "AccountInfoString(ACCOUNT_SERVER)" in init_v3
    assert "QM_MagicRegistryHash()" in init_v3

    legacy_init = _body(COMMON, "QM_FrameworkInit")
    assert "QM_RuntimeExecutionBeginLegacyInitialization" in legacy_init
    assert "QM_RuntimeExecutionResetLegacy" not in COMMON
    assert "#ifdef QM_RUNTIME_EXECUTION_TESTING" in CONTRACT
    assert "QM_RuntimeExecutionTestReset" in RUNTIME_SMOKE

    internal_core = "QM_FrameworkInitCoreAfterRuntimeStateArmed("
    for path in (ROOT / "framework" / "EAs").rglob("*.mq5"):
        source = path.read_text(encoding="utf-8", errors="replace")
        assert internal_core not in source, path
        assert "QM_RUNTIME_EXECUTION_TESTING" not in source, path
    for path in (ROOT / "framework" / "include").rglob("*.mqh"):
        if path != QM / "QM_Common.mqh":
            source = path.read_text(encoding="utf-8", errors="replace")
            assert internal_core not in source, path
            if path != QM / "QM_RuntimeExecutionContract.mqh":
                assert "QM_RUNTIME_EXECUTION_TESTING" not in source, path


def test_v3_reinitialization_paths_transition_to_blocked_not_legacy() -> None:
    begin_required = _body(CONTRACT, "QM_RuntimeExecutionBeginRequiredInitialization")
    begin_legacy = _body(CONTRACT, "QM_RuntimeExecutionBeginLegacyInitialization")
    block = _body(CONTRACT, "QM_RuntimeExecutionBlock")
    bind = _body(CONTRACT, "QM_RuntimeExecutionBindRequired")

    assert "QM_RUNTIME_EXECUTION_REQUIRED_BLOCKED" in block
    assert "CONTRACT_REINITIALIZATION_REFUSED" in begin_required
    assert "LEGACY_INIT_AFTER_CONTRACT_REFUSED" in begin_legacy
    assert "IMMUTABLE_REBIND_REFUSED" in bind
    assert "QM_RuntimeExecutionBlock" in begin_required
    assert "QM_RuntimeExecutionBlock" in begin_legacy
    assert "QM_RuntimeExecutionBlock" in bind

    assert "TEST_SOURCE_GENERATION + 1" in RUNTIME_SMOKE
    assert "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" in RUNTIME_SMOKE
    assert "QM_RuntimeExecutionBeginLegacyInitialization() ||" in RUNTIME_SMOKE
    assert "QM_RuntimeExecutionBeginRequiredInitialization() ||" in RUNTIME_SMOKE


def test_v3_ftmo_entry_requires_fresh_account_wide_governor_and_only_reduces() -> None:
    entry = _body(ENTRY, "QM_EntryInternal")
    contract_guard = entry.index("QM_RuntimeExecutionEntryAllowed")
    identity_guard = entry.index("g_qm_entry_ea_id != g_qm_runtime_execution_contract.ea_id")
    kill_switch = entry.index("QM_KillSwitchCheck")
    magic_guard = entry.index("magic != g_qm_runtime_execution_contract.magic")
    magic_context = entry.index("QM_KillSwitchOwnsMagic")
    assert contract_guard < identity_guard < kill_switch < magic_guard < magic_context
    assert "_Symbol != g_qm_runtime_execution_contract.symbol" in entry
    assert "v3_entry_identity_not_contract_bound" in entry
    assert "v3_magic_not_contract_bound" in entry
    assert "QM_FTMO_ReadGovernorScale(" in entry
    assert "QM_ENTRY_REJECTED_GOVERNOR" in entry
    assert "lots * governor_scale" in entry
    assert entry.index("QM_FTMO_ReadGovernorScale(") < entry.index(
        "QM_TradeContextSend("
    )

    matches = _body(CONTRACT, "QM_RuntimeExecutionContractMatchesRuntime")
    assert 'contract.target == "FTMO"' in matches
    assert "!contract.governor_required" in matches
    assert "governor_heartbeat_max_age_seconds > 5" in matches

    assert "g_qm_entry_ea_id = 1003" in ENTRY_SMOKE
    assert "QM_Entry(req, ticket, 10020001)" in ENTRY_SMOKE
    assert ENTRY_SMOKE.count("QM_ENTRY_REJECTED_CONTRACT") == 2


def test_contract_header_is_wired_at_entry_boundary() -> None:
    assert '#include "QM_RuntimeExecutionContract.mqh"' in ENTRY
    assert '#include "QM_FTMOGovernorClient.mqh"' in ENTRY
    assert "QM_ENTRY_REJECTED_CONTRACT" in ENTRY
    assert "QM_ENTRY_REJECTED_GOVERNOR" in ENTRY


def test_basket_v3_path_cannot_bypass_contract_risk_or_governor() -> None:
    basket = _body(BASKET, "QM_BasketOpenPosition")
    contract_guard = basket.index("QM_RuntimeExecutionEntryAllowed")
    ea_identity = basket.index("ea_id != g_qm_runtime_execution_contract.ea_id")
    symbol_identity = basket.index("req.symbol != g_qm_runtime_execution_contract.symbol")
    kill_switch = basket.index("QM_KillSwitchCheck")
    magic_resolve = basket.index("QM_MagicChecked(")
    magic_identity = basket.index("magic != g_qm_runtime_execution_contract.magic")
    risk = basket.index("QM_LotsForRiskAtEntry(req.symbol")
    governor = basket.index("QM_FTMO_ReadGovernorScale(")
    send = basket.index("QM_TradeContextSend(")

    assert contract_guard < ea_identity < symbol_identity < kill_switch
    assert kill_switch < magic_resolve < magic_identity < risk < governor < send
    assert "g_qm_runtime_execution_state == QM_RUNTIME_EXECUTION_READY" in basket
    assert "v3_ea_id_not_contract_bound" in basket
    assert "v3_symbol_not_contract_bound" in basket
    assert "v3_magic_not_contract_bound" in basket
    assert "invalid_stop_direction" in basket
    assert "MathMin(explicit_lots, risk_lots)" in basket
    assert "basket_explicit_risk_cap" in basket
    assert "GOVERNOR_SCALE_ZERO_LOTS" in basket
    assert "RISK_LOSS_CALC_FALLBACK" in basket
    assert "path\\\":\\\"basket" in basket

    assert "QM_RuntimeExecutionBeginRequiredInitialization" in BASKET_SMOKE
    assert "QM_BasketOpenPosition" in BASKET_SMOKE
    assert "req.lots = 100.0" in BASKET_SMOKE
    assert 'req.symbol = _Symbol + ".UNBOUND"' in BASKET_SMOKE
    assert "QM_BasketOpenPosition(1003" in BASKET_SMOKE
    assert "req.symbol_slot = 1" in BASKET_SMOKE
