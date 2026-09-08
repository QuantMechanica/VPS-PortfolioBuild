import hashlib
import json
from pathlib import Path
from unittest.mock import patch

import pytest

from tools.strategy_farm import legacy_logger_policy as policy
from tools.strategy_farm import q09_news_runner as runner


@pytest.fixture
def bound(tmp_path, monkeypatch):
    # Runner supports script-style and package-style imports; bind the same
    # isolated policy module in both modes, never the live runtime receipt.
    monkeypatch.setattr(runner, 'legacy_logger_policy', policy)
    binary = b'archived pre-control binary'
    digest = hashlib.sha256(binary).hexdigest()
    receipt = {'receipt_id': 'fixture', 'decision_id': policy.DECISION_ID,
               'decision': 'YES', 'decided_by': 'OWNER', 'execution_authorized': True}
    receipt['receipt_sha256'] = hashlib.sha256((json.dumps(
        receipt, sort_keys=True, separators=(',', ':'), ensure_ascii=True) + '\n').encode()).hexdigest()
    receipts = tmp_path / 'receipts.jsonl'
    receipts.write_text(json.dumps(receipt) + '\n')
    entry = {'ea_id': 11167, 'ea_label': 'QM5_11167_weiss-ichi2-ma',
             'ex5_sha256': digest, 'enabled': True, 'git_commit': 'a' * 40}
    config = tmp_path / 'policy.json'
    config.write_text(json.dumps({'schema': 'qm.legacy-logger-allowlist/v1',
                                  'binaries': [entry], 'owner_receipt': {
                                      k: receipt[k] for k in ('receipt_id', 'receipt_sha256')}}))
    monkeypatch.setattr(policy, 'POLICY_PATH', config)
    monkeypatch.setattr(policy, 'RECEIPTS_PATH', receipts)
    setfile = tmp_path / 'inputs.set'
    setfile.write_text('qm_magic_slot_offset=2\n')

    def git(*args):
        if args[0] == 'merge-base':
            return b''
        if '--format=%cI' in args:
            return b'2026-07-14T23:08:03+02:00\n'
        if args[-1].endswith('.ex5'):
            return binary
        return (b'ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n'
                b'11167,weiss-ichi2-ma,2,XAUUSD.DWX,111670002,2026-06-07,Development,active\n')
    monkeypatch.setattr(policy, '_git', git)
    return dict(ea_id=11167, ex5_sha256=digest, symbol='XAUUSD.DWX',
                setfile=setfile, fresh_required=True, phase='Q10_NEWS',
                dispatch_version='q09_news_executor_v1', subgate='0123456789abcdef_selection',
                contract_version='q09-news-evidence/v3')


def test_archived_exact_binary_and_receipt_bind_magic(bound):
    result = policy.resolve_authorization(**bound)
    assert result['expected_magic'] == 111670002
    assert result['logger_sample_authentication'] == 'legacy_no_sv'
    assert 'sv' not in result


@pytest.mark.parametrize('field,value', [
    ('fresh_required', False), ('phase', 'Q02'), ('dispatch_version', 'smoke'),
    ('subgate', '0123456789abcdef_full'), ('subgate', 'selection'),
    ('contract_version', 'q09-news-evidence/v2'),
    ('ex5_sha256', 'f' * 64), ('ea_id', 11196),
])
def test_wrong_scope_or_unknown_binary_has_no_exception(bound, field, value):
    assert policy.resolve_authorization(**{**bound, field: value}) is None


def test_holdout_carries_same_bounded_authorization(bound):
    result = policy.resolve_authorization(**{**bound, 'subgate': '0123456789abcdef_holdout'})
    assert result['fresh_required'] is True


@pytest.mark.parametrize('kind', ['hash', 'date', 'ancestry'])
def test_false_build_proof_fails_closed(bound, kind):
    original = policy._git

    def bad(*args):
        if kind == 'hash' and args[-1].endswith('.ex5'):
            return b'other bytes with arbitrarily old filesystem mtime'
        if kind == 'date' and '--format=%cI' in args:
            return b'2026-07-20T00:00:00+00:00'
        if kind == 'ancestry' and args[0] == 'merge-base':
            raise policy.LegacyLoggerError('not ancestor')
        return original(*args)
    with patch.object(policy, '_git', side_effect=bad), pytest.raises(policy.LegacyLoggerError):
        policy.resolve_authorization(**bound)


def test_tampered_owner_receipt_fails(bound):
    receipt = json.loads(policy.RECEIPTS_PATH.read_text())
    receipt['decision'] = 'NO'
    policy.RECEIPTS_PATH.write_text(json.dumps(receipt) + '\n')
    with pytest.raises(policy.LegacyLoggerError, match='receipt binding'):
        policy.resolve_authorization(**bound)


def test_disabled_registration_stays_closed(bound):
    config = json.loads(policy.POLICY_PATH.read_text())
    config['binaries'][0]['enabled'] = False
    policy.POLICY_PATH.write_text(json.dumps(config))
    assert policy.resolve_authorization(**bound) is None


def test_missing_owner_receipt_stays_closed(bound):
    policy.RECEIPTS_PATH.write_text('')
    with pytest.raises(policy.LegacyLoggerError, match='receipt missing'):
        policy.resolve_authorization(**bound)


