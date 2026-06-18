#property strict
#property version   "5.0"
#property description "QM5_1272 camarilla-weekly-pivots-swing — Weekly Camarilla outer-pivot swing fade + breakout (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1272 camarilla-weekly-pivots-swing
// -----------------------------------------------------------------------------
// Source: ForexFactory Trading Systems forum — Camarilla Equation cluster
//   (Stott lineage). Card: artifacts/cards_approved/QM5_1272_camarilla-weekly-
//   pivots-swing.md (g0_status APPROVED).
//
// Mechanics (H4 execution, weekly Camarilla pivots, closed-bar reads):
//   Weekly pivots STATE: from the PRIOR closed W1 bar (shift 1) read H/L/C.
//     range = H - L
//     H3 = C + range*1.1/4 ; H4 = C + range*1.1/2
//     L3 = C - range*1.1/4 ; L4 = C - range*1.1/2
//     P  = (H + L + C) / 3                 (weekly pivot = Mode-A target)
//   The L3/L4 (and mirrored H3/H4) zone is the decision GATE. We model ONE
//   event: the position of the just-CLOSED H4 bar (shift 1) relative to the
//   outer pivots. The close is either above or below L4 — the two modes are
//   mutually exclusive by construction, so there is no two-cross-same-bar trap.
//
//   LOWER zone (L3/L4):
//     Mode A LONG  FADE  : close1 <= L3 AND close1 >  L4  -> long at next open.
//                          TP = weekly P. SL = L4 (floored by ATR*1.5).
//     Mode B SHORT BREAK : close1 <  L4                   -> short at next open.
//                          TP = L4 - 2*(L3-L4)=projected L5. SL=L3 (ATR floor).
//   UPPER zone (H3/H4) mirrors:
//     Mode A SHORT FADE  : close1 >= H3 AND close1 <  H4  -> short at next open.
//                          TP = weekly P. SL = H4 (ATR floor).
//     Mode B LONG  BREAK : close1 >  H4                   -> long at next open.
//                          TP = H4 + 2*(H4-H3)=projected H5. SL=H3 (ATR floor).
//
//   Exit (in addition to SL/TP):
//     - Friday time-stop: close at/after Friday `friday_stop_hour` broker-time
//       (avoid weekend gap). Handled in Strategy_ExitSignal.
//     - Opposite outer pivot hit before TP = trend invalidation -> close.
//
//   Filters:
//     - Spread cap (fail-open on .DWX zero modeled spread).
//     - No trade in the first `warmup_h4_bars` H4 bars of a new week (let the
//       weekly pivots stabilise; avoid Sunday liquidity gap).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1272;
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
// Camarilla constants are the canonical Stott equation set — NOT inputs.
// (H3 = 1.1/4, H4 = 1.1/2 of the prior-week range about the prior-week close.)
input int    strategy_atr_period        = 14;    // ATR(14) on H4 for the SL floor
input double strategy_sl_atr_floor_mult = 1.5;   // min SL distance = ATR * mult
input int    strategy_warmup_h4_bars    = 2;     // skip first N H4 bars of the week
input double strategy_spread_pct_of_stop = 20.0; // skip if spread > this % of stop distance
input int    strategy_friday_stop_hour  = 20;    // broker-time Friday flat-by hour

// -----------------------------------------------------------------------------
// File-scope cached weekly-pivot state (advanced once per closed H4 bar).
// -----------------------------------------------------------------------------
datetime g_week_anchor   = 0;     // open-time of the W1 bar the pivots belong to
int      g_h4_bars_in_wk = 0;     // count of closed H4 bars since the week rolled
bool     g_pivots_valid  = false;
double   g_H3 = 0.0, g_H4 = 0.0, g_L3 = 0.0, g_L4 = 0.0, g_P = 0.0;

