#property strict
#property version "1.00"
#property description "SYNTHETIC VISUAL QA ONLY. No tick handler or trading functions."

#include <QM/QM_ChartScheme.mqh>
#ifdef QM_CONSOLE_DESIGN_COMPARE
#include <QM/QM_ChartPanelCompare.mqh>
#include "QM_ChartPresentationV2_selftests.mqh"
#else
#ifdef QM_CONSOLE_DESIGN_V2
#include <QM/QM_StrategyConsoleV2.mqh>
#else
#include <QM/QM_ChartPanel.mqh>
#endif
#endif
#include "QM_ConsoleData_selftests.mqh"
#ifdef QM_CONSOLE_NEWS_SELFTEST
#include "QM11421_ConsoleNews_helpers.mqh"
#include "QM11421_ConsoleNews_selftests.mqh"
#endif

// Never attach to a production chart. This harness verifies renderer behavior
// using explicit synthetic snapshots on the launcher's one empty demo chart.
#ifdef QM_CONSOLE_DESIGN_COMPARE
CQMChartPanelCompare g_renderer;
#else
#ifdef QM_CONSOLE_DESIGN_V2
CQMStrategyConsoleV2 g_renderer;
#else
CQMStrategyConsole g_renderer;
#endif
#endif
int g_case=0;
int g_scale=100;
int g_serial=-1;
int g_capture_pending=-1;
QM_ConsoleMode g_mode=QM_CONSOLE_FULL;
QM_ConsoleMode g_display_mode=QM_CONSOLE_FULL;
string g_prefix="QM_QA_";
string g_init_token="";
datetime g_fixture_bar=0;

// Explicit quoting is required: fixture text contains decimal commas and
// tooltips may contain quotes or newlines. FileWriteString avoids assuming
// native FILE_CSV implements RFC-style field escaping.
bool WriteCsvRow(const int file,const string &values[])
  {
   string line="";
   for(int i=0;i<ArraySize(values);++i)
     {
      string value=values[i]; StringReplace(value,"\"","\"\"");
      if(i>0) line+=",";
      line+="\""+value+"\"";
     }
   return FileWriteString(file,line+"\r\n")>0;
  }

bool InitializeRenderer()
  {
   g_display_mode=g_mode;
#ifdef QM_CONSOLE_DESIGN_COMPARE
   return g_renderer.InitializePresentation(ChartID(),g_prefix,true,g_mode,g_scale,
      true,true,true,true,QM_DESIGN_2,true);
#else
#ifdef QM_CONSOLE_DESIGN_V2
   // V2 owns the dashboard only. ChartPresentationV2 is integrated separately.
   return g_renderer.Initialize(ChartID(),g_prefix,true,g_mode,g_scale,false,false,false,false);
#else
   return g_renderer.Initialize(ChartID(),g_prefix,true,g_mode,g_scale,true,true,true,true);
#endif
#endif
  }

void RenderFixture(const QM_ConsoleSnapshot &snapshot)
  {
#ifdef QM_CONSOLE_DESIGN_COMPARE
   g_renderer.Refresh(snapshot);
#else
   g_renderer.Render(snapshot);
#endif
  }

void PresentationEvent(const int id,const string name)
  {
#ifndef QM_CONSOLE_DESIGN_COMPARE
   if(!g_renderer.Ready()) return;
#endif
   // Compare owns an explicit recovery control even while Ready()==false.
   // Do not swallow those clicks in the harness before its adapter sees them.
   if(g_renderer.Ready() && id==CHARTEVENT_OBJECT_CLICK && name==g_prefix+"view")
      g_display_mode=QM_ConsoleNextMode(g_display_mode);
   g_renderer.OnChartEvent(id,name);
#ifdef QM_CONSOLE_DESIGN_COMPARE
   g_display_mode=g_renderer.Mode();
#endif
  }

#ifdef QM_CONSOLE_DESIGN_COMPARE
int CompareFixtureObjects(const long chart,const string prefix)
  {
   int count=0;
   for(int i=ObjectsTotal(chart)-1;i>=0;--i)
     {
      const string name=ObjectName(chart,i);
      if(StringFind(name,prefix)==0 || StringFind(name,"QM_CHART_V2_"+prefix)==0 ||
         StringFind(name,"QM_RETRY_"+prefix)==0) ++count;
     }
   return count;
  }

