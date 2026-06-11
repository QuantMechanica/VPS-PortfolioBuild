#property strict
#property version   "5.0"
#property description "QM5_9582 — ForexFactory Simple Daily Trend Reversal H4 (SDTR)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9582 — ff-sdtr-h4
// Source: mrdfx, ForexFactory thread #713593, first post 2017-11-09
// H4 Fibonacci pivot-zone reversal confirmed by ZigZag swing + Stochastic + EMA
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9582;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period          = 10;    // EMA period for H4 trend filter
input int    strategy_atr_period          = 14;    // ATR period for zone/stop/TP sizing
input int    strategy_stoch_k             = 5;     // Stochastic %K period
input int    strategy_stoch_d             = 3;     // Stochastic %D period
input int    strategy_stoch_slow          = 3;     // Stochastic slow period
input double strategy_stoch_oversold      = 30.0;  // Oversold level (bullish reversal trigger)
input double strategy_stoch_overbought    = 70.0;  // Overbought level (bearish reversal trigger)
input int    strategy_zz_confirm_bars     = 3;     // ZigZag confirmation bars
input int    strategy_zz_lookback_bars    = 8;     // ZigZag lookback window (H4 bars)
input double strategy_zone_pips           = 25.0;  // Pip floor for pivot-zone entry threshold
input double strategy_zone_atr_mult       = 0.25;  // ATR multiplier for zone entry threshold
input double strategy_filter_atr_mult     = 0.8;   // Max pivot-zone distance filter (ATR units)
input double strategy_sl_atr_mult         = 2.0;   // Fallback SL distance (ATR units)
input double strategy_sl_buffer_atr_mult  = 0.3;   // Buffer added beyond swing low/high (ATR units)
input double strategy_tp_pips             = 75.0;  // TP pip floor
input double strategy_tp_atr_mult         = 1.8;   // TP ATR multiplier
input int    strategy_time_stop_bars      = 12;    // Max H4 bars in trade before time stop

// ---- File-scope cached state (updated once per H4 bar) ----------------------
double g_s61 = 0, g_s78 = 0, g_s100 = 0;   // Daily Fibonacci support zones
double g_r61 = 0, g_r78 = 0, g_r100 = 0;   // Daily Fibonacci resistance zones
bool   g_bull_zz  = false, g_bear_zz  = false;  // Confirmed ZigZag swings present
double g_zz_swing_low  = 0, g_zz_swing_high = 0; // Confirmed swing prices for SL
double g_stoch_k_prev  = 50.0, g_stoch_k_curr = 50.0; // Stochastic K for direction
bool   g_opp_signal = false;                 // Opposite-signal exit flag

