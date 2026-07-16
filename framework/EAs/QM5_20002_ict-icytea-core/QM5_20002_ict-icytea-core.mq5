#property strict
#property version   "5.0"
#property description "QM5_20002 ICT / Smart-Money Core Model (icytea Phase 1)"

// Source: MQL5_Strategie_Spezifikation_some_icy_tea.docx (770 annotated trades,
// @some_icy_tea). Extracted spec: D:\QM\reports\ict_intake\spec.txt. Build brief:
// framework/EAs/QM5_20002_ict-icytea-core/docs/BUILD_BRIEF.md. Phase 1 = the Core
// Model only (spec Ch3+Ch4): liquidity sweep -> MSS+displacement -> FVG/OB entry in
// the retracement, filtered by premium/discount, SL behind the sweep, TP at the
// nearest opposite external liquidity pool, partial then breakeven. Long side is
// implemented from the spec directly; short is the exact mirror (spec Ch3 opener).
// Setup variants (Judas/TurtleSoup/Unicorn/SilverBullet/TGIF/3Drives/MMxM/
// IndexMacro/SMT, spec Ch5) are toggle-gated stubs left for Phase 2/3.

#include <QM/QM_Common.mqh>

// spec Ch3 S4 / Ch7: PD-array entry-zone selection mode.
enum ICT_EntryModeType
  {
   ICT_ENTRY_FVG_EDGE = 0,   // limit at the FVG edge nearest the impulse ("FVG-Oberkante"/"-Unterkante")
   ICT_ENTRY_FVG_CE   = 1,   // limit at the FVG Consequent Encroachment (50% midpoint, spec Ch4)
   ICT_ENTRY_OB_MT    = 2    // limit at the Order Block Mean Threshold (50% of [Open,Low]/[Open,High], spec Ch4)
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20002;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input bool                TradeLongs             = false;                // Allow Long trades
input bool                TradeShorts            = true;                 // Allow Short trades
input ENUM_TIMEFRAMES    ExecutionTF            = PERIOD_M1;             // spec Ch7: execution timeframe (all algorithmic defs run on this TF)
input ENUM_TIMEFRAMES    HTF_Context_M15        = PERIOD_M15;            // spec Ch7 HTF_Context #1: used for Asian-range scan; Phase 2 HTF-bias/zone hook
input ENUM_TIMEFRAMES    HTF_Context_H1         = PERIOD_H1;             // spec Ch7 HTF_Context #2: reserved for Phase 2 HTF-bias/HTF-FVG hook (unused Phase 1)
input int                SwingLookback          = 2;                     // spec Ch3 S1: fractal swing lookback each side
input double              EqualTolerance_Pips    = 2.0;                  // spec Ch3 S1: EQH/EQL clustering tolerance (pips)
input double              EqualTolerance_ATRfrac = 0.10;                 // spec Ch3 S1: EQH/EQL clustering tolerance (x ATR14)
input int                SweepReturnBars        = 3;                     // spec Ch3 S2: bars allowed to reclaim a swept level
input double              DisplacementATR        = 1.50;                 // spec Ch3 S3: min impulse body vs ATR14
input bool                RequireFVGInImpulse    = true;                 // spec Ch3 S3: mandate FVG-in-impulse (else OR body>=k*ATR)
input double              FVG_MinPoints          = 10.0;                 // spec Ch4: min FVG width in points (10 = 1 pip on 5-digit)
input ICT_EntryModeType  EntryMode              = ICT_ENTRY_FVG_EDGE;   // spec Ch3 S4 / Ch7
input bool                PremiumDiscountFilter  = true;                 // spec Ch3 S4
input bool                UseHTFBias             = true;                 // spec Ch6 Richtungsfilter: only trade WITH the last HTF (H1) structure break (blocks counter-trend)
input int                 HTFBiasLookback        = 60;                   // spec Ch6: HTF bars scanned for the last swing-break structure state
input bool                UseOTE                 = false;                // spec Ch3 S4: optional 0.62-0.79 OTE refinement
input double              SL_BufferPoints        = 15.0;                 // spec Ch3 S5
input double              MinRR                  = 2.0;                  // spec Ch3 S6 / Ch6
input double              PartialPct             = 50.0;                 // spec Ch3 S6 / Ch6
input double              PartialAt              = 50.0;                 // spec Ch3 S6 / Ch6 (% of the entry->TP distance)
input bool                BreakevenAfterPartial  = true;                 // spec Ch3 S6 / Ch6
input int                MaxTradesPerKZ         = 2;                     // spec Ch6
input int                TZ_Offset_NYtoBroker   = 0;                     // spec Ch2.3: manual correction (hours) on top of the QM_DSTAware NY<->broker conversion
input bool                KZ_London_on           = false;                // spec Ch2.3: London KZ 02:00-05:00 NY
input bool                KZ_NewYork_on          = true;                 // spec Ch2.3: New York KZ 07:00-10:00 NY
input bool                Setup_Judas            = false;                // spec Ch5.1 (Phase 2/3 stub)
input bool                Setup_TurtleSoup       = false;                // spec Ch5.2 (Phase 2/3 stub)
input bool                Setup_Unicorn          = false;                // spec Ch5.3 (Phase 2/3 stub)
input bool                Setup_SilverBullet     = false;                // spec Ch5.4 (Phase 2/3 stub)
input bool                Setup_TGIF             = false;                // spec Ch5.8 (Phase 2/3 stub)
input bool                Setup_3Drives          = false;                // spec Ch5.6 (Phase 2/3 stub)
input bool                Setup_MMxM             = false;                // spec Ch5.7 (Phase 2/3 stub)
input bool                Setup_IndexMacro       = false;                // spec Ch5.9 (Phase 2/3 stub)
input bool                UseSMT                 = false;                // spec Ch5.5: SMT confluence filter (Phase 2/3 stub, no-op while false)

#define ICT_SWING_MAX               64
#define ICT_MSS_PENDING_EXPIRY_BARS 30   // spec gives no explicit sweep->MSS window; bounded engineering assumption (see report)
#define ICT_OB_SEARCH_WINDOW        5
#define ICT_IMPULSE_MAX             40   // cap on the sweep->MSS impulse-leg scan (spec Ch3 S3/S4: the displacement FVG lives inside this leg, not only at the MSS bar)
#define ICT_KZ_LONDON_START         2
#define ICT_KZ_LONDON_END           5
#define ICT_KZ_NEWYORK_START        7
#define ICT_KZ_NEWYORK_END          10

// spec Ch3 S2/S3: one manipulation event being tracked per side while it waits for
// its body-close structural break (MSS). Single-slot per side (Phase 1 simplification
// -- see report): a fresh sweep is only picked up once the current pending resolves
// (traded/invalidated) or expires.
struct ICT_Pending
  {
   bool   active;
   double sweep_extreme;   // manipulation extreme (lowest low / highest high of the sweep)
   double swept_level;     // the liquidity pool price that got swept
   double target_swing;    // last relevant swing high/low that must break (spec Ch3 S3)
   int    bars_waited;
  };

// spec Ch3 S6: partial-then-breakeven state per open position (MT5 has no native
// per-position custom flag, so it is tracked here by POSITION_IDENTIFIER).
struct ICT_PosState
  {
   ulong position_id;
   bool  partial_done;
   bool  be_done;
  };

double   g_ict_sw_high_price[ICT_SWING_MAX];
datetime g_ict_sw_high_time[ICT_SWING_MAX];
int      g_ict_sw_high_count = 0;
double   g_ict_sw_low_price[ICT_SWING_MAX];
datetime g_ict_sw_low_time[ICT_SWING_MAX];
int      g_ict_sw_low_count = 0;

ICT_Pending g_ict_pending_long;
ICT_Pending g_ict_pending_short;

ICT_PosState g_ict_pos_state[];

// -----------------------------------------------------------------------------
// Unit helpers
// -----------------------------------------------------------------------------

// "Points" per spec Ch4/Ch7 (FVG_MinPoints, SL_BufferPoints) = raw MT5 points.
double ICT_PointsToPrice(const string sym, const double points)
  {
   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   return points * point;
  }

// "Pips" per spec Ch3 S1 (EqualTolerance_Pips) = 10 points on a 5-digit FX symbol.
double ICT_PipsToPrice(const string sym, const double pips)
  {
   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

// -----------------------------------------------------------------------------
// DST-aware NY-time <-> broker-time helpers (spec Ch2.3/Ch9: "Zeitzonen sind kritisch")
// -----------------------------------------------------------------------------

// Reduce a broker-time instant to NY wall-clock fields via QM_DSTAware. The
// DarwinexZero broker convention (GMT+2/+3) and US Eastern time (EST/EDT) share
// the same US-DST transition calendar, so QM_BrokerToUTC + the US-DST offset give
// the correct NY hour/date without needing per-broker calibration; TZ_Offset_NYtoBroker
// remains available below as an explicit manual correction on top of this.
void ICT_BrokerTimeToNY(const datetime broker_time, MqlDateTime &ny_out)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const bool dst = QM_IsUSDSTUTC(utc);
   const int ny_offset_sec = dst ? (-4 * 3600) : (-5 * 3600);
   const datetime ny_shifted = utc + ny_offset_sec;
   TimeToStruct(ny_shifted, ny_out);
  }

// spec Ch2.3: killzone bounds are NY-time hour windows; tz_offset is the operator
// correction knob (default 0) layered on top of the automatic DST-aware conversion.
bool ICT_InKillzone(const datetime broker_now, const int kz_start_ny, const int kz_end_ny, const int tz_offset)
  {
   MqlDateTime ny;
   ICT_BrokerTimeToNY(broker_now, ny);
   int h = ((ny.hour + tz_offset) % 24 + 24) % 24;
   if(kz_start_ny <= kz_end_ny)
      return (h >= kz_start_ny && h < kz_end_ny);
   return (h >= kz_start_ny || h < kz_end_ny);
  }

// -----------------------------------------------------------------------------
// Swing points (fractals) — spec Ch3 S1
// -----------------------------------------------------------------------------

void ICT_PushSwingHigh(const double price, const datetime t)
  {
   if(g_ict_sw_high_count > 0 && g_ict_sw_high_time[0] == t)
      return;
   const int n = MathMin(g_ict_sw_high_count + 1, ICT_SWING_MAX);
   for(int i = n - 1; i > 0; --i)
     {
      g_ict_sw_high_price[i] = g_ict_sw_high_price[i - 1];
      g_ict_sw_high_time[i]  = g_ict_sw_high_time[i - 1];
     }
   g_ict_sw_high_price[0] = price;
   g_ict_sw_high_time[0]  = t;
   g_ict_sw_high_count = n;
  }

void ICT_PushSwingLow(const double price, const datetime t)
  {
   if(g_ict_sw_low_count > 0 && g_ict_sw_low_time[0] == t)
      return;
   const int n = MathMin(g_ict_sw_low_count + 1, ICT_SWING_MAX);
   for(int i = n - 1; i > 0; --i)
     {
      g_ict_sw_low_price[i] = g_ict_sw_low_price[i - 1];
      g_ict_sw_low_time[i]  = g_ict_sw_low_time[i - 1];
     }
   g_ict_sw_low_price[0] = price;
   g_ict_sw_low_time[0]  = t;
   g_ict_sw_low_count = n;
  }

// spec Ch3 S1: "3-Kerzen-Fraktal" generalized to `lookback` bars each side. Evaluated
// once per closed bar (Strategy_EntrySignal only runs under the framework's
// QM_IsNewBar() gate), centred on the oldest bar for which both wings are closed.
void ICT_UpdateSwings(const int lookback)
  {
   if(lookback < 1)
      return;
   const int center = lookback + 1;
   const double h  = iHigh(_Symbol, ExecutionTF, center); // perf-allowed
   const double l  = iLow(_Symbol, ExecutionTF, center); // perf-allowed
   const datetime ct = iTime(_Symbol, ExecutionTF, center); // perf-allowed
   if(h <= 0.0 || l <= 0.0 || ct <= 0)
      return;

   bool is_high = true, is_low = true;
   for(int k = 1; k <= lookback; ++k)
     {
      const double h_near = iHigh(_Symbol, ExecutionTF, center - k); // perf-allowed
      const double h_far  = iHigh(_Symbol, ExecutionTF, center + k); // perf-allowed
      if(h_near <= 0.0 || h_far <= 0.0 || !(h > h_near && h > h_far))
         is_high = false;

      const double l_near = iLow(_Symbol, ExecutionTF, center - k); // perf-allowed
      const double l_far  = iLow(_Symbol, ExecutionTF, center + k); // perf-allowed
      if(l_near <= 0.0 || l_far <= 0.0 || !(l < l_near && l < l_far))
         is_low = false;

      if(!is_high && !is_low)
         break;
     }
   if(is_high)
      ICT_PushSwingHigh(h, ct);
   if(is_low)
      ICT_PushSwingLow(l, ct);
  }

// -----------------------------------------------------------------------------
// HTF directional bias — spec Ch6 "Richtungsfilter": last structure break on the HTF
// -----------------------------------------------------------------------------

// Returns +1 bullish / -1 bearish / 0 neutral from the most recent break of structure
// on `htf`: find the newest HTF swing high and swing low (3-bar fractal), then whichever
// was most recently taken out by a subsequent close (higher-high break = bullish BOS,
// lower-low break = bearish BOS) sets the bias. Neutral when neither has broken (range).
int ICT_HTFBias(const ENUM_TIMEFRAMES htf, const int lookback)
  {
   int sh_shift = -1, sl_shift = -1;
   double sh = 0.0, sl = 0.0;
   for(int s = 2; s <= lookback && (sh_shift < 0 || sl_shift < 0); ++s)
     {
      const double h  = iHigh(_Symbol, htf, s);     // perf-allowed: bounded HTF fractal scan
      const double hL = iHigh(_Symbol, htf, s - 1);  // perf-allowed
      const double hR = iHigh(_Symbol, htf, s + 1);  // perf-allowed
      const double l  = iLow(_Symbol, htf, s);       // perf-allowed
      const double lL = iLow(_Symbol, htf, s - 1);    // perf-allowed
      const double lR = iLow(_Symbol, htf, s + 1);    // perf-allowed
      if(h <= 0.0 || l <= 0.0)
         continue;
      if(sh_shift < 0 && h > hL && h > hR) { sh = h; sh_shift = s; }
      if(sl_shift < 0 && l < lL && l < lR) { sl = l; sl_shift = s; }
     }
   if(sh_shift < 0 || sl_shift < 0)
      return 0;

   int bull_break = -1;
   for(int s = 1; s < sh_shift; ++s)
      if(iClose(_Symbol, htf, s) > sh) { bull_break = s; break; } // perf-allowed: most recent close above the swing high
   int bear_break = -1;
   for(int s = 1; s < sl_shift; ++s)
      if(iClose(_Symbol, htf, s) < sl) { bear_break = s; break; } // perf-allowed: most recent close below the swing low

   if(bull_break < 0 && bear_break < 0)
      return 0;
   if(bull_break < 0)
      return -1;
   if(bear_break < 0)
      return +1;
   return (bull_break <= bear_break) ? +1 : -1; // the more recent break (smaller shift) wins
  }

// -----------------------------------------------------------------------------
// Liquidity pools — spec Ch3 S1 (EQH/EQL + fixed daily/weekly levels)
// -----------------------------------------------------------------------------

void ICT_AppendOne(double &arr[], const double value)
  {
   const int idx = ArraySize(arr);
   ArrayResize(arr, idx + 1);
   arr[idx] = value;
  }

void ICT_AppendAll(double &dst[], const double &src[])
  {
   const int base = ArraySize(dst);
   const int add  = ArraySize(src);
   if(add <= 0)
      return;
   ArrayResize(dst, base + add);
   for(int i = 0; i < add; ++i)
      dst[base + i] = src[i];
  }

// spec Ch3 S1: cluster >=2 swings within `tol` of each other; level = their mean.
void ICT_ClusterEqual(const double &src[], const int src_count, const double tol, double &out_levels[])
  {
   ArrayResize(out_levels, 0);
   if(src_count < 2 || tol <= 0.0)
      return;
   bool used[ICT_SWING_MAX];
   for(int z = 0; z < ICT_SWING_MAX; ++z)
      used[z] = false;

   for(int i = 0; i < src_count; ++i)
     {
      if(used[i])
         continue;
      double sum = src[i];
      int n = 1;
      used[i] = true;
      for(int j = i + 1; j < src_count; ++j)
        {
         if(used[j])
            continue;
         if(MathAbs(src[i] - src[j]) <= tol)
           {
            sum += src[j];
            n++;
            used[j] = true;
           }
        }
      if(n >= 2)
         ICT_AppendOne(out_levels, sum / n);
     }
  }

// spec Ch3 S1: tolerance = pips OR ATR14 fraction, whichever is wider.
double ICT_EqualTolerance()
  {
   const double atr = QM_ATR(_Symbol, ExecutionTF, 14, 1);
   const double pip_tol = ICT_PipsToPrice(_Symbol, EqualTolerance_Pips);
   const double atr_tol = (atr > 0.0) ? EqualTolerance_ATRfrac * atr : 0.0;
   return MathMax(pip_tol, atr_tol);
  }

// spec Ch2.3/Ch3 S1: most recently completed Asian session (20:00-00:00 NY). Scans
// backward on `tf` (HTF_Context_M15) collecting the newest contiguous NY-hour-20..23
// block; stops once it moves past that block.
bool ICT_AsianRange(const ENUM_TIMEFRAMES tf, double &out_high, double &out_low)
  {
   out_high = -DBL_MAX;
   out_low  = DBL_MAX;
   bool started = false;
   int match_year = -1, match_mon = -1, match_day = -1;

   for(int s = 1; s <= 400; ++s)
     {
      const datetime t = iTime(_Symbol, tf, s); // perf-allowed
      if(t <= 0)
         break;
      MqlDateTime ny;
      ICT_BrokerTimeToNY(t, ny);
      const bool in_window = (ny.hour >= 20 && ny.hour < 24);
      if(in_window)
        {
         if(!started)
           {
            started = true;
            match_year = ny.year; match_mon = ny.mon; match_day = ny.day;
           }
         else if(ny.year != match_year || ny.mon != match_mon || ny.day != match_day)
            break; // walked into an older Asian session block

         const double h = iHigh(_Symbol, tf, s); // perf-allowed
         const double l = iLow(_Symbol, tf, s); // perf-allowed
         if(h > 0.0 && h > out_high) out_high = h;
         if(l > 0.0 && l < out_low)  out_low = l;
        }
      else if(started)
         break; // most recent Asian block fully collected
     }
   return (out_high > -DBL_MAX && out_low < DBL_MAX);
  }

// spec Ch3 S1: previous calendar week (Mon-Fri) high/low, from broker-time D1 bars
// (week-level boundaries are far less DST-sensitive than intraday killzones; this
// mirrors the precedent in QM5_10095's weekly-open scan).
bool ICT_PrevWeekRange(double &out_high, double &out_low)
  {
   out_high = -DBL_MAX;
   out_low  = DBL_MAX;
   const datetime t0 = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed
   if(t0 <= 0)
      return false;
   MqlDateTime d0;
   TimeToStruct(t0, d0);
   const int dow = d0.day_of_week; // 0=Sun..6=Sat
   const int days_since_monday = (dow == 0) ? 6 : (dow - 1);
   MqlDateTime monday_dt = d0;
   monday_dt.hour = 0; monday_dt.min = 0; monday_dt.sec = 0;
   const datetime this_monday = StructToTime(monday_dt) - (datetime)(days_since_monday * 86400);
   const datetime prev_monday = this_monday - (datetime)(7 * 86400);

   bool found = false;
   for(int s = 1; s <= 30; ++s)
     {
      const datetime t = iTime(_Symbol, PERIOD_D1, s); // perf-allowed
      if(t <= 0)
         break;
      if(t < prev_monday)
         break;
      if(t < this_monday)
        {
         const double h = iHigh(_Symbol, PERIOD_D1, s); // perf-allowed
         const double l = iLow(_Symbol, PERIOD_D1, s); // perf-allowed
         if(h > 0.0 && h > out_high) out_high = h;
         if(l > 0.0 && l < out_low)  out_low = l;
         found = true;
        }
     }
   return found;
  }

// spec Ch3 S1: SSL side (EQL clusters + PDL + Asian Low + Previous Week Low).
void ICT_BuildLowPools(double &out_levels[])
  {
   ArrayResize(out_levels, 0);
   const double tol = ICT_EqualTolerance();
   double eq[];
   ICT_ClusterEqual(g_ict_sw_low_price, g_ict_sw_low_count, tol, eq);
   ICT_AppendAll(out_levels, eq);

   const double pdl = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed
   if(pdl > 0.0)
      ICT_AppendOne(out_levels, pdl);

   double ah = 0.0, al = 0.0;
   if(ICT_AsianRange(HTF_Context_M15, ah, al) && al > 0.0)
      ICT_AppendOne(out_levels, al);

   double wh = 0.0, wl = 0.0;
   if(ICT_PrevWeekRange(wh, wl) && wl > 0.0)
      ICT_AppendOne(out_levels, wl);
  }

// spec Ch3 S1: BSL side (EQH clusters + PDH + Asian High + Previous Week High).
void ICT_BuildHighPools(double &out_levels[])
  {
   ArrayResize(out_levels, 0);
   const double tol = ICT_EqualTolerance();
   double eq[];
   ICT_ClusterEqual(g_ict_sw_high_price, g_ict_sw_high_count, tol, eq);
   ICT_AppendAll(out_levels, eq);

   const double pdh = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed
   if(pdh > 0.0)
      ICT_AppendOne(out_levels, pdh);

   double ah = 0.0, al = 0.0;
   if(ICT_AsianRange(HTF_Context_M15, ah, al) && ah > 0.0)
      ICT_AppendOne(out_levels, ah);

   double wh = 0.0, wl = 0.0;
   if(ICT_PrevWeekRange(wh, wl) && wh > 0.0)
      ICT_AppendOne(out_levels, wh);
  }

bool ICT_NearestAbove(const double &pools[], const int n, const double reference, double &out)
  {
   bool found = false;
   double best = 0.0;
   for(int i = 0; i < n; ++i)
      if(pools[i] > reference && (!found || pools[i] < best))
        {
         best = pools[i];
         found = true;
        }
   out = best;
   return found;
  }

bool ICT_NearestBelow(const double &pools[], const int n, const double reference, double &out)
  {
   bool found = false;
   double best = 0.0;
   for(int i = 0; i < n; ++i)
      if(pools[i] < reference && (!found || pools[i] > best))
        {
         best = pools[i];
         found = true;
        }
   out = best;
   return found;
  }

// -----------------------------------------------------------------------------
// Liquidity sweep (manipulation) — spec Ch3 S2
// -----------------------------------------------------------------------------

// Fires exactly once, on the bar where the reclaim is confirmed: some bar in the
// last `sweep_return_bars` made Low<level (the sweep), and THIS closed bar is the
// first one to close back above level (immediate same-bar rejection is s=1).
bool ICT_LowLevelJustSwept(const double level, const int sweep_return_bars, double &sweep_extreme)
  {
   if(level <= 0.0 || sweep_return_bars < 1)
      return false;
   const double close1 = iClose(_Symbol, ExecutionTF, 1); // perf-allowed
   const double close2 = iClose(_Symbol, ExecutionTF, 2); // perf-allowed
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;
   if(close1 <= level)
      return false; // not reclaimed on this bar
   if(close2 > level)
      return false; // already reclaimed earlier -> not a fresh event

   double lowest = DBL_MAX;
   bool swept = false;
   for(int s = 1; s <= sweep_return_bars; ++s)
     {
      const double lo = iLow(_Symbol, ExecutionTF, s); // perf-allowed
      if(lo <= 0.0)
         break;
      if(lo < level)
         swept = true;
      if(lo < lowest)
         lowest = lo;
     }
   if(!swept)
      return false;
   sweep_extreme = lowest;
   return true;
  }

bool ICT_HighLevelJustSwept(const double level, const int sweep_return_bars, double &sweep_extreme)
  {
   if(level <= 0.0 || sweep_return_bars < 1)
      return false;
   const double close1 = iClose(_Symbol, ExecutionTF, 1); // perf-allowed
   const double close2 = iClose(_Symbol, ExecutionTF, 2); // perf-allowed
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;
   if(close1 >= level)
      return false;
   if(close2 < level)
      return false;

   double highest = 0.0;
   bool swept = false;
   for(int s = 1; s <= sweep_return_bars; ++s)
     {
      const double hi = iHigh(_Symbol, ExecutionTF, s); // perf-allowed
      if(hi <= 0.0)
         break;
      if(hi > level)
         swept = true;
      if(hi > highest)
         highest = hi;
     }
   if(!swept)
      return false;
   sweep_extreme = highest;
   return true;
  }

// spec Ch5.5: SMT-Divergenz optional confluence filter. Phase 1 stub — always
// passes (no-op) so UseSMT=true has zero effect until a real DXY/GBPUSD/ES-YM
// correlation check lands in Phase 2/3.
bool ICT_Setup_SMT_Confirms(const bool is_low_side_sweep)
  {
   return true;
  }

// -----------------------------------------------------------------------------
// MSS + displacement + FVG/OB entry construction — spec Ch3 S3/S4/S5/S6, Ch4
// -----------------------------------------------------------------------------

// spec Ch3 S3/S4 + Ch4: the TWO-PHASE core model. The displacement impulse (sweep ->
// MSS break) LEAVES a Fair Value Gap somewhere inside the leg; the entry is a limit that
// waits for price to RETRACE back into that gap, filtered to the discount half of the
// dealing range. The prior build collapsed both phases onto the MSS bar (it demanded a
// 3-candle FVG in exactly bars 1-3 and it measured premium/discount off a 2-bar leg),
// which fired ~4x/yr on EURUSD M1 and structurally landed the FVG in premium. This scans
// the whole impulse leg for the displacement FVG and selects the highest qualifying gap
// still in discount (the first level price meets on the retrace down).
bool ICT_TryBuildLongEntry(const ICT_Pending &pending, QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, ExecutionTF, 14, 1);
   if(atr <= 0.0)
      return false;

   // spec Ch6 Richtungsfilter: no longs against a bearish HTF structure break.
   if(UseHTFBias && ICT_HTFBias(HTF_Context_H1, HTFBiasLookback) < 0)
      return false;

   // Impulse leg = sweep bar .. MSS bar (shift 1). bars_waited bars have elapsed since the
   // sweep was registered; scan that span plus a small margin, capped (spec Ch3 S3/S4).
   const int leg = MathMax(3, MathMin(pending.bars_waited + SwingLookback + 3, ICT_IMPULSE_MAX));

   // spec Ch3 S4 dealing-range top = highest high across the impulse leg.
   double impulse_high = 0.0;
   for(int k = 1; k <= leg; ++k)
     {
      const double h = iHigh(_Symbol, ExecutionTF, k); // perf-allowed
      if(h > impulse_high) impulse_high = h;
     }
   const double dealing_range = impulse_high - pending.sweep_extreme;
   if(dealing_range <= 0.0)
      return false;
   const double discount_ceiling = pending.sweep_extreme + 0.5 * dealing_range; // entry <= this = discount

   // spec Ch4 Baustein FVG: scan every 3-candle window in the leg for a bullish FVG
   // (Low(C) > High(A); zone [High(A), Low(C)]). Keep the highest qualifying candidate
   // still in discount = the first gap price reaches on the retrace back down.
   bool any_fvg = false, have_fvg = false;
   double fvg_entry = 0.0, fvg_low_sel = 0.0, fvg_high_sel = 0.0;
   for(int i = 1; i <= leg; ++i)
     {
      const double low_c  = iLow(_Symbol, ExecutionTF, i);     // perf-allowed  (C, newer)
      const double high_a = iHigh(_Symbol, ExecutionTF, i + 2); // perf-allowed  (A, older)
      if(low_c <= 0.0 || high_a <= 0.0 || low_c <= high_a)
         continue;
      if((low_c - high_a) < ICT_PointsToPrice(_Symbol, FVG_MinPoints))
         continue;
      any_fvg = true;
      const double fl = high_a, fh = low_c;
      const double cand = (EntryMode == ICT_ENTRY_FVG_CE) ? (fl + fh) * 0.5 : fh; // CE or upper edge
      if(cand <= 0.0)
         continue;
      if(PremiumDiscountFilter && cand > discount_ceiling)
         continue; // spec Ch3 S4: longs only in discount
      if(!have_fvg || cand > fvg_entry) // highest qualifying = first touched on the retrace
        {
         have_fvg = true;
         fvg_entry = cand;
         fvg_low_sel = fl;
         fvg_high_sel = fh;
        }
     }

   // spec Ch3 S3: displacement = FVG-in-impulse (mandatory by default) AND/OR MSS-bar body>=k*ATR.
   const double body_c = MathAbs(iClose(_Symbol, ExecutionTF, 1) - iOpen(_Symbol, ExecutionTF, 1)); // perf-allowed
   const bool body_ok = body_c >= DisplacementATR * atr;
   const bool displacement_ok = RequireFVGInImpulse ? any_fvg : (any_fvg || body_ok);
   if(!displacement_ok)
      return false;

   if(UseSMT && !ICT_Setup_SMT_Confirms(true))
      return false;

   double entry_price = 0.0;
   if(EntryMode == ICT_ENTRY_OB_MT)
     {
      // spec Ch4 Baustein OB: last down-close candle in the leg; zone [Open,Low], MT=50%.
      // Keep the highest OB-MT still in discount (first touched on the retrace).
      bool ob_found = false; double best_mt = 0.0;
      for(int k = 1; k <= leg; ++k)
        {
         const double o  = iOpen(_Symbol, ExecutionTF, k); // perf-allowed
         const double c  = iClose(_Symbol, ExecutionTF, k); // perf-allowed
         const double lo = iLow(_Symbol, ExecutionTF, k); // perf-allowed
         if(o <= 0.0 || c <= 0.0 || lo <= 0.0 || c >= o)
            continue;
         const double mt = (o + lo) * 0.5;
         if(PremiumDiscountFilter && mt > discount_ceiling)
            continue;
         if(!ob_found || mt > best_mt) { best_mt = mt; ob_found = true; }
        }
      if(!ob_found) return false;
      entry_price = best_mt;
     }
   else
     {
      if(!have_fvg) return false;
      entry_price = fvg_entry;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0 || entry_price >= ask)
      return false; // must be a genuine buy-limit level below current market

   // spec Ch3 S4: optional OTE 0.62-0.79 refinement on the dealing range.
   if(UseOTE)
     {
      const double frac = (impulse_high - entry_price) / dealing_range;
      if(frac < 0.62 || frac > 0.79) return false;
     }

   // spec Ch3 S5: stop-loss = sweep extreme minus a buffer.
   double sl = pending.sweep_extreme - ICT_PointsToPrice(_Symbol, SL_BufferPoints);
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0 || sl >= entry_price)
      return false;

   // spec Ch3 S6: TP = nearest opposite external liquidity beyond entry. No fixed pip TP.
   double high_pools[];
   ICT_BuildHighPools(high_pools);
   double tp = 0.0;
   if(!ICT_NearestAbove(high_pools, ArraySize(high_pools), entry_price, tp))
      return false;
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   if(tp <= entry_price)
      return false;

   const double rr = (tp - entry_price) / (entry_price - sl);
   if(rr < MinRR)
      return false;

   req.type = QM_BUY_LIMIT;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry_price);
   req.sl = sl;
   req.tp = tp;
   req.reason = "ict-icytea-core-long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = ICT_MSS_PENDING_EXPIRY_BARS * PeriodSeconds(ExecutionTF);
   return true;
  }

