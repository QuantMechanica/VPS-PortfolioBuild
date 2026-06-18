#property strict
#property version   "5.0"
#property description "QM5_11790 carter-h1-s5-smma55-wpr-stoch-h1 — SMMA55 channel CROSS trigger + WPR(55) & Stochastic confirm (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11790 carter-h1-s5-smma55-wpr-stoch-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Strategy #5", in "20 Forex Trading Strategies
//   (1 Hour Time Frame)", 2014. Card:
//   artifacts/cards_approved/QM5_11790_carter-h1-s5-smma55-wpr-stoch-h1.md
//   (g0_status APPROVED).
//
// Confluence system (closed-bar reads; H1). Per THIS card the SMMA channel
// CLOSE-CROSS is the single trigger EVENT (card body Entry step 1), while
// Williams %R and the Stochastic %K-vs-%D relationship are confirming STATES.
// This differs from sibling QM5_11473 (which uses the Stoch cross as the event)
// and follows the literal mechanic of QM5_11790 — exactly ONE fresh cross event
// to avoid the two-cross-same-bar zero-trade trap.
//
//   Trigger EVENT : Close crosses the SMMA(period) channel boundary.
//                   LONG  : Close[2] <= SMMA_HIGH[2] AND Close[1] > SMMA_HIGH[1].
//                   SHORT : Close[2] >= SMMA_LOW[2]  AND Close[1] < SMMA_LOW[1].
//                   (SMMA on bar HIGH = upper band, on bar LOW = lower band.)
//   WPR STATE     : Williams %R(period) confirms momentum (closed bar shift 1).
//                   LONG  : WPR[1] > wpr_long_thresh  (not oversold, e.g. > -25).
//                   SHORT : WPR[1] < wpr_short_thresh (e.g. < -75).
//                   No QM Williams %R helper exists -> computed from bounded
//                   closed-bar high/low/close. Range [-100, 0].
//   STOCH STATE   : Stochastic %K vs %D signal line (closed bar shift 1).
//                   LONG  : %K[1] > %D[1].   SHORT : %K[1] < %D[1].
//   Stop          : opposite SMMA channel boundary
//                   (LONG -> SMMA_LOW[1], SHORT -> SMMA_HIGH[1]),
//                   capped at sl_cap_pips. If channel width > cap, skip.
//   Take profit   : fixed tp_pips (card: 2x SL distance; flat-pip default here).
//   Exit          : Close re-crosses back through the entry-side channel
//                   (LONG closes if Close[1] < SMMA_HIGH, SHORT if Close[1] > SMMA_LOW).
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11790;
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
input int    strategy_smma_period        = 55;     // SMMA channel period (Fibonacci 55)
input int    strategy_wpr_period         = 55;     // Williams %R lookback period
input double strategy_wpr_long_thresh    = -25.0;  // LONG: WPR[1] must be above this (not oversold)
input double strategy_wpr_short_thresh   = -75.0;  // SHORT: WPR[1] must be below this
input int    strategy_stoch_k_period     = 5;      // Stochastic %K period
input int    strategy_stoch_d_period     = 5;      // Stochastic %D period
input int    strategy_stoch_slowing      = 5;      // Stochastic slowing
input double strategy_tp_pips            = 60.0;   // fixed take-profit distance in pips
input double strategy_sl_cap_pips        = 80.0;   // skip if channel-width stop > this many pips
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Williams %R over `period` ending at bar `shift` (closed bar).
// %R = -100 * (HighestHigh - Close[shift]) / (HighestHigh - LowestLow).
// Range [-100, 0]; 0 = at the high (overbought), -100 = at the low (oversold).
// Returns a sentinel of +1.0 (out of valid range) when data is unavailable.
double WPR_Closed(const int period, const int shift)
  {
   if(period < 1)
      return 1.0;
   const int hh_idx = iHighest(_Symbol, _Period, MODE_HIGH, period, shift);
   const int ll_idx = iLowest(_Symbol, _Period, MODE_LOW,  period, shift);
   if(hh_idx < 0 || ll_idx < 0)
      return 1.0;
   const double hh = iHigh(_Symbol, _Period, hh_idx);   // perf-allowed: bespoke WPR, gated by QM_IsNewBar
   const double ll = iLow(_Symbol, _Period, ll_idx);    // perf-allowed
   const double cl = iClose(_Symbol, _Period, shift);   // perf-allowed
   if(hh <= 0.0 || ll <= 0.0 || cl <= 0.0)
      return 1.0;
   const double range = hh - ll;
   if(range <= 0.0)
      return 0.0; // flat window — treat as top of range (no momentum bias)
   return -100.0 * (hh - cl) / range;
  }

