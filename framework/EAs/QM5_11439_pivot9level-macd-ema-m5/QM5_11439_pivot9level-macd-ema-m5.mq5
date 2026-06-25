#property strict
#property version   "5.0"
#property description "QM5_11439 pivot9level-macd-ema-m5 — 9-Level Daily Pivot + MACD zero-cross + EMA9 trail (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11439 pivot9level-macd-ema-m5
// -----------------------------------------------------------------------------
// Source: DayTradeForex.com "9 Profitable Trading Systems" (System #9).
// Card: artifacts/cards_approved/QM5_11439_pivot9level-macd-ema-m5.md
//       (g0_status APPROVED, source_id fb2ae527-c7ef-5765-a09d-9eb8157e55a0).
//
// Mechanics — STATES vs the single EVENT (avoids the two-cross-same-bar trap):
//
//   Pivot STATES  : 9 classic floor levels (S2,M1,S1,M2,P,M3,R1,M4,R2) computed
//                   deterministically from the PRIOR CLOSED day's OHLC (D1 shift
//                   1 = prior day boundary in broker time). These are persistent
//                   reaction zones, NOT events.
//                     P  = (H+L+C)/3
//                     R1 = 2P-L      R2 = P+(H-L)
//                     S1 = 2P-H      S2 = P-(H-L)
//                     M1 = (S1+S2)/2 M2 = (P+S1)/2
//                     M3 = (P+R1)/2  M4 = (R1+R2)/2
//   Proximity STATE: Close[1] within prox_pips of a support level (long) or a
//                    resistance level (short).
//   Trend STATE   : H1 MACD histogram (Main-Signal) sign aligns with the trade.
//                   MACD can be negative — the test is sign alignment, not >0
//                   absolute, for the H1 filter direction.
//   Trigger EVENT : M5 MACD histogram (Main-Signal) crosses zero — ONE event.
//                     LONG : hist[2] <= 0 AND hist[1] > 0
//                     SHORT: hist[2] >= 0 AND hist[1] < 0
//   Stop          : prox_pips beyond the triggering pivot, capped at sl_cap_pips.
//   Take profit   : next pivot level in the trade direction (fallback: RR cap).
//   Trail exit    : M5 close crosses EMA(trail) against the position (defensive,
//                   evaluated as a per-bar EVENT in Strategy_ExitSignal).
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread per .DWX invariants).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11439;
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

input group "Strategy"
input int    strategy_macd_fast         = 12;     // M5/H1 MACD fast EMA
input int    strategy_macd_slow         = 26;     // M5/H1 MACD slow EMA
input int    strategy_macd_signal       = 9;      // M5/H1 MACD signal EMA
input int    strategy_prox_pips         = 5;      // proximity to pivot (pips) + SL buffer
input int    strategy_sl_cap_pips       = 30;     // P2 max stop distance (pips)
input int    strategy_ema_trail_period  = 9;      // M5 EMA trail-exit period
input double strategy_tp_rr_fallback    = 2.0;    // RR-multiple TP if no next pivot exists
input int    strategy_spread_cap_pips   = 15;     // skip if spread exceeds this pip cap

// -----------------------------------------------------------------------------
// File-scope cached pivot STATES — recomputed once per closed M5 bar from the
// prior CLOSED day's OHLC. Index order is monotonically increasing in price:
//   0=S2 1=M1 2=S1 3=M2 4=P 5=M3 6=R1 7=M4 8=R2
// -----------------------------------------------------------------------------
double g_pivots[9];
bool   g_pivots_valid = false;

// Indices into g_pivots.
#define PV_S2 0
#define PV_M1 1
#define PV_S1 2
#define PV_M2 3
#define PV_P  4
#define PV_M3 5
#define PV_R1 6
#define PV_M4 7
#define PV_R2 8

