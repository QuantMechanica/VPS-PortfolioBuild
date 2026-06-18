#property strict
#property version   "5.0"
#property description "QM5_11440 JanusTrader 100-Pips Daily-Range Layered OCO Breakout (H1, bounded 1% risk)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11440 janus-100pips-daily-range-layered
// -----------------------------------------------------------------------------
// Daily-range breakout at the broker day reset. Each broker day, measure the
// PRIOR CLOSED day's range (iHigh/iLow on PERIOD_D1 shift 1, broker-time day
// boundary). Arm a LAYERED cluster of BUYSTOP orders `offset_pips` above the
// range high and a mirror cluster of SELLSTOP orders `offset_pips` below the
// range low. Each layer carries a DIFFERENT take-profit (tp_pips_layer[k]) and
// a COMMON catastrophic stop (sl_pips). When any order on one side fills, all
// pending orders on the OPPOSITE side are cancelled (OCO). All pendings expire
// at the next broker-day reset (24h window) and are re-armed fresh each day.
//
// BOUNDED-RISK PROPERTY (R4 / HR14-critical — NOT a martingale/grid):
//   * Every layer shares the SAME entry trigger price (range edge +/- offset)
//     and the SAME stop distance sl_pips. There is NO averaging-down: layers do
//     not step deeper as price moves against the basket; they all fire at one
//     trigger and differ only in TP. This is a fixed cluster, not a grid.
//   * The combined lots are backward-solved so the FULL cluster filled and then
//     ALL stopped at the shared sl_pips loses exactly risk_budget_pct of equity.
//     Worst case (every layer fills, all hit the common SL) == risk budget. The
//     lot ladder uses lot_mult (default 1.0 = equal lots) bounded to [1.0,1.3];
//     it NEVER escalates after an adverse move, so the worst-case stays fixed.
//   * Because both clusters are armed simultaneously, only ONE side can fill
//     (OCO cancels the other on first fill), so the per-day worst case is one
//     cluster's budget, not two.
//
// Framework-contract notes (mirror QM5_12552 bounded-grid build):
//   * QM_EntryRequest carries no lot field and QM_Entry sizes via QM_LotsForRisk
//     + rejects a 2nd same-magic position. This strategy needs explicit per-layer
//     lots AND multiple simultaneous same-magic PENDING orders, so the framework
//     auto-entry path cannot express it. Strategy_EntrySignal() ALWAYS returns
//     false; all placement/cancellation happens in Strategy_ManageOpenPosition()
//     through QM_TradeContextSend (the framework trade context — requote/kill/
//     logging-class handling identical to QM_Entry), so the OnTick kill-switch,
//     news and Friday-close corset still fully govern when orders may be placed.
//   * Day boundary uses the broker calendar day (DXZ NY-Close GMT+2/+3). The
//     card's "18:00 EST == 00:00 broker" maps to broker midnight; using the
//     prior CLOSED D1 bar is exactly the broker-day range and is DST-robust.
//   * .DWX invariants: spread filter fails OPEN (never blocks on 0 spread); no
//     swap gate; no external CSV/feed; pip-scaled distances via Strategy_PipSize.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11440;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

// -----------------------------------------------------------------------------
// Strategy parameters (card "Entry / Exit / Session Parameters" + P3 sweeps)
// -----------------------------------------------------------------------------
input group "Strategy"
input double   offset_pips           = 7.0;    // breakout trigger offset beyond the range edge
input double   sl_pips               = 25.0;   // SHARED catastrophic stop (pips) — common to all layers
input int      n_layers              = 3;      // number of layered orders per side (>=1)
input double   tp_pips_layer1        = 15.0;   // layer 1 take-profit (pips)
input double   tp_pips_layer2        = 35.0;   // layer 2 take-profit (pips)
input double   tp_pips_layer3        = 50.0;   // layer 3 take-profit (pips)
input double   lot_mult              = 1.0;    // per-layer lot multiplier, bounded [1.0, 1.3] (1.0 = equal lots)
input double   risk_budget_pct       = 1.0;    // FULL-cluster worst-case risk (% equity) — the bound
input double   max_spread_pips       = 15.0;   // wide-spread block (pips); fail-OPEN on 0 spread
input bool     enable_long           = true;   // arm the BUYSTOP cluster
input bool     enable_short          = true;   // arm the SELLSTOP cluster

