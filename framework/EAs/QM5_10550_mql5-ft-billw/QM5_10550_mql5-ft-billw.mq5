#property strict
#property version   "5.0"
#property description "QM5_10550 MQL5 FT Bill Williams Fractal Alligator"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10550 FT Bill Williams Fractal + Alligator
// -----------------------------------------------------------------------------
// Source: FT BillWillams Trader (fortrader.ru / Yuri idea / V. Karputov /
//   barabashkakvn), MQL5 CodeBase 17113. Mechanical fractal-breakout strategy
//   filtered by the Alligator Teeth.
//
// Entry  : confirmed 5-bar fractal on closed bars. If a buy fractal high sits
//          ABOVE the Alligator Teeth, arm a Buy Stop at fractal_high + buffer.
//          If a sell fractal low sits BELOW the Teeth, arm a Sell Stop at
//          fractal_low - buffer. A newer same-direction fractal cancels the
//          stale same-direction pending order. One position per symbol/magic.
// Exit   : close long when a closed bar's close crosses BELOW the Teeth, or on
//          a fresh opposite (sell) fractal-below-Teeth signal. Mirror for short.
// Stop   : opposite side of the triggering fractal structure OR ATR(14)*mult,
//          whichever is wider.
//
// Framework corset: all indicator reads via QM_* pooled readers (no raw iX),
// closed-bar shift=1 semantics, single QM_IsNewBar consumption (the framework
// OnTick owns the entry new-bar gate; this EA never calls QM_IsNewBar itself).
// The Alligator Teeth/Lips are SMMA(median) lines displaced forward, so their
// value at the latest closed bar (shift 1) is read at shift = 1 + displacement.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10550;
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
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Alligator (SMMA on median price, displaced forward). MT5 defaults:
//   Jaw  = SMMA(13) shift 8, Teeth = SMMA(8) shift 5, Lips = SMMA(5) shift 3.
// Teeth is the trade filter / exit line; Lips is reserved for P3 trailing.
input int    strategy_teeth_period      = 8;     // Alligator Teeth SMMA period
input int    strategy_teeth_shift       = 5;     // Teeth forward displacement (bars)
input int    strategy_lips_period       = 5;     // Alligator Lips SMMA period (P3 reserved)
input int    strategy_lips_shift        = 3;     // Lips forward displacement (bars)
input int    strategy_buffer_pips       = 1;     // stop-order trigger buffer beyond fractal
input int    strategy_atr_period        = 14;    // ATR period for fallback stop
input double strategy_atr_sl_mult       = 2.0;   // ATR multiple for fallback stop
input int    strategy_pending_max_bars  = 10;    // pending-order expiry in bars (0 = GTC)

// File-scope cache advanced once per closed bar inside Strategy_EntrySignal
// (the only per-closed-bar hook the framework guarantees). Read-only thereafter
// by the per-tick exit/management hooks.
double g_teeth          = 0.0;   // Teeth value at last closed bar
double g_buy_fractal    = 0.0;   // most-recent confirmed up-fractal price (0 = none)
double g_sell_fractal   = 0.0;   // most-recent confirmed down-fractal price (0 = none)
double g_last_buy_armed = 0.0;   // up-fractal price already armed as a Buy Stop
double g_last_sell_armed= 0.0;   // down-fractal price already armed as a Sell Stop
bool   g_state_ready    = false;

// Scan a bounded window of confirmed fractal bars and return the most recent
// up/down fractal prices. iFractals confirms a fractal at the centre bar only
// after its two right-hand bars close, so the freshest confirmed fractal sits
// at shift 2 (= 1 closed bar + 1 lag) or further back. We take the nearest one.
void RefreshFractals()
  {
   g_buy_fractal  = 0.0;
   g_sell_fractal = 0.0;
   const int max_scan = 12; // bounded: covers ~12 closed bars of fractal lookback
   for(int s = 2; s <= max_scan; ++s)
     {
      if(g_buy_fractal <= 0.0)
        {
         const double up = QM_FractalUpper(_Symbol, PERIOD_CURRENT, s);
         if(up > 0.0)
            g_buy_fractal = up;
        }
      if(g_sell_fractal <= 0.0)
        {
         const double dn = QM_FractalLower(_Symbol, PERIOD_CURRENT, s);
         if(dn > 0.0)
            g_sell_fractal = dn;
        }
      if(g_buy_fractal > 0.0 && g_sell_fractal > 0.0)
         break;
     }
  }

