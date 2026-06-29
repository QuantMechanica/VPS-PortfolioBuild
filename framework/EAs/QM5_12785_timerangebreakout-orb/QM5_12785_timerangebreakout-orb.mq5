#property strict
#property version   "5.0"
#property description "QM5_12785 TimeRangeBreakout ORB"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12785;
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
input ENUM_TIMEFRAMES strategy_entry_tf          = PERIOD_M15;
input bool   strategy_use_symbol_profile         = true;
input int    strategy_range_start_hour           = 3;
input int    strategy_range_start_minute         = 0;
input int    strategy_range_duration_minutes     = 180;
input int    strategy_close_hour                 = 18;
input int    strategy_close_minute               = 0;
input double strategy_entry_buffer_range_pct     = 0.05;
input double strategy_sl_range_mult              = 1.00;
input double strategy_tp_range_mult              = 1.60;
input int    strategy_atr_period                 = 14;
input double strategy_min_range_d1_atr_mult      = 0.03;
input double strategy_max_range_d1_atr_mult      = 0.90;
input int    strategy_min_range_m1_bars          = 8;
input int    strategy_spread_cap_points          = 80;
input bool   strategy_allow_long                 = true;
input bool   strategy_allow_short                = true;

double   g_range_high = 0.0;
double   g_range_low = 0.0;
bool     g_range_ready = false;
long     g_range_day_key = 0;
long     g_trade_day_key = 0;

long Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (long)dt.year * 10000 + (long)dt.mon * 100 + (long)dt.day;
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_ClampInt(const int value, const int lo, const int hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_SymbolContains(const string needle)
  {
   return (StringFind(_Symbol, needle) >= 0);
  }

void Strategy_Profile(int &start_minute, int &duration_minutes, int &close_minute)
  {
   start_minute = Strategy_ClampInt(strategy_range_start_hour, 0, 23) * 60 +
                  Strategy_ClampInt(strategy_range_start_minute, 0, 59);
   duration_minutes = Strategy_ClampInt(strategy_range_duration_minutes, 15, 720);
   close_minute = Strategy_ClampInt(strategy_close_hour, 0, 23) * 60 +
                  Strategy_ClampInt(strategy_close_minute, 0, 59);

   if(!strategy_use_symbol_profile)
      return;

   if(Strategy_SymbolContains("NDX"))
     {
      start_minute = 11 * 60 + 50;
      duration_minutes = 220;
      close_minute = 21 * 60 + 50;
      return;
     }
   if(Strategy_SymbolContains("SP500"))
     {
      start_minute = 8 * 60 + 35;
      duration_minutes = 375;
      close_minute = 19 * 60;
      return;
     }
   if(Strategy_SymbolContains("GDAXI"))
     {
      start_minute = 1 * 60 + 20;
      duration_minutes = 510;
      close_minute = 18 * 60 + 15;
      return;
     }
   if(Strategy_SymbolContains("XAUUSD"))
     {
      start_minute = 3 * 60 + 5;
      duration_minutes = 180;
      close_minute = 18 * 60 + 55;
      return;
     }
   if(Strategy_SymbolContains("EURJPY"))
     {
      start_minute = 8 * 60;
      duration_minutes = 75;
      close_minute = 21 * 60;
      return;
     }
   if(Strategy_SymbolContains("AUDJPY"))
     {
      start_minute = 3 * 60;
      duration_minutes = 345;
      close_minute = 18 * 60;
      return;
     }
   if(Strategy_SymbolContains("CADJPY"))
     {
      start_minute = 4 * 60 + 50;
      duration_minutes = 505;
      close_minute = 23 * 60;
      return;
     }
   if(Strategy_SymbolContains("USDJPY") || Strategy_SymbolContains("GBPJPY") || Strategy_SymbolContains("NZDJPY"))
     {
      start_minute = 3 * 60;
      duration_minutes = 180;
      close_minute = 18 * 60;
      return;
     }
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

void Strategy_ResetRange(const long day_key)
  {
   g_range_day_key = day_key;
   g_range_high = 0.0;
   g_range_low = 0.0;
   g_range_ready = false;
  }

bool Strategy_BuildRangeForToday()
  {
   const datetime now = TimeCurrent();
   const long day_key = Strategy_DayKey(now);
   if(g_range_day_key != day_key)
      Strategy_ResetRange(day_key);
   if(g_range_ready)
      return true;

   int start_minute = 0;
   int duration_minutes = 0;
   int close_minute = 0;
   Strategy_Profile(start_minute, duration_minutes, close_minute);

   int end_minute = start_minute + duration_minutes;
   if(end_minute > 24 * 60)
      end_minute = 24 * 60;
   if(Strategy_MinutesOfDay(now) < end_minute)
      return false;

   const datetime day_start = Strategy_DayStart(now);
   const datetime from_time = day_start + start_minute * 60;
   const datetime to_time = day_start + end_minute * 60 - 1;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_M1, from_time, to_time, rates); // perf-allowed: once-per-day M1 opening-range reconstruction from the card.
   int min_bars = strategy_min_range_m1_bars;
   if(min_bars < 2)
      min_bars = 2;
   if(copied < min_bars)
      return false;

   double high = rates[0].high;
   double low = rates[0].low;
   for(int i = 1; i < copied; ++i)
     {
      if(rates[i].high > high)
         high = rates[i].high;
      if(rates[i].low < low)
         low = rates[i].low;
     }

   if(high <= low || low <= 0.0)
      return false;

   g_range_high = high;
   g_range_low = low;
   g_range_ready = true;
   return true;
  }

bool Strategy_RangeSizeAllowed()
  {
   const double range = g_range_high - g_range_low;
   if(range <= 0.0)
      return false;

   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(d1_atr <= 0.0)
      return true;
   if(strategy_min_range_d1_atr_mult > 0.0 && range < strategy_min_range_d1_atr_mult * d1_atr)
      return false;
   if(strategy_max_range_d1_atr_mult > 0.0 && range > strategy_max_range_d1_atr_mult * d1_atr)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(strategy_spread_cap_points > 0 && ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_spread_cap_points)
         return true;
     }
   if(strategy_sl_range_mult <= 0.0 || strategy_tp_range_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime now = TimeCurrent();
   const long day_key = Strategy_DayKey(now);
   if(g_trade_day_key == day_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_BuildRangeForToday())
      return false;
   if(!Strategy_RangeSizeAllowed())
      return false;

   int start_minute = 0;
   int duration_minutes = 0;
   int close_minute = 0;
   Strategy_Profile(start_minute, duration_minutes, close_minute);
   int end_minute = start_minute + duration_minutes;
   if(end_minute > 24 * 60)
      end_minute = 24 * 60;

   const int minute_now = Strategy_MinutesOfDay(now);
   if(minute_now < end_minute || minute_now >= close_minute)
      return false;

   const double close_last = iClose(_Symbol, strategy_entry_tf, 1); // perf-allowed: closed-bar breakout confirmation after range lock.
   if(close_last <= 0.0)
      return false;

   const double range = g_range_high - g_range_low;
   const double buffer = MathMax(0.0, strategy_entry_buffer_range_pct) * range;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(strategy_allow_long && close_last > g_range_high + buffer)
     {
      const double entry = ask;
      req.type = QM_BUY;
      req.price = 0.0;
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      req.sl = QM_TM_NormalizePrice(_Symbol, entry - strategy_sl_range_mult * range);
      req.tp = QM_TM_NormalizePrice(_Symbol, entry + strategy_tp_range_mult * range);
      req.reason = "TIMERANGE_ORB_LONG";
      if(req.sl > 0.0 && req.tp > 0.0 && req.sl < entry && req.tp > entry)
        {
         g_trade_day_key = day_key;
         return true;
        }
     }

   if(strategy_allow_short && close_last < g_range_low - buffer)
     {
      const double entry = bid;
      req.type = QM_SELL;
      req.price = 0.0;
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      req.sl = QM_TM_NormalizePrice(_Symbol, entry + strategy_sl_range_mult * range);
      req.tp = QM_TM_NormalizePrice(_Symbol, entry - strategy_tp_range_mult * range);
      req.reason = "TIMERANGE_ORB_SHORT";
      if(req.sl > 0.0 && req.tp > 0.0 && req.sl > entry && req.tp < entry)
        {
         g_trade_day_key = day_key;
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
   if(!Strategy_HasOpenPosition())
      return false;

   int start_minute = 0;
   int duration_minutes = 0;
   int close_minute = 0;
   Strategy_Profile(start_minute, duration_minutes, close_minute);
   return (Strategy_MinutesOfDay(TimeCurrent()) >= close_minute);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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

