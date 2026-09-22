"""Synthetic parser tests, never calendar evidence for market decisions."""
import copy,json,unittest
from datetime import datetime,timedelta,timezone
from zoneinfo import ZoneInfo
from parse_ff_calendar import parse_month

def fixture():
    tz=ZoneInfo('Europe/Berlin')
    days=[{'dateline':int(datetime(2019,6,1,tzinfo=tz).timestamp())+i*86400,'events':[]} for i in range(30)]
    days[3]['events']=[{'id':1,'name':'Synthetic USD release','currency':'USD','impactName':'high',
        'timeMasked':False,'dateline':int(datetime(2019,6,4,13,55,tzinfo=timezone.utc).timestamp()),
        'private_extra':'PRIVATE_SENTINEL'}]
    settings={'begin_date':'June 1, 2019','end_date':'June 30, 2019',
        'currencies':[1,2],'impacts':[3,2,1,0],'event_types':[1,2],'private_extra':'PRIVATE_SENTINEL'}
    values={'currencies':{'1':'USD','2':'EUR'},'impacts':{'3':'high','2':'medium','1':'low','0':'non-economic'},'event_types':{'1':'a','2':'b'}}
    return days,settings,values

def encode(parts,second=None):
    def component(p):
        days,settings,values=p
        return 'window.calendarComponentStates[1] = {\n days: '+json.dumps(days)+',\n settings: '+json.dumps(settings)+',\n settingValues: Object.freeze('+json.dumps(values)+')};\n'
    return ("<script>var private_profile='PRIVATE_SENTINEL';var x={'timezone':'Europe/Berlin'};\n"+component(parts)+(component(second) if second else '')+'</script>').encode()

class MonthTests(unittest.TestCase):
    def test_chrome_declared_windows1252_is_strictly_decoded(self):
        raw=b'<meta charset="windows-1252"><meta charset="utf-8">\xab'+encode(fixture())
        self.assertEqual(parse_month(raw)['source_encoding'],'windows-1252')
        with self.assertRaises(UnicodeDecodeError):parse_month(b'<meta charset="utf-8">\xab'+encode(fixture()))

    def test_complete_month_epochs_empty_days_and_privacy(self):
        result=parse_month(encode(fixture()))
        self.assertEqual(len(result['covered_session_dates']),20)
        self.assertEqual(result['calendar_validation']['june_day_count'],30)
        self.assertTrue(result['days'][0]['empty_day_explicit'])
        self.assertEqual(result['events'][0]['timestamp_utc'],'2019-06-04T13:55:00Z')
        self.assertTrue(result['session_exclusion']['2019-06-04']['excluded'])
        self.assertFalse(result['session_exclusion']['2019-06-06']['excluded'])
        self.assertNotIn('PRIVATE_SENTINEL',json.dumps(result))

    def test_reject_filtered(self):
        p=fixture(); p[1]['impacts']=[3]
        with self.assertRaisesRegex(ValueError,'Filtered'):parse_month(encode(p))

    def test_wrong_month_and_missing_day_fail(self):
        p=fixture(); p[1]['end_date']='June 29, 2019'
        with self.assertRaisesRegex(ValueError,'exact June'):parse_month(encode(p))
        p=fixture(); p[0].pop()
        with self.assertRaisesRegex(ValueError,'30..35'):parse_month(encode(p))
        p=fixture(); p[0][29]['dateline']+=86400
        with self.assertRaisesRegex(ValueError,'Missing, repeated'):parse_month(encode(p))

    def test_untimed_high_excludes_session_without_fabricating_time(self):
        p=fixture(); p[0][3]['events'][0]['timeMasked']=True
        p[0][3]['events'][0]['currency']='All'
        result=parse_month(encode(p))
        self.assertEqual(result['missing_raw_calendar_dates'],[])
        self.assertEqual(result['timing_unresolved_session_dates'],['2019-06-04'])
        self.assertNotIn('2019-06-04',result['covered_session_dates'])
        self.assertIsNone(result['untimed_high_impact_events'][0]['timestamp_utc'])
        self.assertEqual(result['session_exclusion']['2019-06-04']['reason'],'UNTIMED_HIGH_ALL_EVENT')

    def test_exact_epoch_day_checked(self):
        p=fixture(); p[0][3]['events'][0]['dateline']+=86400
        with self.assertRaisesRegex(ValueError,'outside'):parse_month(encode(p))

    def test_duplicates_and_disagreement_fail(self):
        p=fixture(); other=copy.deepcopy(p)
        self.assertEqual(parse_month(encode(p,other))['calendar_validation']['repeated_component_count'],2)
        other[0][3]['events'][0]['name']='Different'
        with self.assertRaisesRegex(ValueError,'disagree'):parse_month(encode(p,other))
        p=fixture(); p[0][3]['events']*=2
        with self.assertRaisesRegex(ValueError,'repeated event'):parse_month(encode(p))

    def test_max35_days_and_challenge_fail(self):
        p=fixture()
        for i in range(6):p[0].append({'dateline':p[0][-1]['dateline']+86400,'events':[]})
        with self.assertRaisesRegex(ValueError,'30..35'):parse_month(encode(p))
        with self.assertRaisesRegex(ValueError,'component'):parse_month(b'<html>Access denied</html>')

if __name__=='__main__':unittest.main(verbosity=2)
