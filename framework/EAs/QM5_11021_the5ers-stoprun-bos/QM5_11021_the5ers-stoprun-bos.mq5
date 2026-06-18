#property strict
#property version   "5.0"
#property description "QM5_11021 the5ers-stoprun-bos — Stop-hunt / Break-of-Structure return-to-origin (M30, D1/H4 bias)"

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11021 the5ers-stoprun-bos
// -----------------------------------------------------------------------------
// Source: The5ers blog, "The 3 Important Characteristics For Successful Trading"
//   (interview with Samuel T). Card:
//   artifacts/cards_approved/QM5_11021_the5ers-stoprun-bos.md (g0_status APPROVED).
//
// Mechanics (entries on M30 closed bars, HTF bias from D1/H4 closed bars):
//   1. HTF bias  : D1 close vs EMA(50) AND H4 close vs EMA(50), confirmed by the
//                  latest H4 fractal swing sequence (HH/HL for long, LL/LH short).
//   2. Stop hunt : M30 sweeps beyond the prior-24-bar swing extreme by >= sweep_atr_mult
//                  * ATR(M30,48) then closes back inside. (long: below swing-low;
//                  short: above swing-high.)
//   3. BOS       : the most recent closed M30 bar closes beyond the last M30 swing
//                  formed BEFORE the sweep (long: above pre-sweep swing high;
//                  short: below pre-sweep swing low).
//   4. Origin    : last opposite-colour M30 candle before the BOS bar.
//   5. Entry     : LIMIT order at origin_fill_pct of the origin candle body in the
//                  bias direction; expires after entry_expiry_bars M30 bars.
//   6. Filters   : London-time sessions (06:00-09:00, 13:00-16:00, UK-DST aware),
//                  skip if stop-hunt bar range > max_range_atr_mult * ATR(M30,48),
//                  news blackout (framework), one position per magic.
//   Stop loss    : long: stop-hunt low  - sl_atr_mult * ATR ; short mirror.
//   Take profit  : tp_rr * R (R = |entry - SL|).
//   Manage       : move SL to break-even after price travels +1R.
//   Time stop    : close after time_stop_bars M30 bars; pending order expiry is
//                  handled by the broker via expiration_seconds.
//
// All structure reads are on CLOSED bars (shift >= 1). Fractal swings require a
// confirmed right side (k bars), so they never repaint after the limit is placed.
// The closed-bar scan runs once per new M30 bar (QM_IsNewBar gate in OnTick).
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11021;
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
// HTF bias
input int    strategy_htf_ema_period     = 50;    // D1 & H4 bias EMA period
input int    strategy_h4_swing_fractal   = 2;     // H4 fractal half-width for HH/HL sequence
// M30 sweep / structure
input int    strategy_m30_swing_fractal  = 2;     // M30 fractal half-width (confirmed swings)
input int    strategy_sweep_lookback     = 24;    // prior M30 bars for swept extreme (P3: {16,24,32})
input int    strategy_atr_period         = 48;    // ATR(M30) period for sweep / SL / range
input double strategy_sweep_atr_mult     = 0.1;   // min sweep penetration = mult * ATR(M30,period)
input double strategy_max_range_atr_mult = 2.5;   // skip if stop-hunt bar range > mult * ATR
input double strategy_origin_fill_pct    = 0.50;  // limit at this % of origin body (P3: {0.5,0.618,0.75})
input int    strategy_entry_expiry_bars  = 8;     // pending limit expires after N M30 bars
// Exit
input double strategy_sl_atr_mult        = 0.25;  // SL beyond stop-hunt extreme = mult * ATR
input double strategy_tp_rr              = 2.0;   // take profit in R multiples (P3: {1.5,2.0})
input int    strategy_time_stop_bars     = 24;    // close open position after N M30 bars
// Sessions (London local hours; UK-DST handled in code)
input int    strategy_sess1_start_uk     = 6;     // London window 1 start hour (UK local)
input int    strategy_sess1_end_uk       = 9;     // London window 1 end hour (exclusive)
input int    strategy_sess2_start_uk     = 13;    // London window 2 start hour (UK local)
input int    strategy_sess2_end_uk       = 16;    // London window 2 end hour (exclusive)

// =============================================================================
// UK DST helper — there is no framework London-DST helper (only US DST exists).
// UK/London DST: last Sunday of March 01:00 UTC -> last Sunday of October 01:00 UTC.
// Inside that window London = UTC+1 (BST), otherwise UTC+0 (GMT).
// =============================================================================
datetime LastSundayUTC(const int year, const int month, const int hour_utc)
  {
   int days = QM_DSTAware_DaysInMonth(year, month);
   for(int day = days; day >= 1; --day)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year; dt.mon = month; dt.day = day;
      dt.hour = hour_utc; dt.min = 0; dt.sec = 0;
      datetime t = StructToTime(dt);
      if(QM_DSTAware_DayOfWeek(t) == SUNDAY)
         return t;
     }
   return 0;
  }