// Pip size for the symbol (10 points on 3/5-digit, 1 point otherwise).
double PipSize()
  {
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long   digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
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
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero modeled spread on .DWX — never block on it

   // Reference stop distance = SMMA channel cap proxy, in price.
   const double stop_distance = strategy_sl_cap_pips * PipSize();
   if(stop_distance <= 0.0)
      return false;

   // Only a genuinely wide spread blocks.
   if(spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Confluence entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Channel STATE: SMMA on HIGH (upper) and SMMA on LOW (lower) ---
   // Read at shift 1 (just-closed bar) and shift 2 (prior bar) for the cross.
   const double smma_high_1 = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_HIGH);
   const double smma_low_1  = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_LOW);
   const double smma_high_2 = QM_SMMA(_Symbol, _Period, strategy_smma_period, 2, PRICE_HIGH);
   const double smma_low_2  = QM_SMMA(_Symbol, _Period, strategy_smma_period, 2, PRICE_LOW);
   if(smma_high_1 <= 0.0 || smma_low_1 <= 0.0 || smma_high_1 <= smma_low_1)
      return false;
   if(smma_high_2 <= 0.0 || smma_low_2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Trigger EVENT: Close crosses an SMMA channel boundary (single fresh event) ---
   const bool cross_up_high   = (close2 <= smma_high_2 && close1 > smma_high_1);
   const bool cross_down_low  = (close2 >= smma_low_2  && close1 < smma_low_1);

   // --- Williams %R STATE ---
   const double wpr = WPR_Closed(strategy_wpr_period, 1);
   if(wpr > 0.0)        // sentinel = data unavailable
      return false;

   // --- Stochastic %K vs %D STATE (signal-line side) ---
   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(k1 <= 0.0 || d1 <= 0.0)
      return false;

   const double tp_dist  = strategy_tp_pips * PipSize();
   const double cap_dist = strategy_sl_cap_pips * PipSize();
   if(tp_dist <= 0.0 || cap_dist <= 0.0)
      return false;

   // --- LONG: fresh close-cross above upper band + WPR not oversold + %K > %D
   if(cross_up_high &&
      wpr > strategy_wpr_long_thresh &&
      k1 > d1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Stop at opposite (lower) channel; reject if wider than the pip cap.
      double sl = QM_TM_NormalizePrice(_Symbol, smma_low_1);
      if(sl <= 0.0 || sl >= entry)
         return false;
      if((entry - sl) > cap_dist)
         return false; // channel too wide — skip per cap
      const double tp = QM_TM_NormalizePrice(_Symbol, entry + tp_dist);
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "smma_cross_wpr_stoch_long";
      return true;
     }

   // --- SHORT: fresh close-cross below lower band + WPR deep + %K < %D
   if(cross_down_low &&
      wpr < strategy_wpr_short_thresh &&
      k1 < d1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = QM_TM_NormalizePrice(_Symbol, smma_high_1);
      if(sl <= 0.0 || sl <= entry)
         return false;
      if((sl - entry) > cap_dist)
         return false;
      const double tp = QM_TM_NormalizePrice(_Symbol, entry - tp_dist);
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "smma_cross_wpr_stoch_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed channel stop / fixed TP. The
// channel re-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Channel re-cross exit: LONG closes if Close[1] falls back below SMMA_HIGH;
// SHORT closes if Close[1] rises back above SMMA_LOW. One closed-bar read.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double smma_high = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_HIGH);
   const double smma_low  = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1, PRICE_LOW);
   if(smma_high <= 0.0 || smma_low <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Determine current position direction for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
     }

   if(is_long && close1 < smma_high)
      return true;
   if(is_short && close1 > smma_low)
      return true;
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
