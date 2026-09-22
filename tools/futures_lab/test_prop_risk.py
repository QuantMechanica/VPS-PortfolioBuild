import unittest
from dataclasses import replace
from decimal import Decimal as D

from prop_risk import (
    Point,
    Rules,
    contracts_for_risk,
    evaluate,
    payout_diagnostic,
    winning_day_diagnostic,
)


class PropRiskTests(unittest.TestCase):
    def point(self, hour, balance, equity=None, close=False, traded=True, session='2026-09-01'):
        equity=balance if equity is None else equity
        return Point(f'{session}T{hour}:00:00+00:00',session,D(str(balance)),D(str(equity)),close,traded,balance==equity)

    def test_intraday_trail_fails_where_eod_trail_survives(self):
        points=[self.point('14',50000,51000),self.point('15',50000,48500),self.point('16',50000,close=True)]
        self.assertTrue(evaluate(points,Rules())['sampled_path_survived'])
        result=evaluate(points,replace(Rules(),trailing_mode='intraday_equity'))
        self.assertEqual(result['breach']['floor'],'49000')
        self.assertEqual(result['evaluation_status'],'FAILED')

    def test_exact_floor_hit_is_sticky_after_recovery(self):
        result=evaluate([self.point('14',50000,48000),self.point('16',54000,close=True)],Rules())
        self.assertFalse(result['sampled_path_survived'])
        self.assertIsNone(result['first_evaluation_conditions_met_at'])

    def test_eod_floor_carries_into_next_session_and_caps(self):
        points=[self.point('16',54000,close=True),self.point('14',54000,49999,session='2026-09-02'),self.point('16',54000,close=True,session='2026-09-02')]
        result=evaluate(points,Rules())
        self.assertEqual(result['trace'][0]['floor'],'50000')
        self.assertEqual(result['breach']['index'],1)

    def test_consistency_and_real_trading_days(self):
        points=[self.point('16',50800+i*800,close=True,session=f'2026-09-0{i+1}') for i in range(4)]
        self.assertEqual(evaluate(points,Rules())['evaluation_status'],'CONDITIONS_MET')
        points[-1]=replace(points[-1],traded=False)
        self.assertIsNone(evaluate(points,Rules())['first_evaluation_conditions_met_at'])

    def test_big_day_cannot_pass_consistency(self):
        points=[self.point('16',52800,close=True)]
        points += [self.point('16',52800+i*100,close=True,session=f'2026-09-0{i+1}') for i in range(1,4)]
        self.assertIsNone(evaluate(points,Rules())['first_evaluation_conditions_met_at'])

    def test_missing_close_and_naive_time_rejected(self):
        with self.assertRaises(ValueError):
            evaluate([self.point('14',50000),self.point('16',50500,close=True,session='2026-09-02')],Rules())
        with self.assertRaises(ValueError):
            evaluate([replace(self.point('16',50000,close=True),timestamp='2026-09-01T16:00:00')],Rules())

    def test_flat_or_unsorted_or_nonfinite_input_rejected(self):
        with self.assertRaises(ValueError):
            evaluate([replace(self.point('16',50000,49000,close=True),flat=True)],Rules())
        with self.assertRaises(ValueError):
            evaluate([self.point('15',50000),self.point('14',50000,close=True)],Rules())
        with self.assertRaises(ValueError):
            evaluate([replace(self.point('16',50000,close=True),equity=D('NaN'))],Rules())

    def test_payout_is_cashflow_and_never_resets_floor(self):
        r=payout_diagnostic(53200,50000,1000,'0.9',250,2000)
        self.assertEqual(r['room_after_payout'],'2200')
        self.assertEqual(r['net_cash_after_entered_fees_before_tax'],'650.0')
        self.assertTrue(r['survives_unchanged_floor_and_requested_buffer'])
        self.assertFalse(payout_diagnostic(53200,50000,3200,1,0,0)['survives_unchanged_floor_and_requested_buffer'])

    def test_tradeify_first_request_floor_lock_is_not_hidden(self):
        result=payout_diagnostic(50750,48750,375,'0.9',165,275,post_payout_floor=50100)
        self.assertEqual(result['cash_to_trader_before_tax'],'337.5')
        self.assertEqual(result['net_cash_after_entered_fees_before_tax'],'172.5')
        self.assertEqual(result['room_after_payout'],'275')
        self.assertTrue(result['floor_changed_by_payout_rule'])
        self.assertTrue(result['survives_effective_floor_and_requested_buffer'])
        self.assertIsNone(result['survives_unchanged_floor_and_requested_buffer'])
        self.assertFalse(payout_diagnostic(50750,48750,375,'0.9',165,276,post_payout_floor=50100)['survives_effective_floor_and_requested_buffer'])

    def test_payout_rule_cannot_reduce_an_existing_floor(self):
        with self.assertRaises(ValueError):
            payout_diagnostic(52600,50100,500,'0.9',125,2000,post_payout_floor=50000)

    def test_mffu_conservative_cashflow_does_not_claim_eligibility(self):
        result=payout_diagnostic(52600,50100,500,'0.9',125,2000)
        self.assertEqual(result['room_after_payout'],'2000')
        self.assertEqual(result['net_cash_after_entered_fees_before_tax'],'325.0')
        self.assertEqual(result['provider_payout_eligibility'],'NOT_EVALUATED')

    def test_source_bound_consistency_boundaries(self):
        mffu_rules=replace(Rules(),minimum_trading_days=4,best_day_fraction=D('0.30'))
        balances=(50900,51600,52300,53000)
        points=[self.point('16',balance,close=True,session=f'2026-09-0{index}')
                for index,balance in enumerate(balances,start=1)]
        self.assertEqual(evaluate(points,mffu_rules)['evaluation_status'],'CONDITIONS_MET')
        points[0]=self.point('16','50900.01',close=True,session='2026-09-01')
        self.assertEqual(evaluate(points,mffu_rules)['evaluation_status'],'TARGET_OR_DAYS_OR_CONSISTENCY_UNMET')

        tradeify_rules=replace(Rules(),minimum_trading_days=3,best_day_fraction=D('0.40'))
        points=[self.point('16',51200,close=True,session='2026-09-01'),
                self.point('16',52100,close=True,session='2026-09-02'),
                self.point('16',53000,close=True,session='2026-09-03')]
        self.assertEqual(evaluate(points,tradeify_rules)['evaluation_status'],'CONDITIONS_MET')

    def test_tradeify_winning_day_threshold_is_inclusive_and_session_bounded(self):
        result=winning_day_diagnostic([150,'149.99',151,200,150,150],5,150)
        self.assertTrue(result['conditions_met'])
        self.assertEqual(result['qualifying_session_indexes'],[0,2,3,4,5])
        result=winning_day_diagnostic([150,'149.99',151,200,150],5,150)
        self.assertFalse(result['conditions_met'])
        self.assertEqual(result['remaining_winning_days'],1)
        self.assertEqual(result['provider_payout_eligibility'],'NOT_EVALUATED')
        with self.assertRaises(ValueError):
            winning_day_diagnostic('150,150,150,150,150',5,150)

    def test_micro_contract_sizing_counts_costs_and_can_skip(self):
        self.assertEqual(contracts_for_risk(10,10,'1.25','2.50'),0)
        self.assertEqual(contracts_for_risk(100,20,'1.25','2.50',2),3)

    def test_truthy_values_cannot_inflate_trading_days(self):
        for field in ('end_of_session','traded','flat'):
            for value in (1,4,'false',None):
                with self.subTest(field=field,value=value),self.assertRaises(ValueError):
                    replace(self.point('16',53000,close=True),**{field:value})


if __name__=='__main__':
    unittest.main()