bool IsUKDSTUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   datetime start_utc = LastSundayUTC(dt.year, 3, 1);   // last Sun Mar 01:00 UTC
   datetime end_utc   = LastSundayUTC(dt.year, 10, 1);   // last Sun Oct 01:00 UTC
   if(start_utc == 0 || end_utc == 0)
      return false;
   return (utc >= start_utc && utc < end_utc);
  }

int UKHourFromBroker(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int uk_offset = IsUKDSTUTC(utc) ? 1 : 0;
   const datetime uk = utc + uk_offset * 3600;
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(uk, dt);
   return dt.hour;
  }

bool InLondonSession(const datetime broker_time)
  {
   const int h = UKHourFromBroker(broker_time);
   const bool w1 = (h >= strategy_sess1_start_uk && h < strategy_sess1_end_uk);
   const bool w2 = (h >= strategy_sess2_start_uk && h < strategy_sess2_end_uk);
   return (w1 || w2);
  }

// =============================================================================
// Fractal swing detection on CLOSED bars. A swing high at shift s (s >= k+1) is
// confirmed when high[s] is strictly the highest in [s-k .. s+k]. Returns the
// shift of the most recent confirmed swing high/low at or after min_shift, else -1.
// perf-allowed: bespoke structural logic, bounded, runs once per closed M30 bar.
// =============================================================================
bool IsSwingHigh(const ENUM_TIMEFRAMES tf, const int s, const int k)
  {
   const double pivot = iHigh(_Symbol, tf, s); // perf-allowed
   if(pivot <= 0.0)
      return false;
   for(int j = 1; j <= k; ++j)
     {
      const double hl = iHigh(_Symbol, tf, s + j); // perf-allowed
      const double hr = iHigh(_Symbol, tf, s - j); // perf-allowed
      if(hl <= 0.0 || hr <= 0.0)
         return false;
      if(pivot <= hl || pivot <= hr)
         return false;
     }
   return true;
  }

bool IsSwingLow(const ENUM_TIMEFRAMES tf, const int s, const int k)
  {
   const double pivot = iLow(_Symbol, tf, s); // perf-allowed
   if(pivot <= 0.0)
      return false;
   for(int j = 1; j <= k; ++j)
     {
      const double ll = iLow(_Symbol, tf, s + j); // perf-allowed
      const double lr = iLow(_Symbol, tf, s - j); // perf-allowed
      if(ll <= 0.0 || lr <= 0.0)
         return false;
      if(pivot >= ll || pivot >= lr)
         return false;
     }
   return true;
  }

// Most recent confirmed swing-high shift at or after min_shift (<= max_shift). -1 if none.
int RecentSwingHighShift(const ENUM_TIMEFRAMES tf, const int k, const int min_shift, const int max_shift)
  {
   for(int s = min_shift; s <= max_shift; ++s)
      if(IsSwingHigh(tf, s, k))
         return s;
   return -1;
  }

int RecentSwingLowShift(const ENUM_TIMEFRAMES tf, const int k, const int min_shift, const int max_shift)
  {
   for(int s = min_shift; s <= max_shift; ++s)
      if(IsSwingLow(tf, s, k))
         return s;
   return -1;
  }

// H4 swing sequence: true if latest two confirmed swing highs are HH and latest two
// confirmed swing lows are HL (uptrend) when want_up, else LL/LH (downtrend).
bool H4SequenceAligned(const bool want_up)
  {
   const int k = strategy_h4_swing_fractal;
   const int min_s = k + 1;
   const int max_s = 60; // bounded H4 lookback (~10 trading days)

   // two most recent swing highs
   const int h1 = RecentSwingHighShift(PERIOD_H4, k, min_s, max_s);
   if(h1 < 0) return false;
   const int h2 = RecentSwingHighShift(PERIOD_H4, k, h1 + 1, max_s);
   if(h2 < 0) return false;
   // two most recent swing lows
   const int l1 = RecentSwingLowShift(PERIOD_H4, k, min_s, max_s);
   if(l1 < 0) return false;
   const int l2 = RecentSwingLowShift(PERIOD_H4, k, l1 + 1, max_s);
   if(l2 < 0) return false;

   const double hh1 = iHigh(_Symbol, PERIOD_H4, h1); // perf-allowed
   const double hh2 = iHigh(_Symbol, PERIOD_H4, h2); // perf-allowed
   const double ll1 = iLow(_Symbol, PERIOD_H4, l1);  // perf-allowed
   const double ll2 = iLow(_Symbol, PERIOD_H4, l2);  // perf-allowed
   if(hh1 <= 0.0 || hh2 <= 0.0 || ll1 <= 0.0 || ll2 <= 0.0)
      return false;

   if(want_up)
      return (hh1 > hh2 && ll1 > ll2);   // higher-high + higher-low
   return (hh1 < hh2 && ll1 < ll2);       // lower-high + lower-low
  }