// ---------------------------------------------------------------------------
// AdvanceStateOnNewBar — called from Strategy_EntrySignal on each new H4 bar.
// Updates all cached state in one pass so OnTick per-tick path reads only
// pre-computed values.
// ---------------------------------------------------------------------------
void AdvanceStateOnNewBar()
  {
   // --- Daily Fibonacci pivot zones (prior D1 bar) ---
   double dh = iHigh (_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke Fib pivot — no QM_ helper covers D1 OHLC
   double dl = iLow  (_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke Fib pivot — no QM_ helper covers D1 OHLC
   double dc = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke Fib pivot — no QM_ helper covers D1 OHLC
   double rng = dh - dl;
   if(rng > 0)
     {
      double pp = (dh + dl + dc) / 3.0;
      g_r61  = pp + rng * 0.618;
      g_r78  = pp + rng * 0.786;
      g_r100 = pp + rng * 1.000;
      g_s61  = pp - rng * 0.618;
      g_s78  = pp - rng * 0.786;
      g_s100 = pp - rng * 1.000;
     }

   // --- ZigZag swing detection (3-bar confirmed local extremes within 8 bars) ---
   // perf-allowed: bespoke structural ZigZag — QM_ helpers don't expose raw OHLC scan
   int confirm  = strategy_zz_confirm_bars;   // = 3 per card
   int lookback = strategy_zz_lookback_bars;  // = 8 per card
   g_bull_zz       = false;
   g_bear_zz       = false;
   g_zz_swing_low  = 0;
   g_zz_swing_high = 0;

   // Scan closed bars: shift p is the candidate swing; shifts p-1..p-confirm must
   // all move away from the extreme (confirming it is a turning point).
   // Maximum shift accessed: lookback + confirm + 1 = 12 bars (well within history).
   for(int p = confirm + 1; p <= lookback + confirm && !g_bull_zz; p++)
     {
      double lo_p  = iLow(_Symbol, PERIOD_H4, p);     // perf-allowed: ZigZag structural scan
      double lo_pm = iLow(_Symbol, PERIOD_H4, p + 1); // perf-allowed: ZigZag structural scan
      double lo_pp = iLow(_Symbol, PERIOD_H4, p - 1); // perf-allowed: ZigZag structural scan
      if(lo_p < lo_pm && lo_p < lo_pp)
        {
         bool ok = true;
         for(int c = 1; c <= confirm && ok; c++)
            if(iLow(_Symbol, PERIOD_H4, p - c) <= lo_p) ok = false; // perf-allowed: ZigZag confirm
         if(ok) { g_bull_zz = true; g_zz_swing_low = lo_p; }
        }
     }

   for(int p = confirm + 1; p <= lookback + confirm && !g_bear_zz; p++)
     {
      double hi_p  = iHigh(_Symbol, PERIOD_H4, p);     // perf-allowed: ZigZag structural scan
      double hi_pm = iHigh(_Symbol, PERIOD_H4, p + 1); // perf-allowed: ZigZag structural scan
      double hi_pp = iHigh(_Symbol, PERIOD_H4, p - 1); // perf-allowed: ZigZag structural scan
      if(hi_p > hi_pm && hi_p > hi_pp)
        {
         bool ok = true;
         for(int c = 1; c <= confirm && ok; c++)
            if(iHigh(_Symbol, PERIOD_H4, p - c) >= hi_p) ok = false; // perf-allowed: ZigZag confirm
         if(ok) { g_bear_zz = true; g_zz_swing_high = hi_p; }
        }
     }

   // --- Stochastic K: prev and current closed-bar values ---
   g_stoch_k_prev = QM_Stoch_K(_Symbol, PERIOD_H4,
                                strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   g_stoch_k_curr = QM_Stoch_K(_Symbol, PERIOD_H4,
                                strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

   // --- Opposite-signal exit flag for existing positions ---
   g_opp_signal = false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY  && g_bear_zz) g_opp_signal = true;
      if(pos_type == POSITION_TYPE_SELL && g_bull_zz) g_opp_signal = true;
     }
  }

// ---------------------------------------------------------------------------
// Trade Filter — no extra filters beyond news/Friday handled by framework.
// ---------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Entry Signal — evaluates pivot-zone reversal setup on each new H4 bar.
// ---------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceStateOnNewBar();

   // One active position max per magic-symbol
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic) return false;
     }

   double atr14 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   double ema10 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 1);
   if(atr14 <= 0 || ema10 <= 0) return false;
   double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: closed bar needed for pivot-zone proximity check
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   // Pip size: 5-digit/3-digit = 10× point; otherwise 1× point (metals, indices)
   double pip    = point * ((digits == 5 || digits == 3) ? 10.0 : 1.0);
   double zone_thresh = MathMax(strategy_zone_pips * pip, strategy_zone_atr_mult * atr14);

   // ---- LONG SETUP -------------------------------------------------------
   if(g_bull_zz && g_s61 > 0)
     {
      double dist_s = MathMin(MathMin(MathAbs(close1 - g_s61),
                                      MathAbs(close1 - g_s78)),
                              MathAbs(close1 - g_s100));
      bool near_support = (dist_s <= zone_thresh);
      bool flt_ok       = (dist_s <= strategy_filter_atr_mult * atr14);
      // Stochastic: was in oversold, now turning up (JSRX/MBFX-style proxy)
      bool stoch_bull   = (g_stoch_k_prev < strategy_stoch_oversold &&
                           g_stoch_k_curr > g_stoch_k_prev);
      // EMA filter: closed bar above EMA(10)
      bool ema_bull     = (close1 > ema10);

      if(near_support && flt_ok && stoch_bull && ema_bull)
        {
         double sl_dist;
         // SL below confirmed swing low + buffer; ATR fallback if swing unavailable
         if(g_zz_swing_low > 0 && close1 > g_zz_swing_low &&
            (close1 - g_zz_swing_low) < strategy_sl_atr_mult * atr14)
            sl_dist = (close1 - g_zz_swing_low) + strategy_sl_buffer_atr_mult * atr14;
         else
            sl_dist = strategy_sl_atr_mult * atr14;

         double sl_price = close1 - sl_dist;
         if(sl_dist <= 0) return false;

         double tp_dist  = MathMax(strategy_tp_pips * pip, strategy_tp_atr_mult * atr14);
         double tp_price = close1 + tp_dist;

         req.type             = QM_BUY;
         req.price            = 0;   // market order; framework resolves from type
         req.sl               = sl_price;
         req.tp               = tp_price;
         req.reason           = "SDTR_BULL";
         req.symbol_slot      = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         return true;
        }
     }

   // ---- SHORT SETUP ------------------------------------------------------
   if(g_bear_zz && g_r61 > 0)
     {
      double dist_r = MathMin(MathMin(MathAbs(close1 - g_r61),
                                      MathAbs(close1 - g_r78)),
                              MathAbs(close1 - g_r100));
      bool near_resist = (dist_r <= zone_thresh);
      bool flt_ok      = (dist_r <= strategy_filter_atr_mult * atr14);
      bool stoch_bear  = (g_stoch_k_prev > strategy_stoch_overbought &&
                          g_stoch_k_curr < g_stoch_k_prev);
      bool ema_bear    = (close1 < ema10);

      if(near_resist && flt_ok && stoch_bear && ema_bear)
        {
         double sl_dist;
         if(g_zz_swing_high > 0 && close1 < g_zz_swing_high &&
            (g_zz_swing_high - close1) < strategy_sl_atr_mult * atr14)
            sl_dist = (g_zz_swing_high - close1) + strategy_sl_buffer_atr_mult * atr14;
         else
            sl_dist = strategy_sl_atr_mult * atr14;

         double sl_price = close1 + sl_dist;
         if(sl_dist <= 0) return false;

         double tp_dist  = MathMax(strategy_tp_pips * pip, strategy_tp_atr_mult * atr14);
         double tp_price = close1 - tp_dist;

         req.type             = QM_SELL;
         req.price            = 0;   // market order; framework resolves from type
         req.sl               = sl_price;
         req.tp               = tp_price;
         req.reason           = "SDTR_BEAR";
         req.symbol_slot      = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         return true;
        }
     }

   return false;
  }

// ---------------------------------------------------------------------------
// Manage Open Position — SL/TP fixed at open; no trailing for this strategy.
// ---------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// ---------------------------------------------------------------------------
// Exit Signal — time stop (12 H4 bars) or confirmed opposite ZigZag signal.
// ---------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Time stop: 12 H4 bars (48 hours) elapsed since position open
      datetime open_time   = (datetime)PositionGetInteger(POSITION_TIME);
      long     elapsed_sec = (long)TimeCurrent() - (long)open_time;
      if(elapsed_sec >= (long)strategy_time_stop_bars * 4 * 3600)
         return true;

      // Opposite-signal exit set by AdvanceStateOnNewBar on the most recent new bar
      if(g_opp_signal) return true;
     }
   return false;
  }

// ---------------------------------------------------------------------------
// News Filter Hook — defer to framework 2-axis filter.
// ---------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line
// =============================================================================

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
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
