#property strict
#property version   "5.0"
#property description "QM5_1204 Zarattini-Aziz VWAP trend trading port to NDX"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1204;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
enum StrategyVwapVolumeMode
  {
   VWAP_TICK_VOLUME = 0,
   VWAP_EQUAL_BAR_VOLUME = 1
  };

input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M5;
input int             strategy_atr_period_m15     = 20;
input double          strategy_atr_sl_mult        = 1.2;
input StrategyVwapVolumeMode strategy_vwap_volume = VWAP_TICK_VOLUME;
input int             strategy_session_start_hour = 16;
input int             strategy_session_start_min  = 30;
input int             strategy_session_end_hour   = 23;
input int             strategy_session_end_min    = 0;
input int             strategy_flatten_before_min = 5;
input int             strategy_min_session_min    = 30;
input int             strategy_min_entry_bars_left = 2;
input int             strategy_max_spread_points  = 80;

const string STRATEGY_SYMBOL = "NDX.DWX";

double   g_session_vwap = 0.0;
double   g_vwap_pv_sum = 0.0;
double   g_vwap_volume_sum = 0.0;
int      g_session_date_key = 0;
datetime g_last_vwap_bar = 0;
datetime g_last_entry_bar = 0;
datetime g_last_exit_bar = 0;
bool     g_last_closed_above_vwap = false;
bool     g_last_closed_below_vwap = false;

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

bool Strategy_IsSessionTime(const datetime value)
  {
   const int minute = Strategy_MinutesOfDay(value);
   const int start_minute = strategy_session_start_hour * 60 + strategy_session_start_min;
   const int end_minute = strategy_session_end_hour * 60 + strategy_session_end_min;
   return (minute >= start_minute && minute < end_minute);
  }

bool Strategy_IsEntryWindow(const datetime value)
  {
   const int minute = Strategy_MinutesOfDay(value);
   const int start_minute = strategy_session_start_hour * 60 + strategy_session_start_min + strategy_min_session_min;
   const int end_minute = strategy_session_end_hour * 60 + strategy_session_end_min - strategy_flatten_before_min;
   const int bars_left = (end_minute - minute) / MathMax(1, PeriodSeconds(strategy_signal_tf) / 60);
   return (minute >= start_minute && minute < end_minute && bars_left >= strategy_min_entry_bars_left);
  }

bool Strategy_IsFlattenWindow(const datetime value)
  {
   const int minute = Strategy_MinutesOfDay(value);
   const int flatten_minute = strategy_session_end_hour * 60 + strategy_session_end_min - strategy_flatten_before_min;
   return (minute >= flatten_minute);
  }

void Strategy_ResetSession(const datetime broker_time)
  {
   g_session_date_key = Strategy_DateKey(broker_time);
   g_session_vwap = 0.0;
   g_vwap_pv_sum = 0.0;
   g_vwap_volume_sum = 0.0;
   g_last_vwap_bar = 0;
   g_last_closed_above_vwap = false;
   g_last_closed_below_vwap = false;
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

double Strategy_AtrStop(const QM_OrderType side, const double entry)
  {
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period_m15, 1);
   if(entry <= 0.0 || atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return 0.0;

   const double distance = atr * strategy_atr_sl_mult;
   const double stop = QM_OrderTypeIsBuy(side) ? (entry - distance) : (entry + distance);
   return NormalizeDouble(stop, _Digits);
  }

void Strategy_AdvanceVwap()
  {
   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_vwap_bar)
      return;

   g_last_vwap_bar = bar_time;
   if(g_session_date_key != Strategy_DateKey(bar_time))
      Strategy_ResetSession(bar_time);

   g_last_closed_above_vwap = false;
   g_last_closed_below_vwap = false;

   if(!Strategy_IsSessionTime(bar_time))
      return;

   const double high = iHigh(_Symbol, strategy_signal_tf, 1);
   const double low = iLow(_Symbol, strategy_signal_tf, 1);
   const double close = iClose(_Symbol, strategy_signal_tf, 1);
   double volume = (double)iVolume(_Symbol, strategy_signal_tf, 1);
   if(strategy_vwap_volume == VWAP_EQUAL_BAR_VOLUME)
      volume = 1.0;

   if(high <= 0.0 || low <= 0.0 || close <= 0.0 || volume <= 0.0)
      return;

   const double typical = (high + low + close) / 3.0;
   g_vwap_pv_sum += typical * volume;
   g_vwap_volume_sum += volume;
   if(g_vwap_volume_sum <= 0.0)
      return;

   g_session_vwap = NormalizeDouble(g_vwap_pv_sum / g_vwap_volume_sum, _Digits);
   g_last_closed_above_vwap = (close > g_session_vwap);
   g_last_closed_below_vwap = (close < g_session_vwap);
  }

bool Strategy_SpreadOk()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(strategy_max_spread_points <= 0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   return ((ask - bid) / point <= strategy_max_spread_points);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;

   const datetime broker_now = TimeCurrent();
   if(g_session_date_key != Strategy_DateKey(broker_now))
      Strategy_ResetSession(broker_now);

   if(QM_IsNewBar(_Symbol, strategy_signal_tf))
      Strategy_AdvanceVwap();

   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   if(!Strategy_HasOpenPosition(ticket, type))
     {
      if(!Strategy_IsEntryWindow(broker_now))
         return true;
      if(!Strategy_SpreadOk())
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_AdvanceVwap();

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1);
   if(bar_time <= 0 || bar_time == g_last_entry_bar)
      return false;
   if(g_session_vwap <= 0.0 || !Strategy_IsEntryWindow(TimeCurrent()))
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   if(Strategy_HasOpenPosition(ticket, type))
      return false;

   QM_OrderType side;
   if(g_last_closed_above_vwap)
      side = QM_BUY;
   else if(g_last_closed_below_vwap)
      side = QM_SELL;
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = Strategy_AtrStop(side, entry);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "zarattini_vwap_ndx";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_last_entry_bar = bar_time;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   Strategy_AdvanceVwap();

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

   if(g_session_vwap <= 0.0)
      return false;

   if(type == POSITION_TYPE_BUY && g_last_closed_below_vwap)
     {
      g_last_exit_bar = bar_time;
      return true;
     }
   if(type == POSITION_TYPE_SELL && g_last_closed_above_vwap)
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
   QM_BasketWarmupHistory(symbols, PERIOD_M15, MathMax(200, strategy_atr_period_m15 + 80));

   Strategy_ResetSession(TimeCurrent());
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1204_zarattini-vwap-ndx\"}");
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

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf))
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