// Exact mirror of ICT_TryBuildLongEntry (spec Ch3 opener: "die Short-Seite ist exakt
// gespiegelt"): impulse-leg scan for the displacement bearish FVG, entry limit waiting
// for the retrace UP into it, filtered to the premium half of the dealing range.
bool ICT_TryBuildShortEntry(const ICT_Pending &pending, QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, ExecutionTF, 14, 1);
   if(atr <= 0.0)
      return false;

   // spec Ch6 Richtungsfilter: no shorts against a bullish HTF structure break.
   if(UseHTFBias && ICT_HTFBias(HTF_Context_H1, HTFBiasLookback) > 0)
      return false;

   const int leg = MathMax(3, MathMin(pending.bars_waited + SwingLookback + 3, ICT_IMPULSE_MAX));

   // dealing-range bottom = lowest low across the impulse leg.
   double impulse_low = DBL_MAX;
   for(int k = 1; k <= leg; ++k)
     {
      const double l = iLow(_Symbol, ExecutionTF, k); // perf-allowed
      if(l > 0.0 && l < impulse_low) impulse_low = l;
     }
   if(impulse_low == DBL_MAX)
      return false;
   const double dealing_range = pending.sweep_extreme - impulse_low;
   if(dealing_range <= 0.0)
      return false;
   const double premium_floor = pending.sweep_extreme - 0.5 * dealing_range; // entry >= this = premium

   // spec Ch4 Baustein FVG: bearish FVG = High(C) < Low(A); zone [High(C), Low(A)].
   // Keep the LOWEST qualifying candidate still in premium = first touched on the retrace up.
   bool any_fvg = false, have_fvg = false;
   double fvg_entry = 0.0, fvg_low_sel = 0.0, fvg_high_sel = 0.0;
   for(int i = 1; i <= leg; ++i)
     {
      const double high_c = iHigh(_Symbol, ExecutionTF, i);    // perf-allowed  (C, newer)
      const double low_a  = iLow(_Symbol, ExecutionTF, i + 2); // perf-allowed  (A, older)
      if(high_c <= 0.0 || low_a <= 0.0 || high_c >= low_a)
         continue;
      if((low_a - high_c) < ICT_PointsToPrice(_Symbol, FVG_MinPoints))
         continue;
      any_fvg = true;
      const double fl = high_c, fh = low_a;
      const double cand = (EntryMode == ICT_ENTRY_FVG_CE) ? (fl + fh) * 0.5 : fl; // CE or lower edge
      if(cand <= 0.0)
         continue;
      if(PremiumDiscountFilter && cand < premium_floor)
         continue; // spec Ch3 S4: shorts only in premium
      if(!have_fvg || cand < fvg_entry) // lowest qualifying = first touched on the retrace up
        {
         have_fvg = true;
         fvg_entry = cand;
         fvg_low_sel = fl;
         fvg_high_sel = fh;
        }
     }

   const double body_c = MathAbs(iClose(_Symbol, ExecutionTF, 1) - iOpen(_Symbol, ExecutionTF, 1)); // perf-allowed
   const bool body_ok = body_c >= DisplacementATR * atr;
   const bool displacement_ok = RequireFVGInImpulse ? any_fvg : (any_fvg || body_ok);
   if(!displacement_ok)
      return false;

   if(UseSMT && !ICT_Setup_SMT_Confirms(false))
      return false;

   double entry_price = 0.0;
   if(EntryMode == ICT_ENTRY_OB_MT)
     {
      // spec Ch4 Baustein OB (bearish): last up-close candle in the leg; zone [Open,High], MT=50%.
      bool ob_found = false; double best_mt = 0.0;
      for(int k = 1; k <= leg; ++k)
        {
         const double o  = iOpen(_Symbol, ExecutionTF, k); // perf-allowed
         const double c  = iClose(_Symbol, ExecutionTF, k); // perf-allowed
         const double hi = iHigh(_Symbol, ExecutionTF, k); // perf-allowed
         if(o <= 0.0 || c <= 0.0 || hi <= 0.0 || c <= o)
            continue;
         const double mt = (o + hi) * 0.5;
         if(PremiumDiscountFilter && mt < premium_floor)
            continue;
         if(!ob_found || mt < best_mt) { best_mt = mt; ob_found = true; }
        }
      if(!ob_found) return false;
      entry_price = best_mt;
     }
   else
     {
      if(!have_fvg) return false;
      entry_price = fvg_entry;
     }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0 || entry_price <= bid)
      return false; // must be a genuine sell-limit level above current market

   if(UseOTE)
     {
      const double frac = (entry_price - impulse_low) / dealing_range;
      if(frac < 0.62 || frac > 0.79) return false;
     }

   double sl = pending.sweep_extreme + ICT_PointsToPrice(_Symbol, SL_BufferPoints);
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0 || sl <= entry_price)
      return false;

   double low_pools[];
   ICT_BuildLowPools(low_pools);
   double tp = 0.0;
   if(!ICT_NearestBelow(low_pools, ArraySize(low_pools), entry_price, tp))
      return false;
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   if(tp <= 0.0 || tp >= entry_price)
      return false;

   const double rr = (entry_price - tp) / (sl - entry_price);
   if(rr < MinRR)
      return false;

   req.type = QM_SELL_LIMIT;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry_price);
   req.sl = sl;
   req.tp = tp;
   req.reason = "ict-icytea-core-short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = ICT_MSS_PENDING_EXPIRY_BARS * PeriodSeconds(ExecutionTF);
   return true;
  }

