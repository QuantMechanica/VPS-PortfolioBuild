#property strict
#property version   "5.0"
#property description "QM5_10751 TradingView ORB Extension Custom Stop (EOD flat)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10751;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Opening-range window in NEW YORK exchange time (HHMM). Source default 09:30-10:30.
// The window is converted to broker time DST-aware via QM_BrokerToUTC + US-DST
// helpers; on DXZ NY-close broker, 09:30 ET == broker ~16:30. Do NOT pass broker
// hours here — pass exchange (NY) hours; the EA converts each bar back to NY.
input int    strategy_or_start_hhmm_ny      = 930;   // OR window open (NY)
input int    strategy_or_end_hhmm_ny        = 1030;  // OR window close (NY); range built over [start,end)
input int    strategy_eod_flat_hhmm_ny      = 1600;  // force-flat time (NY); default 16:00
input int    strategy_entry_delay_bars      = 0;     // bars to wait after OR window before allowing entry
input int    strategy_direction             = 0;     // 0 = both, 1 = long only, -1 = short only
// Target: 0.5 extension of the BODY range projected beyond the body side.
input double strategy_tp_ext_mult           = 0.50;  // body-range extension multiple for TP
// Stop-loss mode: 0 = body-range 0.5 extension beyond opposite body side,
//                 1 = ATR(period) * mult, 2 = recent swing low/high over lookback.
input int    strategy_sl_mode               = 0;     // P2 baseline A = 0
input double strategy_sl_body_ext_mult      = 0.50;  // body-range extension for SL (mode 0)
input int    strategy_atr_period            = 14;    // ATR period (mode 1)
input double strategy_atr_sl_mult           = 1.50;  // ATR multiple (mode 1)
input int    strategy_swing_lookback        = 10;    // recent swing lookback bars (mode 2)
// Range sanity bounds (reject degenerate / runaway ranges; ATR-scaled).
input double strategy_min_range_atr_mult    = 0.10;  // OR range must be >= this * ATR
input double strategy_max_range_atr_mult    = 5.00;  // OR range must be <= this * ATR
input int    strategy_max_spread_points     = 1000;  // fail-open: 0 spread never blocks
input int    strategy_or_scan_bars          = 256;   // bounded closed-bar scan for OR + swing

// ---- File-scope per-session cached state (advanced on closed bars only) ------
int    g_session_key      = -1;     // NY day-of-year key for current session
bool   g_trade_taken      = false;  // one entry per symbol/session
bool   g_range_ready      = false;  // OR window has closed and range was computed
bool   g_range_valid      = false;  // computed range passed sanity bounds
double g_wick_high        = 0.0;    // absolute session high over OR window (long trigger)
double g_wick_low         = 0.0;    // absolute session low over OR window (short trigger)
double g_body_high        = 0.0;    // highest(open,close) over OR window
double g_body_low         = 0.0;    // lowest(open,close) over OR window

int Strategy_HhmmToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return -1;
   return hh * 60 + mm;
  }

// Convert broker time -> NY exchange time, DST-aware (US DST only).
datetime Strategy_BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 3600 : 5 * 3600);
  }

int Strategy_MinutesOfDayNY(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_BrokerToNY(broker_time), dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DateKeyNY(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_BrokerToNY(broker_time), dt);
   return dt.year * 1000 + dt.day_of_year;
  }

// Minutes elapsed since session start, wrap-safe across midnight.
int Strategy_ElapsedFromStart(const int minute, const int start_min)
  {
   if(minute >= start_min)
      return minute - start_min;
   return minute + 1440 - start_min;
  }

// True if `minute` falls in [start_min, end_min) (wrap-safe).
bool Strategy_TimeInWindow(const int minute, const int start_min, const int end_min)
  {
   if(start_min < 0 || end_min < 0 || start_min == end_min)
      return false;
   if(start_min < end_min)
      return (minute >= start_min && minute < end_min);
   return (minute >= start_min || minute < end_min);
  }

void Strategy_ResetSessionIfNeeded(const datetime broker_time)
  {
   const int key = Strategy_DateKeyNY(broker_time);
   if(key == g_session_key)
      return;

   g_session_key = key;
   g_trade_taken = false;
   g_range_ready = false;
   g_range_valid = false;
   g_wick_high   = 0.0;
   g_wick_low    = 0.0;
   g_body_high   = 0.0;
   g_body_low    = 0.0;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

// Spread guard — fail-open on .DWX zero spread (ask==bid in tester). Only a
// genuinely wide spread blocks; zero modeled spread never blocks.
bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;          // zero PRICE is invalid, not a spread block
   if(ask <= bid)
      return true;           // 0 modeled spread (.DWX) — never block
   return ((ask - bid) / point) <= strategy_max_spread_points;
  }

