#property strict
#property version   "5.0"
#property description "QM5_12550 ICT London Close Reversal M15"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12550;
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
input int    strategy_atr_period              = 14;
input double strategy_ote_fraction            = 0.705;
input double strategy_ote_zone_low            = 0.620;
input double strategy_ote_zone_high           = 0.795;
input double strategy_stop_atr_buffer         = 0.30;
input int    strategy_london_open_gmt_h       = 9;
input int    strategy_london_open_gmt_m       = 0;
input int    strategy_london_build_end_gmt_h  = 15;
input int    strategy_london_build_end_gmt_m  = 0;
input int    strategy_close_start_gmt_h       = 15;
input int    strategy_close_start_gmt_m       = 0;
input int    strategy_close_end_gmt_h         = 17;
input int    strategy_close_end_gmt_m         = 30;
input int    strategy_asian_start_gmt_h       = 0;
input int    strategy_asian_end_gmt_h         = 9;
input int    strategy_m15_scan_bars           = 160;
input int    strategy_mss_max_bars            = 10;
input int    strategy_swing_scan_bars         = 24;
input int    strategy_d1_pivot_lookback       = 80;
input int    strategy_h4_ote_lookback         = 60;
input int    strategy_limit_valid_bars        = 3;
input double strategy_runner_rr_fallback      = 2.0;
input double strategy_partial_fraction        = 0.50;
input double strategy_atr_trail_mult          = 1.0;
input int    strategy_max_spread_points       = 80;

struct StrategySessionState
  {
   bool   ready;
   int    day_key;
   double asia_high;
   double asia_low;
   double london_open;
   double london_high;
   double london_low;
   double prior_day_high;
   double prior_day_low;
   bool   london_buy_day;
   bool   london_sell_day;
  };

double g_pending_tp1 = 0.0;
double g_active_tp1 = 0.0;
ulong  g_active_ticket = 0;
bool   g_partial_done = false;
int    g_entry_day_key = 0;

int Strategy_MinutesOfDayUTC(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DayKeyUTC(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_Minutes(const int hour, const int minute)
  {
   return hour * 60 + minute;
  }

bool Strategy_InUTCWindow(const datetime broker_time,
                          const int start_h,
                          const int start_m,
                          const int end_h,
                          const int end_m)
  {
   const int now_m = Strategy_MinutesOfDayUTC(broker_time);
   const int start = Strategy_Minutes(start_h, start_m);
   const int end = Strategy_Minutes(end_h, end_m);
   if(start == end)
      return true;
   if(start < end)
      return (now_m >= start && now_m < end);
   return (now_m >= start || now_m < end);
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_LoadRates(const ENUM_TIMEFRAMES tf,
                        const int start_shift,
                        const int count,
                        MqlRates &rates[])
  {
   ArrayResize(rates, 0);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, start_shift, count, rates); // perf-allowed: bounded ICT structure scan; called only after the framework QM_IsNewBar gate.
   return (copied >= count);
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

void Strategy_RemoveExpiredPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_LIMIT && order_type != ORDER_TYPE_SELL_LIMIT)
         continue;
      const datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      if(expiration > 0 && TimeCurrent() > expiration)
         QM_TM_RemovePendingOrder(ticket, "london_close_limit_expired");
     }
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &pos_type,
                                double &volume,
                                double &open_price,
                                double &sl)
  {
   ticket = 0;
   pos_type = POSITION_TYPE_BUY;
   volume = 0.0;
   open_price = 0.0;
   sl = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      return true;
     }
   return false;
  }

bool Strategy_PreviousDayLevels(double &pdh, double &pdl)
  {
   pdh = 0.0;
   pdl = 0.0;
   MqlRates d1[];
   if(!Strategy_LoadRates(PERIOD_D1, 1, 1, d1))
      return false;
   pdh = d1[0].high;
   pdl = d1[0].low;
   return (pdh > pdl && pdl > 0.0);
  }

