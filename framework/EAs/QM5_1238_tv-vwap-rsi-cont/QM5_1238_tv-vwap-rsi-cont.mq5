#property strict
#property version   "5.0"
#property description "QM5_1238 TradingView VWAP RSI Continuation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1238;
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
input ENUM_TIMEFRAMES strategy_timeframe    = PERIOD_M15;
input int             strategy_atr_period   = 14;
input int             strategy_rsi_period   = 14;
input double          strategy_vwap_touch_atr = 0.15;
input double          strategy_stop_atr_mult  = 1.20;
input double          strategy_tp_r_mult      = 1.50;
input double          strategy_be_trigger_r   = 1.00;
input int             strategy_max_hold_bars  = 16;
input int             strategy_london_start_hour = 7;
input int             strategy_london_end_hour   = 17;
input double          strategy_min_range_h1_atr  = 0.60;
input int             strategy_spread_days       = 20;
input double          strategy_spread_mult       = 2.0;

int      g_session_day_key       = -1;
bool     g_session_ready         = false;
bool     g_session_trade_taken   = false;
double   g_session_pv_sum        = 0.0;
double   g_session_vol_sum       = 0.0;
double   g_session_vwap          = 0.0;
double   g_session_high          = 0.0;
double   g_session_low           = 0.0;
double   g_signal_open           = 0.0;
double   g_signal_close          = 0.0;
double   g_prev_low              = 0.0;
double   g_prev_high             = 0.0;
datetime g_signal_time           = 0;
bool     g_exit_should_close     = false;

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int LastSundayDay(const int year, const int month)
  {
   for(int day = 31; day >= 25; --day)
     {
      MqlDateTime raw;
      raw.year = year;
      raw.mon = month;
      raw.day = day;
      raw.hour = 1;
      raw.min = 0;
      raw.sec = 0;
      datetime candidate = StructToTime(raw);
      MqlDateTime check;
      TimeToStruct(candidate, check);
      if(check.year == year && check.mon == month && check.day == day && check.day_of_week == 0)
         return day;
     }
   return 31;
  }