// Build the opening range (wick + body) once the OR window has closed. Bounded
// closed-bar scan; runs only from Strategy_EntrySignal after QM_IsNewBar().
void Strategy_BuildOpeningRange()
  {
   if(g_range_ready)
      return;

   const int start_min = Strategy_HhmmToMinutes(strategy_or_start_hhmm_ny);
   const int end_min   = Strategy_HhmmToMinutes(strategy_or_end_hhmm_ny);
   if(start_min < 0 || end_min < 0 || start_min == end_min)
      return;

   // Wait until the OR window has fully closed for today before locking the range.
   const int now_min = Strategy_MinutesOfDayNY(TimeCurrent());
   const int win_len = Strategy_ElapsedFromStart(end_min, start_min);
   if(Strategy_ElapsedFromStart(now_min, start_min) < win_len)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars = MathMax(4, MathMin(strategy_or_scan_bars, 512));
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, bars, rates); // perf-allowed: bounded OR scan; runs only after QM_IsNewBar() from EntrySignal.
   if(copied <= 0)
      return;

   const int today_key = Strategy_DateKeyNY(TimeCurrent());
   double wick_high = -DBL_MAX;
   double wick_low  =  DBL_MAX;
   double body_high = -DBL_MAX;
   double body_low  =  DBL_MAX;
   bool   found     = false;

   for(int i = 0; i < copied; ++i)
     {
      if(Strategy_DateKeyNY(rates[i].time) != today_key)
         continue;

      const int bar_min = Strategy_MinutesOfDayNY(rates[i].time);
      if(!Strategy_TimeInWindow(bar_min, start_min, end_min))
         continue;
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high < rates[i].low)
         continue;

      const double body_hi = MathMax(rates[i].open, rates[i].close);
      const double body_lo = MathMin(rates[i].open, rates[i].close);

      wick_high = MathMax(wick_high, rates[i].high);
      wick_low  = MathMin(wick_low,  rates[i].low);
      body_high = MathMax(body_high, body_hi);
      body_low  = MathMin(body_low,  body_lo);
      found     = true;
     }

   g_range_ready = true;
   g_range_valid = false;
   if(!found || wick_high <= wick_low || body_high < body_low || wick_low <= 0.0)
      return;

   // Sanity-bound the wick range against ATR (reject degenerate / runaway days).
   const double atr   = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double range = wick_high - wick_low;
   if(atr <= 0.0 || range < strategy_min_range_atr_mult * atr || range > strategy_max_range_atr_mult * atr)
      return;

   g_wick_high   = wick_high;
   g_wick_low    = wick_low;
   g_body_high   = body_high;
   g_body_low    = body_low;
   g_range_valid = true;
  }

// Read the last closed bar's OHLC (shift 1). perf-allowed: single closed bar.
bool Strategy_ReadLastClosedBar(double &o1, double &h1, double &l1, double &c1)
  {
   o1 = 0.0; h1 = 0.0; l1 = 0.0; c1 = 0.0;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, rates); // perf-allowed: one closed bar; caller inside QM_IsNewBar gate.
   if(copied != 1)
      return false;
   o1 = rates[0].open;
   h1 = rates[0].high;
   l1 = rates[0].low;
   c1 = rates[0].close;
   return (c1 > 0.0 && h1 >= l1);
  }

