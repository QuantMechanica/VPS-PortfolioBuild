#property strict
#property version   "5.0"
#property description "QM5_11905 Hui & Chan Shiryaev-Zhou Index 3-Day (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11905
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11905;
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
input int    strategy_moving_window_n   = 130;
input int    strategy_trading_days_yr   = 250;
input int    strategy_confirmation_days = 3;
input double strategy_beta_threshold    = 0.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input int    strategy_time_stop_bars    = 60;

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

double GetSZBeta(int shift)
{
   if (shift + strategy_moving_window_n >= iBars(_Symbol, PERIOD_D1)) return -999.0;
   
   double sum_r = 0.0;
   double r_array[];
   ArrayResize(r_array, strategy_moving_window_n);
   
   for (int i = 0; i < strategy_moving_window_n; i++)
   {
      double curr = iClose(_Symbol, PERIOD_D1, shift + i);
      double prev = iClose(_Symbol, PERIOD_D1, shift + i + 1);
      
      if (prev <= 0.0 || curr <= 0.0) return -999.0; // Error
      
      double r = MathLog(curr / prev);
      r_array[i] = r;
      sum_r += r;
   }
   
   double r_mean = sum_r / strategy_moving_window_n;
   
   double sum_sq_diff = 0.0;
   for (int i = 0; i < strategy_moving_window_n; i++)
   {
      sum_sq_diff += MathPow(r_array[i] - r_mean, 2);
   }
   
   double s_sq = sum_sq_diff / (strategy_moving_window_n - 1);
   
   double mu_hat = strategy_trading_days_yr * r_mean;
   double sigma_sq_hat = strategy_trading_days_yr * s_sq;
   
   if (sigma_sq_hat == 0) return -999.0;
   
   double beta_hat = (mu_hat / sigma_sq_hat) - 0.5;
   return beta_hat;
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

   // Get Beta for today (shift 1), yesterday (shift 2), day before (shift 3), and day before that (shift 4)
   double beta1 = GetSZBeta(1);
   double beta2 = GetSZBeta(2);
   double beta3 = GetSZBeta(3);
   double beta4 = GetSZBeta(4);
   
   if (beta1 == -999.0 || beta2 == -999.0 || beta3 == -999.0 || beta4 == -999.0) return false;
   
   const double atr1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if (atr1 <= 0.0) return false;

   // Bullish: 3 consecutive days >= threshold, but the 4th day was NOT.
   bool signal_long = (beta1 >= strategy_beta_threshold && 
                       beta2 >= strategy_beta_threshold && 
                       beta3 >= strategy_beta_threshold && 
                       beta4 < strategy_beta_threshold);
                       
   // Bearish: 3 consecutive days < threshold, but the 4th day was NOT.
   bool signal_short = (beta1 < strategy_beta_threshold && 
                        beta2 < strategy_beta_threshold && 
                        beta3 < strategy_beta_threshold && 
                        beta4 >= strategy_beta_threshold);

   if(!signal_long && !signal_short) return false;

   QM_OrderType side = signal_long ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr1, strategy_atr_sl_mult);
   if(sl <= 0.0) return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "SZ_INDEX_LONG" : "SZ_INDEX_SHORT";
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

      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_D1, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }
      
      // Opposite signal exit (Flip)
      double beta1 = GetSZBeta(1);
      double beta2 = GetSZBeta(2);
      double beta3 = GetSZBeta(3);
      
      if (beta1 == -999.0 || beta2 == -999.0 || beta3 == -999.0) continue;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(ptype == POSITION_TYPE_BUY)
      {
         // Exit if bearish condition met (3 days negative)
         if (beta1 < strategy_beta_threshold && beta2 < strategy_beta_threshold && beta3 < strategy_beta_threshold)
            return true;
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         // Exit if bullish condition met (3 days non-negative)
         if (beta1 >= strategy_beta_threshold && beta2 >= strategy_beta_threshold && beta3 >= strategy_beta_threshold)
            return true;
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

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
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
