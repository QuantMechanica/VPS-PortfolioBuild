#property strict
#property version   "5.0"
#property description "QM5_11442 Burke FRD/FGD Daily Pump M5"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11442 burke-frd-fgd-daily-pump-m5
// -----------------------------------------------------------------------------
// Approved card mechanics:
//   - Detect the FRD/FGD reversal pattern on the three prior closed D1 bars.
//   - During London 07:00-12:00 UTC or New York 13:00-17:00 UTC, enter on
//     the first closed M5 bar that crosses back through EMA(20).
//   - Permit at most one entry per broker day and symbol.
//   - Use a 50-pip TP and 20-pip SL. For FRD shorts, an EMA+5-pip stop may
//     widen the stop, subject to the card's absolute 25-pip P2 cap.
//   - After the entry session ends, close positions that have not reached
//     50% of the TP distance. Fixed SL/TP and framework Friday close remain.
//
// Only strategy inputs and the five Strategy_* hooks differ from the canonical
// framework skeleton below.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11442;
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
// A trade is allowed only if BOTH axes allow. See Vault Q09 News Impact Mode.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period          = 20;
input bool   strategy_session_london      = true;
input bool   strategy_session_ny          = true;
input int    strategy_london_start_utc    = 7;
input int    strategy_london_end_utc      = 12;
input int    strategy_ny_start_utc        = 13;
input int    strategy_ny_end_utc          = 17;
input int    strategy_tp_pips             = 50;
input int    strategy_sl_pips             = 20;
input int    strategy_short_ema_buffer_pips = 5;
input int    strategy_sl_cap_pips         = 25;
input int    strategy_spread_cap_pips     = 15;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter: block invalid quotes and genuinely wide spreads only.
// Session and news restrictions remain entry-only so management and exits
// continue outside sessions and through news windows.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return true;

   // .DWX tester quotes may have ask == bid. Only a positive wide spread blocks.
   return (ask > bid && (ask - bid) > spread_cap);
  }

// Trade Entry: D1 FRD/FGD setup plus the first closed M5 EMA crossover in an
// enabled UTC session. The framework calls this once after QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_ema_period < 2 ||
      strategy_tp_pips <= 0 ||
      strategy_sl_pips <= 0 ||
      strategy_sl_cap_pips <= 0 ||
      strategy_short_ema_buffer_pips < 0 ||
      (!strategy_session_london && !strategy_session_ny))
      return false;

   // Use the just-closed M5 bar's broker timestamp, then convert it to UTC.
   const datetime bar_broker = iTime(_Symbol, PERIOD_M5, 1); // perf-allowed: exact closed M5 session-bar timestamp behind framework new-bar gate.
   if(bar_broker <= 0)
      return false;
   const datetime bar_utc = QM_BrokerToUTC(bar_broker);
   if(bar_utc <= 0)
      return false;

   MqlDateTime utc_dt;
   ZeroMemory(utc_dt);
   TimeToStruct(bar_utc, utc_dt);
   const bool in_london =
      strategy_session_london &&
      utc_dt.hour >= strategy_london_start_utc &&
      utc_dt.hour < strategy_london_end_utc;
   const bool in_ny =
      strategy_session_ny &&
      utc_dt.hour >= strategy_ny_start_utc &&
      utc_dt.hour < strategy_ny_end_utc;
   if(!in_london && !in_ny)
      return false;

   // D1 pattern at Day-3 execution: shift 2 is Day 1 (pump/dump), shift 1
   // is Day 2 (reversal), and shift 3 is the pre-pattern reference day.
   const double day1_close = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed: card-authorized structural D1 close behind framework new-bar gate.
   const double reference_high = iHigh(_Symbol, PERIOD_D1, 3); // perf-allowed: card-authorized structural D1 high behind framework new-bar gate.
   const double reference_low = iLow(_Symbol, PERIOD_D1, 3); // perf-allowed: card-authorized structural D1 low behind framework new-bar gate.
   const double day2_open = iOpen(_Symbol, PERIOD_D1, 1); // perf-allowed: card-authorized structural D1 open behind framework new-bar gate.
   const double day2_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: card-authorized structural D1 close behind framework new-bar gate.
   if(day1_close <= 0.0 ||
      reference_high <= 0.0 ||
      reference_low <= 0.0 ||
      day2_open <= 0.0 ||
      day2_close <= 0.0)
      return false;

   const bool frd_short =
      day1_close > reference_high &&
      day2_close < day2_open &&
      day2_open >= day1_close &&
      day2_close < day1_close;
   const bool fgd_long =
      day1_close < reference_low &&
      day2_close > day2_open &&
      day2_open <= day1_close &&
      day2_close > day1_close;
   if(!frd_short && !fgd_long)
      return false;

   // Closed-bar event: one crossover trigger, rather than two simultaneous
   // events. The card's M5[0] close maps to shift 1 on the next tick.
   const double ema_now =
      QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1);
   const double ema_previous =
      QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 2);
   const double close_now = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: card-authorized closed M5 trigger value behind framework new-bar gate.
   const double close_previous = iClose(_Symbol, PERIOD_M5, 2); // perf-allowed: prior closed M5 state for the single crossover event.
   if(ema_now <= 0.0 ||
      ema_previous <= 0.0 ||
      close_now <= 0.0 ||
      close_previous <= 0.0)
      return false;

   const bool short_trigger =
      frd_short && close_previous >= ema_previous && close_now < ema_now;
   const bool long_trigger =
      fgd_long && close_previous <= ema_previous && close_now > ema_now;
   if(!short_trigger && !long_trigger)
      return false;

   // Restart-safe one-trade-per-Day-3 guard: reject if this magic and symbol
   // already recorded an entry deal on the closed bar's broker day.
   MqlDateTime day_start_dt;
   ZeroMemory(day_start_dt);
   TimeToStruct(bar_broker, day_start_dt);
   day_start_dt.hour = 0;
   day_start_dt.min = 0;
   day_start_dt.sec = 0;
   const datetime day_start = StructToTime(day_start_dt);
   const datetime history_end = TimeCurrent();
   if(day_start <= 0 || history_end < day_start)
      return false;
   if(!HistorySelect(day_start, history_end))
      return false;

   const int magic = QM_FrameworkMagic();
   const int deal_total = HistoryDealsTotal();
   for(int i = 0; i < deal_total; ++i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY deal_entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(deal_entry == DEAL_ENTRY_IN || deal_entry == DEAL_ENTRY_INOUT)
         return false;
     }

   const QM_OrderType side = short_trigger ? QM_SELL : QM_BUY;
   const double entry =
      short_trigger
      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   int base_stop_pips = strategy_sl_pips;
   if(base_stop_pips > strategy_sl_cap_pips)
      base_stop_pips = strategy_sl_cap_pips;

   double stop_price =
      QM_StopFixedPips(_Symbol, side, entry, base_stop_pips);
   const double take_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   const double cap_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(stop_price <= 0.0 || take_distance <= 0.0 || cap_distance <= 0.0)
      return false;

   if(short_trigger)
     {
      // Literal resolution of the card's conflicting short-stop wording:
      // use the farther of entry+20 pips and EMA20+5 pips, then enforce the
      // explicit absolute P2 cap of 25 pips.
      const double ema_buffer =
         QM_StopRulesPipsToPriceDistance(_Symbol,
                                         strategy_short_ema_buffer_pips);
      const double ema_stop =
         QM_StopRulesNormalizePrice(_Symbol, ema_now + ema_buffer);
      if(ema_stop > stop_price)
         stop_price = ema_stop;
      const double capped_stop =
         QM_StopRulesNormalizePrice(_Symbol, entry + cap_distance);
      if(stop_price > capped_stop)
         stop_price = capped_stop;
     }

   req.type = side;
   req.price = 0.0;
   req.sl = stop_price;
   req.tp =
      QM_StopRulesNormalizePrice(_Symbol,
                                 short_trigger
                                 ? entry - take_distance
                                 : entry + take_distance);
   req.reason = short_trigger ? "burke_frd_short" : "burke_fgd_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   return true;
  }

