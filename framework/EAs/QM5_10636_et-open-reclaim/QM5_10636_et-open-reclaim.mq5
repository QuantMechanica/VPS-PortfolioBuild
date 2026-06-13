#property strict
#property version   "5.0"
#property description "QM5_10636 Elite Trader Opening Price Reclaim"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10636;
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
input int    strategy_session_start_hour       = 16;
input int    strategy_session_start_minute     = 30;
input int    strategy_session_end_hour         = 23;
input int    strategy_session_end_minute       = 0;
input int    strategy_atr_period               = 14;
input int    strategy_trend_sma_period         = 100;
input double strategy_gap_atr_mult             = 0.25;
input int    strategy_opening_range_minutes    = 15;
input double strategy_small_range_atr_mult     = 0.80;
input int    strategy_reclaim_deadline_minutes = 60;
input int    strategy_entry_window_minutes     = 90;
input int    strategy_max_hold_bars            = 18;
input double strategy_sl_atr_buffer_mult       = 0.15;
input double strategy_tp_r_cap                 = 2.0;
input int    strategy_max_spread_points        = 0;

int      g_session_key = 0;
bool     g_have_current_session = false;
bool     g_have_prior_session = false;
bool     g_open_range_ready = false;
bool     g_traded_below_session_open = false;
bool     g_traded_above_session_open = false;
int      g_opening_bars_seen = 0;
double   g_session_open = 0.0;
double   g_session_high = 0.0;
double   g_session_low = 0.0;
double   g_session_close = 0.0;
double   g_open_range_high = 0.0;
double   g_open_range_low = 0.0;
double   g_prior_session_high = 0.0;
double   g_prior_session_low = 0.0;
double   g_prior_session_close = 0.0;

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

int MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 60 + dt.min);
  }

int SessionStartMinute()
  {
   return (strategy_session_start_hour * 60 + strategy_session_start_minute);
  }

int SessionEndMinute()
  {
   return (strategy_session_end_hour * 60 + strategy_session_end_minute);
  }

bool IsInsideSessionMinute(const int minute_of_day)
  {
   const int start_min = SessionStartMinute();
   const int end_min = SessionEndMinute();
   if(start_min == end_min)
      return true;
   if(start_min < end_min)
      return (minute_of_day >= start_min && minute_of_day < end_min);
   return (minute_of_day >= start_min || minute_of_day < end_min);
  }

int MinutesSinceSessionStart(const datetime t)
  {
   const int minute_of_day = MinutesOfDay(t);
   const int start_min = SessionStartMinute();
   if(minute_of_day >= start_min)
      return (minute_of_day - start_min);
   return (minute_of_day + 1440 - start_min);
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
      return true;
     }
   return false;
  }

