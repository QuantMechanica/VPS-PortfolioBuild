#property strict
#property version   "5.0"
#property description "QM5_11275 iaf-st-ema — SuperTrend flip + EMA-crossover confirmation (long-only, H2)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11275 iaf-st-ema
// -----------------------------------------------------------------------------
// Source: coding-kitties/investing-algorithm-framework,
//   examples/tutorial/strategies/supertrend_ema_confirmation/strategy.py
// Card: artifacts/cards_approved/QM5_11275_iaf-st-ema.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1; H2 base TF):
//   SuperTrend(ATR length 10, factor 3.0) — deterministic closed-bar recursion,
//     seeded from hl2 (bar median), NOT from a band several ATR away. ONE forward
//     reconstruction over a bounded warmup window yields dir@1 and dir@2.
//     A SuperTrend flip (dir@2<=0 && dir@1>0) is the single ENTRY EVENT;
//     a bearish flip (dir@2>=0 && dir@1<0) is the single EXIT EVENT.
//   EMA trend STATE: EMA(short) crossed above EMA(long) within the lookback
//     window (a state observed over the window, NOT a same-bar second event).
//   RSI(14) gate: RSI < rsi_upper (70) on the closed bar.
//   Bollinger(20, 2.0) gate: close < upper band on the closed bar.
//   Long entry  : flat, ST flipped bullish (event) AND EMA-short>EMA-long state
//                 confirmed within lookback AND RSI<70 AND close<BB upper.
//   Manual exit : ST flipped bearish (event) AND EMA-short<EMA-long state within
//                 lookback. SUPPRESSED when RSI<=rsi_lower(30) AND close<=BB lower
//                 (let the ATR stop/target handle the capitulation case).
//   Stop / take : ATR-derived fixed-risk stop & RR target (source 5% SL / 10% TP
//                 → 1:2 RR translated to fixed-risk ATR semantics).
//   Spread guard: skip only a genuinely wide spread (fail-OPEN on .DWX 0 spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs + the SuperTrend recursion helper
// are EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11275;
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
input int    strategy_st_atr_period      = 10;    // SuperTrend ATR length
input double strategy_st_factor          = 3.0;   // SuperTrend multiplier
input int    strategy_ema_short_period   = 20;    // EMA short (confirmation)
input int    strategy_ema_long_period    = 100;   // EMA long (confirmation)
input int    strategy_confirm_lookback   = 10;    // bars to confirm EMA state / ST flip window
input int    strategy_rsi_period         = 14;    // RSI period
input double strategy_rsi_upper          = 70.0;  // block long entry if RSI >= this
input double strategy_rsi_lower          = 30.0;  // suppress exit if RSI <= this
input int    strategy_bb_period          = 20;    // Bollinger period
input double strategy_bb_deviation       = 2.0;   // Bollinger deviation
input double strategy_sl_atr_mult        = 3.0;   // stop distance = mult * ATR (ST ATR)
input double strategy_tp_rr              = 2.0;   // take-profit RR multiple (5%/10% -> 1:2)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// SuperTrend — deterministic closed-bar recursion.
// -----------------------------------------------------------------------------
// Reconstructs final upper/lower bands and direction forward from a warmup
// origin to the requested end shift. Direction is seeded from hl2 (the bar
// median) on the first reconstructed bar, NOT from a band several ATR away
// (DWX invariant #8 — seeding from a far band pins the trend so it never flips).
//
// Fills `dir_out[k]` with the SuperTrend direction at shift (1+k) for
// k = 0 .. n_shifts-1 (so dir_out[0] = direction at the last closed bar):
//   +1 = bullish (price above SuperTrend line), -1 = bearish, 0 = unavailable.
// ONE forward reconstruction from a warmup origin down to shift 1 produces the
// whole series — NOT a fresh convergent reconstruction per shift (DWX inv. #8).
// Direction is seeded from hl2 (the bar median) on the first reconstructed bar.
// The per-bar iHigh/iLow/iClose reads are perf-allowed bespoke structural math;
// the loop is O(warmup + n_shifts) and runs at most once per OnTick call.
// Returns true if the series was populated.
bool QM_SuperTrendDirSeries(const string sym, const ENUM_TIMEFRAMES tf,
                            const int atr_period, const double factor,
                            const int n_shifts, const int warmup_bars,
                            int &dir_out[])
  {
   if(n_shifts < 1)
      return false;
   ArrayResize(dir_out, n_shifts);
   ArrayInitialize(dir_out, 0);

   // Reconstruct from the oldest warmup bar down to shift 1.
   const int origin = n_shifts + warmup_bars; // oldest shift in the window
   double prev_final_upper = 0.0;
   double prev_final_lower = 0.0;
   int    prev_dir         = 0;
   double prev_close       = 0.0;
   bool   seeded           = false;

   for(int s = origin; s >= 1; --s)
     {
      const double high  = iHigh(sym, tf, s);   // perf-allowed: bespoke ST math
      const double low   = iLow(sym, tf, s);
      const double close = iClose(sym, tf, s);
      const double atr   = QM_ATR(sym, tf, atr_period, s); // pooled reader
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         continue; // skip incomplete bars; recursion resumes when data is valid

      const double hl2         = (high + low) / 2.0;
      const double basic_upper = hl2 + factor * atr;
      const double basic_lower = hl2 - factor * atr;

      int dir;
      if(!seeded)
        {
         // Seed from hl2: the first reconstructed bar establishes the bands and
         // a direction from the bar median (close vs hl2), never from a far band.
         prev_final_upper = basic_upper;
         prev_final_lower = basic_lower;
         dir              = (close >= hl2) ? 1 : -1;
         prev_dir         = dir;
         prev_close       = close;
         seeded           = true;
        }
      else
        {
         // Final band recursion (canonical SuperTrend form).
         double final_upper = basic_upper;
         if(!(basic_upper < prev_final_upper || prev_close > prev_final_upper))
            final_upper = prev_final_upper;

         double final_lower = basic_lower;
         if(!(basic_lower > prev_final_lower || prev_close < prev_final_lower))
            final_lower = prev_final_lower;

         // Direction recursion: flip only on a close crossing the active band.
         if(prev_dir <= 0)
            dir = (close > prev_final_upper) ? 1 : -1;   // was bearish (line=upper)
         else
            dir = (close < prev_final_lower) ? -1 : 1;   // was bullish (line=lower)

         prev_final_upper = final_upper;
         prev_final_lower = final_lower;
         prev_dir         = dir;
         prev_close       = close;
        }

      // Record direction for shifts within the requested window (s in 1..n_shifts).
      if(s >= 1 && s <= n_shifts)
         dir_out[s - 1] = dir;
     }

   return seeded;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_st_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int warmup = MathMax(strategy_confirm_lookback + 5, 3 * strategy_st_atr_period);

   // --- ENTRY EVENT: SuperTrend flipped bullish within the lookback window. ---
   // The flip is the SINGLE event. Search the window for a bar where dir goes
   // from <=0 (prev) to >0 (now). dir@1 must be bullish (we only enter long
   // while ST is currently bullish).
   const int dir1 = QM_SuperTrendDir(_Symbol, _Period, strategy_st_atr_period,
                                     strategy_st_factor, 1, warmup);
   if(dir1 <= 0)
      return false; // ST must currently be bullish

   bool st_flipped_bull = false;
   for(int s = 1; s <= strategy_confirm_lookback; ++s)
     {
      const int d_now  = QM_SuperTrendDir(_Symbol, _Period, strategy_st_atr_period,
                                          strategy_st_factor, s, warmup);
      const int d_prev = QM_SuperTrendDir(_Symbol, _Period, strategy_st_atr_period,
                                          strategy_st_factor, s + 1, warmup);
      if(d_now > 0 && d_prev <= 0)
        {
         st_flipped_bull = true;
         break;
        }
     }
   if(!st_flipped_bull)
      return false;

   // --- EMA STATE: short crossed above long within the same lookback window. ---
   // State, not a second same-bar event: somewhere in the window the short EMA
   // transitioned from <= long to > long, and it is currently short > long.
   const double ema_short_1 = QM_EMA(_Symbol, _Period, strategy_ema_short_period, 1);
   const double ema_long_1  = QM_EMA(_Symbol, _Period, strategy_ema_long_period, 1);
   if(ema_short_1 <= 0.0 || ema_long_1 <= 0.0)
      return false;
   if(!(ema_short_1 > ema_long_1))
      return false;

   bool ema_crossed_up = false;
   for(int s = 1; s <= strategy_confirm_lookback; ++s)
     {
      const double es_now  = QM_EMA(_Symbol, _Period, strategy_ema_short_period, s);
      const double el_now  = QM_EMA(_Symbol, _Period, strategy_ema_long_period, s);
      const double es_prev = QM_EMA(_Symbol, _Period, strategy_ema_short_period, s + 1);
      const double el_prev = QM_EMA(_Symbol, _Period, strategy_ema_long_period, s + 1);
      if(es_now <= 0.0 || el_now <= 0.0 || es_prev <= 0.0 || el_prev <= 0.0)
         continue;
      if(es_prev <= el_prev && es_now > el_now)
        {
         ema_crossed_up = true;
         break;
        }
     }
   if(!ema_crossed_up)
      return false;

   // --- RSI gate: do not chase overextended longs. ---
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;
   if(rsi1 >= strategy_rsi_upper)
      return false;

   // --- Bollinger gate: close below the upper band (not overextended). ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period,
                                       strategy_bb_deviation, 1);
   if(bb_upper <= 0.0)
      return false;
   if(!(close1 < bb_upper))
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_st_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "st_flip_ema_confirm_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop / RR target. The
// SuperTrend-flip defensive exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: SuperTrend flipped bearish (EVENT) within the lookback AND the
// EMA state is bearish (short < long) within the lookback. Suppressed in the
// capitulation case (RSI <= lower AND close <= BB lower) — let SL/TP handle it.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int warmup = MathMax(strategy_confirm_lookback + 5, 3 * strategy_st_atr_period);

   // --- EXIT EVENT: SuperTrend flipped bearish within the lookback window. ---
   const int dir1 = QM_SuperTrendDir(_Symbol, _Period, strategy_st_atr_period,
                                     strategy_st_factor, 1, warmup);
   bool st_flipped_bear = false;
   for(int s = 1; s <= strategy_confirm_lookback; ++s)
     {
      const int d_now  = QM_SuperTrendDir(_Symbol, _Period, strategy_st_atr_period,
                                          strategy_st_factor, s, warmup);
      const int d_prev = QM_SuperTrendDir(_Symbol, _Period, strategy_st_atr_period,
                                          strategy_st_factor, s + 1, warmup);
      if(d_now < 0 && d_prev >= 0)
        {
         st_flipped_bear = true;
         break;
        }
     }
   if(!st_flipped_bear || dir1 >= 0)
      return false;

   // --- EMA STATE: short below long within the lookback window. ---
   const double ema_short_1 = QM_EMA(_Symbol, _Period, strategy_ema_short_period, 1);
   const double ema_long_1  = QM_EMA(_Symbol, _Period, strategy_ema_long_period, 1);
   if(ema_short_1 <= 0.0 || ema_long_1 <= 0.0)
      return false;
   if(!(ema_short_1 < ema_long_1))
      return false;

   bool ema_crossed_down = false;
   for(int s = 1; s <= strategy_confirm_lookback; ++s)
     {
      const double es_now  = QM_EMA(_Symbol, _Period, strategy_ema_short_period, s);
      const double el_now  = QM_EMA(_Symbol, _Period, strategy_ema_long_period, s);
      const double es_prev = QM_EMA(_Symbol, _Period, strategy_ema_short_period, s + 1);
      const double el_prev = QM_EMA(_Symbol, _Period, strategy_ema_long_period, s + 1);
      if(es_now <= 0.0 || el_now <= 0.0 || es_prev <= 0.0 || el_prev <= 0.0)
         continue;
      if(es_prev >= el_prev && es_now < el_now)
        {
         ema_crossed_down = true;
         break;
        }
     }
   if(!ema_crossed_down)
      return false;

   // --- Suppression: capitulation case lets SL/TP handle the exit. ---
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period,
                                       strategy_bb_deviation, 1);
   if(rsi1 > 0.0 && bb_lower > 0.0 && close1 > 0.0 &&
      rsi1 <= strategy_rsi_lower && close1 <= bb_lower)
      return false; // suppress the manual exit

   return true;
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
