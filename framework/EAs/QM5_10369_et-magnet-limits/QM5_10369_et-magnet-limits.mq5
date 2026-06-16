#property strict
#property version   "5.0"
#property description "QM5_10369 Elite Trader Magnet Limit Bracket"
// rework v2 2026-06-16: max-bracket sanity cap compared a session-scale bracket (0.70% of price) against an M1/M5 ATR (a few bp) -> always rejected -> 0 fills -> MIN_TRADES. Cap now uses a daily-scale ATR so it only rejects abnormally wide brackets; intraday stop still uses M1/M5 ATR.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10369;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_M1;
input int    strategy_open_hour_broker         = 16;
input int    strategy_open_minute_broker       = 30;
input int    strategy_cancel_hour_broker       = 19;
input int    strategy_cancel_minute_broker     = 0;
input int    strategy_exit_hour_broker         = 23;
input int    strategy_exit_minute_broker       = 0;
input double strategy_bracket_pct              = 0.35;
input int    strategy_atr_period               = 14;
input double strategy_stop_atr_mult            = 0.30;
input double strategy_max_bracket_atr_mult     = 1.20;
input double strategy_min_spread_width_mult    = 4.0;

int Strategy_ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_ConfiguredHhmm(const int hour_value, const int minute_value)
  {
   return Strategy_ClampInt(hour_value, 0, 23) * 100 + Strategy_ClampInt(minute_value, 0, 59);
  }

bool Strategy_IsOpenBar(const datetime bar_time)
  {
   return Strategy_Hhmm(bar_time) == Strategy_ConfiguredHhmm(strategy_open_hour_broker, strategy_open_minute_broker);
  }

bool Strategy_CurrentSpread(double &spread_price)
  {
   spread_price = 0.0;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   spread_price = ask - bid;
   return true;
  }

bool Strategy_HasOurOpenPosition()
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

bool Strategy_IsOurLimitOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT);
  }

int Strategy_OurPendingLimitCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurLimitOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

bool Strategy_DeletePendingOrder(const ulong ticket, const string reason)
  {
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   request.symbol = _Symbol;
   request.comment = reason;

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);
   QM_LogEvent(ok ? QM_INFO : QM_WARN,
               "PENDING_DELETE",
               StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
                            ticket,
                            QM_LoggerEscapeJson(reason),
                            ok ? "true" : "false",
                            result.retcode,
                            QM_LoggerEscapeJson(error_class)));
   return ok;
  }

void Strategy_DeleteOurPendingLimits(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurLimitOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      Strategy_DeletePendingOrder(ticket, reason);
     }
  }

void Strategy_InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: bracket limit orders around the 08:30 Chicago-equivalent open.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitEntryRequest(req);

   if(strategy_timeframe != PERIOD_M1 && strategy_timeframe != PERIOD_M5)
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingLimitCount() > 0)
      return false;

   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 1);
   if(bar_time <= 0 || !Strategy_IsOpenBar(bar_time))
      return false;

   const double session_open = iOpen(_Symbol, strategy_timeframe, 1);
   if(session_open <= 0.0 || strategy_bracket_pct <= 0.0)
      return false;

   double spread_price = 0.0;
   if(!Strategy_CurrentSpread(spread_price))
      return false;

   const double bracket_distance = session_open * (strategy_bracket_pct / 100.0);
   const double bracket_width = bracket_distance * 2.0;
   if(bracket_width <= 0.0)
      return false;
   if(strategy_min_spread_width_mult > 0.0 && bracket_width < strategy_min_spread_width_mult * spread_price)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0)
      return false;
   // Max-bracket sanity cap must use a daily-scale ATR: the bracket is sized as a
   // percent of the session open (session-scale), so comparing it to an intraday
   // M1/M5 ATR (orders of magnitude smaller) would reject every normal day.
   const double atr_daily = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, strategy_atr_period), 1);
   if(atr_daily <= 0.0)
      return false;
   if(strategy_max_bracket_atr_mult > 0.0 && bracket_width > strategy_max_bracket_atr_mult * atr_daily)
      return false;
   if(strategy_stop_atr_mult <= 0.0)
      return false;

   const double buy_limit = QM_TM_NormalizePrice(_Symbol, session_open - bracket_distance);
   const double sell_limit = QM_TM_NormalizePrice(_Symbol, session_open + bracket_distance);
   const double target = QM_TM_NormalizePrice(_Symbol, session_open);
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(buy_limit <= 0.0 || sell_limit <= 0.0 || target <= 0.0 || stop_distance <= 0.0)
      return false;
   if(!(buy_limit < session_open && session_open < sell_limit))
      return false;

   QM_EntryRequest buy_req;
   Strategy_InitEntryRequest(buy_req);
   buy_req.type = QM_BUY_LIMIT;
   buy_req.price = buy_limit;
   buy_req.sl = QM_TM_NormalizePrice(_Symbol, buy_limit - stop_distance);
   buy_req.tp = target;
   buy_req.reason = "ET_MAGNET_BUY_LIMIT";

   req.type = QM_SELL_LIMIT;
   req.price = sell_limit;
   req.sl = QM_TM_NormalizePrice(_Symbol, sell_limit + stop_distance);
   req.tp = target;
   req.reason = "ET_MAGNET_SELL_LIMIT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(buy_req.sl <= 0.0 || buy_req.sl >= buy_limit || req.sl <= sell_limit)
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   return true;
  }

// Trade Management: first fill wins; cancel the opposite bracket order.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOurOpenPosition())
     {
      Strategy_DeleteOurPendingLimits("opposite_order_after_fill");
      return;
     }

   if(Strategy_Hhmm(TimeCurrent()) >= Strategy_ConfiguredHhmm(strategy_cancel_hour_broker, strategy_cancel_minute_broker))
      Strategy_DeleteOurPendingLimits("entry_window_expired");
  }

// Trade Close: flatten any still-open position at the 15:00 Chicago-equivalent exit.
bool Strategy_ExitSignal()
  {
   if(Strategy_Hhmm(TimeCurrent()) < Strategy_ConfiguredHhmm(strategy_exit_hour_broker, strategy_exit_minute_broker))
      return false;
   return Strategy_HasOurOpenPosition();
  }

// News Filter Hook: central FW1 news filter handles high-impact blackout.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(strategy_timeframe != PERIOD_M1 && strategy_timeframe != PERIOD_M5)
      return INIT_PARAMETERS_INCORRECT;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10369\",\"ea\":\"et-magnet-limits\"}");
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