// Recompute the 9 pivot levels from the prior closed D1 bar. Cheap: 3 closed-bar
// reads + arithmetic. Called once per new M5 bar (closed-bar gate upstream).
void AdvancePivots_OnNewBar()
  {
   const double H = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: prior closed D1 pivot high
   const double L = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: prior closed D1 pivot low
   const double C = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: prior closed D1 pivot close
   if(H <= 0.0 || L <= 0.0 || C <= 0.0 || H < L)
     {
      g_pivots_valid = false;
      return;
     }

   const double P  = (H + L + C) / 3.0;
   const double R1 = 2.0 * P - L;
   const double R2 = P + (H - L);
   const double S1 = 2.0 * P - H;
   const double S2 = P - (H - L);
   const double M1 = (S1 + S2) / 2.0;
   const double M2 = (P + S1) / 2.0;
   const double M3 = (P + R1) / 2.0;
   const double M4 = (R1 + R2) / 2.0;

   g_pivots[PV_S2] = S2;
   g_pivots[PV_M1] = M1;
   g_pivots[PV_S1] = S1;
   g_pivots[PV_M2] = M2;
   g_pivots[PV_P]  = P;
   g_pivots[PV_M3] = M3;
   g_pivots[PV_R1] = R1;
   g_pivots[PV_M4] = M4;
   g_pivots[PV_R2] = R2;
   g_pivots_valid = true;
  }

// Pip size as a price distance (5-digit / JPY scale-correct).
double PipPriceDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// Find the support pivot (index <= PV_P) nearest to `ref` within `tol` price
// distance. Returns the level price, or -1.0 if none. Sets out_idx.
double NearestSupportWithin(const double ref, const double tol, int &out_idx)
  {
   out_idx = -1;
   double best = -1.0;
   double best_dist = tol; // strict: must be within tol
   for(int i = PV_S2; i <= PV_P; ++i)
     {
      if(ref > g_pivots[i])
         continue;
      const double d = g_pivots[i] - ref;
      if(d <= best_dist)
        {
         best_dist = d;
         best = g_pivots[i];
         out_idx = i;
        }
     }
   return best;
  }

// Find the resistance pivot (index >= PV_P) nearest to `ref` within `tol`.
double NearestResistanceWithin(const double ref, const double tol, int &out_idx)
  {
   out_idx = -1;
   double best = -1.0;
   double best_dist = tol;
   for(int i = PV_P; i <= PV_R2; ++i)
     {
      if(ref < g_pivots[i])
         continue;
      const double d = ref - g_pivots[i];
      if(d <= best_dist)
        {
         best_dist = d;
         best = g_pivots[i];
         out_idx = i;
        }
     }
   return best;
  }

// Next pivot strictly ABOVE `level_idx` (for a long TP). Returns price or -1.0.
double NextPivotAbove(const int level_idx)
  {
   if(level_idx < 0 || level_idx >= PV_R2)
      return -1.0;
   return g_pivots[level_idx + 1];
  }

// Next pivot strictly BELOW `level_idx` (for a short TP). Returns price or -1.0.
double NextPivotBelow(const int level_idx)
  {
   if(level_idx <= PV_S2 || level_idx > PV_R2)
      return -1.0;
   return g_pivots[level_idx - 1];
  }

// M5 MACD histogram (Main - Signal) at a given closed-bar shift.
double M5MacdHist(const int shift)
  {
   const double m = QM_MACD_Main(_Symbol, PERIOD_M5,
                                 strategy_macd_fast, strategy_macd_slow,
                                 strategy_macd_signal, shift);
   const double s = QM_MACD_Signal(_Symbol, PERIOD_M5,
                                   strategy_macd_fast, strategy_macd_slow,
                                   strategy_macd_signal, shift);
   return m - s;
  }

