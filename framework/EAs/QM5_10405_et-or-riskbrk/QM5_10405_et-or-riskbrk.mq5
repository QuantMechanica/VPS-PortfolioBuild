#property strict
#property version   "5.0"
#property description "QM5_10405 Elite Trader Fixed-Risk Opening Range Breakout"
// rework v2 2026-06-16: Q02 MIN_TRADES_NOT_MET root cause = framework risk sizer.
// This EA's opening-range stops are very tight on high-priced indices (WS30 ~40pts),
// so RISK_FIXED=$1000 demanded >100 lots -> clamped to SYMBOL_VOLUME_MAX -> tester
// rejected ~95% of daily brackets as "deleted [no money]" (1 fill / 6 months on WS30).
// Fix in QM_RiskSizer.mqh: apply a free-margin lot cap even when SYMBOL_MARGIN_INITIAL==0
// (DWX custom symbols), making the bracket affordable. Strategy logic unchanged.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10405;
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
input int    strategy_opening_range_bars       = 3;
input int    strategy_breakout_ticks           = 1;
input int    strategy_stop_buffer_ticks        = 1;
input double strategy_target_rr                = 1.0;
input int    strategy_atr_period               = 20;
input double strategy_max_range_atr_mult       = 2.5;
input int    strategy_us_session_start_hhmm    = 1530;
input int    strategy_us_session_end_hhmm      = 2200;
input int    strategy_dax_session_start_hhmm   = 900;
input int    strategy_dax_session_end_hhmm     = 1730;
input int    strategy_gold_session_start_hhmm  = 800;
input int    strategy_gold_session_end_hhmm    = 2100;

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

bool Strategy_InMinuteWindow(const int now_min, const int start_min, const int end_min)
  {
   if(start_min <= end_min)
      return (now_min >= start_min && now_min < end_min);
   return (now_min >= start_min || now_min < end_min);
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

bool Strategy_SessionWindow(int &start_min, int &end_min)
  {
   int start_hhmm = 0;
   int end_hhmm = 0;
   Strategy_SessionForSymbol(start_hhmm, end_hhmm);
   start_min = Strategy_MinutesOfDay(start_hhmm);
   end_min = Strategy_MinutesOfDay(end_hhmm);
   return (start_min >= 0 && start_min < 1440 && end_min >= 0 && end_min <= 1440);
  }

bool Strategy_InSessionNow()
  {
   int start_min = 0;
   int end_min = 0;
   if(!Strategy_SessionWindow(start_min, end_min))
      return false;
   const int now_min = Strategy_MinutesOfDay(Strategy_Hhmm(TimeCurrent()));
   return Strategy_InMinuteWindow(now_min, start_min, end_min);
  }

int Strategy_SecondsUntilSessionEnd()
  {
   int start_min = 0;
   int end_min = 0;
   if(!Strategy_SessionWindow(start_min, end_min))
      return 3600;

   const int now_min = Strategy_MinutesOfDay(Strategy_Hhmm(TimeCurrent()));
   int remaining_minutes = end_min - now_min;
   if(remaining_minutes <= 0)
      remaining_minutes += 24 * 60;
   return MathMax(60, remaining_minutes * 60);
  }

bool Strategy_LastClosedBarIsFirstSessionBar()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   int start_hhmm = 0;
   int end_hhmm = 0;
   Strategy_SessionForSymbol(start_hhmm, end_hhmm);
   return (Strategy_Hhmm(bar_time) == start_hhmm);
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

// No Trade Filter (time, spread, news): framework handles news; this hook blocks
// new entry setup outside the mapped session while allowing management cleanup.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0)
      return false;

   if(!Strategy_InSessionNow())
      return true;

   double spread_price = 0.0;
   return !Strategy_CurrentSpread(spread_price);
  }

