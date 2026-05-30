#property strict
#property version   "5.0"
#property description "QM5_1255 Zarattini-Aziz QQQ opening range breakout on NDX"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1255;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf           = PERIOD_M5;
input int             strategy_opening_range_min   = 5;
input int             strategy_atr_period          = 14;
input double          strategy_atr_stop_mult       = 1.0;
input int             strategy_session_start_hour  = 16;
input int             strategy_session_start_min   = 30;
input int             strategy_session_end_hour    = 23;
input int             strategy_session_end_min     = 0;
input int             strategy_flatten_before_min  = 5;
input int             strategy_max_spread_points   = 80;
input int             strategy_min_history_bars    = 80;
input bool            strategy_one_trade_per_day   = true;

const string STRATEGY_SYMBOL = "NDX.DWX";

int      g_session_date_key = 0;
double   g_or_high = 0.0;
double   g_or_low = 0.0;
bool     g_range_ready = false;
bool     g_traded_today = false;
datetime g_last_processed_bar = 0;
datetime g_last_entry_bar = 0;
datetime g_last_exit_bar = 0;
bool     g_long_breakout = false;
bool     g_short_breakout = false;

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinutesOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_SessionStartMinute()
  {
   return strategy_session_start_hour * 60 + strategy_session_start_min;
  }

int Strategy_SessionEndMinute()
  {
   return strategy_session_end_hour * 60 + strategy_session_end_min;
  }

int Strategy_RangeEndMinute()
  {
   return Strategy_SessionStartMinute() + MathMax(1, strategy_opening_range_min);
  }

bool Strategy_IsFlattenWindow(const datetime value)
  {
   const int minute = Strategy_MinutesOfDay(value);
   return (minute >= Strategy_SessionEndMinute() - MathMax(0, strategy_flatten_before_min));
  }

bool Strategy_IsEntryWindow(const datetime value)
  {
   const int minute = Strategy_MinutesOfDay(value);
   const int entry_start = Strategy_RangeEndMinute();
   const int entry_end = Strategy_SessionEndMinute() - MathMax(0, strategy_flatten_before_min);
   return (minute >= entry_start && minute < entry_end);
  }

void Strategy_ResetSession(const datetime broker_time)
  {
   g_session_date_key = Strategy_DateKey(broker_time);
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_range_ready = false;
   g_traded_today = false;
   g_last_processed_bar = 0;
   g_long_breakout = false;
   g_short_breakout = false;
  }

bool Strategy_HasOpenPosition(ulong &ticket, ENUM_POSITION_TYPE &type)
  {
   ticket = 0;
   type = POSITION_TYPE_BUY;

   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
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
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_SpreadOk()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   return ((ask - bid) / point <= (double)strategy_max_spread_points);
  }

bool Strategy_StopOk(const QM_OrderType side, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

double Strategy_InitialStop(const QM_OrderType side, const double entry)
  {
   if(!g_range_ready || g_or_high <= g_or_low || entry <= 0.0)
      return 0.0;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);
   const double range_distance = g_or_high - g_or_low;
   const double atr_distance = (atr > 0.0 ? atr * MathMax(0.0, strategy_atr_stop_mult) : 0.0);
   const double min_distance = MathMax(range_distance, atr_distance);
   if(min_distance <= 0.0)
      return 0.0;

   double stop = 0.0;
   if(side == QM_BUY)
      stop = MathMin(g_or_low, entry - min_distance);
   else
      stop = MathMax(g_or_high, entry + min_distance);

   return NormalizeDouble(stop, _Digits);
  }

void Strategy_AdvanceOpeningRange()
  {
   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_processed_bar)
      return;

   g_last_processed_bar = bar_time;
   if(g_session_date_key != Strategy_DateKey(bar_time))
      Strategy_ResetSession(bar_time);

   g_long_breakout = false;
   g_short_breakout = false;

   const int minute = Strategy_MinutesOfDay(bar_time);
   const int start_minute = Strategy_SessionStartMinute();
   const int range_end_minute = Strategy_RangeEndMinute();

   const double high = iHigh(_Symbol, strategy_signal_tf, 1);
   const double low = iLow(_Symbol, strategy_signal_tf, 1);
   const double close = iClose(_Symbol, strategy_signal_tf, 1);
   if(high <= 0.0 || low <= 0.0 || close <= 0.0 || high < low)
      return;

   if(minute >= start_minute && minute < range_end_minute)
     {
      if(g_or_high <= 0.0 || high > g_or_high)
         g_or_high = high;
      if(g_or_low <= 0.0 || low < g_or_low)
         g_or_low = low;
      return;
     }

   if(minute >= range_end_minute && g_or_high > g_or_low)
      g_range_ready = true;

   if(g_range_ready && Strategy_IsEntryWindow(bar_time))
     {
      g_long_breakout = (close > g_or_high);
      g_short_breakout = (close < g_or_low);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != strategy_signal_tf)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_opening_range_min <= 0 || strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return true;
   if(strategy_session_end_hour * 60 + strategy_session_end_min <= Strategy_RangeEndMinute())
      return true;
   if(Bars(_Symbol, strategy_signal_tf) < MathMax(strategy_min_history_bars, strategy_atr_period + 20))
      return true;

   const datetime broker_now = TimeCurrent();
   if(g_session_date_key != Strategy_DateKey(broker_now))
      Strategy_ResetSession(broker_now);

   Strategy_AdvanceOpeningRange();
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

   Strategy_AdvanceOpeningRange();

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_entry_bar)
      return false;
   if(!g_range_ready || !Strategy_IsEntryWindow(bar_time))
      return false;
   if(strategy_one_trade_per_day && g_traded_today)
      return false;
   if(!Strategy_SpreadOk())
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   if(Strategy_HasOpenPosition(ticket, type))
      return false;

   QM_OrderType side;
   if(g_long_breakout && !g_short_breakout)
      side = QM_BUY;
   else if(g_short_breakout && !g_long_breakout)
      side = QM_SELL;
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   const double sl = Strategy_InitialStop(side, entry);
   if(!Strategy_StopOk(side, entry, sl))
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "zarattini_qqq_orb";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_entry_bar = bar_time;
   g_traded_today = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   Strategy_AdvanceOpeningRange();

   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   if(!Strategy_HasOpenPosition(ticket, type))
      return false;

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_exit_bar)
      return false;

   if(Strategy_IsFlattenWindow(TimeCurrent()))
     {
      g_last_exit_bar = bar_time;
      return true;
     }

   if(!g_range_ready)
      return false;

   if(type == POSITION_TYPE_BUY && g_short_breakout)
     {
      g_last_exit_bar = bar_time;
      return true;
     }
   if(type == POSITION_TYPE_SELL && g_long_breakout)
     {
      g_last_exit_bar = bar_time;
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

   string symbols[1] = {STRATEGY_SYMBOL};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, strategy_signal_tf, MathMax(120, strategy_atr_period + 80));

   Strategy_ResetSession(TimeCurrent());
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1255_zarattini-qqq-orb\"}");
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
      const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
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
