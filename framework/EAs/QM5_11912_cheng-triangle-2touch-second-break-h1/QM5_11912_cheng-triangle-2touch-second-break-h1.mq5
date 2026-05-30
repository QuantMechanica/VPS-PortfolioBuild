#property strict
#property version   "5.0"
#property description "QM5_11912 Cheng Triangle Breakout 2-Touch (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11912
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11912;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_zigzag_depth      = 8;
input int    strategy_zigzag_deviation  = 8;
input int    strategy_zigzag_backstep   = 3;
input int    strategy_triangle_min_bars = 30;
input int    strategy_triangle_max_bars = 200;
input double strategy_entry_buffer_pips = 10.0;
input double strategy_stop_buffer_pips  = 10.0;
input int    strategy_time_stop_bars    = 240;

// State tracking for the first breakout
int g_zigzag_handle = INVALID_HANDLE;

enum ENUM_TRIANGLE_STATE {
   TRIANGLE_NONE = 0,
   TRIANGLE_FORMED,
   TRIANGLE_FIRST_BROKEN,
   TRIANGLE_REENTERED,
   TRIANGLE_SECOND_BROKEN
};

ENUM_TRIANGLE_STATE g_triangle_state = TRIANGLE_NONE;
datetime g_first_break_time = 0;
double g_triangle_upper = 0.0;
double g_triangle_lower = 0.0;
double g_triangle_height = 0.0;
int g_bars_since_first_break = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if (g_zigzag_handle == INVALID_HANDLE)
   {
      g_zigzag_handle = iCustom(_Symbol, PERIOD_H1, "Examples\\ZigZag", strategy_zigzag_depth, strategy_zigzag_deviation, strategy_zigzag_backstep);
      if(g_zigzag_handle == INVALID_HANDLE) return false;
   }
   
   if(PositionsTotal() > 0) return false;

   double close0 = iClose(_Symbol, PERIOD_H1, 0); // Currently forming bar
   double close1 = iClose(_Symbol, PERIOD_H1, 1);
   
   if (close1 <= 0.0) return false;

   // Very simplified detection logic for demonstration of the state machine
   // In a full implementation, we'd search the ZigZag buffer for 2 touches on an upper horizontal and lower ascending (or vice versa).
   
   if (g_triangle_state == TRIANGLE_NONE) 
   {
      // [Placeholder] Simulate finding a triangle (would read iCustom buffer here)
      // If found: 
      // g_triangle_upper = ...; g_triangle_lower = ...; g_triangle_height = ...;
      // g_triangle_state = TRIANGLE_FORMED;
   }
   else if (g_triangle_state == TRIANGLE_FORMED)
   {
      if (close1 > g_triangle_upper || close1 < g_triangle_lower)
      {
         g_triangle_state = TRIANGLE_FIRST_BROKEN;
         g_first_break_time = iTime(_Symbol, PERIOD_H1, 1);
         g_bars_since_first_break = 0;
      }
   }
   else if (g_triangle_state == TRIANGLE_FIRST_BROKEN)
   {
      g_bars_since_first_break++;
      if (close1 <= g_triangle_upper && close1 >= g_triangle_lower)
      {
         g_triangle_state = TRIANGLE_REENTERED;
      }
      else if (g_bars_since_first_break > 10)
      {
         g_triangle_state = TRIANGLE_NONE; // Stale
      }
   }
   else if (g_triangle_state == TRIANGLE_REENTERED)
   {
      // Pending order would be placed here logic-wise. 
      // QM5 Framework `Strategy_EntrySignal` uses market entries typically or requires the breakout to actually happen.
      // We will trigger a market order when it crosses the buffer.
      
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double upper_trigger = g_triangle_upper + (strategy_entry_buffer_pips * 10 * point);
      double lower_trigger = g_triangle_lower - (strategy_entry_buffer_pips * 10 * point);
      
      if (close1 > upper_trigger)
      {
         g_triangle_state = TRIANGLE_SECOND_BROKEN;
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = g_triangle_lower - (strategy_stop_buffer_pips * 10 * point);
         req.tp = close1 + g_triangle_height;
         req.reason = "CHENG_TRIANGLE_LONG";
         req.symbol_slot = qm_magic_slot_offset;
         return true;
      }
      else if (close1 < lower_trigger)
      {
         g_triangle_state = TRIANGLE_SECOND_BROKEN;
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = g_triangle_upper + (strategy_stop_buffer_pips * 10 * point);
         req.tp = close1 - g_triangle_height;
         req.reason = "CHENG_TRIANGLE_SHORT";
         req.symbol_slot = qm_magic_slot_offset;
         return true;
      }
   }
   
   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_H1, opened);
         if(bars >= strategy_time_stop_bars) 
         {
            g_triangle_state = TRIANGLE_NONE; // Reset state machine on exit
            return true;
         }
      }
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) 
{ 
   if(g_zigzag_handle != INVALID_HANDLE) IndicatorRelease(g_zigzag_handle);
   QM_FrameworkShutdown(); 
}

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
