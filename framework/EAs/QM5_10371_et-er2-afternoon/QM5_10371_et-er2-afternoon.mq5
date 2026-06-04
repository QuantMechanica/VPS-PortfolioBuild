#property strict
#property version   "5.0"
#property description "QM5_10371 Elite Trader ER2 Afternoon Open-Price Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10371;
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
input int    strategy_us_session_open_hhmm = 1530;
input int    strategy_eu_session_open_hhmm = 900;
input int    strategy_entry_hhmm_broker    = 2100;
input int    strategy_exit_hhmm_broker     = 2300;
input double strategy_trigger_pct          = 0.0033;
input int    strategy_atr_period           = 14;
input double strategy_atr_cap_mult         = 1.5;
input double strategy_min_spread_multiple  = 4.0;

datetime g_trade_day = 0;
bool     g_setup_done_today = false;
bool     g_trade_seen_today = false;

datetime DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime DayTime(const datetime day, const int hhmm)
  {
   return day + (hhmm / 100) * 3600 + (hhmm % 100) * 60;
  }

int SessionOpenHhmm()
  {
   if(_Symbol == "GDAXI.DWX")
      return strategy_eu_session_open_hhmm;
   return strategy_us_session_open_hhmm;
  }

void ResetDailyStateIfNeeded()
  {
   const datetime today = DateKey(TimeCurrent());
   if(today == g_trade_day)
      return;
   g_trade_day = today;
   g_setup_done_today = false;
   g_trade_seen_today = false;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool IsOurPendingType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void CancelOurPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         QM_TM_RemovePendingOrder(ticket, "QM5_10371_CANCEL_PENDING");
     }
  }

bool ReadSessionOpenPrice(double &open_price)
  {
   open_price = 0.0;
   const datetime session_open = DayTime(g_trade_day, SessionOpenHhmm());
   int shift = iBarShift(_Symbol, PERIOD_M1, session_open, false);
   if(shift < 0)
      return false;

   // perf-allowed: exact regular-session open M1 bar lookup
   const datetime bar_time = iTime(_Symbol, PERIOD_M1, shift); // perf-allowed: exact regular-session open M1 bar lookup
   if(bar_time <= 0 || MathAbs((int)(bar_time - session_open)) > 5 * 60)
      return false;

   // perf-allowed: exact regular-session open price from resolved M1 bar
   open_price = iOpen(_Symbol, PERIOD_M1, shift); // perf-allowed: exact regular-session open price from resolved M1 bar
   return (open_price > 0.0);
  }

double AtrCappedStop(const QM_OrderType side, const double entry, const double opposite_trigger)
  {
   double sl = opposite_trigger;
   if(strategy_atr_cap_mult > 0.0 && strategy_atr_period > 0)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period, 1);
      const double cap = atr * strategy_atr_cap_mult;
      if(atr > 0.0 && cap > 0.0)
        {
         if(QM_OrderTypeIsBuy(side) && entry - sl > cap)
            sl = entry - cap;
         if(!QM_OrderTypeIsBuy(side) && sl - entry > cap)
            sl = entry + cap;
        }
     }
   return NormalizeDouble(sl, _Digits);
  }

bool SpreadAllowsBracket(const double session_open)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(point <= 0.0 || spread_points <= 0)
      return true;

   const double trigger_distance = session_open * strategy_trigger_pct;
   const double spread_distance = spread_points * point;
   return (trigger_distance >= strategy_min_spread_multiple * spread_distance);
  }

void InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildRequest(const QM_OrderType type,
                  const double entry,
                  const double stop,
                  const int expiration_seconds,
                  const string reason,
                  QM_EntryRequest &req)
  {
   InitRequest(req);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double market_ref = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double risk_entry = (entry > 0.0) ? entry : market_ref;
   if(risk_entry <= 0.0 || stop <= 0.0 || point <= 0.0)
      return false;
   if(MathAbs(risk_entry - stop) / point <= 0.0)
      return false;

   req.type = type;
   req.price = (entry > 0.0) ? NormalizeDouble(entry, _Digits) : 0.0;
   req.sl = NormalizeDouble(stop, _Digits);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   ResetDailyStateIfNeeded();

   if(HasOurOpenPosition())
      return false;

   if(TimeCurrent() >= DayTime(g_trade_day, strategy_exit_hhmm_broker))
     {
      CancelOurPendingOrders();
      return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitRequest(req);
   ResetDailyStateIfNeeded();

   if(g_setup_done_today || g_trade_seen_today || HasOurOpenPosition() || HasOurPendingOrder())
      return false;

   const datetime now = TimeCurrent();
   const datetime entry_time = DayTime(g_trade_day, strategy_entry_hhmm_broker);
   const datetime exit_time = DayTime(g_trade_day, strategy_exit_hhmm_broker);
   if(now < entry_time || now >= exit_time)
      return false;

   double session_open = 0.0;
   if(!ReadSessionOpenPrice(session_open))
      return false;

   if(strategy_trigger_pct <= 0.0 || !SpreadAllowsBracket(session_open))
     {
      g_setup_done_today = true;
      return false;
     }

   const double long_trigger = NormalizeDouble(session_open * (1.0 + strategy_trigger_pct), _Digits);
   const double short_trigger = NormalizeDouble(session_open * (1.0 - strategy_trigger_pct), _Digits);
   const int expiry_seconds = (int)MathMax(60, exit_time - now);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || long_trigger <= short_trigger)
      return false;

   if(ask >= long_trigger)
     {
      const double sl = AtrCappedStop(QM_BUY, ask, short_trigger);
      if(BuildRequest(QM_BUY, 0.0, sl, 0, "ET_ER2_MARKET_LONG", req))
        {
         g_setup_done_today = true;
         return true;
        }
      return false;
     }

   if(bid <= short_trigger)
     {
      const double sl = AtrCappedStop(QM_SELL, bid, long_trigger);
      if(BuildRequest(QM_SELL, 0.0, sl, 0, "ET_ER2_MARKET_SHORT", req))
        {
         g_setup_done_today = true;
         return true;
        }
      return false;
     }

   QM_EntryRequest buy_req;
   const double buy_sl = AtrCappedStop(QM_BUY_STOP, long_trigger, short_trigger);
   if(!BuildRequest(QM_BUY_STOP, long_trigger, buy_sl, expiry_seconds, "ET_ER2_BUY_STOP", buy_req))
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   const double sell_sl = AtrCappedStop(QM_SELL_STOP, short_trigger, long_trigger);
   if(BuildRequest(QM_SELL_STOP, short_trigger, sell_sl, expiry_seconds, "ET_ER2_SELL_STOP", req))
     {
      g_setup_done_today = true;
      return true;
     }

   CancelOurPendingOrders();
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(HasOurOpenPosition())
     {
      g_trade_seen_today = true;
      CancelOurPendingOrders();
     }
  }

bool Strategy_ExitSignal()
  {
   ResetDailyStateIfNeeded();
   if(!HasOurOpenPosition())
      return false;
   return (TimeCurrent() >= DayTime(g_trade_day, strategy_exit_hhmm_broker));
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
