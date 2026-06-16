#property strict
#property version   "5.0"
#property description "QM5_10964 FTMO Volume Profile Value Area Breakout"
// rework v2 2026-06-16 — raise strategy_max_va_width_atr default 4.0->12.0: the
// profile is built over the full 23h session window (session 0..23h default), so a
// 70% value area is structurally several H1-ATRs wide; the 4x ceiling rejected
// essentially every session -> ~0 trades / Q02 MIN_TRADES. Floor kept at 1.0.

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
input int    qm_ea_id                   = 10964;
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
input int    strategy_profile_bins        = 48;
input double strategy_value_area_pct      = 70.0;
input int    strategy_atr_period          = 14;
input double strategy_min_va_width_atr    = 1.0;
input double strategy_max_va_width_atr    = 12.0;
input double strategy_breakout_vol_mult   = 1.2;
input int    strategy_volume_lookback     = 20;
input int    strategy_pullback_bars       = 6;
input double strategy_pullback_atr_mult   = 0.15;
input double strategy_sl_atr_mult         = 0.5;
input double strategy_final_rr            = 2.5;
input int    strategy_session_start_hour  = 0;
input int    strategy_session_end_hour    = 23;
input int    strategy_max_spread_points   = 0;

datetime g_active_session_start = 0;
bool     g_long_attempted = false;
bool     g_short_attempted = false;
int      g_breakout_direction = 0;
int      g_breakout_age = 0;
double   g_breakout_level = 0.0;

datetime g_profile_session_start = 0;
bool     g_profile_ready = false;
double   g_profile_vah = 0.0;
double   g_profile_val = 0.0;
double   g_profile_vpoc = 0.0;

