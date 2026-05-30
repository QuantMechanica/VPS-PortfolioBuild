#property strict
#property version   "5.0"
#property description "QM5_1045 Zarattini SPY Intraday Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1045;
input int    qm_magic_slot_offset       = 2;
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
input int    strategy_noise_lookback_days = 14;
input int    strategy_winter_open_hhmm    = 1530;
input int    strategy_winter_close_hhmm   = 2200;
input int    strategy_usdst_open_hhmm     = 1430;
input int    strategy_usdst_close_hhmm    = 2100;
input bool   strategy_use_us_dst_session  = true;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_spread_points   = 250;
input int    strategy_copy_bars           = 2200;

int  g_trade_day_key = -1;
bool g_long_taken_today = false;
bool g_short_taken_today = false;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int DayOfYearKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int DayOfWeekForDate(const int year, const int mon, const int day)
  {
   const datetime stamp = StringToTime(StringFormat("%04d.%02d.%02d 00:00", year, mon, day));
   MqlDateTime dt;
   TimeToStruct(stamp, dt);
   return dt.day_of_week;
  }

int NthSundayOfMonth(const int year, const int mon, const int n)
  {
   const int first_dow = DayOfWeekForDate(year, mon, 1);
   return 1 + ((7 - first_dow) % 7) + 7 * (n - 1);
  }

bool IsUsDstDate(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.mon < 3 || dt.mon > 11)
      return false;
   if(dt.mon > 3 && dt.mon < 11)
      return true;

   const int start_day = NthSundayOfMonth(dt.year, 3, 2);
   const int end_day = NthSundayOfMonth(dt.year, 11, 1);
   if(dt.mon == 3)
      return (dt.day >= start_day);
   return (dt.day < end_day);
  }

int SessionOpenHhmm(const datetime t)
  {
   if(strategy_use_us_dst_session && IsUsDstDate(t))
      return strategy_usdst_open_hhmm;
   return strategy_winter_open_hhmm;
  }

int SessionCloseHhmm(const datetime t)
  {
   if(strategy_use_us_dst_session && IsUsDstDate(t))
      return strategy_usdst_close_hhmm;
   return strategy_winter_close_hhmm;
  }

bool IsCashSessionMark(const datetime t, const bool allow_close_mark)
  {
   const int hhmm = Hhmm(t);
   const int session_open = SessionOpenHhmm(t);
   const int session_close = SessionCloseHhmm(t);
   if(allow_close_mark)
      return (hhmm >= session_open && hhmm <= session_close);
   return (hhmm >= session_open && hhmm < session_close);
  }

bool IsHalfHourMark(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.min == 0 || dt.min == 30);
  }

bool HasOurPosition()
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         g_long_taken_today = true;
      if(ptype == POSITION_TYPE_SELL)
         g_short_taken_today = true;
      return true;
     }

   return false;
  }

void RefreshTradeDayState(const datetime t)
  {
   const int day_key = DayKey(t);
   if(day_key == g_trade_day_key)
      return;

   g_trade_day_key = day_key;
   g_long_taken_today = false;
   g_short_taken_today = false;
  }

int FindDayIndex(const int &days[], const int count, const int day_key)
  {
   for(int i = 0; i < count; ++i)
     {
      if(days[i] == day_key)
         return i;
     }
   return -1;
  }

