#property strict
#property version   "5.0"
#property description "QM5_1286 camarilla-monthly-pivots-position — Monthly Camarilla outer-pivot position trade: Mode A S3/R3 fade to P + Mode B S4/R4 break w/ Chandelier trail (D1-native)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1286 camarilla-monthly-pivots-position
// -----------------------------------------------------------------------------
// Source: ForexFactory Camarilla Equation community cluster (monthly-anchoring
//   variant) + Nick Stott Camarilla Equation (Stocks & Commodities 1989).
//   Card: artifacts/cards_approved/QM5_1286_camarilla-monthly-pivots-position.md
//   (g0_status APPROVED).
//
// Mechanics (position scale; execution + all reads are D1-native):
//   Camarilla pivots from the JUST-CLOSED calendar month's H/L/C. Because .DWX
//   custom symbols yield 0 bars on MN1 in the tester, the "monthly" H/L/C are
//   aggregated from the D1 bars that belong to the just-closed month, and the
//   month-rollover edge is taken from QM_CalendarPeriodKey(PERIOD_MN1) (a
//   D1-derived calendar key — NEVER a raw MN1 bar or a hand-rolled iTime key).
//     range = H - L
//     P  = (H + L + C) / 3
//     H3 = C + range*1.1/4 ; H4 = C + range*1.1/2
//     L3 = C - range*1.1/4 ; L4 = C - range*1.1/2
//   Levels are static for the whole following month.
//
//   MODE SELECTION at month-open (latched for the month, never re-evaluated):
//     range_ratio = month_range / (ATR(20,D1) * 20)
//     range_ratio <  break_ratio (0.80)  -> Mode A (Fade, mean-reversion)
//     range_ratio >= break_ratio (0.80)  -> Mode B (Break, trend-continuation)
//     range_ratio <  skip_ratio  (0.50)  -> degenerate month, no trades
//
//   MODE A — Outer Fade (target P):
//     LONG  when D1 close[1] <= L3 ; TP = P ; SL = L4 - 0.5*ATR(20,D1)
//     SHORT when D1 close[1] >= H3 ; TP = P ; SL = H4 + 0.5*ATR(20,D1)
//     Exit also at month-end rollover (close on first bar of next month).
//   MODE B — Outer Break (trail):
//     LONG  when D1 close[1] >  H4 ; initial SL = H3 ; no fixed TP
//     SHORT when D1 close[1] <  L4 ; initial SL = L3 ; no fixed TP
//     Chandelier trail ATR(20,D1)*3.0 engages once price is +ATR(20,D1)*1.0
//     past entry (monotonic tighten, via QM_TM_TrailATR). Opposite outer-pivot
//     daily close (long: close<L4 / short: close>H4) = trend invalidation exit.
//   Hard time-stop: 3 calendar months from entry (both modes).
//   One entry per symbol/magic per month (no re-entry within the same month).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1286;
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
// Camarilla coefficients (1.1 ; divisors 2/4) are the canonical Stott equation
// set — NOT inputs. Only the mode-threshold / stop / trail multipliers below.
input int    strategy_atr_period        = 20;     // ATR period on D1 (range-ratio, stops, trail)
input double strategy_atr_month_mult    = 20.0;   // monthly-scale baseline = ATR(period,D1) * this
input double strategy_break_ratio       = 0.80;   // range_ratio >= this => Mode B (break); else Mode A (fade)
input double strategy_skip_ratio        = 0.50;   // skip month if range_ratio < this (degenerate no-movement)
input double strategy_sl_atr_buffer     = 0.50;   // Mode A SL buffer beyond L4/H4 in ATR units
input double strategy_chandelier_mult   = 3.00;   // Mode B Chandelier trail = ATR(period,D1) * this
input double strategy_trail_engage_mult = 1.00;   // Mode B trail engages once price is +ATR*this past entry
input int    strategy_time_stop_months  = 3;      // hard time-stop: close after N calendar months from entry
input int    strategy_max_spread_points = 50;     // block only a genuinely wide spread (pts); .DWX models 0