bool Strategy_BuildSessionState(const MqlRates &m15[],
                                const int day_key,
                                StrategySessionState &state)
  {
   state.ready = false;
   state.day_key = day_key;
   state.asia_high = -DBL_MAX;
   state.asia_low = DBL_MAX;
   state.london_open = 0.0;
   state.london_high = -DBL_MAX;
   state.london_low = DBL_MAX;
   state.prior_day_high = 0.0;
   state.prior_day_low = 0.0;
   state.london_buy_day = false;
   state.london_sell_day = false;

   if(!Strategy_PreviousDayLevels(state.prior_day_high, state.prior_day_low))
      return false;

   const int asia_start = Strategy_Minutes(strategy_asian_start_gmt_h, 0);
   const int asia_end = Strategy_Minutes(strategy_asian_end_gmt_h, 0);
   const int london_start = Strategy_Minutes(strategy_london_open_gmt_h, strategy_london_open_gmt_m);
   const int london_end = Strategy_Minutes(strategy_london_build_end_gmt_h, strategy_london_build_end_gmt_m);

   datetime london_open_time = 0;
   int asia_count = 0;
   int london_count = 0;

   for(int i = 0; i < ArraySize(m15); ++i)
     {
      if(Strategy_DayKeyUTC(m15[i].time) != day_key)
         continue;

      const int minute = Strategy_MinutesOfDayUTC(m15[i].time);
      if(minute >= asia_start && minute < asia_end)
        {
         state.asia_high = MathMax(state.asia_high, m15[i].high);
         state.asia_low = MathMin(state.asia_low, m15[i].low);
         asia_count++;
        }

      if(minute >= london_start && minute < london_end)
        {
         state.london_high = MathMax(state.london_high, m15[i].high);
         state.london_low = MathMin(state.london_low, m15[i].low);
         london_count++;
         if(london_open_time == 0 || m15[i].time < london_open_time)
           {
            london_open_time = m15[i].time;
            state.london_open = m15[i].open;
           }
        }
     }

   if(asia_count < 8 || london_count < 12 ||
      state.london_open <= 0.0 ||
      state.asia_high <= 0.0 || state.asia_low >= DBL_MAX ||
      state.london_high <= 0.0 || state.london_low >= DBL_MAX)
      return false;

   state.london_buy_day = (state.london_high > state.asia_high &&
                           state.london_high > state.prior_day_high &&
                           state.london_high > state.london_open);
   state.london_sell_day = (state.london_low < state.asia_low &&
                            state.london_low < state.prior_day_low &&
                            state.london_low < state.london_open);
   state.ready = true;
   return true;
  }

bool Strategy_IsPivotLow(const MqlRates &rates[], const int index)
  {
   if(index <= 0 || index >= ArraySize(rates) - 1)
      return false;
   return (rates[index].low < rates[index - 1].low && rates[index].low < rates[index + 1].low);
  }

bool Strategy_IsPivotHigh(const MqlRates &rates[], const int index)
  {
   if(index <= 0 || index >= ArraySize(rates) - 1)
      return false;
   return (rates[index].high > rates[index - 1].high && rates[index].high > rates[index + 1].high);
  }

bool Strategy_D1BearishBias()
  {
   MqlRates d1[];
   const int need = MathMax(20, strategy_d1_pivot_lookback);
   if(!Strategy_LoadRates(PERIOD_D1, 1, need, d1))
      return false;

   double recent_high = 0.0;
   double prior_high = 0.0;
   double recent_low = 0.0;
   double prior_low = 0.0;

   for(int i = 1; i < ArraySize(d1) - 1; ++i)
     {
      if(Strategy_IsPivotHigh(d1, i))
        {
         if(recent_high <= 0.0)
            recent_high = d1[i].high;
         else
           {
            prior_high = d1[i].high;
            break;
           }
        }
     }

   for(int i = 1; i < ArraySize(d1) - 1; ++i)
     {
      if(Strategy_IsPivotLow(d1, i))
        {
         if(recent_low <= 0.0)
            recent_low = d1[i].low;
         else
           {
            prior_low = d1[i].low;
            break;
           }
        }
     }

   return (recent_high > 0.0 && prior_high > 0.0 &&
           recent_low > 0.0 && prior_low > 0.0 &&
           recent_high < prior_high && recent_low < prior_low);
  }

bool Strategy_D1BullishBias()
  {
   MqlRates d1[];
   const int need = MathMax(20, strategy_d1_pivot_lookback);
   if(!Strategy_LoadRates(PERIOD_D1, 1, need, d1))
      return false;

   double recent_high = 0.0;
   double prior_high = 0.0;
   double recent_low = 0.0;
   double prior_low = 0.0;

   for(int i = 1; i < ArraySize(d1) - 1; ++i)
     {
      if(Strategy_IsPivotHigh(d1, i))
        {
         if(recent_high <= 0.0)
            recent_high = d1[i].high;
         else
           {
            prior_high = d1[i].high;
            break;
           }
        }
     }

   for(int i = 1; i < ArraySize(d1) - 1; ++i)
     {
      if(Strategy_IsPivotLow(d1, i))
        {
         if(recent_low <= 0.0)
            recent_low = d1[i].low;
         else
           {
            prior_low = d1[i].low;
            break;
           }
        }
     }

   return (recent_high > 0.0 && prior_high > 0.0 &&
           recent_low > 0.0 && prior_low > 0.0 &&
           recent_high > prior_high && recent_low > prior_low);
  }