// Trade Management: the card specifies no trailing, break-even, partial close,
// or adaptive management. Server-side SL/TP remain active.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: once the position's entry session has ended, close it if the
// favorable move is still below 50% of the fixed TP distance.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime entry_broker =
         (datetime)PositionGetInteger(POSITION_TIME);
      const datetime entry_utc = QM_BrokerToUTC(entry_broker);
      const datetime now_utc = QM_BrokerToUTC(TimeCurrent());
      if(entry_utc <= 0 || now_utc <= 0)
         return false;

      MqlDateTime entry_dt;
      ZeroMemory(entry_dt);
      TimeToStruct(entry_utc, entry_dt);

      int session_end_hour = -1;
      if(strategy_session_london &&
         entry_dt.hour >= strategy_london_start_utc &&
         entry_dt.hour < strategy_london_end_utc)
         session_end_hour = strategy_london_end_utc;
      else if(strategy_session_ny &&
              entry_dt.hour >= strategy_ny_start_utc &&
              entry_dt.hour < strategy_ny_end_utc)
         session_end_hour = strategy_ny_end_utc;
      if(session_end_hour < 0)
         return false;

      MqlDateTime session_end_dt = entry_dt;
      session_end_dt.hour = session_end_hour;
      session_end_dt.min = 0;
      session_end_dt.sec = 0;
      const datetime session_end_utc = StructToTime(session_end_dt);
      if(session_end_utc <= 0 || now_utc < session_end_utc)
         return false;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      const double market_price =
         (position_type == POSITION_TYPE_BUY)
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double target_distance =
         QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
      if(open_price <= 0.0 || market_price <= 0.0 || target_distance <= 0.0)
         return false;

      const double favorable_move =
         (position_type == POSITION_TYPE_BUY)
         ? market_price - open_price
         : open_price - market_price;
      return (favorable_move < 0.5 * target_distance);
     }

   return false;
  }

// News Filter Hook: no extra per-strategy override. The framework's callable
// high-impact temporal/compliance gate remains authoritative for new entries.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — copied intact from framework/templates/EA_Skeleton.mq5.
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management and exits stay above the entry-only news/new-bar gates.
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

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows =
         QM_NewsAllowsTrade2(_Symbol,
                             broker_now,
                             qm_news_temporal,
                             qm_news_compliance);
   else
      news_allows =
         QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
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
