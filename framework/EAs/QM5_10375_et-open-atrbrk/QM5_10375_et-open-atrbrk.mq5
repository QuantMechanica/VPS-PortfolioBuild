#property strict
#property version   "5.0"
#property description "QM5_10375 Elite Trader Session Open ATR Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10375;
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
input ENUM_TIMEFRAMES strategy_trade_tf          = PERIOD_M5;
input int    strategy_atr_period                 = 20;
input double strategy_entry_atr_mult             = 0.30;
input double strategy_target_atr_mult            = 0.60;
input int    strategy_final_order_minutes        = 30;
input int    strategy_us_session_start_hhmm      = 1530;
input int    strategy_us_session_end_hhmm        = 2200;
input int    strategy_dax_session_start_hhmm     = 900;
input int    strategy_dax_session_end_hhmm       = 1730;
input int    strategy_gold_session_start_hhmm    = 800;
input int    strategy_gold_session_end_hhmm      = 2100;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_MinutesOfDay(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

void Strategy_SessionForSymbol(int &start_hhmm, int &end_hhmm)
  {
   start_hhmm = strategy_us_session_start_hhmm;
   end_hhmm = strategy_us_session_end_hhmm;

   if(StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "GER40") >= 0)
     {
      start_hhmm = strategy_dax_session_start_hhmm;
      end_hhmm = strategy_dax_session_end_hhmm;
      return;
     }

   if(StringFind(_Symbol, "XAUUSD") >= 0)
     {
      start_hhmm = strategy_gold_session_start_hhmm;
      end_hhmm = strategy_gold_session_end_hhmm;
     }
  }

bool Strategy_InMinuteWindow(const int now_min, const int start_min, const int end_min)
  {
   if(start_min <= end_min)
      return (now_min >= start_min && now_min < end_min);
   return (now_min >= start_min || now_min < end_min);
  }

bool Strategy_IsOurStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
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

int Strategy_OurPendingStopCount()
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
      if(Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
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

void Strategy_DeleteOurPendingStops(const string reason)
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
      if(!Strategy_IsOurStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      Strategy_DeletePendingOrder(ticket, reason);
     }
  }

bool Strategy_CurrentSpread(double &spread_price)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   spread_price = ask - bid;
   return true;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_IsFirstClosedSessionBar(datetime &bar_time)
  {
   bar_time = iTime(_Symbol, strategy_trade_tf, 1);
   if(bar_time <= 0)
      return false;

   int start_hhmm = 0;
   int end_hhmm = 0;
   Strategy_SessionForSymbol(start_hhmm, end_hhmm);
   return (Strategy_Hhmm(bar_time) == start_hhmm);
  }

int Strategy_SecondsUntilFinalOrderWindow(const datetime now)
  {
   int start_hhmm = 0;
   int end_hhmm = 0;
   Strategy_SessionForSymbol(start_hhmm, end_hhmm);

   const int now_min = Strategy_MinutesOfDay(Strategy_Hhmm(now));
   const int end_min = Strategy_MinutesOfDay(end_hhmm);
   int remaining_minutes = end_min - now_min - MathMax(0, strategy_final_order_minutes);
   if(remaining_minutes <= 0)
      remaining_minutes += 24 * 60;
   return MathMax(60, remaining_minutes * 60);
  }

bool Strategy_FinalOrderWindowOrLater(const datetime now)
  {
   int start_hhmm = 0;
   int end_hhmm = 0;
   Strategy_SessionForSymbol(start_hhmm, end_hhmm);
   const int now_min = Strategy_MinutesOfDay(Strategy_Hhmm(now));
   const int start_min = Strategy_MinutesOfDay(start_hhmm);
   const int end_min = Strategy_MinutesOfDay(end_hhmm);
   const int final_start = end_min - MathMax(0, strategy_final_order_minutes);
   return Strategy_InMinuteWindow(now_min, final_start, end_min) || !Strategy_InMinuteWindow(now_min, start_min, end_min);
  }

