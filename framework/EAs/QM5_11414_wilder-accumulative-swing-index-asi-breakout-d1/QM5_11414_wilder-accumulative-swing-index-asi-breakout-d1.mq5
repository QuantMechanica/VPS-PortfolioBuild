#property strict
#property version   "5.0"
#property description "QM5_11414 wilder-asi-breakout — Accumulative Swing Index level break (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11414 wilder-accumulative-swing-index-asi-breakout-d1
// -----------------------------------------------------------------------------
// Source: J. Welles Wilder Jr., "New Concepts in Technical Trading Systems"
//         (Trend Research, 1978), Section VIII — Swing Index System.
// Card: artifacts/cards_approved/QM5_11414_wilder-accumulative-swing-index-asi-breakout-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads; ASI computed deterministically from OHLC):
//   Swing Index (SI) per Wilder, subscript 2 = current bar, 1 = prior bar:
//     N = (C2-C1) + 0.5*(C2-O2) + 0.25*(C1-O1)
//     K = max(|H2-C1|, |L2-C1|)
//     R = trueRange-style term chosen by which of |H2-C1|,|L2-C1|,(H2-L2) is largest
//     SI = 50 * (N/R) * (K/L)
//     L  = limit-move proxy = ATR(atr_period) * limit_mult  (computed once/day)
//   ASI = running cumulative sum of SI (advanced one step per closed bar, cached).
//
//   Swing points on the ASI series (1 bar each side):
//     HSP: ASI[i] > ASI[i-1] AND ASI[i] > ASI[i+1]  (local max) -> HIP = bar High[i]
//     LSP: ASI[i] < ASI[i-1] AND ASI[i] < ASI[i+1]  (local min) -> LOP = bar Low[i]
//
//   Entry EVENT (the single signal = the ASI level break, confirmed on close):
//     LONG : ASI[1] crosses above the most-recent prior HSP ASI value
//            (ASI[2] <= HSP_asi  AND  ASI[1] > HSP_asi). Market entry.
//     SHORT: ASI[1] crosses below the most-recent prior LSP ASI value
//            (ASI[2] >= LSP_asi  AND  ASI[1] < LSP_asi). Market entry.
//   Stop (INDEX SAR, structural leg): LONG -> most-recent LSP's LOP price;
//     SHORT -> most-recent HSP's HIP price; capped at sl_cap_pips.
//   Take profit: RR multiple of the realised stop distance.
//   Defensive exit: opposite ASI level break closes the position.
//   Spread guard: fail-OPEN on .DWX zero modeled spread; block only a wide spread.
//
// NO external feed. ASI is pure arithmetic on closed OHLC bars. Raw iOpen/iHigh/
// iLow/iClose reads are bespoke structural math (perf-allowed) and run ONCE per
// new closed bar inside AdvanceState_OnNewBar, cached into file-scope state.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11414;
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
input int    strategy_atr_period        = 14;     // ATR period for the limit-move (L) proxy
input double strategy_limit_mult        = 5.0;    // L = ATR * mult  (P3 sweep: 3/5/7)
input int    strategy_asi_window        = 120;    // closed bars over which ASI is accumulated/scanned
input int    strategy_swing_span        = 1;      // bars each side for HSP/LSP pivots (P3 sweep: 1/2/3)
input int    strategy_sl_cap_pips       = 100;    // max stop distance (card P2 cap = 100 pips)
input double strategy_tp_rr             = 2.0;    // take-profit = RR * stop distance
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached strategy state (advanced once per closed bar).
// -----------------------------------------------------------------------------
double g_asi_curr      = 0.0;    // ASI value at shift 1 (latest closed bar)
double g_asi_prev      = 0.0;    // ASI value at shift 2
double g_hsp_asi       = 0.0;    // most-recent confirmed HSP ASI value (prior to shift 1)
double g_hsp_hip       = 0.0;    // price High of the HSP bar
bool   g_hsp_valid     = false;
double g_lsp_asi       = 0.0;    // most-recent confirmed LSP ASI value (prior to shift 1)
double g_lsp_lop       = 0.0;    // price Low of the LSP bar
bool   g_lsp_valid     = false;
bool   g_state_ready   = false;