bool SelectOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at)
  {
   ptype = POSITION_TYPE_BUY;
   opened_at = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

void ResetForNewSession(const int key, const double first_open)
  {
   if(g_have_current_session)
     {
      g_prior_session_high = g_session_high;
      g_prior_session_low = g_session_low;
      g_prior_session_close = g_session_close;
      g_have_prior_session = (g_prior_session_high > 0.0 &&
                              g_prior_session_low > 0.0 &&
                              g_prior_session_close > 0.0);
     }

   g_session_key = key;
   g_have_current_session = true;
   g_open_range_ready = false;
   g_traded_below_session_open = false;
   g_traded_above_session_open = false;
   g_opening_bars_seen = 0;
   g_session_open = first_open;
   g_session_high = first_open;
   g_session_low = first_open;
   g_session_close = first_open;
   g_open_range_high = 0.0;
   g_open_range_low = 0.0;
  }

void AdvanceSessionState()
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: one closed-bar timestamp for session state
   if(bar_time <= 0)
      return;

   const int minute_of_day = MinutesOfDay(bar_time);
   if(!IsInsideSessionMinute(minute_of_day))
      return;

   const double bar_open = iOpen(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: one closed-bar open for session state
   const double bar_high = iHigh(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: one closed-bar high for session state
   const double bar_low = iLow(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: one closed-bar low for session state
   const double bar_close = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: one closed-bar close for session state
   if(bar_open <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return;

   const int key = DateKey(bar_time);
   const int minutes_from_open = MinutesSinceSessionStart(bar_time);
   if(!g_have_current_session || key != g_session_key || minutes_from_open < PeriodSeconds(PERIOD_CURRENT) / 60)
     {
      if(minutes_from_open < strategy_opening_range_minutes)
         ResetForNewSession(key, bar_open);
     }

   if(!g_have_current_session || key != g_session_key)
      return;

   if(bar_high > g_session_high)
      g_session_high = bar_high;
   if(bar_low < g_session_low)
      g_session_low = bar_low;
   g_session_close = bar_close;

   if(bar_low < g_session_open)
      g_traded_below_session_open = true;
   if(bar_high > g_session_open)
      g_traded_above_session_open = true;

   if(minutes_from_open < strategy_opening_range_minutes)
     {
      if(g_opening_bars_seen == 0)
        {
         g_open_range_high = bar_high;
         g_open_range_low = bar_low;
        }
      else
        {
         if(bar_high > g_open_range_high)
            g_open_range_high = bar_high;
         if(bar_low < g_open_range_low)
            g_open_range_low = bar_low;
        }
      g_opening_bars_seen++;
     }

   const int bar_minutes = MathMax(1, PeriodSeconds(PERIOD_CURRENT) / 60);
   if(g_opening_bars_seen * bar_minutes >= strategy_opening_range_minutes)
      g_open_range_ready = true;
  }

double CappedTakeProfit(const QM_OrderType side,
                        const double entry,
                        const double stop_price)
  {
   const double risk_distance = MathAbs(entry - stop_price);
   if(risk_distance <= 0.0 || strategy_tp_r_cap <= 0.0)
      return 0.0;

   if(side == QM_BUY)
     {
      if(g_prior_session_high <= entry)
         return 0.0;
      const double cap = entry + risk_distance * strategy_tp_r_cap;
      return NormalizeDouble(MathMin(g_prior_session_high, cap), _Digits);
     }

   if(g_prior_session_low >= entry)
      return 0.0;
   const double cap = entry - risk_distance * strategy_tp_r_cap;
   return NormalizeDouble(MathMax(g_prior_session_low, cap), _Digits);
  }

bool Strategy_NoTradeFilter()
  {
   if(HasOurPosition())
      return false;

   const datetime now = TimeCurrent();
   const int minute_of_day = MinutesOfDay(now);
   if(!IsInsideSessionMinute(minute_of_day))
      return true;

   const int minutes_from_open = MinutesSinceSessionStart(now);
   if(minutes_from_open > strategy_entry_window_minutes)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

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

   AdvanceSessionState();

   if(HasOurPosition())
      return false;
   if(!g_have_current_session || !g_have_prior_session || !g_open_range_ready)
      return false;
   if(strategy_atr_period <= 0 || strategy_trend_sma_period <= 0)
      return false;

   const datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: closed-bar timestamp for entry window
   const double bar_close = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: closed-bar close for reclaim trigger
   if(bar_time <= 0 || bar_close <= 0.0)
      return false;

   const int minutes_from_open = MinutesSinceSessionStart(bar_time);
   if(minutes_from_open < strategy_opening_range_minutes ||
      minutes_from_open > strategy_reclaim_deadline_minutes ||
      minutes_from_open > strategy_entry_window_minutes)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double opening_range = g_open_range_high - g_open_range_low;
   if(opening_range <= 0.0 || opening_range > strategy_small_range_atr_mult * atr)
      return false;

   const double m15_close = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: one HTF close for trend filter
   const double m15_sma = QM_SMA(_Symbol, PERIOD_M15, strategy_trend_sma_period, 1);
   if(m15_close <= 0.0 || m15_sma <= 0.0)
      return false;

   const double gap_distance = strategy_gap_atr_mult * atr;
   const double sl_buffer = strategy_sl_atr_buffer_mult * atr;
   if(gap_distance <= 0.0 || sl_buffer <= 0.0)
      return false;

   if(m15_close > m15_sma &&
      g_session_open <= g_prior_session_close - gap_distance &&
      g_traded_below_session_open &&
      bar_close > g_session_open)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(g_open_range_low - sl_buffer, _Digits);
      req.tp = CappedTakeProfit(QM_BUY, SymbolInfoDouble(_Symbol, SYMBOL_ASK), req.sl);
      req.reason = "ET_OPEN_RECLAIM_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(m15_close < m15_sma &&
      g_session_open >= g_prior_session_close + gap_distance &&
      g_traded_above_session_open &&
      bar_close < g_session_open)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(g_open_range_high + sl_buffer, _Digits);
      req.tp = CappedTakeProfit(QM_SELL, SymbolInfoDouble(_Symbol, SYMBOL_BID), req.sl);
      req.reason = "ET_OPEN_RECLAIM_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial close logic.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   if(!SelectOurPosition(ptype, opened_at))
      return false;

   const datetime now = TimeCurrent();
   if(!IsInsideSessionMinute(MinutesOfDay(now)))
      return true;

   const int max_hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_M5);
   if(max_hold_seconds > 0 && opened_at > 0 && now >= opened_at + max_hold_seconds)
      return true;

   if(g_session_open <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 && bid < g_session_open);
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 && ask > g_session_open);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10636_et-open-reclaim\"}");
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
