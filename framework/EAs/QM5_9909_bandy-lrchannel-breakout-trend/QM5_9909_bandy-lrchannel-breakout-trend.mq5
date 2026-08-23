#property strict
#property version   "5.0"
#property description "QM5_9909 Bandy Linear Regression Channel Breakout Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9909
// Strategy Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9909_bandy-lrchannel-breakout-trend.md
// Source: Howard B. Bandy, "Quantitative Technical Analysis", 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9909;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
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
input int    strategy_lr_window         = 50;
input double strategy_channel_sigma     = 2.0;
input int    strategy_atr_period        = 14;
input double strategy_trail_atr_mult    = 2.5;
input double strategy_sl_atr_mult       = 5.0;
input int    strategy_time_stop_bars    = 40;
input double strategy_spread_max_atr    = 0.30;
input int    strategy_warmup_bars       = 60;

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

bool ComputeLinearRegressionChannel(const string sym, const ENUM_TIMEFRAMES tf,
                                    const int window, const double sigma,
                                    double &out_center, double &out_upper, double &out_lower)
{
   if(window <= 2 || iBars(sym, tf) < (window + 1))
      return false;

   double sum_y = 0.0;
   double sum_ty = 0.0;
   const double sum_t = (double)(window - 1) * (double)window / 2.0;
   const double sum_t2 = (double)(window - 1) * (double)window * (double)(2 * window - 1) / 6.0;

   // Sample closed bars: t=0 is oldest bar (shift window), t=window-1 is newest closed bar (shift 1)
   for(int i = 0; i < window; ++i)
   {
      const double y = iClose(sym, tf, window - i);
      if(y <= 0.0)
         return false;
      sum_y += y;
      sum_ty += (double)i * y;
   }

   const double denom = (double)window * sum_t2 - sum_t * sum_t;
   if(denom == 0.0)
      return false;

   const double b = ((double)window * sum_ty - sum_t * sum_y) / denom;
   const double a = (sum_y - b * sum_t) / (double)window;

   out_center = a + b * (double)(window - 1);

   // Residual standard deviation
   double sum_res2 = 0.0;
   for(int i = 0; i < window; ++i)
   {
      const double y = iClose(sym, tf, window - i);
      const double y_hat = a + b * (double)i;
      const double res = y - y_hat;
      sum_res2 += res * res;
   }

   const double resid_sd = MathSqrt(sum_res2 / (double)(window - 1));
   out_upper = out_center + sigma * resid_sd;
   out_lower = out_center - sigma * resid_sd;

   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr > 0.0 && ask > bid && (ask - bid) > (strategy_spread_max_atr * atr))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   double lr_center = 0.0, lr_upper = 0.0, lr_lower = 0.0;
   if(!ComputeLinearRegressionChannel(_Symbol, PERIOD_D1, strategy_lr_window, strategy_channel_sigma,
                                      lr_center, lr_upper, lr_lower))
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   if(close1 <= 0.0 || lr_upper <= 0.0 || lr_lower <= 0.0)
      return false;

   // Long breakout: Close > Upper Channel
   if(close1 > lr_upper)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_trail_atr_mult);
      req.tp = 0.0;
      req.reason = "BANDY_LRC_BREAKOUT_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short breakout: Close < Lower Channel
   if(close1 < lr_lower)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_trail_atr_mult);
      req.tp = 0.0;
      req.reason = "BANDY_LRC_BREAKOUT_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double atr    = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      if(bars_held >= strategy_time_stop_bars)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      // Chandelier ATR trailing stop
      if(close1 > 0.0 && atr > 0.0)
      {
         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double current_sl = PositionGetDouble(POSITION_SL);

         if(ptype == POSITION_TYPE_BUY)
         {
            const double new_sl = close1 - strategy_trail_atr_mult * atr;
            if(new_sl > current_sl)
            {
               QM_TM_MoveSL(ticket, new_sl, "LRC_ATR_TRAIL");
            }
         }
         else if(ptype == POSITION_TYPE_SELL)
         {
            const double new_sl = close1 + strategy_trail_atr_mult * atr;
            if(current_sl == 0.0 || new_sl < current_sl)
            {
               QM_TM_MoveSL(ticket, new_sl, "LRC_ATR_TRAIL");
            }
         }
      }
   }
}

bool Strategy_ExitSignal()
{
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
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer()
{
   QM_FrameworkOnTimer();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   QM_FrameworkOnTradeTransaction(trans, request, result);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
