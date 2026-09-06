"""Strict, explicit card declaration for the n=1 DSR special case."""
import hashlib
import json
from pathlib import Path
import re

SCHEMA = 'qm.dsr-single-configuration-cohort/v1'
DECLARATION = 'qm.dsr-single-configuration-declaration/v1'


def require(condition, reason):
    if not condition: raise ValueError(reason)


def pairs(items):
    result = {}
    for key, value in items:
        require(key not in result, 'DUPLICATE_DECLARATION_KEY')
        result[key] = value
    return result


def read_binding(binding):
    require(isinstance(binding, dict) and set(binding) == {'path', 'sha256'}, 'SINGLE_CONFIG_BINDING_REQUIRED')
    path = Path(binding['path'])
    require(path.is_absolute() and path.is_file(), 'SINGLE_CONFIG_FILE_UNAVAILABLE')
    raw = path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == binding['sha256'], 'SINGLE_CONFIG_HASH_MISMATCH')
    return raw


def declaration(card):
    text = card.decode('utf-8-sig')
    front = re.match(r'\A---\s*\n(.*?)\n---', text, re.S)
    require(front is not None and re.findall(r'^g0_status:\s*(.*?)\s*$', front[1], re.M) == ['APPROVED'],
            'APPROVED_CARD_REQUIRED')
    blocks = re.findall(r'^```qm-dsr-single-configuration\s*\n(.*?)^```\s*$', text, re.M | re.S)
    require(len(blocks) == 1, 'EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED')
    value = json.loads(blocks[0], object_pairs_hook=pairs)
    require(isinstance(value, dict) and set(value) == {'schema', 'ea_id', 'symbol', 'timeframe', 'complete',
            'no_optimization_search', 'research_trial_count', 'spec_sha256', 'locked_parameters'}, 'SINGLE_CONFIGURATION_DECLARATION_FIELDS')
    require(isinstance(value, dict) and value.get('schema') == DECLARATION and value.get('complete') is True
            and value.get('no_optimization_search') is True, 'SINGLE_CONFIGURATION_SEARCH_NOT_COMPLETE')
    require(type(value.get('research_trial_count')) is int and value['research_trial_count'] == 0,
            'DOCUMENTED_RESEARCH_TRIAL_LEDGER_REQUIRED')
    return value


def parameters(raw):
    text = raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith((';', '#')): continue
        key, separator, value = line.partition('=')
        require(bool(separator) and key.strip() not in result, 'INVALID_OR_DUPLICATE_SET_PARAMETER')
        # Optimizer metadata is not a locked baseline declaration.
        require('||' not in value, 'OPTIMIZER_SET_NOT_SINGLE_CONFIGURATION')
        result[key.strip()] = value.strip()
    require(bool(result), 'EMPTY_LOCKED_PARAMETER_SET')
    return result


def source_parameters(raw):
    """Return literal defaults for every directly declared EA input.

    MT5 set files commonly omit inputs that retain their compiled defaults.  A
    complete configuration lock therefore consists of these source defaults
    overlaid by every explicit set-file assignment.  The source bytes are also
    hash-bound, so an omitted default cannot change without invalidating the
    cohort.
    """
    text = raw.decode('utf-8-sig')
    result = {}
    pattern = re.compile(
        r'^\s*input\s+(?!group\b)\w+\s+(\w+)\s*=\s*(.*?)\s*;\s*(?://.*)?$',
        re.M,
    )
    for key, value in pattern.findall(text):
        require(key not in result, 'DUPLICATE_SOURCE_INPUT')
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        result[key] = value
    require(bool(result), 'SOURCE_INPUTS_UNAVAILABLE')
    return result


def effective_parameters(source_raw, setfile_raw):
    result = source_parameters(source_raw)
    result.update(parameters(setfile_raw))
    return result


