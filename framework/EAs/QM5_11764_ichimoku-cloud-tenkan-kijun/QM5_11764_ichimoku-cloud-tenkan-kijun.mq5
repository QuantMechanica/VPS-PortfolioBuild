#property strict
#property version   "5.0"
#property description "QM5_11764 ichimoku-cloud-tenkan-kijun — Ichimoku cloud trend + Tenkan/Kijun cross trigger (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11764 ichimoku-cloud-tenkan-kijun
// -----------------------------------------------------------------------------
// Source: Anonymous, "Ichimoku Cloud Forex Trading Strategy", ~2019
//   (source_id 053a19aa-386f-50a7-8a0e-1c480d243306).
// Card: artifacts/cards_approved/QM5_11764_ichimoku-cloud-tenkan-kijun.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H4):
//   Trend STATE (cloud position): the last closed bar's close is fully ABOVE the
//     Kumo (above BOTH Senkou A and Senkou B) for a long bias, or fully BELOW
//     both for a short bias. Senkou A/B are displaced +kijun bars forward in the
//     buffer, so the cloud value aligned to the closed bar (shift 1) is read at
//     shift (1 + kijun).
//   Cloud-color STATE: Senkou A > Senkou B => bullish (green) cloud (LONG side);
//     Senkou A < Senkou B => bearish (red) cloud (SHORT side). Read at the SAME
//     displaced shift as the position check.
//   Chikou-clearance STATE: the Chikou (lagging span) = the current close plotted
//     kijun bars BACK must not be intersecting the historical candle there — i.e.
//     the last closed bar's close must sit clear of the candle range kijun bars
//     before it (above the high for a long, below the low for a short). This is a
//     STATE filter, not the trigger.
//   Trigger EVENT (single): Tenkan-sen / Kijun-sen cross in the bias direction.
//     LONG  : Tenkan crossed from <=Kijun (shift 2) to >Kijun (shift 1).
//     SHORT : Tenkan crossed from >=Kijun (shift 2) to <Kijun (shift 1).
//     Exactly ONE fresh cross event per bar; the cloud position, cloud colour and
//     Chikou clearance are STATES, not second crosses — this avoids the
//     two-cross-same-bar zero-trade trap.
//   Stop : lowest-low (long) / highest-high (short) of the recent swing lookback
//     (QM_StopStructure) with a small pip buffer beyond the swing.
//   Take : RR multiple of the stop distance (card P2 baseline).
//   Defensive exit: reverse Tenkan/Kijun cross (opposite of the entry trigger).
//   Spread guard: skip only a genuinely wide spread; fail-open on .DWX zero spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11764;
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
input int    strategy_ichi_tenkan       = 9;     // Ichimoku Tenkan-sen period
input int    strategy_ichi_kijun        = 26;    // Ichimoku Kijun-sen period (also cloud displacement / Chikou lookback)
input int    strategy_ichi_senkou       = 52;    // Ichimoku Senkou Span B period
input bool   strategy_use_chikou_filter = true;  // require Chikou clear of historical candle
input int    strategy_swing_lookback    = 10;    // bars to scan for the structural swing stop (card: last 10 bars)
input double strategy_sl_buffer_pips    = 5.0;   // extra pips beyond the swing
input double strategy_tp_rr             = 2.0;   // take-profit as RR multiple of stop distance
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Reference stop distance for the spread cap: the SL buffer distance in price.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_buffer_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Returns +1 for a fresh bullish Tenkan>Kijun cross, -1 for a fresh bearish
// cross, 0 for no cross. Single event per bar (shift 2 -> shift 1).
int TenkanKijunCross()
  {
   const double t_now  = QM_Ichimoku_TenkanSen(_Symbol, _Period, strategy_ichi_tenkan,
                                               strategy_ichi_kijun, strategy_ichi_senkou, 1);
   const double k_now  = QM_Ichimoku_KijunSen(_Symbol, _Period, strategy_ichi_tenkan,
                                              strategy_ichi_kijun, strategy_ichi_senkou, 1);
   const double t_prev = QM_Ichimoku_TenkanSen(_Symbol, _Period, strategy_ichi_tenkan,
                                               strategy_ichi_kijun, strategy_ichi_senkou, 2);
   const double k_prev = QM_Ichimoku_KijunSen(_Symbol, _Period, strategy_ichi_tenkan,
                                              strategy_ichi_kijun, strategy_ichi_senkou, 2);
   if(t_now <= 0.0 || k_now <= 0.0 || t_prev <= 0.0 || k_prev <= 0.0)
      return 0;

   if(t_prev <= k_prev && t_now > k_now)
      return 1;   // fresh bullish cross
   if(t_prev >= k_prev && t_now < k_now)
      return -1;  // fresh bearish cross
   return 0;
  }

