#property strict
#property version   "5.0"
#property description "QM5_11901 London Asia-Range Breakout (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11901
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11901;
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
input int    strategy_asia_start_hour   = 2;  // Broker time equivalent to 00:00 UTC
input int    strategy_asia_end_hour     = 10; // Broker time equivalent to 08:00 UTC
input int    strategy_window_end_hour   = 13; // Broker time equivalent to 11:00 UTC
input int    strategy_timeout_hour      = 22; // Broker time equivalent to 20:00 UTC
input double strategy_tp_pips           = 30.0;
input double strategy_sl_buffer_pips    = 2.0;

// State tracking
datetime g_current_trade_day = 0;
double   g_asia_high = 0.0;
double   g_asia_low  = 0.0;
bool     g_range_computed = false;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(PositionsTotal() > 0) return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Reset daily state at the start of the Asia session
   datetime day_start = TimeCurrent() - (dt.hour * 3600) - (dt.min * 60) - dt.sec;
   if(day_start != g_current_trade_day)
   {
      g_current_trade_day = day_start;
      g_range_computed = false;
      g_asia_high = 0.0;
      g_asia_low = 999999.0;
   }

   // Compute range exactly at the end of the Asia session (London Open)
   if(dt.hour == strategy_asia_end_hour && dt.min == 0 && !g_range_computed)
   {
      int bars_in_session = (strategy_asia_end_hour - strategy_asia_start_hour) * 4; // M15 bars
      for(int i = 1; i <= bars_in_session; i++)
      {
         double h = iHigh(_Symbol, PERIOD_M15, i);
         double l = iLow(_Symbol, PERIOD_M15, i);
         if(h > g_asia_high) g_asia_high = h;
         if(l < g_asia_low)  g_asia_low = l;
      }
      g_range_computed = true;
   }

   // Check breakout window
   if(!g_range_computed) return false;
   if(dt.hour < strategy_asia_end_hour || dt.hour >= strategy_window_end_hour) return false;

   const double close1 = iClose(_Symbol, PERIOD_M15, 1);
   const double high1 = iHigh(_Symbol, PERIOD_M15, 1);
   const double low1 = iLow(_Symbol, PERIOD_M15, 1);

   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0) return false;

   bool signal_long = false;
   bool signal_short = false;

   if(close1 > g_asia_high) signal_long = true;
   if(close1 < g_asia_low) signal_short = true;

   if(!signal_long && !signal_short) return false;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   QM_OrderType side = signal_long ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl = 0.0;
   if(side == QM_BUY) sl = low1 - (strategy_sl_buffer_pips * 10 * point);
   else sl = high1 + (strategy_sl_buffer_pips * 10 * point);
   
   double tp = 0.0;
   if(side == QM_BUY) tp = entry + (strategy_tp_pips * 10 * point);
   else tp = entry - (strategy_tp_pips * 10 * point);

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "LONDON_BO_LONG" : "LONDON_BO_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   
   // Prevents taking another trade today since g_current_trade_day handles state,
   // but PositionsTotal() blocks concurrent. Once closed, we could re-enter if still in window.
   // The card says "One-shot per session: only the FIRST valid breakout per day triggers a trade."
   // We enforce this by invalidating the range after a signal is generated.
   g_range_computed = false; // Consume the setup for today

   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Hard timeout at 20:00 UTC (strategy_timeout_hour broker time)
      if(dt.hour >= strategy_timeout_hour && dt.hour < 23) // prevent triggering on next day open
         return true;
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

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

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
