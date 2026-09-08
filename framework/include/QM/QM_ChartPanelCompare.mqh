#ifndef QM_CHARTPANELCOMPARE_MQH
#define QM_CHARTPANELCOMPARE_MQH

#include <QM/QM_ChartPanel.mqh>
#include <QM/QM_StrategyConsoleV2.mqh>
#include <QM/QM_ChartPresentationV2.mqh>

enum QM_ConsoleDesign { QM_DESIGN_1=1, QM_DESIGN_2=2 };

// Only the explicitly selected EURUSD canary uses this adapter. The shared V1
// adapter and every other EA keep their existing presentation contract.
// A/B changes renderer objects and reversible chart styling, never EA lifecycle.
class CQMChartPanelCompare
  {
private:
   CQMConsoleData m_data;
   CQMStrategyConsole m_v1;
   CQMStrategyConsoleV2 m_v2;
   CQMChartPresentationV2 m_chart_v2;
   QM_ConsoleSnapshot m_cached;
   long m_chart;
   string m_prefix,m_bid_text,m_quote_time;
   double m_bid;
   bool m_ready,m_has_snapshot,m_busy,m_apply_theme,m_recovering,m_recovery_button;
   bool m_range,m_strategy,m_levels,m_markers;
   int m_scale;
   QM_ConsoleMode m_mode;
   QM_ConsoleDesign m_design,m_recovery_design;

   bool StartRenderer()
     {
      if(m_chart_v2.RestorePending())
        { Print("QM_DESIGN_COMPARE: start refused while chart restore is pending; trading unaffected"); return false; }
      if(m_design==QM_DESIGN_1)
         return m_v1.Initialize(m_chart,m_prefix,true,m_mode,m_scale,m_range,m_strategy,m_levels,m_markers);
      if(!m_v2.Initialize(m_chart,m_prefix,true,m_mode,m_scale,false,false,false,false)) return false;
      // Disjoint namespaces: neither renderer may prune the other's objects.
      if(!m_chart_v2.Initialize(m_chart,"QM_CHART_V2_"+m_prefix,true,true,m_scale,
            m_range,m_levels,m_markers,m_strategy,m_apply_theme))
        { m_v2.Shutdown(); return false; }
      return true;
     }
   void PaintCached()
     {
      if(!m_ready || !m_has_snapshot) return;
      if(m_design==QM_DESIGN_1)
        {
         m_v1.Render(m_cached);
         if(!m_v1.Ready()) RenderFailed("V1 render");
        }
      else
        {
         m_v2.Render(m_cached);
         if(!m_v2.Ready()) { RenderFailed("V2 render"); return; }
         if(!m_chart_v2.Render(m_cached,m_v2.PanelRightPixels(),m_bid,m_bid_text,m_quote_time))
            RenderFailed("chart render");
        }
     }
   bool StopRenderer()
     {
      if(m_design==QM_DESIGN_1) m_v1.Shutdown();
      else
        {
         const bool stopped=m_chart_v2.Shutdown();
         if(!stopped || m_chart_v2.RestorePending())
           {
            Print("QM_DESIGN_COMPARE: chart style restore incomplete; switch refused, retry available; trading unaffected");
            return false;
           }
         m_v2.Shutdown();
        }
      return true;
     }
   void RenderFailed(const string stage)
     {
      // Rendering can fail AFTER Initialize succeeded. Freeze the cache and
      // retain this exact design as cleanup/retry owner; never restart on a timer.
      m_ready=false; m_recovering=true; m_recovery_design=m_design;
      const bool cleaned=StopRenderer();
      Print("QM_DESIGN_COMPARE: ",stage," failed; cleanup=",cleaned,
            "; explicit same-design retry available; trading unaffected");
      ShowRecovery();
     }
   string RecoveryName() const { return "QM_RETRY_"+m_prefix; }
   bool HideRecovery()
     {
      if(!m_recovery_button) return true;
      if(ObjectFind(m_chart,RecoveryName())<0 ||
         (ObjectDelete(m_chart,RecoveryName()) && ObjectFind(m_chart,RecoveryName())<0))
        { m_recovery_button=false; return true; }
      Print("QM_DESIGN_COMPARE: recovery control cleanup incomplete; restart deferred; trading unaffected");
      return false;
     }
   void ShowRecovery()
     {
      // Separate ownership: neither dashboard nor chart overlay cleanup adopts
      // this control. Only an explicit click retries; no resize/timer loop.
      const string name=RecoveryName();
      if(!m_recovery_button)
        {
         if(ObjectFind(m_chart,name)>=0 || !ObjectCreate(m_chart,name,OBJ_BUTTON,0,0,0))
           { Print("QM_DESIGN_COMPARE: recovery control unavailable; click chart background to retry previous design; trading unaffected"); return; }
         m_recovery_button=true;
        }
      const double factor=MathMax(72.0,(double)TerminalInfoInteger(TERMINAL_SCREEN_DPI))/96.0*
                          MathMax(80.0,MathMin(150.0,(double)m_scale))/100.0;
      const int width=(int)MathMax(1,MathMin(236*factor,ChartGetInteger(m_chart,CHART_WIDTH_IN_PIXELS)-16));
      const int height=(int)MathMax(1,MathMin(30*factor,ChartGetInteger(m_chart,CHART_HEIGHT_IN_PIXELS)-16));
      bool ok=ObjectSetInteger(m_chart,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ok=ObjectSetInteger(m_chart,name,OBJPROP_XDISTANCE,8) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_YDISTANCE,8) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_XSIZE,width) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_YSIZE,height) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_BGCOLOR,QM_COLOR_SURFACE) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_COLOR,QM_COLOR_INK) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_BORDER_COLOR,QM_COLOR_WARNING) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_FONTSIZE,(int)MathMax(8,MathRound(9*m_scale/100.0))) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_ZORDER,960) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_BACK,false) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_HIDDEN,true) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_SELECTABLE,false) && ok;
      ok=ObjectSetInteger(m_chart,name,OBJPROP_STATE,false) && ok;
      ok=ObjectSetString(m_chart,name,OBJPROP_FONT,QM_FONT_UI) && ok;
      ok=ObjectSetString(m_chart,name,OBJPROP_TEXT,"Display unavailable - retry") && ok;
      ok=ObjectSetString(m_chart,name,OBJPROP_TOOLTIP,"Retry the retained design after a presentation failure. Trading unaffected. Chart background click also retries.") && ok;
      if(!ok) Print("QM_DESIGN_COMPARE: recovery control update incomplete; click chart background to retry previous design; trading unaffected");
      ChartRedraw(m_chart);
     }
   void RecoverPrevious()
     {
      // Keep m_design on the cleanup owner until both objects and saved chart
      // properties are released; never start another renderer over that owner.
      if(!StopRenderer() || !HideRecovery()) { ShowRecovery(); return; }
      m_design=m_recovery_design;
      m_ready=StartRenderer();
      if(!m_ready)
        {
         const bool cleaned=StopRenderer();
         Print("QM_DESIGN_COMPARE: previous design restart failed; cleanup=",cleaned,
               "; explicit retry available; trading unaffected");
         ShowRecovery(); return;
        }
      m_recovering=false;
      PaintCached();
      // PaintCached may itself fail again and re-arm explicit recovery.
      if(m_ready && !m_recovering)
         Print("QM_DESIGN_COMPARE: presentation recovered to design ",(int)m_design,"; trading unaffected");
     }
