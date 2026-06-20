#property strict
#property version   "5.0"
#property description "QM5_11575 robo-32points-d1 — RoboForex 32-points daily pending breakout bracket (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11575 robo-32points-d1
// -----------------------------------------------------------------------------
// Source: RoboForex strategy collection, "Strategy 32 points", page 114.
// Card: artifacts/cards_approved/QM5_11575_robo-32points-d1.md (g0_status APPROVED).
//
// Mechanics (daily pending-order bracket around the prior D1 close):
//   On each new D1 bar (the prior day's candle has just closed):
//     prev_close = close at shift 1 (the just-closed D1 candle).
//     Place a Buy Stop  at prev_close + offset (pips).
//     Place a Sell Stop at prev_close - offset (pips).
//     TP = take_pips, SL = stop_pips, both as fixed pip distances off the
//     pending fill price.
//   If one pending fills (a position opens for this magic), cancel the surviving
//     opposite pending order (one position per magic).
//   If neither fills within the day, both pendings are cancelled before the next
//     D1 close — enforced two ways: (1) a fixed expiration on each pending, and
//     (2) a cancel-then-replace sweep at the top of every new D1 bar.
//   No same-day re-entry after a fill: a fresh bracket is only ever placed at a
//     new D1 bar, and never while a position OR a pending for this magic exists.
//   Friday cutoff: do not arm a new bracket on Friday at/after the broker cutoff
//     hour (the framework Friday-close guard still flattens open risk separately).
//   Gap-skip determinism: if at placement time the market has already gapped past
//     a stop level, that leg is degenerate (would fill instantly as a market
//     order); skip the degenerate leg. If BOTH levels are already crossed, place
//     neither and log a gap-skip — preserves determinism (card Implementation Note).
//
// Architecture note (two legs vs the single-entry framework hook):
//   The framework OnTick path places exactly ONE order from the req returned by
//   Strategy_EntrySignal. This is a two-leg bracket, so Strategy_EntrySignal
//   places the SELL-STOP leg itself (direct QM_TM_OpenPosition) and returns the
//   BUY-STOP leg via req for the framework to place. The trigger EVENT is the
//   new D1 bar; the component conditions (Friday cutoff, existing position/order,
//   gap) are STATES — no two-cross-same-bar trap (this is a bracket, not a
//   crossover system).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11575;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_offset_pips   = 32;   // buy/sell stop distance from prior close
input int    strategy_tp_pips             = 35;   // take profit distance (pips)
input int    strategy_sl_pips             = 28;   // stop loss distance (pips)
input int    strategy_pending_expiry_hours = 23;  // pending lifetime; 0 = GTC (new-bar sweep still cancels)
input int    strategy_friday_cutoff_hour  = 21;   // do not arm a bracket on Friday at/after this broker hour
input int    strategy_spread_cap_tenths_pips = 25; // 25 = 2.5 pips; zero .DWX spread is allowed

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// Count this EA's still-live pending orders (by magic). Cheap: pending books are
// tiny (<=2 for this EA). Allowed direct order-book read — no indicator math.
int Strategy_PendingCount(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      count++;
     }
   return count;
  }

// Remove every still-live pending order belonging to this magic.
void Strategy_CancelAllPendings(const int magic, const string reason)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. The card's 2.5-pip EURUSD spread cap is enforced
// without fail-closing on zero .DWX modeled spread: only a genuinely wide
// positive spread blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_tenths_pips) / 10.0;
   if(cap > 0.0 && ask > bid && (ask - bid) > cap)
      return true;

   return false;
  }

// New-bar bracket placement. Caller guarantees QM_IsNewBar() == true.
// Places the SELL-STOP leg directly and returns the BUY-STOP leg via req.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // --- New-day housekeeping: cancel any pendings left from the prior day. ---
   // This enforces "if neither filled within the day, cancel both" and prevents
   // duplicate/stale brackets stacking. Runs before any new placement.
   if(Strategy_PendingCount(magic) > 0)
      Strategy_CancelAllPendings(magic, "robo32_new_day_cancel");

   // No new bracket while a position is open (one position per magic; this also
   // gives "no same-day re-entry" since brackets only arm on a fresh D1 bar).
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // --- Friday cutoff STATE: do not arm a bracket on Friday at/after cutoff. ---
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);   // broker time
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hour)
      return false;

   // --- prev_close = the just-closed D1 candle (shift 1). ---
   const double prev_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed D1 close required by card; EntrySignal is QM_IsNewBar-gated
   if(prev_close <= 0.0)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_offset_pips);
   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   if(offset <= 0.0 || sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   const double buy_stop_price  = QM_StopRulesNormalizePrice(_Symbol, prev_close + offset);
   const double sell_stop_price = QM_StopRulesNormalizePrice(_Symbol, prev_close - offset);

   // --- Gap-skip STATE: a stop level already crossed by current price is a
   //     degenerate leg (instant fill); skip it. If both are crossed, skip the
   //     whole bracket and log (card Implementation Note: prefer no trade). ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool buy_leg_degenerate  = (ask >= buy_stop_price);   // would fill as market
   const bool sell_leg_degenerate = (bid <= sell_stop_price);  // would fill as market

   if(buy_leg_degenerate && sell_leg_degenerate)
     {
      QM_LogEvent(QM_WARN, "ROBO32_GAP_SKIP",
                  StringFormat("{\"prev_close\":%.8f,\"buy_stop\":%.8f,\"sell_stop\":%.8f,\"ask\":%.8f,\"bid\":%.8f}",
                               prev_close, buy_stop_price, sell_stop_price, ask, bid));
      return false;
     }

   const int expiry_seconds = (strategy_pending_expiry_hours > 0)
                              ? strategy_pending_expiry_hours * 3600 : 0;

   // --- SELL-STOP leg (placed directly; framework places only the returned req). ---
   if(!sell_leg_degenerate)
     {
      QM_EntryRequest sreq;
      sreq.type   = QM_SELL_STOP;
      sreq.price  = sell_stop_price;
      sreq.sl     = QM_StopRulesNormalizePrice(_Symbol, sell_stop_price + sl_dist);
      sreq.tp     = QM_StopRulesNormalizePrice(_Symbol, sell_stop_price - tp_dist);
      sreq.reason = "robo32_sell_stop";
      sreq.symbol_slot       = qm_magic_slot_offset;
      sreq.expiration_seconds = expiry_seconds;
      ulong sticket = 0;
      QM_TM_OpenPosition(sreq, sticket);
     }

   // --- BUY-STOP leg (returned via req for the framework OnTick path). ---
   if(buy_leg_degenerate)
      return false; // only the sell leg was placeable this bar

   req.type   = QM_BUY_STOP;
   req.price  = buy_stop_price;
   req.sl     = QM_StopRulesNormalizePrice(_Symbol, buy_stop_price - sl_dist);
   req.tp     = QM_StopRulesNormalizePrice(_Symbol, buy_stop_price + tp_dist);
   req.reason = "robo32_buy_stop";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;
   return true;
  }

// Opposite-on-fill: once a position is open for this magic, cancel any surviving
// pending order so only the filled leg lives. Runs every tick (cheap O(<=2)).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0 && Strategy_PendingCount(magic) > 0)
      Strategy_CancelAllPendings(magic, "robo32_opposite_on_fill");
  }

// No discretionary close: exits are the fixed TP/SL carried on the filled order.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
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