// Remove this EA's same-direction pending stop order (used to cancel a stale
// fractal signal when a newer same-direction fractal appears, or to clear
// pendings once a position is live). dir > 0 = remove Buy Stop, dir < 0 = Sell Stop.
void RemovePendingForDir(const int dir)
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
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(dir > 0 && ot == ORDER_TYPE_BUY_STOP)
         QM_TM_RemovePendingOrder(ticket, "fractal_cancel_stale_buy");
      else if(dir < 0 && ot == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, "fractal_cancel_stale_sell");
     }
  }

// True if this EA already has a working pending stop order in the given
// direction. dir > 0 = Buy Stop, dir < 0 = Sell Stop.
bool HasPendingForDir(const int dir)
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
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(dir > 0 && ot == ORDER_TYPE_BUY_STOP)
         return true;
      if(dir < 0 && ot == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// Arm a fresh stop order in `dir` (>0 buy, <0 sell) directly via the framework
// single-entry path. Cancels any stale same-direction pending first. Returns
// true if an order was placed. Used for the secondary direction inside
// Strategy_EntrySignal (the framework only sends the one req we return).
bool ArmPendingStop(const int dir, const double fractal_price)
  {
   if(fractal_price <= 0.0 || g_teeth <= 0.0)
      return false;

   const bool is_buy = (dir > 0);
   // Alligator filter: buy fractal must sit above Teeth; sell below Teeth.
   if(is_buy  && fractal_price <= g_teeth)
      return false;
   if(!is_buy && fractal_price >= g_teeth)
      return false;

   const QM_OrderType side = is_buy ? QM_BUY_STOP : QM_SELL_STOP;
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_buffer_pips);
   const double trigger = is_buy ? (fractal_price + buffer) : (fractal_price - buffer);
   if(trigger <= 0.0)
      return false;

   // Stop: opposite side of the triggering fractal structure OR ATR*mult,
   // whichever is WIDER (further from the trigger price).
   const double struct_dist = MathAbs(trigger - fractal_price); // = buffer (fractal is the structural anchor)
   double atr_sl = QM_StopATR(_Symbol, is_buy ? QM_BUY : QM_SELL, trigger,
                              strategy_atr_period, strategy_atr_sl_mult);
   const double atr_dist = (atr_sl > 0.0) ? MathAbs(trigger - atr_sl) : 0.0;
   // Structural anchor for the fractal: opposite extreme is the fractal itself
   // for a tight stop; the card wants the WIDER of structure vs ATR.
   double sl_dist = (atr_dist > struct_dist) ? atr_dist : struct_dist;
   if(sl_dist <= 0.0)
      return false;
   const double sl_price = is_buy ? (trigger - sl_dist) : (trigger + sl_dist);

   const int magic = QM_FrameworkMagic();
   if(HasOpenPosition())
      return false;

   RemovePendingForDir(dir); // cancel stale same-direction pending (newer fractal)

   QM_EntryRequest req;
   req.type = side;
   req.price = QM_StopRulesNormalizePrice(_Symbol, trigger);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   req.tp = 0.0;
   req.reason = is_buy ? "FRACTAL_BUYSTOP" : "FRACTAL_SELLSTOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   if(strategy_pending_max_bars > 0)
     {
      const int bar_secs = PeriodSeconds(PERIOD_CURRENT);
      if(bar_secs > 0)
         req.expiration_seconds = strategy_pending_max_bars * bar_secs;
     }

   ulong out_ticket = 0;
   const bool ok = QM_TM_OpenPosition(req, out_ticket);
   if(ok)
     {
      if(is_buy)
         g_last_buy_armed = fractal_price;
      else
         g_last_sell_armed = fractal_price;
     }
   return ok;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_teeth_period <= 0 || strategy_teeth_shift < 0 ||
      strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

// Runs exactly once per closed bar (caller guarantees QM_IsNewBar()==true).
// We use it as the single per-closed-bar tick: refresh cached Teeth + fractals,
// then arm BOTH pending stop directions. The buy direction is returned via req
// for the framework to send; the sell direction is armed directly here. Both
// stay live as working stop orders until filled, cancelled, or a position opens.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Advance cached closed-bar state (Teeth displaced SMMA on median price).
   g_teeth = QM_SMMA(_Symbol, PERIOD_CURRENT, strategy_teeth_period,
                     1 + strategy_teeth_shift, PRICE_MEDIAN);
   RefreshFractals();
   g_state_ready = (g_teeth > 0.0);
   if(!g_state_ready)
      return false;

   // While a position is live, clear any leftover pendings and do not arm new.
   if(HasOpenPosition())
     {
      RemovePendingForDir(1);
      RemovePendingForDir(-1);
      return false;
     }

   // Determine which directions have a FRESH (newly-confirmed) fractal beyond
   // the Teeth. A fractal is "fresh" if its price differs from the one we last
   // armed in that direction.
   const bool buy_qual  = (g_buy_fractal  > 0.0 && g_buy_fractal  > g_teeth &&
                           g_buy_fractal  != g_last_buy_armed);
   const bool sell_qual = (g_sell_fractal > 0.0 && g_sell_fractal < g_teeth &&
                           g_sell_fractal != g_last_sell_armed);

   bool returned_via_req = false;

   if(buy_qual)
     {
      // Build the buy-stop req for the framework to send (cancel stale first).
      const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_buffer_pips);
      const double trigger = g_buy_fractal + buffer;
      double atr_sl = QM_StopATR(_Symbol, QM_BUY, trigger, strategy_atr_period, strategy_atr_sl_mult);
      const double atr_dist = (atr_sl > 0.0) ? MathAbs(trigger - atr_sl) : 0.0;
      const double struct_dist = MathAbs(trigger - g_buy_fractal);
      const double sl_dist = (atr_dist > struct_dist) ? atr_dist : struct_dist;
      if(trigger > 0.0 && sl_dist > 0.0)
        {
         RemovePendingForDir(1);
         req.type = QM_BUY_STOP;
         req.price = QM_StopRulesNormalizePrice(_Symbol, trigger);
         req.sl = QM_StopRulesNormalizePrice(_Symbol, trigger - sl_dist);
         req.tp = 0.0;
         req.reason = "FRACTAL_BUYSTOP";
         if(strategy_pending_max_bars > 0)
           {
            const int bar_secs = PeriodSeconds(PERIOD_CURRENT);
            if(bar_secs > 0)
               req.expiration_seconds = strategy_pending_max_bars * bar_secs;
           }
         g_last_buy_armed = g_buy_fractal;
         returned_via_req = true;
        }
     }

   // Sell direction: arm directly (framework sends only the returned req).
   if(sell_qual)
      ArmPendingStop(-1, g_sell_fractal);

   return returned_via_req;
  }

