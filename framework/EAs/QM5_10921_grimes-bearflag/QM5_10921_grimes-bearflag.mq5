#property strict
#property version   "5.0"
#property description "QM5_10921 Grimes Momentum Bear Flag"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10921;
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
input int    strategy_keltner_period       = 20;
input double strategy_keltner_atr_mult     = 2.25;
input int    strategy_break_lookback       = 20;
input int    strategy_break_recent_bars    = 10;
input int    strategy_macd_fast            = 12;
input int    strategy_macd_slow            = 26;
input int    strategy_macd_signal          = 9;
input int    strategy_macd_extreme_lookback = 60;
input int    strategy_macd_near_bars       = 3;
input int    strategy_bounce_min_bars      = 2;
input int    strategy_bounce_max_bars      = 8;
input double strategy_max_retrace          = 0.50;
input double strategy_reject_retrace       = 0.618;
input int    strategy_atr_period           = 14;
input double strategy_stop_atr_buffer      = 0.25;
input double strategy_max_stop_atr         = 3.0;
input double strategy_target_r             = 1.0;
input double strategy_trail_atr_mult       = 2.0;
input int    strategy_max_hold_bars        = 10;
input double strategy_spread_stop_fraction = 0.10;

// perf-allowed: these raw OHLC reads are the card's bespoke D1 flag-structure
// scan. They are called only from Strategy_EntrySignal(), which the V5 skeleton
// invokes after QM_IsNewBar(), so the bounded loops run once per closed bar.
double BarClose(const int shift)
  {
   return iClose(_Symbol, _Period, shift);
  }

double BarHigh(const int shift)
  {
   return iHigh(_Symbol, _Period, shift);
  }

double BarLow(const int shift)
  {
   return iLow(_Symbol, _Period, shift);
  }

double HighestHigh(const int start_shift, const int count)
  {
   if(start_shift < 1 || count <= 0)
      return 0.0;
   double value = -DBL_MAX;
   for(int i = 0; i < count; ++i)
     {
      const double h = BarHigh(start_shift + i);
      if(h <= 0.0)
         return 0.0;
      value = MathMax(value, h);
     }
   return value;
  }

double LowestLow(const int start_shift, const int count)
  {
   if(start_shift < 1 || count <= 0)
      return 0.0;
   double value = DBL_MAX;
   for(int i = 0; i < count; ++i)
     {
      const double l = BarLow(start_shift + i);
      if(l <= 0.0)
         return 0.0;
      value = MathMin(value, l);
     }
   return value;
  }

double HighestClose(const int start_shift, const int count)
  {
   if(start_shift < 1 || count <= 0)
      return 0.0;
   double value = -DBL_MAX;
   for(int i = 0; i < count; ++i)
     {
      const double c = BarClose(start_shift + i);
      if(c <= 0.0)
         return 0.0;
      value = MathMax(value, c);
     }
   return value;
  }

double LowestClose(const int start_shift, const int count)
  {
   if(start_shift < 1 || count <= 0)
      return 0.0;
   double value = DBL_MAX;
   for(int i = 0; i < count; ++i)
     {
      const double c = BarClose(start_shift + i);
      if(c <= 0.0)
         return 0.0;
      value = MathMin(value, c);
     }
   return value;
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

bool HasOurOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool SpreadWithinStopCap(const double stop_distance)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid || stop_distance <= 0.0)
      return false;
   return ((ask - bid) <= stop_distance * strategy_spread_stop_fraction);
  }

bool MacdIsLowestAt(const int shift)
  {
   const double candidate = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal,
                                         shift);
   double low = candidate;
   for(int i = 1; i < strategy_macd_extreme_lookback; ++i)
     {
      const double value = QM_MACD_Main(_Symbol, _Period,
                                        strategy_macd_fast,
                                        strategy_macd_slow,
                                        strategy_macd_signal,
                                        shift + i);
      low = MathMin(low, value);
     }
   return (candidate <= low);
  }

bool MacdIsHighestAt(const int shift)
  {
   const double candidate = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal,
                                         shift);
   double high = candidate;
   for(int i = 1; i < strategy_macd_extreme_lookback; ++i)
     {
      const double value = QM_MACD_Main(_Symbol, _Period,
                                        strategy_macd_fast,
                                        strategy_macd_slow,
                                        strategy_macd_signal,
                                        shift + i);
      high = MathMax(high, value);
     }
   return (candidate >= high);
  }

bool MacdLowNearBreakdown(const int breakdown_shift)
  {
   const int from_shift = MathMax(1, breakdown_shift - strategy_macd_near_bars);
   const int to_shift = breakdown_shift + strategy_macd_near_bars;
   for(int shift = from_shift; shift <= to_shift; ++shift)
     {
      if(MacdIsLowestAt(shift))
         return true;
     }
   return false;
  }

bool MacdHighNearBreakout(const int breakout_shift)
  {
   const int from_shift = MathMax(1, breakout_shift - strategy_macd_near_bars);
   const int to_shift = breakout_shift + strategy_macd_near_bars;
   for(int shift = from_shift; shift <= to_shift; ++shift)
     {
      if(MacdIsHighestAt(shift))
         return true;
     }
   return false;
  }

void ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildShortRequest(QM_EntryRequest &req)
  {
   const double trigger_close = BarClose(1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(trigger_close <= 0.0 || bid <= 0.0)
      return false;

   for(int bounce_len = strategy_bounce_min_bars;
       bounce_len <= strategy_bounce_max_bars;
       ++bounce_len)
     {
      const int breakdown_shift = bounce_len + 2;
      if(breakdown_shift > strategy_break_recent_bars)
         continue;

      const double breakdown_close = BarClose(breakdown_shift);
      const double breakdown_low = BarLow(breakdown_shift);
      const double prior_low_close = LowestClose(breakdown_shift + 1, strategy_break_lookback);
      if(breakdown_close <= 0.0 || breakdown_low <= 0.0 || prior_low_close <= 0.0)
         continue;
      if(breakdown_close >= prior_low_close)
         continue;

      const double mid = QM_EMA(_Symbol, _Period, strategy_keltner_period, breakdown_shift);
      const double atr20 = QM_ATR(_Symbol, _Period, strategy_keltner_period, breakdown_shift);
      if(mid <= 0.0 || atr20 <= 0.0)
         continue;
      const double lower = mid - strategy_keltner_atr_mult * atr20;
      if(breakdown_low > lower && breakdown_close > lower)
         continue;
      if(!MacdLowNearBreakdown(breakdown_shift))
         continue;

      const double bounce_high = HighestHigh(2, bounce_len);
      const double bounce_low = LowestLow(2, bounce_len);
      if(bounce_high <= 0.0 || bounce_low <= 0.0 || trigger_close >= bounce_low)
         continue;

      const double impulse_high = HighestHigh(breakdown_shift + 1, strategy_break_lookback);
      if(impulse_high <= breakdown_low)
         continue;
      const double retrace = (bounce_high - breakdown_low) / (impulse_high - breakdown_low);
      if(retrace > strategy_max_retrace || retrace > strategy_reject_retrace)
         continue;

      const double atr14 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr14 <= 0.0)
         continue;
      const double sl = NormalizeStrategyPrice(bounce_high + strategy_stop_atr_buffer * atr14);
      const double stop_distance = sl - bid;
      if(stop_distance <= 0.0 || stop_distance > strategy_max_stop_atr * atr14)
         continue;
      if(!SpreadWithinStopCap(stop_distance))
         continue;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "GRIMES_BEARFLAG_SHORT";
      return true;
     }

   return false;
  }

bool BuildLongRequest(QM_EntryRequest &req)
  {
   const double trigger_close = BarClose(1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(trigger_close <= 0.0 || ask <= 0.0)
      return false;

   for(int bounce_len = strategy_bounce_min_bars;
       bounce_len <= strategy_bounce_max_bars;
       ++bounce_len)
     {
      const int breakout_shift = bounce_len + 2;
      if(breakout_shift > strategy_break_recent_bars)
         continue;

      const double breakout_close = BarClose(breakout_shift);
      const double breakout_high = BarHigh(breakout_shift);
      const double prior_high_close = HighestClose(breakout_shift + 1, strategy_break_lookback);
      if(breakout_close <= 0.0 || breakout_high <= 0.0 || prior_high_close <= 0.0)
         continue;
      if(breakout_close <= prior_high_close)
         continue;

      const double mid = QM_EMA(_Symbol, _Period, strategy_keltner_period, breakout_shift);
      const double atr20 = QM_ATR(_Symbol, _Period, strategy_keltner_period, breakout_shift);
      if(mid <= 0.0 || atr20 <= 0.0)
         continue;
      const double upper = mid + strategy_keltner_atr_mult * atr20;
      if(breakout_high < upper && breakout_close < upper)
         continue;
      if(!MacdHighNearBreakout(breakout_shift))
         continue;

      const double pullback_high = HighestHigh(2, bounce_len);
      const double pullback_low = LowestLow(2, bounce_len);
      if(pullback_high <= 0.0 || pullback_low <= 0.0 || trigger_close <= pullback_high)
         continue;

      const double impulse_low = LowestLow(breakout_shift + 1, strategy_break_lookback);
      if(impulse_low <= 0.0 || breakout_high <= impulse_low)
         continue;
      const double retrace = (breakout_high - pullback_low) / (breakout_high - impulse_low);
      if(retrace > strategy_max_retrace || retrace > strategy_reject_retrace)
         continue;

      const double atr14 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr14 <= 0.0)
         continue;
      const double sl = NormalizeStrategyPrice(pullback_low - strategy_stop_atr_buffer * atr14);
      const double stop_distance = ask - sl;
      if(stop_distance <= 0.0 || stop_distance > strategy_max_stop_atr * atr14)
         continue;
      if(!SpreadWithinStopCap(stop_distance))
         continue;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "GRIMES_BEARFLAG_LONG";
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
   ResetRequest(req);

   if(HasOurOpenPosition())
      return false;
   if(strategy_bounce_min_bars < 1 ||
      strategy_bounce_max_bars < strategy_bounce_min_bars ||
      strategy_break_lookback < 1 ||
      strategy_macd_extreme_lookback < 2 ||
      strategy_target_r <= 0.0 ||
      strategy_spread_stop_fraction <= 0.0)
      return false;

   if(BuildShortRequest(req))
      return true;

   ResetRequest(req);
   if(BuildLongRequest(req))
      return true;

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

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
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double initial_r = MathAbs(open_price - current_sl);
      if(initial_r <= 0.0)
         continue;

      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double target = is_buy ? (open_price + strategy_target_r * initial_r)
                                   : (open_price - strategy_target_r * initial_r);
      const double close1 = BarClose(1);
      const double high1 = BarHigh(1);
      const double low1 = BarLow(1);
      if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
         continue;

      const bool touched_target = is_buy ? (high1 >= target) : (low1 <= target);
      if(!touched_target)
         continue;

      const bool closed_beyond_target = is_buy ? (close1 >= target) : (close1 <= target);
      if(closed_beyond_target)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
      else
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_max_hold_bars <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(PERIOD_D1);
   if(seconds_per_bar <= 0)
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && TimeCurrent() - open_time >= strategy_max_hold_bars * seconds_per_bar)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10921_grimes_bearflag\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
