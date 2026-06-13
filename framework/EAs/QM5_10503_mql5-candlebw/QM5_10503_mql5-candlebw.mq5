#property strict
#property version   "5.0"
#property description "QM5_10503 MQL5 CandlesticksBW color-change session EA"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10503;
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
input ENUM_TIMEFRAMES strategy_work_tf     = PERIOD_H4;
input int    strategy_ao_fast_period       = 5;
input int    strategy_ao_slow_period       = 34;
input int    strategy_ac_smooth_period     = 5;
input bool   strategy_session_enabled      = true;
input int    strategy_session_start_hour   = 0;
input int    strategy_session_start_minute = 0;
input int    strategy_session_end_hour     = 23;
input int    strategy_session_end_minute   = 59;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 1.5;
input double strategy_take_profit_rr       = 1.5;

int Strategy_MinuteOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_ClampSessionMinute(const int hour_value, const int minute_value)
  {
   const int h = MathMax(0, MathMin(23, hour_value));
   const int m = MathMax(0, MathMin(59, minute_value));
   return h * 60 + m;
  }

bool Strategy_IsWithinSession(const datetime broker_time)
  {
   if(!strategy_session_enabled)
      return true;

   const int now_minute = Strategy_MinuteOfDay(broker_time);
   const int start_minute = Strategy_ClampSessionMinute(strategy_session_start_hour,
                                                        strategy_session_start_minute);
   const int end_minute = Strategy_ClampSessionMinute(strategy_session_end_hour,
                                                      strategy_session_end_minute);

   if(start_minute == end_minute)
      return now_minute == start_minute;
   if(start_minute < end_minute)
      return (now_minute >= start_minute && now_minute < end_minute);
   return (now_minute >= start_minute || now_minute < end_minute);
  }

double Strategy_AO(const int shift)
  {
   if(shift < 1 ||
      strategy_ao_fast_period <= 0 ||
      strategy_ao_slow_period <= strategy_ao_fast_period)
      return EMPTY_VALUE;

   const double fast = QM_SMA(_Symbol, strategy_work_tf, strategy_ao_fast_period, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, strategy_work_tf, strategy_ao_slow_period, shift, PRICE_MEDIAN);
   if(fast == 0.0 || slow == 0.0)
      return EMPTY_VALUE;

   return fast - slow;
  }

double Strategy_AC(const int shift)
  {
   if(strategy_ac_smooth_period <= 0)
      return EMPTY_VALUE;

   const double ao_now = Strategy_AO(shift);
   if(ao_now == EMPTY_VALUE)
      return EMPTY_VALUE;

   double ao_sum = 0.0;
   for(int i = 0; i < strategy_ac_smooth_period; ++i)
     {
      const double ao = Strategy_AO(shift + i);
      if(ao == EMPTY_VALUE)
         return EMPTY_VALUE;
      ao_sum += ao;
     }

   return ao_now - (ao_sum / strategy_ac_smooth_period);
  }

int Strategy_CandlesticksBWState(const int shift)
  {
   const double ao_now = Strategy_AO(shift);
   const double ao_prev = Strategy_AO(shift + 1);
   const double ac_now = Strategy_AC(shift);
   const double ac_prev = Strategy_AC(shift + 1);
   if(ao_now == EMPTY_VALUE || ao_prev == EMPTY_VALUE ||
      ac_now == EMPTY_VALUE || ac_prev == EMPTY_VALUE)
      return 0;

   if(ao_now >= ao_prev && ac_now >= ac_prev)
      return 1;
   if(ao_now <= ao_prev && ac_now <= ac_prev)
      return -1;
   return 0;
  }

bool Strategy_FindOurPosition(ENUM_POSITION_TYPE &position_type,
                              datetime &opened_at,
                              ulong &ticket)
  {
   position_type = POSITION_TYPE_BUY;
   opened_at = 0;
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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      ticket = candidate;
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   ulong ticket;
   if(Strategy_FindOurPosition(position_type, opened_at, ticket))
      return false;

   return !Strategy_IsWithinSession(TimeCurrent());
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

   if(!Strategy_IsWithinSession(TimeCurrent()))
      return false;

   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   ulong ticket;
   if(Strategy_FindOurPosition(position_type, opened_at, ticket))
      return false;

   const int state_now = Strategy_CandlesticksBWState(1);
   const int state_prev = Strategy_CandlesticksBWState(2);
   if(state_now == 0 || state_now == state_prev)
      return false;

   const bool is_long = (state_now > 0);
   const QM_OrderType side = is_long ? QM_BUY : QM_SELL;
   const double entry = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_work_tf, strategy_atr_period, 1);
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr);
   if(atr <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = is_long ? "CANDLEBW_BULL_COLOR_CHANGE" : "CANDLEBW_BEAR_COLOR_CHANGE";
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // The card specifies fixed initial SL/TP only; no trailing, BE, or partial logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   ulong ticket;
   if(!Strategy_FindOurPosition(position_type, opened_at, ticket))
      return false;

   if(!Strategy_IsWithinSession(TimeCurrent()))
      return true;

   const int state_now = Strategy_CandlesticksBWState(1);
   const int state_prev = Strategy_CandlesticksBWState(2);
   if(state_now == 0 || state_now == state_prev)
      return false;

   if(position_type == POSITION_TYPE_BUY && state_now < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && state_now > 0)
      return true;
   return false;
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
