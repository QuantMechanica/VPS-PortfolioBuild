//+------------------------------------------------------------------+
//| QM_PatternPermission.mqh                                          |
//| Closed-bar, fail-closed directional permission gate.              |
//|                                                                    |
//| OPT-IN ONLY. This file is deliberately NOT included by            |
//| QM_Common.mqh: pulling it into the umbrella would force a         |
//| fleet-wide recompile and hash churn on every live sleeve.         |
//| An EA that wants the gate includes it directly.                   |
//|                                                                    |
//| Contract (plan v2, docs/research/PATTERN_PERMISSION_FILTER_       |
//| PLAN_V2_2026-08-13.md):                                           |
//|  - evaluates ONLY closed bars: closed_shift >= 1, shift 0 is      |
//|    rejected at the API boundary (the reference implementation     |
//|    read the forming bar and therefore repainted);                 |
//|  - FAILS CLOSED: any missing/short/invalid history yields         |
//|    valid=false with BOTH directions blocked (the reference        |
//|    implementation fails open, which silently disables the gate);  |
//|  - deterministic: the decision is cached per                      |
//|    (symbol, timeframe, reference_bar_time, profile) so tick       |
//|    cadence, restarts and reinitialisation cannot change it;       |
//|  - pure: never touches orders, positions, stops, risk, the news   |
//|    gate or the kill switch. Those keep absolute precedence.       |
//|                                                                    |
//| Predicate numbering intentionally mirrors the source reference so |
//| every predicate stays traceable to its origin. Kill-list ids      |
//| (SMC/ICT/FVG/order-block/BOS/ChoCh 61-76, Wyckoff 85/86, Hurst    |
//| 95/96, the mislabelled "correlation" 97) are NOT implemented and  |
//| their numbers are left as gaps on purpose.                        |
//+------------------------------------------------------------------+
#property strict

#ifndef __QM_PATTERN_PERMISSION_MQH__
#define __QM_PATTERN_PERMISSION_MQH__

//--- Maximum bars any implemented predicate needs (id 90/91 percentiles).
#define QM_PP_MAX_LOOKBACK 120
//--- Predicate list capacity inside one compiled profile.
#define QM_PP_MAX_PREDICATES 8

//+------------------------------------------------------------------+
//| Predicate identifiers (source-traceable numbering)                |
//+------------------------------------------------------------------+
enum QM_PatternId
  {
   QM_PP_NONE                       = 0,
   // --- single-bar shape -----------------------------------------
   QM_PP_DOJI                       = 3,
   QM_PP_DRAGONFLY_DOJI             = 4,
   QM_PP_GRAVESTONE_DOJI            = 5,
   QM_PP_HAMMER                     = 6,
   QM_PP_INVERTED_HAMMER            = 7,
   QM_PP_HANGING_MAN                = 8,
   QM_PP_SHOOTING_STAR              = 9,
   QM_PP_PIN_BAR_BULL               = 10,
   QM_PP_PIN_BAR_BEAR               = 11,
   QM_PP_LONG_LOWER_WICK            = 12,
   QM_PP_LONG_UPPER_WICK            = 13,
   QM_PP_MARUBOZU_BULL              = 14,
   QM_PP_MARUBOZU_BEAR              = 15,
   QM_PP_BELT_HOLD_BULL             = 16,
   QM_PP_BELT_HOLD_BEAR             = 17,
   QM_PP_SPINNING_TOP               = 18,
   // --- two/three-bar reversal -----------------------------------
   QM_PP_ENGULFING_BULL             = 19,
   QM_PP_ENGULFING_BEAR             = 20,
   QM_PP_HARAMI_BULL                = 21,
   QM_PP_HARAMI_BEAR                = 22,
   QM_PP_PIERCING_LINE              = 23,
   QM_PP_DARK_CLOUD_COVER           = 24,
   QM_PP_TWEEZER_BOTTOM             = 25,
   QM_PP_TWEEZER_TOP                = 26,
   QM_PP_MORNING_STAR               = 27,
   QM_PP_EVENING_STAR               = 28,
   QM_PP_THREE_WHITE_SOLDIERS       = 29,
   QM_PP_THREE_BLACK_CROWS          = 30,
   QM_PP_THREE_INSIDE_UP            = 31,
   QM_PP_THREE_INSIDE_DOWN          = 32,
   QM_PP_THREE_OUTSIDE_UP           = 33,
   QM_PP_THREE_OUTSIDE_DOWN         = 34,
   // --- continuation ---------------------------------------------
   QM_PP_RISING_THREE_METHODS       = 35,
   QM_PP_FALLING_THREE_METHODS      = 36,
   QM_PP_MAT_HOLD_BULL              = 37,
   QM_PP_MAT_HOLD_BEAR              = 38,
   // --- consolidation / squeeze ----------------------------------
   QM_PP_INSIDE_BAR                 = 39,
   QM_PP_DOUBLE_INSIDE_BAR          = 40,
   QM_PP_OUTSIDE_BAR                = 41,
   QM_PP_NR4                        = 42,
   QM_PP_NR7                        = 43,
   QM_PP_WIDE_RANGE_BAR             = 44,
   // --- gaps -------------------------------------------------------
   QM_PP_GAP_UP                     = 45,
   QM_PP_GAP_DOWN                   = 46,
   QM_PP_GAP_AND_GO_BULL            = 47,
   QM_PP_GAP_AND_GO_BEAR            = 48,
   QM_PP_EXHAUSTION_GAP_UP          = 49,
   QM_PP_EXHAUSTION_GAP_DOWN        = 50,
   // --- structure / momentum -------------------------------------
   QM_PP_HIGHER_HIGH                = 51,
   QM_PP_LOWER_LOW                  = 52,
   QM_PP_THREE_DAY_RISING           = 53,
   QM_PP_THREE_DAY_FALLING          = 54,
   QM_PP_CLOSE_ABOVE_PREV_HIGH      = 55,
   QM_PP_CLOSE_BELOW_PREV_LOW       = 56,
   // --- volatility -------------------------------------------------
   QM_PP_LOW_VOLATILITY             = 57,
   QM_PP_HIGH_VOLATILITY            = 58,
   QM_PP_VOL_CONTRACTION            = 59,
   QM_PP_VOL_EXPANSION              = 60,
   // --- regime (bar-count trend strength; source-tagged "HMM" but the
   //     implementation is deterministic bar counting, reclassified and
   //     renamed per OWNER decision 2026-08-13) --------------------
   QM_PP_TREND_STRENGTH_UP_STRONG   = 77,
   QM_PP_TREND_STRENGTH_UP_WEAK     = 78,
   QM_PP_RANGING                    = 79,
   QM_PP_TREND_STRENGTH_DOWN_WEAK   = 80,
   QM_PP_TREND_STRENGTH_DOWN_STRONG = 81,
   QM_PP_HIGH_VOL_REGIME            = 82,
   QM_PP_REGIME_TRANSITION          = 83,
   QM_PP_TREND_EXHAUSTION           = 84,
   // --- statistical (closed-form, no fitting) ---------------------
   QM_PP_MEAN_REVERSION_SETUP       = 87,
   QM_PP_ZSCORE_HIGH                = 88,
   QM_PP_ZSCORE_LOW                 = 89,
   QM_PP_VOL_PERCENTILE_HIGH        = 90,
   QM_PP_VOL_PERCENTILE_LOW         = 91,
   QM_PP_FRACTAL_BREAKOUT           = 92,
   QM_PP_EFFICIENCY_RATIO_HIGH      = 93,
   QM_PP_EFFICIENCY_RATIO_LOW       = 94,
   // --- tick-volume proxy (DWX tick COUNT, not traded volume) -----
   QM_PP_VOLUME_CLIMAX              = 98,
   // --- calendar (derived from the reference bar's open time in UTC,
   //     never from TimeCurrent(); see OWNER decision E0-2) --------
   QM_PP_THIRD_FRIDAY               = 99,
   QM_PP_QUARTER_END                = 100
  };