bool Strategy_H4OteZone(const bool bearish_context)
  {
   MqlRates h4[];
   const int need = MathMax(20, strategy_h4_ote_lookback);
   if(!Strategy_LoadRates(PERIOD_H4, 1, need, h4))
      return false;

   const double current = h4[0].close;
   double best_range = 0.0;
   double zone_low = 0.0;
   double zone_high = 0.0;

   if(bearish_context)
     {
      for(int hi_i = 3; hi_i < ArraySize(h4); ++hi_i)
        {
         for(int lo_i = 1; lo_i < hi_i; ++lo_i)
           {
            const double range = h4[hi_i].high - h4[lo_i].low;
            if(range <= best_range)
               continue;
            best_range = range;
            zone_low = h4[lo_i].low + strategy_ote_zone_low * range;
            zone_high = h4[lo_i].low + strategy_ote_zone_high * range;
           }
        }
      return (best_range > 0.0 && current >= zone_low && current <= zone_high);
     }

   for(int lo_i = 3; lo_i < ArraySize(h4); ++lo_i)
     {
      for(int hi_i = 1; hi_i < lo_i; ++hi_i)
        {
         const double range = h4[hi_i].high - h4[lo_i].low;
         if(range <= best_range)
            continue;
         best_range = range;
         zone_low = h4[hi_i].high - strategy_ote_zone_high * range;
         zone_high = h4[hi_i].high - strategy_ote_zone_low * range;
        }
     }

   return (best_range > 0.0 && current >= zone_low && current <= zone_high);
  }

bool Strategy_ReversalCandleAllows(const MqlRates &m15[], const bool want_short)
  {
   if(ArraySize(m15) < 2)
      return false;
   if(want_short)
      return (m15[0].close < m15[0].open || m15[0].high < m15[1].high);
   return (m15[0].close > m15[0].open || m15[0].low > m15[1].low);
  }

bool Strategy_FindShortMSS(const MqlRates &m15[],
                           const StrategySessionState &state,
                           double &sweep_high,
                           MqlRates &mss_bar)
  {
   sweep_high = 0.0;
   ZeroMemory(mss_bar);

   const int max_s = MathMin(strategy_mss_max_bars, ArraySize(m15) - 3);
   for(int s = 1; s <= max_s; ++s)
     {
      if(!Strategy_InUTCWindow(m15[s].time,
                               strategy_close_start_gmt_h,
                               strategy_close_start_gmt_m,
                               strategy_close_end_gmt_h,
                               strategy_close_end_gmt_m))
         continue;
      if(m15[s].high <= state.london_high)
         continue;

      double swing_low = 0.0;
      const int max_i = MathMin(ArraySize(m15) - 2, s + MathMax(4, strategy_swing_scan_bars));
      for(int i = s + 1; i <= max_i; ++i)
        {
         if(Strategy_DayKeyUTC(m15[i].time) != state.day_key)
            break;
         if(Strategy_IsPivotLow(m15, i))
           {
            swing_low = m15[i].low;
            break;
           }
        }
      if(swing_low <= 0.0)
        {
         swing_low = DBL_MAX;
         for(int i = s + 1; i <= max_i; ++i)
           {
            if(Strategy_DayKeyUTC(m15[i].time) != state.day_key)
               break;
            swing_low = MathMin(swing_low, m15[i].low);
           }
         if(swing_low >= DBL_MAX)
            swing_low = 0.0;
        }

      if(swing_low > 0.0 && m15[0].time > m15[s].time && m15[0].close < swing_low)
        {
         sweep_high = m15[s].high;
         mss_bar = m15[0];
         return true;
        }
     }
   return false;
  }