bool CompareStartFailureSelfTest(const long chart,string &detail)
  {
   // Natural production guard, no test hook: V1 accepts this 30-character
   // namespace; ChartV2 rejects its 42-character derived namespace (>35).
   // This proves failed-start rollback, NOT a forced chart-Restore failure.
   const string prefix="QM_QA_FAIL_"+StringSubstr(g_init_token,(int)MathMax(0,StringLen(g_init_token)-19));
   detail="";
   if(chart!=ChartID() || StringLen(prefix)!=30 || StringLen("QM_CHART_V2_"+prefix)<=35 ||
      CompareFixtureObjects(chart,prefix)!=0)
     { detail="Chart/prefix guard failed or temporary namespace already occupied"; return false; }
   CQMChartPanelCompare probe;
   const bool initialized=probe.InitializePresentation(chart,prefix,true,QM_CONSOLE_COMPACT,100,
      false,false,false,false,QM_DESIGN_1,true);
   bool before_ok=false,removed=false,rollback_ok=false;
   int before_objects=0,after_objects=0;
   string bid_before="",time_before="",bid_after="",time_after="";
   if(initialized)
     {
      QM_ConsoleSnapshot snapshot; snapshot.Reset();
      snapshot.strategy_name="Native rollback fixture"; snapshot.symbol=_Symbol;
      snapshot.timeframe="D1"; snapshot.environment="DESIGN QA"; snapshot.version="5.0 QA";
      snapshot.state=QM_CONSOLE_WAITING_SETUP;
      snapshot.reason="Rollback cached snapshot"; snapshot.next_event="Await explicit event";
      snapshot.today="0 closed | USD 0,00"; snapshot.week=snapshot.today;
      // One real adapter refresh creates the cache and observes one quote.
      // Nothing refreshes between this observation and the failed A/B attempt.
      probe.Refresh(snapshot);
      bid_before=probe.ObservedBidText(); time_before=probe.QuoteObservedAt();
      before_objects=CompareFixtureObjects(chart,prefix);
      before_ok=probe.Ready() && probe.Design()==QM_DESIGN_1 && probe.Mode()==QM_CONSOLE_COMPACT &&
         bid_before!="" && time_before!="" && before_objects>0 &&
         ObjectGetString(chart,prefix+"state_reason",OBJPROP_TEXT)==snapshot.reason &&
         ObjectGetString(chart,prefix+"design_version",OBJPROP_TEXT)=="01";
      // Deleting one owned label makes redraw observable. A swallowed/no-op
      // click cannot pass simply because Ready/Design/Mode stayed unchanged.
      removed=ObjectDelete(chart,prefix+"state_reason") && ObjectFind(chart,prefix+"state_reason")<0;
      probe.OnChartEvent(CHARTEVENT_OBJECT_CLICK,prefix+"design_version");
      bid_after=probe.ObservedBidText(); time_after=probe.QuoteObservedAt();
      after_objects=CompareFixtureObjects(chart,prefix);
      rollback_ok=probe.Ready() && probe.Design()==QM_DESIGN_1 && probe.Mode()==QM_CONSOLE_COMPACT &&
         bid_after==bid_before && time_after==time_before && after_objects==before_objects &&
         ObjectFind(chart,prefix+"bg")>=0 && ObjectFind(chart,prefix+"state_reason")>=0 &&
         ObjectGetString(chart,prefix+"state_reason",OBJPROP_TEXT)==snapshot.reason &&
         ObjectGetString(chart,prefix+"state_next",OBJPROP_TEXT)==snapshot.next_event &&
         ObjectGetString(chart,prefix+"design_version",OBJPROP_TEXT)=="01" &&
         ObjectFind(chart,"QM_RETRY_"+prefix)<0;
     }
   // Always close the local adapter, including a partially failed Initialize.
   probe.Shutdown();
   const int remaining=CompareFixtureObjects(chart,prefix);
   const bool cleanup_ok=!probe.Ready() && remaining==0;
   detail=StringFormat("prefix=%s; derived_v2_length=%d; initialized=%d; before=%d; deleted_label=%d; rollback=%d; cleanup=%d; objects=%d/%d/%d; bid=%s/%s; quote=%s/%s; restore_failure_injected=0",
      prefix,StringLen("QM_CHART_V2_"+prefix),(int)initialized,(int)before_ok,(int)removed,(int)rollback_ok,
      (int)cleanup_ok,before_objects,after_objects,remaining,bid_before,bid_after,time_before,time_after);
   return initialized && before_ok && removed && rollback_ok && cleanup_ok;
  }

bool CompareRenderFailureSelfTest(const long chart,string &detail)
  {
   const string prefix="QM_RF_"+StringSubstr(g_init_token,(int)MathMax(0,StringLen(g_init_token)-12));
   const string collision="QM_CHART_V2_"+prefix+"identity";
   detail="";
   if(chart!=ChartID() || StringLen(prefix)!=18 || StringLen("QM_CHART_V2_"+prefix)>35 ||
      CompareFixtureObjects(chart,prefix)!=0)
     { detail="Chart/prefix guard failed or temporary namespace already occupied"; return false; }
   CQMChartPanelCompare probe;
   const bool initialized=probe.InitializePresentation(chart,prefix,true,QM_CONSOLE_COMPACT,100,
      false,false,false,false,QM_DESIGN_2,true);
   bool created=false,injected=false,rejected=false,removed=false,recovered=false;
   string bid_before="",time_before="",bid_after="",time_after="";
   if(initialized)
     {
      // The presenter has not rendered yet. This label belongs only to this
      // harness, not its private object registry: adoption must be rejected.
      created=ObjectFind(chart,collision)<0 && ObjectCreate(chart,collision,OBJ_LABEL,0,0,0);
      injected=created && ObjectSetString(chart,collision,OBJPROP_TEXT,"QA collision sentinel");
      QM_ConsoleSnapshot snapshot; snapshot.Reset();
      snapshot.strategy_name="Native render recovery"; snapshot.symbol=_Symbol;
      snapshot.timeframe="D1"; snapshot.environment="DESIGN QA"; snapshot.version="5.0 QA";
      snapshot.state=QM_CONSOLE_WAITING_SETUP;
      snapshot.reason="Cached render recovery"; snapshot.next_event="Await explicit event";
      snapshot.today="0 closed | USD 0,00"; snapshot.week=snapshot.today;
      if(injected)
        {
         probe.Refresh(snapshot);
         bid_before=probe.ObservedBidText(); time_before=probe.QuoteObservedAt();
         rejected=!probe.Ready() && probe.Design()==QM_DESIGN_2 && probe.Mode()==QM_CONSOLE_COMPACT &&
            bid_before!="" && time_before!="" && ObjectFind(chart,"QM_RETRY_"+prefix)>=0 &&
            ObjectFind(chart,collision)>=0 && ObjectGetString(chart,collision,OBJPROP_TEXT)=="QA collision sentinel";
        }
      // Remove only the exact object successfully created above. Never remove
      // a pre-existing/manual object or delete a broad namespace to make PASS.
      if(created) removed=ObjectDelete(chart,collision) && ObjectFind(chart,collision)<0;
      if(rejected && removed)
        {
         probe.OnChartEvent(CHARTEVENT_CLICK,"");
         bid_after=probe.ObservedBidText(); time_after=probe.QuoteObservedAt();
         recovered=probe.Ready() && probe.Design()==QM_DESIGN_2 && probe.Mode()==QM_CONSOLE_COMPACT &&
            bid_after==bid_before && time_after==time_before &&
            ObjectGetString(chart,prefix+"state_reason",OBJPROP_TEXT)==snapshot.reason &&
            ObjectGetString(chart,prefix+"state_next",OBJPROP_TEXT)==snapshot.next_event &&
            ObjectGetString(chart,prefix+"design_version",OBJPROP_TEXT)=="02" &&
            ObjectFind(chart,collision)>=0 && ObjectGetString(chart,collision,OBJPROP_TEXT)!="QA collision sentinel" &&
            ObjectFind(chart,"QM_RETRY_"+prefix)<0;
        }
      }
   probe.Shutdown();
   // If the first removal failed, one final attempt still targets only our
   // successfully created fault label; never a renderer-created replacement.
   if(created && !removed)
      removed=ObjectFind(chart,collision)<0 || (ObjectDelete(chart,collision) && ObjectFind(chart,collision)<0);
   const int remaining=CompareFixtureObjects(chart,prefix);
   const bool cleanup_ok=!probe.Ready() && remaining==0;
   detail=StringFormat("prefix=%s; collision=%s; initialized=%d; injected=%d; rejected=%d; fault_removed=%d; recovered=%d; cleanup=%d; remaining=%d; bid=%s/%s; quote=%s/%s; restore_failure_injected=0",
      prefix,collision,(int)initialized,(int)injected,(int)rejected,(int)removed,(int)recovered,(int)cleanup_ok,
      remaining,bid_before,bid_after,time_before,time_after);
   return initialized && injected && rejected && removed && recovered && cleanup_ok;
  }