// -----------------------------------------------------------------------------
// File-scope cached monthly-pivot state (advanced once per closed D1 bar).
// -----------------------------------------------------------------------------
double g_P = 0.0, g_H3 = 0.0, g_H4 = 0.0, g_L3 = 0.0, g_L4 = 0.0;
double g_month_range = 0.0, g_range_ratio = 0.0;
double g_atr_d1 = 0.0;          // cached ATR(period,D1) shift 1 — read by per-tick paths
double g_close1 = 0.0;          // cached last closed D1 close — read by per-tick paths
bool   g_pivots_valid   = false;
bool   g_month_tradeable = false;
bool   g_mode_break     = false; // latched mode for the current month (true=B break, false=A fade)
int    g_active_month_key = 0;   // month (yyyymm) whose pivots are currently latched
int    g_entered_month_key = 0;  // month (yyyymm) in which an entry already fired (one/month)

// yyyymm key from an arbitrary timestamp (e.g. a position's open time).
int MonthKeyFromTime(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   return d.year * 100 + d.mon;
  }

// Whole-month distance between two yyyymm keys (newer - older).
int MonthsBetween(const int older_key, const int newer_key)
  {
   const int oy = older_key / 100, om = older_key % 100;
   const int ny = newer_key / 100, nm = newer_key % 100;
   return (ny - oy) * 12 + (nm - om);
  }

// Aggregate the JUST-CLOSED month's H/L/C from its D1 bars (MN1 bars are 0 in
// the .DWX tester), compute the Camarilla levels, select + latch the mode.
// Called once, on the D1 bar where the calendar month rolls over.
void RecomputeMonthlyPivots()
  {
   const int closed_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1); // month of last closed D1 bar
   if(closed_key <= 0)
     {
      g_pivots_valid = false;
      return;
     }

   double hi = -DBL_MAX, lo = DBL_MAX, close_c = 0.0;
   bool got = false;
   const int max_scan = 40; // > any month's D1 bar count
   for(int s = 1; s <= max_scan; ++s)
     {
      if(QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, s) != closed_key)
         break; // walked past the just-closed month's boundary
      // Bounded once-per-month D1 OHLC aggregation (structural). // perf-allowed
      const double h = iHigh(_Symbol, PERIOD_D1, s); // perf-allowed
      const double l = iLow(_Symbol,  PERIOD_D1, s); // perf-allowed
      if(h <= 0.0 || l <= 0.0)
         break;
      if(!got)
        {
         close_c = iClose(_Symbol, PERIOD_D1, s); // shift 1 = month's closing D1 bar // perf-allowed
         got = true;
        }
      if(h > hi) hi = h;
      if(l < lo) lo = l;
     }

   if(!got || !(hi > lo) || close_c <= 0.0)
     {
      g_pivots_valid = false;
      return;
     }

   const double range = hi - lo;
   const double c = close_c;
   g_month_range = range;
   g_P  = (hi + lo + c) / 3.0;
   g_H3 = c + range * 1.1 / 4.0;
   g_H4 = c + range * 1.1 / 2.0;
   g_L3 = c - range * 1.1 / 4.0;
   g_L4 = c - range * 1.1 / 2.0;

   const double baseline = g_atr_d1 * strategy_atr_month_mult; // ATR(period,D1) * 20
   if(g_atr_d1 <= 0.0 || baseline <= 0.0)
     {
      g_pivots_valid = false; // ATR not warm yet — no valid mode this month
      return;
     }
   g_range_ratio     = range / baseline;
   g_month_tradeable = (g_range_ratio >= strategy_skip_ratio);
   g_mode_break      = (g_range_ratio >= strategy_break_ratio);
   g_pivots_valid    = true;
   g_entered_month_key = 0; // fresh month — allow one new entry
  }

// Advance closed-bar cached state; recompute pivots on a calendar-month roll.
// Caller guarantees QM_IsNewBar() == true (once per closed D1 bar).
void AdvanceState_OnNewBar()
  {
   g_atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   // Single last-closed-bar D1 close cache for per-tick reads.
   g_close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed

   const int cur_key = QM_CalendarPeriodKey(PERIOD_MN1); // D1-derived yyyymm
   if(cur_key > 0 && cur_key != g_active_month_key)
     {
      g_active_month_key = cur_key;
      RecomputeMonthlyPivots(); // uses the just-closed (shift-1) month
     }
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
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > strategy_max_spread_points * point)
      return true;
   return false;
  }

