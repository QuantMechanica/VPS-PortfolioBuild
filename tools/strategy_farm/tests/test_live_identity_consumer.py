"""Only fixture metadata is consumed; deployed binaries and presets stay unopened."""
from copy import deepcopy
import datetime as dt
import json
from types import SimpleNamespace

import pytest

from tools.strategy_farm import live_identity_attest as attest
from tools.strategy_farm import live_identity_consumer as consumer
from tools.strategy_farm import live_deployment_pointer_auth as auth
from tools.strategy_farm import risk_freeze
from tools.strategy_farm import verify_live_deployment_contract as verifier
from tools.strategy_farm.tests.test_live_identity_attest import book


def raw(value):
    return (json.dumps(value, sort_keys=True, indent=2)+'\n').encode()


def seal(context):
    proposal_sha = attest.raw_sha(context['proposal_raw'])
    receipt = {'schema': consumer.decisions.RECEIPT_SCHEMA,
               'receipt_id': '1b275695-829c-480f-a59b-34b77ea8c244',
               'decided_by': 'OWNER', 'decision': 'YES',
               'decided_at_utc': '2026-09-05T11:01:00+00:00',
               'decision_id': consumer.DECISION_PREFIX + proposal_sha,
               'selected_effect': consumer.attestation_effect(proposal_sha)}
    receipt['receipt_sha256'] = consumer.decisions.sha256_bytes(consumer.decisions.canonical_bytes(receipt))
    context.update(receipt_id=receipt['receipt_id'], receipts=[receipt])


@pytest.fixture
def context(book, tmp_path):
    manifest, pointer, freeze, observation, _, at = deepcopy(book)
    manifest['version'] = 'unchanged-v1'
    files = {'manifest': raw(manifest), 'freeze': raw(freeze), 'source_tool': b'# measured fixture source'}
    pointer['manifest_sha256'] = attest.raw_sha(files['manifest'])
    pointer['manifest_path'] = str(tmp_path/'manifest.json')
    files['pointer'] = raw(pointer)
    bindings = {k: {'path': str(tmp_path/(k+'.json')), 'sha256': attest.raw_sha(v)} for k,v in files.items()}
    observation.update({k+'_sha256': b['sha256'] for k,b in bindings.items()})
    files['observation'] = raw(observation)
    bindings['observation'] = {'path': str(tmp_path/'observation.json'), 'sha256': attest.raw_sha(files['observation'])}
    proposal = attest.evaluate(manifest, pointer, freeze, observation, bindings, at)
    assert proposal['status'] == 'ELIGIBLE_FOR_OWNER_REVIEW', proposal
    result = {'files': files, 'proposal_raw': raw(proposal)}
    seal(result)
    return result


def test_flag_off_does_not_inspect_context_or_change_auth(context):
    class Forbidden(dict):
        def get(self, *args):
            raise AssertionError('disabled path inspected context')
    assert consumer.evaluate(Forbidden())['reason'] == 'IDENTITY_EXCEPTION_DISABLED'
    pointer = json.loads(context['files']['pointer'])
    args = dict(manifest_sha_actual=pointer['manifest_sha256'], manifest_status='LIVE', manifest_book='DXZ_12345678')
    assert auth.authenticate_deploy_stamp(pointer, **args) == auth.authenticate_deploy_stamp(
        pointer, **args, identity_exception_enabled=False, identity_context=Forbidden())


def test_identical_attested_case_recognized_without_mutating_active_freeze(context, monkeypatch):
    before = deepcopy(context)
    result = consumer.evaluate(context, enabled=True)
    assert result['accepted'] and result['condition_1_satisfied']
    assert result['freeze_status'] == 'ACTIVE'
    assert not result['mutation_allowed'] and not result['runtime_pointer_write']
    monkeypatch.setattr(risk_freeze, 'diff_against_baseline', lambda **kw: pytest.fail('deployed tree read'))
    with pytest.raises(risk_freeze.RiskFreezeBlocked) as caught:
        risk_freeze.assert_live_book_mutation_allowed('generate pointer', identity_exception_enabled=True, identity_context=context)
    assert caught.value.result['allowed'] is False
    assert caught.value.result['lift_conditions'][0]['status'] == 'SATISFIED'
    assert risk_freeze.LIFT_CONDITIONS[0]['status'] == 'BLOCKED'
    assert before == context


@pytest.mark.parametrize('role', ['manifest','pointer','freeze','source_tool','observation'])
def test_any_bound_file_byte_drift_refused(context, role):
    context['files'][role] += b' '
    result = consumer.evaluate(context, enabled=True)
    assert not result['accepted'] and 'BYTE_DRIFT' in result['detail']


@pytest.mark.parametrize('change', ['roster','binary','setfile','risk','stale','future','version'])
def test_recomputed_proposal_refuses_bad_observation_or_version(context, change):
    proposal = json.loads(context['proposal_raw'])
    observation = json.loads(context['files']['observation'])
    sleeve = observation['measurement']['sleeves'][0]
    if change == 'roster': sleeve['timeframe'] = 'M5'
    if change == 'binary': sleeve['binary_sha256'] = 'b'*64
    if change == 'setfile': sleeve['preset_sha256'] = 'c'*64
    if change == 'risk': sleeve['RISK_PERCENT'] = 0.6
    if change == 'stale': observation['captured_at_utc'] = '2026-09-05T10:54:59+00:00'
    if change == 'future': observation['captured_at_utc'] = '2026-09-05T11:00:01+00:00'
    if change == 'version': observation['schema'] = 'qm.live-identity-observation/v2'
    context['files']['observation'] = raw(observation)
    proposal['bindings']['observation']['sha256'] = attest.raw_sha(context['files']['observation'])
    context['proposal_raw'] = raw(proposal)
    seal(context)  # Even an exact matching receipt cannot bypass revalidation.
    assert not consumer.evaluate(context, enabled=True)['accepted']


