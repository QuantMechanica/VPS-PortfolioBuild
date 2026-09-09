import copy
import pytest
from tools.strategy_farm.portfolio import ftmo_acceleration_plan as p
def intake(n=6):return {'pairs':[{'ea_id':f'QM5_{i}','symbol':'EURUSD.DWX'} for i in range(n)]}
def test_empty_roster_is_valid_and_does_not_select_investigation_list():
    assert p.validate_selection(intake(),{'selected_pairs':[],'investigation_pairs':['QM5_1:EURUSD.DWX']})==[]
def test_pilot_cap_duplicates_and_outside_roster_fail():
    keys=[f'QM5_{i}:EURUSD.DWX' for i in range(6)]
    for rows in (keys,[keys[0],keys[0]],['QM5_100:EURUSD.DWX']):
        with pytest.raises(ValueError):p.validate_selection(intake(),{'selected_pairs':rows})
    with pytest.raises(ValueError):p.validate_selection(intake(),{'selected_pairs':keys[:1]},keys[1:2])
def test_identity_dedup_and_deterministic_request():
    binding={'ea_id':'QM5_1','phase':'Q10_NEWS','target':'FTMO','ex5':'a'*64,'calendar':'b'*64,'windows':'c'*64}
    same=copy.deepcopy(binding)
    assert p.request_id(binding)==p.request_id(same)
    rows=[{'id':'old','binding':same}]
    assert p.exact_existing(rows,binding)==['old']
    for field in ('target','ex5','calendar','windows'):
        changed=dict(binding);changed[field]='changed'
        assert not p.exact_existing(rows,changed)
        assert p.request_id(changed)!=p.request_id(binding)