// Trade Entry: build the first three M5 bars into an opening range, then place
// long/short breakout stop orders one tick beyond that range.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(strategy_opening_range_bars <= 0 ||
      strategy_breakout_ticks <= 0 ||
      strategy_stop_buffer_ticks < 0 ||
      strategy_target_rr <= 0.0 ||
      strategy_atr_period <= 0 ||
      strategy_max_range_atr_mult <= 0.0)
      return false;

   static int    s_day_key = -1;
   static int    s_range_bars = 0;
   static bool   s_range_ready = false;
   static bool   s_orders_placed = false;
   static double s_range_high = 0.0;
   static double s_range_low = 0.0;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   const int day_key = Strategy_DayKey(bar_time);
   if(day_key != s_day_key || Strategy_LastClosedBarIsFirstSessionBar())
     {
      if(day_key != s_day_key || !s_range_ready)
        {
         s_day_key = day_key;
         s_range_bars = 0;
         s_range_ready = false;
         s_orders_placed = false;
         s_range_high = 0.0;
         s_range_low = 0.0;
        }
     }

   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingStopCount() > 0 || s_orders_placed)
      return false;
   if(!Strategy_InSessionNow())
      return false;

   if(!s_range_ready)
     {
      if(s_range_bars == 0 && !Strategy_LastClosedBarIsFirstSessionBar())
         return false;

      const double high = iHigh(_Symbol, _Period, 1);
      const double low = iLow(_Symbol, _Period, 1);
      if(high <= 0.0 || low <= 0.0 || high <= low)
         return false;

      if(s_range_bars == 0)
        {
         s_range_high = high;
         s_range_low = low;
        }
      else
        {
         s_range_high = MathMax(s_range_high, high);
         s_range_low = MathMin(s_range_low, low);
        }

      ++s_range_bars;
      if(s_range_bars >= strategy_opening_range_bars)
         s_range_ready = true;
      return false;
     }

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      return false;

   double spread_price = 0.0;
   if(!Strategy_CurrentSpread(spread_price))
      return false;

   const double range_width = s_range_high - s_range_low;
   const double stop_distance = range_width + (strategy_breakout_ticks + strategy_stop_buffer_ticks) * tick_size;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(range_width <= 0.0 ||
      stop_distance <= 0.0 ||
      atr <= 0.0 ||
      range_width < spread_price + 2.0 * tick_size ||
      stop_distance > strategy_max_range_atr_mult * atr)
      return false;

   const double buy_entry = QM_TM_NormalizePrice(_Symbol, s_range_high + strategy_breakout_ticks * tick_size);
   const double sell_entry = QM_TM_NormalizePrice(_Symbol, s_range_low - strategy_breakout_ticks * tick_size);
   if(buy_entry <= 0.0 || sell_entry <= 0.0 || buy_entry <= sell_entry)
      return false;

   QM_EntryRequest buy_req;
   Strategy_InitRequest(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = QM_TM_NormalizePrice(_Symbol, s_range_low - strategy_stop_buffer_ticks * tick_size);
   buy_req.tp = QM_TM_NormalizePrice(_Symbol, buy_entry + strategy_target_rr * MathAbs(buy_entry - buy_req.sl));
   buy_req.reason = "ET_OR_RISKBRK_BUY_STOP";
   buy_req.expiration_seconds = Strategy_SecondsUntilSessionEnd();

   req.type = QM_SELL_STOP;
   req.price = sell_entry;
   req.sl = QM_TM_NormalizePrice(_Symbol, s_range_high + strategy_stop_buffer_ticks * tick_size);
   req.tp = QM_TM_NormalizePrice(_Symbol, sell_entry - strategy_target_rr * MathAbs(req.sl - sell_entry));
   req.reason = "ET_OR_RISKBRK_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = Strategy_SecondsUntilSessionEnd();

   if(buy_req.sl <= 0.0 || buy_req.sl >= buy_req.price || buy_req.tp <= buy_req.price)
      return false;
   if(req.sl <= req.price || req.tp >= req.price || req.tp <= 0.0)
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   s_orders_placed = true;
   return true;
  }

// Trade Management: no trailing/partial logic; only remove obsolete bracket
// stops after a fill or at the session boundary.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOurOpenPosition())
     {
      Strategy_DeleteOurPendingStops("opposite_order_after_fill");
      return;
     }

   if(!Strategy_InSessionNow())
      Strategy_DeleteOurPendingStops("session_close_pending_cleanup");
  }

// Trade Close: flatten at session end for intraday backtest/session hygiene.
bool Strategy_ExitSignal()
  {
   return (Strategy_HasOurOpenPosition() && !Strategy_InSessionNow());
  }

// News Filter Hook (callable for P8 News Impact phase): defer to framework.
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