// Compute one SI value for current bar c (subscript 2) vs prior bar p (subscript 1).
double ComputeSI(const double o2, const double h2, const double l2, const double c2,
                 const double o1, const double c1, const double limit_L)
  {
   if(limit_L <= 0.0)
      return 0.0;

   const double move_hc = MathAbs(h2 - c1);
   const double move_lc = MathAbs(l2 - c1);
   const double range_hl = h2 - l2;

   // R selection per Wilder: based on which of the three terms is largest.
   double R = 0.0;
   if(move_hc >= move_lc && move_hc >= range_hl)
      R = (h2 - c1) - 0.5 * (l2 - c1) + 0.25 * (c1 - o1);
   else if(move_lc >= move_hc && move_lc >= range_hl)
      R = (l2 - c1) - 0.5 * (h2 - c1) + 0.25 * (c1 - o1);
   else
      R = (h2 - l2) + 0.25 * (c1 - o1);

   if(MathAbs(R) <= 0.0)
      return 0.0;

   const double K = MathMax(move_hc, move_lc);
   const double N = (c2 - c1) + 0.5 * (c2 - o2) + 0.25 * (c1 - o1);

   double si = 50.0 * (N / R) * (K / limit_L);
   if(si >  100.0) si =  100.0;
   if(si < -100.0) si = -100.0;
   return si;
  }

// Advance ASI + swing-point state. Called ONCE per new closed bar (no second
// timestamp gate inside). Recomputes the bounded ASI window and the most-recent
// confirmed HSP/LSP that PRECEDE the latest closed bar (shift 1).
void AdvanceState_OnNewBar()
  {
   g_state_ready = false;

   const int span = (strategy_swing_span < 1) ? 1 : strategy_swing_span;
   int win = strategy_asi_window;
   if(win < (span * 2 + 5))
      win = span * 2 + 5;

   // Need OHLC for shifts 1..win+1 (SI at shift i uses bar i and bar i+1).
   const int oldest = win + 1;
   if(Bars(_Symbol, _Period) < oldest + 2) // perf-allowed: bespoke ASI history-depth guard, once/bar
      return;

   // Limit-move proxy L = ATR * mult, one value per evaluation (closed bar).
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double limit_L = atr_value * strategy_limit_mult;
   if(limit_L <= 0.0)
      return;

   // Build ASI over the window. asi[k] corresponds to bar shift (win - k),
   // i.e. asi[win-1] = ASI at shift 1 (latest closed), asi[0] = ASI at shift win.
   // SI at shift s uses bar s (subscript 2) and bar s+1 (subscript 1).
   double asi[];
   double hip[];   // bar High at the same shift
   double lop[];   // bar Low at the same shift
   if(ArrayResize(asi, win) != win) return;
   if(ArrayResize(hip, win) != win) return;
   if(ArrayResize(lop, win) != win) return;

   double running = 0.0;
   for(int k = 0; k < win; k++)
     {
      const int s = win - k;                 // shift for this element (win .. 1)
      const double o2 = iOpen(_Symbol, _Period, s);     // perf-allowed: bespoke ASI math, once/bar
      const double h2 = iHigh(_Symbol, _Period, s);     // perf-allowed
      const double l2 = iLow(_Symbol, _Period, s);      // perf-allowed
      const double c2 = iClose(_Symbol, _Period, s);    // perf-allowed
      const double o1 = iOpen(_Symbol, _Period, s + 1); // perf-allowed
      const double c1 = iClose(_Symbol, _Period, s + 1);// perf-allowed
      if(o2 <= 0.0 || h2 <= 0.0 || l2 <= 0.0 || c2 <= 0.0 || o1 <= 0.0 || c1 <= 0.0)
         return; // history gap — defer; do not emit a half-built series

      running += ComputeSI(o2, h2, l2, c2, o1, c1, limit_L);
      asi[k] = running;
      hip[k] = h2;
      lop[k] = l2;
     }

   g_asi_curr = asi[win - 1];                 // shift 1
   g_asi_prev = (win >= 2) ? asi[win - 2] : asi[win - 1]; // shift 2

   // Most-recent confirmed HSP/LSP strictly BEFORE the latest closed bar.
   // A pivot at index i needs span neighbours each side: i in [span, win-1-span].
   // Scan from newest confirmable (win-1-span) downward; take the first match.
   g_hsp_valid = false;
   g_lsp_valid = false;
   for(int i = win - 1 - span; i >= span; i--)
     {
      if(!g_hsp_valid)
        {
         bool is_hsp = true;
         for(int d = 1; d <= span && is_hsp; d++)
            if(!(asi[i] > asi[i - d] && asi[i] > asi[i + d]))
               is_hsp = false;
         if(is_hsp)
           {
            g_hsp_asi   = asi[i];
            g_hsp_hip   = hip[i];
            g_hsp_valid = true;
           }
        }
      if(!g_lsp_valid)
        {
         bool is_lsp = true;
         for(int d = 1; d <= span && is_lsp; d++)
            if(!(asi[i] < asi[i - d] && asi[i] < asi[i + d]))
               is_lsp = false;
         if(is_lsp)
           {
            g_lsp_asi   = asi[i];
            g_lsp_lop   = lop[i];
            g_lsp_valid = true;
           }
        }
      if(g_hsp_valid && g_lsp_valid)
         break;
     }

   g_state_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * cap_distance)
      return true; // genuinely wide spread

   return false;
  }

