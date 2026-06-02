#property strict
#property version   "5.0"
#property description "QM5_10769_v2 TradingView Axis Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10769;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_axis_sensitivity       = 20;
input int    strategy_rsi_period             = 14;
input double strategy_rsi_long_threshold     = 30.0;
input double strategy_rsi_short_threshold    = 70.0;
input int    strategy_rsi_sync_bars          = 3;
input int    strategy_supertrend_atr_period  = 10;
input double strategy_supertrend_multiplier  = 3.0;
input int    strategy_supertrend_warmup_bars = 80;
input int    strategy_atr_stop_period        = 14;
input double strategy_atr_stop_buffer        = 0.5;
input double strategy_rr_target              = 2.0;
input bool   strategy_exit_on_opposite_supertrend = false;

bool   g_axis_long_armed = false;
bool   g_axis_short_armed = false;
double g_axis_long_extreme = 0.0;
double g_axis_short_extreme = 0.0;
bool   g_exit_long_on_flip = false;
bool   g_exit_short_on_flip = false;

int Strategy_ActiveSupertrend(const MqlRates &rates[], const int count, int &prev_trend)
  {
   prev_trend = 0;
   if(count < 3 || strategy_supertrend_atr_period < 1 || strategy_supertrend_multiplier <= 0.0)
      return 0;

   bool initialized = false;
   double prev_final_upper = 0.0;
   double prev_final_lower = 0.0;
   double prev_close = 0.0;
   int trend = 0;

   for(int i = count - 1; i >= 0; --i)
     {
      const int shift = i + 1;
      const double atr = QM_ATR(_Symbol, _Period, strategy_supertrend_atr_period, shift);
      if(atr <= 0.0)
         continue;

      const double mid = (rates[i].high + rates[i].low) * 0.5;
      const double basic_upper = mid + strategy_supertrend_multiplier * atr;
      const double basic_lower = mid - strategy_supertrend_multiplier * atr;

      if(!initialized)
        {
         prev_final_upper = basic_upper;
         prev_final_lower = basic_lower;
         trend = (rates[i].close >= mid) ? 1 : -1;
         prev_close = rates[i].close;
         initialized = true;
        }
      else
        {
         const double final_upper = (basic_upper < prev_final_upper || prev_close > prev_final_upper)
                                    ? basic_upper : prev_final_upper;
         const double final_lower = (basic_lower > prev_final_lower || prev_close < prev_final_lower)
                                    ? basic_lower : prev_final_lower;

         if(trend < 0 && rates[i].close > final_upper)
            trend = 1;
         else if(trend > 0 && rates[i].close < final_lower)
            trend = -1;

         prev_final_upper = final_upper;
         prev_final_lower = final_lower;
         prev_close = rates[i].close;
        }

      if(i == 1)
         prev_trend = trend;
     }

   return trend;
  }

bool Strategy_RsiTouched(const bool long_side)
  {
   const int window = (strategy_rsi_sync_bars > 1) ? strategy_rsi_sync_bars : 1;
   for(int shift = 1; shift <= window; ++shift)
     {
      const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, shift);
      if(rsi <= 0.0)
         continue;
      if(long_side && rsi <= strategy_rsi_long_threshold)
         return true;
      if(!long_side && rsi >= strategy_rsi_short_threshold)
         return true;
     }
   return false;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
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
   g_exit_long_on_flip = false;
   g_exit_short_on_flip = false;

   const int axis_bars = (strategy_axis_sensitivity > 2) ? strategy_axis_sensitivity : 2;
   const int min_warmup = axis_bars + 5;
   const int warmup_bars = (strategy_supertrend_warmup_bars > min_warmup) ? strategy_supertrend_warmup_bars : min_warmup;
   const int bars_needed = warmup_bars + 2;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, bars_needed, rates); // perf-allowed: caller is behind the framework QM_IsNewBar() closed-bar gate.
   if(copied < axis_bars + 2)
      return false;

   double axis_low = DBL_MAX;
   double axis_high = -DBL_MAX;
   for(int i = 1; i <= axis_bars && i < copied; ++i)
     {
      axis_low = MathMin(axis_low, rates[i].low);
      axis_high = MathMax(axis_high, rates[i].high);
     }

   if(axis_low == DBL_MAX || axis_high == -DBL_MAX)
      return false;

   const bool lower_axis_breached = (rates[0].low < axis_low);
   const bool upper_axis_breached = (rates[0].high > axis_high);
   if(lower_axis_breached)
     {
      g_axis_long_armed = true;
      g_axis_short_armed = false;
      g_axis_long_extreme = rates[0].low;
     }
   if(upper_axis_breached)
     {
      g_axis_short_armed = true;
      g_axis_long_armed = false;
      g_axis_short_extreme = rates[0].high;
     }

   int prev_trend = 0;
   const int st_count = (copied < bars_needed) ? copied : bars_needed;
   const int current_trend = Strategy_ActiveSupertrend(rates, st_count, prev_trend);
   const bool bullish_flip = (prev_trend < 0 && current_trend > 0);
   const bool bearish_flip = (prev_trend > 0 && current_trend < 0);
   g_exit_long_on_flip = bearish_flip;
   g_exit_short_on_flip = bullish_flip;

   if(Strategy_HasOpenPosition())
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double atr_stop = QM_ATR(_Symbol, _Period, strategy_atr_stop_period, 1);
   if(atr_stop <= 0.0 || strategy_atr_stop_buffer <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_axis_long_armed && Strategy_RsiTouched(true) && bullish_flip)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_axis_long_extreme - atr_stop * strategy_atr_stop_buffer);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_rr_target);
      req.reason = "AXIS_REV_LONG";
      if(req.sl > 0.0 && req.tp > 0.0 && req.sl < req.price)
        {
         g_axis_long_armed = false;
         return true;
        }
     }

   if(g_axis_short_armed && Strategy_RsiTouched(false) && bearish_flip)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_axis_short_extreme + atr_stop * strategy_atr_stop_buffer);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_rr_target);
      req.reason = "AXIS_REV_SHORT";
      if(req.sl > 0.0 && req.tp > 0.0 && req.sl > req.price)
        {
         g_axis_short_armed = false;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!strategy_exit_on_opposite_supertrend)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_exit_long_on_flip)
         return true;
      if(type == POSITION_TYPE_SELL && g_exit_short_on_flip)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10769_tv-axis-rev\"}");
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
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