datetime UKDstBoundaryUTC(const int year, const int month)
  {
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = LastSundayDay(year, month);
   dt.hour = 1;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool IsUKDSTUTC(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   const datetime start = UKDstBoundaryUTC(dt.year, 3);
   const datetime finish = UKDstBoundaryUTC(dt.year, 10);
   return (utc_time >= start && utc_time < finish);
  }

int LondonHourFromBrokerTime(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   const int offset_seconds = IsUKDSTUTC(utc_time) ? 3600 : 0;
   MqlDateTime london;
   TimeToStruct(utc_time + offset_seconds, london);
   return london.hour;
  }

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

void ResetSessionCache(const int day_key)
  {
   g_session_day_key = day_key;
   g_session_ready = false;
   g_session_trade_taken = false;
   g_session_pv_sum = 0.0;
   g_session_vol_sum = 0.0;
   g_session_vwap = 0.0;
   g_session_high = 0.0;
   g_session_low = 0.0;
  }

void AddClosedBarToSession(const int shift)
  {
   // perf-allowed: fixed closed-bar OHLCV read for session VWAP; no QM OHLC helpers exist.
   const double high = iHigh(_Symbol, strategy_timeframe, shift);
   const double low = iLow(_Symbol, strategy_timeframe, shift);
   const double close = iClose(_Symbol, strategy_timeframe, shift);
   const long tick_volume = iVolume(_Symbol, strategy_timeframe, shift);
   if(high <= 0.0 || low <= 0.0 || close <= 0.0 || high < low)
      return;

   if(!g_session_ready)
     {
      g_session_high = high;
      g_session_low = low;
      g_session_ready = true;
     }
   else
     {
      if(high > g_session_high)
         g_session_high = high;
      if(low < g_session_low)
         g_session_low = low;
     }

   const double volume = (tick_volume > 0) ? (double)tick_volume : 1.0;
   const double typical = (high + low + close) / 3.0;
   g_session_pv_sum += typical * volume;
   g_session_vol_sum += volume;
   if(g_session_vol_sum > 0.0)
      g_session_vwap = g_session_pv_sum / g_session_vol_sum;
  }

void BootstrapSessionFromClosedDay(const datetime signal_time)
  {
   ResetSessionCache(DayKey(signal_time));

   const int max_bars = 120;
   for(int shift = max_bars; shift >= 1; --shift)
     {
      // perf-allowed: bounded one-time daily VWAP bootstrap; no QM Time helper exists.
      const datetime bar_time = iTime(_Symbol, strategy_timeframe, shift);
      if(bar_time <= 0 || DayKey(bar_time) != g_session_day_key)
         continue;
      AddClosedBarToSession(shift);
     }
  }

double MedianSpreadForEntryHour()
  {
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0 || strategy_spread_days <= 0)
      return 0.0;

   MqlDateTime signal_dt;
   TimeToStruct(g_signal_time, signal_dt);

   const int max_shift = MathMax(1, strategy_spread_days * 96);
   double values[];
   ArrayResize(values, max_shift);
   int count = 0;

   for(int shift = 1; shift <= max_shift; ++shift)
     {
      // perf-allowed: historical spread baseline only when modeled spread is non-zero.
      const datetime bar_time = iTime(_Symbol, strategy_timeframe, shift);
      if(bar_time <= 0)
         continue;
      MqlDateTime dt;
      TimeToStruct(bar_time, dt);
      if(dt.hour != signal_dt.hour)
         continue;

      const int spread = iSpread(_Symbol, strategy_timeframe, shift);
      if(spread > 0)
        {
         values[count] = (double)spread;
         count++;
        }
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);
   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

bool CurrentSpreadAllowed()
  {
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   const double median_spread = MedianSpreadForEntryHour();
   if(median_spread <= 0.0)
      return true;

   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

void UpdateExitCache()
  {
   g_exit_should_close = false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!SelectOurPosition(ticket, position_type, open_time))
      return;

   g_session_trade_taken = true;

   // perf-allowed: O(1) open-time to bar-shift conversion for card max-hold rule.
   const int open_shift = iBarShift(_Symbol, strategy_timeframe, open_time, false);
   if(open_shift >= strategy_max_hold_bars)
     {
      g_exit_should_close = true;
      return;
     }

   if(!g_session_ready || g_session_vwap <= 0.0 || g_signal_close <= 0.0)
      return;

   if(position_type == POSITION_TYPE_BUY && g_signal_close < g_session_vwap)
      g_exit_should_close = true;
   else if(position_type == POSITION_TYPE_SELL && g_signal_close > g_session_vwap)
      g_exit_should_close = true;
  }

void AdvanceState_OnNewBar()
  {
   if(strategy_timeframe != PERIOD_M15)
      return;

   // perf-allowed: fixed closed-bar OHLC/time reads; no QM OHLC helpers exist.
   g_signal_time = iTime(_Symbol, strategy_timeframe, 1);
   if(g_signal_time <= 0)
      return;

   g_signal_open = iOpen(_Symbol, strategy_timeframe, 1);
   g_signal_close = iClose(_Symbol, strategy_timeframe, 1);
   g_prev_low = iLow(_Symbol, strategy_timeframe, 2);
   g_prev_high = iHigh(_Symbol, strategy_timeframe, 2);

   const int day_key = DayKey(g_signal_time);
   if(day_key != g_session_day_key)
      BootstrapSessionFromClosedDay(g_signal_time);
   else
      AddClosedBarToSession(1);

   UpdateExitCache();
  }

bool LondonEntryWindowAllowed()
  {
   if(g_signal_time <= 0)
      return false;
   const int hour = LondonHourFromBrokerTime(g_signal_time);
   return (hour >= strategy_london_start_hour && hour < strategy_london_end_hour);
  }

bool FridayPreCloseEntryBlocked()
  {
   if(g_signal_time <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(g_signal_time, dt);
   return (dt.day_of_week == 5 && dt.hour >= qm_friday_close_hour_broker - 2);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(SelectOurPosition(ticket, position_type, open_time))
      return false;

   if(!LondonEntryWindowAllowed())
      return true;
   if(FridayPreCloseEntryBlocked())
      return true;
   if(!CurrentSpreadAllowed())
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_timeframe != PERIOD_M15)
      return false;
   if(g_session_trade_taken || !g_session_ready || g_session_vwap <= 0.0)
      return false;
   if(g_signal_open <= 0.0 || g_signal_close <= 0.0 || g_prev_low <= 0.0 || g_prev_high <= 0.0)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(SelectOurPosition(ticket, position_type, open_time))
      return false;

   const double atr_m15 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double rsi = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1, PRICE_CLOSE);
   if(atr_m15 <= 0.0 || atr_h1 <= 0.0 || rsi <= 0.0)
      return false;
   if((g_session_high - g_session_low) < strategy_min_range_h1_atr * atr_h1)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double stop_distance = atr_m15 * strategy_stop_atr_mult;
   if(stop_distance <= point)
      return false;

   if(g_signal_close > g_session_vwap &&
      g_prev_low <= g_session_vwap + strategy_vwap_touch_atr * atr_m15 &&
      g_signal_close > g_signal_open &&
      rsi >= 50.0 && rsi <= 70.0)
     {
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - stop_distance);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, ask + strategy_tp_r_mult * stop_distance);
      if(req.sl <= 0.0 || req.sl >= ask - point || req.tp <= ask + point)
         return false;
      req.reason = "vwap_rsi_cont_long";
      return true;
     }

   if(g_signal_close < g_session_vwap &&
      g_prev_high >= g_session_vwap - strategy_vwap_touch_atr * atr_m15 &&
      g_signal_close < g_signal_open &&
      rsi >= 30.0 && rsi <= 50.0)
     {
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bid + stop_distance);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, bid - strategy_tp_r_mult * stop_distance);
      if(req.sl <= bid + point || req.tp >= bid - point)
         return false;
      req.reason = "vwap_rsi_cont_short";
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!SelectOurPosition(ticket, position_type, open_time))
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(open_price <= 0.0 || current_sl <= 0.0 || point <= 0.0)
      return;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double risk = open_price - current_sl;
      if(bid > 0.0 && risk > point && (bid - open_price) >= strategy_be_trigger_r * risk)
        {
         const double be_sl = QM_StopRulesNormalizePrice(_Symbol, open_price);
         if(be_sl > current_sl + point * 0.5)
            QM_TM_MoveSL(ticket, be_sl, "vwap_rsi_be_long");
        }
     }
   else if(position_type == POSITION_TYPE_SELL)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk = current_sl - open_price;
      if(ask > 0.0 && risk > point && (open_price - ask) >= strategy_be_trigger_r * risk)
        {
         const double be_sl = QM_StopRulesNormalizePrice(_Symbol, open_price);
         if(be_sl < current_sl - point * 0.5)
            QM_TM_MoveSL(ticket, be_sl, "vwap_rsi_be_short");
        }
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!g_exit_should_close)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   return SelectOurPosition(ticket, position_type, open_time);
  }

// News Filter Hook
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1238\",\"ea\":\"QM5_1238_tv-vwap-rsi-cont\"}");
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

   const bool new_bar = QM_IsNewBar(_Symbol, strategy_timeframe);
   if(new_bar)
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

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
      return;
     }

   if(!new_bar)
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         g_session_trade_taken = true;
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
