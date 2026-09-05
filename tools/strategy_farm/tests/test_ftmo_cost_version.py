import copy
import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import ftmo_cost_version as costs
from tools.strategy_farm.portfolio import ftmo_timebox_eval, build_book_ftmo
from tools.strategy_farm import ftmo_lane_runner

PACK = Path(__file__).resolve().parents[3] / 'docs/ops/evidence/2026-09-05_m08_ftmo_cost_pack/cost_version.json'


def test_all_three_consumers_read_identical_pinned_fields(capsys):
    digest = hashlib.sha256(PACK.read_bytes()).hexdigest()
    arguments = ['inspect-cost-version', '--cost-version', str(PACK), '--expected-sha256', digest]
    outputs = []
    for main, argv in [(ftmo_timebox_eval.main, arguments), (ftmo_lane_runner.main, arguments),
                       (build_book_ftmo.main, ['--inspect-cost-version', str(PACK), '--expected-cost-version-sha256', digest])]:
        assert main(argv) == 0
        outputs.append(json.loads(capsys.readouterr().out))
    assert len({o['consumer'] for o in outputs}) == 3
    for field in ('symbols','coverage','open_items','version_id','cost_version_sha256'):
        assert outputs[0][field] == outputs[1][field] == outputs[2][field]
    assert all(o['governed_adoption'] is False for o in outputs)
    # The review reader cannot adopt this new file into either governed pin.
    assert digest not in {build_book_ftmo.EXPECTED_COST_SNAPSHOT_SHA256, ftmo_lane_runner.EXPECTED_COST_SNAPSHOT_SHA256}


def test_hash_drift_refused_before_fields_used(tmp_path):
    p=tmp_path/'pack.json';p.write_bytes(PACK.read_bytes()+b' ')
    with pytest.raises(costs.CostVersionError,match='hash mismatch'):
        costs.load(p,hashlib.sha256(PACK.read_bytes()).hexdigest())


@pytest.mark.parametrize('defect', ['adoption','duplicate_symbol','unknown_value','missing_provenance','boolean_cost'])
def test_provenance_and_no_adoption_fail_closed(tmp_path,defect):
    value=json.loads(PACK.read_text())
    if defect=='adoption':value['governed_adoption']=True
    elif defect=='duplicate_symbol':value['symbols'][1]=copy.deepcopy(value['symbols'][0])
    elif defect=='unknown_value':value['symbols'][0]['fields']['lot_step']['value']=.01
    elif defect=='missing_provenance':del value['symbols'][0]['fields']['commission']['provenance']
    else:value['symbols'][0]['fields']['commission']['value']=True
    raw=json.dumps(value).encode();p=tmp_path/'bad.json';p.write_bytes(raw)
    with pytest.raises(costs.CostVersionError):costs.load(p,hashlib.sha256(raw).hexdigest())


def test_missing_overlap_and_lot_specs_are_not_filled_in():
    value=costs.load(PACK,hashlib.sha256(PACK.read_bytes()).hexdigest())
    assert set(value['coverage']['matched_venue_minutes'].values()) == {0}
    for symbol in value['symbols']:
        assert symbol['coverage']['matched_spread_delta'] is None
        for key in ('lot_min','lot_step','fill_slippage','triple_rollover_weekday'):
            assert symbol['fields'][key]['value'] is None
            assert symbol['fields'][key]['provenance'] == 'unknown'