// No Trade Filter (time, spread, news): entry timing and spread guard, with
// pending/position pass-through so management and session-close cleanup can run.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;

   const datetime now = TimeCurrent();
   if(Strategy_FinalOrderWindowOrLater(now))
      return true;

   double spread = 0.0;
   if(!Strategy_CurrentSpread(spread))
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0)
      return true;

   const double band_distance = strategy_entry_atr_mult * atr;
   if(band_distance < 4.0 * spread)
      return true;

   return false;
  }

// Trade Entry: at the first M5 bar of the primary session, bracket the session
// open with symmetric ATR stop orders.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   static int s_order_day = -1;
   const datetime now = TimeCurrent();
   const int day_key = Strategy_DayKey(now);
   if(s_order_day != day_key && Strategy_OurPendingStopCount() == 0 && !Strategy_HasOurOpenPosition())
      s_order_day = -1;

   if(s_order_day == day_key)
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;
   if(Strategy_FinalOrderWindowOrLater(now))
      return false;

   datetime session_bar_time = 0;
   if(!Strategy_IsFirstClosedSessionBar(session_bar_time))
      return false;

   const double session_open = iOpen(_Symbol, strategy_trade_tf, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, strategy_atr_period), 1);
   double spread = 0.0;
   if(session_open <= 0.0 || atr <= 0.0 || !Strategy_CurrentSpread(spread))
      return false;

   const double band = strategy_entry_atr_mult * atr;
   const double target_dist = strategy_target_atr_mult * atr;
   if(band <= 0.0 || target_dist <= 0.0 || band < 4.0 * spread)
      return false;

   const double long_entry = QM_TM_NormalizePrice(_Symbol, session_open + band);
   const double short_entry = QM_TM_NormalizePrice(_Symbol, session_open - band);
   if(long_entry <= 0.0 || short_entry <= 0.0 || long_entry <= short_entry)
      return false;

   QM_EntryRequest buy_req;
   Strategy_InitRequest(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = long_entry;
   buy_req.sl = QM_TM_NormalizePrice(_Symbol, session_open - band);
   buy_req.tp = QM_TM_NormalizePrice(_Symbol, long_entry + target_dist);
   buy_req.reason = "ET_OPEN_ATRBRK_BUY_STOP";
   buy_req.expiration_seconds = Strategy_SecondsUntilFinalOrderWindow(now);

   req.type = QM_SELL_STOP;
   req.price = short_entry;
   req.sl = QM_TM_NormalizePrice(_Symbol, session_open + band);
   req.tp = QM_TM_NormalizePrice(_Symbol, short_entry - target_dist);
   req.reason = "ET_OPEN_ATRBRK_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = Strategy_SecondsUntilFinalOrderWindow(now);

   if(buy_req.sl <= 0.0 || buy_req.sl >= buy_req.price || buy_req.tp <= buy_req.price)
      return false;
   if(req.sl <= req.price || req.tp >= req.price || req.tp <= 0.0)
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   s_order_day = day_key;
   return true;
  }

// Trade Management: cancel the unfilled bracket side after one side fills, and
// remove any remaining pending stops at the final-order/session boundary.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOurOpenPosition())
     {
      Strategy_DeleteOurPendingStops("opposite_order_after_fill");
      return;
     }

   if(Strategy_FinalOrderWindowOrLater(TimeCurrent()))
      Strategy_DeleteOurPendingStops("session_final_order_window");
  }

// Trade Close: flat any open position at the mapped session close.
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition())
      return false;

   int start_hhmm = 0;
   int end_hhmm = 0;
   Strategy_SessionForSymbol(start_hhmm, end_hhmm);
   const int now_min = Strategy_MinutesOfDay(Strategy_Hhmm(TimeCurrent()));
   const int start_min = Strategy_MinutesOfDay(start_hhmm);
   const int end_min = Strategy_MinutesOfDay(end_hhmm);
   return !Strategy_InMinuteWindow(now_min, start_min, end_min);
  }

// News Filter Hook: callable P8 hook; default defers to framework two-axis news.
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
