"""Inert live-mode trial set derivation from database-bound sealed baselines.

This creates review artifacts only. It never installs sets or authorizes execution.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sqlite3

REPO_ROOT = Path(__file__).resolve().parents[3]
TRIAL_ROOT = Path('D:/QM/strategy_farm/artifacts/ftmo_trial_sets_review')
DATABASE = Path('D:/QM/strategy_farm/state/farm_state.sqlite')
BINDING = REPO_ROOT / 'tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json'
RULEPACK = REPO_ROOT / 'tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json'
CANDIDATES = ((10706, 'GBPUSD'), (11421, 'EURUSD'), (11422, 'USDCAD'), (11910, 'NZDUSD'), (13054, 'XTIUSD'), (1537, 'XAGUSD'), (20048, 'XTIUSD'), (21505, 'XAGUSD'))
LANES = {'XAUUSD':'XAUUSD', 'GER40':'GER40.cash', 'GBPUSD':'GBPUSD', 'EURUSD':'EURUSD', 'USDCAD':'USDCAD', 'NZDUSD':'NZDUSD', 'XTIUSD':'USOIL.cash', 'XAGUSD':'XAGUSD'}
ALLOWED = frozenset((
    'RISK_FIXED', 'RISK_PERCENT',
    'qm_news_temporal', 'qm_news_compliance', 'qm_news_stale_max_hours',
    'qm_friday_close_enabled', 'qm_friday_close_hour_broker',
))

class Refusal(ValueError):
    pass


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def values(text: str) -> dict[str, str]:
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        if '=' not in line:
            raise Refusal('malformed_set_line')
        key, value = (part.strip() for part in line.split('=', 1))
        if not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', key) or key in result or not value:
            raise Refusal('duplicate_or_invalid_parameter')
        if '||' in value:
            raise Refusal('optimization_range_not_trial_input')
        result[key] = value
    return result


def decode(raw: bytes) -> str:
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')


def identity(params: dict[str, str]) -> str:
    return sha(json.dumps({k:v for k,v in params.items() if k not in ALLOWED}, sort_keys=True, separators=(',', ':')).encode())


def verify_derivation(before: str, after: str) -> str:
    left, right = values(before), values(after)
    if {k:v for k,v in left.items() if k not in ALLOWED} != {k:v for k,v in right.items() if k not in ALLOWED}:
        raise Refusal('strategy_parameters_changed')
    return identity(left)


def _repo_file(relative: str) -> Path:
    if not isinstance(relative, str) or '\\' in relative or not relative:
        raise Refusal('invalid_repo_relative_path')
    target = (REPO_ROOT / relative).resolve()
    try:
        target.relative_to(REPO_ROOT)
    except ValueError as exc:
        raise Refusal('repo_path_escape') from exc
    if not target.is_file():
        raise Refusal('bound_file_missing')
    return target


def _primary(value: str) -> str:
    return value.split('||', 1)[0].strip()


def _preset_values(text: str) -> dict[str, str]:
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        if '=' not in line:
            raise Refusal('malformed_governor_preset_line')
        key, value = (part.strip() for part in line.split('=', 1))
        if not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', key) or key in result or not value:
            raise Refusal('duplicate_or_invalid_governor_parameter')
        result[key] = _primary(value)
    return result


def load_binding(path: Path = BINDING) -> tuple[dict, dict, Path, bytes]:
    """Load and verify the exact Standard rulepack, evidence, and governor presets."""

    binding = json.loads(path.read_text(encoding='utf-8'))
    if binding.get('schema') != 'qm.ftmo-m13-standard-demo-binding/v1' or binding.get('status') != 'REVIEW_ONLY':
        raise Refusal('invalid_binding_contract')
    account = binding.get('account', {})
    if account.get('variant') != 'STANDARD_2STEP_100K_FREE_TRIAL' or account.get('login') != 1514536732 or account.get('server') != 'FTMO-Demo' or account.get('observed_leverage') != '1:100':
        raise Refusal('wrong_standard_demo_account')
    terms = _repo_file(account.get('terms_evidence_path', ''))
    if sha(terms.read_bytes()) != account.get('terms_evidence_sha256'):
        raise Refusal('account_terms_evidence_hash_drift')

    contract = binding.get('rulepack', {})
    rulepack_path = _repo_file(contract.get('path', ''))
    rule_bytes = rulepack_path.read_bytes()
    if sha(rule_bytes) != contract.get('file_sha256'):
        raise Refusal('rulepack_file_hash_drift')
    rule = json.loads(rule_bytes)
    canonical = json.dumps(rule, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
    if sha(canonical) != contract.get('canonical_sha256'):
        raise Refusal('rulepack_canonical_hash_drift')
    if (rule.get('rulepack_id'), rule.get('profile_version'), rule.get('as_of')) != (
        contract.get('id'), contract.get('profile_version'), contract.get('as_of')
    ) or rule.get('rulepack_id') != 'FTMO_2S_100K_STANDARD_V2':
        raise Refusal('wrong_rulepack')

    rules = {item['rule_id']: item for item in rule['official_rules']}
    daily = rules['ftmo_2s_max_daily_loss']['parameters']
    total = rules['ftmo_2s_maximum_loss']['parameters']
    news = rules['ftmo_standard_news']['parameters']
    weekend = rules['ftmo_standard_weekend']['parameters']
    limits = binding.get('official_limits', {})
    if daily.get('percent_of_initial_simulated_capital') != limits.get('maximum_daily_loss_percent') or daily.get('timezone') != limits.get('daily_reset_timezone') or total.get('percent_of_initial_simulated_capital') != limits.get('maximum_loss_percent'):
        raise Refusal('rulepack_limits_binding_mismatch')
    if news.get('evaluation_restricted') is not False or news.get('ftmo_account_standard_restricted') is not True or weekend.get('evaluation_restricted') is not False or weekend.get('ftmo_account_standard_restricted') is not True:
        raise Refusal('standard_provider_conditions_invalid')

    overlay = binding.get('qm_demo_overlay', {})
    expected_overlay = {
        'classification': 'INTERNAL_QM_POLICY_NOT_PROVIDER_RULE',
        'news_temporal_mode': 3,
        'news_compliance_profile': 2,
        'news_pause_before_minutes': 30,
        'news_pause_after_minutes': 30,
        'news_stale_max_hours': 336,
        'weekend_flat': True,
        'friday_close_hour_broker': 21,
        'friday_flat_lead_minutes': 5,
        'provider_evaluation_news_restricted': False,
        'provider_evaluation_weekend_restricted': False,
    }
    if overlay != expected_overlay:
        raise Refusal('demo_overlay_binding_mismatch')

    evaluator = binding.get('evaluator', {})
    if evaluator != {
        'module': 'tools/strategy_farm/portfolio/ftmo_book3_standalone_evaluator.py',
        'selection_mode': 'EXPLICIT_M13_DEMO_BINDING',
        'rulepack_path': contract['path'],
        'rulepack_file_sha256': contract['file_sha256'],
        'rulepack_canonical_sha256': contract['canonical_sha256'],
    }:
        raise Refusal('evaluator_binding_mismatch')

    governor = binding.get('governor', {})
    if governor.get('ea_id') != 13206 or governor.get('policy_id') != 'FTMO_2S_P1_100K_V2':
        raise Refusal('wrong_governor_binding')
    expected_preset = {
        'signed_policy_id': governor['policy_id'],
        'qm_news_temporal': str(overlay['news_temporal_mode']),
        'qm_news_compliance': str(overlay['news_compliance_profile']),
        'qm_news_stale_max_hours': str(overlay['news_stale_max_hours']),
        'qm_friday_close_enabled': 'true',
        'qm_friday_close_hour_broker': str(overlay['friday_close_hour_broker']),
        'qm_friday_flat_lead_minutes': str(overlay['friday_flat_lead_minutes']),
        'expected_account_login': str(account['login']),
        'expected_account_server': account['server'],
    }
    for role in ('bootstrap', 'active'):
        preset = _repo_file(governor[f'{role}_preset_path'])
        if sha(preset.read_bytes()) != governor[f'{role}_preset_sha256']:
            raise Refusal(f'{role}_preset_hash_drift')
        actual = _preset_values(decode(preset.read_bytes()))
        if any(actual.get(key) != value for key, value in expected_preset.items()):
            raise Refusal(f'{role}_preset_binding_mismatch')

    authority = binding.get('authority_boundary', {})
    if any(authority.get(key) is not False for key in ('install_authorized', 'attachment_authorized', 'autotrading_authorized', 'purchase_authorized')) or authority.get('owner_signature_required') is not True:
        raise Refusal('authority_boundary_invalid')
    return binding, rule, rulepack_path, rule_bytes


def derive(source: bytes, risk_percent: float) -> tuple[bytes, dict]:
    if not math.isfinite(risk_percent) or not 0 < risk_percent <= 1:
        raise Refusal('risk_percent_outside_dry_run_cap')
    text = decode(source)
    before = values(text)
    if float(before.get('RISK_FIXED', 'nan')) <= 0 or not math.isfinite(float(before.get('RISK_FIXED', 'nan'))) or float(before.get('RISK_PERCENT', 'nan')) != 0:
        raise Refusal('source_not_fixed_risk_backtest')
    stale = float(before.get('qm_news_stale_max_hours', '336'))
    if not math.isfinite(stale) or not 0 < stale <= 336:
        raise Refusal('stale_news_guard_invalid')
    updates = {
        'RISK_FIXED':'0',
        'RISK_PERCENT':format(risk_percent, '.10g'),
        'qm_news_temporal':'3',
        'qm_news_compliance':'2',
        'qm_news_stale_max_hours':format(stale, '.10g'),
        # The OWNER's 2026-09-06 account is Standard, not Swing.  Weekend
        # holding is therefore forbidden and every installed sleeve must use
        # the framework's Friday flattening control.
        'qm_friday_close_enabled':'true',
        'qm_friday_close_hour_broker':'21',
    }
    lines = []
    seen = set()
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith(';'):
            if re.match(r';\s*(environment|risk_mode)\s*:', stripped):
                continue
            lines.append(line)
            continue
        key = stripped.split('=', 1)[0].strip()
        if key in updates:
            lines.append(key + '=' + updates[key]); seen.add(key)
        else:
            lines.append(line)
    lines += [k+'='+v for k,v in updates.items() if k not in seen]
    lines += ['; environment: live', '; risk_mode: PERCENT', '; trial_status: INERT_REVIEW_ONLY; NOT_INSTALLABLE', '; ENV is provenance metadata; these EAs have no ENV input.']
    output = '\n'.join(lines) + '\n'
    proof = verify_derivation(text, output)
    return output.encode(), {'strategy_identity_sha256':proof, 'strategy_parameter_count':len([k for k in before if k not in ALLOWED]), 'changes':{k:{'before':before.get(k), 'after':v} for k,v in updates.items() if before.get(k) != v}}


def sealed_source(conn: sqlite3.Connection, ea: int, symbol: str) -> tuple[bytes, dict]:
    """Legacy hard-bound path: venue name comes from the module-level LANES map."""
    raw, binding = sealed_source_raw(conn, ea, symbol)
    return raw, dict(binding, native_symbol=LANES[symbol])


def sealed_source_raw(conn: sqlite3.Connection, ea: int, symbol: str) -> tuple[bytes, dict]:
    row = conn.execute("SELECT id,setfile_path,evidence_path,setfile_sha256 FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q10_NEWS' AND status='done' AND verdict='CONFIG_LOCKED' ORDER BY updated_at DESC LIMIT 1", (f'QM5_{ea}', symbol+'.DWX')).fetchone()
    if row is None:
        raise Refusal(f'unsealed_source:{ea}:{symbol}')
    task, source_name, seal_name, db_hash = row
    source_path, seal_path = Path(source_name).resolve(), Path(seal_name).resolve()
    seal_bytes = seal_path.read_bytes()
    seal = json.loads(seal_bytes)
    if seal.get('verdict') != 'CONFIG_LOCKED' or seal.get('schema_version') not in ('q09-news-adjudication/v2', 'q09-news-adjudication/v3'):
        raise Refusal('seal_not_locked')
    expected = seal.get('identities', {}).get('baseline_setfile_sha256')
    raw = source_path.read_bytes()
    if not expected or sha(raw) != expected or (db_hash and db_hash != expected):
        raise Refusal('sealed_source_hash_drift')
    timeframe_match = re.search(r'_((?:M|H)\d+|D1|W1|MN1)(?:_|\.)', source_path.name)
    if not timeframe_match:
        raise Refusal('source_timeframe_unresolved')
    return raw, {'ea_id':ea, 'symbol':symbol, 'timeframe':timeframe_match.group(1), 'seal_work_item_id':task, 'source_path':str(source_path), 'source_sha256':expected, 'seal_path':str(seal_path), 'seal_sha256':sha(seal_bytes), 'source_role':'SEALED_BASELINE_STRATEGY_PARAMETERS', 'original_selected_news_config':seal.get('chosen_config'), 'ex5_sha256':seal.get('identities', {}).get('ex5_sha256')}


def output_path(run_name: str) -> Path:
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}', run_name):
        raise Refusal('invalid_run_name')
    root = TRIAL_ROOT.resolve()
    # Refuse junction/symlink redirection out of the literal review tree.
    if str(root).replace('\\','/').casefold() != str(TRIAL_ROOT.absolute()).replace('\\','/').casefold():
        raise Refusal('review_root_redirected')
    target = root / run_name
    if target.exists() or target.resolve().parent != root:
        raise Refusal('output_exists_or_escapes_trial_root')
    return target


def generate(run_name: str, risk_percent: float, *, database: Path = DATABASE, binding_path: Path = BINDING) -> dict:
    target = output_path(run_name)
    binding, rule, rulepack, rule_bytes = load_binding(binding_path)
    rules = {item['rule_id']:item for item in rule['official_rules']}
    daily = float(rules['ftmo_2s_max_daily_loss']['parameters']['percent_of_initial_simulated_capital'])
    total = float(rules['ftmo_2s_maximum_loss']['parameters']['percent_of_initial_simulated_capital'])
    if not 0 < daily <= 5 or not 0 < total <= 10:
        raise Refusal('rulepack_drawdown_limits_invalid')
    planned = []
    with sqlite3.connect(database.resolve().as_uri()+'?mode=ro', uri=True) as conn:
        for ea,symbol in CANDIDATES:
            raw, source_binding = sealed_source(conn, ea, symbol)
            data, proof = derive(raw, risk_percent)
            filename = f'QM5_{ea}_{source_binding["native_symbol"]}_{source_binding["timeframe"]}_live_trial.set'
            planned.append((filename,data,dict(source_binding, **proof, output_path=filename, output_sha256=sha(data))))
    manifest = {'schema':'qm.ftmo-trial-setpath/v3', 'status':'INERT_REVIEW_ONLY', 'installed':False, 'installable':False, 'mode':'DRY_RUN', 'ENV':'live', 'risk_percent':risk_percent, 'risk_authority':'OWNER_RATIFIED_EQUAL_EIGHT_SLEEVE_ALLOCATION', 'account_variant':'STANDARD_2STEP_100K_FREE_TRIAL', 'duration_cap_calendar_days':14, 'binding':{'id':binding['binding_id'],'path':str(binding_path.resolve())}, 'rulepack':{'path':str(rulepack),'sha256':sha(rule_bytes),'canonical_sha256':binding['rulepack']['canonical_sha256'],'id':rule['rulepack_id'],'profile_version':rule['profile_version'],'as_of':rule['as_of']}, 'constraints':{'max_daily_loss_percent':daily,'max_total_loss_percent':total,'timezone':'Europe/Prague','observed_account_leverage':binding['account']['observed_leverage'],'provider_evaluation_news_restricted':False,'provider_evaluation_weekend_restricted':False,'qm_news_blackout':'PRE30_POST30_PLUS_FTMO_COMPLIANCE','qm_weekend_flat':'FRIDAY_CLOSE_21_BROKER_WITH_5_MINUTE_LEAD','calendar_binding':'NATIVE_MT5_CALENDAR_LIVE; seed health and execution must be verified before attachment','governor_enforcement':'BOUND_TO_QM5_13206_PRESETS; ATTACHMENT_REQUIRES_OWNER_SIGNATURE'}, 'candidates':[p[2] for p in planned]}
    # Validate the whole batch before writing any set; no active-set destination option.
    target.mkdir(parents=True)
    for filename,data,_ in planned:
        with (target / filename).open('xb') as handle:
            handle.write(data)
    (target/'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True)+'\n',encoding='utf-8')
    for filename,data,binding in planned:
        if sha((target/filename).read_bytes()) != binding['output_sha256']:
            raise Refusal('output_hash_mismatch')
        verify_derivation(decode(Path(binding['source_path']).read_bytes()),decode(data))
    return dict(manifest, directory=str(target))


# --------------------------------------------------------------------------- #
# Roster-driven derivation (G1/G2). The legacy CANDIDATES/LANES path above is
# unchanged; a roster file replaces those two module constants with an explicit,
# reviewable input so a new cycle never needs a code edit.
# --------------------------------------------------------------------------- #
ROSTER_SCHEMA = 'qm.ftmo-demo-roster/v1'
ROSTER_FIELDS = ('ea_id', 'ea_label', 'dxz_symbol', 'ftmo_symbol', 'timeframe', 'slot', 'magic', 'risk_percent')
# Any set key naming a symbol slot. Multi-symbol EAs carry one input per slot
# (OWNER 2026-09-06); a slot left on a .DWX factory name is dark on a broker chart.
SYMBOL_INPUT_RE = re.compile(r'^strategy_[A-Za-z0-9_]*symbol[A-Za-z0-9_]*$')
FACTORY_SUFFIX = '.DWX'
_TIMEFRAME_RE = re.compile(r'^(?:M|H)\d+$|^D1$|^W1$|^MN1$')


def load_roster(path: Path) -> dict:
    """Load and fully validate a qm.ftmo-demo-roster/v1 file. Fail-closed."""
    roster = json.loads(Path(path).read_text(encoding='utf-8'))
    if not isinstance(roster, dict) or roster.get('schema') != ROSTER_SCHEMA:
        raise Refusal('invalid_roster_schema')
    rows = roster.get('candidates')
    if not isinstance(rows, list) or not rows:
        raise Refusal('empty_roster')
    seen_magic: dict[int, dict] = {}
    seen_slot: set[tuple[int, int]] = set()
    clean = []
    for row in rows:
        if not isinstance(row, dict) or any(field not in row for field in ROSTER_FIELDS):
            raise Refusal('roster_row_incomplete')
        ea_id, slot, magic = row['ea_id'], row['slot'], row['magic']
        if not all(isinstance(v, int) and not isinstance(v, bool) for v in (ea_id, slot, magic)):
            raise Refusal('roster_row_non_integer_identity')
        if ea_id <= 0 or slot < 0 or magic != ea_id * 10000 + slot:
            raise Refusal(f'roster_magic_formula_violation:{ea_id}:{slot}:{magic}')
        if magic in seen_magic:
            raise Refusal(f'roster_magic_collision:{magic}')
        if (ea_id, slot) in seen_slot:
            raise Refusal(f'roster_slot_collision:{ea_id}:{slot}')
        seen_magic[magic] = row
        seen_slot.add((ea_id, slot))
        for field in ('ea_label', 'dxz_symbol', 'ftmo_symbol', 'timeframe'):
            if not isinstance(row[field], str) or not row[field].strip():
                raise Refusal(f'roster_row_blank_field:{field}')
        if row['ftmo_symbol'].upper().endswith(FACTORY_SUFFIX):
            raise Refusal(f'roster_ftmo_symbol_is_factory_name:{row["ftmo_symbol"]}')
        if not _TIMEFRAME_RE.fullmatch(row['timeframe']):
            raise Refusal(f'roster_timeframe_invalid:{row["timeframe"]}')
        risk = row['risk_percent']
        if not isinstance(risk, (int, float)) or isinstance(risk, bool) or not math.isfinite(float(risk)) or not 0 < float(risk) <= 1:
            raise Refusal(f'roster_risk_percent_outside_cap:{risk}')
        clean.append(dict(row, risk_percent=float(risk)))
    return dict(roster, candidates=clean)


def rebind_symbol_inputs(text: str, dxz_symbol: str, ftmo_symbol: str) -> tuple[str, dict]:
    """Rewrite symbol-slot inputs from the .DWX factory name to the venue name.

    Only a slot whose value is this row's own factory symbol is rewritten. Any
    other .DWX-valued symbol slot is refused: its venue name is not knowable from
    this roster row, and leaving it would make that leg silently dark (B1).
    """
    changes: dict[str, dict[str, str]] = {}
    lines = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(';') or '=' not in stripped:
            lines.append(line)
            continue
        key, value = (part.strip() for part in stripped.split('=', 1))
        if not SYMBOL_INPUT_RE.fullmatch(key) or not value.upper().endswith(FACTORY_SUFFIX):
            lines.append(line)
            continue
        base = value[: -len(FACTORY_SUFFIX)]
        if base != dxz_symbol:
            raise Refusal(f'unmapped_symbol_slot_input:{key}={value}')
        lines.append(key + '=' + ftmo_symbol)
        changes[key] = {'before': value, 'after': ftmo_symbol}
    return '\n'.join(lines) + ('\n' if text.endswith('\n') else ''), changes


def derive_for_roster(source: bytes, risk_percent: float, dxz_symbol: str, ftmo_symbol: str) -> tuple[bytes, dict]:
    """derive() plus the venue symbol-slot rebind, with both proofs recorded."""
    derived, proof = derive(source, risk_percent)
    text, symbol_changes = rebind_symbol_inputs(decode(derived), dxz_symbol, ftmo_symbol)
    output = text.encode()
    frozen = set(ALLOWED) | set(symbol_changes)
    before, after = values(decode(derived)), values(text)
    if {k: v for k, v in before.items() if k not in frozen} != {k: v for k, v in after.items() if k not in frozen}:
        raise Refusal('symbol_rebind_changed_strategy_parameters')
    return output, dict(
        proof,
        symbol_slot_changes=symbol_changes,
        venue_symbol=ftmo_symbol,
        factory_symbol=dxz_symbol + FACTORY_SUFFIX,
    )


def generate_from_roster(run_name: str, roster_path: Path, *, database: Path = DATABASE,
                         binding_path: Path = BINDING, trial_root: Path | None = None) -> dict:
    """Derive presets for exactly the roster's candidates and write the v2 manifest."""
    roster = load_roster(roster_path)
    target = output_path(run_name) if trial_root is None else Path(trial_root) / run_name
    if trial_root is not None and target.exists():
        raise Refusal('output_exists_or_escapes_trial_root')
    binding, rule, rulepack, rule_bytes = load_binding(binding_path)
    rules = {item['rule_id']: item for item in rule['official_rules']}
    daily = float(rules['ftmo_2s_max_daily_loss']['parameters']['percent_of_initial_simulated_capital'])
    total = float(rules['ftmo_2s_maximum_loss']['parameters']['percent_of_initial_simulated_capital'])
    if not 0 < daily <= 5 or not 0 < total <= 10:
        raise Refusal('rulepack_drawdown_limits_invalid')
    planned = []
    with sqlite3.connect(database.resolve().as_uri() + '?mode=ro', uri=True) as conn:
        for row in roster['candidates']:
            raw, source_binding = sealed_source_for(conn, row)
            data, proof = derive_for_roster(raw, row['risk_percent'], row['dxz_symbol'], row['ftmo_symbol'])
            observed = values(decode(data))
            if observed.get('qm_ea_id') not in (None, str(row['ea_id'])):
                raise Refusal(f'roster_ea_id_mismatch:{row["ea_id"]}')
            if observed.get('qm_magic_slot_offset') not in (None, str(row['slot'])):
                raise Refusal(f'roster_slot_mismatch:{row["ea_id"]}:{row["slot"]}')
            filename = f'QM5_{row["ea_id"]}_{row["ftmo_symbol"]}_{row["timeframe"]}_live_trial.set'
            planned.append((filename, data, dict(
                source_binding, **proof,
                ea_label=row['ea_label'], slot=row['slot'], magic=row['magic'],
                risk_percent=row['risk_percent'],
                output_path=filename, output_sha256=sha(data),
                qm_ea_id=observed.get('qm_ea_id'),
                qm_magic_slot_offset=observed.get('qm_magic_slot_offset'),
            )))
    risks = sorted({row['risk_percent'] for row in roster['candidates']})
    manifest = {
        'schema': 'qm.ftmo-trial-setpath/v2',
        'status': 'INERT_REVIEW_ONLY', 'installed': False, 'installable': False, 'mode': 'DRY_RUN',
        'ENV': 'live',
        'risk_percent': risks[0] if len(risks) == 1 else risks,
        'book_risk_percent': round(sum(r['risk_percent'] for r in roster['candidates']), 6),
        'risk_authority': roster.get('risk_authority', 'ROSTER_DECLARED_AWAITING_OWNER'),
        'roster_label': roster.get('label', run_name),
        'roster_schema': ROSTER_SCHEMA,
        'roster_source': str(Path(roster_path).resolve()),
        'roster_sha256': sha(Path(roster_path).read_bytes()),
        'account_variant': 'STANDARD_2STEP_100K_FREE_TRIAL',
        'duration_cap_calendar_days': 14,
        'binding': {'id': binding['binding_id'], 'path': str(binding_path.resolve())},
        'rulepack': {'path': str(rulepack), 'sha256': sha(rule_bytes),
                     'canonical_sha256': binding['rulepack']['canonical_sha256'],
                     'id': rule['rulepack_id'], 'profile_version': rule['profile_version'], 'as_of': rule['as_of']},
        'constraints': {
            'max_daily_loss_percent': daily, 'max_total_loss_percent': total, 'timezone': 'Europe/Prague',
            'observed_account_leverage': binding['account']['observed_leverage'],
            'provider_evaluation_news_restricted': False, 'provider_evaluation_weekend_restricted': False,
            'qm_news_blackout': 'PRE30_POST30_PLUS_FTMO_COMPLIANCE',
            'qm_weekend_flat': 'FRIDAY_CLOSE_21_BROKER_WITH_5_MINUTE_LEAD',
            'calendar_binding': 'NATIVE_MT5_CALENDAR_LIVE; seed health and execution must be verified before attachment',
            'governor_enforcement': 'BOUND_TO_QM5_13206_PRESETS; ATTACHMENT_REQUIRES_OWNER_SIGNATURE',
        },
        'candidates': [item[2] for item in planned],
    }
    target.mkdir(parents=True)
    for filename, data, _ in planned:
        with (target / filename).open('xb') as handle:
            handle.write(data)
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    for filename, data, item in planned:
        if sha((target / filename).read_bytes()) != item['output_sha256']:
            raise Refusal('output_hash_mismatch')
    return dict(manifest, directory=str(target))


