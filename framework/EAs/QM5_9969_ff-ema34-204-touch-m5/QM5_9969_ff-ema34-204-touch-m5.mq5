#property strict
#property version   "5.0"
#property description "QM5_9969 EMA34/204 first-touch swing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9969;
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
input int    strategy_fast_ema_period      = 34;
input int    strategy_slow_ema_period      = 204;
input int    strategy_atr_period           = 14;
input int    strategy_swing_lookback_bars  = 5;
input double strategy_sl_buffer_pips       = 1.0;
input double strategy_reward_r             = 2.0;
input double strategy_min_stop_atr         = 0.5;
input double strategy_max_stop_atr         = 2.0;
input double strategy_max_spread_stop_frac = 0.12;
input int    strategy_session_start_hour   = 9;
input int    strategy_session_end_hour     = 19;
input int    strategy_time_stop_bars       = 36;

int g_cross_state = 0;
int g_bars_since_cross = 0;
bool g_trade_fired_for_cross = false;

double PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

int BrokerHour(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

bool InEntrySession(const datetime t)
  {
   const int h = BrokerHour(t);
   if(strategy_session_start_hour == strategy_session_end_hour)
      return true;
   if(strategy_session_start_hour < strategy_session_end_hour)
      return (h >= strategy_session_start_hour && h < strategy_session_end_hour);
   return (h >= strategy_session_start_hour || h < strategy_session_end_hour);
  }

double BarHigh(const int shift)
  {
   return iHigh(_Symbol, _Period, shift); // perf-allowed: closed-bar touch/swing structure from the card
  }

double BarLow(const int shift)
  {
   return iLow(_Symbol, _Period, shift); // perf-allowed: closed-bar touch/swing structure from the card
  }

double BarClose(const int shift)
  {
   return iClose(_Symbol, _Period, shift); // perf-allowed: closed-bar touch confirmation from the card
  }

double RecentSwingLow(const int lookback)
  {
   double low = DBL_MAX;
   for(int i = 1; i <= lookback; ++i)
      low = MathMin(low, BarLow(i));
   return (low == DBL_MAX) ? 0.0 : low;
  }

double RecentSwingHigh(const int lookback)
  {
   double high = -DBL_MAX;
   for(int i = 1; i <= lookback; ++i)
      high = MathMax(high, BarHigh(i));
   return (high == -DBL_MAX) ? 0.0 : high;
  }

bool CrossedUp()
  {
   const double fast_now = QM_EMA(_Symbol, _Period, strategy_fast_ema_period, 1);
   const double slow_now = QM_EMA(_Symbol, _Period, strategy_slow_ema_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_fast_ema_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_slow_ema_period, 2);
   return (fast_prev <= slow_prev && fast_now > slow_now);
  }

bool CrossedDown()
  {
   const double fast_now = QM_EMA(_Symbol, _Period, strategy_fast_ema_period, 1);
   const double slow_now = QM_EMA(_Symbol, _Period, strategy_slow_ema_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_fast_ema_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_slow_ema_period, 2);
   return (fast_prev >= slow_prev && fast_now < slow_now);
  }

bool AdvanceCrossState()
  {
   if(CrossedUp())
     {
      g_cross_state = 1;
      g_bars_since_cross = 0;
      g_trade_fired_for_cross = false;
      return true;
     }

   if(CrossedDown())
     {
      g_cross_state = -1;
      g_bars_since_cross = 0;
      g_trade_fired_for_cross = false;
      return true;
     }

   if(g_cross_state != 0 && g_bars_since_cross < 1000000)
      ++g_bars_since_cross;
   return false;
  }

bool SignalBarTouchedEma(const double ema_fast, const double ema_slow)
  {
   const double high = BarHigh(1);
   const double low = BarLow(1);
   if(high <= 0.0 || low <= 0.0)
      return false;
   return ((low <= ema_fast && ema_fast <= high) ||
           (low <= ema_slow && ema_slow <= high));
  }

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &type, double &open_price, double &sl, datetime &open_time)
  {
   ticket = 0;
   type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
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

   const bool cross_changed = AdvanceCrossState();
   if(cross_changed || g_cross_state == 0 || g_bars_since_cross < 1)
      return false;
   if(g_trade_fired_for_cross)
      return false;
   if(!InEntrySession(TimeCurrent()))
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_fast_ema_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_slow_ema_period, 1);
   const double close_1 = BarClose(1);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double pip = PipSize();
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || close_1 <= 0.0 || atr <= 0.0 || pip <= 0.0)
      return false;
   if(!SignalBarTouchedEma(ema_fast, ema_slow))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double buffer = strategy_sl_buffer_pips * pip;
   const double spread = ask - bid;

   if(g_cross_state > 0 && close_1 > ema_fast)
     {
      const double entry = ask;
      const double swing = RecentSwingLow(strategy_swing_lookback_bars);
      const double sl = swing - buffer;
      const double stop_dist = entry - sl;
      if(swing <= 0.0 || stop_dist <= 0.0)
         return false;
      if(stop_dist < strategy_min_stop_atr * atr || stop_dist > strategy_max_stop_atr * atr)
         return false;
      if(spread > strategy_max_spread_stop_frac * stop_dist)
         return false;

      req.type = QM_BUY;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry + stop_dist * strategy_reward_r, _Digits);
      req.reason = "EMA34_204_FIRST_TOUCH_LONG";
      g_trade_fired_for_cross = true;
      return true;
     }

   if(g_cross_state < 0 && close_1 < ema_fast)
     {
      const double entry = bid;
      const double swing = RecentSwingHigh(strategy_swing_lookback_bars);
      const double sl = swing + buffer;
      const double stop_dist = sl - entry;
      if(swing <= 0.0 || stop_dist <= 0.0)
         return false;
      if(stop_dist < strategy_min_stop_atr * atr || stop_dist > strategy_max_stop_atr * atr)
         return false;
      if(spread > strategy_max_spread_stop_frac * stop_dist)
         return false;

      req.type = QM_SELL;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry - stop_dist * strategy_reward_r, _Digits);
      req.reason = "EMA34_204_FIRST_TOUCH_SHORT";
      g_trade_fired_for_cross = true;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double open_price;
   double sl;
   datetime open_time;
   if(!SelectOurPosition(ticket, type, open_price, sl, open_time))
      return;
   if(open_price <= 0.0 || sl <= 0.0)
      return;

   const double r = MathAbs(open_price - sl);
   if(r <= 0.0)
      return;

   if(type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid - open_price >= r && sl < open_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "breakeven_at_1r");
     }
   else
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price - ask >= r && sl > open_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "breakeven_at_1r");
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double open_price;
   double sl;
   datetime open_time;
   if(!SelectOurPosition(ticket, type, open_price, sl, open_time))
      return false;

   const int hold_seconds = strategy_time_stop_bars * PeriodSeconds(_Period);
   if(hold_seconds > 0 && open_time > 0 && (TimeCurrent() - open_time) >= hold_seconds)
      return true;

   if(type == POSITION_TYPE_BUY && CrossedDown())
      return true;
   if(type == POSITION_TYPE_SELL && CrossedUp())
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9969_ff_ema34_204_touch_m5\"}");
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
