#ifndef QM_CHARTPANEL_MQH
#define QM_CHARTPANEL_MQH

#include <QM/QM_ChartScheme.mqh>
#include <QM/QM_ConsoleData.mqh>
#include <QM/QM_StrategyConsole.mqh>

// V5 compatibility entry point. Data production and rendering stay separate.
class CQMChartPanel
  {
private:
   CQMConsoleData m_data;
   CQMStrategyConsole m_renderer;
public:
   bool Initialize(const long chart,const int ea_id,const string identity,
                    const long magic,const string build_hash,const bool enabled=true,
                    const QM_ConsoleMode mode=QM_CONSOLE_FULL,const int scale=100,
                    const bool show_range=true,const bool show_strategy=true,
                    const bool show_levels=true,const bool show_markers=true)
     {
      if(!enabled || MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0) return false;
      m_data.Initialize(magic);
      return m_renderer.Initialize(chart,"QM_SIG_"+IntegerToString(ea_id)+"_"+
         StringFormat("%I64d",magic)+"_",enabled,mode,scale,show_range,show_strategy,show_levels,show_markers);
     }
   bool Ready() const { return m_renderer.Ready(); }
   void Populate(QM_ConsoleSnapshot &snapshot) { if(Ready()) m_data.Populate(snapshot); }
   void Refresh(const QM_ConsoleSnapshot &snapshot) { m_renderer.Render(snapshot); }
   void InvalidatePerformance() { m_data.Invalidate(); }
   void OnChartEvent(const int id,const string object_name) { m_renderer.OnChartEvent(id,object_name); }
   void Shutdown() { m_renderer.Shutdown(); }
  };

#endif
