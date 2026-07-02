#property strict
#property version   "5.0"
#property description "QM5_9350 Brooks Failed TTR H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9350;
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
input int    strategy_donchian_period       = 20;
input int    strategy_atr_period            = 14;
input int    strategy_min_small_bodies      = 14;
input double strategy_range_atr_mult        = 1.5;
input double strategy_body_atr_mult         = 0.4;
input double strategy_envelope_atr_mult     = 0.1;
input double strategy_breakout_atr_mult     = 0.2;
input double strategy_failure_inside_atr    = 0.5;
input double strategy_stop_buffer_atr       = 0.3;
input double strategy_target_extension_atr  = 1.0;
input double strategy_max_spread_atr_mult   = 0.20;
input int    strategy_breakout_window_bars  = 20;
input int    strategy_failure_window_bars   = 8;
input int    strategy_time_stop_bars        = 30;

enum TtrSetupState
  {
   TTR_SCAN = 0,
   TTR_LOCKED = 1,
   TTR_BREAKOUT = 2
  };

MqlRates      g_rates[];
TtrSetupState g_state = TTR_SCAN;
int           g_bars_since_lock = 0;
int           g_bars_since_breakout = 0;
int           g_breakout_side = 0; // +1 = up breakout, -1 = down breakout.
double        g_ttr_high = 0.0;
double        g_ttr_low = 0.0;
double        g_breakout_extreme = 0.0;

void ResetSetup()
  {
   g_state = TTR_SCAN;
   g_bars_since_lock = 0;
   g_bars_since_breakout = 0;
   g_breakout_side = 0;
   g_ttr_high = 0.0;
   g_ttr_low = 0.0;
   g_breakout_extreme = 0.0;
  }

bool LoadClosedRates(const int bars_needed)
  {
   if(bars_needed <= 0)
      return false;
   ArrayFree(g_rates);
   ArraySetAsSeries(g_rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, bars_needed, g_rates); // perf-allowed: H4 closed-bar structural pattern scan.
   return (copied >= bars_needed);
  }

bool DonchianRange(const int bars, double &out_high, double &out_low)
  {
   out_high = -DBL_MAX;
   out_low = DBL_MAX;
   if(bars <= 0 || ArraySize(g_rates) < bars)
      return false;

   for(int i = 0; i < bars; ++i)
     {
      if(g_rates[i].high <= 0.0 || g_rates[i].low <= 0.0)
         return false;
      if(g_rates[i].high > out_high)
         out_high = g_rates[i].high;
      if(g_rates[i].low < out_low)
         out_low = g_rates[i].low;
     }

   return (out_high > out_low && out_low > 0.0);
  }

bool DetectTtrFormation(const double atr_value, double &out_high, double &out_low)
  {
   if(atr_value <= 0.0 || strategy_donchian_period < 2)
      return false;
   if(!DonchianRange(strategy_donchian_period, out_high, out_low))
      return false;

   const double width = out_high - out_low;
   if(width > strategy_range_atr_mult * atr_value)
      return false;

   int small_bodies = 0;
   for(int i = 0; i < strategy_donchian_period; ++i)
     {
      const double body = MathAbs(g_rates[i].close - g_rates[i].open);
      if(body <= strategy_body_atr_mult * atr_value)
         small_bodies++;

      if(g_rates[i].high > out_high + strategy_envelope_atr_mult * atr_value)
         return false;
      if(g_rates[i].low < out_low - strategy_envelope_atr_mult * atr_value)
         return false;
     }

   return (small_bodies >= strategy_min_small_bodies);
  }

bool SpreadAllowsEntry(const double atr_value)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || atr_value <= 0.0)
      return false;
   if(ask > bid && (ask - bid) > strategy_max_spread_atr_mult * atr_value)
      return false;
   return true;
  }

