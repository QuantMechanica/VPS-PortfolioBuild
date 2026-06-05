#property strict
#property version   "5.0"
#property description "QM5_10791 TradingView Trend Trader + STC confirmation (tv-stc-tt)"
// Strategy Card: QM5_10791_tv-stc-tt (source d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7),
// G0 APPROVED 2026-05-22. Trend-following + momentum-confirmation:
// Schaff Trend Cycle (STC) signal must agree with an Andrew-Abraham Trend-Trader
// (TT) ATR-trailing trend line. Long when STC crosses up out of oversold while the
// TT line is in an uptrend (close above the line); short is the mirror.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10791;
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
// --- Schaff Trend Cycle (STC) — source defaults 23/50/10, factor 0.5 ---
input int    stc_fast_length            = 23;     // MACD fast EMA length
input int    stc_slow_length            = 50;     // MACD slow EMA length
input int    stc_cycle_length           = 10;     // STC stochastic cycle length
input double stc_factor                 = 0.5;    // STC smoothing factor (0..1)
input double stc_buy_level              = 25.0;   // upward cross of this = buy signal
input double stc_sell_level             = 75.0;   // downward cross of this = sell signal
// --- Trend Trader (Abraham) ATR-trailing trend line ---
input int    tt_atr_period              = 14;     // ATR period for the TT line
input double tt_atr_mult                = 3.0;    // ATR multiple (line sensitivity)
// --- Bracket stop / target (ATR multiples, P2 baseline) ---
input int    sl_atr_period              = 14;     // ATR period for SL/TP brackets
input double sl_atr_mult                = 2.0;    // SL = sl_atr_mult * ATR
input double tp_atr_mult                = 3.0;    // TP = tp_atr_mult * ATR (1.5R vs SL)
// --- Optional filters (P3 axes; OFF for the P2 baseline) ---
input bool   use_ema_filter             = false;  // require close on EMA side
input int    ema_filter_period          = 200;    // EMA length for side filter
input bool   use_adx_filter             = false;  // require ADX >= adx_min
input int    adx_period                 = 14;     // ADX period
input double adx_min                    = 25.0;   // minimum ADX to allow entries
input double max_spread_points          = 0.0;    // No-Trade spread guard (0 = off)

// -----------------------------------------------------------------------------
// Cached closed-bar strategy state. Recomputed exactly once per new closed bar
// inside Strategy_EntrySignal (the framework gates that call with QM_IsNewBar).
// Strategy_ExitSignal runs every tick and reads ONLY these cached values — no
// per-tick recompute of STC / TT (INTRADAY DISCIPLINE: closed-bar cache).
// -----------------------------------------------------------------------------
#define QM_STC_WARMUP 100

double g_stc_now    = 0.0;     // STC at shift 1 (last closed bar)
double g_stc_prev   = 0.0;     // STC at shift 2
double g_tt_line    = 0.0;     // TT trend line at shift 1
int    g_tt_trend   = 0;       // +1 uptrend / -1 downtrend
double g_close1     = 0.0;     // close of last closed bar
bool   g_long_ok    = false;   // full long-entry condition met on last closed bar
bool   g_short_ok   = false;   // full short-entry condition met on last closed bar
bool   g_exit_long  = false;   // long-exit condition met on last closed bar
bool   g_exit_short = false;   // short-exit condition met on last closed bar
bool   g_state_ready = false;  // cache populated at least once