// Monthly Camarilla outer-pivot entry. Caller guarantees QM_IsNewBar()==true and
// that AdvanceState_OnNewBar() has already refreshed the cached state this bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_pivots_valid || !g_month_tradeable)
      return false;

   const int mkey = QM_CalendarPeriodKey(PERIOD_MN1);
   if(mkey <= 0)
      return false;
   if(g_entered_month_key == mkey)
      return false; // one entry per month per symbol/magic

   const double close1 = g_close1;
   const double atr = g_atr_d1;
   if(close1 <= 0.0 || atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(!g_mode_break)
     {
      // ---- Mode A — Outer Fade back toward P ----
      if(close1 <= g_L3)
        {
         double sl = g_L4 - strategy_sl_atr_buffer * atr;
         const double tp = g_P;
         if(!(sl < ask) || !(tp > ask))
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "cam_mn_modeA_long_fade_L3";
         g_entered_month_key = mkey;
         return true;
        }
      if(close1 >= g_H3)
        {
         double sl = g_H4 + strategy_sl_atr_buffer * atr;
         const double tp = g_P;
         if(!(sl > bid) || !(tp < bid))
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
         req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
         req.reason = "cam_mn_modeA_short_fade_H3";
         g_entered_month_key = mkey;
         return true;
        }
      return false;
     }

   // ---- Mode B — Outer Break (trend); no fixed TP, Chandelier trail manages ----
   if(close1 > g_H4)
     {
      const double sl = g_H3; // broken outer level becomes support
      if(!(sl < ask))
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = 0.0;
      req.reason = "cam_mn_modeB_long_break_H4";
      g_entered_month_key = mkey;
      return true;
     }
   if(close1 < g_L4)
     {
      const double sl = g_L3;
      if(!(sl > bid))
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = 0.0;
      req.reason = "cam_mn_modeB_short_break_L4";
      g_entered_month_key = mkey;
      return true;
     }
   return false;
  }

// Mode B only: engage the Chandelier ATR trail once price is +ATR*engage past
// entry. Mode A (fixed TP=P) is not actively managed. Reads cached g_atr_d1;
// the actual monotonic tighten is delegated to the pooled-handle QM_TM_TrailATR.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;
   const double atr = g_atr_d1;
   if(atr <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetDouble(POSITION_TP) > 0.0)
         continue; // Mode A carries a fixed TP — not trailed
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const long   ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && (bid - open_price) >= strategy_trail_engage_mult * atr)
            QM_TM_TrailATR(ticket, strategy_atr_period, strategy_chandelier_mult);
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && (open_price - ask) >= strategy_trail_engage_mult * atr)
            QM_TM_TrailATR(ticket, strategy_atr_period, strategy_chandelier_mult);
        }
     }
  }

// Discretionary exits beyond SL/TP:
//   - Hard time-stop: 3 calendar months from entry (both modes).
//   - Mode A: close at month-end rollover (first bar of the next month).
//   - Mode B: opposite outer-pivot daily close = trend invalidation.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int cur_mkey = QM_CalendarPeriodKey(PERIOD_MN1);
   if(cur_mkey <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const int entry_mkey = MonthKeyFromTime((datetime)PositionGetInteger(POSITION_TIME));
      const int months_held = MonthsBetween(entry_mkey, cur_mkey);

      // Hard time-stop (both modes).
      if(months_held >= strategy_time_stop_months)
         return true;

      const bool is_modeA = (PositionGetDouble(POSITION_TP) > 0.0);
      if(is_modeA)
        {
         // Close at month-end rollover (next month has begun).
         if(months_held >= 1)
            return true;
        }
      else
        {
         // Mode B: opposite outer-pivot daily close invalidates the trend.
         if(!g_pivots_valid || g_close1 <= 0.0)
            continue;
         const long ptype = PositionGetInteger(POSITION_TYPE);
         if(ptype == POSITION_TYPE_BUY && g_close1 < g_L4)
            return true;
         if(ptype == POSITION_TYPE_SELL && g_close1 > g_H4)
            return true;
        }
     }
   return false;
  }

// Defer to the central two-axis news filter.
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management + rule-based exits run through news windows (they gate entries
   // only, per the 2026-07-02 audit ordering rule).
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

   // News gate applies to NEW entries only.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults
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
