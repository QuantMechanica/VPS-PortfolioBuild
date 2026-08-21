//+------------------------------------------------------------------+
//| QM_pattern_permission_fixture_runner.mq5                          |
//|                                                                    |
//| Executes the hand-built predicate fixtures against the REAL        |
//| QM_PP_Evaluate and writes a verdict CSV.                           |
//|                                                                    |
//| Why an EA and not a script: the fixture suite has to run through   |
//| the sanctioned ad-hoc tester harness on a free terminal (starting  |
//| terminal64 by hand is forbidden). All work happens in OnInit, so   |
//| the run costs one bar of tester time and touches no market data.   |
//|                                                                    |
//| Nothing here re-implements a predicate. The fixtures are DATA; the |
//| logic under test is the include's own. A second implementation     |
//| would only ever test itself.                                       |
//|                                                                    |
//| I/O uses FILE_COMMON so the bundle is read from, and the verdicts  |
//| written to, the shared Common\Files folder rather than a per-agent |
//| tester sandbox that would be discarded after the run.              |
//+------------------------------------------------------------------+
#property strict
#property version   "1.0"
#property description "QM pattern-permission predicate fixture runner (test harness, never traded)"

#include <QM/QM_PatternPermission.mqh>

input string qm_fixture_input  = "QM\\pattern_fixtures.csv";
input string qm_fixture_output = "QM\\pattern_fixture_results.csv";

//--- One fixture's worth of parsed state.
struct QM_FixtureCase
  {
   string            fixture_id;
   string            predicate;
   int               predicate_id;
   string            case_class;
   bool              expected;
   QM_PPBars         bars;
  };

//+------------------------------------------------------------------+
//| Split a CSV line. Fixture data is machine-generated and contains  |
//| no quoted fields, so a plain split is sufficient and auditable.   |
//+------------------------------------------------------------------+
int QM_FR_Split(const string line, string &out[])
  {
   return StringSplit(line, (ushort)',', out);
  }

//+------------------------------------------------------------------+
//| Flush one accumulated fixture to the results file.                |
//+------------------------------------------------------------------+
void QM_FR_Emit(const int out_handle, QM_FixtureCase &fx,
                int &pass_count, int &fail_count, int &short_count)
  {
   if(fx.fixture_id == "")
      return;

   // A window shorter than the predicate needs would make QM_PP_Evaluate
   // return false for the WINDOW, not for the pattern -- a pass for the wrong
   // reason. The bundler already rejects this; the runner refuses it too, so
   // a hand-edited CSV cannot smuggle one in.
   const int need = QM_PP_RequiredBars((QM_PatternId)fx.predicate_id);
   if(fx.bars.count < need)
     {
      short_count++;
      FileWrite(out_handle, fx.fixture_id, fx.predicate, fx.case_class,
                (fx.expected ? "1" : "0"), "NA", "SHORT_WINDOW",
                IntegerToString(fx.bars.count), IntegerToString(need));
      fx.fixture_id = "";
      return;
     }

   const bool actual = QM_PP_Evaluate((QM_PatternId)fx.predicate_id, fx.bars);
   const bool ok = (actual == fx.expected);
   if(ok)
      pass_count++;
   else
      fail_count++;

   FileWrite(out_handle, fx.fixture_id, fx.predicate, fx.case_class,
             (fx.expected ? "1" : "0"), (actual ? "1" : "0"),
             (ok ? "PASS" : "FAIL"),
             IntegerToString(fx.bars.count), IntegerToString(need));
   fx.fixture_id = "";
  }