// -----------------------------------------------------------------------------
// File-scope per-day state.
// -----------------------------------------------------------------------------
#define QM_MAX_LAYERS 8

datetime g_armed_day        = 0;     // broker-day date (00:00) the clusters were armed for
bool     g_oco_triggered    = false; // a fill happened this day -> opposite side cancelled
int      g_planned_layers   = 0;     // layers actually armed (<= n_layers)

// =============================================================================
// Helpers
// =============================================================================

// Pip size: 10 points on 3/5-digit FX quotes, 1 point otherwise.
double Strategy_PipSize()
  {
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

// Money lost per lot per unit of adverse price travel (tick value / tick size).
double Strategy_ValuePerLotPerPriceUnit()
  {
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_value > 0.0 && tick_size > 0.0)
      return tick_value / tick_size;
   const double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   return (contract > 0.0) ? contract : 0.0;
  }

// Broker-day date floor (strip time-of-day) for the given broker timestamp.
datetime Strategy_BrokerDayFloor(const datetime broker_now)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_now, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

// TP for layer k (0-based), clamped to the configured layers.
double Strategy_TPPipsForLayer(const int k)
  {
   if(k <= 0)
      return tp_pips_layer1;
   if(k == 1)
      return tp_pips_layer2;
   return tp_pips_layer3;
  }

// Backward-solve the per-layer bounded lots. The FULL cluster filled and then
// ALL stopped at the COMMON sl_pips must lose exactly risk_budget_pct of equity:
//   Σ_k L_k * sl_dist * value_per_unit == budget,  L_k = L_1 * lot_mult^k
// => L_1 = budget / (sl_dist * value_per_unit * Σ_k lot_mult^k).
// Returns the number of plannable layers (lots that round >= broker min), and
// fills out_lots[] for the contiguous valid prefix. 0 if sizing impossible.
int Strategy_SolveBoundedLots(double &out_lots[])
  {
   int N = n_layers;
   if(N < 1)
      N = 1;
   if(N > QM_MAX_LAYERS)
      N = QM_MAX_LAYERS;

   double mult = lot_mult;
   if(mult < 1.0)
      mult = 1.0;
   if(mult > 1.3)
      mult = 1.3;

   const double pip = Strategy_PipSize();
   if(pip <= 0.0)
      return 0;
   const double sl_dist = sl_pips * pip;
   if(sl_dist <= 0.0)
      return 0;

   const double value_unit = Strategy_ValuePerLotPerPriceUnit();
   if(value_unit <= 0.0)
      return 0;

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double budget = (risk_budget_pct / 100.0) * equity;
   if(budget <= 0.0)
      return 0;

   double weight_sum = 0.0;
   for(int k = 0; k < N; ++k)
      weight_sum += MathPow(mult, (double)k);
   if(weight_sum <= 0.0)
      return 0;

   const double L1 = budget / (sl_dist * value_unit * weight_sum);

   ArrayResize(out_lots, N);
   int plannable = 0;
   for(int k = 0; k < N; ++k)
     {
      const double raw  = L1 * MathPow(mult, (double)k);
      const double norm = QM_TM_NormalizeVolume(_Symbol, raw);
      out_lots[k] = norm;          // 0.0 => sub-min layer, skipped (never up-sized)
      if(norm > 0.0)
         plannable++;
     }
   if(plannable <= 0 || out_lots[0] <= 0.0)
      return 0;                     // cannot even afford layer 1 within budget
   return N;
  }

