#property strict
#property version   "5.0"
#property description "QM5_10752 TradingView NQ VWAP ORB ATR Brackets"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10752;
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
input int    strategy_or_minutes          = 15;
input int    strategy_session_open_hour   = 15;
input int    strategy_session_open_minute = 30;
input int    strategy_session_close_hour  = 21;
input int    strategy_session_close_minute = 55;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 1.5;
input double strategy_target_r            = 2.0;
input bool   strategy_use_vwap_filter     = true;
input bool   strategy_use_volume_filter   = false;
input int    strategy_volume_lookback     = 20;
input double strategy_volume_mult         = 1.25;
input int    strategy_max_daily_trades    = 1;
input int    strategy_max_spread_points   = 0;
input int    strategy_max_hold_minutes    = 0;
input bool   strategy_use_atr_trailing    = false;
input double strategy_trail_trigger_r     = 1.0;
input double strategy_trail_atr_mult      = 1.0;

#define STRATEGY_VOL_WINDOW_MAX 256

int      g_state_day_key = 0;
bool     g_or_has_range = false;
bool     g_or_locked = false;
double   g_or_high = 0.0;
double   g_or_low = 0.0;
double   g_session_pv = 0.0;
double   g_session_volume = 0.0;
double   g_session_vwap = 0.0;
bool     g_last_volume_pass = true;
int      g_trades_today = 0;
double   g_volume_window[STRATEGY_VOL_WINDOW_MAX];
int      g_volume_count = 0;
int      g_volume_index = 0;
double   g_volume_sum = 0.0;

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

datetime Strategy_SessionStartFor(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = MathMax(0, MathMin(23, strategy_session_open_hour));
   dt.min = MathMax(0, MathMin(59, strategy_session_open_minute));
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_OpenMinuteOfDay()
  {
   return MathMax(0, MathMin(23, strategy_session_open_hour)) * 60 +
          MathMax(0, MathMin(59, strategy_session_open_minute));
  }

int Strategy_CloseMinuteOfDay()
  {
   return MathMax(0, MathMin(23, strategy_session_close_hour)) * 60 +
          MathMax(0, MathMin(59, strategy_session_close_minute));
  }

void Strategy_ResetSessionState(const int day_key)
  {
   g_state_day_key = day_key;
   g_or_has_range = false;
   g_or_locked = false;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_session_pv = 0.0;
   g_session_volume = 0.0;
   g_session_vwap = 0.0;
   g_last_volume_pass = !strategy_use_volume_filter;
   g_trades_today = 0;
   g_volume_count = 0;
   g_volume_index = 0;
   g_volume_sum = 0.0;
   ArrayInitialize(g_volume_window, 0.0);
  }

void Strategy_EnsureDayState(const datetime t)
  {
   const int key = Strategy_DateKey(t);
   if(g_state_day_key != key)
      Strategy_ResetSessionState(key);
  }

bool Strategy_InsideTradeSession(const datetime t)
  {
   const int now_min = Strategy_MinutesOfDay(t);
   const int open_min = Strategy_OpenMinuteOfDay();
   const int close_min = Strategy_CloseMinuteOfDay();
   if(open_min <= close_min)
      return (now_min >= open_min && now_min <= close_min);
   return (now_min >= open_min || now_min <= close_min);
  }

bool Strategy_HasOurOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   return ((ask - bid) / point <= strategy_max_spread_points);
  }

void Strategy_UpdateVolumeState(const double tick_volume)
  {
   const int lookback = MathMin(MathMax(strategy_volume_lookback, 1), STRATEGY_VOL_WINDOW_MAX);
   const double avg_volume = (g_volume_count > 0) ? (g_volume_sum / g_volume_count) : 0.0;
   g_last_volume_pass = !strategy_use_volume_filter ||
                        (avg_volume > 0.0 && tick_volume >= avg_volume * strategy_volume_mult);

   if(g_volume_count < lookback)
     {
      g_volume_window[g_volume_index] = tick_volume;
      g_volume_sum += tick_volume;
      g_volume_count++;
      g_volume_index = (g_volume_index + 1) % lookback;
      return;
     }

   g_volume_sum -= g_volume_window[g_volume_index];
   g_volume_window[g_volume_index] = tick_volume;
   g_volume_sum += tick_volume;
   g_volume_index = (g_volume_index + 1) % lookback;
  }

