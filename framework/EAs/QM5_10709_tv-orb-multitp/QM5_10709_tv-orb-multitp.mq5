#property strict
#property version   "5.0"
#property description "QM5_10709 TradingView ORB MultiTP"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10709;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_session_start_hour      = 9;
input int    strategy_session_start_minute    = 0;
input int    strategy_session_end_hour        = 17;
input int    strategy_session_end_minute      = 0;
input int    strategy_opening_range_minutes   = 30;
input int    strategy_range_lookback_bars     = 256;
input double strategy_min_range_pct           = 0.15;
input double strategy_max_range_pct           = 1.25;
input bool   strategy_use_midpoint_stop       = false;
input double strategy_tp1_rr                  = 1.0;
input double strategy_tp2_rr                  = 2.0;
input double strategy_tp1_close_pct           = 50.0;
input int    strategy_max_spread_points       = 0;

int    g_session_day_key = -1;
double g_or_high = 0.0;
double g_or_low = 0.0;
bool   g_or_locked = false;
bool   g_long_taken = false;
bool   g_short_taken = false;
ulong  g_partial_ticket = 0;
bool   g_partial_done = false;

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_ClampMinute(const int hour_value, const int minute_value)
  {
   const int h = MathMin(23, MathMax(0, hour_value));
   const int m = MathMin(59, MathMax(0, minute_value));
   return h * 60 + m;
  }

int Strategy_SessionStartMinute()
  {
   return Strategy_ClampMinute(strategy_session_start_hour, strategy_session_start_minute);
  }

int Strategy_SessionEndMinute()
  {
   return Strategy_ClampMinute(strategy_session_end_hour, strategy_session_end_minute);
  }

bool Strategy_MinuteInWindow(const int minute_value, const int start_minute, const int end_minute)
  {
   if(start_minute == end_minute)
      return true;
   if(start_minute < end_minute)
      return (minute_value >= start_minute && minute_value < end_minute);
   return (minute_value >= start_minute || minute_value < end_minute);
  }

bool Strategy_InTradeSession(const datetime t)
  {
   return Strategy_MinuteInWindow(Strategy_MinutesOfDay(t),
                                  Strategy_SessionStartMinute(),
                                  Strategy_SessionEndMinute());
  }

bool Strategy_AfterOpeningRange(const datetime t)
  {
   const int range_minutes = MathMax(1, strategy_opening_range_minutes);
   const int start_minute = Strategy_SessionStartMinute();
   const int range_end = (start_minute + range_minutes) % 1440;
   return !Strategy_MinuteInWindow(Strategy_MinutesOfDay(t), start_minute, range_end);
  }

bool Strategy_AfterSessionEnd(const datetime t)
  {
   const int minute_value = Strategy_MinutesOfDay(t);
   const int start_minute = Strategy_SessionStartMinute();
   const int end_minute = Strategy_SessionEndMinute();
   if(start_minute < end_minute)
      return (minute_value >= end_minute);
   return (minute_value >= end_minute && minute_value < start_minute);
  }

void Strategy_ResetSessionIfNeeded(const datetime t)
  {
   const int day_key = Strategy_DayKey(t);
   if(day_key == g_session_day_key)
      return;

   g_session_day_key = day_key;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_or_locked = false;
   g_long_taken = false;
   g_short_taken = false;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl_price,
                                double &volume,
                                ulong &ticket)
  {
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl_price = 0.0;
   volume = 0.0;
   ticket = 0;

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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl_price = PositionGetDouble(POSITION_SL);
      volume = PositionGetDouble(POSITION_VOLUME);
      ticket = candidate;
      return true;
     }

   return false;
  }

bool Strategy_HasOurPosition()
  {
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   double sl_price = 0.0;
   double volume = 0.0;
   ulong ticket = 0;
   return Strategy_SelectOurPosition(position_type, open_price, sl_price, volume, ticket);
  }

bool Strategy_OpeningRangeWidthAllowed()
  {
   if(!g_or_locked || g_or_high <= g_or_low || g_or_low <= 0.0)
      return false;

   const double mid = (g_or_high + g_or_low) * 0.5;
   if(mid <= 0.0)
      return false;

   const double width_pct = ((g_or_high - g_or_low) / mid) * 100.0;
   if(width_pct < strategy_min_range_pct)
      return false;
   if(width_pct > strategy_max_range_pct)
      return false;
   return true;
  }