// Place ONE bounded pending stop order (BUYSTOP/SELLSTOP) at an explicit lot,
// with the shared SL and the layer's TP, expiring at the next broker-day reset.
// Mirrors QM5_12552 Strategy_SendBounded but for pending stop orders.
bool Strategy_SendPending(const bool is_buy, const double lots, const double trigger,
                          const double sl, const double tp, const datetime expiry,
                          const string reason)
  {
   const double norm_lots = QM_TM_NormalizeVolume(_Symbol, lots);
   if(norm_lots <= 0.0)
      return false;
   if(trigger <= 0.0)
      return false;

   MqlTradeRequest request;
   ZeroMemory(request);
   request.action       = TRADE_ACTION_PENDING;
   request.symbol       = _Symbol;
   request.magic        = QM_FrameworkMagic();
   request.volume       = norm_lots;
   request.type         = is_buy ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
   request.price        = QM_TM_NormalizePrice(_Symbol, trigger);
   request.sl           = (sl > 0.0) ? QM_TM_NormalizePrice(_Symbol, sl) : 0.0;
   request.tp           = (tp > 0.0) ? QM_TM_NormalizePrice(_Symbol, tp) : 0.0;
   request.deviation    = QM_TM_DEFAULT_DEVIATION_POINTS;
   request.type_time    = ORDER_TIME_SPECIFIED;
   request.expiration   = expiry;
   request.comment      = reason;

   MqlTradeResult result;
   string error_class = "";
   const bool ok = QM_TradeContextSend(request, result, error_class);

   const string payload = StringFormat(
      "{\"symbol\":\"%s\",\"buy\":%s,\"lots\":%.8f,\"trigger\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
      QM_LoggerEscapeJson(_Symbol), is_buy ? "true" : "false", norm_lots,
      request.price, request.sl, request.tp, QM_LoggerEscapeJson(reason),
      ok ? "true" : "false", result.retcode, QM_LoggerEscapeJson(error_class));
   QM_LogEvent(ok ? QM_INFO : QM_WARN, "LAYER_PENDING", payload);
   return ok;
  }

// Count this magic's open positions and pending orders on this symbol.
void Strategy_CountWorkingOrders(int &out_open, int &out_buy_pending, int &out_sell_pending)
  {
   out_open         = 0;
   out_buy_pending  = 0;
   out_sell_pending = 0;
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
      out_open++;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const long ot = OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP)
         out_buy_pending++;
      else if(ot == ORDER_TYPE_SELL_STOP)
         out_sell_pending++;
     }
  }

// Cancel all of this magic's pending stop orders on this symbol whose direction
// matches `cancel_buys` (true => cancel BUYSTOPs, false => cancel SELLSTOPs).
void Strategy_CancelPendings(const bool cancel_buys)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const long ot = OrderGetInteger(ORDER_TYPE);
      const bool is_buy_stop  = (ot == ORDER_TYPE_BUY_STOP);
      const bool is_sell_stop = (ot == ORDER_TYPE_SELL_STOP);
      if((cancel_buys && is_buy_stop) || (!cancel_buys && is_sell_stop))
         QM_TM_RemovePendingOrder(ticket, "OCO_CANCEL_OPPOSITE");
     }
  }