bool Strategy_FindLongMSS(const MqlRates &m15[],
                          const StrategySessionState &state,
                          double &sweep_low,
                          MqlRates &mss_bar)
  {
   sweep_low = 0.0;
   ZeroMemory(mss_bar);

   const int max_s = MathMin(strategy_mss_max_bars, ArraySize(m15) - 3);
   for(int s = 1; s <= max_s; ++s)
     {
      if(!Strategy_InUTCWindow(m15[s].time,
                               strategy_close_start_gmt_h,
                               strategy_close_start_gmt_m,
                               strategy_close_end_gmt_h,
                               strategy_close_end_gmt_m))
         continue;
      if(m15[s].low >= state.london_low)
         continue;

      double swing_high = 0.0;
      const int max_i = MathMin(ArraySize(m15) - 2, s + MathMax(4, strategy_swing_scan_bars));
      for(int i = s + 1; i <= max_i; ++i)
        {
         if(Strategy_DayKeyUTC(m15[i].time) != state.day_key)
            break;
         if(Strategy_IsPivotHigh(m15, i))
           {
            swing_high = m15[i].high;
            break;
           }
        }
      if(swing_high <= 0.0)
        {
         for(int i = s + 1; i <= max_i; ++i)
           {
            if(Strategy_DayKeyUTC(m15[i].time) != state.day_key)
               break;
            swing_high = MathMax(swing_high, m15[i].high);
           }
        }

      if(swing_high > 0.0 && m15[0].time > m15[s].time && m15[0].close > swing_high)
        {
         sweep_low = m15[s].low;
         mss_bar = m15[0];
         return true;
        }
     }
   return false;
  }

double Strategy_H4SwingTarget(const bool want_short, const double entry)
  {
   MqlRates h4[];
   if(!Strategy_LoadRates(PERIOD_H4, 1, MathMax(20, strategy_h4_ote_lookback), h4))
      return 0.0;

   double target = want_short ? 0.0 : DBL_MAX;
   for(int i = 1; i < ArraySize(h4) - 1; ++i)
     {
      if(want_short && Strategy_IsPivotLow(h4, i) && h4[i].low < entry)
         target = MathMax(target, h4[i].low);
      if(!want_short && Strategy_IsPivotHigh(h4, i) && h4[i].high > entry)
         target = MathMin(target, h4[i].high);
     }

   if(!want_short && target >= DBL_MAX)
      return 0.0;
   return target;
  }

bool Strategy_ValidateStopGeometry(const QM_OrderType type,
                                   const double entry,
                                   const double sl)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_points = (double)((stops_level > 0) ? stops_level : 0) + MathMax(0.0, (ask - bid) / point);
   const double sl_points = MathAbs(entry - sl) / point;
   if(sl_points <= min_points)
      return false;

   if(type == QM_SELL_LIMIT)
      return (entry > bid + min_points * point);
   if(type == QM_BUY_LIMIT)
      return (entry < ask - min_points * point);
   return true;
  }

