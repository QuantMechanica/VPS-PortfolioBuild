#property strict
#property version   "5.0"
#property description "QM5_20005 Kurisko Quad Rotation Structure Retest M5"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20005;
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
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Kurisko Quad Rotation (four stochastics, OWNER mechanization directive
// 2026-07-17): horizontal consolidation range -> breakout -> retest of the
// broken boundary via resting limit order, armed ONLY while all four
// stochastics sit in the opposite-side zone on the last closed bar. One
// direction at a time, one order at a time — explicitly NO OCO pairing.
input int    strategy_stoch1_k            = 9;   // fast / trigger stochastic %K
input int    strategy_stoch1_d            = 3;
input int    strategy_stoch1_slow         = 3;
input int    strategy_stoch2_k            = 14;
input int    strategy_stoch2_d            = 3;
input int    strategy_stoch2_slow         = 3;
input int    strategy_stoch3_k            = 44;
input int    strategy_stoch3_d            = 3;
input int    strategy_stoch3_slow         = 3;
input int    strategy_stoch4_k            = 60;  // slow stochastic %K
input int    strategy_stoch4_d            = 10;
input int    strategy_stoch4_slow         = 3;
input double strategy_zone_oversold       = 20.0;
input double strategy_zone_overbought     = 80.0;
input int    strategy_range_bars          = 36;  // consolidation box lookback (closed bars)
input double strategy_range_min_atr_mult  = 0.8; // box height floor vs ATR
input double strategy_range_max_atr_mult  = 3.0; // box height ceiling vs ATR
input double strategy_breakout_buffer_atr = 0.10; // close must clear boundary by this x ATR
input int    strategy_retest_window_bars  = 72;  // armed-state lifetime in closed bars
input int    strategy_atr_period          = 14;
input int    strategy_sl_pips             = 0;   // fail-safe SL distance; 0 = ATR-derived
input int    strategy_tp_pips             = 0;   // fail-safe TP distance; 0 = ATR-derived
input double strategy_sl_atr_mult         = 2.0; // used when strategy_sl_pips = 0
input double strategy_tp_atr_mult         = 4.0; // used when strategy_tp_pips = 0

// Breakout/retest state machine. SCAN looks for a consolidation box broken
// by the last closed bar; RETEST_* keeps a limit order resting at the broken
// boundary while the quad-stochastic confluence holds on closed bars.
enum QuadRotState
  {
   QUADROT_SCAN = 0,
   QUADROT_RETEST_LONG = 1,
   QUADROT_RETEST_SHORT = 2
  };

QuadRotState g_strategy_state = QUADROT_SCAN;
double g_strategy_range_high = 0.0;
double g_strategy_range_low = 0.0;
int    g_strategy_retest_bars_left = 0;
bool   g_strategy_was_in_trade = false;

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

bool Strategy_IsOurPendingType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT);
  }

int Strategy_RemoveOurPendingOrders(const string reason)
  {
   int removed = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(QM_TM_RemovePendingOrder(ticket, reason))
         removed++;
     }
   return removed;
  }

bool Strategy_HasOurPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < OrdersTotal(); ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < PositionsTotal(); ++i)
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

// Quad Rotation checks read the MAIN (slowed %K) line of all four
// stochastics on the LAST CLOSED bar. A failed indicator read returns 0.0
// from the pooled reader, which would count as "oversold" — the k > 0.0
// guard keeps unwarmed buffers from arming false long confluence.
bool Strategy_QuadOversold()
  {
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch1_k, strategy_stoch1_d, strategy_stoch1_slow, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch2_k, strategy_stoch2_d, strategy_stoch2_slow, 1);
   const double k3 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch3_k, strategy_stoch3_d, strategy_stoch3_slow, 1);
   const double k4 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch4_k, strategy_stoch4_d, strategy_stoch4_slow, 1);
   return (k1 > 0.0 && k1 < strategy_zone_oversold &&
           k2 > 0.0 && k2 < strategy_zone_oversold &&
           k3 > 0.0 && k3 < strategy_zone_oversold &&
           k4 > 0.0 && k4 < strategy_zone_oversold);
  }