int Strategy_ClampInt(const int value, const int lo, const int hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

double Strategy_ClampDouble(const double value, const double lo, const double hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

datetime Strategy_SessionStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = Strategy_ClampInt(strategy_session_start_hour, 0, 23);
   dt.min = 0;
   dt.sec = 0;
   datetime start = StructToTime(dt);
   if(t < start)
      start -= 86400;
   return start;
  }

datetime Strategy_SessionEndFromStart(const datetime start)
  {
   const int start_hour = Strategy_ClampInt(strategy_session_start_hour, 0, 23);
   const int end_hour = Strategy_ClampInt(strategy_session_end_hour, 0, 23);
   int hours = end_hour - start_hour;
   if(hours <= 0)
      hours += 24;
   return start + hours * 3600;
  }

void Strategy_ResetSessionState(const datetime session_start)
  {
   if(g_active_session_start == session_start)
      return;
   g_active_session_start = session_start;
   g_long_attempted = false;
   g_short_attempted = false;
   g_breakout_direction = 0;
   g_breakout_age = 0;
   g_breakout_level = 0.0;
  }

int Strategy_SymbolSlot()
  {
   return qm_magic_slot_offset;
  }

bool Strategy_CurrentSessionOpen(const datetime session_start,
                                 const datetime closed_bar_time,
                                 double &session_open)
  {
   session_open = 0.0;
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   // perf-allowed: current-session open for value-area setup, called only after the framework QM_IsNewBar gate.
   const int copied = CopyRates(_Symbol, PERIOD_M5, session_start, closed_bar_time, rates);
   if(copied <= 0)
      return false;
   session_open = rates[0].open;
   return (session_open > 0.0);
  }

bool Strategy_BuildPreviousProfile(const datetime session_start)
  {
   if(g_profile_ready && g_profile_session_start == session_start)
      return true;

   g_profile_ready = false;
   g_profile_session_start = session_start;
   g_profile_vah = 0.0;
   g_profile_val = 0.0;
   g_profile_vpoc = 0.0;

   const datetime prev_start = session_start - 86400;
   const datetime prev_end = Strategy_SessionEndFromStart(prev_start);

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   // perf-allowed: previous-session volume profile requires raw M5 OHLC/tick volume and runs only behind the framework QM_IsNewBar gate.
   const int copied = CopyRates(_Symbol, PERIOD_M5, prev_start, prev_end, rates);
   if(copied < 12)
      return false;

   double session_low = DBL_MAX;
   double session_high = -DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].low <= 0.0 || rates[i].high <= 0.0)
         continue;
      if(rates[i].low < session_low)
         session_low = rates[i].low;
      if(rates[i].high > session_high)
         session_high = rates[i].high;
     }
   if(session_high <= session_low || session_low == DBL_MAX)
      return false;

   const int bins = Strategy_ClampInt(strategy_profile_bins, 12, 96);
   double histogram[];
   ArrayResize(histogram, bins);
   ArrayInitialize(histogram, 0.0);

   const double range = session_high - session_low;
   double total_volume = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      const double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      int idx = (int)MathFloor((typical - session_low) / range * bins);
      if(idx < 0)
         idx = 0;
      if(idx >= bins)
         idx = bins - 1;
      const double volume = (double)rates[i].tick_volume;
      histogram[idx] += volume;
      total_volume += volume;
     }
   if(total_volume <= 0.0)
      return false;

   int poc = 0;
   for(int i = 1; i < bins; ++i)
      if(histogram[i] > histogram[poc])
         poc = i;

   const double target = total_volume * Strategy_ClampDouble(strategy_value_area_pct, 50.0, 90.0) / 100.0;
   int lower = poc;
   int upper = poc;
   double selected = histogram[poc];

   while(selected < target && (lower > 0 || upper < bins - 1))
     {
      const double left_volume = (lower > 0) ? histogram[lower - 1] : -1.0;
      const double right_volume = (upper < bins - 1) ? histogram[upper + 1] : -1.0;
      if(right_volume >= left_volume && upper < bins - 1)
        {
         upper++;
         selected += histogram[upper];
        }
      else if(lower > 0)
        {
         lower--;
         selected += histogram[lower];
        }
      else
         break;
     }

   const double bin_width = range / bins;
   g_profile_val = session_low + lower * bin_width;
   g_profile_vah = session_low + (upper + 1) * bin_width;
   g_profile_vpoc = session_low + (poc + 0.5) * bin_width;
   g_profile_ready = (g_profile_vah > g_profile_val && g_profile_vpoc > 0.0);
   return g_profile_ready;
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

double Strategy_AverageTickVolume(const MqlRates &bars[], const int start_index, const int count)
  {
   if(count <= 0)
      return 0.0;
   double total = 0.0;
   int samples = 0;
   for(int i = start_index; i < start_index + count; ++i)
     {
      if(i >= ArraySize(bars))
         break;
      total += (double)bars[i].tick_volume;
      samples++;
     }
   return (samples > 0) ? total / samples : 0.0;
  }

