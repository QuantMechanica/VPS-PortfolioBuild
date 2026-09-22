import unittest
import tempfile
from pathlib import Path
from dataclasses import replace
from prop_risk import Point, Rules, evaluate, timestamp_ns, read_points

class EventOrderTests(unittest.TestCase):
    def points(self):
        return [Point('2026-09-16T14:00:00.123456789Z','s',50000,51000,False,True,False,0),
                Point('2026-09-16T14:00:00.123456789Z','s',50000,48000,False,False,False,1),
                Point('2026-09-16T20:00:00Z','s',50000,50000,True,False,True,2)]

    def test_equal_time_breach_survives_recovery_in_bounded_stream(self):
        result=evaluate(iter(self.points()),Rules(),retain_trace=False)
        self.assertEqual(result['evaluation_status'],'FAILED')
        self.assertEqual(result['breach']['replay_ordinal'],1)
        self.assertEqual(result['point_count'],3)
        self.assertEqual(result['trace'],[])

    def test_nanoseconds_are_not_rounded_into_equal_times(self):
        p=self.points()
        p=[replace(x,replay_ordinal=None) for x in p]
        p[1]=replace(p[1],timestamp='2026-09-16T14:00:00.123456790Z')
        self.assertEqual(evaluate(p,Rules())['point_count'],3)
        self.assertEqual(timestamp_ns(p[1].timestamp)-timestamp_ns(p[0].timestamp),1)

    def test_lossy_unordered_equal_time_and_regression_rejected(self):
        for p in [[replace(x,replay_ordinal=None) for x in self.points()],
                  [self.points()[0],replace(self.points()[1],replay_ordinal=0),self.points()[2]],
                  [self.points()[0],replace(self.points()[1],replay_ordinal=None),self.points()[2]],
                  [self.points()[0],replace(self.points()[1],timestamp='2026-09-16T13:59:59Z'),self.points()[2]]]:
            with self.assertRaises(ValueError):evaluate(p,Rules())

    def test_empty_generator_and_invalid_ordinal_rejected(self):
        with self.assertRaises(ValueError):evaluate(iter(()),Rules())
        for ordinal in [True,-1,1.5]:
            with self.assertRaises(ValueError):replace(self.points()[0],replay_ordinal=ordinal)

    def test_timezone_equivalence_and_precision_limit(self):
        self.assertEqual(timestamp_ns('2026-09-16T10:00:00.123456789-04:00'),timestamp_ns('2026-09-16T14:00:00.123456789Z'))
        with self.assertRaises(ValueError):timestamp_ns('2026-09-16T14:00:00.1234567899Z')

    def test_csv_preserves_nanoseconds_and_optional_event_ordinals(self):
        with tempfile.TemporaryDirectory(prefix='qm-risk-csv-test-') as folder:
            path=Path(folder)/'marks.csv'
            path.write_text('timestamp,session,balance,equity,end_of_session,traded,flat,replay_ordinal\n'
                            '2026-09-16T14:00:00.123456789Z,s,50000,48000,false,true,false,0\n'
                            '2026-09-16T14:00:00.123456789Z,s,50000,50000,true,false,true,1\n')
            result=evaluate(read_points(path),Rules(),retain_trace=False)
            self.assertEqual(result['evaluation_status'],'FAILED')
            self.assertEqual(result['breach']['replay_ordinal'],0)

if __name__ == '__main__':unittest.main()