bool FillFailureEntry(QM_EntryRequest &req, const bool sell_failure, const double atr_value)
  {
   if(!SpreadAllowsEntry(atr_value))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const QM_OrderType side = sell_failure ? QM_SELL : QM_BUY;
   const double entry_price = sell_failure ? bid : ask;
   if(entry_price <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(sell_failure)
     {
      sl = MathMax(entry_price, g_breakout_extreme) + strategy_stop_buffer_atr * atr_value;
      tp = g_ttr_low - strategy_target_extension_atr * atr_value;
      if(sl <= entry_price || tp >= entry_price)
         return false;
      req.reason = "BROOKS_TTR_UP_BREAKOUT_FAILURE_SELL";
     }
   else
     {
      sl = MathMin(entry_price, g_breakout_extreme) - strategy_stop_buffer_atr * atr_value;
      tp = g_ttr_high + strategy_target_extension_atr * atr_value;
      if(sl >= entry_price || tp <= entry_price)
         return false;
      req.reason = "BROOKS_TTR_DOWN_BREAKOUT_FAILURE_BUY";
     }

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ResetSetup();
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_H4);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int bars_needed = strategy_donchian_period + strategy_breakout_window_bars + strategy_failure_window_bars + 5;
   if(!LoadClosedRates(bars_needed))
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(g_state == TTR_SCAN)
     {
      double dc_high = 0.0;
      double dc_low = 0.0;
      if(DetectTtrFormation(atr_value, dc_high, dc_low))
        {
         g_ttr_high = dc_high;
         g_ttr_low = dc_low;
         g_bars_since_lock = 0;
         g_state = TTR_LOCKED;
        }
      return false;
     }

   if(g_state == TTR_LOCKED)
     {
      g_bars_since_lock++;
      if(g_bars_since_lock > strategy_breakout_window_bars)
        {
         ResetSetup();
         return false;
        }

      const double close_1 = g_rates[0].close;
      if(close_1 > g_ttr_high + strategy_breakout_atr_mult * atr_value)
        {
         g_breakout_side = 1;
         g_breakout_extreme = g_rates[0].high;
         g_bars_since_breakout = 0;
         g_state = TTR_BREAKOUT;
        }
      else if(close_1 < g_ttr_low - strategy_breakout_atr_mult * atr_value)
        {
         g_breakout_side = -1;
         g_breakout_extreme = g_rates[0].low;
         g_bars_since_breakout = 0;
         g_state = TTR_BREAKOUT;
        }
      return false;
     }

   if(g_state == TTR_BREAKOUT)
     {
      g_bars_since_breakout++;
      if(g_bars_since_breakout > strategy_failure_window_bars)
        {
         ResetSetup();
         return false;
        }

      const double open_1 = g_rates[0].open;
      const double close_1 = g_rates[0].close;
      const double high_1 = g_rates[0].high;
      const double low_1 = g_rates[0].low;

      if(g_breakout_side > 0)
        {
         if(close_1 > g_breakout_extreme)
           {
            ResetSetup();
            return false;
           }
         if(high_1 > g_breakout_extreme)
            g_breakout_extreme = high_1;

         const bool failed_back_inside = (close_1 < g_ttr_high &&
                                          close_1 < open_1 &&
                                          low_1 <= g_ttr_high - strategy_failure_inside_atr * atr_value);
         if(failed_back_inside)
            return FillFailureEntry(req, true, atr_value);
        }
      else if(g_breakout_side < 0)
        {
         if(close_1 < g_breakout_extreme)
           {
            ResetSetup();
            return false;
           }
         if(low_1 < g_breakout_extreme)
            g_breakout_extreme = low_1;

         const bool failed_back_inside = (close_1 > g_ttr_low &&
                                          close_1 > open_1 &&
                                          high_1 >= g_ttr_low + strategy_failure_inside_atr * atr_value);
         if(failed_back_inside)
            return FillFailureEntry(req, false, atr_value);
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int timeout_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_H4);
   if(timeout_seconds <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && TimeCurrent() - opened_at >= timeout_seconds)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9350_brooks_failed_ttr_h4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management runs regardless of news — stops must stay active through news windows.
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // News gate — entry path only.
   if(Strategy_NewsFilterHook(broker_now))
      return;
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