bool Strategy_AdvanceStateFromClosedBar(MqlRates &bar)
  {
   Strategy_EnsureDayState(bar.time);

   const datetime session_start = Strategy_SessionStartFor(bar.time);
   const datetime or_end = session_start + MathMax(1, strategy_or_minutes) * 60;
   if(bar.time < session_start)
      return false;

   const double tick_volume = MathMax(1.0, (double)bar.tick_volume);
   const double typical = (bar.high + bar.low + bar.close) / 3.0;
   g_session_pv += typical * tick_volume;
   g_session_volume += tick_volume;
   if(g_session_volume > 0.0)
      g_session_vwap = g_session_pv / g_session_volume;

   Strategy_UpdateVolumeState(tick_volume);

   if(bar.time < or_end)
     {
      if(!g_or_has_range)
        {
         g_or_high = bar.high;
         g_or_low = bar.low;
         g_or_has_range = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, bar.high);
         g_or_low = MathMin(g_or_low, bar.low);
        }
      return false;
     }

   if(g_or_has_range)
      g_or_locked = true;
   return g_or_locked;
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

bool Strategy_BuildMarketRequest(const QM_OrderType side,
                                 const double entry,
                                 const string reason,
                                 QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   Strategy_InitRequest(req);
   req.type = side;
   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_stop_mult);
   req.tp = QM_TakeRR(_Symbol, side, entry, req.sl, strategy_target_r);
   req.reason = reason;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_EnsureDayState(broker_now);

   if(!Strategy_InsideTradeSession(broker_now))
      return !Strategy_HasOurOpenPosition();
   if(!Strategy_SpreadAllowed())
      return true;
   if(strategy_max_daily_trades > 0 && g_trades_today >= strategy_max_daily_trades)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(Strategy_HasOurOpenPosition())
      return false;
   if(!Strategy_InsideTradeSession(TimeCurrent()))
      return false;
   if(strategy_max_daily_trades > 0 && g_trades_today >= strategy_max_daily_trades)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // Strategy_EntrySignal is called by framework OnTick only after QM_IsNewBar().
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, rates) != 1) // perf-allowed
      return false;

   MqlRates bar = rates[0];
   if(!Strategy_AdvanceStateFromClosedBar(bar))
      return false;
   if(!g_last_volume_pass)
      return false;
   if(g_session_vwap <= 0.0 || g_or_high <= 0.0 || g_or_low <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(bar.close > g_or_high && (!strategy_use_vwap_filter || bar.close > g_session_vwap))
     {
      if(Strategy_BuildMarketRequest(QM_BUY, ask, "OR_BREAK_VWAP_LONG", req))
        {
         g_trades_today++;
         return true;
        }
     }

   if(bar.close < g_or_low && (!strategy_use_vwap_filter || bar.close < g_session_vwap))
     {
      if(Strategy_BuildMarketRequest(QM_SELL, bid, "OR_BREAK_VWAP_SHORT", req))
        {
         g_trades_today++;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_use_atr_trailing)
      return;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || sl <= 0.0)
         continue;

      const double current = (ptype == POSITION_TYPE_BUY)
                             ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                             : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk_distance = MathAbs(open_price - sl);
      const double profit_distance = (ptype == POSITION_TYPE_BUY)
                                     ? (current - open_price)
                                     : (open_price - current);
      if(risk_distance > 0.0 && profit_distance >= risk_distance * strategy_trail_trigger_r)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   if(Strategy_MinutesOfDay(broker_now) >= Strategy_CloseMinuteOfDay())
      return true;

   if(strategy_max_hold_minutes <= 0)
      return false;

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
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && broker_now - opened >= strategy_max_hold_minutes * 60)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10752_tv-nq-vwap-orb\"}");
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