@pytest.mark.parametrize('text', ['', 'qm_magic_slot_offset=1\n',
                                'qm_magic_slot_offset=2\nqm_magic_slot_offset=2\n'])
def test_missing_wrong_or_duplicate_magic_slot_fails(bound, text):
    bound['setfile'].write_text(text)
    with pytest.raises(policy.LegacyLoggerError):
        policy.resolve_authorization(**bound)


@pytest.fixture
def legacy_stream(bound, tmp_path):
    authorization = policy.resolve_authorization(**bound)
    archive = tmp_path / 'archive.json'
    archive.write_text(json.dumps({'ea_id': 11167}))
    logger = tmp_path / 'logger.jsonl'
    row = dict(ts_utc='2020-01-01T00:00:00Z', ts_broker='2020-01-01T02:00:00',
               level='INFO', ea_id=11167, slug='ea-11167', symbol='XAUUSD.DWX',
               tf='D1', magic=111670002, event='ENTRY_ACCEPTED', payload={})
    logger.write_text(json.dumps(row) + '\n')
    summary = {'logger_sample_authentication': 'legacy_no_sv', 'logger_sample': {
        'logger_sample_authentication': 'legacy_no_sv',
        'capture_mode': 'fresh_required', 'source_offset_start': 0,
        'legacy_authorization': authorization, 'pre_run_archive_manifest_path': str(archive),
        'pre_run_archive_manifest_sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}}
    kwargs = dict(logger_path=logger, ea_id=11167, symbol='XAUUSD.DWX', period='D1',
                  spec={'run_identity_sha256': '0123456789abcdef' * 4,
                        'setfile_path': str(bound['setfile'])},
                  input_manifest={'contract_version': 'q09-news-evidence/v3',
                                  'identities': {'ex5_sha256': bound['ex5_sha256']}})
    return summary, kwargs


def test_consumer_authenticates_declared_residual(legacy_stream):
    summary, kwargs = legacy_stream
    assert runner._validate_legacy_logger_evidence(summary, **kwargs)['expected_magic'] == 111670002


@pytest.mark.parametrize('field,value', [('magic', 111960002), ('ea_id', 11196),
                                       ('symbol', 'EURUSD.DWX'), ('tf', 'H4'),
                                       ('sv', 1), ('event', '')])
def test_consumer_rejects_wrong_identity_or_mixed_schema(legacy_stream, field, value):
    summary, kwargs = legacy_stream
    row = json.loads(kwargs['logger_path'].read_text())
    row[field] = value
    kwargs['logger_path'].write_text(json.dumps(row) + '\n')
    with pytest.raises(runner.RunnerError):
        runner._validate_legacy_logger_evidence(summary, **kwargs)


@pytest.mark.parametrize('field,value', [('capture_mode', 'delta'), ('source_offset_start', 3),
                                       ('pre_run_archive_manifest_sha256', 'f' * 64),
                                       ('legacy_authorization', {}),
                                       ('logger_sample_authentication', 'schema_v1')])
def test_consumer_rejects_unfresh_unbound_undeclared(legacy_stream, field, value):
    summary, kwargs = legacy_stream
    summary['logger_sample'][field] = value
    with pytest.raises(runner.RunnerError):
        runner._validate_legacy_logger_evidence(summary, **kwargs)


@pytest.mark.parametrize('marker', ['LEGACY_LOGGER_AUTHENTICATION_REFUSED',
                                   'Required fresh structured logger sample was not authenticated'])
def test_deterministic_refusal_is_not_a_transient_retry(tmp_path, marker):
    from types import SimpleNamespace
    spec = {'receipt_path': str(tmp_path / 'cell_receipt.json'),
            'run_identity_sha256': 'a' * 64, 'setfile_path': str(tmp_path / 'inputs.set')}
    context = {
        'ea_id': 11167, 'input_manifest': {
            'contract_version': 'q09-news-evidence/v3',
            'windows': {f'{window}_{edge}_utc': date
                        for window in ('selection', 'holdout', 'full')
                        for edge, date in [('from', '2019-01-01T00:00:00Z'),
                                           ('to', '2023-12-31T23:59:59Z')]}},
        'farm_root': str(tmp_path), 'work_item_id': 'canary', 'terminal': 'T1',
        'plan_path': str(tmp_path / 'plan.json'), 'expected_plan_file_sha256': 'a' * 64,
        'run_smoke_path': 'run_smoke.ps1', 'expert': 'QM\\QM5_11167_weiss-ichi2-ma',
        'symbol': 'XAUUSD.DWX', 'period': 'D1', 'cell_timeout_sec': 60,
        'expected_expert_sha256': 'b' * 64, 'terminal_root': str(tmp_path),
        'repo_root': str(tmp_path)}
    with (patch.object(runner, '_validate_cell_setfile', return_value=100),
          patch.object(runner, 'assert_factory_capacity'),
          patch.object(runner, '_wait_for_claimed_terminal_exit'),
          patch.object(runner.subprocess, 'run', return_value=SimpleNamespace(
              returncode=1, stdout='', stderr=marker)) as child):
        with pytest.raises(runner.RunnerError) as error:
            runner._production_dispatch_cell(spec, context)
        assert not isinstance(error.value, runner.TransientCellError)
        assert child.call_count == 1
