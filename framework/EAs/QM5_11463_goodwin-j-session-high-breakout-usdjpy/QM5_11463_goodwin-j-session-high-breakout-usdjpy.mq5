#property strict
#property version   "5.0"
#property description "QM5_11463 Goodwin-J Session High Breakout USDJPY"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11463 goodwin-j-session-high-breakout-usdjpy
// -----------------------------------------------------------------------------
// Approved card: D:/QM/strategy_farm/artifacts/cards_approved/
//   QM5_11463_goodwin-j-session-high-breakout-usdjpy.md
//
// Goodwin session breakout: build the 17:00-21:30 EST session range, then place
// one stop order in the direction of the prior D1 candle. Exit and cancel
// unfilled orders at 16:50 EST. Inputs below are broker-time minutes because
// DXZ broker time follows the New-York-close GMT+2/+3 convention.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11463;
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
input int    strategy_session_open_min      = 1380; // 23:00 broker, 17:00 EST
input int    strategy_accum_end_min         = 210;  // 03:30 broker, 21:30 EST
input int    strategy_eod_exit_min          = 1370; // 22:50 broker, 16:50 EST
input int    strategy_stop_loss_pips        = 150;
input int    strategy_spread_cap_pips       = 20;
input bool   strategy_use_prior_bar_filter  = true;

datetime g_last_order_session_open = 0;

int BrokerMinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

datetime BrokerDayStart(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int WrappedMinutesFromSessionOpen(const int target_min)
  {
   int offset = target_min - strategy_session_open_min;
   if(offset < 0)
      offset += 1440;
   return offset;
  }

datetime CurrentSessionOpen(const datetime broker_now)
  {
   datetime open_time = BrokerDayStart(broker_now) + strategy_session_open_min * 60;
   if(BrokerMinuteOfDay(broker_now) < strategy_session_open_min)
      open_time -= 86400;
   return open_time;
  }

datetime SessionBoundary(const datetime session_open, const int target_min)
  {
   return session_open + WrappedMinutesFromSessionOpen(target_min) * 60;
  }

bool StrategyParamsValid()
  {
   return (strategy_session_open_min >= 0 && strategy_session_open_min < 1440 &&
           strategy_accum_end_min >= 0 && strategy_accum_end_min < 1440 &&
           strategy_eod_exit_min >= 0 && strategy_eod_exit_min < 1440 &&
           strategy_session_open_min != strategy_accum_end_min &&
           strategy_accum_end_min != strategy_eod_exit_min &&
           strategy_stop_loss_pips > 0 &&
           strategy_spread_cap_pips >= 0);
  }

bool IsOurPendingOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP ||
           order_type == ORDER_TYPE_SELL_STOP ||
           order_type == ORDER_TYPE_BUY_LIMIT ||
           order_type == ORDER_TYPE_SELL_LIMIT);
  }

bool HasOurPendingOrder()
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
      if(IsOurPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void CancelOurPendingOrders(const string reason)
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
      if(!IsOurPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool ReadPriorD1Direction(int &direction)
  {
   direction = 0;

   MqlRates daily[];
   ArraySetAsSeries(daily, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, daily); // perf-allowed
   if(copied != 1)
      return false;

   if(daily[0].close > daily[0].open)
      direction = 1;
   else if(daily[0].close < daily[0].open)
      direction = -1;

   if(direction == 0 && !strategy_use_prior_bar_filter)
      direction = 1;

   return (direction != 0);
  }

bool ReadSessionRange(const datetime session_open,
                      const datetime accum_end,
                      double &session_high,
                      double &session_low)
  {
   session_high = 0.0;
   session_low = 0.0;
   if(accum_end <= session_open)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, false);
   const int copied = CopyRates(_Symbol, PERIOD_M30, session_open, accum_end - 1, bars); // perf-allowed
   if(copied <= 0)
      return false;

   bool have_bar = false;
   for(int i = 0; i < copied; ++i)
     {
      if(bars[i].high <= 0.0 || bars[i].low <= 0.0)
         continue;
      if(!have_bar)
        {
         session_high = bars[i].high;
         session_low = bars[i].low;
         have_bar = true;
        }
      else
        {
         if(bars[i].high > session_high)
            session_high = bars[i].high;
         if(bars[i].low < session_low)
            session_low = bars[i].low;
        }
     }

   return (have_bar && session_high > 0.0 && session_low > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(!StrategyParamsValid())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(ask > bid && cap > 0.0 && (ask - bid) > cap)
      return true;

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

   const datetime now = TimeCurrent();
   const datetime session_open = CurrentSessionOpen(now);
   const datetime accum_end = SessionBoundary(session_open, strategy_accum_end_min);
   const datetime eod_exit = SessionBoundary(session_open, strategy_eod_exit_min);

   if(now < accum_end || now >= eod_exit)
      return false;
   if(g_last_order_session_open == session_open)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0 || HasOurPendingOrder())
      return false;

   int direction = 0;
   if(!ReadPriorD1Direction(direction))
      return false;

   double session_high = 0.0;
   double session_low = 0.0;
   if(!ReadSessionRange(session_open, accum_end, session_high, session_low))
      return false;

   const double entry_price = (direction > 0) ? session_high : session_low;
   const QM_OrderType order_type = (direction > 0) ? QM_BUY_STOP : QM_SELL_STOP;
   const double normalized_entry = QM_StopRulesNormalizePrice(_Symbol, entry_price);
   const double sl = QM_StopFixedPips(_Symbol, order_type, normalized_entry, strategy_stop_loss_pips);
   if(normalized_entry <= 0.0 || sl <= 0.0)
      return false;

   const int expiry_seconds = (int)(eod_exit - now);
   if(expiry_seconds <= 60)
      return false;

   req.type = order_type;
   req.price = normalized_entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (direction > 0) ? "goodwin_prior_d1_bull_session_high_buystop"
                                : "goodwin_prior_d1_bear_session_low_sellstop";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;

   g_last_order_session_open = session_open;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime now = TimeCurrent();
   const datetime session_open = CurrentSessionOpen(now);
   const datetime eod_exit = SessionBoundary(session_open, strategy_eod_exit_min);
   if(now >= eod_exit)
      CancelOurPendingOrders("goodwin_eod_cancel_pending");
  }

bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime now = TimeCurrent();
   const datetime session_open = CurrentSessionOpen(now);
   const datetime eod_exit = SessionBoundary(session_open, strategy_eod_exit_min);
   return (now >= eod_exit);
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