// Cancel ALL of this magic's pending stop orders on this symbol (day reset).
void Strategy_CancelAllPendings(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const long ot = OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

// Arm both layered clusters for the new broker day from the prior CLOSED daily
// range. Returns true if at least one order was placed.
bool Strategy_ArmDay(const datetime broker_now)
  {
   // Prior CLOSED daily bar = the broker-day range just completed at reset.
   const double day_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 range edge
   const double day_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed: closed D1 range edge
   if(day_high <= 0.0 || day_low <= 0.0 || day_high <= day_low)
      return false;

   const double pip = Strategy_PipSize();
   if(pip <= 0.0)
      return false;

   double lots[];
   const int N = Strategy_SolveBoundedLots(lots);
   if(N <= 0)
      return false;

   const double offset = offset_pips * pip;
   const double sl_d   = sl_pips * pip;

   const double buy_trigger  = day_high + offset;
   const double sell_trigger = day_low  - offset;
   // Common catastrophic stop, shared across all layers on each side.
   const double buy_sl  = buy_trigger  - sl_d;
   const double sell_sl = sell_trigger + sl_d;

   // Expiry: next broker-day reset (current armed day + 24h).
   const datetime expiry = Strategy_BrokerDayFloor(broker_now) + 24 * 3600;

   int placed = 0;
   for(int k = 0; k < N; ++k)
     {
      if(lots[k] <= 0.0)               // sub-min layer dropped (budget-faithful)
         continue;
      const double tp_pips = Strategy_TPPipsForLayer(k);
      const double tp_dist = tp_pips * pip;

      if(enable_long)
        {
         const double tp = buy_trigger + tp_dist;
         if(Strategy_SendPending(true, lots[k], buy_trigger, buy_sl, tp, expiry,
                                 StringFormat("JANUS_BUYSTOP_L%d", k + 1)))
            placed++;
        }
      if(enable_short)
        {
         const double tp = sell_trigger - tp_dist;
         if(Strategy_SendPending(false, lots[k], sell_trigger, sell_sl, tp, expiry,
                                 StringFormat("JANUS_SELLSTOP_L%d", k + 1)))
            placed++;
        }
     }

   if(placed > 0)
      g_planned_layers = N;
   return (placed > 0);
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// Spread filter only. Block ONLY a genuinely wide spread; NEVER block on a
// zero / degenerate spread (.DWX quotes ask==bid / spread==0 in the tester).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double pip = Strategy_PipSize();
   if(pip <= 0.0)
      return false;
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > max_spread_pips * pip)
      return true;   // genuinely wide spread -> block
   return false;
  }

// No framework auto-entry: the layered cluster (explicit per-layer lots +
// multiple simultaneous same-magic pending orders + OCO) cannot go through
// QM_Entry. All placement/cancellation happens in Strategy_ManageOpenPosition().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return false;
  }

// All arming / OCO / day-reset logic. Runs every tick (framework calls this
// before the QM_IsNewBar entry gate). Per-day arming is gated on the broker-day
// floor so it happens once per broker day, not per tick.
void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   const datetime day_floor  = Strategy_BrokerDayFloor(broker_now);

   int open_count, buy_pending, sell_pending;
   Strategy_CountWorkingOrders(open_count, buy_pending, sell_pending);

   // ---- New broker day: clear any stale working orders, re-arm fresh. ----
   if(day_floor != g_armed_day)
     {
      // Cancel leftover pendings from the previous day (expiry also handles
      // this broker-side, but we cancel explicitly to keep state clean).
      Strategy_CancelAllPendings("DAY_RESET");
      g_armed_day      = day_floor;
      g_oco_triggered  = false;
      g_planned_layers = 0;

      // Only arm when flat (no open position carried over). If a position is
      // still open from yesterday, let it run on its own SL/TP; do not arm.
      if(open_count <= 0)
         Strategy_ArmDay(broker_now);
      return;
     }

   // ---- Same day: OCO. On the first fill, cancel the opposite cluster. ----
   if(!g_oco_triggered && open_count > 0)
     {
      // Determine which side filled by inspecting the open position direction.
      const int magic = QM_FrameworkMagic();
      int net_dir = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         const long pt = PositionGetInteger(POSITION_TYPE);
         net_dir = (pt == POSITION_TYPE_BUY) ? 1 : -1;
         break;
        }
      if(net_dir > 0)
         Strategy_CancelPendings(false);   // long filled -> cancel SELLSTOPs
      else if(net_dir < 0)
         Strategy_CancelPendings(true);    // short filled -> cancel BUYSTOPs
      g_oco_triggered = true;
     }
  }

// No discretionary virtual exit — each layer exits on its own broker SL/TP.
// The shared SL and per-layer TP are attached at placement time. Time/expiry is
// handled by the pending-order expiry and the next-day reset.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Optional news-filter override. Defer to the central framework filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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

   g_armed_day      = 0;
   g_oco_triggered  = false;
   g_planned_layers = 0;
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: arming / OCO / day-reset bookkeeping.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (none here — exits via broker SL/TP).
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

   // Per-closed-bar: entry-signal evaluation (always false for this EA; arming
   // is done in Strategy_ManageOpenPosition). Gate kept for framework parity.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