void Strategy_ClearBreakout()
  {
   g_breakout_direction = 0;
   g_breakout_age = 0;
   g_breakout_level = 0.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_session_start_hour < 0 || strategy_session_start_hour > 23)
      return true;
   if(strategy_session_end_hour < 0 || strategy_session_end_hour > 23)
      return true;
   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }
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
   req.symbol_slot = Strategy_SymbolSlot();
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   // perf-allowed: M30 breakout/pullback state uses a bounded closed-bar slice and EntrySignal is called only after QM_IsNewBar().
   const int volume_lookback = Strategy_ClampInt(strategy_volume_lookback, 1, 200);
   int need_bars = volume_lookback + 2;
   if(need_bars < 24)
      need_bars = 24;
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, need_bars, bars);
   if(copied < volume_lookback + 2)
      return false;

   const MqlRates closed = bars[0];
   const datetime session_start = Strategy_SessionStart(closed.time);
   Strategy_ResetSessionState(session_start);

   const datetime session_end = Strategy_SessionEndFromStart(session_start);
   if(closed.time >= session_end)
      return false;

   if(!Strategy_BuildPreviousProfile(session_start))
      return false;

   double session_open = 0.0;
   if(!Strategy_CurrentSessionOpen(session_start, closed.time, session_open))
      return false;
   if(session_open < g_profile_val || session_open > g_profile_vah)
      return false;

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double atr_m30 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr_h1 <= 0.0 || atr_m30 <= 0.0)
      return false;

   const double va_width = g_profile_vah - g_profile_val;
   if(va_width < strategy_min_va_width_atr * atr_h1)
      return false;
   if(va_width > strategy_max_va_width_atr * atr_h1)
      return false;

   if(g_breakout_direction != 0)
     {
      g_breakout_age++;
      if(g_breakout_age > strategy_pullback_bars)
         Strategy_ClearBreakout();
      else
        {
         const double tolerance = strategy_pullback_atr_mult * atr_m30;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(g_breakout_direction > 0 && !g_long_attempted &&
            closed.low <= g_breakout_level + tolerance &&
            closed.close > g_breakout_level &&
            ask > 0.0)
           {
            const double sl_anchor = g_breakout_level - strategy_sl_atr_mult * atr_m30;
            const double sl = MathMin(closed.low, sl_anchor);
            if(sl > 0.0 && sl < ask)
              {
               req.type = QM_BUY;
               req.price = 0.0;
               req.sl = NormalizeDouble(sl, _Digits);
               req.tp = NormalizeDouble(ask + (ask - sl) * strategy_final_rr, _Digits);
               req.reason = "FTMO_VA_BREAK_LONG_PULLBACK";
               g_long_attempted = true;
               Strategy_ClearBreakout();
               return true;
              }
           }

         if(g_breakout_direction < 0 && !g_short_attempted &&
            closed.high >= g_breakout_level - tolerance &&
            closed.close < g_breakout_level &&
            bid > 0.0)
           {
            const double sl_anchor = g_breakout_level + strategy_sl_atr_mult * atr_m30;
            const double sl = MathMax(closed.high, sl_anchor);
            if(sl > bid)
              {
               req.type = QM_SELL;
               req.price = 0.0;
               req.sl = NormalizeDouble(sl, _Digits);
               req.tp = NormalizeDouble(bid - (sl - bid) * strategy_final_rr, _Digits);
               req.reason = "FTMO_VA_BREAK_SHORT_PULLBACK";
               g_short_attempted = true;
               Strategy_ClearBreakout();
               return true;
              }
           }
        }
     }

   if(g_breakout_direction == 0)
     {
      const double avg_volume = Strategy_AverageTickVolume(bars, 1, volume_lookback);
      const bool volume_ok = (avg_volume > 0.0 && (double)closed.tick_volume >= strategy_breakout_vol_mult * avg_volume);
      if(volume_ok && closed.close > g_profile_vah && !g_long_attempted)
        {
         g_breakout_direction = 1;
         g_breakout_age = 0;
         g_breakout_level = g_profile_vah;
         return false;
        }
      if(volume_ok && closed.close < g_profile_val && !g_short_attempted)
        {
         g_breakout_direction = -1;
         g_breakout_age = 0;
         g_breakout_level = g_profile_val;
         return false;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         if(current_sl >= open_price)
            continue;
         const double risk = open_price - current_sl;
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(risk > 0.0 && bid >= open_price + risk)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "tp1_touch_move_sl_breakeven");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(current_sl <= open_price)
            continue;
         const double risk = current_sl - open_price;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(risk > 0.0 && ask <= open_price - risk)
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "tp1_touch_move_sl_breakeven");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   const datetime now = TimeCurrent();
   const datetime session_start = Strategy_SessionStart(now);
   const datetime session_end = Strategy_SessionEndFromStart(session_start);
   return (now >= session_end);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade2(_Symbol, broker_time, qm_news_temporal, qm_news_compliance))
      return true;
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
