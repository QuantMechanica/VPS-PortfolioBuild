"""Safety-boundary tests use temporary fixture bytes, never the live terminal."""
from copy import deepcopy
import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm import live_identity_attest as attest
from tools.strategy_farm import generate_live_deployment_pointer as generator
from tools.strategy_farm.tests.test_risk_freeze_prevention import _preset_tree, _freeze_state


@pytest.fixture
def book(tmp_path):
    presets = _preset_tree(tmp_path / 'presets')
    freeze = json.loads(_freeze_state(tmp_path / 'freeze.json', presets).read_text())
    sleeve = freeze['baseline']['sleeves'][0]
    manifest = {'status': 'LIVE', 'book': 'DXZ_12345678', 'sleeves': [{
        'ea_id': 100, 'symbol': 'EURUSD.DWX', 'magic_number': 1000000,
        'deployed_preset': str(presets / sleeve['preset']), 'ex5_path': sleeve['binary_path'],
        'set_file_expectation': {'RISK_PERCENT': 0.5, 'RISK_FIXED': 0.0, 'PORTFOLIO_WEIGHT': 1.0},
    }]}
    binding = {k: {'sha256': attest.digest(k)} for k in ['manifest', 'pointer', 'freeze', 'source_tool']}
    pointer = {'schema_version': generator.SCHEMA_VERSION, 'manifest_sha256': binding['manifest']['sha256'],
               'expected_account': '12345678', 'expected_server': 'fixture', 'expected_phase': 'DXZ_LIVE',
               'expected_sleeves': generator.compute_expected_sleeves(manifest),
               'binary_setfile_fingerprint': generator.compute_binary_setfile_fingerprint(manifest, tmp_path)}
    at = dt.datetime(2026, 9, 5, 11, tzinfo=dt.timezone.utc)
    observation = {'schema': attest.OBSERVATION_SCHEMA, 'source_tool': 'risk_freeze.measure',
                   'captured_at_utc': at.isoformat(), 'measurement': deepcopy(freeze['baseline']),
                   **{k + '_sha256': v['sha256'] for k, v in binding.items()}}
    return manifest, pointer, freeze, observation, binding, at


def test_identical_fixture_is_only_unsigned_proposal_and_does_not_mutate(book):
    original = deepcopy(book)
    result = attest.evaluate(*book)
    assert result['status'] == 'ELIGIBLE_FOR_OWNER_REVIEW'
    assert result['transition'].startswith('ACTIVE/')
    assert not any(result[k] for k in ['signed', 'runtime_pointer_write', 'freeze_mutation', 'activation_authorized'])
    assert book == original


@pytest.mark.parametrize('field,value,reason', [
    ('preset_sha256', 'a' * 64, 'SETFILE'), ('binary_sha256', 'b' * 64, 'BINARY'),
    ('RISK_PERCENT', 0.6, 'RISK'), ('RISK_FIXED', 1, 'RISK'),
    ('PORTFOLIO_WEIGHT', 2, 'RISK'), ('qm_magic_slot_offset', 1, 'ROSTER'),
    ('symbol', 'GBPUSD', 'ROSTER'), ('timeframe', 'M5', 'ROSTER'),
    ('ea_id', 101, 'ROSTER'), ('preset', 'other.set', 'ROSTER'),
])
def test_any_observed_identity_drift_refuses(book, field, value, reason):
    book[3]['measurement']['sleeves'][0][field] = value
    result = attest.evaluate(*book)
    assert result['status'] == 'REFUSED'
    assert any(reason in failure for failure in result['failures'])
    assert book[2]['status'] == 'ACTIVE'


@pytest.mark.parametrize('role', ['manifest', 'pointer', 'freeze', 'source_tool'])
def test_each_input_hash_binding_is_mandatory(book, role):
    book[3][role + '_sha256'] = 'c' * 64
    assert attest.evaluate(*book)['status'] == 'REFUSED'


@pytest.mark.parametrize('seconds', [-1, 301])
def test_observation_cannot_be_future_or_stale(book, seconds):
    book[3]['captured_at_utc'] = (book[-1] - dt.timedelta(seconds=seconds)).isoformat()
    assert 'OBSERVATION_STALE_OR_FUTURE' in attest.evaluate(*book)['failures']


@pytest.mark.parametrize('case', ['missing', 'inactive', 'binary_envelope', 'roster_hash', 'account', 'invalid_risk'])
def test_bad_metadata_fails_closed(book, case):
    args = list(book)
    if case == 'missing': args[3] = None
    if case == 'inactive': args[2]['status'] = 'LIFTED'
    if case == 'binary_envelope': args[1]['binary_setfile_fingerprint']['fingerprint_sha256'] = 'd' * 64
    if case == 'roster_hash': args[1]['expected_sleeves']['identity_sha256'] = 'e' * 64
    if case == 'account': args[1]['expected_account'] = '99999999'
    if case == 'invalid_risk': args[3]['measurement']['sleeves'][0]['RISK_PERCENT'] = 'NaN'
    assert attest.evaluate(*args)['status'] == 'REFUSED'


def test_dispatch_never_calls_legacy_builder_or_writer(book, tmp_path, monkeypatch, capsys):
    paths = []
    for label, data in zip(['manifest', 'pointer', 'freeze'], book[:3]):
        path = tmp_path / (label + '.json')
        path.write_text(json.dumps(data))
        paths.append(path)
    source = tmp_path / 'source.py'
    source.write_text('# fixture source')
    monkeypatch.setattr(attest, 'SOURCE_TOOL', source)
    monkeypatch.setattr(attest, 'EVIDENCE', tmp_path / 'evidence')
    def forbidden(*a, **kw): raise AssertionError('legacy live-book path called')
    monkeypatch.setattr(generator, 'build_pointer', forbidden)
    monkeypatch.setattr(generator, '_atomic_write_json', forbidden)
    original = [path.read_bytes() for path in paths]
    argv = ['--attest-current', '--manifest', str(paths[0]), '--current-pointer', str(paths[1]), '--freeze-state', str(paths[2])]
    assert generator.main(argv) == 2
    assert not (tmp_path / 'evidence').exists()
    target = tmp_path / 'evidence' / 'proposal'
    assert generator.main(argv + ['--write-proposal', '--proposal-dir', str(target)]) == 2
    assert set(p.name for p in target.iterdir()) == {'proposal.json', 'receipt.json'}
    assert json.loads((target / 'receipt.json').read_text())['proposal_sha256'] == attest.raw_sha((target / 'proposal.json').read_bytes())
    assert [path.read_bytes() for path in paths] == original
    assert json.loads(paths[2].read_text())['status'] == 'ACTIVE'
    with pytest.raises(ValueError, match='NEW canonical evidence child'):
        generator.main(argv + ['--write-proposal', '--proposal-dir', str(target)])


@pytest.mark.parametrize('flag', ['--signed', '--out', '--deployment-epoch-utc'])
def test_legacy_activation_arguments_refused(flag):
    with pytest.raises(SystemExit):
        generator.main(['--attest-current', '--manifest', 'fixture.json', flag])


def test_t_live_and_alias_paths_refused(tmp_path):
    with pytest.raises(ValueError, match='T_Live'):
        attest.safe_path(tmp_path / 'T_Live' / 'anything.json')
    target = tmp_path / 'target'
    target.mkdir()
    alias = tmp_path / 'alias'
    try: alias.symlink_to(target, target_is_directory=True)
    except OSError: pytest.skip('symlink privilege unavailable')
    with pytest.raises(ValueError, match='reparse/symlink'):
        attest.safe_path(alias / 'proposal.json')