// Recompute the weekly Camarilla pivots from the prior closed W1 bar, and
// track how many H4 bars have closed since the current week opened. Called
// once per new closed H4 bar (post QM_IsNewBar gate). No per-tick history.
void AdvanceState_OnNewBar()
  {
   // perf-allowed: bounded single-bar reads of the prior closed weekly bar.
   const double wk_h = iHigh(_Symbol, PERIOD_W1, 1);
   const double wk_l = iLow(_Symbol,  PERIOD_W1, 1);
   const double wk_c = iClose(_Symbol, PERIOD_W1, 1);
   const datetime wk_open = iTime(_Symbol, PERIOD_W1, 0); // current week's open time

   if(wk_h > 0.0 && wk_l > 0.0 && wk_c > 0.0 && wk_h > wk_l)
     {
      const double range = wk_h - wk_l;
      g_H3 = wk_c + range * 1.1 / 4.0;
      g_H4 = wk_c + range * 1.1 / 2.0;
      g_L3 = wk_c - range * 1.1 / 4.0;
      g_L4 = wk_c - range * 1.1 / 2.0;
      g_P  = (wk_h + wk_l + wk_c) / 3.0;
      g_pivots_valid = true;
     }
   else
     {
      g_pivots_valid = false;
     }

   // Reset the within-week H4 bar counter when the W1 bar rolls.
   if(wk_open != g_week_anchor)
     {
      g_week_anchor   = wk_open;
      g_h4_bars_in_wk = 0;
     }
   g_h4_bars_in_wk++;   // this closed H4 bar counts toward the new week
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to the entry gate

   const double stop_distance = strategy_sl_atr_floor_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Weekly Camarilla outer-pivot entry. Caller guarantees QM_IsNewBar()==true.
// Reads the just-closed H4 bar (shift 1) position vs the cached weekly pivots.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_pivots_valid)
      return false;

   // Let the weekly pivots stabilise: skip the first N H4 bars of the week.
   if(g_h4_bars_in_wk <= strategy_warmup_h4_bars)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double sl_floor = strategy_sl_atr_floor_mult * atr_value; // min SL distance

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;
   const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_bid <= 0.0)
      return false;

   // ----- LOWER zone (L3 / L4): the close1 is either above L4 (fade) or below
   //       it (break). Mutually exclusive by construction — one decision. -----
   if(close1 <= g_L3)
     {
      if(close1 > g_L4)
        {
         // Mode A — LONG fade at L3. TP = weekly P. SL = L4 (ATR-floored).
         double sl = g_L4;
         if(entry - sl < sl_floor)
            sl = entry - sl_floor;
         const double tp = g_P;
         if(!(tp > entry) || !(sl < entry))
            return false; // geometry invalid (e.g. P already below price) — skip
         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "camarilla_wk_modeA_long_fade_L3";
         return true;
        }
      else
        {
         // Mode B — SHORT break below L4. TP = projected L5 = L4 - 2*(L3-L4).
         double sl = g_L3;
         if(sl - entry_bid < sl_floor)
            sl = entry_bid + sl_floor;
         const double tp = g_L4 - 2.0 * (g_L3 - g_L4); // = 3*L4 - 2*L3
         if(!(tp < entry_bid) || !(sl > entry_bid))
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "camarilla_wk_modeB_short_break_L4";
         return true;
        }
     }

   // ----- UPPER zone (H3 / H4): mirror. -----
   if(close1 >= g_H3)
     {
      if(close1 < g_H4)
        {
         // Mode A — SHORT fade at H3. TP = weekly P. SL = H4 (ATR-floored).
         double sl = g_H4;
         if(sl - entry_bid < sl_floor)
            sl = entry_bid + sl_floor;
         const double tp = g_P;
         if(!(tp < entry_bid) || !(sl > entry_bid))
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "camarilla_wk_modeA_short_fade_H3";
         return true;
        }
      else
        {
         // Mode B — LONG break above H4. TP = projected H5 = H4 + 2*(H4-H3).
         double sl = g_H3;
         if(entry - sl < sl_floor)
            sl = entry - sl_floor;
         const double tp = g_H4 + 2.0 * (g_H4 - g_H3); // = 3*H4 - 2*H3
         if(!(tp > entry) || !(sl < entry))
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "camarilla_wk_modeB_long_break_H4";
         return true;
        }
     }

   return false;
  }

// No active SL/TP modification; the fixed pivot stop/target manage the trade.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits separate from SL/TP:
//   1) Friday time-stop: flat at/after Friday `friday_stop_hour` broker-time.
//   2) Opposite-side outer pivot hit before TP = trend invalidation.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // --- Friday time-stop (broker time). Avoid weekend gap risk. ---
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_stop_hour) // 5 = Friday
      return true;

   // --- Opposite outer pivot hit before TP (trend invalidation). ---
   if(!g_pivots_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         // Long invalidated if price breaks the lower outer pivot L4.
         if(bid <= g_L4)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         // Short invalidated if price breaks the upper outer pivot H4.
         if(ask >= g_H4)
            return true;
        }
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

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