bool Strategy_BuildRequest(const bool want_short,
                           const StrategySessionState &state,
                           const MqlRates &mss_bar,
                           QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, PERIOD_M15, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double entry = 0.0;
   double sl = 0.0;
   double tp1 = 0.0;
   double tp2 = 0.0;
   const double clamped_ote = MathMax(0.0, MathMin(1.0, strategy_ote_fraction));

   if(want_short)
     {
      const double range = state.london_high - state.london_open;
      if(range <= 0.0)
         return false;
      entry = state.london_high - clamped_ote * range;
      sl = state.london_high + strategy_stop_atr_buffer * atr;
      tp1 = state.london_low;
      tp2 = state.prior_day_low;
      if(tp2 <= 0.0 || tp2 >= entry)
         tp2 = Strategy_H4SwingTarget(true, entry);
      if(tp2 <= 0.0 || tp2 >= entry)
         tp2 = entry - strategy_runner_rr_fallback * (sl - entry);
      req.type = (bid <= entry) ? QM_SELL : QM_SELL_LIMIT;
      req.reason = (req.type == QM_SELL) ? "ICT_LONDON_CLOSE_SHORT_MARKET" : "ICT_LONDON_CLOSE_SHORT_LIMIT";
     }
   else
     {
      const double range = state.london_open - state.london_low;
      if(range <= 0.0)
         return false;
      entry = state.london_low + clamped_ote * range;
      sl = state.london_low - strategy_stop_atr_buffer * atr;
      tp1 = state.london_high;
      tp2 = state.prior_day_high;
      if(tp2 <= entry)
         tp2 = Strategy_H4SwingTarget(false, entry);
      if(tp2 <= entry)
         tp2 = entry + strategy_runner_rr_fallback * (entry - sl);
      req.type = (ask >= entry) ? QM_BUY : QM_BUY_LIMIT;
      req.reason = (req.type == QM_BUY) ? "ICT_LONDON_CLOSE_LONG_MARKET" : "ICT_LONDON_CLOSE_LONG_LIMIT";
     }

   entry = Strategy_NormalizePrice((req.type == QM_BUY || req.type == QM_SELL) ? mss_bar.open : entry);
   sl = Strategy_NormalizePrice(sl);
   tp1 = Strategy_NormalizePrice(tp1);
   tp2 = Strategy_NormalizePrice(tp2);
   if(entry <= 0.0 || sl <= 0.0 || tp1 <= 0.0 || tp2 <= 0.0)
      return false;
   if(want_short && (sl <= entry || tp2 >= entry || tp1 >= entry))
      return false;
   if(!want_short && (sl >= entry || tp2 <= entry || tp1 <= entry))
      return false;
   if(!Strategy_ValidateStopGeometry(req.type, entry, sl))
      return false;

   req.price = (req.type == QM_BUY || req.type == QM_SELL) ? 0.0 : entry;
   req.sl = sl;
   req.tp = tp2;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_limit_valid_bars) * PeriodSeconds(PERIOD_M15);

   g_pending_tp1 = tp1;
   g_active_tp1 = 0.0;
   g_active_ticket = 0;
   g_partial_done = false;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   double volume;
   double open_price;
   double sl;
   if(Strategy_SelectOurPosition(ticket, pos_type, volume, open_price, sl) || Strategy_HasOurPendingOrder())
      return false;

   if(_Period != PERIOD_M15)
      return true;
   if(!Strategy_SpreadAllows())
      return true;

   return !Strategy_InUTCWindow(TimeCurrent(),
                                strategy_close_start_gmt_h,
                                strategy_close_start_gmt_m,
                                strategy_close_end_gmt_h,
                                strategy_close_end_gmt_m);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);
   Strategy_RemoveExpiredPendingOrders();

   if(_Period != PERIOD_M15)
      return false;
   if(!Strategy_SpreadAllows())
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   double volume;
   double open_price;
   double sl;
   if(Strategy_SelectOurPosition(ticket, pos_type, volume, open_price, sl) || Strategy_HasOurPendingOrder())
      return false;

   const int need = MathMax(80, strategy_m15_scan_bars);
   MqlRates m15[];
   if(!Strategy_LoadRates(PERIOD_M15, 1, need, m15))
      return false;

   const MqlRates closed_bar = m15[0];
   if(!Strategy_InUTCWindow(closed_bar.time,
                            strategy_close_start_gmt_h,
                            strategy_close_start_gmt_m,
                            strategy_close_end_gmt_h,
                            strategy_close_end_gmt_m))
      return false;

   const int day_key = Strategy_DayKeyUTC(closed_bar.time);
   if(g_entry_day_key == day_key)
      return false;

   StrategySessionState state;
   if(!Strategy_BuildSessionState(m15, day_key, state))
      return false;

   const bool bearish_context = Strategy_D1BearishBias() || Strategy_H4OteZone(true);
   const bool bullish_context = Strategy_D1BullishBias() || Strategy_H4OteZone(false);

   double sweep_extreme = 0.0;
   MqlRates mss_bar;
   if(state.london_buy_day &&
      bearish_context &&
      Strategy_ReversalCandleAllows(m15, true) &&
      Strategy_FindShortMSS(m15, state, sweep_extreme, mss_bar))
     {
      if(Strategy_BuildRequest(true, state, mss_bar, req))
        {
         g_entry_day_key = day_key;
         return true;
        }
     }

   if(state.london_sell_day &&
      bullish_context &&
      Strategy_ReversalCandleAllows(m15, false) &&
      Strategy_FindLongMSS(m15, state, sweep_extreme, mss_bar))
     {
      if(Strategy_BuildRequest(false, state, mss_bar, req))
        {
         g_entry_day_key = day_key;
         return true;
        }
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   double volume;
   double open_price;
   double sl;
   if(!Strategy_SelectOurPosition(ticket, pos_type, volume, open_price, sl))
     {
      g_active_ticket = 0;
      g_active_tp1 = 0.0;
      g_partial_done = false;
      return;
     }

   if(g_active_ticket != ticket)
     {
      g_active_ticket = ticket;
      g_active_tp1 = g_pending_tp1;
      g_partial_done = false;
     }

   const bool is_buy = (pos_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   if(!g_partial_done && g_active_tp1 > 0.0 &&
      ((is_buy && market >= g_active_tp1) || (!is_buy && market <= g_active_tp1)))
     {
      const double close_lots = volume * MathMax(0.0, MathMin(1.0, strategy_partial_fraction));
      if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
         g_partial_done = true;
     }

   if(g_partial_done)
      QM_TM_TrailATR(ticket, MathMax(1, strategy_atr_period), strategy_atr_trail_mult);
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12550\",\"strategy\":\"ict_london_close_reversal_m15\"}");
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
