#property strict
#property version   "5.0"
#property description "QM5_11379 144lwma-5smma-cross-m5 — SMMA(5)x LWMA(144) cross + 10-pip proximity, fractal SL, 2R TP (M5 FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11379 144lwma-5smma-cross-m5
// -----------------------------------------------------------------------------
// Source: "144 Trend Shift Scalping Forex Trading Strategy" (anonymous,
// forexmt4indicators.com / local PDF archive).
// Card: artifacts/cards_approved/QM5_11379_144lwma-5smma-cross-m5.md (g0 APPROVED).
//
// Mechanics (closed-bar reads, shift 1 = last closed bar):
//   Long-term trend anchor : LWMA(144) on PRICE_CLOSE.
//   Trigger EVENT (ONE)    : SMMA(5) crosses LWMA(144). One fresh cross per bar
//                            (state @shift2 vs state @shift1). LONG = cross up,
//                            SHORT = cross down. Avoids the two-cross-same-bar
//                            zero-trade trap — the cross is the ONLY event; the
//                            proximity check is a STATE on the same closed bar.
//   Proximity STATE        : |close[1] - LWMA144[1]| <= proximity_pips. Only
//                            enter when price is still hugging the LWMA at the
//                            cross (avoids late, over-extended entries).
//   Stop                   : most-recent Williams fractal on the opposite side
//                            within fractal_lookback closed bars (LONG = down
//                            fractal Low; SHORT = up fractal High). Capped at
//                            sl_cap_pips. Skip the trade if the fractal sits
//                            further than fractal_max_pips from entry.
//   Take profit            : 2R (tp_rr) of the realised stop distance.
//   Spread guard           : fail-OPEN on .DWX zero modeled spread; only a
//                            genuinely wide spread > spread_cap_pips blocks.
//   Position rule          : one open position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11379;
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
input int    strategy_smma_period       = 5;     // fast SMMA (trigger MA)
input int    strategy_lwma_period       = 144;   // slow LWMA (trend anchor)
input int    strategy_proximity_pips    = 10;    // max |close - LWMA144| at the cross bar
input int    strategy_fractal_lookback  = 10;    // bars to scan back for the most recent fractal
input int    strategy_fractal_wing      = 2;     // bars each side that define a Williams fractal
input int    strategy_sl_cap_pips       = 20;    // hard cap on the fractal stop distance (card P2 cap)
input int    strategy_fractal_max_pips  = 15;    // skip if the fractal SL is wider than this
input double strategy_tp_rr             = 2.0;   // take profit = tp_rr * stop distance
input int    strategy_spread_cap_pips   = 15;    // skip only a genuinely wide spread

// -----------------------------------------------------------------------------
// Helpers (closed-bar structural math; bounded loops gated to the new-bar path)
// -----------------------------------------------------------------------------

// Most-recent DOWN fractal Low (a bar whose Low is strictly the lowest within
// +/- wing bars). Scans the closed-bar window [start_shift .. start_shift+lb-1].
// Returns the fractal Low price, or 0.0 if none found.
// perf-allowed: bounded structural scan, only reached on the closed-bar entry path.
double FindDownFractalLow(const int lb, const int wing)
  {
   for(int center = 1 + wing; center <= lb + wing; ++center)
     {
      const double low_c = iLow(_Symbol, _Period, center); // perf-allowed: structural read
      if(low_c <= 0.0)
         continue;
      bool is_fractal = true;
      for(int k = 1; k <= wing && is_fractal; ++k)
        {
         const double low_l = iLow(_Symbol, _Period, center + k); // older side
         const double low_r = iLow(_Symbol, _Period, center - k); // newer side
         if(low_l <= 0.0 || low_r <= 0.0) { is_fractal = false; break; }
         if(!(low_c < low_l && low_c < low_r))
            is_fractal = false;
        }
      if(is_fractal)
         return low_c;
     }
   return 0.0;
  }

