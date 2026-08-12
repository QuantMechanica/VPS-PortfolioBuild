#property strict
#property version   "5.0"
#property description "QM5_11390 Midnight Setup D1 Candle Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy-specific code is confined to the five Strategy_* hooks and the
// Strategy input group. Framework wiring below remains canonical.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11390;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;    // live setfile: 0.5 after Q13 approval
input double RISK_FIXED                 = 1000.0; // tester default
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1: two-axis news filter. The central gate applies to new entries only.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int strategy_min_range_pips = 90;  // prior D1 high-low must meet this threshold
input int strategy_offset_pips    = 5;   // pending-stop offset beyond prior D1 extreme
input int strategy_sl_pips        = 50;  // fixed stop loss from pending entry
input int strategy_tp_pips        = 100; // fixed take profit from pending entry
input int strategy_spread_cap_pips = 30; // only a genuinely wider positive spread blocks

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the APPROVED Strategy Card.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): D1 is mandatory. The framework's
// closed-bar gate supplies midnight cadence, the entry hook applies the spread
// cap on that one bar, and the central news gate remains below management.
bool Strategy_NoTradeFilter()
  {
   return ((ENUM_TIMEFRAMES)_Period != PERIOD_D1);
  }

// Trade Entry: on the first tick of a new D1 bar, place an OCO BUY_STOP and
// SELL_STOP around the prior closed D1 candle when its range is at least the
// configured minimum. Both orders expire at the next broker-day boundary.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_min_range_pips <= 0 || strategy_offset_pips <= 0 ||
      strategy_sl_pips <= 0 || strategy_tp_pips <= 0 ||
      strategy_spread_cap_pips <= 0)
      return false;

   MqlRates current_bar;
   MqlRates previous_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 1, previous_bar))
      return false;
   if(current_bar.time <= 0 || previous_bar.high <= 0.0 ||
      previous_bar.low <= 0.0 || previous_bar.high <= previous_bar.low)
      return false;

   const double min_range_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_range_pips);
   const double offset_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_offset_pips);
   const double spread_cap_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(min_range_distance <= 0.0 || offset_distance <= 0.0 ||
      spread_cap_distance <= 0.0)
      return false;
   if((previous_bar.high - previous_bar.low) < min_range_distance)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask > bid && (ask - bid) > spread_cap_distance)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // Never stack a second straddle or re-enter after activity earlier in the
   // current broker day (including a terminal restart during that D1 bar).
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (int)OrderGetInteger(ORDER_MAGIC) == magic)
         return false;
     }

   const datetime broker_now = TimeCurrent();
   if(HistorySelect(current_bar.time, broker_now))
     {
      for(int i = HistoryOrdersTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = HistoryOrderGetTicket(i);
         if(ticket == 0)
            continue;
         if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol ||
            (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
            continue;
         const datetime setup_time =
            (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP);
         if(setup_time >= current_bar.time)
            return false;
        }
      for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol ||
            (int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
            continue;
         const datetime deal_time =
            (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         if(deal_time >= current_bar.time)
            return false;
        }
     }

   const int day_seconds = PeriodSeconds(PERIOD_D1);
   const long expiry_remaining =
      (long)current_bar.time + (long)day_seconds - (long)broker_now;
   if(day_seconds <= 0 || expiry_remaining <= 0)
      return false;
   const int expiration_seconds = (int)expiry_remaining;

   const double buy_price = QM_StopRulesNormalizePrice(
      _Symbol, previous_bar.high + offset_distance);
   const double sell_price = QM_StopRulesNormalizePrice(
      _Symbol, previous_bar.low - offset_distance);
   if(buy_price <= ask || sell_price >= bid || sell_price <= 0.0)
      return false;

   QM_EntryRequest buy_req;
   ZeroMemory(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_price;
   buy_req.sl = QM_StopFixedPips(_Symbol, QM_BUY_STOP,
                                 buy_price, strategy_sl_pips);
   buy_req.tp = QM_TakeFixedPips(_Symbol, QM_BUY_STOP,
                                 buy_price, strategy_tp_pips);
   buy_req.reason = "midnight_buy_stop";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = expiration_seconds;

   req.type = QM_SELL_STOP;
   req.price = sell_price;
   req.sl = QM_StopFixedPips(_Symbol, QM_SELL_STOP,
                             sell_price, strategy_sl_pips);
   req.tp = QM_TakeFixedPips(_Symbol, QM_SELL_STOP,
                             sell_price, strategy_tp_pips);
   req.reason = "midnight_sell_stop";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;

   if(buy_req.sl <= 0.0 || buy_req.tp <= 0.0 ||
      req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   // The hook opens the first OCO leg; returning true delegates the second leg
   // to the canonical skeleton's single framework entry path.
   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;
   return true;
  }

// Trade Management: cancel the unfilled OCO peer as soon as one side becomes
// an open position. Also remove any pending order whose daily expiry is due.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool has_open_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         has_open_position = true;
         break;
        }
     }

   const datetime broker_now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP &&
         order_type != ORDER_TYPE_SELL_STOP)
         continue;
      const datetime expiration =
         (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      if(has_open_position)
         QM_TM_RemovePendingOrder(ticket, "midnight_oco_peer_cancel");
      else if(expiration > 0 && expiration <= broker_now)
         QM_TM_RemovePendingOrder(ticket, "midnight_daily_expiry");
     }
  }

// Trade Close: fixed server-side SL/TP implement the card's base exit. The
// hold-to-next-midnight alternative is reserved for the declared P3 sweep.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no card-specific override; defer to the central entry-only
// temporal/compliance filter in the framework wiring below.
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. Keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management and exits remain above the central news entry gate.
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