// Trend-following entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar close for the cloud-position and Chikou STATES ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Cloud STATE: Senkou A/B aligned to the last closed bar. The buffer stores
   //     the spans displaced +kijun forward, so the cloud under the closed bar
   //     (shift 1) is read at shift (1 + kijun). ---
   const int cloud_shift = 1 + strategy_ichi_kijun;
   const double span_a = QM_Ichimoku_SenkouSpanA(_Symbol, _Period, strategy_ichi_tenkan,
                                                 strategy_ichi_kijun, strategy_ichi_senkou, cloud_shift);
   const double span_b = QM_Ichimoku_SenkouSpanB(_Symbol, _Period, strategy_ichi_tenkan,
                                                 strategy_ichi_kijun, strategy_ichi_senkou, cloud_shift);
   if(span_a <= 0.0 || span_b <= 0.0)
      return false;

   const double cloud_top = MathMax(span_a, span_b);
   const double cloud_bot = MathMin(span_a, span_b);

   // Price fully above the cloud + bullish (green) cloud => long bias.
   // Price fully below the cloud + bearish (red) cloud => short bias.
   const bool bias_long  = (close1 > cloud_top && span_a > span_b);
   const bool bias_short = (close1 < cloud_bot && span_a < span_b);
   if(!bias_long && !bias_short)
      return false;

   // --- Trigger EVENT: Tenkan/Kijun cross in the bias direction (single event) ---
   const int cross = TenkanKijunCross();
   if(cross == 0)
      return false;

   QM_OrderType side;
   string reason;
   if(bias_long && cross > 0)
     {
      side   = QM_BUY;
      reason = "ichi_cloud_tk_long";
     }
   else if(bias_short && cross < 0)
     {
      side   = QM_SELL;
      reason = "ichi_cloud_tk_short";
     }
   else
      return false;

   // --- Chikou-clearance STATE: the Chikou (current close plotted kijun bars back)
   //     must sit clear of the candle range there. The last closed bar's close
   //     must be above the high (long) / below the low (short) kijun bars before
   //     it. Historical range read at shift (1 + kijun). ---
   if(strategy_use_chikou_filter)
     {
      const int chikou_shift = 1 + strategy_ichi_kijun;
      const double hist_high = iHigh(_Symbol, _Period, chikou_shift); // perf-allowed: single bar read
      const double hist_low  = iLow(_Symbol, _Period, chikou_shift);  // perf-allowed: single bar read
      if(hist_high <= 0.0 || hist_low <= 0.0)
         return false;
      if(side == QM_BUY && !(close1 > hist_high))
         return false;
      if(side == QM_SELL && !(close1 < hist_low))
         return false;
     }

   // --- Entry price (market) ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Structural swing stop at the recent low/high (lowest low / highest high
   //     of the lookback; QM_StopStructure has no buffer param) ---
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   if(sl <= 0.0)
      return false;

   // Push the stop the card's small buffer BEYOND the swing: lower for a long,
   // higher for a short. Buffer distance is pip-scale-correct.
   const double buffer_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_buffer_pips);
   if(side == QM_BUY)
      sl = QM_StopRulesNormalizePrice(_Symbol, sl - buffer_dist);
   else
      sl = QM_StopRulesNormalizePrice(_Symbol, sl + buffer_dist);
   if(sl <= 0.0)
      return false;

   // Reject a degenerate (zero/wrong-side) stop.
   const double stop_dist = MathAbs(entry - sl);
   if(stop_dist <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   // --- Take profit = RR multiple of the stop distance ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// No active trade management beyond the fixed structural stop / RR target.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: a reverse Tenkan/Kijun cross against the open position.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int cross = TenkanKijunCross();
   if(cross == 0)
      return false;

   // Close a long on a fresh bearish cross; close a short on a fresh bullish cross.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != QM_FrameworkMagic())
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cross < 0)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross > 0)
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