//+------------------------------------------------------------------+
//| Implemented-set guard.                                            |
//|                                                                    |
//| QM_PP_Evaluate's default branch returns false for an unknown id.   |
//| That is correct for evaluation (an unknown pattern must not block) |
//| but it is a measurement hazard: an ablation trial naming a         |
//| kill-list or typo'd id would never fire, produce results identical |
//| to the control, and be recorded as "this predicate has no effect". |
//| Callers that ACCEPT an id from outside the binary (census trials,  |
//| setfiles) must reject it up front instead. Profile construction    |
//| below does exactly that, so no such id can reach a profile.        |
//|                                                                    |
//| The list is generated from the enum and pinned by                  |
//| test_pattern_permission_contract.py, which asserts three-way set   |
//| equality (enum == QM_PP_Evaluate cases == this switch). Adding an  |
//| enum member without implementing it fails that test.               |
//+------------------------------------------------------------------+
bool QM_PP_IsImplemented(const QM_PatternId id)
  {
   switch(id)
     {
      case QM_PP_DOJI:
      case QM_PP_DRAGONFLY_DOJI:
      case QM_PP_GRAVESTONE_DOJI:
      case QM_PP_HAMMER:
      case QM_PP_INVERTED_HAMMER:
      case QM_PP_HANGING_MAN:
      case QM_PP_SHOOTING_STAR:
      case QM_PP_PIN_BAR_BULL:
      case QM_PP_PIN_BAR_BEAR:
      case QM_PP_LONG_LOWER_WICK:
      case QM_PP_LONG_UPPER_WICK:
      case QM_PP_MARUBOZU_BULL:
      case QM_PP_MARUBOZU_BEAR:
      case QM_PP_BELT_HOLD_BULL:
      case QM_PP_BELT_HOLD_BEAR:
      case QM_PP_SPINNING_TOP:
      case QM_PP_ENGULFING_BULL:
      case QM_PP_ENGULFING_BEAR:
      case QM_PP_HARAMI_BULL:
      case QM_PP_HARAMI_BEAR:
      case QM_PP_PIERCING_LINE:
      case QM_PP_DARK_CLOUD_COVER:
      case QM_PP_TWEEZER_BOTTOM:
      case QM_PP_TWEEZER_TOP:
      case QM_PP_MORNING_STAR:
      case QM_PP_EVENING_STAR:
      case QM_PP_THREE_WHITE_SOLDIERS:
      case QM_PP_THREE_BLACK_CROWS:
      case QM_PP_THREE_INSIDE_UP:
      case QM_PP_THREE_INSIDE_DOWN:
      case QM_PP_THREE_OUTSIDE_UP:
      case QM_PP_THREE_OUTSIDE_DOWN:
      case QM_PP_RISING_THREE_METHODS:
      case QM_PP_FALLING_THREE_METHODS:
      case QM_PP_MAT_HOLD_BULL:
      case QM_PP_MAT_HOLD_BEAR:
      case QM_PP_INSIDE_BAR:
      case QM_PP_DOUBLE_INSIDE_BAR:
      case QM_PP_OUTSIDE_BAR:
      case QM_PP_NR4:
      case QM_PP_NR7:
      case QM_PP_WIDE_RANGE_BAR:
      case QM_PP_GAP_UP:
      case QM_PP_GAP_DOWN:
      case QM_PP_GAP_AND_GO_BULL:
      case QM_PP_GAP_AND_GO_BEAR:
      case QM_PP_EXHAUSTION_GAP_UP:
      case QM_PP_EXHAUSTION_GAP_DOWN:
      case QM_PP_HIGHER_HIGH:
      case QM_PP_LOWER_LOW:
      case QM_PP_THREE_DAY_RISING:
      case QM_PP_THREE_DAY_FALLING:
      case QM_PP_CLOSE_ABOVE_PREV_HIGH:
      case QM_PP_CLOSE_BELOW_PREV_LOW:
      case QM_PP_LOW_VOLATILITY:
      case QM_PP_HIGH_VOLATILITY:
      case QM_PP_VOL_CONTRACTION:
      case QM_PP_VOL_EXPANSION:
      case QM_PP_TREND_STRENGTH_UP_STRONG:
      case QM_PP_TREND_STRENGTH_UP_WEAK:
      case QM_PP_RANGING:
      case QM_PP_TREND_STRENGTH_DOWN_WEAK:
      case QM_PP_TREND_STRENGTH_DOWN_STRONG:
      case QM_PP_HIGH_VOL_REGIME:
      case QM_PP_REGIME_TRANSITION:
      case QM_PP_TREND_EXHAUSTION:
      case QM_PP_MEAN_REVERSION_SETUP:
      case QM_PP_ZSCORE_HIGH:
      case QM_PP_ZSCORE_LOW:
      case QM_PP_VOL_PERCENTILE_HIGH:
      case QM_PP_VOL_PERCENTILE_LOW:
      case QM_PP_FRACTAL_BREAKOUT:
      case QM_PP_EFFICIENCY_RATIO_HIGH:
      case QM_PP_EFFICIENCY_RATIO_LOW:
      case QM_PP_VOLUME_CLIMAX:
      case QM_PP_THIRD_FRIDAY:
      case QM_PP_QUARTER_END:
         return true;
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
//| Result / profile types                                            |
//+------------------------------------------------------------------+
struct QM_PermissionResult
  {
   bool              allow_buy;
   bool              allow_sell;
   bool              valid;
   datetime          reference_bar_time;
   string            reason;
  };

//--- v1 semantics: BLACKLIST only. A firing predicate BLOCKS its side.
//--- Whitelist is a physically different experiment and is out of scope
//--- for v1 (OWNER decision E0-3); the enum exists so a future profile
//--- cannot be silently misread as blacklist.
enum QM_PatternProfileMode
  {
   QM_PP_MODE_BLACKLIST = 0
  };

struct QM_PatternProfile
  {
   string                name;             // card-declared profile name
   QM_PatternProfileMode mode;
   ENUM_TIMEFRAMES       reference_tf;
   int                   closed_shift;     // must be >= 1
   int                   buy_count;
   int                   sell_count;
   QM_PatternId          buy_predicates[QM_PP_MAX_PREDICATES];
   QM_PatternId          sell_predicates[QM_PP_MAX_PREDICATES];
  };

//--- Closed-bar OHLCV window, index 0 == the reference (closed) bar.
struct QM_PPBars
  {
   double            open[QM_PP_MAX_LOOKBACK];
   double            high[QM_PP_MAX_LOOKBACK];
   double            low[QM_PP_MAX_LOOKBACK];
   double            close[QM_PP_MAX_LOOKBACK];
   long              tick_volume[QM_PP_MAX_LOOKBACK];
   datetime          time[QM_PP_MAX_LOOKBACK];
   int               count;
  };

//+------------------------------------------------------------------+
//| Profile construction helpers                                      |
//+------------------------------------------------------------------+
void QM_PP_ProfileInit(QM_PatternProfile &p, const string profile_name,
                       const ENUM_TIMEFRAMES tf, const int closed_shift)
  {
   p.name = profile_name;
   p.mode = QM_PP_MODE_BLACKLIST;
   p.reference_tf = tf;
   p.closed_shift = closed_shift;
   p.buy_count = 0;
   p.sell_count = 0;
   for(int i = 0; i < QM_PP_MAX_PREDICATES; ++i)
     {
      p.buy_predicates[i] = QM_PP_NONE;
      p.sell_predicates[i] = QM_PP_NONE;
     }
  }

bool QM_PP_ProfileAddBuy(QM_PatternProfile &p, const QM_PatternId id)
  {
   if(p.buy_count >= QM_PP_MAX_PREDICATES || !QM_PP_IsImplemented(id))
      return false;
   p.buy_predicates[p.buy_count] = id;
   p.buy_count++;
   return true;
  }

bool QM_PP_ProfileAddSell(QM_PatternProfile &p, const QM_PatternId id)
  {
   if(p.sell_count >= QM_PP_MAX_PREDICATES || !QM_PP_IsImplemented(id))
      return false;
   p.sell_predicates[p.sell_count] = id;
   p.sell_count++;
   return true;
  }

//--- Stable identity of a profile, used as part of the cache key.
string QM_PP_ProfileKey(const QM_PatternProfile &p)
  {
   string k = p.name + "|" + IntegerToString((int)p.mode) + "|" +
              IntegerToString((int)p.reference_tf) + "|" +
              IntegerToString(p.closed_shift) + "|B";
   for(int i = 0; i < p.buy_count; ++i)
      k += ":" + IntegerToString((int)p.buy_predicates[i]);
   k += "|S";
   for(int j = 0; j < p.sell_count; ++j)
      k += ":" + IntegerToString((int)p.sell_predicates[j]);
   return k;
  }

//+------------------------------------------------------------------+
//| History loading — the ONLY place history validity is decided.     |
//| Returns false on any shortfall so the caller fails closed.        |
//+------------------------------------------------------------------+
int QM_PP_RequiredBars(const QM_PatternId id)
  {
   switch(id)
     {
      case QM_PP_VOL_PERCENTILE_HIGH:
      case QM_PP_VOL_PERCENTILE_LOW:      return 101;
      case QM_PP_HIGH_VOL_REGIME:
      case QM_PP_REGIME_TRANSITION:       return 22;
      case QM_PP_MEAN_REVERSION_SETUP:
      case QM_PP_ZSCORE_HIGH:
      case QM_PP_ZSCORE_LOW:              return 21;
      case QM_PP_VOLUME_CLIMAX:           return 22;
      case QM_PP_LOW_VOLATILITY:
      case QM_PP_HIGH_VOLATILITY:         return 12;
      case QM_PP_TREND_STRENGTH_UP_STRONG:
      case QM_PP_TREND_STRENGTH_UP_WEAK:
      case QM_PP_TREND_STRENGTH_DOWN_WEAK:
      case QM_PP_TREND_STRENGTH_DOWN_STRONG:
      case QM_PP_RANGING:
      case QM_PP_EFFICIENCY_RATIO_HIGH:
      case QM_PP_EFFICIENCY_RATIO_LOW:    return 11;
      case QM_PP_WIDE_RANGE_BAR:          return 8;
      case QM_PP_NR7:                     return 7;
      case QM_PP_RISING_THREE_METHODS:
      case QM_PP_FALLING_THREE_METHODS:
      case QM_PP_MAT_HOLD_BULL:
      case QM_PP_MAT_HOLD_BEAR:
      case QM_PP_TREND_EXHAUSTION:
      case QM_PP_FRACTAL_BREAKOUT:        return 6;
      case QM_PP_NR4:
      case QM_PP_THREE_DAY_RISING:
      case QM_PP_THREE_DAY_FALLING:       return 4;
      case QM_PP_THIRD_FRIDAY:
      case QM_PP_QUARTER_END:             return 1;
      default:                            return 3;
     }
  }

int QM_PP_ProfileRequiredBars(const QM_PatternProfile &p)
  {
   int need = 3;
   for(int i = 0; i < p.buy_count; ++i)
      need = MathMax(need, QM_PP_RequiredBars(p.buy_predicates[i]));
   for(int j = 0; j < p.sell_count; ++j)
      need = MathMax(need, QM_PP_RequiredBars(p.sell_predicates[j]));
   return MathMin(need, QM_PP_MAX_LOOKBACK);
  }

bool QM_PP_LoadBars(const string symbol, const ENUM_TIMEFRAMES tf,
                    const int closed_shift, const int need, QM_PPBars &b)
  {
   b.count = 0;
   if(closed_shift < 1 || need < 1 || need > QM_PP_MAX_LOOKBACK)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, tf, closed_shift, need, rates);
   if(copied < need)   // partial fills are a shortfall, never a best effort
      return false;

   for(int i = 0; i < need; ++i)
     {
      if(rates[i].time <= 0 || rates[i].high < rates[i].low)
         return false;
      b.open[i] = rates[i].open;
      b.high[i] = rates[i].high;
      b.low[i] = rates[i].low;
      b.close[i] = rates[i].close;
      b.tick_volume[i] = rates[i].tick_volume;
      b.time[i] = rates[i].time;
     }
   b.count = need;
   return true;
  }

//+------------------------------------------------------------------+
//| Small shape helpers (all operate on closed bars only)             |
//+------------------------------------------------------------------+
double QM_PP_Range(const QM_PPBars &b, const int i)
  { return b.high[i] - b.low[i]; }

double QM_PP_Body(const QM_PPBars &b, const int i)
  { return MathAbs(b.close[i] - b.open[i]); }

double QM_PP_UpperWick(const QM_PPBars &b, const int i)
  { return b.high[i] - MathMax(b.open[i], b.close[i]); }

double QM_PP_LowerWick(const QM_PPBars &b, const int i)
  { return MathMin(b.open[i], b.close[i]) - b.low[i]; }

bool QM_PP_IsBull(const QM_PPBars &b, const int i)
  { return b.close[i] > b.open[i]; }

bool QM_PP_IsBear(const QM_PPBars &b, const int i)
  { return b.close[i] < b.open[i]; }

double QM_PP_Mid(const QM_PPBars &b, const int i)
  { return (b.open[i] + b.close[i]) * 0.5; }

//--- Simple average true range over `period` bars ending at `start`.
double QM_PP_Atr(const QM_PPBars &b, const int start, const int period)
  {
   if(period < 1 || start + period >= b.count)
      return 0.0;
   double sum = 0.0;
   for(int i = start; i < start + period; ++i)
     {
      const double tr = MathMax(b.high[i], b.close[i + 1]) -
                        MathMin(b.low[i], b.close[i + 1]);
      sum += tr;
     }
   return sum / period;
  }

double QM_PP_SmaClose(const QM_PPBars &b, const int start, const int period)
  {
   if(period < 1 || start + period > b.count)
      return 0.0;
   double sum = 0.0;
   for(int i = start; i < start + period; ++i)
      sum += b.close[i];
   return sum / period;
  }

double QM_PP_StdClose(const QM_PPBars &b, const int start, const int period)
  {
   if(period < 2 || start + period > b.count)
      return 0.0;
   const double mean = QM_PP_SmaClose(b, start, period);
   double acc = 0.0;
   for(int i = start; i < start + period; ++i)
      acc += (b.close[i] - mean) * (b.close[i] - mean);
   return MathSqrt(acc / period);
  }

//+------------------------------------------------------------------+
//| Calendar helpers — date is taken from the REFERENCE BAR's open    |
//| time, never from TimeCurrent(). Server time is broker-local and   |
//| DST-dependent; the bar timestamp is immutable and already part of |
//| the cache key, so a calendar predicate stays deterministic.       |
//+------------------------------------------------------------------+
bool QM_PP_IsThirdFriday(const datetime bar_open)
  {
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   return (dt.day_of_week == 5 && dt.day >= 15 && dt.day <= 21);
  }

bool QM_PP_IsQuarterEnd(const datetime bar_open)
  {
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   const bool quarter_month = (dt.mon == 3 || dt.mon == 6 || dt.mon == 9 || dt.mon == 12);
   return (quarter_month && dt.day >= 24);
  }

//+------------------------------------------------------------------+
//| Predicate evaluation. Index 0 is the reference (closed) bar.      |
//| Every branch is a pure function of the loaded window.             |
//+------------------------------------------------------------------+
bool QM_PP_Evaluate(const QM_PatternId id, const QM_PPBars &b)
  {
   if(b.count < QM_PP_RequiredBars(id))
      return false;

   const double r0 = QM_PP_Range(b, 0);
   const double body0 = QM_PP_Body(b, 0);
   const double up0 = QM_PP_UpperWick(b, 0);
   const double lo0 = QM_PP_LowerWick(b, 0);

   switch(id)
     {
      // ---- single-bar shape --------------------------------------
      case QM_PP_DOJI:
         return (r0 > 0 && body0 <= 0.10 * r0);
      case QM_PP_DRAGONFLY_DOJI:
         return (r0 > 0 && body0 <= 0.10 * r0 && up0 <= 0.10 * r0 && lo0 >= 0.50 * r0);
      case QM_PP_GRAVESTONE_DOJI:
         return (r0 > 0 && body0 <= 0.10 * r0 && lo0 <= 0.10 * r0 && up0 >= 0.50 * r0);
      case QM_PP_HAMMER:
         return (r0 > 0 && body0 <= 0.35 * r0 && lo0 >= 2.0 * body0 && up0 <= 0.30 * body0);
      case QM_PP_INVERTED_HAMMER:
         return (r0 > 0 && body0 <= 0.35 * r0 && up0 >= 2.0 * body0 && lo0 <= 0.30 * body0);
      case QM_PP_HANGING_MAN:
         return (r0 > 0 && body0 <= 0.35 * r0 && lo0 >= 2.0 * body0 && up0 <= 0.30 * body0
                 && b.close[1] > b.close[2]);
      case QM_PP_SHOOTING_STAR:
         return (r0 > 0 && body0 <= 0.35 * r0 && up0 >= 2.0 * body0 && lo0 <= 0.30 * body0
                 && b.close[1] > b.close[2]);
      case QM_PP_PIN_BAR_BULL:
         return (r0 > 0 && lo0 >= 0.66 * r0 && up0 <= 0.25 * r0);
      case QM_PP_PIN_BAR_BEAR:
         return (r0 > 0 && up0 >= 0.66 * r0 && lo0 <= 0.25 * r0);
      case QM_PP_LONG_LOWER_WICK:
         return (r0 > 0 && lo0 >= 0.50 * r0);
      case QM_PP_LONG_UPPER_WICK:
         return (r0 > 0 && up0 >= 0.50 * r0);
      case QM_PP_MARUBOZU_BULL:
         return (r0 > 0 && QM_PP_IsBull(b, 0) && body0 >= 0.95 * r0);
      case QM_PP_MARUBOZU_BEAR:
         return (r0 > 0 && QM_PP_IsBear(b, 0) && body0 >= 0.95 * r0);
      case QM_PP_BELT_HOLD_BULL:
         return (r0 > 0 && QM_PP_IsBull(b, 0) && lo0 <= 0.05 * r0 && body0 >= 0.60 * r0);
      case QM_PP_BELT_HOLD_BEAR:
         return (r0 > 0 && QM_PP_IsBear(b, 0) && up0 <= 0.05 * r0 && body0 >= 0.60 * r0);
      case QM_PP_SPINNING_TOP:
         return (r0 > 0 && body0 >= 0.20 * r0 && body0 <= 0.35 * r0
                 && up0 >= 0.25 * r0 && lo0 >= 0.25 * r0);

      // ---- two/three-bar reversal --------------------------------
      case QM_PP_ENGULFING_BULL:
         return (QM_PP_IsBear(b, 1) && QM_PP_IsBull(b, 0)
                 && b.close[0] >= b.open[1] && b.open[0] <= b.close[1]);
      case QM_PP_ENGULFING_BEAR:
         return (QM_PP_IsBull(b, 1) && QM_PP_IsBear(b, 0)
                 && b.open[0] >= b.close[1] && b.close[0] <= b.open[1]);
      case QM_PP_HARAMI_BULL:
         return (QM_PP_IsBear(b, 1) && QM_PP_IsBull(b, 0)
                 && b.close[0] <= b.open[1] && b.open[0] >= b.close[1]
                 && QM_PP_Body(b, 1) > body0);
      case QM_PP_HARAMI_BEAR:
         return (QM_PP_IsBull(b, 1) && QM_PP_IsBear(b, 0)
                 && b.open[0] <= b.close[1] && b.close[0] >= b.open[1]
                 && QM_PP_Body(b, 1) > body0);
      case QM_PP_PIERCING_LINE:
         return (QM_PP_IsBear(b, 1) && b.open[0] < b.low[1]
                 && b.close[0] > QM_PP_Mid(b, 1) && b.close[0] < b.open[1]);
      case QM_PP_DARK_CLOUD_COVER:
         return (QM_PP_IsBull(b, 1) && b.open[0] > b.high[1]
                 && b.close[0] < QM_PP_Mid(b, 1) && b.close[0] > b.open[1]);
      case QM_PP_TWEEZER_BOTTOM:
         return (QM_PP_Range(b, 1) > 0
                 && MathAbs(b.low[0] - b.low[1]) <= 0.05 * QM_PP_Range(b, 1)
                 && b.low[0] < b.low[2] && b.low[1] < b.low[2]);
      case QM_PP_TWEEZER_TOP:
         return (QM_PP_Range(b, 1) > 0
                 && MathAbs(b.high[0] - b.high[1]) <= 0.05 * QM_PP_Range(b, 1)
                 && b.high[0] > b.high[2] && b.high[1] > b.high[2]);
      case QM_PP_MORNING_STAR:
         return (QM_PP_IsBear(b, 2) && QM_PP_Range(b, 1) > 0
                 && QM_PP_Body(b, 1) <= 0.35 * QM_PP_Range(b, 1)
                 && QM_PP_IsBull(b, 0) && b.close[0] > QM_PP_Mid(b, 2));
      case QM_PP_EVENING_STAR:
         return (QM_PP_IsBull(b, 2) && QM_PP_Range(b, 1) > 0
                 && QM_PP_Body(b, 1) <= 0.35 * QM_PP_Range(b, 1)
                 && QM_PP_IsBear(b, 0) && b.close[0] < QM_PP_Mid(b, 2));
      case QM_PP_THREE_WHITE_SOLDIERS:
         return (QM_PP_IsBull(b, 0) && QM_PP_IsBull(b, 1) && QM_PP_IsBull(b, 2)
                 && b.close[0] > b.close[1] && b.close[1] > b.close[2]
                 && b.open[0] <= b.close[1] && b.open[1] <= b.close[2]);
      case QM_PP_THREE_BLACK_CROWS:
         return (QM_PP_IsBear(b, 0) && QM_PP_IsBear(b, 1) && QM_PP_IsBear(b, 2)
                 && b.close[0] < b.close[1] && b.close[1] < b.close[2]
                 && b.open[0] >= b.close[1] && b.open[1] >= b.close[2]);
      case QM_PP_THREE_INSIDE_UP:
         return (QM_PP_Evaluate(QM_PP_HARAMI_BULL, b) && b.close[0] > b.high[1]);
      case QM_PP_THREE_INSIDE_DOWN:
         return (QM_PP_Evaluate(QM_PP_HARAMI_BEAR, b) && b.close[0] < b.low[1]);
      case QM_PP_THREE_OUTSIDE_UP:
         return (QM_PP_Evaluate(QM_PP_ENGULFING_BULL, b) && b.close[0] > b.high[1]);
      case QM_PP_THREE_OUTSIDE_DOWN:
         return (QM_PP_Evaluate(QM_PP_ENGULFING_BEAR, b) && b.close[0] < b.low[1]);

      // ---- continuation ------------------------------------------
      case QM_PP_RISING_THREE_METHODS:
         return (QM_PP_IsBull(b, 4) && QM_PP_IsBear(b, 3) && QM_PP_IsBear(b, 2)
                 && QM_PP_IsBear(b, 1) && QM_PP_IsBull(b, 0)
                 && b.high[3] <= b.high[4] && b.high[2] <= b.high[4] && b.high[1] <= b.high[4]
                 && b.low[3] >= b.low[4] && b.low[2] >= b.low[4] && b.low[1] >= b.low[4]
                 && b.close[0] > b.high[4]);
      case QM_PP_FALLING_THREE_METHODS:
         return (QM_PP_IsBear(b, 4) && QM_PP_IsBull(b, 3) && QM_PP_IsBull(b, 2)
                 && QM_PP_IsBull(b, 1) && QM_PP_IsBear(b, 0)
                 && b.high[3] <= b.high[4] && b.high[2] <= b.high[4] && b.high[1] <= b.high[4]
                 && b.low[3] >= b.low[4] && b.low[2] >= b.low[4] && b.low[1] >= b.low[4]
                 && b.close[0] < b.low[4]);
      case QM_PP_MAT_HOLD_BULL:
         return (QM_PP_IsBull(b, 4) && b.low[3] > b.high[4]
                 && QM_PP_Range(b, 4) > 0
                 && QM_PP_Body(b, 3) <= 0.5 * QM_PP_Range(b, 4)
                 && QM_PP_Body(b, 2) <= 0.5 * QM_PP_Range(b, 4)
                 && QM_PP_Body(b, 1) <= 0.5 * QM_PP_Range(b, 4)
                 && b.close[0] > b.high[4]);
      case QM_PP_MAT_HOLD_BEAR:
         return (QM_PP_IsBear(b, 4) && b.high[3] < b.low[4]
                 && QM_PP_Range(b, 4) > 0
                 && QM_PP_Body(b, 3) <= 0.5 * QM_PP_Range(b, 4)
                 && QM_PP_Body(b, 2) <= 0.5 * QM_PP_Range(b, 4)
                 && QM_PP_Body(b, 1) <= 0.5 * QM_PP_Range(b, 4)
                 && b.close[0] < b.low[4]);

      // ---- consolidation / squeeze -------------------------------
      case QM_PP_INSIDE_BAR:
         return (b.high[0] <= b.high[1] && b.low[0] >= b.low[1]);
      case QM_PP_DOUBLE_INSIDE_BAR:
         return (b.high[0] <= b.high[1] && b.low[0] >= b.low[1]
                 && b.high[1] <= b.high[2] && b.low[1] >= b.low[2]);
      case QM_PP_OUTSIDE_BAR:
         return (b.high[0] >= b.high[1] && b.low[0] <= b.low[1]);
      case QM_PP_NR4:
         return (r0 < QM_PP_Range(b, 1) && r0 < QM_PP_Range(b, 2) && r0 < QM_PP_Range(b, 3));
      case QM_PP_NR7:
        {
         for(int i = 1; i <= 6; ++i)
            if(r0 >= QM_PP_Range(b, i))
               return false;
         return true;
        }
      case QM_PP_WIDE_RANGE_BAR:
        {
         const double atr5 = QM_PP_Atr(b, 1, 5);
         return (atr5 > 0 && r0 > 1.5 * atr5);
        }

      // ---- gaps ---------------------------------------------------
      case QM_PP_GAP_UP:
         return (b.open[0] > b.high[1]);
      case QM_PP_GAP_DOWN:
         return (b.open[0] < b.low[1]);
      case QM_PP_GAP_AND_GO_BULL:
         return (b.open[0] > b.high[1] && QM_PP_IsBull(b, 0));
      case QM_PP_GAP_AND_GO_BEAR:
         return (b.open[0] < b.low[1] && QM_PP_IsBear(b, 0));
      case QM_PP_EXHAUSTION_GAP_UP:
         return (b.open[0] > b.high[1] && QM_PP_IsBear(b, 0)
                 && r0 < 0.5 * QM_PP_Range(b, 1));
      case QM_PP_EXHAUSTION_GAP_DOWN:
         return (b.open[0] < b.low[1] && QM_PP_IsBull(b, 0)
                 && r0 < 0.5 * QM_PP_Range(b, 1));

      // ---- structure / momentum ----------------------------------
      case QM_PP_HIGHER_HIGH:
         return (b.high[0] > b.high[1] && b.low[0] > b.low[1]);
      case QM_PP_LOWER_LOW:
         return (b.low[0] < b.low[1] && b.high[0] < b.high[1]);
      case QM_PP_THREE_DAY_RISING:
         return (b.close[0] > b.close[1] && b.close[1] > b.close[2] && b.close[2] > b.close[3]);
      case QM_PP_THREE_DAY_FALLING:
         return (b.close[0] < b.close[1] && b.close[1] < b.close[2] && b.close[2] < b.close[3]);
      case QM_PP_CLOSE_ABOVE_PREV_HIGH:
         return (b.close[0] > b.high[1]);
      case QM_PP_CLOSE_BELOW_PREV_LOW:
         return (b.close[0] < b.low[1]);

      // ---- volatility ---------------------------------------------
      case QM_PP_LOW_VOLATILITY:
        {
         const double atr10 = QM_PP_Atr(b, 1, 10);
         return (atr10 > 0 && r0 < 0.7 * atr10);
        }
      case QM_PP_HIGH_VOLATILITY:
        {
         const double atr10 = QM_PP_Atr(b, 1, 10);
         return (atr10 > 0 && r0 > 1.3 * atr10);
        }
      case QM_PP_VOL_CONTRACTION:
         return (r0 < QM_PP_Range(b, 1) && QM_PP_Range(b, 1) < QM_PP_Range(b, 2));
      case QM_PP_VOL_EXPANSION:
         return (r0 > QM_PP_Range(b, 1) && QM_PP_Range(b, 1) > QM_PP_Range(b, 2));

      // ---- regime (deterministic bar counting) -------------------
      case QM_PP_TREND_STRENGTH_UP_STRONG:
      case QM_PP_TREND_STRENGTH_UP_WEAK:
      case QM_PP_TREND_STRENGTH_DOWN_WEAK:
      case QM_PP_TREND_STRENGTH_DOWN_STRONG:
        {
         int bulls = 0;
         for(int i = 0; i < 10; ++i)
            if(QM_PP_IsBull(b, i))
               bulls++;
         const int bears = 10 - bulls;
         if(id == QM_PP_TREND_STRENGTH_UP_STRONG)
            return (bulls >= 7 && b.close[0] > b.close[9]);
         if(id == QM_PP_TREND_STRENGTH_UP_WEAK)
            return (bulls >= 5 && bulls <= 6);
         if(id == QM_PP_TREND_STRENGTH_DOWN_WEAK)
            return (bears >= 5 && bears <= 6);
         return (bears >= 7 && b.close[0] < b.close[9]);
        }
      case QM_PP_RANGING:
        {
         double hi = b.high[0], lo = b.low[0];
         for(int i = 1; i < 10; ++i)
           {
            hi = MathMax(hi, b.high[i]);
            lo = MathMin(lo, b.low[i]);
           }
         const double span = hi - lo;
         if(span <= 0)
            return false;
         return (MathAbs(b.close[0] - (hi + lo) * 0.5) < 0.25 * span);
        }
      case QM_PP_HIGH_VOL_REGIME:
        {
         const double atr20 = QM_PP_Atr(b, 1, 20);
         return (atr20 > 0 && r0 > 2.0 * atr20);
        }
      case QM_PP_REGIME_TRANSITION:
        {
         const double a5 = QM_PP_Atr(b, 0, 5);
         const double a20 = QM_PP_Atr(b, 0, 20);
         return (a20 > 0 && a5 > 1.5 * a20);
        }
      case QM_PP_TREND_EXHAUSTION:
         return (b.close[4] < b.close[2]
                 && MathAbs(b.close[0] - b.close[1]) < 0.3 * MathAbs(b.close[3] - b.close[4]));

      // ---- statistical (closed form) -----------------------------
      case QM_PP_MEAN_REVERSION_SETUP:
        {
         const double sma20 = QM_PP_SmaClose(b, 0, 20);
         const double atr20 = QM_PP_Atr(b, 0, 20);
         return (atr20 > 0 && MathAbs(b.close[0] - sma20) > 2.0 * atr20);
        }
      case QM_PP_ZSCORE_HIGH:
      case QM_PP_ZSCORE_LOW:
        {
         const double mean20 = QM_PP_SmaClose(b, 0, 20);
         const double sd20 = QM_PP_StdClose(b, 0, 20);
         if(sd20 <= 0)
            return false;
         const double z = (b.close[0] - mean20) / sd20;
         return (id == QM_PP_ZSCORE_HIGH) ? (z > 2.5) : (z < -2.5);
        }
      case QM_PP_VOL_PERCENTILE_HIGH:
      case QM_PP_VOL_PERCENTILE_LOW:
        {
         int below = 0;
         for(int i = 1; i < 101; ++i)
            if(QM_PP_Range(b, i) < r0)
               below++;
         const double pct = (double)below / 100.0;
         return (id == QM_PP_VOL_PERCENTILE_HIGH) ? (pct >= 0.90) : (pct <= 0.10);
        }
      case QM_PP_FRACTAL_BREAKOUT:
         return (b.high[2] > b.high[3] && b.high[2] > b.high[4]
                 && b.high[2] > b.high[1] && b.high[2] > b.high[0]
                 && b.close[0] > b.high[2]);
      case QM_PP_EFFICIENCY_RATIO_HIGH:
      case QM_PP_EFFICIENCY_RATIO_LOW:
        {
         double path = 0.0;
         for(int i = 0; i < 10; ++i)
            path += MathAbs(b.close[i] - b.close[i + 1]);
         if(path <= 0)
            return false;
         const double er = MathAbs(b.close[0] - b.close[10]) / path;
         return (id == QM_PP_EFFICIENCY_RATIO_HIGH) ? (er > 0.7) : (er < 0.3);
        }

      // ---- tick-volume proxy --------------------------------------
      case QM_PP_VOLUME_CLIMAX:
        {
         double vsum = 0.0;
         for(int i = 1; i <= 20; ++i)
            vsum += (double)b.tick_volume[i];
         const double vavg = vsum / 20.0;
         const double atr20 = QM_PP_Atr(b, 1, 20);
         return (vavg > 0 && atr20 > 0
                 && (double)b.tick_volume[0] > 3.0 * vavg
                 && r0 > 1.5 * atr20);
        }

      // ---- calendar ------------------------------------------------
      case QM_PP_THIRD_FRIDAY:
         return QM_PP_IsThirdFriday(b.time[0]);
      case QM_PP_QUARTER_END:
         return QM_PP_IsQuarterEnd(b.time[0]);

      default:
         return false;   // unknown id never grants and never blocks silently
     }
  }

//+------------------------------------------------------------------+
//| Cached evaluator — the public entry point.                        |
//+------------------------------------------------------------------+
string   g_qm_pp_cache_key = "";
bool     g_qm_pp_cache_allow_buy = false;
bool     g_qm_pp_cache_allow_sell = false;
bool     g_qm_pp_cache_valid = false;
datetime g_qm_pp_cache_bar = 0;
string   g_qm_pp_cache_reason = "";

void QM_PP_Deny(QM_PermissionResult &out, const string reason)
  {
   out.allow_buy = false;
   out.allow_sell = false;
   out.valid = false;
   out.reference_bar_time = 0;
   out.reason = reason;
  }

QM_PermissionResult QM_PatternPermissionEvaluate(const string symbol,
                                                 const ENUM_TIMEFRAMES reference_tf,
                                                 const int closed_shift,
                                                 const QM_PatternProfile &profile)
  {
   QM_PermissionResult out;

   // Shift 0 is the forming bar. Rejecting it here is what keeps the gate
   // repaint-free; the source reference read it and therefore repainted.
   if(closed_shift < 1)
     {
      QM_PP_Deny(out, "invalid_closed_shift_must_be_ge_1");
      return out;
     }
   if(profile.mode != QM_PP_MODE_BLACKLIST)
     {
      QM_PP_Deny(out, "unsupported_profile_mode");
      return out;
     }

   const datetime ref_bar = iTime(symbol, reference_tf, closed_shift);
   if(ref_bar <= 0)
     {
      QM_PP_Deny(out, "reference_bar_unavailable");
      return out;
     }

   const string key = symbol + "|" + IntegerToString((int)reference_tf) + "|" +
                      IntegerToString((int)ref_bar) + "|" + QM_PP_ProfileKey(profile);
   if(key == g_qm_pp_cache_key)
     {
      out.allow_buy = g_qm_pp_cache_allow_buy;
      out.allow_sell = g_qm_pp_cache_allow_sell;
      out.valid = g_qm_pp_cache_valid;
      out.reference_bar_time = g_qm_pp_cache_bar;
      out.reason = g_qm_pp_cache_reason;
      return out;
     }

   QM_PPBars bars;
   const int need = QM_PP_ProfileRequiredBars(profile);
   if(!QM_PP_LoadBars(symbol, reference_tf, closed_shift, need, bars))
     {
      QM_PP_Deny(out, "insufficient_or_invalid_history");
      // Cache the denial too: a history gap must not be re-probed every tick,
      // and it must not flip to allow mid-bar.
      g_qm_pp_cache_key = key;
      g_qm_pp_cache_allow_buy = false;
      g_qm_pp_cache_allow_sell = false;
      g_qm_pp_cache_valid = false;
      g_qm_pp_cache_bar = 0;
      g_qm_pp_cache_reason = out.reason;
      return out;
     }

   bool allow_buy = true;
   bool allow_sell = true;
   string reason = "clear";

   for(int i = 0; i < profile.buy_count; ++i)
      if(QM_PP_Evaluate(profile.buy_predicates[i], bars))
        {
         allow_buy = false;
         reason = "buy_blocked_by_" + IntegerToString((int)profile.buy_predicates[i]);
         break;
        }
   for(int j = 0; j < profile.sell_count; ++j)
      if(QM_PP_Evaluate(profile.sell_predicates[j], bars))
        {
         allow_sell = false;
         reason = (allow_buy ? "" : reason + ";") +
                  "sell_blocked_by_" + IntegerToString((int)profile.sell_predicates[j]);
         break;
        }

   out.allow_buy = allow_buy;
   out.allow_sell = allow_sell;
   out.valid = true;
   out.reference_bar_time = bars.time[0];
   out.reason = reason;

   g_qm_pp_cache_key = key;
   g_qm_pp_cache_allow_buy = out.allow_buy;
   g_qm_pp_cache_allow_sell = out.allow_sell;
   g_qm_pp_cache_valid = true;
   g_qm_pp_cache_bar = out.reference_bar_time;
   g_qm_pp_cache_reason = out.reason;
   return out;
  }

#endif // __QM_PATTERN_PERMISSION_MQH__
//+------------------------------------------------------------------+