bool CompareInitialStartFailureSelfTest(const long chart,string &detail)
  {
   // A permanently invalid derived prefix exercises the real initial-start
   // failure path. It cannot recover with the same prefix, and does NOT model
   // transient CAPTURE_UNSTABLE or a chart-property restoration failure.
   const string prefix="QM_QA_INIT_"+StringSubstr(g_init_token,(int)MathMax(0,StringLen(g_init_token)-19));
   const string retry="QM_RETRY_"+prefix;
   const string sentinel="QM_CHART_V2_"+prefix+"identity";
   detail="";
   if(chart!=ChartID() || StringLen(prefix)!=30 || StringLen("QM_CHART_V2_"+prefix)<=35 ||
      CompareFixtureObjects(chart,prefix)!=0)
     { detail="Chart/prefix guard failed or temporary namespace already occupied"; return false; }
   // The disabled entry guard must not expose recovery or acquire a quote.
   // MQL_TESTER is not injected here; that early guard has source contracts.
   CQMChartPanelCompare disabled;
   const bool disabled_result=disabled.InitializePresentation(chart,prefix,false,QM_CONSOLE_COMPACT,100,
      false,false,false,false,QM_DESIGN_2,true);
   bool disabled_ok=!disabled_result && !disabled.Ready() && CompareFixtureObjects(chart,prefix)==0 &&
      disabled.ObservedBidText()=="" && disabled.QuoteObservedAt()=="";
   disabled.Shutdown();
   disabled_ok=disabled_ok && CompareFixtureObjects(chart,prefix)==0;
   if(!disabled_ok)
     { detail="Disabled adapter unexpectedly initialized or left objects/quote state"; return false; }

   // A harness-owned foreign label proves that failed startup/retry/shutdown
   // never adopts or deletes an unregistered object in the derived namespace.
   const bool created=ObjectFind(chart,sentinel)<0 && ObjectCreate(chart,sentinel,OBJ_LABEL,0,0,0);
   const bool seeded=created && ObjectSetString(chart,sentinel,OBJPROP_TEXT,"Initial failure sentinel");
   CQMChartPanelCompare probe;
   bool initialized=false,initial_ok=false,refresh_blocked=false,removed_retry=false,retry_ok=false;
   int before_objects=0,after_objects=0;
   string bid_before="",time_before="",bid_after="",time_after="";
   if(seeded)
     {
      initialized=probe.InitializePresentation(chart,prefix,true,QM_CONSOLE_COMPACT,100,
         false,false,false,false,QM_DESIGN_2,true);
      before_objects=CompareFixtureObjects(chart,prefix);
      bid_before=probe.ObservedBidText(); time_before=probe.QuoteObservedAt();
      initial_ok=!initialized && !probe.Ready() && probe.Design()==QM_DESIGN_2 &&
         probe.Mode()==QM_CONSOLE_COMPACT && before_objects==2 && bid_before=="" && time_before=="" &&
         ObjectFind(chart,retry)>=0 && ObjectGetInteger(chart,retry,OBJPROP_TYPE)==OBJ_BUTTON &&
         ObjectGetString(chart,retry,OBJPROP_TEXT)=="Display unavailable - retry" &&
         ObjectGetString(chart,sentinel,OBJPROP_TEXT)=="Initial failure sentinel" &&
         ObjectFind(chart,prefix+"bg")<0;
      if(initial_ok)
        {
         QM_ConsoleSnapshot snapshot; snapshot.Reset(); snapshot.symbol=_Symbol;
         // An unready adapter must reject Refresh before touching cache/quote.
         probe.Refresh(snapshot);
         refresh_blocked=!probe.Ready() && probe.ObservedBidText()=="" && probe.QuoteObservedAt()=="";
         // Remove only the owned retry button. Reappearance proves the explicit
         // invalid retry was actually processed, not a swallowed/no-op event.
         removed_retry=ObjectDelete(chart,retry) && ObjectFind(chart,retry)<0;
         if(removed_retry)
           {
            probe.OnChartEvent(CHARTEVENT_OBJECT_CLICK,retry);
            bid_after=probe.ObservedBidText(); time_after=probe.QuoteObservedAt();
            after_objects=CompareFixtureObjects(chart,prefix);
            retry_ok=!probe.Ready() && probe.Design()==QM_DESIGN_2 && probe.Mode()==QM_CONSOLE_COMPACT &&
               after_objects==2 && bid_after==bid_before && time_after==time_before &&
               ObjectFind(chart,retry)>=0 && ObjectGetInteger(chart,retry,OBJPROP_TYPE)==OBJ_BUTTON &&
               ObjectGetString(chart,retry,OBJPROP_TEXT)=="Display unavailable - retry" &&
               ObjectGetString(chart,sentinel,OBJPROP_TEXT)=="Initial failure sentinel" &&
               ObjectFind(chart,prefix+"bg")<0;
           }
        }
     }
   probe.Shutdown();
   const bool not_adopted=seeded && ObjectFind(chart,sentinel)>=0 &&
      ObjectGetString(chart,sentinel,OBJPROP_TEXT)=="Initial failure sentinel";
   // Only this successfully created sentinel belongs to the harness.
   bool removed_sentinel=!created;
   if(created) removed_sentinel=ObjectDelete(chart,sentinel) && ObjectFind(chart,sentinel)<0;
   const int remaining=CompareFixtureObjects(chart,prefix);
   const bool cleanup_ok=!probe.Ready() && removed_sentinel && remaining==0;
   detail=StringFormat("prefix=%s; derived_v2_length=%d; disabled=%d; initialized=%d; initial_failure=%d; refresh_blocked=%d; deleted_retry=%d; invalid_retry=%d; not_adopted=%d; cleanup=%d; objects=%d/%d/%d; bid=%s/%s; quote=%s/%s; transient_capture_failure_injected=0; same_invalid_prefix_recovered=0; restore_failure_injected=0; tester_guard_exercised=0",
      prefix,StringLen("QM_CHART_V2_"+prefix),(int)disabled_ok,(int)initialized,(int)initial_ok,
      (int)refresh_blocked,(int)removed_retry,(int)retry_ok,(int)not_adopted,(int)cleanup_ok,
      before_objects,after_objects,remaining,bid_before,bid_after,time_before,time_after);
   return disabled_ok && seeded && initial_ok && refresh_blocked && removed_retry && retry_ok && not_adopted && cleanup_ok;
  }