void Strategy_ManageOpenPosition()
  {
   // Card P2 baseline: fixed initial SL, no trailing / break-even / partials.
   // Lips-based trailing is an explicit P3 sweep item, not in the baseline.
  }

// Per-tick discretionary exit. Uses cached closed-bar state only (O(1)):
//   - close long if the last closed bar's CLOSE crossed below the Teeth
//   - close long on a fresh opposite (sell) fractal-below-Teeth signal
//   - mirror for short
bool Strategy_ExitSignal()
  {
   if(!g_state_ready || g_teeth <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   bool have_long = false;
   bool have_short = false;
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY)
         have_long = true;
      else if(pt == POSITION_TYPE_SELL)
         have_short = true;
     }
   if(!have_long && !have_short)
      return false;

   // Last closed bar's close (shift 1) vs Teeth — closed-bar cross test.
   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: single closed-bar read for Teeth-cross exit
   if(close1 <= 0.0)
      return false;

   if(have_long)
     {
      if(close1 < g_teeth)
         return true;
      // fresh opposite (sell) signal below Teeth
      if(g_sell_fractal > 0.0 && g_sell_fractal < g_teeth)
         return true;
     }
   if(have_short)
     {
      if(close1 > g_teeth)
         return true;
      if(g_buy_fractal > 0.0 && g_buy_fractal > g_teeth)
         return true;
     }
   return false;
  }

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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
