#property strict
#property version   "5.0"
#property description "QM5_10652 TradingView Liquidity Sweep Filter — EMA trend bands + swing-sweep reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10652_tv-ls-filter
// -----------------------------------------------------------------------------
// Mechanik (TradingView "Liquidity Sweep Filter Strategy [AlgoAlpha X
// PineIndicators]"), M15 baseline on DWX indices / metals / FX:
//
//   - Central trend line = EMA(close, ema_length).
//   - Deviation bands = EMA +/- (mean absolute deviation of close from EMA over
//     ema_length bars) * band_mult.
//   - Trend state: UP when close[1] > upper band, DOWN when close[1] < lower band.
//   - A trend SHIFT (state transition vs the prior bar) is the confirmation leg.
//   - Liquidity levels = most recent confirmed swing high / swing low
//     (fractal-style pivots, swing_lookback bars each side).
//   - Bullish sweep: a recent bar's low pierced below the swing low and the last
//     closed bar closed back above that swing low.
//   - Bearish sweep: a recent bar's high pierced above the swing high and the
//     last closed bar closed back below that swing high.
//   - LONG  = bullish trend shift confirmed AND bullish sweep AND longs allowed.
//   - SHORT = bearish trend shift confirmed AND bearish sweep AND shorts allowed.
//   - Exit: opposite trend shift, OR time stop after time_stop_bars M15 bars.
//   - Stop: swept liquidity level -/+ atr_sl_buffer_mult * ATR(14); emergency
//     cap = atr_emergency_mult * ATR(14) from entry (tighter of the two).
//
// All swing/band detection is structural with no QM reader equivalent, so it is
// recomputed ONCE per closed bar in AdvanceState_OnNewBar() and cached in
// file-scope state. OnTick stays O(1) on the per-tick path. Raw bar reads are
// // perf-allowed and gated by the framework new-bar consume.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10652;
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
// Trend-band engine
input int    ema_length                 = 50;     // central EMA trend line length
input double band_mult                  = 1.5;    // deviation-band multiplier on mean abs deviation
// Liquidity-sweep structure
input int    swing_lookback             = 10;     // bars each side for a confirmed swing pivot
input int    sweep_window               = 6;      // bars back to search for a piercing sweep wick
// Stops
input int    atr_period                 = 14;     // ATR period for SL buffer + emergency cap
input double atr_sl_buffer_mult         = 0.5;    // buffer added beyond swept level (x ATR)
input double atr_emergency_mult         = 3.0;    // emergency cap distance from entry (x ATR)
// Exit
input int    time_stop_bars             = 96;     // close after N M15 bars without opposite shift
// Trade mode
input bool   allow_longs                = true;
input bool   allow_shorts               = true;

// -----------------------------------------------------------------------------
// File-scope cached state — advanced ONCE per closed bar.
// -----------------------------------------------------------------------------
int      g_trend_state       = 0;     // +1 up, -1 down, 0 neutral (current, from bar[1])
int      g_trend_state_prev  = 0;     // trend state as of bar[2] (to detect a shift)
double   g_swing_high        = 0.0;   // most recent confirmed swing high (liquidity)
double   g_swing_low         = 0.0;   // most recent confirmed swing low (liquidity)
bool     g_bull_sweep        = false; // bullish liquidity sweep confirmed on bar[1]
bool     g_bear_sweep        = false; // bearish liquidity sweep confirmed on bar[1]
double   g_atr_cached        = 0.0;   // ATR(atr_period) at shift 1
datetime g_entry_bar_time    = 0;     // bar-open time of the bar an entry was taken on
int      g_bars_held         = 0;     // closed bars elapsed since entry

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Mean absolute deviation of close from the EMA centre over `length` closed bars.
// perf-allowed: bespoke band math, recomputed only on a new closed bar.
double ComputeMeanAbsDeviation(const double centre, const int length)
  {
   if(length <= 0)
      return 0.0;
   double sum = 0.0;
   int    n   = 0;
   for(int shift = 1; shift <= length; ++shift)
     {
      double c = iClose(_Symbol, PERIOD_CURRENT, shift); // perf-allowed
      if(c <= 0.0)
         continue;
      sum += MathAbs(c - centre);
      ++n;
     }
   if(n <= 0)
      return 0.0;
   return sum / n;
  }