// Compute the Schaff Trend Cycle at shift 1 and shift 2 using the framework's
// pooled MACD reader. The STC is MACD passed through two stochastic+smoothing
// passes (factor-EMA). The full recursion is rebuilt over a fixed warmup window
// once per new bar — the factor smoothing converges well within the window, so
// the two newest values are exact. Bounded: ~115 bars * cycle inner loop.
bool ComputeSTCPair(double &out_stc1, double &out_stc2)
  {
   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int cyc = (stc_cycle_length > 1) ? stc_cycle_length : 2;
   const int n = QM_STC_WARMUP + cyc + 5;
   if(n < 4)
      return false;

   double macd[];
   double pf[];
   double stc[];
   ArrayResize(macd, n);
   ArrayResize(pf, n);
   ArrayResize(stc, n);

   // index 0..n-1 == shift n (oldest) .. 1 (newest closed bar)
   for(int idx = 0; idx < n; ++idx)
     {
      const int shift = n - idx;
      macd[idx] = QM_MACD_Main(sym, tf, stc_fast_length, stc_slow_length, 9, shift);
     }

   // First stochastic of MACD + factor smoothing -> pf
   double prev_pf = 0.0;
   bool   have_pf = false;
   for(int idx = 0; idx < n; ++idx)
     {
      int lo_i = idx - cyc + 1;
      if(lo_i < 0)
         lo_i = 0;
      double mn = macd[lo_i];
      double mx = macd[lo_i];
      for(int j = lo_i + 1; j <= idx; ++j)
        {
         if(macd[j] < mn) mn = macd[j];
         if(macd[j] > mx) mx = macd[j];
        }
      const double rng = mx - mn;
      const double f1 = (rng > 0.0) ? (macd[idx] - mn) / rng * 100.0 : (have_pf ? prev_pf : 0.0);
      const double cur = have_pf ? (prev_pf + stc_factor * (f1 - prev_pf)) : f1;
      pf[idx] = cur;
      prev_pf = cur;
      have_pf = true;
     }

   // Second stochastic of pf + factor smoothing -> STC
   double prev_st = 0.0;
   bool   have_st = false;
   for(int idx = 0; idx < n; ++idx)
     {
      int lo_i = idx - cyc + 1;
      if(lo_i < 0)
         lo_i = 0;
      double mn = pf[lo_i];
      double mx = pf[lo_i];
      for(int j = lo_i + 1; j <= idx; ++j)
        {
         if(pf[j] < mn) mn = pf[j];
         if(pf[j] > mx) mx = pf[j];
        }
      const double rng = mx - mn;
      const double f2 = (rng > 0.0) ? (pf[idx] - mn) / rng * 100.0 : (have_st ? prev_st : 0.0);
      const double cur = have_st ? (prev_st + stc_factor * (f2 - prev_st)) : f2;
      stc[idx] = cur;
      prev_st = cur;
      have_st = true;
     }

   out_stc1 = stc[n - 1];
   out_stc2 = stc[n - 2];
   return true;
  }

// Compute the Andrew-Abraham Trend Trader line + trend state at shift 1. This is
// an ATR-trailing trend line (SuperTrend-style): one line that flips between the
// volatility floor (uptrend) and ceiling (downtrend). "Close above the TT line"
// is equivalent to "TT trend is up" by construction. Rebuilt over the warmup
// window once per new bar; raw OHLC reads are gated to this closed-bar path.
bool ComputeTT(double &out_line, int &out_trend)
  {
   const string sym = _Symbol;
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int n = QM_STC_WARMUP;

   double final_upper = 0.0;
   double final_lower = 0.0;
   int    trend = 1;
   double prev_close = 0.0;
   double line = 0.0;
   bool   init = false;

   for(int idx = 0; idx < n; ++idx)
     {
      const int shift = n - idx;
      const double hi = iHigh(sym, tf, shift);   // perf-allowed
      const double lo = iLow(sym, tf, shift);    // perf-allowed
      const double cl = iClose(sym, tf, shift);  // perf-allowed
      const double atr = QM_ATR(sym, tf, tt_atr_period, shift);
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0 || atr <= 0.0)
        {
         prev_close = cl;
         continue;
        }
      const double hl2 = (hi + lo) / 2.0;
      const double basic_upper = hl2 + tt_atr_mult * atr;
      const double basic_lower = hl2 - tt_atr_mult * atr;

      if(!init)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         trend = 1;
         line = final_lower;
         prev_close = cl;
         init = true;
         continue;
        }

      // Trail the bands using the PREVIOUS bar's close.
      if(basic_upper < final_upper || prev_close > final_upper)
         final_upper = basic_upper;
      if(basic_lower > final_lower || prev_close < final_lower)
         final_lower = basic_lower;

      // Flip the trend using the CURRENT bar's close against the trailed bands.
      if(trend == 1)
        {
         if(cl < final_lower)
            trend = -1;
        }
      else
        {
         if(cl > final_upper)
            trend = 1;
        }

      line = (trend == 1) ? final_lower : final_upper;
      prev_close = cl;
     }

   out_line = line;
   out_trend = trend;
   return init;
  }

// True if this EA already holds a position on the current symbol.
bool QM_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
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