def test_manifest_version_change_after_attestation_refused(context):
    manifest = json.loads(context['files']['manifest'])
    manifest['version'] = 'new-v2'
    context['files']['manifest'] = raw(manifest)
    assert not consumer.evaluate(context, enabled=True)['accepted']


@pytest.mark.parametrize('age,accepted', [(300,True),(301,False)])
def test_freshness_boundary_is_at_proposal_time(context, age, accepted):
    proposal = json.loads(context['proposal_raw'])
    files = context['files']
    observation = json.loads(files['observation'])
    created = attest.utc(proposal['created_at_utc'])
    observation['captured_at_utc'] = (created-dt.timedelta(seconds=age)).isoformat()
    files['observation'] = raw(observation)
    proposal['bindings']['observation']['sha256'] = attest.raw_sha(files['observation'])
    result = attest.evaluate(*[json.loads(files[k]) for k in ['manifest','pointer','freeze','observation']],
                             proposal['bindings'],created)
    context['proposal_raw'] = raw(result)
    seal(context)
    assert consumer.evaluate(context, enabled=True)['accepted'] is accepted


@pytest.mark.parametrize('case', ['missing','duplicate','other_hash','policy_yes','not_owner','no','checksum','before_proposal'])
def test_receipt_authority_negatives(context, case):
    receipt = context['receipts'][0]
    if case == 'missing': context['receipts'] = []
    if case == 'duplicate': context['receipts'].append(deepcopy(receipt))
    if case == 'other_hash': receipt['selected_effect'] = consumer.attestation_effect('d'*64)
    if case == 'policy_yes': receipt['decision_id'] = 'OWNER-DEC-LIVE-IDENTITY-ATTEST-20260905'
    if case == 'not_owner': receipt['decided_by'] = 'CEO'
    if case == 'no': receipt['decision'] = 'NO'
    if case == 'before_proposal': receipt['decided_at_utc'] = '2026-09-05T10:59:00+00:00'
    receipt.pop('receipt_sha256')
    receipt['receipt_sha256'] = consumer.decisions.sha256_bytes(consumer.decisions.canonical_bytes(receipt))
    if case == 'checksum': receipt['receipt_sha256'] = 'f'*64
    assert not consumer.evaluate(context, enabled=True)['accepted']


def test_pointer_consumer_binds_actual_inputs_and_default_off(context):
    pointer = json.loads(context['files']['pointer'])
    args = dict(manifest_sha_actual=pointer['manifest_sha256'], manifest_status='LIVE', manifest_book='DXZ_12345678')
    assert not auth.authenticate_deploy_stamp(pointer, **args).clean
    assert auth.authenticate_deploy_stamp(pointer, **args, identity_exception_enabled=True, identity_context=context).clean
    pointer['expected_server'] = 'different'
    assert auth.authenticate_deploy_stamp(pointer, **args, identity_exception_enabled=True, identity_context=context).has_conflict


def test_metadata_loader_cli_and_verifier_hook_never_read_deployed_paths(context, tmp_path, monkeypatch, capsys):
    proposal = json.loads(context['proposal_raw'])
    for role, data in context['files'].items():
        (tmp_path/(role+'.json')).write_bytes(data)
    proposal_path = tmp_path/'proposal.json'
    proposal_path.write_bytes(context['proposal_raw'])
    ledger = tmp_path/'receipts.jsonl'
    ledger.write_bytes(raw(context['receipts'][0]).replace(b'\n',b'')+b'\n')
    monkeypatch.setattr(consumer.decisions, 'DEFAULT_RECEIPTS', ledger)
    for constant, role in [('POINTER','pointer'),('STATE','freeze'),('SOURCE_TOOL','source_tool')]:
        monkeypatch.setattr(attest, constant, tmp_path/(role+'.json'))
    monkeypatch.setattr(risk_freeze, 'measure', lambda *a,**kw: pytest.fail('T_Live access'))
    original = {p:p.read_bytes() for p in tmp_path.glob('*.json*')}
    loaded = consumer.load_context(proposal_path, context['receipt_id'])
    assert consumer.evaluate(loaded, enabled=True)['accepted']
    assert consumer.main(['--allow-attested-current-identity','--identity-proposal',str(proposal_path),
                          '--identity-attestation-receipt-id',context['receipt_id']]) == 0
    args = SimpleNamespace(pointer=str(tmp_path/'pointer.json'), manifest=str(tmp_path/'manifest.json'),
                           allow_attested_current_identity=True, identity_proposal=str(proposal_path),
                           identity_attestation_receipt_id=context['receipt_id'])
    manifest = SimpleNamespace(file_sha256=proposal['bindings']['manifest']['sha256'], declared_status='LIVE', book='DXZ_12345678')
    # Module import styles can differ; bind the already tested loader explicitly.
    monkeypatch.setattr(verifier.pointer_auth, 'authenticate_deploy_stamp', auth.authenticate_deploy_stamp)
    assert verifier._resolve_pointer_binding(args, manifest)['auth_status'] == 'VERIFIED'
    assert original == {p:p.read_bytes() for p in original}