// H1 MACD histogram (Main - Signal) at the last closed H1 bar.
double H1MacdHist()
  {
   const double m = QM_MACD_Main(_Symbol, PERIOD_H1,
                                 strategy_macd_fast, strategy_macd_slow,
                                 strategy_macd_signal, 1);
   const double s = QM_MACD_Signal(_Symbol, PERIOD_H1,
                                   strategy_macd_fast, strategy_macd_slow,
                                   strategy_macd_signal, 1);
   return m - s;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = PipPriceDistance(strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(ask > 0.0 && bid > 0.0 && ask > bid && spread > spread_cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (M5 closed-bar gate). Pivots
// are advanced for this bar by AdvancePivots_OnNewBar() before this runs.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_pivots_valid)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double tol = PipPriceDistance(strategy_prox_pips);
   if(tol <= 0.0)
      return false;

   // --- Trigger EVENT: M5 MACD histogram zero-cross (one event/bar) ---
   const double hist1 = M5MacdHist(1); // last closed bar
   const double hist2 = M5MacdHist(2); // bar before
   const bool cross_up   = (hist2 <= 0.0 && hist1 > 0.0);
   const bool cross_down = (hist2 >= 0.0 && hist1 < 0.0);
   if(!cross_up && !cross_down)
      return false;

   // --- Trend STATE: H1 MACD histogram sign aligns with the trade direction ---
   const double h1hist = H1MacdHist();

   if(cross_up)
     {
      // LONG: H1 momentum non-negative (aligned up). MACD may be negative; we
      // require the H1 histogram sign to be supportive (>0).
      if(!(h1hist > 0.0))
         return false;

      // Proximity STATE: Close[1] within tol of a SUPPORT pivot.
      int piv_idx = -1;
      const double piv = NearestSupportWithin(close1, tol, piv_idx);
      if(piv_idx < 0 || piv <= 0.0)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // SL: prox_pips below the triggering pivot, capped at sl_cap_pips from entry.
      double sl = piv - PipPriceDistance(strategy_prox_pips);
      const double sl_cap_dist = PipPriceDistance(strategy_sl_cap_pips);
      const double min_sl = entry - sl_cap_dist;
      if(sl < min_sl)
         sl = min_sl;
      if(sl >= entry)
         return false;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);

      // TP: next pivot above the triggering level; fallback = RR multiple.
      double tp = NextPivotAbove(piv_idx);
      if(tp <= entry)
         tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr_fallback);
      if(tp <= entry)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, tp);

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "pivot9_macd_long";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // cross_down -> SHORT
   // SHORT: H1 momentum negative (aligned down).
   if(!(h1hist < 0.0))
      return false;

   // Proximity STATE: Close[1] within tol of a RESISTANCE pivot.
   int piv_idx = -1;
   const double piv = NearestResistanceWithin(close1, tol, piv_idx);
   if(piv_idx < 0 || piv <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // SL: prox_pips above the triggering pivot, capped at sl_cap_pips from entry.
   double sl = piv + PipPriceDistance(strategy_prox_pips);
   const double sl_cap_dist = PipPriceDistance(strategy_sl_cap_pips);
   const double max_sl = entry + sl_cap_dist;
   if(sl > max_sl)
      sl = max_sl;
   if(sl <= entry)
      return false;
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   // TP: next pivot below the triggering level; fallback = RR multiple.
   double tp = NextPivotBelow(piv_idx);
   if(tp <= 0.0 || tp >= entry)
      tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr_fallback);
   if(tp <= 0.0 || tp >= entry)
      return false;
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "pivot9_macd_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active SL/TP modification; the fixed stop/target plus the EMA-trail exit
// (Strategy_ExitSignal) manage the position.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive trail exit: M5 close crosses EMA(trail) AGAINST the open position.
// One event at shift 1. Long exits on a downward close-vs-EMA cross; short on an
// upward cross.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_now  = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_trail_period, 1);
   const double ema_prev = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_trail_period, 2);
   if(ema_now <= 0.0 || ema_prev <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, PERIOD_M5, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // Determine the direction of the open position for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      break;
     }

   // Close[2] vs EMA[2] -> Close[1] vs EMA[1] : one fresh cross event.
   const bool crossed_below = (close2 >= ema_prev && close1 < ema_now);
   const bool crossed_above = (close2 <= ema_prev && close1 > ema_now);

   if(is_long  && crossed_below) return true;
   if(is_short && crossed_above) return true;
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

   // Advance the closed-bar pivot STATES once per new M5 bar.
   AdvancePivots_OnNewBar();

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
