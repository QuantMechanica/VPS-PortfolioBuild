#property strict
#property version   "5.0"
#property description "QM5_11515 Carter ADX14 prior-day range H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11515_carter-t-adx14-prev-day-range-h1
// -----------------------------------------------------------------------------
// Approved card: ADX(14) < 35 identifies a rangebound H1 regime. A closed H1
// bar that trades 15 pips below the prior broker-day low stages a BuyStop 15
// pips above the prior-day high. The mirrored false breakout stages a SellStop
// below the prior-day low. Pending orders expire at broker-day end; filled
// positions use the card's 30-pip stop, 60-pip (2R) target, and same-day exit.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11515;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_adx_period          = 14;
input double strategy_adx_threshold       = 35.0;
input int    strategy_false_break_pips    = 15;
input int    strategy_entry_offset_pips   = 15;
input int    strategy_stop_loss_pips      = 30;
input double strategy_take_profit_rr      = 2.0;
input int    strategy_max_spread_pips     = 15;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter: block invalid quotes and spreads wider than the card's
// 15-pip cap. A zero modeled .DWX spread remains tradeable.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                              strategy_max_spread_pips);
   if(spread_cap <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Trade Entry: caller guarantees QM_IsNewBar() == true. The prior-day range
// and false-break trigger are structural OHLC reads through QM_ReadBar; ADX is
// read through the pooled framework indicator helper.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY_STOP;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_adx_period < 2 || strategy_adx_threshold <= 0.0 ||
      strategy_false_break_pips <= 0 || strategy_entry_offset_pips <= 0 ||
      strategy_stop_loss_pips <= 0 || strategy_take_profit_rr <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime now_parts;
   TimeToStruct(broker_now, now_parts);
   if(now_parts.day_of_week == 5) // Card filter: no Friday entry.
      return false;

   const double adx = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   if(adx <= 0.0 || adx >= strategy_adx_threshold)
      return false;

   MqlRates signal_bar;
   MqlRates prior_day;
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 1, signal_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 1, prior_day))
      return false;
   if(signal_bar.high <= 0.0 || signal_bar.low <= 0.0 ||
      prior_day.high <= prior_day.low || prior_day.low <= 0.0)
      return false;

   const double false_break_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_false_break_pips);
   const double entry_offset =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_offset_pips);
   if(false_break_distance <= 0.0 || entry_offset <= 0.0)
      return false;

   const bool long_signal =
      (signal_bar.low < prior_day.low - false_break_distance);
   const bool short_signal =
      (signal_bar.high > prior_day.high + false_break_distance);
   if(!long_signal && !short_signal)
      return false;

   // Reconstruct the once-per-direction broker-day rule from active and
   // historical orders so an EA restart cannot duplicate a session's leg.
   bool long_already_ordered = false;
   bool short_already_ordered = false;

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
      if(order_type == ORDER_TYPE_BUY_STOP)
         long_already_ordered = true;
      else if(order_type == ORDER_TYPE_SELL_STOP)
         short_already_ordered = true;
     }

   MqlDateTime day_start_parts = now_parts;
   day_start_parts.hour = 0;
   day_start_parts.min = 0;
   day_start_parts.sec = 0;
   const datetime day_start = StructToTime(day_start_parts);
   if(day_start <= 0 || !HistorySelect(day_start, broker_now))
      return false;

   const int history_orders = HistoryOrdersTotal();
   for(int i = history_orders - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol ||
         (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP)
         long_already_ordered = true;
      else if(order_type == ORDER_TYPE_SELL_STOP)
         short_already_ordered = true;
     }

   MqlDateTime expiry_parts = now_parts;
   expiry_parts.hour = 23;
   expiry_parts.min = 59;
   expiry_parts.sec = 59;
   const datetime expiry_time = StructToTime(expiry_parts);
   const int expiry_seconds = (int)(expiry_time - broker_now);
   if(expiry_seconds <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // The card lists LONG first. If one exceptional H1 candle breaches both
   // sides, the single-entry framework hook therefore gives LONG priority.
   if(long_signal && !long_already_ordered)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol,
                                                       prior_day.high + entry_offset);
      if(entry > ask)
        {
         const double sl = QM_StopFixedPips(_Symbol,
                                             QM_BUY_STOP,
                                             entry,
                                             strategy_stop_loss_pips);
         const double tp = QM_TakeRR(_Symbol,
                                      QM_BUY_STOP,
                                      entry,
                                      sl,
                                      strategy_take_profit_rr);
         if(sl > 0.0 && sl < entry && tp > entry)
           {
            req.type               = QM_BUY_STOP;
            req.price              = entry;
            req.sl                 = sl;
            req.tp                 = tp;
            req.reason             = "ADX_PD_FALSE_BREAK_LONG";
            req.expiration_seconds = expiry_seconds;
            return true;
           }
        }
     }

   if(short_signal && !short_already_ordered)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol,
                                                       prior_day.low - entry_offset);
      if(entry < bid)
        {
         const double sl = QM_StopFixedPips(_Symbol,
                                             QM_SELL_STOP,
                                             entry,
                                             strategy_stop_loss_pips);
         const double tp = QM_TakeRR(_Symbol,
                                      QM_SELL_STOP,
                                      entry,
                                      sl,
                                      strategy_take_profit_rr);
         if(sl > entry && tp > 0.0 && tp < entry)
           {
            req.type               = QM_SELL_STOP;
            req.price              = entry;
            req.sl                 = sl;
            req.tp                 = tp;
            req.reason             = "ADX_PD_FALSE_BREAK_SHORT";
            req.expiration_seconds = expiry_seconds;
            return true;
           }
        }
     }

   return false;
  }

// Trade Management: once one staged leg fills, remove any still-active
// opposite pending leg so the framework's one-position-per-magic invariant is
// preserved when the other price level is reached later in the session.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         has_position = true;
         break;
        }
     }
   if(!has_position)
      return;

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
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, "position_open_cancel_other_leg");
     }
  }

// Trade Close: the card describes intraday logic, so any filled position still
// open after its broker-time entry day closes is exited on the first next-day
// tick. The fixed server-side SL/TP remain active throughout the session.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlDateTime now_parts;
   TimeToStruct(TimeCurrent(), now_parts);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened_at =
         (datetime)PositionGetInteger(POSITION_TIME);
      MqlDateTime opened_parts;
      TimeToStruct(opened_at, opened_parts);
      if(opened_parts.year != now_parts.year ||
         opened_parts.mon != now_parts.mon ||
         opened_parts.day != now_parts.day)
         return true;
     }

   return false;
  }

// News Filter Hook: no card-specific override; defer to the central callable
// framework news gate used by the P8 News Impact phase.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
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

   // Management, rule-based exits and the Friday sweep above remain active
   // before the central news gate, which blocks only new entries.
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
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