int OnInit()
  {
   const int in_handle = FileOpen(qm_fixture_input,
                                  FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(in_handle == INVALID_HANDLE)
     {
      PrintFormat("QM_FIXTURE_RUNNER fixture bundle not readable: %s (err=%d)",
                  qm_fixture_input, GetLastError());
      return INIT_FAILED;
     }

   const int out_handle = FileOpen(qm_fixture_output,
                                   FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(out_handle == INVALID_HANDLE)
     {
      PrintFormat("QM_FIXTURE_RUNNER cannot write results: %s (err=%d)",
                  qm_fixture_output, GetLastError());
      FileClose(in_handle);
      return INIT_FAILED;
     }

   FileWrite(out_handle, "fixture_id", "predicate", "case",
             "expected", "actual", "verdict", "bars_supplied", "bars_required");

   QM_FixtureCase current;
   current.fixture_id = "";
   current.bars.count = 0;

   int pass_count = 0, fail_count = 0, short_count = 0, malformed = 0, line_no = 0;
   string cols[];

   while(!FileIsEnding(in_handle))
     {
      const string line = FileReadString(in_handle);
      line_no++;
      if(line == "" || StringFind(line, "fixture_id,") == 0)
         continue;   // blank or header

      const int n = QM_FR_Split(line, cols);
      if(n < 12)
        {
         malformed++;
         PrintFormat("QM_FIXTURE_RUNNER malformed line %d (%d cols)", line_no, n);
         continue;
        }

      const string fid = cols[0];
      if(fid != current.fixture_id)
        {
         QM_FR_Emit(out_handle, current, pass_count, fail_count, short_count);
         current.fixture_id = fid;
         current.predicate = cols[1];
         current.predicate_id = (int)StringToInteger(cols[2]);
         current.case_class = cols[3];
         current.expected = (cols[4] == "1");
         current.bars.count = 0;
        }

      const int idx = (int)StringToInteger(cols[5]);
      if(idx < 0 || idx >= QM_PP_MAX_LOOKBACK)
        {
         malformed++;
         PrintFormat("QM_FIXTURE_RUNNER bar index %d out of range at line %d",
                     idx, line_no);
         continue;
        }

      current.bars.time[idx]        = (datetime)StringToInteger(cols[6]);
      current.bars.open[idx]        = StringToDouble(cols[7]);
      current.bars.high[idx]        = StringToDouble(cols[8]);
      current.bars.low[idx]         = StringToDouble(cols[9]);
      current.bars.close[idx]       = StringToDouble(cols[10]);
      current.bars.tick_volume[idx] = StringToInteger(cols[11]);
      if(idx + 1 > current.bars.count)
         current.bars.count = idx + 1;
     }

   QM_FR_Emit(out_handle, current, pass_count, fail_count, short_count);

   FileClose(in_handle);
   FileClose(out_handle);

   // Bug #4 evidence probe: exercise the public history-loading path with the
   // deepest predicate in the 77-predicate bank. The fixture assertions above
   // remain pure-data tests; this extra call exists only to make the first bar
   // at which the fail-closed history gate becomes tradable visible in the
   // sanctioned tester evidence. It never places or modifies an order.
   QM_PatternProfile warmup_profile;
   QM_PP_ProfileInit(warmup_profile, "BUG4_MAX_DEPTH", PERIOD_D1, 1);
   const bool warmup_added =
      QM_PP_ProfileAddBuy(warmup_profile, QM_PP_VOL_PERCENTILE_HIGH);
   const QM_PermissionResult warmup_result =
      QM_PatternPermissionEvaluate(_Symbol, PERIOD_D1, 1, warmup_profile);
   PrintFormat("QM_PATTERN_WARMUP_PROBE added=%s valid=%s required_bars=%d reference_bar_time=%I64d reason=%s",
               (string)warmup_added,
               (string)warmup_result.valid,
               QM_PP_ProfileRequiredBars(warmup_profile),
               (long)warmup_result.reference_bar_time,
               warmup_result.reason);

   PrintFormat("QM_FIXTURE_RUNNER done pass=%d fail=%d short=%d malformed=%d out=%s",
               pass_count, fail_count, short_count, malformed, qm_fixture_output);

   // All the work is done. We still return INIT_SUCCEEDED and let the tester
   // finish normally: aborting from OnInit makes run_smoke.ps1 see a failed
   // run with no report, which is indistinguishable from a real failure. Run
   // this over a two-day window with Model 4 and the "backtest" costs seconds.
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   // Intentionally empty: this harness never trades. Fixture evaluation is
   // finished before the first tick arrives.
  }

double OnTester()
  {
   return 0.0;
  }