// Find the most recent confirmed swing high / swing low. A confirmed swing pivot
// at index p requires `lb` bars on each side to be strictly lower (for a high) or
// higher (for a low). We scan from the freshest confirmable pivot outward.
// perf-allowed: structural pivot scan, recomputed only on a new closed bar.
void FindRecentSwings(const int lb, double &out_high, double &out_low)
  {
   out_high = 0.0;
   out_low  = 0.0;
   bool have_high = false;
   bool have_low  = false;
   // First fully-confirmed pivot sits at shift = lb+1 (needs lb bars to its right).
   const int first_p = lb + 1;
   const int last_p  = lb + 1 + 200; // bounded scan depth
   for(int p = first_p; p <= last_p; ++p)
     {
      double ph = iHigh(_Symbol, PERIOD_CURRENT, p); // perf-allowed
      double pl = iLow(_Symbol, PERIOD_CURRENT, p);  // perf-allowed
      if(ph <= 0.0 || pl <= 0.0)
         break;

      if(!have_high)
        {
         bool is_high = true;
         for(int k = 1; k <= lb; ++k)
           {
            double rh = iHigh(_Symbol, PERIOD_CURRENT, p - k); // perf-allowed
            double lh = iHigh(_Symbol, PERIOD_CURRENT, p + k); // perf-allowed
            if(rh <= 0.0 || lh <= 0.0 || rh >= ph || lh >= ph)
              {
               is_high = false;
               break;
              }
           }
         if(is_high)
           {
            out_high  = ph;
            have_high = true;
           }
        }

      if(!have_low)
        {
         bool is_low = true;
         for(int k = 1; k <= lb; ++k)
           {
            double rl = iLow(_Symbol, PERIOD_CURRENT, p - k); // perf-allowed
            double ll = iLow(_Symbol, PERIOD_CURRENT, p + k); // perf-allowed
            if(rl <= 0.0 || ll <= 0.0 || rl <= pl || ll <= pl)
              {
               is_low = false;
               break;
              }
           }
         if(is_low)
           {
            out_low  = pl;
            have_low = true;
           }
        }

      if(have_high && have_low)
         break;
     }
  }