// Resolve the type of this EA's open position on the current symbol.
bool QM_OurPositionType(ENUM_POSITION_TYPE &out_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      out_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// Recompute STC + TT and the derived entry/exit booleans for the last closed
// bar. Called once per new closed bar from Strategy_EntrySignal.
void QM_ComputeState()
  {
   g_state_ready = false;

   double stc1 = 0.0, stc2 = 0.0, ttl = 0.0;
   int ttr = 0;
   if(!ComputeSTCPair(stc1, stc2))
      return;
   if(!ComputeTT(ttl, ttr))
      return;

   g_stc_now  = stc1;
   g_stc_prev = stc2;
   g_tt_line  = ttl;
   g_tt_trend = ttr;
   g_close1   = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);  // perf-allowed
   if(g_close1 <= 0.0)
      return;

   const bool stc_buy     = (g_stc_prev <= stc_buy_level  && g_stc_now > stc_buy_level);
   const bool stc_sell    = (g_stc_prev >= stc_sell_level && g_stc_now < stc_sell_level);
   const bool stc_rising  = (g_stc_now > g_stc_prev);
   const bool stc_falling = (g_stc_now < g_stc_prev);

   const bool close_above_tt = (g_close1 > g_tt_line);
   const bool close_below_tt = (g_close1 < g_tt_line);
   const bool tt_up = (g_tt_trend == 1);
   const bool tt_dn = (g_tt_trend == -1);

   // Optional directional EMA filter (P3 axis).
   bool ema_ok_long = true, ema_ok_short = true;
   if(use_ema_filter)
     {
      const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, ema_filter_period, 1);
      ema_ok_long  = (ema > 0.0) ? (g_close1 > ema) : true;
      ema_ok_short = (ema > 0.0) ? (g_close1 < ema) : true;
     }

   // Optional ADX trend-strength filter (P3 axis).
   bool adx_ok = true;
   if(use_adx_filter)
     {
      const double adx = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, adx_period, 1);
      adx_ok = (adx >= adx_min);
     }

   // Long: STC buy signal, STC rising, TT in uptrend (close above TT line),
   // STC direction agrees with TT direction. Short is the mirror.
   g_long_ok  = stc_buy  && stc_rising  && close_above_tt && tt_up && ema_ok_long  && adx_ok;
   g_short_ok = stc_sell && stc_falling && close_below_tt && tt_dn && ema_ok_short && adx_ok;

   // Discretionary exits: opposite STC signal OR price closing through the TT line.
   g_exit_long  = (stc_sell || close_below_tt);
   g_exit_short = (stc_buy  || close_above_tt);

   g_state_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news). Cheap O(1) per-tick guard. Baseline:
// optional max-spread guard only (news handled by the framework filter below).
bool Strategy_NoTradeFilter()
  {
   if(max_spread_points > 0.0)
     {
      const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > max_spread_points)
         return true;
     }
   return false;
  }

// Trade Entry. Called once per new closed bar (framework guarantees QM_IsNewBar).
// Refreshes the closed-bar cache, then opens at most one position per symbol.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   QM_ComputeState();           // refresh closed-bar cache every new bar
   if(!g_state_ready)
      return false;

   if(QM_HasOurPosition())      // no pyramiding — one position per symbol/magic
      return false;

   QM_OrderType side;
   if(g_long_ok)
      side = QM_BUY;
   else if(g_short_ok)
      side = QM_SELL;
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, sl_atr_period, sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeATR(_Symbol, side, entry, sl_atr_period, tp_atr_mult);

   req.type = side;
   req.price = 0.0;             // market order; framework resolves the fill price
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "tv_stc_tt_long" : "tv_stc_tt_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management. Baseline: brackets (SL/TP) manage the trade; no break-even
// or trailing in the P2 baseline (those are later optimisation axes).
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close. Per-tick discretionary exit reading ONLY the closed-bar cache:
// exit long on STC sell signal or close below TT; mirror for short.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready)
      return false;
   ENUM_POSITION_TYPE pt;
   if(!QM_OurPositionType(pt))
      return false;
   if(pt == POSITION_TYPE_BUY && g_exit_long)
      return true;
   if(pt == POSITION_TYPE_SELL && g_exit_short)
      return true;
   return false;
  }

// News Filter Hook (callable for the P8 News Impact phase). Defer to the central
// framework two-axis news filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10791_tv_stc_tt\"}");
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