// HTF bias: +1 long, -1 short, 0 none.
int HTFBias()
  {
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double h4_close = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed
   const double d1_ema   = QM_EMA(_Symbol, PERIOD_D1, strategy_htf_ema_period, 1);
   const double h4_ema   = QM_EMA(_Symbol, PERIOD_H4, strategy_htf_ema_period, 1);
   if(d1_close <= 0.0 || h4_close <= 0.0 || d1_ema <= 0.0 || h4_ema <= 0.0)
      return 0;

   if(d1_close > d1_ema && h4_close > h4_ema && H4SequenceAligned(true))
      return 1;
   if(d1_close < d1_ema && h4_close < h4_ema && H4SequenceAligned(false))
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: London session + spread sanity. Fail-open on .DWX
// zero modeled spread (never block on zero spread).
bool Strategy_NoTradeFilter()
  {
   // Session is checked in Strategy_EntrySignal so management and time-stop
   // exits can still run outside the entry windows.
   const datetime broker_now = TimeCurrent();

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double cap = 0.25 * atr_value; // wide-spread guard scaled to volatility
   const double spread = ask - bid;
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry: stop-hunt -> break-of-structure -> origin-fill LIMIT order in HTF bias
// direction. Caller guarantees QM_IsNewBar() == true (closed-bar gate). All reads
// at shift >= 1 (confirmed); bounded single-pass scan once per closed M30 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!InLondonSession(TimeCurrent()))
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   // Suppress a fresh limit while one is already pending for this magic/symbol.
   for(int oi = OrdersTotal() - 1; oi >= 0; --oi)
     {
      const ulong oticket = OrderGetTicket(oi);
      if(oticket == 0 || !OrderSelect(oticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == QM_FrameworkMagic() &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
         return false;
     }

   const int bias = HTFBias();
   if(bias == 0)
      return false;

   const double atr_m30 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_m30 <= 0.0)
      return false;
   const double min_pen = strategy_sweep_atr_mult * atr_m30;

   const int k = strategy_m30_swing_fractal;

   if(bias > 0)
     {
      // ---- LONG: sweep BELOW the lowest swing-low of prior sweep_lookback bars ----
      // Swept reference = lowest confirmed swing-low in the prior lookback.
      double swept_low = 0.0;
      bool have = false;
      for(int s = k + 1; s <= strategy_sweep_lookback + k; ++s)
        {
         if(!IsSwingLow(_Period, s, k))
            continue;
         const double lo = iLow(_Symbol, _Period, s); // perf-allowed
         if(lo <= 0.0) continue;
         if(!have || lo < swept_low) { swept_low = lo; have = true; }
        }
      if(!have) return false;

      // Stop-hunt bar = most recent closed bar (shift 1): sweeps below swept_low by
      // >= min_pen then closes back above it.
      const double hunt_low   = iLow(_Symbol, _Period, 1);   // perf-allowed
      const double hunt_high  = iHigh(_Symbol, _Period, 1);  // perf-allowed
      const double hunt_close = iClose(_Symbol, _Period, 1); // perf-allowed
      if(hunt_low <= 0.0 || hunt_high <= 0.0 || hunt_close <= 0.0)
         return false;
      if(!((swept_low - hunt_low) >= min_pen && hunt_close > swept_low))
         return false;
      // Skip oversized stop-hunt candle.
      if((hunt_high - hunt_low) > strategy_max_range_atr_mult * atr_m30)
         return false;

      // BOS: the stop-hunt bar (shift 1) closes ABOVE the last M30 swing high formed
      // BEFORE the sweep (search from shift 2 outward).
      const int sh = RecentSwingHighShift(_Period, k, k + 1, strategy_sweep_lookback + 2 * k + 2);
      if(sh < 0) return false;
      const double pre_swing_high = iHigh(_Symbol, _Period, sh); // perf-allowed
      if(pre_swing_high <= 0.0) return false;
      if(!(hunt_close > pre_swing_high))
         return false;

      // Origin = last opposite-colour (bearish) M30 candle before the BOS impulse,
      // searched from the candle before the BOS bar back through the impulse leg.
      double origin_open = 0.0, origin_close = 0.0;
      bool found_origin = false;
      for(int s = 2; s <= sh + 2; ++s)
        {
         const double o = iOpen(_Symbol, _Period, s);  // perf-allowed
         const double c = iClose(_Symbol, _Period, s);  // perf-allowed
         if(o <= 0.0 || c <= 0.0) continue;
         if(c < o) { origin_open = o; origin_close = c; found_origin = true; break; }
        }
      if(!found_origin) return false;

      // Limit at origin_fill_pct of the bearish origin body (top=open, bottom=close).
      const double body_top = origin_open;
      const double body_bot = origin_close;
      const double limit_px = body_bot + strategy_origin_fill_pct * (body_top - body_bot);
      if(limit_px <= 0.0) return false;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, hunt_low - strategy_sl_atr_mult * atr_m30);
      if(sl <= 0.0 || sl >= limit_px) return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, limit_px, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_BUY_LIMIT;
      req.price              = QM_StopRulesNormalizePrice(_Symbol, limit_px);
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "stoprun_bos_long";
      req.expiration_seconds = strategy_entry_expiry_bars * PeriodSeconds(_Period);
      return true;
     }
   else
     {
      // ---- SHORT: sweep ABOVE the highest swing-high of prior sweep_lookback bars ----
      double swept_high = 0.0;
      bool have = false;
      for(int s = k + 1; s <= strategy_sweep_lookback + k; ++s)
        {
         if(!IsSwingHigh(_Period, s, k))
            continue;
         const double hi = iHigh(_Symbol, _Period, s); // perf-allowed
         if(hi <= 0.0) continue;
         if(!have || hi > swept_high) { swept_high = hi; have = true; }
        }
      if(!have) return false;

      const double hunt_low   = iLow(_Symbol, _Period, 1);   // perf-allowed
      const double hunt_high  = iHigh(_Symbol, _Period, 1);  // perf-allowed
      const double hunt_close = iClose(_Symbol, _Period, 1); // perf-allowed
      if(hunt_low <= 0.0 || hunt_high <= 0.0 || hunt_close <= 0.0)
         return false;
      if(!((hunt_high - swept_high) >= min_pen && hunt_close < swept_high))
         return false;
      if((hunt_high - hunt_low) > strategy_max_range_atr_mult * atr_m30)
         return false;

      const int sl_shift = RecentSwingLowShift(_Period, k, k + 1, strategy_sweep_lookback + 2 * k + 2);
      if(sl_shift < 0) return false;
      const double pre_swing_low = iLow(_Symbol, _Period, sl_shift); // perf-allowed
      if(pre_swing_low <= 0.0) return false;
      if(!(hunt_close < pre_swing_low))
         return false;

      // Origin = last opposite-colour (bullish) M30 candle before the BOS impulse.
      double origin_open = 0.0, origin_close = 0.0;
      bool found_origin = false;
      for(int s = 2; s <= sl_shift + 2; ++s)
        {
         const double o = iOpen(_Symbol, _Period, s);  // perf-allowed
         const double c = iClose(_Symbol, _Period, s);  // perf-allowed
         if(o <= 0.0 || c <= 0.0) continue;
         if(c > o) { origin_open = o; origin_close = c; found_origin = true; break; }
        }
      if(!found_origin) return false;

      // Bullish origin body (top=close, bottom=open).
      const double body_top = origin_close;
      const double body_bot = origin_open;
      const double limit_px = body_top - strategy_origin_fill_pct * (body_top - body_bot);
      if(limit_px <= 0.0) return false;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, hunt_high + strategy_sl_atr_mult * atr_m30);
      if(sl <= 0.0 || sl <= limit_px) return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, limit_px, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_SELL_LIMIT;
      req.price              = QM_StopRulesNormalizePrice(_Symbol, limit_px);
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "stoprun_bos_short";
      req.expiration_seconds = strategy_entry_expiry_bars * PeriodSeconds(_Period);
      return true;
     }
  }

// Move SL to break-even once price has travelled +1R (R = |open - SL|).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_px = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_px   = PositionGetDouble(POSITION_SL);
      if(open_px <= 0.0 || sl_px <= 0.0)
         continue;

      const double r_dist = MathAbs(open_px - sl_px);
      if(r_dist <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double mkt = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(mkt <= 0.0)
         continue;

      const double moved = is_buy ? (mkt - open_px) : (open_px - mkt);
      if(moved < r_dist)
         continue; // not yet +1R

      // Already at/through break-even?
      const bool already_be = is_buy ? (sl_px >= open_px) : (sl_px <= open_px && sl_px > 0.0);
      if(already_be)
         continue;

      QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_px), "breakeven_after_1R");
     }
  }

// Time stop: close after strategy_time_stop_bars M30 bars since position open.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const long max_age = (long)strategy_time_stop_bars * (long)PeriodSeconds(_Period);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened <= 0)
         continue;
      if((long)(TimeCurrent() - opened) >= max_age)
         return true; // framework loop closes all positions for this magic
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