// Advance all cached strategy state by exactly one closed bar. Called once after
// the framework consumes the new-bar event (single QM_IsNewBar() consume in OnTick).
void AdvanceState_OnNewBar()
  {
   // --- Trend bands (current = bar[1], prior = bar[2]) ---
   const double ema1 = QM_EMA(_Symbol, PERIOD_CURRENT, ema_length, 1, PRICE_CLOSE);
   const double ema2 = QM_EMA(_Symbol, PERIOD_CURRENT, ema_length, 2, PRICE_CLOSE);
   const double mad  = ComputeMeanAbsDeviation(ema1, ema_length);
   const double dev  = mad * band_mult;

   const double upper1 = ema1 + dev;
   const double lower1 = ema1 - dev;
   const double upper2 = ema2 + dev;
   const double lower2 = ema2 - dev;

   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double close2 = iClose(_Symbol, PERIOD_CURRENT, 2); // perf-allowed

   g_trend_state_prev = 0;
   if(close2 > 0.0 && upper2 > 0.0 && lower2 > 0.0)
     {
      if(close2 > upper2)
         g_trend_state_prev = 1;
      else if(close2 < lower2)
         g_trend_state_prev = -1;
     }

   g_trend_state = 0;
   if(close1 > 0.0 && upper1 > 0.0 && lower1 > 0.0)
     {
      if(close1 > upper1)
         g_trend_state = 1;
      else if(close1 < lower1)
         g_trend_state = -1;
     }

   // --- Liquidity levels ---
   FindRecentSwings(swing_lookback, g_swing_high, g_swing_low);

   // --- Liquidity sweeps (confirmed on bar[1]) ---
   // Bullish: within the last `sweep_window` bars some low pierced below the
   // swing low, and bar[1] closed back above the swing low.
   g_bull_sweep = false;
   g_bear_sweep = false;

   if(g_swing_low > 0.0 && close1 > g_swing_low)
     {
      for(int s = 1; s <= sweep_window; ++s)
        {
         double lo = iLow(_Symbol, PERIOD_CURRENT, s); // perf-allowed
         if(lo > 0.0 && lo < g_swing_low)
           {
            g_bull_sweep = true;
            break;
           }
        }
     }

   if(g_swing_high > 0.0 && close1 > 0.0 && close1 < g_swing_high)
     {
      for(int s = 1; s <= sweep_window; ++s)
        {
         double hi = iHigh(_Symbol, PERIOD_CURRENT, s); // perf-allowed
         if(hi > 0.0 && hi > g_swing_high)
           {
            g_bear_sweep = true;
            break;
           }
        }
     }

   // --- ATR for stops ---
   g_atr_cached = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);

   // --- Position hold counter ---
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
     {
      if(g_entry_bar_time > 0)
         g_bars_held++;
     }
   else
     {
      g_entry_bar_time = 0;
      g_bars_held      = 0;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_atr_cached <= 0.0)
      return false;

   const bool bull_shift = (g_trend_state == 1 && g_trend_state_prev != 1);
   const bool bear_shift = (g_trend_state == -1 && g_trend_state_prev != -1);

   const double atr_buf  = g_atr_cached * atr_sl_buffer_mult;
   const double atr_emer = g_atr_cached * atr_emergency_mult;

   if(allow_longs && bull_shift && g_bull_sweep && g_swing_low > 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Baseline stop at swept level minus buffer; emergency cap from entry.
      double sl_struct = g_swing_low - atr_buf;
      double sl_emer   = entry - atr_emer;
      double sl        = MathMax(sl_struct, sl_emer); // tighter (closer to entry) of the two
      if(sl >= entry)                                  // safety: keep stop below entry
         sl = entry - atr_emer;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = 0.0;
      req.reason = "ls_bull_sweep_trend_shift";
      g_entry_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      g_bars_held      = 0;
      return true;
     }

   if(allow_shorts && bear_shift && g_bear_sweep && g_swing_high > 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl_struct = g_swing_high + atr_buf;
      double sl_emer   = entry + atr_emer;
      double sl        = MathMin(sl_struct, sl_emer); // tighter (closer to entry) of the two
      if(sl <= entry)
         sl = entry + atr_emer;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = 0.0;
      req.reason = "ls_bear_sweep_trend_shift";
      g_entry_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      g_bars_held      = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No active trailing in baseline — exits are SL + opposite shift + time stop.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine current open side.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         have_long = true;
      else
         have_short = true;
     }

   // Opposite trend shift exit.
   const bool bull_shift = (g_trend_state == 1 && g_trend_state_prev != 1);
   const bool bear_shift = (g_trend_state == -1 && g_trend_state_prev != -1);
   if(have_long && bear_shift)
      return true;
   if(have_short && bull_shift)
      return true;

   // Time stop after N M15 bars.
   if(time_stop_bars > 0 && g_bars_held >= time_stop_bars)
      return true;

   return false;
  }

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

   g_trend_state      = 0;
   g_trend_state_prev = 0;
   g_swing_high       = 0.0;
   g_swing_low        = 0.0;
   g_bull_sweep       = false;
   g_bear_sweep       = false;
   g_atr_cached       = 0.0;
   g_entry_bar_time   = 0;
   g_bars_held        = 0;

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

   // Single new-bar consume: advance cached structural state once per closed bar.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

   // Per-tick path below is O(1): reads cached state only.
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
      g_entry_bar_time = 0;
      g_bars_held      = 0;
     }

   // Entry evaluated once per closed bar.
   if(!is_new_bar)
      return;

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