def validate(provenance, candidate, expected):
    require(isinstance(provenance, dict) and set(provenance) == {'card', 'spec', 'mq5', 'ex5', 'setfile'}, 'SINGLE_CONFIG_PROVENANCE_REQUIRED')
    raw = {role: read_binding(binding) for role, binding in provenance.items()}
    decl = declaration(raw['card'])
    require({key: decl.get(key) for key in ('ea_id', 'symbol', 'timeframe')} == candidate,
            'SINGLE_CONFIG_CANDIDATE_MISMATCH')
    require(decl.get('spec_sha256') == provenance['spec']['sha256'], 'SINGLE_CONFIG_SPEC_MISMATCH')
    require(isinstance(decl.get('locked_parameters'), dict)
            and all(isinstance(v, str) for v in decl['locked_parameters'].values())
            and decl['locked_parameters'] == effective_parameters(raw['mq5'], raw['setfile']),
            'LOCKED_PARAMETER_DRIFT')
    require(isinstance(expected, dict) and set(expected) == {'mq5_sha256', 'ex5_sha256', 'setfile_sha256'}, 'COMPLETE_BUILD_IDENTITY_REQUIRED')
    for role in ('mq5', 'ex5', 'setfile'):
        require(expected[role+'_sha256'] == provenance[role]['sha256'], 'BUILD_IDENTITY_MISMATCH:'+role)
    return decl


def canonical_ea_id(value):
    """Identity-format normalization (2026-09-06): the Q08 aggregator receives ``--ea-id 11167`` (int, farmctl
    strips the ``QM5_`` prefix) while the sealed candidate carries the work-item label ``QM5_11167``. Both name the
    same EA; compare the numeric core so equivalent spellings match and different EAs still fail closed."""
    text = str(value).strip().upper()
    if text.startswith('QM5_'):
        text = text[4:]
    return text.split('_', 1)[0]


def validate_context(context, *, ea_id, symbol):
    require(context.get('schema') == SCHEMA and context.get('sealed') is True
            and context.get('complete') is True and context.get('losers_included') is True,
            'UNSEALED_SINGLE_CONFIG_CONTEXT')
    candidate = context.get('candidate')
    require(isinstance(candidate, dict) and canonical_ea_id(candidate.get('ea_id')) == canonical_ea_id(ea_id)
            and candidate.get('symbol') == symbol, 'SINGLE_CONFIG_CANDIDATE_MISMATCH')
    require(all(type(context.get(k)) is int for k in ('declared_trial_count','effective_trial_count','research_trial_count','selection_trial_count'))
            and context.get('selection_mode') == 'DECLARED_SINGLE_CONFIGURATION' and context.get('cohort_std_daily') == 0
            and context.get('selection_trial_count') == 1 and context.get('declared_trial_count') == 1 and context.get('effective_trial_count') == 1
            and context.get('research_trial_count') == 0 and context.get('losers') == [], 'SINGLE_CONFIG_TRIAL_COUNT_MISMATCH')
    history = context.get('search_history')
    require(isinstance(history, dict)
            and set(history) == {'complete', 'unit', 'annual_measurements_are_trials', 'factory_search_ledger'}
            and history.get('complete') is True
            and history.get('unit') == 'candidate_configuration'
            and history.get('annual_measurements_are_trials') is False,
            'SINGLE_CONFIG_SEARCH_HISTORY_REQUIRED')
    search = history.get('factory_search_ledger')
    require(isinstance(search, dict)
            and search.get('schema') == 'qm.factory-search-before-q08-claim/v1'
            and search.get('complete') is True
            and search.get('optimization_rows') == []
            and search.get('q08_work_item_id')
            and search.get('q08_claimed_at_utc'),
            'FACTORY_SEARCH_LEDGER_REQUIRED')
    require(context.get('frequency') == 'CALENDAR_DAY' and context.get('costs_attested') is True, 'SINGLE_CONFIG_COSTS_REQUIRED')
    validate(context.get('provenance'), candidate, context.get('build_identity'))
