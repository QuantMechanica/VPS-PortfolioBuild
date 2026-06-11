#property strict
#property version   "5.0"
#property description "QM5_10077 GitHub kai Setup 9.1 EMA Turn Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10077;
input int    qm_magic_slot_offset       = 0;
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
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_M5;
input int    strategy_ema_period         = 9;
input int    strategy_entry_start_hhmm   = 900;
input int    strategy_entry_end_hhmm     = 1600;
input int    strategy_flat_hhmm          = 1730;
input int    strategy_take_profit_points = 1000;

enum StrategySignal
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
  };

int    g_prior_signal = SIGNAL_NONE;
int    g_signal_day_key = 0;
int    g_latest_signal = SIGNAL_NONE;
double g_latest_signal_breakout = 0.0;

int Hhmm(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool InEntrySession(const datetime value)
  {
   const int now_hhmm = Hhmm(value);
   return (now_hhmm >= strategy_entry_start_hhmm && now_hhmm <= strategy_entry_end_hhmm);
  }

bool IsFlatTime(const datetime value)
  {
   return (Hhmm(value) >= strategy_flat_hhmm);
  }

int SecondsUntilEndOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 23;
   dt.min = 59;
   dt.sec = 59;
   const datetime end_of_day = StructToTime(dt);
   const int seconds = (int)(end_of_day - value);
   return (seconds > 60) ? seconds : 60;
  }

double NormalizeSymbolPrice(const double price)
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

int CurrentSignal()
  {
   if(strategy_ema_period < 2)
      return SIGNAL_NONE;

   const double ema_last = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1, PRICE_CLOSE);
   const double ema_prev = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 2, PRICE_CLOSE);
   if(ema_last <= 0.0 || ema_prev <= 0.0)
      return SIGNAL_NONE;
   if(ema_last > ema_prev)
      return SIGNAL_BUY;
   if(ema_last < ema_prev)
      return SIGNAL_SELL;
   return SIGNAL_NONE;
  }

bool IsOurPendingOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP ||
           order_type == ORDER_TYPE_SELL_STOP ||
           order_type == ORDER_TYPE_BUY_LIMIT ||
           order_type == ORDER_TYPE_SELL_LIMIT);
  }

int PendingOrderSignal(const ENUM_ORDER_TYPE order_type)
  {
   if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)
      return SIGNAL_BUY;
   if(order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT)
      return SIGNAL_SELL;
   return SIGNAL_NONE;
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

bool HasOurPendingOrder(const int signal_filter = SIGNAL_NONE)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsOurPendingOrderType(order_type))
         continue;
      if(signal_filter == SIGNAL_NONE || PendingOrderSignal(order_type) == signal_filter)
         return true;
     }
   return false;
  }

void RemoveOurPendingOrders(const string reason, const int signal_filter = SIGNAL_NONE)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsOurPendingOrderType(order_type))
         continue;
      if(signal_filter != SIGNAL_NONE && PendingOrderSignal(order_type) != signal_filter)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool ReadSignalBar(MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: two closed M5 signal candles; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   if(CopyRates(_Symbol, strategy_timeframe, 1, 2, rates) != 2)
      return false;
   bar = rates[0];
   return (bar.high > 0.0 && bar.low > 0.0);
  }

// Return TRUE to BLOCK trading this tick. Session gating is applied in the
// entry hook so timed pending-order removal and position close can still run.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   const int today = DayKey(broker_now);
   if(today != g_signal_day_key)
     {
      g_signal_day_key = today;
      g_prior_signal = SIGNAL_NONE;
      g_latest_signal = SIGNAL_NONE;
      g_latest_signal_breakout = 0.0;
     }

   MqlRates signal_bar;
   if(!ReadSignalBar(signal_bar))
      return false;

   const int signal = CurrentSignal();
   if(signal == SIGNAL_NONE)
      return false;

   g_latest_signal = signal;
   g_latest_signal_breakout = (signal == SIGNAL_BUY) ? signal_bar.high : signal_bar.low;

   const int previous_signal = g_prior_signal;
   g_prior_signal = signal;

   if(previous_signal != SIGNAL_NONE && previous_signal != signal)
      RemoveOurPendingOrders("opposite_ema_signal", previous_signal);

   if(!InEntrySession(broker_now) || IsFlatTime(broker_now))
      return false;
   if(HasOurPosition() || HasOurPendingOrder())
      return false;
   if(previous_signal == SIGNAL_SELL && signal == SIGNAL_BUY)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(point <= 0.0 || ask <= 0.0)
         return false;

      const double entry = NormalizeSymbolPrice(signal_bar.high);
      const double sl = NormalizeSymbolPrice(signal_bar.low);
      if(entry <= ask || entry <= sl)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = NormalizeSymbolPrice(entry + strategy_take_profit_points * point);
      req.reason = "SETUP91_EMA_TURN_BUY_STOP";
      req.expiration_seconds = SecondsUntilEndOfDay(broker_now);
      return true;
     }

   if(previous_signal == SIGNAL_BUY && signal == SIGNAL_SELL)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || bid <= 0.0)
         return false;

      const double entry = NormalizeSymbolPrice(signal_bar.low);
      const double sl = NormalizeSymbolPrice(signal_bar.high);
      if(entry >= bid || entry >= sl)
         return false;

      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = NormalizeSymbolPrice(entry - strategy_take_profit_points * point);
      req.reason = "SETUP91_EMA_TURN_SELL_STOP";
      req.expiration_seconds = SecondsUntilEndOfDay(broker_now);
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(g_latest_signal == SIGNAL_NONE || g_latest_signal_breakout <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double target_sl = NormalizeSymbolPrice(g_latest_signal_breakout);
      if(position_type == POSITION_TYPE_BUY && g_latest_signal == SIGNAL_SELL)
        {
         if(current_sl <= 0.0 || target_sl > current_sl + point * 0.5)
            QM_TM_MoveSL(ticket, target_sl, "opposite_ema_signal_breakout");
        }
      else if(position_type == POSITION_TYPE_SELL && g_latest_signal == SIGNAL_BUY)
        {
         if(current_sl <= 0.0 || target_sl < current_sl - point * 0.5)
            QM_TM_MoveSL(ticket, target_sl, "opposite_ema_signal_breakout");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   if(!IsFlatTime(TimeCurrent()))
      return false;

   RemoveOurPendingOrders("strategy_flat_time");
   return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10077_gh-kai-setup91\"}");
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

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