// Recent swing low/high over `lookback` closed bars (shift 1..lookback).
// perf-allowed: bounded structural scan, runs once per closed bar from EntrySignal.
bool Strategy_RecentSwing(const int lookback, double &swing_high, double &swing_low)
  {
   swing_high = -DBL_MAX;
   swing_low  =  DBL_MAX;
   const int n = MathMax(2, MathMin(lookback, strategy_or_scan_bars));
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, n, rates); // perf-allowed: bounded swing scan after QM_IsNewBar().
   if(copied <= 0)
      return false;
   bool found = false;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high < rates[i].low)
         continue;
      swing_high = MathMax(swing_high, rates[i].high);
      swing_low  = MathMin(swing_low,  rates[i].low);
      found = true;
     }
   return found;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   Strategy_ResetSessionIfNeeded(TimeCurrent());

   // Never block management/exit of an already-open position.
   if(Strategy_HasOpenPosition())
      return false;
   if(g_trade_taken)
      return true;
   if(!Strategy_SpreadAllowed())
      return true;

   const int start_min = Strategy_HhmmToMinutes(strategy_or_start_hhmm_ny);
   const int end_min   = Strategy_HhmmToMinutes(strategy_or_end_hhmm_ny);
   const int eod_min   = Strategy_HhmmToMinutes(strategy_eod_flat_hhmm_ny);
   if(start_min < 0 || end_min < 0 || eod_min < 0)
      return true;

   const int now_min = Strategy_MinutesOfDayNY(TimeCurrent());

   // Only allow entries between OR-window-close (+delay) and EOD-flat time.
   const int win_len      = Strategy_ElapsedFromStart(end_min, start_min);
   const int delay_min    = MathMax(0, strategy_entry_delay_bars) * (PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60);
   const int elapsed_now  = Strategy_ElapsedFromStart(now_min, start_min);
   if(elapsed_now < win_len + delay_min)
      return true;                                   // still inside OR window or entry delay
   if(!Strategy_TimeInWindow(now_min, start_min, eod_min))
      return true;                                   // past EOD flat or wrong part of day

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_ResetSessionIfNeeded(TimeCurrent());

   if(g_trade_taken || Strategy_HasOpenPosition())
      return false;
   if(strategy_tp_ext_mult <= 0.0)
      return false;

   Strategy_BuildOpeningRange();
   if(!g_range_ready || !g_range_valid)
      return false;

   double o1, h1, l1, c1;
   if(!Strategy_ReadLastClosedBar(o1, h1, l1, c1))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double body_range = g_body_high - g_body_low;
   if(body_range <= 0.0)
      return false;
   const double tp_dist = strategy_tp_ext_mult * body_range;  // 0.5 body-range extension

   // ----- LONG: breakout candle closed above wick high -----
   if(strategy_direction >= 0 && c1 > g_wick_high)
     {
      const double tp_long = g_body_high + tp_dist;  // 0.5 ext above body high
      // Fresh-breakout filter: reject if the breakout candle already touched/
      // exceeded the TP extension before close (overextended).
      if(h1 >= tp_long)
         return false;

      const double entry = ask;
      double sl = 0.0;
      if(strategy_sl_mode == 1)
        {
         sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
        }
      else if(strategy_sl_mode == 2)
        {
         double sh, slo;
         if(!Strategy_RecentSwing(strategy_swing_lookback, sh, slo))
            return false;
         sl = slo;
        }
      else // mode 0: 0.5 body-range extension below the opposite (lower) body side
        {
         sl = g_body_low - strategy_sl_body_ext_mult * body_range;
        }

      const double tp = QM_StopRulesNormalizePrice(_Symbol, tp_long);
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl > 0.0 && sl < entry && tp > entry)
        {
         req.type   = QM_BUY;
         req.price  = QM_StopRulesNormalizePrice(_Symbol, entry);
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "TV_ORB_EXT_LONG";
         g_trade_taken = true;
         return true;
        }
      return false;
     }

   // ----- SHORT: breakout candle closed below wick low -----
   if(strategy_direction <= 0 && c1 < g_wick_low)
     {
      const double tp_short = g_body_low - tp_dist; // 0.5 ext below body low
      // Fresh-breakout filter: reject if breakout candle low already reached TP.
      if(l1 <= tp_short)
         return false;

      const double entry = bid;
      double sl = 0.0;
      if(strategy_sl_mode == 1)
        {
         sl = QM_StopATR(_Symbol, QM_SELL, entry, strategy_atr_period, strategy_atr_sl_mult);
        }
      else if(strategy_sl_mode == 2)
        {
         double sh, slo;
         if(!Strategy_RecentSwing(strategy_swing_lookback, sh, slo))
            return false;
         sl = sh;
        }
      else // mode 0: 0.5 body-range extension above the opposite (upper) body side
        {
         sl = g_body_high + strategy_sl_body_ext_mult * body_range;
        }

      const double tp = QM_StopRulesNormalizePrice(_Symbol, tp_short);
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl > entry && tp > 0.0 && tp < entry)
        {
         req.type   = QM_SELL;
         req.price  = QM_StopRulesNormalizePrice(_Symbol, entry);
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "TV_ORB_EXT_SHORT";
         g_trade_taken = true;
         return true;
        }
      return false;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline brackets the trade with TP + SL at entry and forces EOD flat.
   // No trailing, break-even, partial-close, or reversal management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end). EOD force-flat at strategy_eod_flat_hhmm_ny.
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const int start_min = Strategy_HhmmToMinutes(strategy_or_start_hhmm_ny);
   const int eod_min   = Strategy_HhmmToMinutes(strategy_eod_flat_hhmm_ny);
   if(start_min < 0 || eod_min < 0)
      return false;

   // Flat any time outside the [OR-start, EOD-flat) intraday window.
   return !Strategy_TimeInWindow(Strategy_MinutesOfDayNY(TimeCurrent()), start_min, eod_min);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
