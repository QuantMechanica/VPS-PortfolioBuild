#property strict
#property version   "5.0"
#property description "QM5_11315 tc-m5-8-triple-bb50-rsi3-stoch — Triple BB(50) red-band reversal + RSI(3) + Stoch (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11315 tc-m5-8-triple-bb50-rsi3-stoch
// -----------------------------------------------------------------------------
// Source: "20 Forex Trading Strategies (5 Minute Time Frame)" by Thomas Carter,
//   2014 (PDF), 5 Min Trading System #8. Card:
//   artifacts/cards_approved/QM5_11315_tc-m5-8-triple-bb50-rsi3-stoch.md
//   (g0_status APPROVED). source_id e78a9f1f-4e6a-563c-a080-915133d6ed28.
//
// Mechanics (closed-bar reads, M5; "touch bar" = shift 2, "confirm bar" = shift 1):
//   Three Bollinger Bands on the SAME SMA(50) middle, graded by deviation:
//     red  = BB(50, 2)  — the trade band
//     yellow = BB(50, 3) — first stop reference (one band out)
//     orange = BB(50, 4) — fallback stop if price already beyond yellow
//
//   LONG (reversal off the lower red band):
//     STATE  (touch bar, shift 2): Low touched/closed below red-lower
//                                  AND RSI(3) < rsi_oversold
//                                  AND Stoch %K < stoch_oversold (extreme zone).
//     EVENT  (confirm bar, shift 1, the SINGLE trigger): the just-closed bar
//            closed back ABOVE red-lower (band recapture) — i.e. shift2 was
//            below the band and shift1 closed above it.
//     STATE  (confirm bar): RSI(3) recovered above rsi_oversold
//                           AND Stoch %K turning up (K[1] > K[2]).
//   SHORT is the mirror off the upper red band.
//
//   Per .DWX invariant #4: the band RECAPTURE is the one fresh EVENT; the RSI /
//   Stoch conditions are STATES (level + simple turn), never two cross events on
//   the same bar.
//
//   Take profit : SMA(50) middle band (red middle), captured at entry.
//   Stop loss   : yellow band (BB 50,3) on the entry side at entry time. If the
//                 confirm bar already extends beyond yellow, use orange (BB 50,4).
//                 Final SL distance capped to sl_max_pips (P2 cap, tighter wins).
//   Spread guard: fail-OPEN on .DWX zero modeled spread; block only a genuinely
//                 wide spread > spread_cap_pips.
//   Dead-band   : skip if red-band width (upper-lower) < width_spread_mult * spread.
//   Session     : London + NY only (13:00-22:00 GMT). Gated in UTC via
//                 QM_BrokerToUTC so it stays correct across broker DST (GMT+2/+3).
//
// .DWX invariants honoured: fail-open spread, no swap gate, single-consume
// new-bar gate, prior-CLOSE band recapture (gapless CFDs), broker-time session
// converted to UTC, pips->price via QM_StopRulesPipsToPriceDistance, no
// external-macro CSV. Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11315;
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
input int    strategy_bb_period         = 50;    // Bollinger SMA period (middle band)
input double strategy_bb_dev_red        = 2.0;   // red band deviation (trade band)
input double strategy_bb_dev_yellow     = 3.0;   // yellow band deviation (first SL)
input double strategy_bb_dev_orange     = 4.0;   // orange band deviation (fallback SL)
input int    strategy_rsi_period        = 3;     // RSI period
input double strategy_rsi_oversold      = 20.0;  // RSI long-side extreme threshold
input double strategy_rsi_overbought    = 80.0;  // RSI short-side extreme threshold
input int    strategy_stoch_k           = 6;     // Stochastic %K period
input int    strategy_stoch_d           = 3;     // Stochastic %D period
input int    strategy_stoch_slow        = 3;     // Stochastic slowing
input double strategy_stoch_oversold    = 20.0;  // Stoch long-side extreme threshold
input double strategy_stoch_overbought  = 80.0;  // Stoch short-side extreme threshold
input int    strategy_sl_max_pips       = 25;    // hard SL cap, pips (P2 cap; tighter wins)
input double strategy_width_spread_mult = 1.5;   // dead-band: red width >= mult * spread
input double strategy_spread_cap_pips   = 15.0;  // block only a wider spread, pips
input int    strategy_session_start_gmt = 13;    // London+NY window start (GMT/UTC hour)
input int    strategy_session_end_gmt   = 22;    // London+NY window end   (GMT/UTC hour)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + spread guard.
// Session window is expressed in GMT/UTC and matched against the UTC hour
// derived from broker time, so it tracks broker DST (GMT+2/+3) automatically.
// Spread guard fails OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   // --- Session: London + NY only (13:00-22:00 GMT). ---
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(QM_Sig_Session(utc_now, strategy_session_start_gmt, strategy_session_end_gmt) == 0)
      return true; // outside the London+NY window — block

   // --- Spread guard (fail-open on .DWX zero spread). ---
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

