#property strict
#property version   "5.0"
#property description "QM5_11092 cvd-zero — CVD zero-cross entry/exit (H1, tick-volume delta proxy)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11092 cvd-zero
// -----------------------------------------------------------------------------
// Source: EarnForex "Cumulative Volume Delta" (CVD.mq5), GitHub + article.
// Card: artifacts/cards_approved/QM5_11092_cvd-zero.md (g0_status APPROVED).
//
// APPROXIMATION FLAG (load-bearing — read before judging fidelity):
//   True CVD needs a buy/sell volume split (bid/ask aggression). The Darwinex
//   `.DWX` symbols provide ONLY tick volume — there is NO order-flow split in
//   the MT5 tester. Per the build mandate, delta is approximated deterministically
//   from CLOSED bars as:
//
//       close_pos = (close - low) / (high - low)        // 0..1 within the bar
//       delta_bar = tick_volume * (2 * close_pos - 1)   // +vol near high, -vol near low
//
//   This is the card's own "buy = vol*close_pos, sell = vol*(1-close_pos)"
//   formula (delta = buy - sell). It is a bar-direction-weighted tick-volume
//   proxy, NOT exchange order-flow delta. CVD = rolling sum of delta_bar over the
//   last `cvd_period` CLOSED bars, advanced ONCE per new closed bar (no per-tick
//   re-sum). Reviewer must treat broker-volume fidelity as the key uncertainty
//   (card R3 caveat).
//
// Mechanics (closed-bar reads at shift 1; CVD cached file-scope):
//   Long  ENTRY : CVD crosses from <= 0 to > 0 on the just-closed bar.
//   Short ENTRY : CVD crosses from >= 0 to < 0 on the just-closed bar.
//   Exit        : CVD crosses back through zero against the position (reverse
//                 cross) -> close manually. (A reverse cross is also a fresh
//                 opposite entry on the next eligible bar.)
//   Time stop   : close after `cvd_time_stop_bars` H1 bars held.
//   Stop loss   : ATR(atr_period) hard stop at `sl_atr_mult` ATR (no TP; exit is
//                 CVD-driven). Catastrophic protection only.
//
//   Per the intraday discipline, CVD state is advanced ONE step per closed bar in
//   AdvanceCVD_OnNewBar(); OnTick reads only cached values. The raw iVolume /
//   iHigh / iLow / iClose reads are bespoke structural logic with no QM_* reader,
//   so they are `// perf-allowed` and gated to one call per closed bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs + the CVD cache are EA-specific.
// Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11092;
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
input int    cvd_period             = 20;    // rolling CVD window in CLOSED bars
input int    cvd_time_stop_bars     = 20;    // catastrophic time stop, H1 bars held
input int    atr_period             = 14;    // ATR period for the hard stop
input double sl_atr_mult            = 2.0;   // hard stop = mult * ATR
input double spread_pct_of_stop     = 15.0;  // skip only if spread > this % of stop

// -----------------------------------------------------------------------------
// CVD cache (file-scope, advanced once per new closed bar)
// -----------------------------------------------------------------------------
double   g_cvd_now      = 0.0;     // CVD over the most recent `cvd_period` closed bars (ends at shift 1)
double   g_cvd_prev     = 0.0;     // CVD ending one bar earlier (ends at shift 2)
bool     g_cvd_ready    = false;   // becomes true once enough history is loaded
datetime g_entry_bartime = 0;      // bar-open time of the bar on which we entered (time stop)

// Bar-direction-weighted tick-volume delta for the bar at `shift`.
// perf-allowed: bespoke order-flow proxy; no QM_* reader exists for it.
double BarDelta(const int shift)
  {
   const double high = iHigh(_Symbol, _Period, shift);    // perf-allowed
   const double low  = iLow(_Symbol, _Period, shift);     // perf-allowed
   const double cls  = iClose(_Symbol, _Period, shift);   // perf-allowed
   const double vol  = (double)iVolume(_Symbol, _Period, shift); // perf-allowed: tick volume
   const double range = high - low;
   double close_pos = 0.5;           // doji / zero-range bar -> neutral delta
   if(range > 0.0)
      close_pos = (cls - low) / range;
   return vol * (2.0 * close_pos - 1.0);
  }

// Rolling CVD sum over `cvd_period` closed bars whose newest bar is at `end_shift`.
double CvdSum(const int end_shift)
  {
   double sum = 0.0;
   for(int k = 0; k < cvd_period; ++k)
      sum += BarDelta(end_shift + k);
   return sum;
  }

// Advance the cached CVD once per new closed bar. The newest closed bar is shift 1.
// g_cvd_now  ends at shift 1 (window shifts 1..cvd_period).
// g_cvd_prev ends at shift 2 (window shifts 2..cvd_period+1).
void AdvanceCVD_OnNewBar()
  {
   const int need = cvd_period + 2; // shifts 1..cvd_period+1 must be readable
   if(Bars(_Symbol, _Period) < need + 1)
     {
      g_cvd_ready = false;
      return;
     }
   g_cvd_now  = CvdSum(1);
   g_cvd_prev = CvdSum(2);
   g_cvd_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer, do not block here

   const double stop_distance = sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on CVD zero-cross. Caller guarantees QM_IsNewBar() == true; the CVD cache
// has already been advanced this bar in OnTick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_cvd_ready)
      return false;

   // Long: CVD crosses from <= 0 to > 0. Short: from >= 0 to < 0. ONE event drives it.
   const bool cross_up   = (g_cvd_prev <= 0.0 && g_cvd_now > 0.0);
   const bool cross_down = (g_cvd_prev >= 0.0 && g_cvd_now < 0.0);
   if(!cross_up && !cross_down)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(cross_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // CVD-driven exit; catastrophic stop only
      req.reason = "cvd_zero_cross_long";
     }
   else // cross_down
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "cvd_zero_cross_short";
     }

   g_entry_bartime = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open time for time stop
   return true;
  }

// No active trade management beyond the fixed ATR catastrophic stop. CVD reverse
// cross and the time stop live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit on CVD reverse cross (against the open side) OR the catastrophic time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open side.
   bool is_long = false, is_short = false;
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
      break;
     }
   if(!is_long && !is_short)
      return false;

   // Catastrophic time stop: held for >= cvd_time_stop_bars H1 bars.
   if(g_entry_bartime > 0 && cvd_time_stop_bars > 0)
     {
      const datetime bar_now = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open time
      const int bars_held = (int)((bar_now - g_entry_bartime) / (PeriodSeconds(_Period)));
      if(bars_held >= cvd_time_stop_bars)
         return true;
     }

   // CVD reverse cross through zero against the position.
   if(!g_cvd_ready)
      return false;
   if(is_long)
     {
      const bool cross_down = (g_cvd_prev >= 0.0 && g_cvd_now < 0.0);
      if(cross_down)
         return true;
     }
   else // is_short
     {
      const bool cross_up = (g_cvd_prev <= 0.0 && g_cvd_now > 0.0);
      if(cross_up)
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

   g_cvd_now = 0.0;
   g_cvd_prev = 0.0;
   g_cvd_ready = false;
   g_entry_bartime = 0;

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

   // Per-tick: discretionary exit (CVD reverse cross / time stop) reads cached state.
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

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar())
      return;

   // FIRST on the new closed bar: advance the cached CVD by one step.
   AdvanceCVD_OnNewBar();

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