// ASI level-break entry. Caller guarantees QM_IsNewBar() == true. Reads cached
// state advanced by AdvanceState_OnNewBar — no per-tick recompute.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_state_ready)
      return false;

   // LONG: ASI crosses above the most-recent prior HSP level (one event).
   if(g_hsp_valid && g_asi_prev <= g_hsp_asi && g_asi_curr > g_hsp_asi)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // INDEX SAR structural leg: most-recent LSP's LOP, capped at sl_cap_pips.
      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
      double sl = entry - cap_dist; // default to the cap
      if(g_lsp_valid && g_lsp_lop > 0.0 && g_lsp_lop < entry)
        {
         const double struct_sl = g_lsp_lop;
         // Use structural stop unless it is wider than the cap (then keep cap).
         if((entry - struct_sl) <= cap_dist)
            sl = struct_sl;
        }
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // market entry at send (breakout confirmed on close)
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "asi_break_long";
      return true;
     }

   // SHORT: ASI crosses below the most-recent prior LSP level (one event).
   if(g_lsp_valid && g_asi_prev >= g_lsp_asi && g_asi_curr < g_lsp_asi)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
      double sl = entry + cap_dist; // default to the cap
      if(g_hsp_valid && g_hsp_hip > entry)
        {
         const double struct_sl = g_hsp_hip;
         if((struct_sl - entry) <= cap_dist)
            sl = struct_sl;
        }
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "asi_break_short";
      return true;
     }

   return false;
  }

// Fixed structural stop + RR target; no active trailing beyond SL/TP.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: an opposite ASI level break closes the open position.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(!g_state_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      // Long is open: a downward break of the prior LSP is the opposite signal.
      if(ptype == POSITION_TYPE_BUY &&
         g_lsp_valid && g_asi_prev >= g_lsp_asi && g_asi_curr < g_lsp_asi)
         return true;
      // Short is open: an upward break of the prior HSP is the opposite signal.
      if(ptype == POSITION_TYPE_SELL &&
         g_hsp_valid && g_asi_prev <= g_hsp_asi && g_asi_curr > g_hsp_asi)
         return true;
     }
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!QM_IsNewBar())
      return;

   // FIRST work on the new closed bar: advance cached ASI + swing state.
   AdvanceState_OnNewBar();

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