// Triple-BB red-band reversal entry. Caller guarantees QM_IsNewBar() == true.
// touch bar = shift 2, confirm bar = shift 1. The band recapture is the EVENT;
// RSI/Stoch are STATES.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Bollinger bands (same SMA50 middle; deviation MANDATORY per arg). ---
   // Confirm bar (shift 1) values used for the recapture EVENT and SL/TP geometry.
   const double mid_c   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_red,    1);
   const double red_up_c   = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_red,    1);
   const double red_lo_c   = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_red,    1);
   const double yel_up_c   = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_yellow, 1);
   const double yel_lo_c   = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_yellow, 1);
   const double org_up_c   = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_orange, 1);
   const double org_lo_c   = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_orange, 1);
   if(mid_c <= 0.0 || red_up_c <= 0.0 || red_lo_c <= 0.0 ||
      yel_up_c <= 0.0 || yel_lo_c <= 0.0 || org_up_c <= 0.0 || org_lo_c <= 0.0)
      return false;

   // Touch bar (shift 2) red band — for the STATE on the touch bar.
   const double red_up_t = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_red, 2);
   const double red_lo_t = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_red, 2);
   if(red_up_t <= 0.0 || red_lo_t <= 0.0)
      return false;

   // --- Dead-band filter: skip if red-band width < mult * spread. ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   const double spread = (ask > bid) ? (ask - bid) : 0.0;
   if(spread > 0.0 && (red_up_c - red_lo_c) < strategy_width_spread_mult * spread)
      return false; // dead band — range too tight relative to cost

   // --- Oscillator reads. RSI(3); Stoch(6,3,3) %K. ---
   const double rsi_t = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double rsi_c = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double k_t   = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double k_c   = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   if(rsi_t <= 0.0 || rsi_c <= 0.0 || k_t <= 0.0 || k_c <= 0.0)
      return false;

   // --- Closed-bar OHLC. perf-allowed: single closed-bar reads, shifts 1 & 2. ---
   const double low_t   = iLow(_Symbol, _Period, 2);
   const double high_t  = iHigh(_Symbol, _Period, 2);
   const double close_t = iClose(_Symbol, _Period, 2);
   const double low_c   = iLow(_Symbol, _Period, 1);
   const double high_c  = iHigh(_Symbol, _Period, 1);
   const double close_c = iClose(_Symbol, _Period, 1);
   if(low_t <= 0.0 || high_t <= 0.0 || close_t <= 0.0 ||
      low_c <= 0.0 || high_c <= 0.0 || close_c <= 0.0)
      return false;

   QM_OrderType side;
   double sl_band;   // entry-side stop band (yellow, or orange if extended)
   double entry;

   // ---------------- LONG: reversal off the lower red band ----------------
   const bool long_touch_state  = (low_t <= red_lo_t) &&            // touched/closed below red-lower
                                  (rsi_t < strategy_rsi_oversold) && // RSI(3) exhausted
                                  (k_t   < strategy_stoch_oversold); // Stoch extreme low
   const bool long_recapture    = (close_t < red_lo_t) &&           // touch bar below band (STATE)
                                  (close_c > red_lo_c);              // confirm bar closed back above (EVENT)
   const bool long_osc_confirm  = (rsi_c > strategy_rsi_oversold) && // RSI recovered above threshold
                                  (k_c   > k_t);                     // Stoch turning up

   // ---------------- SHORT: reversal off the upper red band ----------------
   const bool short_touch_state = (high_t >= red_up_t) &&
                                  (rsi_t > strategy_rsi_overbought) &&
                                  (k_t   > strategy_stoch_overbought);
   const bool short_recapture   = (close_t > red_up_t) &&
                                  (close_c < red_up_c);
   const bool short_osc_confirm = (rsi_c < strategy_rsi_overbought) &&
                                  (k_c   < k_t);

   if(long_touch_state && long_recapture && long_osc_confirm)
     {
      side  = QM_BUY;
      entry = ask;
      // SL: yellow lower; if confirm bar already extends below yellow, use orange.
      sl_band = (low_c < yel_lo_c) ? org_lo_c : yel_lo_c;
     }
   else if(short_touch_state && short_recapture && short_osc_confirm)
     {
      side  = QM_SELL;
      entry = bid;
      sl_band = (high_c > yel_up_c) ? org_up_c : yel_up_c;
     }
   else
      return false;

   if(entry <= 0.0)
      return false;

   // --- Stop: band stop capped to sl_max_pips (P2 cap). Take the TIGHTER. ---
   const double band_sl = QM_StopRulesNormalizePrice(_Symbol, sl_band);
   const double cap_sl  = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_max_pips);
   if(band_sl <= 0.0 || cap_sl <= 0.0)
      return false;

   double sl;
   if(side == QM_BUY)
      sl = MathMax(band_sl, cap_sl);   // higher SL = tighter for a long
   else
      sl = MathMin(band_sl, cap_sl);   // lower SL = tighter for a short

   // --- Target: SMA(50) middle band. ---
   const double tp = QM_StopRulesNormalizePrice(_Symbol, mid_c);

   // Reject degenerate geometry (SL/TP on the wrong side of entry).
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
   req.reason = (side == QM_BUY) ? "triple_bb_redband_reversal_long"
                                 : "triple_bb_redband_reversal_short";
   return true;
  }

// Static band-derived SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the band SL / SMA50 TP.
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