bool ComputeNoiseBoundaries(const datetime signal_time,
                            const double signal_close,
                            double &upper,
                            double &lower)
  {
   upper = 0.0;
   lower = 0.0;

   const int count_request = (strategy_copy_bars < 500) ? 500 : strategy_copy_bars;
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_M30, 1, count_request, rates);
   if(copied <= 0)
      return false;
   ArraySetAsSeries(rates, true);

   const int current_day = DayOfYearKey(signal_time);
   const int target_hhmm = Hhmm(signal_time);
   double session_open = 0.0;
   double prior_close = 0.0;

   int day_keys[64];
   double day_highs[64];
   double day_lows[64];
   int day_count = 0;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_open = rates[i].time;
      const datetime bar_close = bar_open + PeriodSeconds(PERIOD_M30);
      const int bar_day = DayOfYearKey(bar_close);
      const int close_hhmm = Hhmm(bar_close);
      const int session_open_hhmm = SessionOpenHhmm(bar_close);
      const int session_close_hhmm = SessionCloseHhmm(bar_close);

      if(bar_day == current_day && Hhmm(bar_open) == session_open_hhmm && session_open <= 0.0)
         session_open = rates[i].open;

      if(bar_day == current_day)
         continue;

      if(prior_close <= 0.0 && close_hhmm <= session_close_hhmm && close_hhmm > session_open_hhmm)
         prior_close = rates[i].close;

      if(close_hhmm < session_open_hhmm || close_hhmm > target_hhmm)
         continue;

      int idx = FindDayIndex(day_keys, day_count, bar_day);
      if(idx < 0)
        {
         if(day_count >= strategy_noise_lookback_days)
            continue;
         idx = day_count;
         day_keys[idx] = bar_day;
         day_highs[idx] = rates[i].high;
         day_lows[idx] = rates[i].low;
         day_count++;
        }
      else
        {
         if(rates[i].high > day_highs[idx])
            day_highs[idx] = rates[i].high;
         if(rates[i].low < day_lows[idx])
            day_lows[idx] = rates[i].low;
        }
     }

   if(session_open <= 0.0)
      session_open = iOpen(_Symbol, PERIOD_D1, 0);
   if(session_open <= 0.0 || signal_close <= 0.0 || day_count < strategy_noise_lookback_days)
      return false;

   double sum_move = 0.0;
   for(int j = 0; j < strategy_noise_lookback_days; ++j)
     {
      if(day_highs[j] <= day_lows[j])
         return false;
      sum_move += day_highs[j] - day_lows[j];
     }

   const double avg_move = sum_move / strategy_noise_lookback_days;
   double gap_adj_up = 0.0;
   double gap_adj_dn = 0.0;
   if(prior_close > 0.0)
     {
      if(session_open < prior_close)
         gap_adj_up = prior_close - session_open;
      else if(session_open > prior_close)
         gap_adj_dn = session_open - prior_close;
     }

   upper = session_open + avg_move + gap_adj_up;
   lower = session_open - avg_move - gap_adj_dn;
   return (upper > lower);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   RefreshTradeDayState(broker_now);

   if(HasOurPosition())
      return false;

   if(!IsCashSessionMark(broker_now, false))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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

   const datetime bar_open = iTime(_Symbol, PERIOD_M30, 1);
   if(bar_open <= 0)
      return false;
   const datetime signal_time = bar_open + PeriodSeconds(PERIOD_M30);
   RefreshTradeDayState(signal_time);

   if(HasOurPosition())
      return false;
   if(!IsHalfHourMark(signal_time) || !IsCashSessionMark(signal_time, false))
      return false;
   if(strategy_noise_lookback_days < 1 || strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0)
      return false;

   const double signal_close = iClose(_Symbol, PERIOD_M30, 1);
   double upper = 0.0;
   double lower = 0.0;
   if(!ComputeNoiseBoundaries(signal_time, signal_close, upper, lower))
      return false;

   if(signal_close > upper && !g_long_taken_today)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "QM5_1045_NOISE_BOUNDARY_LONG";
      if(req.sl > 0.0 && req.sl < entry)
        {
         g_long_taken_today = true;
         return true;
        }
     }

   if(signal_close < lower && !g_short_taken_today)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "QM5_1045_NOISE_BOUNDARY_SHORT";
      if(req.sl > 0.0 && req.sl > entry)
        {
         g_short_taken_today = true;
         return true;
        }
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!HasOurPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   return (Hhmm(broker_now) >= SessionCloseHhmm(broker_now) || !IsCashSessionMark(broker_now, true));
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1045_zarattini-spy-intraday-momentum\"}");
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