public:
   CQMChartPanelCompare()
     {
      m_chart=0; m_prefix=""; m_ready=false; m_has_snapshot=false; m_busy=false;
      m_recovering=false; m_recovery_button=false; m_recovery_design=QM_DESIGN_2;
      m_apply_theme=true; m_range=true; m_strategy=true; m_levels=true; m_markers=true;
      m_scale=100; m_mode=QM_CONSOLE_FULL; m_design=QM_DESIGN_2;
      m_bid=0.0; m_bid_text=""; m_quote_time="";
     }
   bool InitializePresentation(const long chart,const string prefix,const bool enabled,
                    const QM_ConsoleMode mode,const int scale,const bool show_range,
                    const bool show_strategy,const bool show_levels,const bool show_markers,
                    const QM_ConsoleDesign design=QM_DESIGN_2,const bool apply_theme=true)
     {
      if(!enabled || MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0 || prefix=="")
         return false;
      // Reinitialization must not overwrite the chart/prefix/design that still
      // owns cleanup or a pending restore. Recover only through an explicit
      // click, or complete Shutdown before initializing this adapter again.
      if(m_ready || m_recovering || m_chart_v2.RestorePending())
        { Print("QM_DESIGN_COMPARE: initialization refused while presentation ownership remains; use explicit retry or complete shutdown; trading unaffected"); return false; }
      if(!HideRecovery()) return false;
      m_recovering=false;
      m_chart=chart; m_prefix=prefix; m_mode=mode;
      // The MT5 input field accepts arbitrary integers. Keep dashboard, chart
      // and recovery controls on the same documented 80..150% display scale.
      m_scale=(int)MathMax(80,MathMin(150,scale));
      m_range=show_range; m_strategy=show_strategy; m_levels=show_levels; m_markers=show_markers;
      m_design=design==QM_DESIGN_1?QM_DESIGN_1:QM_DESIGN_2; m_apply_theme=apply_theme;
      m_has_snapshot=false; m_ready=StartRenderer();
      if(!m_ready)
        {
         // A transient capture/layout failure can happen on the first start as
         // well. Keep the failed design as cleanup owner and expose the same
         // explicit retry used after A/B/render failures. Never start a timer,
         // invent a snapshot, or retry StartRenderer inside this failure path.
         m_recovering=true; m_recovery_design=m_design;
         const bool cleaned=StopRenderer();
         Print("QM_DESIGN_COMPARE: initial design ",(int)m_design," start failed; cleanup=",cleaned,
               "; explicit same-design retry available; caller must resume observation after recovery; trading unaffected");
         ShowRecovery(); return false;
        }
      return true;
     }
   bool Initialize(const long chart,const int ea_id,const string identity,
                    const long magic,const string build_hash,const bool enabled=true,
                    const QM_ConsoleMode mode=QM_CONSOLE_FULL,const int scale=100,
                    const bool show_range=true,const bool show_strategy=true,
                    const bool show_levels=true,const bool show_markers=true,
                    const QM_ConsoleDesign design=QM_DESIGN_2,const bool apply_theme=true)
     {
      if(!enabled || MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0) return false;
      // Do not reset the collector to another magic while a retained renderer
      // still owns presentation recovery. InitializePresentation enforces the
      // same guard before changing its chart/prefix/design identity.
      if(m_ready || m_recovering || m_chart_v2.RestorePending()) return false;
      m_data.Initialize(magic);
      return InitializePresentation(chart,"QM_SIG_"+IntegerToString(ea_id)+"_"+
         StringFormat("%I64d",magic)+"_",enabled,mode,scale,show_range,show_strategy,show_levels,show_markers,design,apply_theme);
     }
   bool Ready() const { return m_ready; }
   QM_ConsoleMode Mode() const { return m_design==QM_DESIGN_1?m_v1.Mode():m_v2.Mode(); }
   QM_ConsoleDesign Design() const { return m_design; }
   string ObservedBidText() const { return m_bid_text; }
   string QuoteObservedAt() const { return m_quote_time; }
   int PanelRightPixels() const { return m_design==QM_DESIGN_1?m_v1.PanelRightPixels():m_v2.PanelRightPixels(); }
   void Populate(QM_ConsoleSnapshot &snapshot) { if(Ready()) m_data.Populate(snapshot); }
   void InvalidatePerformance() { m_data.Invalidate(); }
   void Refresh(const QM_ConsoleSnapshot &snapshot)
     {
      if(!m_ready || m_busy) return;
      m_cached=snapshot; m_has_snapshot=true;
      // Read-only quote acquisition belongs to the adapter, never a renderer or
      // click handler. A missing/stale quote is not fabricated as a current bid.
      MqlTick quote;
      m_bid=0.0; m_bid_text=""; m_quote_time="";
      if(SymbolInfoTick(snapshot.symbol,quote) && quote.bid>0.0 && quote.time>0)
        {
         m_bid=quote.bid;
         m_bid_text=DoubleToString(quote.bid,(int)SymbolInfoInteger(snapshot.symbol,SYMBOL_DIGITS));
         m_quote_time=TimeToString(quote.time,TIME_DATE|TIME_SECONDS)+" BT";
        }
      PaintCached();
     }
   void OnChartEvent(const int id,const string object_name)
     {
      if(m_busy) return;
      if(m_recovering)
        {
         if((id==CHARTEVENT_OBJECT_CLICK && object_name==RecoveryName()) || id==CHARTEVENT_CLICK)
           { m_busy=true; RecoverPrevious(); m_busy=false; }
         return;
        }
      if(!m_ready) return;
      if(id==CHARTEVENT_OBJECT_CLICK && object_name==m_prefix+"design_version")
        {
         m_busy=true;
         m_mode=Mode();
         const QM_ConsoleDesign previous=m_design;
         if(!StopRenderer()) { m_busy=false; return; }
         m_design=m_design==QM_DESIGN_1?QM_DESIGN_2:QM_DESIGN_1;
         m_ready=StartRenderer();
         if(!m_ready)
           {
            Print("QM_DESIGN_COMPARE: target design ",(int)m_design,
                  " start failed; recovering previous design ",(int)previous,"; trading unaffected");
            m_recovery_design=previous; m_recovering=true;
            RecoverPrevious(); m_busy=false; return;
           }
         // Source snapshot, history, account and quote are unchanged by A/B.
         PaintCached(); m_busy=false; return;
        }
      if(m_design==QM_DESIGN_1)
        {
         m_v1.OnChartEvent(id,object_name);
         if(!m_v1.Ready()) RenderFailed("V1 event render");
        }
      else
        {
         m_v2.OnChartEvent(id,object_name);
         if(!m_v2.Ready()) { RenderFailed("V2 event render"); return; }
         if(m_has_snapshot && (id==CHARTEVENT_CHART_CHANGE || id==CHARTEVENT_OBJECT_CLICK))
            if(!m_chart_v2.Render(m_cached,m_v2.PanelRightPixels(),m_bid,m_bid_text,m_quote_time))
               RenderFailed("chart event render");
        }
     }
   void Shutdown()
     {
      const bool stopped=StopRenderer();
      const bool hidden=HideRecovery();
      if(!stopped || !hidden || m_chart_v2.RestorePending())
         Print("QM_DESIGN_COMPARE: shutdown cleanup incomplete; renderer_stopped=",stopped,
               " recovery_removed=",hidden," chart_restore_pending=",m_chart_v2.RestorePending(),
               "; no further retry after external deinitialization; trading lifecycle unchanged");
      m_recovering=false; m_ready=false; m_has_snapshot=false;
     }
  };

#endif