def sealed_source_for(conn: sqlite3.Connection, row: dict) -> tuple[bytes, dict]:
    """sealed_source() for a roster row: no LANES lookup, timeframe cross-checked."""
    raw, binding = sealed_source_raw(conn, int(row['ea_id']), str(row['dxz_symbol']))
    if binding['timeframe'] != row['timeframe']:
        raise Refusal(f'roster_timeframe_mismatch:{row["ea_id"]}:{binding["timeframe"]}!={row["timeframe"]}')
    return raw, dict(binding, native_symbol=row['ftmo_symbol'])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-name', required=True)
    parser.add_argument('--risk-percent', type=float, help='Legacy hard-bound path: explicit dry-run example; not trading authority')
    parser.add_argument('--roster', help='qm.ftmo-demo-roster/v1 file; risk_percent comes from each row')
    parser.add_argument('--dry-run', action='store_true', required=True)
    args = parser.parse_args()
    if bool(args.roster) == (args.risk_percent is not None):
        parser.error('pass exactly one of --roster or --risk-percent')
    if args.roster:
        result = generate_from_roster(args.run_name, Path(args.roster))
    else:
        result = generate(args.run_name, args.risk_percent)
    print(json.dumps({'directory': result['directory'], 'sets': len(result['candidates']),
                      'schema': result['schema'], 'status': result['status']}))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