bool Strategy_RefreshOpeningRange()
  {
   const datetime now = TimeCurrent();
   Strategy_ResetSessionIfNeeded(now);

   if(!Strategy_AfterOpeningRange(now))
     {
      g_or_locked = false;
      return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int lookback = MathMax(8, strategy_range_lookback_bars);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, lookback, rates); // perf-allowed: bounded OR session scan on framework closed-bar path.
   if(copied <= 0)
      return false;

   const int day_key = Strategy_DayKey(now);
   const int start_minute = Strategy_SessionStartMinute();
   const int range_end = (start_minute + MathMax(1, strategy_opening_range_minutes)) % 1440;
   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   bool have = false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_time = rates[i].time;
      if(Strategy_DayKey(bar_time) != day_key)
         continue;
      const int bar_minute = Strategy_MinutesOfDay(bar_time);
      if(!Strategy_MinuteInWindow(bar_minute, start_minute, range_end))
         continue;
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high < rates[i].low)
         continue;

      if(rates[i].high > hi)
         hi = rates[i].high;
      if(rates[i].low < lo)
         lo = rates[i].low;
      have = true;
     }

   if(!have)
      return false;

   g_or_high = hi;
   g_or_low = lo;
   g_or_locked = true;
   return true;
  }

double Strategy_StopPrice(const QM_OrderType side)
  {
   if(!g_or_locked)
      return 0.0;

   double stop = 0.0;
   if(strategy_use_midpoint_stop)
      stop = (g_or_high + g_or_low) * 0.5;
   else
      stop = (side == QM_BUY) ? g_or_low : g_or_high;

   return NormalizeDouble(stop, _Digits);
  }

void Strategy_InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// Return TRUE to BLOCK trading this tick. Framework news remains central;
// this strategy hook blocks entries before the locked OR window, outside the
// trade session, or when the optional spread ceiling is exceeded.
bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   Strategy_ResetSessionIfNeeded(now);

   if(Strategy_HasOurPosition())
      return false;

   if(!Strategy_InTradeSession(now))
      return true;
   if(!Strategy_AfterOpeningRange(now))
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
   Strategy_InitEntryRequest(req);

   const datetime now = TimeCurrent();
   if(!Strategy_InTradeSession(now) || !Strategy_AfterOpeningRange(now))
      return false;
   if(!Strategy_RefreshOpeningRange())
      return false;
   if(!Strategy_OpeningRangeWidthAllowed())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(!g_long_taken && ask > g_or_high)
     {
      const double sl = Strategy_StopPrice(QM_BUY);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp2_rr);
      req.reason = "TV_ORB_MULTITP_LONG";
      g_long_taken = true;
      return (req.tp > ask);
     }

   if(!g_short_taken && bid < g_or_low)
     {
      const double sl = Strategy_StopPrice(QM_SELL);
      if(sl <= 0.0 || sl <= bid)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp2_rr);
      req.reason = "TV_ORB_MULTITP_SHORT";
      g_short_taken = true;
      return (req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   double sl_price = 0.0;
   double volume = 0.0;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(position_type, open_price, sl_price, volume, ticket))
     {
      g_partial_ticket = 0;
      g_partial_done = false;
      return;
     }

   if(g_partial_ticket != ticket)
     {
      g_partial_ticket = ticket;
      g_partial_done = false;
     }

   if(g_partial_done || strategy_tp1_close_pct <= 0.0)
      return;

   const double risk_dist = MathAbs(open_price - sl_price);
   if(risk_dist <= 0.0 || volume <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double tp1 = is_buy ? open_price + risk_dist * strategy_tp1_rr
                             : open_price - risk_dist * strategy_tp1_rr;
   const bool hit_tp1 = is_buy ? (market >= tp1) : (market <= tp1);
   if(!hit_tp1)
      return;

   const double close_fraction = MathMin(100.0, MathMax(0.0, strategy_tp1_close_pct)) / 100.0;
   const double close_volume = volume * close_fraction;
   if(QM_TM_PartialClose(ticket, close_volume, QM_EXIT_PARTIAL))
      g_partial_done = true;
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;
   return Strategy_AfterSessionEnd(TimeCurrent());
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10709_tv-orb-multitp\"}");
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
