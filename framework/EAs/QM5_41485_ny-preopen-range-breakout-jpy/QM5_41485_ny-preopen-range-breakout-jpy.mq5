#property strict
#property version   "5.0"
#property description "QM5_41485 DXZ NY pre-open range breakout on a :30-aligned grid"

#include <QM/QM_Common.mqh>

// Mechanical H-V4 revision-2 build. The fixed 15:30/23:00 clock contract is
// valid only for the Darwinex NY-close server clock. No FTMO set is admitted
// until the governed QM_SessionClock dependency exists and is verified.
// build-gate-allowed: broker-time-window -- the approved source proves the
// economic New York times map to these fixed DXZ server times in both seasons;
// cross-vendor reviewer afb38e9a approved this DXZ-only implementation.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41485;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_range_end_hour          = 15;
input int    strategy_range_end_minute        = 30;
input int    strategy_range_bars              = 2;
input int    strategy_exit_hour               = 23;
input int    strategy_exit_minute             = 0;
input int    strategy_grid_offset_minutes     = 30;
input int    strategy_news_retry_window_minutes = 60;
input int    strategy_atr_period              = 14;
input double strategy_min_range_atr_mult      = 0.4;
input double strategy_max_range_atr_mult      = 2.5;
input double strategy_trail_trigger_r         = 1.0;
input int    strategy_range_scan_bars         = 36;

struct Strategy_GridBar
  {
   datetime start_time;
   datetime end_time;
   double   open;
   double   high;
   double   low;
   double   close;
  };

double g_strategy_range_high = 0.0;
double g_strategy_range_low = 0.0;
int    g_strategy_range_day_key = -1;
int    g_strategy_attempt_day_key = -1;

int Strategy_ServerDayKey(const datetime server_time)
  {
   MqlDateTime dt;
   TimeToStruct(server_time, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

datetime Strategy_ServerDayStart(const datetime server_time)
  {
   MqlDateTime dt;
   TimeToStruct(server_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_ServerMinuteOfDay(const datetime server_time)
  {
   MqlDateTime dt;
   TimeToStruct(server_time, dt);
   return dt.hour * 60 + dt.min;
  }

datetime Strategy_TodayAt(const datetime server_time, const int hour, const int minute)
  {
   return Strategy_ServerDayStart(server_time) + hour * 3600 + minute * 60;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_41485.%d.%s.attempt", QM_FrameworkMagic(), _Symbol);
  }

void Strategy_LoadAttemptState()
  {
   const string key = Strategy_AttemptStateKey();
   if(GlobalVariableCheck(key))
      g_strategy_attempt_day_key = (int)MathRound(GlobalVariableGet(key));
  }

void Strategy_MarkAttempt(const int day_key)
  {
   g_strategy_attempt_day_key = day_key;
   GlobalVariableSet(Strategy_AttemptStateKey(), (double)day_key);
  }

bool Strategy_IsOurPendingType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_IsOurPositionSelected()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

bool Strategy_IsOurOrderSelected()
  {
   return (OrderGetString(ORDER_SYMBOL) == _Symbol &&
           (int)OrderGetInteger(ORDER_MAGIC) == QM_FrameworkMagic() &&
           Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)));
  }

int Strategy_OurPendingCount()
  {
   int count = 0;
   if(QM_FrameworkMagic() <= 0)
      return count;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) || !Strategy_IsOurOrderSelected())
         continue;
      count++;
     }
   return count;
  }

bool Strategy_HasOurOpenPosition()
  {
   if(QM_FrameworkMagic() <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOurPositionSelected())
         return true;
     }
   return false;
  }

int Strategy_RemoveOurPendingOrders(const string reason)
  {
   int removed = 0;
   if(QM_FrameworkMagic() <= 0)
      return removed;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) || !Strategy_IsOurOrderSelected())
         continue;
      if(QM_TM_RemovePendingOrder(ticket, reason))
         removed++;
     }
   return removed;
  }

