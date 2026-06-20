#property strict
#property version   "5.0"
#property description "QM5_11548 Carter-T M5 Session Box Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11548 carter-t-m5-session-box-breakout
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_11548_carter-t-m5-session-box-breakout.md
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         System #7.
//
// Mechanics:
//   - On the M5 bar whose broker-time open is 15:00, read the just-closed H1
//     bar (14:00-15:00 DWX broker time) as the session box.
//   - Place both a BuyStop at box_high + 20% of box_height and a SellStop at
//     box_low - 20% of box_height.
//   - Pending orders expire after one hour and are also explicitly removed
//     after 16:00 broker time.
//   - TP is measured from the box extreme: long box_high + 4x height, short
//     box_low - 4x height. SL is the opposite side of the box.
//   - No Friday entries. No discretionary exit beyond SL/TP, pending expiry,
//     one-position cleanup, and framework Friday close.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11548;
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
input int    strategy_signal_hour_broker      = 15;
input int    strategy_signal_minute_broker    = 0;
input double strategy_breakout_box_pct        = 0.20;
input double strategy_tp_box_mult             = 4.0;
input int    strategy_pending_expiry_minutes  = 60;
input int    strategy_max_box_pips            = 50;
input int    strategy_max_spread_pips         = 5;

int      g_orders_placed_day_broker = 0;
datetime g_pending_expiry_broker    = 0;

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_IsFriday(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day_of_week == 5);
  }

bool Strategy_IsSignalBarOpen(const datetime bar_open)
  {
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   return (dt.hour == strategy_signal_hour_broker &&
           dt.min == strategy_signal_minute_broker);
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_pips <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread = ask - bid;
   if(spread <= 0.0)
      return true;

   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(max_spread <= 0.0)
      return true;

   return (spread <= max_spread);
  }

bool Strategy_IsStopPendingType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

int Strategy_PendingStopCount()
  {
   int count = 0;
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
      if(Strategy_IsStopPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         count++;
     }
   return count;
  }

void Strategy_RemoveOurPendingStops(const string reason)
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
      if(!Strategy_IsStopPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_ReadH1Box(double &box_high, double &box_low)
  {
   box_high = 0.0;
   box_low = 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, 1, rates); // perf-allowed: one closed H1 box bar inside QM_IsNewBar-gated EntrySignal.
   if(copied != 1)
      return false;

   box_high = rates[0].high;
   box_low = rates[0].low;
   return (box_high > 0.0 && box_low > 0.0 && box_high > box_low);
  }

bool Strategy_BoxWithinCap(const double box_height)
  {
   if(strategy_max_box_pips <= 0)
      return true;

   const double max_height = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_box_pips);
   if(max_height <= 0.0)
      return true;

   return (box_height <= max_height);
  }

bool Strategy_BuildStopRequest(const QM_OrderType side,
                               const double box_high,
                               const double box_low,
                               QM_EntryRequest &req)
  {
   const double box_height = box_high - box_low;
   if(box_height <= 0.0 ||
      strategy_breakout_box_pct <= 0.0 ||
      strategy_tp_box_mult <= 0.0)
      return false;

   int expiry_seconds = strategy_pending_expiry_minutes * 60;
   if(expiry_seconds < 60)
      expiry_seconds = 60;

   const bool is_buy = (side == QM_BUY_STOP);
   const double offset = box_height * strategy_breakout_box_pct;
   const double entry = is_buy ? (box_high + offset) : (box_low - offset);
   const double sl = is_buy ? box_low : box_high;
   const double tp = is_buy ? (box_high + strategy_tp_box_mult * box_height)
                            : (box_low - strategy_tp_box_mult * box_height);

   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = QM_TM_NormalizePrice(_Symbol, entry);
   req.sl = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp = QM_TM_NormalizePrice(_Symbol, tp);
   req.reason = is_buy ? "carter_session_box_buy_stop" : "carter_session_box_sell_stop";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;
   return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   return (QM_TM_OpenPositionCount(magic) > 0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(g_pending_expiry_broker > 0 && TimeCurrent() >= g_pending_expiry_broker)
      Strategy_RemoveOurPendingStops("session_box_1600_expiry");

   return !Strategy_SpreadAllows();
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M5)
      return false;

   const datetime current_bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: current M5 bar open for exact 15:00 broker-time gate.
   if(current_bar_open <= 0)
      return false;
   if(Strategy_IsFriday(current_bar_open))
      return false;
   if(!Strategy_IsSignalBarOpen(current_bar_open))
      return false;
   if(!Strategy_SpreadAllows())
      return false;

   const int today_key = Strategy_DateKey(current_bar_open);
   if(g_orders_placed_day_broker == today_key)
      return false;
   if(Strategy_HasOpenPosition() || Strategy_PendingStopCount() > 0)
      return false;

   double box_high = 0.0;
   double box_low = 0.0;
   if(!Strategy_ReadH1Box(box_high, box_low))
      return false;

   const double box_height = box_high - box_low;
   if(!Strategy_BoxWithinCap(box_height))
      return false;

   QM_EntryRequest buy_req;
   if(Strategy_BuildStopRequest(QM_BUY_STOP, box_high, box_low, buy_req))
     {
      ulong buy_ticket = 0;
      QM_TM_OpenPosition(buy_req, buy_ticket);
     }

   if(!Strategy_BuildStopRequest(QM_SELL_STOP, box_high, box_low, req))
      return false;

   g_orders_placed_day_broker = today_key;
   g_pending_expiry_broker = current_bar_open + strategy_pending_expiry_minutes * 60;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(g_pending_expiry_broker > 0 && TimeCurrent() >= g_pending_expiry_broker)
      Strategy_RemoveOurPendingStops("session_box_1600_expiry");

   if(Strategy_HasOpenPosition())
      Strategy_RemoveOurPendingStops("session_box_one_position_cleanup");
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
