#property strict
#property version   "5.0"
#property description "QM5_11916 Alexander 1961 Filter Rule y=2% (Neely-Weller 2013)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11916
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11916;
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
input double strategy_filter_size_y     = 0.02;   // 2% filter
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 4.0;
input int    strategy_time_stop_bars    = 250;

// --- State Variables ---
double g_running_high = 0.0;
double g_running_low  = 0.0;
int    g_current_dir  = 0; // 1=Long, -1=Short, 0=None

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   // Closed bar data
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double atr1   = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   
   if(close1 <= 0.0 || atr1 <= 0.0) return false;

   // Initialize extrema if starting
   if(g_running_high <= 0.0) g_running_high = close1;
   if(g_running_low <= 0.0)  g_running_low = close1;

   // Update running extrema
   if(close1 > g_running_high) g_running_high = close1;
   if(close1 < g_running_low)  g_running_low = close1;

   bool signal_long  = (g_current_dir != 1  && close1 > g_running_low  * (1.0 + strategy_filter_size_y));
   bool signal_short = (g_current_dir != -1 && close1 < g_running_high * (1.0 - strategy_filter_size_y));

   if(!signal_long && !signal_short) return false;

   QM_OrderType side = QM_BUY;
   if(signal_long) {
      side = QM_BUY;
      g_current_dir = 1;
      g_running_high = close1; // Reset to track next local max
   } else {
      side = QM_SELL;
      g_current_dir = -1;
      g_running_low = close1;  // Reset to track next local min
   }

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr1, strategy_atr_sl_mult);

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "ALEXANDER_FILTER_LONG" : "ALEXANDER_FILTER_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   
   return true;
}

void Strategy_ManageOpenPosition()
{
   // No management specified in card
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   
   // Hard timeout check
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_D1, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }
      
      // Opposite signal (handled by flip in EntrySignal logic, but framework 
      // calls ExitSignal first. However, the flip logic is best handled 
      // by the EntrySignal returning true when a position already exists.)
      // In QM framework, if EntrySignal returns true and a position exists, 
      // the framework doesn't automatically close it unless we do it here 
      // or the trade manager handles it.
      
      const double close1 = iClose(_Symbol, PERIOD_D1, 1);
      if(g_current_dir == 1 && close1 < g_running_high * (1.0 - strategy_filter_size_y)) return true;
      if(g_current_dir == -1 && close1 > g_running_low * (1.0 + strategy_filter_size_y)) return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

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