// -----------------------------------------------------------------------------
// Per-side state machine: sweep -> pending -> MSS break -> entry construction
// -----------------------------------------------------------------------------

bool ICT_ProcessLong(QM_EntryRequest &req)
  {
   if(g_ict_pending_long.active)
     {
      g_ict_pending_long.bars_waited++;
      if(g_ict_pending_long.bars_waited > ICT_MSS_PENDING_EXPIRY_BARS)
         g_ict_pending_long.active = false;
     }

   if(g_ict_pending_long.active)
     {
      const double close1 = iClose(_Symbol, ExecutionTF, 1); // perf-allowed
      if(close1 > g_ict_pending_long.target_swing) // spec Ch3 S3: body-close break of the last relevant swing high
        {
         const bool ok = ICT_TryBuildLongEntry(g_ict_pending_long, req);
         g_ict_pending_long.active = false; // structure resolved either way (Phase 1 simplification)
         if(ok)
            return true;
        }
      return false; // still waiting on this pending sweep, or just resolved without a trade
     }

   double low_pools[];
   ICT_BuildLowPools(low_pools);
   const int n = ArraySize(low_pools);
   if(n <= 0 || g_ict_sw_high_count <= 0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double best_extreme = 0.0, best_level = 0.0, best_dist = DBL_MAX;
   bool found = false;
   for(int i = 0; i < n; ++i)
     {
      double extreme = 0.0;
      if(ICT_LowLevelJustSwept(low_pools[i], SweepReturnBars, extreme))
        {
         const double dist = MathAbs(bid - low_pools[i]);
         if(dist < best_dist)
           {
            best_dist = dist;
            best_level = low_pools[i];
            best_extreme = extreme;
            found = true;
           }
        }
     }
   if(!found)
      return false;
   if(UseSMT && !ICT_Setup_SMT_Confirms(true))
      return false;

   g_ict_pending_long.active = true;
   g_ict_pending_long.sweep_extreme = best_extreme;
   g_ict_pending_long.swept_level = best_level;
   g_ict_pending_long.target_swing = g_ict_sw_high_price[0]; // spec Ch3 S3: last relevant swing high before the swept low
   g_ict_pending_long.bars_waited = 0;

   const double close1b = iClose(_Symbol, ExecutionTF, 1); // perf-allowed
   if(close1b > g_ict_pending_long.target_swing) // same-bar sweep+reclaim+MSS
     {
      const bool ok2 = ICT_TryBuildLongEntry(g_ict_pending_long, req);
      g_ict_pending_long.active = false;
      if(ok2)
         return true;
     }
   return false;
  }

bool ICT_ProcessShort(QM_EntryRequest &req)
  {
   if(g_ict_pending_short.active)
     {
      g_ict_pending_short.bars_waited++;
      if(g_ict_pending_short.bars_waited > ICT_MSS_PENDING_EXPIRY_BARS)
         g_ict_pending_short.active = false;
     }

   if(g_ict_pending_short.active)
     {
      const double close1 = iClose(_Symbol, ExecutionTF, 1); // perf-allowed
      if(close1 < g_ict_pending_short.target_swing)
        {
         const bool ok = ICT_TryBuildShortEntry(g_ict_pending_short, req);
         g_ict_pending_short.active = false;
         if(ok)
            return true;
        }
      return false;
     }

   double high_pools[];
   ICT_BuildHighPools(high_pools);
   const int n = ArraySize(high_pools);
   if(n <= 0 || g_ict_sw_low_count <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double best_extreme = 0.0, best_level = 0.0, best_dist = DBL_MAX;
   bool found = false;
   for(int i = 0; i < n; ++i)
     {
      double extreme = 0.0;
      if(ICT_HighLevelJustSwept(high_pools[i], SweepReturnBars, extreme))
        {
         const double dist = MathAbs(ask - high_pools[i]);
         if(dist < best_dist)
           {
            best_dist = dist;
            best_level = high_pools[i];
            best_extreme = extreme;
            found = true;
           }
        }
     }
   if(!found)
      return false;
   if(UseSMT && !ICT_Setup_SMT_Confirms(false))
      return false;

   g_ict_pending_short.active = true;
   g_ict_pending_short.sweep_extreme = best_extreme;
   g_ict_pending_short.swept_level = best_level;
   g_ict_pending_short.target_swing = g_ict_sw_low_price[0];
   g_ict_pending_short.bars_waited = 0;

   const double close1b = iClose(_Symbol, ExecutionTF, 1); // perf-allowed
   if(close1b < g_ict_pending_short.target_swing)
     {
      const bool ok2 = ICT_TryBuildShortEntry(g_ict_pending_short, req);
      g_ict_pending_short.active = false;
      if(ok2)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// spec Ch6: MaxTradesPerKZ — counted from filled entries (opening deals) for this
// magic/symbol within today's NY calendar day, scoped to the given killzone window.
// -----------------------------------------------------------------------------

int ICT_KillzoneTradeCount(const string kz_id, const datetime broker_now)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   MqlDateTime ny_now;
   ICT_BrokerTimeToNY(broker_now, ny_now);

   const datetime scan_from = broker_now - (datetime)(26 * 3600);
   if(!HistorySelect(scan_from, broker_now))
      return 0;

   int count = 0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;

      const datetime dt = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      MqlDateTime deal_ny;
      ICT_BrokerTimeToNY(dt, deal_ny);
      if(deal_ny.year != ny_now.year || deal_ny.day_of_year != ny_now.day_of_year)
         continue; // resets each NY calendar day/session

      bool in_this_kz = false;
      if(kz_id == "LONDON")
         in_this_kz = (deal_ny.hour >= ICT_KZ_LONDON_START && deal_ny.hour < ICT_KZ_LONDON_END);
      else if(kz_id == "NEWYORK")
         in_this_kz = (deal_ny.hour >= ICT_KZ_NEWYORK_START && deal_ny.hour < ICT_KZ_NEWYORK_END);

      if(in_this_kz)
         count++;
     }
   return count;
  }

// -----------------------------------------------------------------------------
// spec Ch5: Setup-variant module hooks. Phase 1 = core model only; every stub is a
// deliberate no-op (returns false) so Phase 2/3 can fill them in without touching
// the framework wiring or the core sweep->MSS->FVG/OB pipeline above.
// -----------------------------------------------------------------------------

bool ICT_Setup_Judas_Entry(QM_EntryRequest &req)       { return false; } // spec Ch5.1
bool ICT_Setup_TurtleSoup_Entry(QM_EntryRequest &req)  { return false; } // spec Ch5.2
bool ICT_Setup_Unicorn_Entry(QM_EntryRequest &req)     { return false; } // spec Ch5.3
bool ICT_Setup_SilverBullet_Entry(QM_EntryRequest &req){ return false; } // spec Ch5.4
bool ICT_Setup_TGIF_Entry(QM_EntryRequest &req)        { return false; } // spec Ch5.8
bool ICT_Setup_3Drives_Entry(QM_EntryRequest &req)     { return false; } // spec Ch5.6
bool ICT_Setup_MMxM_Entry(QM_EntryRequest &req)        { return false; } // spec Ch5.7
bool ICT_Setup_IndexMacro_Entry(QM_EntryRequest &req)  { return false; } // spec Ch5.9

// -----------------------------------------------------------------------------
// spec Ch3 S6: partial-then-breakeven position state
// -----------------------------------------------------------------------------

int ICT_PosStateFind(const ulong position_id)
  {
   for(int i = ArraySize(g_ict_pos_state) - 1; i >= 0; --i)
      if(g_ict_pos_state[i].position_id == position_id)
         return i;
   return -1;
  }

int ICT_PosStateUpsert(const ulong position_id)
  {
   const int idx = ICT_PosStateFind(position_id);
   if(idx >= 0)
      return idx;
   const int n = ArraySize(g_ict_pos_state);
   ArrayResize(g_ict_pos_state, n + 1);
   g_ict_pos_state[n].position_id = position_id;
   g_ict_pos_state[n].partial_done = false;
   g_ict_pos_state[n].be_done = false;
   return n;
  }

void ICT_PosStatePrune()
  {
   for(int i = ArraySize(g_ict_pos_state) - 1; i >= 0; --i)
     {
      bool still_open = false;
      for(int p = PositionsTotal() - 1; p >= 0; --p)
        {
         const ulong t = PositionGetTicket(p);
         if(t == 0 || !PositionSelectByTicket(t))
            continue;
         if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == g_ict_pos_state[i].position_id)
           {
            still_open = true;
            break;
           }
        }
      if(!still_open)
        {
         const int last = ArraySize(g_ict_pos_state) - 1;
         g_ict_pos_state[i] = g_ict_pos_state[last];
         ArrayResize(g_ict_pos_state, last);
        }
     }
  }

// -----------------------------------------------------------------------------
// No-Trade module — spec Ch2.3/Ch6 (killzone + MaxTradesPerKZ + news + Friday)
// -----------------------------------------------------------------------------

// spec Ch2.3/Ch6 killzone timing and MaxTradesPerKZ gating are enforced inside
// Strategy_EntrySignal instead of here. Reason: the framework's OnTick wiring
// (mirrored below from QM5_10628/QM5_10095) hard-returns the whole tick when this
// function is true, which would also skip Strategy_ManageOpenPosition and
// Strategy_ExitSignal — starving partial/breakeven management and the day-end
// flat for positions still open once the killzone that opened them has ended.
// Both reference EAs leave this as a pure pass-through for the identical reason;
// news and Friday-close are already handled unconditionally by the framework's
// OnTick before this hook runs.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry module — spec Ch3 (core model) + Ch5 (setup hooks)
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // spec Ch2.3/Ch6: killzone timing + MaxTradesPerKZ gate new entries (see
   // Strategy_NoTradeFilter above for why this check lives here).
   const datetime broker_now = TimeCurrent();
   const bool in_london = KZ_London_on && ICT_InKillzone(broker_now, ICT_KZ_LONDON_START, ICT_KZ_LONDON_END, TZ_Offset_NYtoBroker);
   const bool in_ny     = KZ_NewYork_on && ICT_InKillzone(broker_now, ICT_KZ_NEWYORK_START, ICT_KZ_NEWYORK_END, TZ_Offset_NYtoBroker);
   if(!in_london && !in_ny)
      return false;
   const string kz_id = in_london ? "LONDON" : "NEWYORK";
   if(ICT_KillzoneTradeCount(kz_id, broker_now) >= MaxTradesPerKZ)
      return false;

   // avoid stacking a second pending limit order for this magic/symbol
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return false;
     }

   const int needed = 2 * SwingLookback + ICT_OB_SEARCH_WINDOW + 10;
   if(Bars(_Symbol, ExecutionTF) < needed) // perf-allowed
      return false;

   ICT_UpdateSwings(SwingLookback); // spec Ch3 S1

   if(TradeLongs && ICT_ProcessLong(req))
      return true;
   if(TradeShorts && ICT_ProcessShort(req))
      return true;

   // spec Ch5: Phase-2/3 setup-module hooks — every stub is a no-op in Phase 1.
   if(Setup_Judas && ICT_Setup_Judas_Entry(req)) return true;
   if(Setup_TurtleSoup && ICT_Setup_TurtleSoup_Entry(req)) return true;
   if(Setup_Unicorn && ICT_Setup_Unicorn_Entry(req)) return true;
   if(Setup_SilverBullet && ICT_Setup_SilverBullet_Entry(req)) return true;
   if(Setup_TGIF && ICT_Setup_TGIF_Entry(req)) return true;
   if(Setup_3Drives && ICT_Setup_3Drives_Entry(req)) return true;
   if(Setup_MMxM && ICT_Setup_MMxM_Entry(req)) return true;
   if(Setup_IndexMacro && ICT_Setup_IndexMacro_Entry(req)) return true;

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management module — spec Ch3 S6 / Ch6 (partial at PartialAt, then breakeven)
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const int idx = ICT_PosStateUpsert(position_id);

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double tp = PositionGetDouble(POSITION_TP);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || tp <= 0.0 || volume <= 0.0)
         continue;

      // spec Ch3 S6: partial at PartialAt% of the entry->TP distance.
      if(!g_ict_pos_state[idx].partial_done)
        {
         const double trigger = is_buy
            ? open_price + (tp - open_price) * (PartialAt / 100.0)
            : open_price - (open_price - tp) * (PartialAt / 100.0);
         const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const bool reached = is_buy ? (market >= trigger) : (market <= trigger);
         if(reached)
           {
            const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * (PartialPct / 100.0));
            if(close_lots > 0.0 && close_lots < volume)
              {
               if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
                  g_ict_pos_state[idx].partial_done = true;
              }
            else
              {
               // PartialPct rounds to the whole position at the broker's volume step;
               // nothing left to run as a "breakeven runner" so skip the BE move too.
               g_ict_pos_state[idx].partial_done = true;
               g_ict_pos_state[idx].be_done = true;
              }
           }
        }

      // spec Ch3 S6: "Danach Stop auf Breakeven" — immediately after the partial.
      if(BreakevenAfterPartial && g_ict_pos_state[idx].partial_done && !g_ict_pos_state[idx].be_done)
        {
         if(QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "breakeven_after_partial"))
            g_ict_pos_state[idx].be_done = true;
        }
     }

   ICT_PosStatePrune();
  }

// -----------------------------------------------------------------------------
// Trade Close module — spec Ch3 S6 / Ch6: flatten by day-end. Hard TP at the
// opposite liquidity pool is set as the order's TP in Strategy_EntrySignal, not
// re-checked here.
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   MqlDateTime ny;
   ICT_BrokerTimeToNY(TimeCurrent(), ny);
   static int s_last_flat_ny_day_key = -1;
   const int day_key = ny.year * 1000 + ny.day_of_year;
   if(ny.hour == 0 && day_key != s_last_flat_ny_day_key)
     {
      s_last_flat_ny_day_key = day_key;
      return true; // spec Ch3 S6/Ch6: "spätestens zum Tagesende schließen" (NY midnight)
     }
   return false;
  }

// News Filter Hook: no custom overlay beyond the framework's two-axis news filter
// (spec Ch5.10: Phase-1 recommendation is a blanket pause around high-impact news,
// which the framework's News group already provides).
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   g_ict_pending_long.active = false;
   g_ict_pending_short.active = false;
   ArrayResize(g_ict_pos_state, 0);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20002_ict-icytea-core\"}");
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