// Most-recent UP fractal High (a bar whose High is strictly the highest within
// +/- wing bars). Returns the fractal High price, or 0.0 if none found.
// perf-allowed: bounded structural scan, only reached on the closed-bar entry path.
double FindUpFractalHigh(const int lb, const int wing)
  {
   for(int center = 1 + wing; center <= lb + wing; ++center)
     {
      const double high_c = iHigh(_Symbol, _Period, center); // perf-allowed: structural read
      if(high_c <= 0.0)
         continue;
      bool is_fractal = true;
      for(int k = 1; k <= wing && is_fractal; ++k)
        {
         const double high_l = iHigh(_Symbol, _Period, center + k);
         const double high_r = iHigh(_Symbol, _Period, center - k);
         if(high_l <= 0.0 || high_r <= 0.0) { is_fractal = false; break; }
         if(!(high_c > high_l && high_c > high_r))
            is_fractal = false;
        }
      if(is_fractal)
         return high_c;
     }
   return 0.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing quote

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(cap > 0.0 && spread > 0.0 && spread > cap)
      return true;
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend anchor + trigger MA at the two most recent closed bars ---
   const double lwma_1 = QM_LWMA(_Symbol, _Period, strategy_lwma_period, 1);
   const double lwma_2 = QM_LWMA(_Symbol, _Period, strategy_lwma_period, 2);
   const double smma_1 = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1);
   const double smma_2 = QM_SMMA(_Symbol, _Period, strategy_smma_period, 2);
   if(lwma_1 <= 0.0 || lwma_2 <= 0.0 || smma_1 <= 0.0 || smma_2 <= 0.0)
      return false;

   // --- Trigger EVENT: the SMMA/LWMA cross (the ONLY event) ---
   const bool cross_up   = (smma_2 <= lwma_2 && smma_1 >  lwma_1);
   const bool cross_down = (smma_2 >= lwma_2 && smma_1 <  lwma_1);
   if(!cross_up && !cross_down)
      return false;

   // --- Proximity STATE: price still hugging the LWMA at the cross bar ---
   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close_1 <= 0.0)
      return false;
   const double prox = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_proximity_pips);
   if(prox <= 0.0)
      return false;
   if(MathAbs(close_1 - lwma_1) > prox)
      return false;

   const double sl_cap     = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double sl_max     = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fractal_max_pips);
   const QM_OrderType side = cross_up ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: most-recent opposite-side fractal, capped + range-filtered ---
   double sl = 0.0;
   if(side == QM_BUY)
     {
      const double frac_low = FindDownFractalLow(strategy_fractal_lookback, strategy_fractal_wing);
      if(frac_low <= 0.0 || frac_low >= entry)
         return false;                                   // no valid fractal below entry
      double sl_dist = entry - frac_low;
      if(sl_max > 0.0 && sl_dist > sl_max)
         return false;                                   // fractal too far → excessive risk, skip
      if(sl_cap > 0.0 && sl_dist > sl_cap)
         sl_dist = sl_cap;                               // P2 hard cap on SL distance
      sl = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist);
     }
   else
     {
      const double frac_high = FindUpFractalHigh(strategy_fractal_lookback, strategy_fractal_wing);
      if(frac_high <= 0.0 || frac_high <= entry)
         return false;                                   // no valid fractal above entry
      double sl_dist = frac_high - entry;
      if(sl_max > 0.0 && sl_dist > sl_max)
         return false;
      if(sl_cap > 0.0 && sl_dist > sl_cap)
         sl_dist = sl_cap;
      sl = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist);
     }
   if(sl <= 0.0)
      return false;

   // --- Take profit: 2R of the realised stop distance ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "lwma144_smma5_cross_long" : "lwma144_smma5_cross_short";
   return true;
  }

// Fixed fractal stop / 2R target only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// SL/TP handle the exit; no discretionary exit signal.
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