bool Strategy_QuadOverbought()
  {
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch1_k, strategy_stoch1_d, strategy_stoch1_slow, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch2_k, strategy_stoch2_d, strategy_stoch2_slow, 1);
   const double k3 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch3_k, strategy_stoch3_d, strategy_stoch3_slow, 1);
   const double k4 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch4_k, strategy_stoch4_d, strategy_stoch4_slow, 1);
   return (k1 > strategy_zone_overbought && k1 <= 100.0 &&
           k2 > strategy_zone_overbought && k2 <= 100.0 &&
           k3 > strategy_zone_overbought && k3 <= 100.0 &&
           k4 > strategy_zone_overbought && k4 <= 100.0);
  }

// Fail-safe SL/TP distances (OWNER spec): explicit pips inputs win; at the
// 0 default both derive dynamically from ATR at order placement so defaults
// stay scale-sane across SP500/NDX/WS30 without per-symbol hand-tuning.
void Strategy_FailsafeDistances(const double atr, double &sl_dist, double &tp_dist)
  {
   sl_dist = (strategy_sl_pips > 0)
             ? QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips)
             : atr * strategy_sl_atr_mult;
   tp_dist = (strategy_tp_pips > 0)
             ? QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips)
             : atr * strategy_tp_atr_mult;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): no session window — the range /
   // breakout / retest state machine is the timing filter. High-impact news
   // is delegated to the V5 two-axis news gate. No spread gate: .DWX quotes
   // ask == bid in the tester (zero-spread invariant).
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: advance the SCAN -> RETEST state machine once per closed
   // bar. In RETEST the returned request is a LIMIT order resting at the
   // broken boundary, placed only while all four stochastics hold the
   // opposite-side zone (Quad Rotation confluence). No OCO: one direction,
   // one order, ever.
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOurOpenPosition())
     {
      g_strategy_was_in_trade = true;
      return false;
     }
   if(g_strategy_was_in_trade)
     {
      // Trade completed (stoch exit, SL, TP, or Friday close): sweep any
      // orphan order and restart from a clean SCAN on the next closed bar.
      g_strategy_was_in_trade = false;
      g_strategy_state = QUADROT_SCAN;
      Strategy_RemoveOurPendingOrders("QUADROT_POST_TRADE_SWEEP");
      return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int need = strategy_range_bars + 1;
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, need, rates); // perf-allowed: once per closed bar, bounded by input default 37.
   if(copied < need)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(g_strategy_state == QUADROT_RETEST_LONG || g_strategy_state == QUADROT_RETEST_SHORT)
     {
      const bool is_long = (g_strategy_state == QUADROT_RETEST_LONG);
      g_strategy_retest_bars_left--;

      const double mid = 0.5 * (g_strategy_range_high + g_strategy_range_low);
      const double trigger_close = rates[0].close;
      const bool expired = (g_strategy_retest_bars_left <= 0);
      const bool invalidated = is_long ? (trigger_close < mid) : (trigger_close > mid);
      if(expired || invalidated)
        {
         Strategy_RemoveOurPendingOrders(expired ? "QUADROT_RETEST_WINDOW_EXPIRED"
                                                 : "QUADROT_BREAKOUT_INVALIDATED");
         g_strategy_state = QUADROT_SCAN;
         return false;
        }

      const bool quad = is_long ? Strategy_QuadOversold() : Strategy_QuadOverbought();
      if(!quad)
        {
         // Confluence lapsed: the boundary may NOT be hit while the quad
         // condition is off — pull the resting order (OWNER spec: entry only
         // on exact convergence of structure and indicators).
         Strategy_RemoveOurPendingOrders("QUADROT_CONFLUENCE_LAPSED");
         return false;
        }
      if(Strategy_HasOurPendingOrders())
         return false;   // limit already resting at the boundary

      // Order-validity guard: a BUY LIMIT must sit BELOW the market, a SELL
      // LIMIT above it. If price is currently through the boundary the
      // retest ran deeper than the level — wait for price to hold the
      // breakout side again (or for midpoint invalidation to kill the
      // setup) instead of spamming broker-rejected orders.
      const double entry = is_long ? g_strategy_range_high : g_strategy_range_low;
      const double market = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(market <= 0.0)
         return false;
      if(is_long && market <= entry)
         return false;
      if(!is_long && market >= entry)
         return false;

      double sl_dist = 0.0;
      double tp_dist = 0.0;
      Strategy_FailsafeDistances(atr, sl_dist, tp_dist);
      if(sl_dist <= 0.0 || tp_dist <= 0.0)
         return false;
      req.type = is_long ? QM_BUY_LIMIT : QM_SELL_LIMIT;
      req.price = Strategy_NormalizePrice(entry);
      req.sl = Strategy_NormalizePrice(is_long ? entry - sl_dist : entry + sl_dist);
      req.tp = Strategy_NormalizePrice(is_long ? entry + tp_dist : entry - tp_dist);
      req.reason = is_long ? "QUADROT_RETEST_LONG_LIMIT" : "QUADROT_RETEST_SHORT_LIMIT";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // SCAN: consolidation box over the strategy_range_bars closed bars BEFORE
   // the last closed bar (rates[1..range_bars]); the last closed bar
   // (rates[0]) is the breakout trigger candidate.
   if(Strategy_HasOurPendingOrders())
      return false;   // defensive: never re-scan while an order rests

   double box_high = -DBL_MAX;
   double box_low = DBL_MAX;
   for(int i = 1; i <= strategy_range_bars; ++i)
     {
      box_high = MathMax(box_high, rates[i].high);
      box_low = MathMin(box_low, rates[i].low);
     }
   const double box_height = box_high - box_low;
   if(box_low <= 0.0 || box_height <= 0.0)
      return false;
   if(box_height < strategy_range_min_atr_mult * atr ||
      box_height > strategy_range_max_atr_mult * atr)
      return false;

   const double buffer = strategy_breakout_buffer_atr * atr;
   const double trigger_close = rates[0].close;
   if(trigger_close > box_high + buffer)
     {
      g_strategy_range_high = box_high;
      g_strategy_range_low = box_low;
      g_strategy_state = QUADROT_RETEST_LONG;
      g_strategy_retest_bars_left = strategy_retest_window_bars;
     }
   else if(trigger_close < box_low - buffer)
     {
      g_strategy_range_high = box_high;
      g_strategy_range_low = box_low;
      g_strategy_state = QUADROT_RETEST_SHORT;
      g_strategy_retest_bars_left = strategy_retest_window_bars;
     }
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: fail-safe SL/TP ride server-side from placement and
   // the primary exit is the fast-stochastic rotation in Strategy_ExitSignal
   // — no trailing/BE per OWNER spec ("algorithmisch strikt"). This hook
   // latches the fill flag (catches intra-bar limit fills that open AND
   // close inside one bar) and sweeps orphan pendings (none expected: no
   // OCO sibling exists by design).
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      g_strategy_was_in_trade = true;
      if(Strategy_HasOurPendingOrders())
         Strategy_RemoveOurPendingOrders("QUADROT_ORPHAN_PENDING_SWEEP");
      break;
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close (OWNER spec, strict): long closes at market once the fast
   // stochastic (stoch1) MAIN line reaches the overbought zone on the last
   // closed bar; short closes once it reaches the oversold zone. The k > 0.0
   // guard on the short side keeps a failed indicator read (0.0) from
   // false-triggering the exit.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double k1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT,
                                   strategy_stoch1_k, strategy_stoch1_d, strategy_stoch1_slow, 1);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && k1 >= strategy_zone_overbought)
         return true;
      if(pos_type == POSITION_TYPE_SELL && k1 > 0.0 && k1 <= strategy_zone_oversold)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: the card's high-impact blackout is handled by the
   // framework's two-axis news inputs (PRE30_POST30 + DXZ compliance).
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
