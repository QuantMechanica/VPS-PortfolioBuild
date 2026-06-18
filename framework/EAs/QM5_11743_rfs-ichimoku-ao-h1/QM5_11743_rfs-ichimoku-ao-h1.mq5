#property strict
#property version   "5.0"
#property description "QM5_11743 rfs-ichimoku-ao-h1 — Ichimoku Senkou B break + Awesome Oscillator confirmation (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11743 rfs-ichimoku-ao-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "Ichimoku + Awesome Oscillator", Robo-forex Strategy
//   Compilation (robofx.com, ~2015), pages 57-58. source_id b5a932a2-...
// Card: artifacts/cards_approved/QM5_11743_rfs-ichimoku-ao-h1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1). Sibling of QM5_11574, but THIS
// card defines the AO leg as a directional STATE (green & above zero), not a
// zero-line cross. To honour the card literally while avoiding the
// two-cross-same-bar zero-trade trap, the SINGLE fresh trigger EVENT is the
// price/cloud break of Senkou Span B; the Awesome Oscillator legs are confirming
// STATES:
//
//   Trigger EVENT (single, one per bar): closed-bar close crosses the Ichimoku
//     Senkou Span B line.
//       LONG  : close[2] <= SenkouB  AND  close[1] > SenkouB   (fresh break up)
//       SHORT : close[2] >= SenkouB  AND  close[1] < SenkouB   (fresh break down)
//     Senkou Span B is displaced +kijun bars forward in the buffer, so the cloud
//     value aligned to the LAST CLOSED bar (shift 1) is read at shift (1+kijun),
//     and the value aligned to shift 2 is read at shift (2+kijun).
//
//   Confirming STATE — Awesome Oscillator = SMA(median,5) - SMA(median,34):
//       LONG  : AO[1] > 0 (above zero)  AND  AO[1] > AO[2] (green / rising)
//       SHORT : AO[1] < 0 (below zero)  AND  AO[1] < AO[2] (red / falling)
//
//   Because the cloud break is the EVENT and the AO legs are STATES, exactly one
//   fresh trigger can fire per bar; the one-position-per-magic guard then blocks
//   re-entry while the trade is live.
//
//   Stop : structural swing beyond the recent lookback (QM_StopStructure) pushed
//          a small pip buffer further out (card: "5 pips beyond nearest swing").
//   Take : RR multiple of the stop distance (card baseline = 1:1 RR).
//   Spread guard: skip only a genuinely wide spread; fail-open on .DWX zero spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11743;
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
input int    strategy_ichi_tenkan       = 9;     // Ichimoku Tenkan period
input int    strategy_ichi_kijun        = 26;    // Ichimoku Kijun period (also cloud displacement)
input int    strategy_ichi_senkou       = 52;    // Ichimoku Senkou Span B period
input int    strategy_ao_fast           = 5;     // Awesome Oscillator fast SMA (median price)
input int    strategy_ao_slow           = 34;    // Awesome Oscillator slow SMA (median price)
input int    strategy_swing_lookback    = 20;    // bars to scan for the structural swing stop
input double strategy_sl_buffer_pips    = 5.0;   // extra pips beyond the swing ("5 pips")
input double strategy_tp_rr             = 1.0;   // take-profit as RR multiple of stop distance
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Awesome Oscillator helper: SMA(median,fast) - SMA(median,slow) at a shift.
// Median price = (High + Low) / 2  (PRICE_MEDIAN). Handle-pooled via QM_SMA.
// -----------------------------------------------------------------------------
double AO_Value(const int shift)
  {
   const double fast = QM_SMA(_Symbol, _Period, strategy_ao_fast, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, _Period, strategy_ao_slow, shift, PRICE_MEDIAN);
   return fast - slow;
  }

// Senkou Span B value aligned to a given closed-bar shift. The Ichimoku buffer
// stores Senkou B displaced +kijun forward, so the cloud level under bar `shift`
// is read at buffer shift (shift + kijun).
double SenkouB_AlignedTo(const int bar_shift)
  {
   return QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                  strategy_ichi_tenkan,
                                  strategy_ichi_kijun,
                                  strategy_ichi_senkou,
                                  bar_shift + strategy_ichi_kijun);
  }

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

// Cloud-break reversal entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar closes for the cloud-break EVENT (shift 1 = last closed) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Senkou Span B aligned to bars 1 and 2 ---
   const double senkou1 = SenkouB_AlignedTo(1);
   const double senkou2 = SenkouB_AlignedTo(2);
   if(senkou1 <= 0.0 || senkou2 <= 0.0)
      return false;

   // Trigger EVENT: a FRESH break of the Senkou B line on the last closed bar.
   const bool break_up   = (close2 <= senkou2 && close1 > senkou1);
   const bool break_down = (close2 >= senkou2 && close1 < senkou1);
   if(!break_up && !break_down)
      return false;

   // --- Confirming STATE: Awesome Oscillator sign + direction ---
   const double ao1 = AO_Value(1);
   const double ao2 = AO_Value(2);

   const bool ao_long_ok  = (ao1 > 0.0 && ao1 > ao2); // above zero AND rising (green)
   const bool ao_short_ok = (ao1 < 0.0 && ao1 < ao2); // below zero AND falling (red)

   QM_OrderType side;
   string reason;
   if(break_up && ao_long_ok)
     {
      side   = QM_BUY;
      reason = "rfs_ichi_ao_long";
     }
   else if(break_down && ao_short_ok)
     {
      side   = QM_SELL;
      reason = "rfs_ichi_ao_short";
     }
   else
      return false;

   // --- Entry price (market) ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Structural swing stop at the recent low/high (sits on the swing;
   //     QM_StopStructure has no buffer param) ---
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   if(sl <= 0.0)
      return false;

   // Push the stop the card's small buffer ("5 pips") BEYOND the swing:
   // lower for a long, higher for a short. Buffer distance is pip-scale-correct.
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

   // --- Take profit = RR multiple of the stop distance (card: 1:1) ---
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

// No discretionary exit; the fixed SL/TP carry the position.
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