int Strategy_CloseOurPositions(const QM_ExitReason reason)
  {
   int closed = 0;
   if(QM_FrameworkMagic() <= 0)
      return closed;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsOurPositionSelected())
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         closed++;
     }
   return closed;
  }

// A grid bar ending at grid_end consists of two exact, completed M30 halves:
// [grid_end-60m, grid_end-30m) and [grid_end-30m, grid_end).
bool Strategy_ReadGridBar(const datetime grid_end, Strategy_GridBar &bar)
  {
   const datetime first_start = grid_end - 3600;
   const datetime second_start = grid_end - 1800;
   if(grid_end > TimeCurrent())
      return false;

   const int first_shift = iBarShift(_Symbol, PERIOD_M30, first_start, true);
   const int second_shift = iBarShift(_Symbol, PERIOD_M30, second_start, true);
   if(first_shift < 1 || second_shift < 1)
      return false;

   const datetime first_time = iTime(_Symbol, PERIOD_M30, first_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   const datetime second_time = iTime(_Symbol, PERIOD_M30, second_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   if(first_time != first_start || second_time != second_start)
      return false;

   const double first_open = iOpen(_Symbol, PERIOD_M30, first_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   const double first_high = iHigh(_Symbol, PERIOD_M30, first_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   const double first_low = iLow(_Symbol, PERIOD_M30, first_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   const double first_close = iClose(_Symbol, PERIOD_M30, first_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   const double second_open = iOpen(_Symbol, PERIOD_M30, second_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   const double second_high = iHigh(_Symbol, PERIOD_M30, second_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   const double second_low = iLow(_Symbol, PERIOD_M30, second_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   const double second_close = iClose(_Symbol, PERIOD_M30, second_shift); // perf-allowed: exact bounded two-half grid reconstruction.
   if(first_open <= 0.0 || first_high <= 0.0 || first_low <= 0.0 || first_close <= 0.0 ||
      second_open <= 0.0 || second_high <= 0.0 || second_low <= 0.0 || second_close <= 0.0 ||
      first_high < first_low || second_high < second_low)
      return false;

   bar.start_time = first_start;
   bar.end_time = grid_end;
   bar.open = first_open;
   bar.high = MathMax(first_high, second_high);
   bar.low = MathMin(first_low, second_low);
   bar.close = second_close;
   return true;
  }

bool Strategy_BuildRangeAndAtr(const datetime anchor,
                               double &range_high,
                               double &range_low,
                               double &atr)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;
   atr = 0.0;

   const int required_grid_bars = MathMax(strategy_range_bars, strategy_atr_period + 1);
   if(required_grid_bars <= 1 || strategy_range_scan_bars < required_grid_bars * 2)
      return false;

   Strategy_GridBar bars[];
   ArrayResize(bars, required_grid_bars);
   for(int i = 0; i < required_grid_bars; ++i)
     {
      if(!Strategy_ReadGridBar(anchor - i * 3600, bars[i]))
         return false;
      if(i < strategy_range_bars)
        {
         range_high = MathMax(range_high, bars[i].high);
         range_low = MathMin(range_low, bars[i].low);
        }
     }

   double tr_sum = 0.0;
   for(int i = 0; i < strategy_atr_period; ++i)
     {
      const double previous_close = bars[i + 1].close;
      const double tr = MathMax(bars[i].high - bars[i].low,
                                MathMax(MathAbs(bars[i].high - previous_close),
                                        MathAbs(bars[i].low - previous_close)));
      if(previous_close <= 0.0 || tr <= 0.0)
         return false;
      tr_sum += tr;
     }

   atr = tr_sum / (double)strategy_atr_period;
   return (range_low > 0.0 && range_high > range_low && atr > 0.0);
  }

datetime Strategy_MostRecentGridEnd(const datetime server_now)
  {
   datetime boundary = Strategy_ServerDayStart(server_now) + strategy_grid_offset_minutes * 60;
   if(boundary > server_now)
      boundary -= 86400;
   const long elapsed = (long)(server_now - boundary);
   boundary += (datetime)((elapsed / 3600) * 3600);
   return boundary;
  }

bool Strategy_ReadTrailLevels(const datetime server_now, double &trail_low, double &trail_high)
  {
   Strategy_GridBar newest;
   Strategy_GridBar prior;
   const datetime newest_end = Strategy_MostRecentGridEnd(server_now);
   if(!Strategy_ReadGridBar(newest_end, newest) ||
      !Strategy_ReadGridBar(newest_end - 3600, prior))
      return false;
   trail_low = MathMin(newest.low, prior.low);
   trail_high = MathMax(newest.high, prior.high);
   return (trail_low > 0.0 && trail_high > trail_low);
  }

void Strategy_PopulateEntry(QM_EntryRequest &req,
                            const QM_OrderType type,
                            const double entry,
                            const double sl,
                            const string reason)
  {
   ZeroMemory(req);
   req.type = type;
   req.price = Strategy_NormalizePrice(entry);
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// This hook sends and retains both legs itself, then returns false so the
// framework caller cannot send a third request.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.type = QM_BUY_STOP;
   req.symbol_slot = qm_magic_slot_offset;

   const datetime now = TimeCurrent();
   const int day_key = Strategy_ServerDayKey(now);
   const datetime anchor = Strategy_TodayAt(now, strategy_range_end_hour, strategy_range_end_minute);
   const datetime retry_end = anchor + strategy_news_retry_window_minutes * 60;
   if(now < anchor || now >= retry_end)
      return false;
   if(g_strategy_attempt_day_key == day_key)
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_OurPendingCount() > 0)
      return false;

   // Mark before any calculation/send so a data/filter rejection, dual send
   // failure, or terminal restart cannot turn into a second attempt that day.
   Strategy_MarkAttempt(day_key);

   double range_high = 0.0;
   double range_low = 0.0;
   double atr = 0.0;
   if(!Strategy_BuildRangeAndAtr(anchor, range_high, range_low, atr))
      return false;

   const double range_width = range_high - range_low;
   if(range_width < strategy_min_range_atr_mult * atr ||
      range_width > strategy_max_range_atr_mult * atr)
      return false;

   g_strategy_range_high = range_high;
   g_strategy_range_low = range_low;
   g_strategy_range_day_key = day_key;

   QM_EntryRequest buy_req;
   ZeroMemory(buy_req);  // MQL5: struct initializer lists are not allowed (compile fix 2026-09-21, Fable)
   QM_EntryRequest sell_req;
   ZeroMemory(sell_req);  // MQL5: struct initializer lists are not allowed (compile fix 2026-09-21, Fable)
   Strategy_PopulateEntry(buy_req, QM_BUY_STOP, range_high, range_low, "NY_PREOPEN_RANGE_BUY_STOP");
   Strategy_PopulateEntry(sell_req, QM_SELL_STOP, range_low, range_high, "NY_PREOPEN_RANGE_SELL_STOP");
   buy_req.type = QM_BUY_STOP;
   sell_req.type = QM_SELL_STOP;

   ulong buy_ticket = 0;
   ulong sell_ticket = 0;
   const bool buy_ok = QM_TM_OpenPosition(buy_req, buy_ticket);
   const bool sell_ok = QM_TM_OpenPosition(sell_req, sell_ticket);

   if(buy_ok != sell_ok)
     {
      // Fail closed: remove the sole accepted pending leg. If it raced into a
      // position, flatten it as well; reconciliation repeats on later ticks.
      Strategy_RemoveOurPendingOrders("NY_PREOPEN_ONE_SIDED_SEND");
      Strategy_CloseOurPositions(QM_EXIT_STRATEGY);
     }
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime now = TimeCurrent();
   const int current_day = Strategy_ServerDayKey(now);
   const int flat_minute = strategy_exit_hour * 60 + strategy_exit_minute;

   bool stale_pending = (Strategy_ServerMinuteOfDay(now) >= flat_minute);
   for(int i = OrdersTotal() - 1; i >= 0 && !stale_pending; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) || !Strategy_IsOurOrderSelected())
         continue;
      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(Strategy_ServerDayKey(setup_time) != current_day)
         stale_pending = true;
     }
   if(stale_pending)
      Strategy_RemoveOurPendingOrders("NY_PREOPEN_SESSION_FLAT");

   const bool has_position = Strategy_HasOurOpenPosition();
   const int pending_count = Strategy_OurPendingCount();
   if(has_position)
      Strategy_RemoveOurPendingOrders("NY_PREOPEN_OCO_PEER");
   else if(g_strategy_attempt_day_key == current_day && pending_count == 1)
      Strategy_RemoveOurPendingOrders("NY_PREOPEN_PAIR_RECONCILE");

   if(!has_position)
      return;

   double trail_low = 0.0;
   double trail_high = 0.0;
   if(!Strategy_ReadTrailLevels(now, trail_low, trail_high))
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0 || market <= 0.0 || point <= 0.0)
         continue;

      // Incumbent contract: risk is deliberately re-read from CURRENT SL.
      const double risk_dist = MathAbs(open_price - current_sl);
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(risk_dist <= point || moved < strategy_trail_trigger_r * risk_dist)
         continue;

      const double target_sl = Strategy_NormalizePrice(is_buy ? trail_low : trail_high);
      const bool improves = is_buy ? (target_sl > current_sl + point * 0.5)
                                   : (target_sl < current_sl - point * 0.5);
      if(target_sl > 0.0 && improves)
         QM_TM_MoveSL(ticket, target_sl, "NY_PREOPEN_2GRIDBAR_TRAIL");
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime now = TimeCurrent();
   const int current_day = Strategy_ServerDayKey(now);
   const int flat_minute = strategy_exit_hour * 60 + strategy_exit_minute;
   if(Strategy_ServerMinuteOfDay(now) >= flat_minute)
      return true;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime setup_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_ServerDayKey(setup_time) != current_day)
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
   if(qm_ea_id != 41485 || _Period != PERIOD_M30 ||
      (strategy_range_bars != 2 && strategy_range_bars != 3) ||
      strategy_range_end_hour != 15 || strategy_range_end_minute != 30 ||
      strategy_exit_hour != 23 || strategy_exit_minute != 0 ||
      strategy_grid_offset_minutes != 30 ||
      strategy_news_retry_window_minutes != 60 ||
      strategy_atr_period != 14 ||
      strategy_range_scan_bars < 30 ||
      strategy_min_range_atr_mult <= 0.0 ||
      strategy_max_range_atr_mult <= strategy_min_range_atr_mult ||
      strategy_trail_trigger_r <= 0.0 ||
      qm_news_stale_max_hours < 1 || qm_news_stale_max_hours > 336)
     {
      Print("QM5_41485 frozen input contract invalid");
      return INIT_PARAMETERS_INCORRECT;
     }

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

   Strategy_LoadAttemptState();
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // Management, OCO cleanup, and time exits run before the placement-only
   // news gate. A blackout never freezes an already-open position.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      Strategy_CloseOurPositions(QM_EXIT_STRATEGY);

   if(!QM_IsNewBar(_Symbol, PERIOD_M30))
      return;
   QM_EquityStreamOnNewBar();
   if(Strategy_NoTradeFilter())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0 ||
      !HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol ||
      (int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != QM_FrameworkMagic())
      return;
   const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
      Strategy_RemoveOurPendingOrders("NY_PREOPEN_OCO_FILL_TRANSACTION");
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
