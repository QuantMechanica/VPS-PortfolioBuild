#property strict
#property version   "5.0"
#property description "QM5_11910 Larry Williams 18-Day MA + 2 Outside Bars (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11910
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11910;
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
input int    strategy_ma_period         = 18;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_target_atr_mult   = 4.0;
input int    strategy_order_validity    = 5;
input int    strategy_time_stop_bars    = 30;

// State tracking for simulated pending orders
double g_long_level = 0.0;
double g_long_sl    = 0.0;
double g_long_tp    = 0.0;
int    g_long_valid = 0;

double g_short_level = 0.0;
double g_short_sl    = 0.0;
double g_short_tp    = 0.0;
int    g_short_valid = 0;

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

bool IsInsideBar(int shift)
{
   double high_curr = iHigh(_Symbol, PERIOD_D1, shift);
   double low_curr  = iLow(_Symbol, PERIOD_D1, shift);
   double high_prev = iHigh(_Symbol, PERIOD_D1, shift + 1);
   double low_prev  = iLow(_Symbol, PERIOD_D1, shift + 1);
   
   return (high_curr < high_prev && low_curr > low_prev);
}

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

   // Bar t = 1, Bar t-1 = 2
   const double low1 = iLow(_Symbol, PERIOD_D1, 1);
   const double low2 = iLow(_Symbol, PERIOD_D1, 2);
   const double high1 = iHigh(_Symbol, PERIOD_D1, 1);
   const double high2 = iHigh(_Symbol, PERIOD_D1, 2);
   
   const double ma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 1);
   const double ma2 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 2);
   const double atr1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(low1 <= 0.0 || low2 <= 0.0 || ma1 <= 0.0 || ma2 <= 0.0 || atr1 <= 0.0) return false;

   // Check Bullish Setup
   if(low1 > ma1 && low2 > ma2 && !IsInsideBar(1) && !IsInsideBar(2))
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      g_long_level = MathMax(high1, high2) + (10 * point); // +1 pip
      g_long_sl = g_long_level - (strategy_atr_sl_mult * atr1);
      g_long_tp = g_long_level + (strategy_target_atr_mult * atr1);
      g_long_valid = strategy_order_validity;
   }
   
   // Check Bearish Setup
   if(high1 < ma1 && high2 < ma2 && !IsInsideBar(1) && !IsInsideBar(2))
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      g_short_level = MathMin(low1, low2) - (10 * point); // -1 pip
      g_short_sl = g_short_level + (strategy_atr_sl_mult * atr1);
      g_short_tp = g_short_level - (strategy_target_atr_mult * atr1);
      g_short_valid = strategy_order_validity;
   }

   // Decrease validity
   if(g_long_valid > 0)  g_long_valid--;
   if(g_short_valid > 0) g_short_valid--;

   // Check Trigger
   bool trigger_long = false;
   bool trigger_short = false;

   if(g_long_valid >= 0 && g_long_level > 0.0)
   {
      if(high1 >= g_long_level)
      {
         trigger_long = true;
         g_long_valid = 0; // consumed
      }
   }
   
   if(g_short_valid >= 0 && g_short_level > 0.0)
   {
      if(low1 <= g_short_level)
      {
         trigger_short = true;
         g_short_valid = 0; // consumed
      }
   }

   if(!trigger_long && !trigger_short) return false;

   QM_OrderType side = trigger_long ? QM_BUY : QM_SELL;
   
   req.type = side;
   req.price = 0.0;
   req.sl = (side == QM_BUY) ? g_long_sl : g_short_sl;
   req.tp = (side == QM_BUY) ? g_long_tp : g_short_tp;
   req.reason = (side == QM_BUY) ? "WILLIAMS_18MA_LONG" : "WILLIAMS_18MA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
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

      // Time stop
      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_D1, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }
      
      // MA Cross Exit
      const double close1 = iClose(_Symbol, PERIOD_D1, 1);
      const double ma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 1);
      
      if(close1 <= 0.0 || ma1 <= 0.0) continue;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(ptype == POSITION_TYPE_BUY && close1 < ma1) return true;
      if(ptype == POSITION_TYPE_SELL && close1 > ma1) return true;
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
