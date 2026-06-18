#property strict
#property version   "5.0"
#property description "QM5_11303 tc-m5-bb-midband-retrace — BB(20,2) sloping midband retrace (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11303 tc-m5-bb-midband-retrace
// -----------------------------------------------------------------------------
// Source: "20 Forex Trading Strategies (5 Minute Time Frame)" by Thomas Carter,
//   2014 (PDF), System #4. Card:
//   artifacts/cards_approved/QM5_11303_tc-m5-bb-midband-retrace.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trend STATE  : BB(20,2) middle band sloping.
//                  LONG  -> mid[shift1] > mid[shift1+slope_lookback].
//                  SHORT -> mid[shift1] < mid[shift1+slope_lookback].
//   Width  STATE : (upper - lower) >= bb_min_width_pips (viable S/R range).
//   Touch  EVENT : the just-closed bar retraced to and closed back off the mid.
//                  LONG  -> Low[shift1]  <= mid  AND  Close[shift1] >= mid.
//                  SHORT -> High[shift1] >= mid  AND  Close[shift1] <= mid.
//                  The slope is the STATE; the touch-and-close is the single
//                  EVENT (one per closed bar) — never two events on one bar.
//   Take profit  : opposite BB band at entry bar (upper for LONG, lower SHORT).
//   Stop loss    : the BB band on the entry side (lower for LONG, upper SHORT)
//                  capped to sl_max_pips — i.e. the TIGHTER of {band stop,
//                  sl_max_pips}. Card: MathMin(band, 15-pip) distance.
//   Spread guard : block only a genuinely wide spread > spread_cap_pips
//                  (fail-open on .DWX zero modeled spread).
//
// .DWX invariants honoured: fail-open spread guard, no swap gate, single-consume
// new-bar gate, prior-CLOSE-based touch (gapless CFDs), pips->price scaling via
// QM_StopRulesPipsToPriceDistance, no external-macro CSV. Sessions: none required
// by the card; M5 runs all hours (no session window).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11303;
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
input int    strategy_bb_period         = 20;    // Bollinger period (SMA20 middle)
input double strategy_bb_deviation      = 2.0;   // Bollinger standard-deviation mult
input int    strategy_slope_lookback    = 3;     // bars back for midband slope check
input int    strategy_bb_min_width_pips = 10;    // min (upper-lower) width, pips
input int    strategy_sl_max_pips       = 15;    // hard SL cap, pips (tighter wins)
input double strategy_spread_cap_pips   = 3.0;   // block only a wider spread, pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread:
// only a genuinely WIDE spread blocks; zero/negative modeled spread passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero / negative modeled spread — fail open

   const double cap = strategy_spread_cap_pips *
                      QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(cap > 0.0 && spread > cap)
      return true;  // genuinely wide spread — block

   return false;
  }

// Midband-retrace entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger bands on the just-closed bar (shift 1). deviation MANDATORY. ---
   const double mid   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period,
                                     strategy_bb_deviation, 1);
   const double upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period,
                                    strategy_bb_deviation, 1);
   const double lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period,
                                    strategy_bb_deviation, 1);
   if(mid <= 0.0 || upper <= 0.0 || lower <= 0.0)
      return false;

   // --- Width STATE: viable S/R range. ---
   const double min_width = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                            strategy_bb_min_width_pips);
   if(min_width > 0.0 && (upper - lower) < min_width)
      return false;

   // --- Slope STATE: midband direction over slope_lookback bars. ---
   const double mid_prev = QM_BB_Middle(_Symbol, _Period, strategy_bb_period,
                                        strategy_bb_deviation,
                                        1 + strategy_slope_lookback);
   if(mid_prev <= 0.0)
      return false;
   const bool slope_up   = (mid > mid_prev);
   const bool slope_down = (mid < mid_prev);
   if(!slope_up && !slope_down)
      return false; // horizontal midband — no trend, skip

   // --- Touch EVENT on the just-closed bar (single event/bar). ---
   // perf-allowed: single closed-bar OHLC reads (shift 1).
   const double low1   = iLow(_Symbol, _Period, 1);
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(low1 <= 0.0 || high1 <= 0.0 || close1 <= 0.0)
      return false;

   QM_OrderType side;
   double sl_band;   // band stop on the entry side
   double tp_band;   // opposite band as target
   double entry;

   if(slope_up)
     {
      // LONG: bar low touched/breached the mid, close held at/above the mid.
      if(!(low1 <= mid && close1 >= mid))
         return false;
      side    = QM_BUY;
      tp_band = upper;   // target = upper band
      sl_band = lower;   // stop reference = lower band
      entry   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else
     {
      // SHORT: bar high touched/breached the mid, close held at/below the mid.
      if(!(high1 >= mid && close1 <= mid))
         return false;
      side    = QM_SELL;
      tp_band = lower;   // target = lower band
      sl_band = upper;   // stop reference = upper band
      entry   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }

   if(entry <= 0.0)
      return false;

   // --- Stop: band stop capped to sl_max_pips. Take the TIGHTER distance. ---
   const double band_sl = QM_StopRulesNormalizePrice(_Symbol, sl_band);
   const double cap_sl  = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_max_pips);
   if(band_sl <= 0.0 || cap_sl <= 0.0)
      return false;

   double sl;
   if(side == QM_BUY)
      sl = MathMax(band_sl, cap_sl);   // higher SL = tighter for a long
   else
      sl = MathMin(band_sl, cap_sl);   // lower SL = tighter for a short

   // --- Target: opposite band. Reject if SL/TP are on the wrong side of entry
   //     (degenerate narrow-band geometry). ---
   const double tp = QM_StopRulesNormalizePrice(_Symbol, tp_band);
   if(side == QM_BUY)
     {
      if(!(sl < entry && tp > entry))
         return false;
     }
   else
     {
      if(!(sl > entry && tp < entry))
         return false;
     }

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "bb_midband_retrace_long"
                                 : "bb_midband_retrace_short";
   return true;
  }

// Static band-derived SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the band SL/TP.
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