#endif

bool FixtureChartAllowed()
  {
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO ||
      AccountInfoString(ACCOUNT_SERVER)!="FTMO-Demo" || _Symbol!="EURUSD" || _Period!=PERIOD_D1)
      return false;
   const int f=FileOpen("QM_Console_QA\\fixture_chart.txt",FILE_READ|FILE_TXT|FILE_ANSI);
   if(f==INVALID_HANDLE) return false;
   const long expected=StringToInteger(FileReadString(f)); FileClose(f);
   return expected==ChartID();
  }

void BuildFixture(QM_ConsoleSnapshot &s)
  {
   g_fixture_bar=0;
   s.Reset(); s.strategy_name="OHLC Daily Squeeze Reversal"; s.timeframe="D1";
   s.symbol="EURUSD"; s.environment="DESIGN QA"; s.version="5.0 QA";
   s.state=QM_CONSOLE_WAITING_SETUP; s.reason="Synthetic fixture - no trading functions";
   s.next_event="Next D1 evaluation in 12h 14m";
   QM_ConsoleAddGate(s,"execution","Execution","Permission open",QM_GATE_PASS);
   QM_ConsoleAddGate(s,"news","News","Native MT5 clear",QM_GATE_PASS);
   QM_ConsoleAddGate(s,"kill","Kill switch","Armed",QM_GATE_PASS);
   QM_ConsoleAddGate(s,"friday","Friday","Before close",QM_GATE_PASS);
   QM_ConsoleAddGate(s,"spread","Spread","0,6 pip",QM_GATE_PASS);
   QM_ConsoleAddGate(s,"capacity","Capacity","One slot free",QM_GATE_PASS);
   QM_ConsoleAddGate(s,"squeeze","Squeeze","On D1 close",QM_GATE_WAIT);
   QM_ConsoleAddLine(s.risk,"Next trade","0,31 % | USD 312,50");
   QM_ConsoleAddLine(s.risk,"Position SL risk","0,00 % | USD 0,00");
   QM_ConsoleAddLine(s.risk,"Stop basis","Prior range x 1,50 | cap 80,0 pip");
   s.today="1 closed | USD +84,20"; s.week="4 closed | USD +412,70";
   QM_ConsoleAddLine(s.performance,"Trades today / attach / all","1 / 7 / 124");
   QM_ConsoleAddLine(s.performance,"Wins / losses | win rate","83 / 41 | 66,94 %");
   QM_ConsoleAddLine(s.performance,"Net P/L | attach equity","USD +12.345,67 | +3,09 %",QM_GATE_PASS);
   QM_ConsoleAddLine(s.performance,"Gross profit / loss","USD +18.450,00 / USD -6.104,33");
   QM_ConsoleAddLine(s.performance,"Profit factor / expectancy","3,02 / USD +99,56");
   QM_ConsoleAddLine(s.performance,"Average win / loss","USD +222,29 / USD -148,89");
   QM_ConsoleAddLine(s.performance,"Closed-trade drawdown","USD 2.100,00 | 0,53 %");
   QM_ConsoleAddLine(s.performance,"Streaks now / longest","W3 L0 / W8 L4");
   QM_ConsoleAddLine(s.performance,"Best / worst","USD +780,00 / USD -310,00");
   QM_ConsoleAddLine(s.performance,"Last closed trade","USD +145,20 | 2026-09-07 18:00 BT");
   QM_ConsoleAddLine(s.performance,"Account balance / equity","USD 100.412,70 / USD 100.412,70");
   if(g_case==1 || g_case==2)
     {
      s.state=g_case==1?QM_CONSOLE_BLOCKED:QM_CONSOLE_ERROR;
      s.reason=g_case==1?"Execution - Permission off":"News - Calendar unavailable";
      s.alert_reason=s.reason; s.alert_state=g_case==1?QM_GATE_BLOCK:QM_GATE_ERROR;
      s.next_event="Next news check on a fresh market quote";
      s.gates[g_case==1?0:1].state=s.alert_state;
      s.gates[g_case==1?0:1].reason=g_case==1?"Permission off":"Calendar unavailable";
     }
   if(g_case>=3 && g_case<=5)
     {
      const bool pending=g_case==3;
      s.state=pending?QM_CONSOLE_WAITING_TRIGGER:QM_CONSOLE_POSITION_ACTIVE;
      s.reason=pending?"Pending stop armed; no additional entry":"Position managed by fixed SL / TP";
      s.next_event=pending?"Next event: trigger, expiry or D1 re-evaluation":"Next event: SL / TP or Friday close";
      s.positions=pending?0:1; s.pending_orders=pending?1:0;
      s.gates[5].state=QM_GATE_BLOCK; s.gates[5].reason="Slot occupied";
      ArrayResize(s.exposure,1);
      s.exposure[0].ticket=999999001; s.exposure[0].symbol="EURUSD";
      s.exposure[0].pending=pending; s.exposure[0].buy=true;
      s.exposure[0].opened=D'2026.09.07 12:00'; s.exposure[0].expires=D'2026.09.09 00:00';
      if(pending)
        {
         // Dates follow the displayed D1 series, never account/deal state.
         // Keep a reproducible fallback when chart history is unavailable.
         g_fixture_bar=iTime(_Symbol,PERIOD_D1,0);
         if(g_fixture_bar<=0) g_fixture_bar=D'2026.09.07 00:00';
         s.exposure[0].opened=g_fixture_bar-PeriodSeconds(PERIOD_D1)/2;
         s.exposure[0].expires=g_fixture_bar+2*PeriodSeconds(PERIOD_D1);
        }
      s.exposure[0].entry=1.16550; s.exposure[0].sl=1.15750; s.exposure[0].tp=1.17150;
      s.exposure[0].entry_text="1,16550"; s.exposure[0].sl_text="1,15750"; s.exposure[0].tp_text="1,17150";
      s.exposure[0].lots=0.39; s.exposure[0].pnl=84.20;
      QM_ConsoleAddLine(s.live,pending?"Pending 1":"Position 1","EURUSD BUY 0,39 lot",QM_GATE_WAIT);
      QM_ConsoleAddLine(s.live,"Entry / SL / TP","1,16550 / 1,15750 / 1,17150");
      QM_ConsoleAddLine(s.live,pending?"Expiry":"Floating / duration",
         pending?TimeToString(s.exposure[0].expires,TIME_DATE|TIME_MINUTES)+" BT":"USD +84,20 | 01:23",pending?QM_GATE_NA:QM_GATE_PASS);
      if(pending)
        {
         s.active_range=true; s.range_start=g_fixture_bar-4*PeriodSeconds(PERIOD_D1); s.range_end=g_fixture_bar;
         s.range_high=1.16450; s.range_low=1.15850; s.range_high_text="1,16450"; s.range_low_text="1,15850";
        }
      if(g_case==5)
        { s.alert_reason="Entry warning: Execution - Permission off"; s.alert_state=QM_GATE_BLOCK;
          s.gates[0].state=QM_GATE_BLOCK; s.gates[0].reason="Permission off"; }
     }
   if(g_case==6)
     {
      s.strategy_name="Very Long Strategy Identity To Exercise Safe Text Measurement";
      s.symbol="EURUSD.long-broker-suffix";
      s.reason="A deliberately long operational reason which must not overlap any other label or silently hide the critical cause";
      s.next_event="Next D1 evaluation in 123h 59m | 2026-12-31 23:59 broker time";
      s.gates[1].reason="Calendar history unavailable until a fresh high-impact event snapshot arrives";
      s.gates[1].state=QM_GATE_STALE;
      s.risk[0].value="100,00 % | USD 123.456.789.012,34";
      s.today="12345 closed | USD +123.456.789,00"; s.week=s.today;
     }
   if(g_case==7)
     {
      s.today="N/A - history unavailable"; s.week=s.today;
      ArrayResize(s.performance,0);
      QM_ConsoleAddLine(s.performance,"History","Unavailable - no performance inferred",QM_GATE_WARN);
      for(int i=0;i<ArraySize(s.gates);++i) s.gates[i].state=(QM_ConsoleGateState)i;
     }
  }

void Capture(const int serial)
  {
   const string root="QM_Console_QA\\qa_"+IntegerToString(serial);
   const int width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   const int height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   // ChartScreenShot dimensions include native axes/borders; the chart pixel
   // properties describe the plot. The host reads the already-bound HWND's
   // client rectangle without DLL permissions and provides this calibration.
   int screenshot_width=width,screenshot_height=height;
   bool screenshot_calibrated=false;
   const int viewport=FileOpen("QM_Console_QA\\capture_viewport.csv",FILE_READ|FILE_CSV|FILE_ANSI,',');
   if(viewport!=INVALID_HANDLE)
     {
      const long chart=(long)FileReadNumber(viewport),window=(long)FileReadNumber(viewport);
      const int plot_width=(int)FileReadNumber(viewport),plot_height=(int)FileReadNumber(viewport);
      const int client_width=(int)FileReadNumber(viewport),client_height=(int)FileReadNumber(viewport);
      const int dpi=(int)FileReadNumber(viewport);
      FileClose(viewport);
      if(chart==ChartID() && window==ChartGetInteger(0,CHART_WINDOW_HANDLE) &&
         plot_width==width && plot_height==height && dpi==TerminalInfoInteger(TERMINAL_SCREEN_DPI) &&
         client_width>=width && client_width<=width+512 && client_height>=height && client_height<=height+512)
        { screenshot_width=client_width; screenshot_height=client_height; screenshot_calibrated=true; }
     }
   const bool screenshot_ok=ChartScreenShot(0,root+".png",screenshot_width,screenshot_height,ALIGN_LEFT);
   const int f=FileOpen(root+".csv",FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(f==INVALID_HANDLE) return;
   string header[]={"name","type","x","y","width","height","anchor","text","tooltip",
      "type_name","anchor_name","corner","corner_name","angle","scope","serial","subwindow"};
   bool complete=WriteCsvRow(f,header);
   int captured=0;
   for(int i=0;i<ObjectsTotal(0);++i)
     {
      const string name=ObjectName(0,i);
      if(StringFind(name,g_prefix)!=0 && StringFind(name,"QM_CHART_V2_"+g_prefix)!=0) continue;
      const ENUM_OBJECT type=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);
      const bool pixel=type==OBJ_LABEL || type==OBJ_BUTTON || type==OBJ_RECTANGLE_LABEL ||
         type==OBJ_EDIT || type==OBJ_BITMAP_LABEL || type==OBJ_CHART;
      const bool anchored=type==OBJ_LABEL || type==OBJ_BITMAP_LABEL;
      const ENUM_ANCHOR_POINT anchor=anchored?(ENUM_ANCHOR_POINT)ObjectGetInteger(0,name,OBJPROP_ANCHOR):ANCHOR_LEFT_UPPER;
      const ENUM_BASE_CORNER corner=pixel?(ENUM_BASE_CORNER)ObjectGetInteger(0,name,OBJPROP_CORNER):CORNER_LEFT_UPPER;
      const bool overlay=StringFind(name,"QM_CHART_V2_"+g_prefix)==0 ||
         StringFind(name,g_prefix+"range_")==0 || StringFind(name,g_prefix+"trade_")==0;
      string row[]; ArrayResize(row,17);
      row[0]=name; row[1]=IntegerToString((int)type);
      row[2]=pixel?IntegerToString(ObjectGetInteger(0,name,OBJPROP_XDISTANCE)):"";
      row[3]=pixel?IntegerToString(ObjectGetInteger(0,name,OBJPROP_YDISTANCE)):"";
      row[4]=pixel?IntegerToString(ObjectGetInteger(0,name,OBJPROP_XSIZE)):"";
      row[5]=pixel?IntegerToString(ObjectGetInteger(0,name,OBJPROP_YSIZE)):"";
      row[6]=pixel?IntegerToString((int)anchor):"";
      row[7]=ObjectGetString(0,name,OBJPROP_TEXT); row[8]=ObjectGetString(0,name,OBJPROP_TOOLTIP);
      row[9]=EnumToString(type); row[10]=pixel?EnumToString(anchor):"N/A";
      row[11]=pixel?IntegerToString((int)corner):""; row[12]=pixel?EnumToString(corner):"N/A";
      row[13]=type==OBJ_LABEL?DoubleToString(ObjectGetDouble(0,name,OBJPROP_ANGLE),8):"0";
      row[14]=!pixel?"time_price":overlay?"overlay":"panel";
      row[15]=IntegerToString(serial); row[16]=IntegerToString(ObjectFind(0,name));
      complete=WriteCsvRow(f,row) && complete; ++captured;
     }
   FileFlush(f);
   FileClose(f);
   // Written last: a partial object file cannot become a valid census alone.
   const int meta=FileOpen(root+".meta.csv",FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(meta==INVALID_HANDLE) return;
   string keys[]={"schema_version","serial","chart_id","chart_width","chart_height","dpi",
      "scenario","mode","mode_name","requested_mode","scale","prefix","panel_name","object_count",
      "capture_complete","screenshot_ok","init_run_id","selftest_receipt","design","fixture_bar",
      "expert_name","qa_trade_allowed","terminal_trade_allowed","cached_bid","quote_observed_at",
      "screenshot_width","screenshot_height","screenshot_calibrated"};
   string values[]; ArrayResize(values,28);
   values[0]="2"; values[1]=IntegerToString(serial); values[2]=IntegerToString(ChartID());
   values[3]=IntegerToString(width); values[4]=IntegerToString(height);
   values[5]=IntegerToString(TerminalInfoInteger(TERMINAL_SCREEN_DPI)); values[6]=IntegerToString(g_case);
   values[7]=IntegerToString((int)g_display_mode); values[8]=EnumToString(g_display_mode);
   values[9]=IntegerToString((int)g_mode); values[10]=IntegerToString(g_scale);
   values[11]=g_prefix; values[12]=g_prefix+"bg"; values[13]=IntegerToString(captured);
   values[14]=complete?"1":"0"; values[15]=screenshot_ok?"1":"0";
   values[16]=g_init_token; values[17]="selftests_"+g_init_token+".csv";
#ifdef QM_CONSOLE_DESIGN_COMPARE
   values[18]=g_renderer.Design()==QM_DESIGN_2?"V2":"V1";
#else
#ifdef QM_CONSOLE_DESIGN_V2
   values[18]="V2";
#else
   values[18]="V1";
#endif
#endif
   values[19]=IntegerToString(g_fixture_bar);
   values[20]=ChartGetString(0,CHART_EXPERT_NAME);
   values[21]=IntegerToString(MQLInfoInteger(MQL_TRADE_ALLOWED));
   values[22]=IntegerToString(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED));
#ifdef QM_CONSOLE_DESIGN_COMPARE
   values[23]=g_renderer.ObservedBidText(); values[24]=g_renderer.QuoteObservedAt();
#else
   values[23]="N/A"; values[24]="N/A";
#endif
   values[25]=IntegerToString(screenshot_width); values[26]=IntegerToString(screenshot_height);
   values[27]=screenshot_calibrated?"1":"0";
   const bool metadata_ok=WriteCsvRow(meta,keys) && WriteCsvRow(meta,values);
   FileFlush(meta); FileClose(meta);
   Print("QM_CONSOLE_QA CAPTURE ",serial," case=",g_case," size=",width,"x",height,
      " dpi=",TerminalInfoInteger(TERMINAL_SCREEN_DPI)," objects=",captured," complete=",complete && metadata_ok);
   const int chart_proof=FileOpen(root+".chart.csv",FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(chart_proof==INVALID_HANDLE) return;
   string chart_columns[]={"serial","chart_id","property","value"};
   WriteCsvRow(chart_proof,chart_columns);
   ENUM_CHART_PROPERTY_INTEGER properties[]={CHART_COLOR_BACKGROUND,CHART_COLOR_FOREGROUND,
      CHART_COLOR_GRID,CHART_COLOR_CHART_UP,CHART_COLOR_CHART_DOWN,CHART_COLOR_CANDLE_BULL,
      CHART_COLOR_CANDLE_BEAR,CHART_COLOR_CHART_LINE,CHART_COLOR_VOLUME,CHART_COLOR_BID,
      CHART_COLOR_ASK,CHART_COLOR_LAST,CHART_MODE,CHART_FOREGROUND,CHART_SHOW_GRID,
      CHART_SHOW_VOLUMES,CHART_SHOW_BID_LINE,CHART_SHOW_ASK_LINE,CHART_SHOW_LAST_LINE,
      CHART_SHIFT,CHART_SCALE,CHART_AUTOSCROLL,CHART_SHOW_TRADE_LEVELS,
      CHART_DRAG_TRADE_LEVELS,CHART_SHOW_TRADE_HISTORY};
   string chart_row[]; ArrayResize(chart_row,4);
   chart_row[0]=IntegerToString(serial); chart_row[1]=IntegerToString(ChartID());
   for(int property=0;property<ArraySize(properties);++property)
     {
      chart_row[2]=EnumToString(properties[property]);
      chart_row[3]=IntegerToString(ChartGetInteger(0,properties[property]));
      WriteCsvRow(chart_proof,chart_row);
     }
   chart_row[2]="CHART_SHIFT_SIZE"; chart_row[3]=DoubleToString(ChartGetDouble(0,CHART_SHIFT_SIZE),16);
   WriteCsvRow(chart_proof,chart_row); FileFlush(chart_proof); FileClose(chart_proof);
  }

int OnInit()
  {
   if(!FixtureChartAllowed()) { Print("QM_CONSOLE_QA wrong chart - refused"); return INIT_FAILED; }
   g_init_token=StringFormat("%I64d_%I64d_%I64u",ChartID(),(long)TimeLocal(),GetTickCount64());
   const string receipt="QM_Console_QA\\selftests_"+g_init_token+".csv";
   const int proof=FileOpen(receipt,FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(proof==INVALID_HANDLE) return INIT_FAILED;
   string columns[]={"init_run_id","chart_id","suite","status","expected_cases","passed_cases","detail"};
   bool proof_ok=WriteCsvRow(proof,columns);
   string result[]; ArrayResize(result,7);
   result[0]=g_init_token; result[1]=IntegerToString(ChartID()); result[4]="1"; result[6]="";
   const bool formatter_ok=QM_PanelFormatterSelfTest();
   result[2]="formatter"; result[3]=formatter_ok?"PASS":"FAIL"; result[5]=formatter_ok?"1":"0";
   proof_ok=WriteCsvRow(proof,result) && proof_ok;
   const bool model_ok=QM_ConsoleSnapshotSelfTest();
   result[2]="model"; result[3]=model_ok?"PASS":"FAIL"; result[5]=model_ok?"1":"0";
   proof_ok=WriteCsvRow(proof,result) && proof_ok;
   if(!formatter_ok || !model_ok || !proof_ok) { FileFlush(proof); FileClose(proof); return INIT_FAILED; }
   Print("QM_CONSOLE_QA MODEL_FORMATTER_SELF_TESTS PASS");
   string failure="";
   const bool data_ok=QM_ConsoleDataSelfTest(failure);
   result[2]="data"; result[3]=data_ok?"PASS":"FAIL"; result[4]="11"; result[5]=data_ok?"11":"0"; result[6]=failure;
   proof_ok=WriteCsvRow(proof,result) && proof_ok; FileFlush(proof); FileClose(proof);
   if(!data_ok || !proof_ok)
     { Print("QM_CONSOLE_QA DATA_SELF_TESTS/RECEIPT FAIL ",failure); return INIT_FAILED; }
   Print("QM_CONSOLE_QA DATA_SELF_TESTS PASS");
#ifdef QM_CONSOLE_NEWS_SELFTEST
   const bool news_ok=QM11421_ConsoleNewsSelfTest(failure);
   const int news_proof=FileOpen("QM_Console_QA\\news_selftests_"+g_init_token+".csv",
      FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(news_proof==INVALID_HANDLE) return INIT_FAILED;
   string news_columns[]={"init_run_id","chart_id","suite","status","expected_cases","detail"};
   string news_result[]={g_init_token,IntegerToString(ChartID()),"news_observation",news_ok?"PASS":"FAIL","24",failure};
   const bool news_proof_ok=WriteCsvRow(news_proof,news_columns) && WriteCsvRow(news_proof,news_result);
   FileFlush(news_proof); FileClose(news_proof);
   if(!news_ok || !news_proof_ok)
     { Print("QM_CONSOLE_QA NEWS_SELF_TESTS FAIL ",failure); return INIT_FAILED; }
   Print("QM_CONSOLE_QA NEWS_SELF_TESTS PASS");
#endif
#ifdef QM_CONSOLE_DESIGN_COMPARE
   const int chart_proof=FileOpen("QM_Console_QA\\chart_selftests_"+g_init_token+".csv",
      FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(chart_proof==INVALID_HANDLE) return INIT_FAILED;
   string chart_columns[]={"init_run_id","chart_id","suite","status","detail"};
   bool chart_proof_ok=WriteCsvRow(chart_proof,chart_columns);
   string chart_result[]; ArrayResize(chart_result,5);
   chart_result[0]=g_init_token; chart_result[1]=IntegerToString(ChartID());
   const bool geometry_ok=QM_ChartPresentationV2SelfTest(failure);
   chart_result[2]="chart_geometry"; chart_result[3]=geometry_ok?"PASS":"FAIL"; chart_result[4]=failure;
   chart_proof_ok=WriteCsvRow(chart_proof,chart_result) && chart_proof_ok;
   // This exact guard-bound disposable chart is the only place we run native
   // apply/restore and manual-object-deletion recovery tests.
   const bool roundtrip_ok=geometry_ok && QM_ChartPresentationV2ChartSelfTest(ChartID(),failure);
   chart_result[2]="chart_property_roundtrip"; chart_result[3]=roundtrip_ok?"PASS":"FAIL"; chart_result[4]=failure;
   chart_proof_ok=WriteCsvRow(chart_proof,chart_result) && chart_proof_ok;
   // Explicitly opt in only on this guard-bound disposable no-trade fixture.
   // The test simulates a changed zoom, verifies that the presenter preserves
   // it, then restores its own original chart settings on every exit path.
   const bool zoom_ok=roundtrip_ok && FixtureChartAllowed() &&
      QM_ChartPresentationV2ZoomSelfTest(ChartID(),failure,true);
   chart_result[2]="chart_zoom_roundtrip"; chart_result[3]=zoom_ok?"PASS":(roundtrip_ok?"FAIL":"NOT_RUN"); chart_result[4]=failure;
   chart_proof_ok=WriteCsvRow(chart_proof,chart_result) && chart_proof_ok;
   FileFlush(chart_proof); FileClose(chart_proof);
   if(!geometry_ok || !roundtrip_ok || !zoom_ok || !chart_proof_ok)
     { Print("QM_CONSOLE_QA CHART_SELF_TESTS FAIL ",failure); return INIT_FAILED; }
   Print("QM_CONSOLE_QA CHART_SELF_TESTS PASS");
   const int compare_proof=FileOpen("QM_Console_QA\\compare_selftests_"+g_init_token+".csv",
      FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(compare_proof==INVALID_HANDLE) return INIT_FAILED;
   string compare_columns[]={"init_run_id","chart_id","suite","status","detail"};
   bool compare_proof_ok=WriteCsvRow(compare_proof,compare_columns);
   const bool compare_start_ok=CompareStartFailureSelfTest(ChartID(),failure);
   string compare_result[]={g_init_token,IntegerToString(ChartID()),"compare_start_failure_rollback",compare_start_ok?"PASS":"FAIL",failure};
   compare_proof_ok=WriteCsvRow(compare_proof,compare_result) && compare_proof_ok;
   if(!compare_start_ok) failure="Not run: prior start-failure rollback test failed";
   const bool compare_render_ok=compare_start_ok && CompareRenderFailureSelfTest(ChartID(),failure);
   compare_result[2]="compare_render_failure_recovery";
   compare_result[3]=compare_render_ok?"PASS":(compare_start_ok?"FAIL":"NOT_RUN"); compare_result[4]=failure;
   compare_proof_ok=WriteCsvRow(compare_proof,compare_result) && compare_proof_ok;
   if(!compare_render_ok) failure="Not run: prior compare failure test failed";
   const bool compare_initial_ok=compare_render_ok && CompareInitialStartFailureSelfTest(ChartID(),failure);
   compare_result[2]="initial_start_failure_retry";
   compare_result[3]=compare_initial_ok?"PASS":(compare_render_ok?"FAIL":"NOT_RUN"); compare_result[4]=failure;
   compare_proof_ok=WriteCsvRow(compare_proof,compare_result) && compare_proof_ok;
   FileFlush(compare_proof); FileClose(compare_proof);
   const bool compare_ok=compare_start_ok && compare_render_ok && compare_initial_ok;
   if(!compare_ok || !compare_proof_ok)
     { Print("QM_CONSOLE_QA COMPARE_SELF_TESTS FAIL ",failure); return INIT_FAILED; }
   Print("QM_CONSOLE_QA COMPARE_SELF_TESTS PASS");
#endif
   QM_ChartScheme_Apply(ChartID());
   if(!InitializeRenderer()) return INIT_FAILED;
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnTimer()
  {
   if(g_capture_pending>=0)
     { Capture(g_capture_pending); g_capture_pending=-1; return; }
   const int f=FileOpen("QM_Console_QA\\command.csv",FILE_READ|FILE_CSV|FILE_ANSI,',');
   if(f==INVALID_HANDLE)
     { QM_ConsoleSnapshot s; BuildFixture(s); RenderFixture(s); return; }
   const int serial=(int)FileReadNumber(f);
   const int scenario=(int)FileReadNumber(f);
   const int mode=(int)FileReadNumber(f);
   const int scale=(int)FileReadNumber(f);
   const string action=FileReadString(f);
   FileClose(f);
   if(serial<=g_serial || scenario<0 || scenario>7 || mode<0 || mode>2 || scale<80 || scale>150) return;
   g_serial=serial;
   const bool reset=g_case!=scenario || g_mode!=(QM_ConsoleMode)mode || g_scale!=scale || action=="reset";
   if(reset)
     {
      g_case=scenario; g_mode=(QM_ConsoleMode)mode; g_scale=scale;
      g_renderer.Shutdown();
      if(!InitializeRenderer()) return;
     }
   // A/B captures must retain the very same cached quote as well as snapshot.
   // No pre-click Refresh is allowed to fetch a newer tick for this operation.
   if(reset || action!="design_version")
     { QM_ConsoleSnapshot s; BuildFixture(s); RenderFixture(s); }
   if(action!="capture" && action!="reset" && action!="")
      PresentationEvent(CHARTEVENT_OBJECT_CLICK,g_prefix+action);
   // Capture on the next event so asynchronous native text sizes are settled.
   g_capture_pending=serial;
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  { PresentationEvent(id,sparam); }

void OnDeinit(const int reason)
  { EventKillTimer(); g_renderer.Shutdown(); QM_ChartScheme_Restore(ChartID()); }
