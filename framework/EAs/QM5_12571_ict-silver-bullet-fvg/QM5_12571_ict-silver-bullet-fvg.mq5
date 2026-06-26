#property strict
#property version   "5.0"
#property description "QM5_12571 ICT Silver Bullet — liquidity sweep -> MSS -> FVG (intraday, EOD-flat)"

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
//   - QM_TM_RemovePendingOrder(ticket, reason)
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly for
//     INDICATORS — use the QM_* readers above. (Raw OHLC series accessors
//     iOpen/iHigh/iLow/iClose for CLOSED bars, shift>=1, are allowed — this EA
//     needs them for day-range / sweep / fractal / FVG geometry.)
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12571;
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
input string cutoff_time                    = "10:00";   // freeze day high/low at this broker HH:MM
input string closing_time                   = "00:00";   // EOD: cancel pendings + flat (00:00 = end of day)
input bool   close_positions_at_closing_time = true;
input int    liquidity_sweep_max_candles    = 10;        // bars to return inside range after a break
input int    fractal_strength               = 2;         // fractal left/right strength for MSS level
input int    fractal_lookback               = 30;        // bars before sweep to scan for fractal
input int    mss_confirmation_time_lapse     = 0;        // bars; 0 = until end of day
input double fvg_min_size                    = 0.5;       // min FVG size as ATR(atr_fvg_period) multiple
input double fvg_max_size                     = 0.0;       // max FVG size as ATR mult; 0 = no cap
input double stop_loss_multiplier             = 1.0;       // SL beyond FVG by FVG_width * this
input double risk_to_reward_ratio             = 2.0;       // TP = entry +/- (SL_dist * this)
input int    atr_fvg_period                   = 100;       // ATR period used for FVG size filter
input int    strategy_max_spread_points       = 300;

// -----------------------------------------------------------------------------
// Strategy parse / time helpers
// -----------------------------------------------------------------------------

// Parse "HH:MM" into minutes-since-midnight. Returns -1 on malformed input.
int QM_ParseHHMM(const string raw)
  {
   const int colon = StringFind(raw, ":");
   if(colon <= 0 || colon >= StringLen(raw) - 1)
      return -1;
   const string hh = StringSubstr(raw, 0, colon);
   const string mm = StringSubstr(raw, colon + 1);
   if(StringLen(hh) == 0 || StringLen(mm) == 0)
      return -1;
   // reject non-digit chars
   for(int i = 0; i < StringLen(hh); ++i)
     {
      const ushort c = StringGetCharacter(hh, i);
      if(c < '0' || c > '9')
         return -1;
     }
   for(int j = 0; j < StringLen(mm); ++j)
     {
      const ushort c = StringGetCharacter(mm, j);
      if(c < '0' || c > '9')
         return -1;
     }
   const int h = (int)StringToInteger(hh);
   const int m = (int)StringToInteger(mm);
   if(h < 0 || h > 23 || m < 0 || m > 59)
      return -1;
   return h * 60 + m;
  }

int QM_BrokerMinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

// Broker calendar-day key (yyyy*10000 + mm*100 + dd) for day-rollover detection.
long QM_BrokerDayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (long)dt.year * 10000 + (long)dt.mon * 100 + (long)dt.day;
  }

bool QM_StrategyTimesValid()
  {
   return (QM_ParseHHMM(cutoff_time) >= 0 && QM_ParseHHMM(closing_time) >= 0);
  }

// Pending-order helpers for THIS EA's magic ------------------------------------

bool QM_IsPendingStop(const ENUM_ORDER_TYPE t)
  {
   return (t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_SELL_STOP);
  }

// Find this magic/symbol pending STOP order. Returns 0 if none.
ulong QM_FindPendingStop()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(QM_IsPendingStop((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return ticket;
     }
   return 0;
  }

void QM_CancelAllPendings(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(QM_IsPendingStop((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool QM_HasOpenPositionThisMagic()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Day-scoped state machine (Steps 1-6). All static; reset on broker-day roll.
// -----------------------------------------------------------------------------
// Lives in Strategy_EntrySignal but the FVG geometry is shared with the manage
// hook (invalidation), so the *active* FVG is held in file-scope statics too.

// Phase: 0=building range (pre-cutoff), 1=frozen, waiting sweep,
//        2=sweep registered, waiting MSS confirm,
//        3=MSS confirmed, FVG located, waiting midpoint touch -> pending placed,
//        4=setup consumed / void for the day.
int    g_day_phase        = 0;
long   g_day_key          = -1;     // broker day currently being processed
double g_day_high         = 0.0;
double g_day_low          = 0.0;
bool   g_range_frozen     = false;

bool   g_sweep_is_buy     = false;  // buy setup (low swept) vs sell setup (high swept)
int    g_sweep_bar_index  = 0;      // shift of the sweep return bar at registration time (info only)
datetime g_sweep_time     = 0;      // bar time of the sweep return bar
double g_mss_level        = 0.0;
bool   g_mss_confirmed    = false;
int    g_bars_since_sweep = 0;      // confirmation time-lapse counter

// Active FVG geometry (set once a valid FVG is found; used for entry + invalidation)
bool   g_fvg_active       = false;  // FVG located & pending logic live
bool   g_fvg_is_buy       = false;
double g_fvg_entry_edge   = 0.0;    // upper edge (buy) / lower edge (sell) -> stop price
double g_fvg_far_edge     = 0.0;    // lower edge (buy) / upper edge (sell)
double g_fvg_mid          = 0.0;
double g_fvg_width        = 0.0;
bool   g_pending_placed   = false;  // a pending stop has been issued for this FVG

void QM_ResetDayState(const long new_key)
  {
   g_day_key          = new_key;
   g_day_phase        = 0;
   g_day_high         = 0.0;
   g_day_low          = 0.0;
   g_range_frozen     = false;
   g_sweep_is_buy     = false;
   g_sweep_bar_index  = 0;
   g_sweep_time       = 0;
   g_mss_level        = 0.0;
   g_mss_confirmed    = false;
   g_bars_since_sweep = 0;
   g_fvg_active       = false;
   g_fvg_is_buy       = false;
   g_fvg_entry_edge   = 0.0;
   g_fvg_far_edge     = 0.0;
   g_fvg_mid          = 0.0;
   g_fvg_width        = 0.0;
   g_pending_placed   = false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   // Malformed time inputs -> guard: never trade, print once.
   static bool time_err_logged = false;
   if(!QM_StrategyTimesValid())
     {
      if(!time_err_logged)
        {
         Print("QM5_12571 ERROR: malformed cutoff_time/closing_time (need HH:MM). Trading disabled.");
         time_err_logged = true;
        }
      return true;
     }

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Locate the most recent fractal level before the sweep return bar.
// is_buy_setup: scan for a fractal swing LOW (MSS level price must be broken
//   upward by a close). Sell setup: fractal swing HIGH.
// Returns true and sets out_level if found.
bool QM_FindFractalLevel(const bool is_buy_setup, const int sweep_shift, double &out_level)
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int k = MathMax(1, fractal_strength);
   // candidate center must have k bars on each side; start just before the
   // sweep return bar and walk back up to fractal_lookback bars.
   for(int c = sweep_shift + 1; c <= sweep_shift + fractal_lookback; ++c)
     {
      const int center = c;            // shift of candidate fractal center
      bool is_fractal = true;
      if(is_buy_setup)
        {
         const double cl = iLow(_Symbol, tf, center);   // perf-allowed: bounded fractal scan on closed bars
         if(cl <= 0.0)
            return false;
         for(int s = 1; s <= k && is_fractal; ++s)
           {
            const double l_left  = iLow(_Symbol, tf, center + s); // perf-allowed: bounded fractal scan on closed bars
            const double l_right = iLow(_Symbol, tf, center - s); // perf-allowed: bounded fractal scan on closed bars
            if(l_left <= 0.0 || l_right <= 0.0 || l_left <= cl || l_right <= cl)
               is_fractal = false;
           }
         if(is_fractal)
           {
            out_level = cl;
            return true;
           }
        }
      else
        {
         const double ch = iHigh(_Symbol, tf, center);  // perf-allowed: bounded fractal scan on closed bars
         if(ch <= 0.0)
            return false;
         for(int s = 1; s <= k && is_fractal; ++s)
           {
            const double h_left  = iHigh(_Symbol, tf, center + s); // perf-allowed: bounded fractal scan on closed bars
            const double h_right = iHigh(_Symbol, tf, center - s); // perf-allowed: bounded fractal scan on closed bars
            if(h_left <= 0.0 || h_right <= 0.0 || h_left >= ch || h_right >= ch)
               is_fractal = false;
           }
         if(is_fractal)
           {
            out_level = ch;
            return true;
           }
        }
     }
   return false;
  }

// Scan back from the sweep return bar for the first valid FVG (3-bar gap).
// Bullish (buy setup): low[i] > high[i+2]  -> gap between [high[i+2], low[i]].
// Bearish (sell setup): high[i] < low[i+2] -> gap between [high[i], low[i+2]].
// Filters: at least partially inside [day_low, day_high]; size in [ATR*min, ATR*max].
bool QM_FindFVG(const bool is_buy_setup, const int sweep_shift)
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double atr = QM_ATR(_Symbol, tf, atr_fvg_period, 1);
   if(atr <= 0.0)
      return false;
   const double min_w = atr * fvg_min_size;
   const double max_w = (fvg_max_size > 0.0) ? atr * fvg_max_size : 0.0;

   const int scan_to = sweep_shift + fractal_lookback;
   for(int i = 1; i <= scan_to; ++i)
     {
      // 3-bar sequence: bar1 = i (newest), bar2 = i+1, bar3 = i+2 (oldest)
      const double low1  = iLow(_Symbol, tf, i);        // perf-allowed: bounded FVG scan on closed bars
      const double high1 = iHigh(_Symbol, tf, i);       // perf-allowed: bounded FVG scan on closed bars
      const double low3  = iLow(_Symbol, tf, i + 2);    // perf-allowed: bounded FVG scan on closed bars
      const double high3 = iHigh(_Symbol, tf, i + 2);   // perf-allowed: bounded FVG scan on closed bars
      if(low1 <= 0.0 || high1 <= 0.0 || low3 <= 0.0 || high3 <= 0.0)
         continue;

      double edge_near = 0.0;   // entry edge (stop level)
      double edge_far  = 0.0;
      double gap_lo = 0.0, gap_hi = 0.0;
      bool   found = false;

      if(is_buy_setup)
        {
         // bullish FVG: low1 > high3 -> gap [high3, low1]
         if(low1 > high3)
           {
            gap_lo  = high3;
            gap_hi  = low1;
            edge_near = low1;    // buy stop above the upper edge of the gap (top)
            edge_far  = high3;   // lower edge
            found = true;
           }
        }
      else
        {
         // bearish FVG: high1 < low3 -> gap [high1, low3]
         if(high1 < low3)
           {
            gap_lo  = high1;
            gap_hi  = low3;
            edge_near = high1;   // sell stop below the lower edge of the gap (bottom)
            edge_far  = low3;    // upper edge
            found = true;
           }
        }

      if(!found)
         continue;

      const double width = gap_hi - gap_lo;
      if(width <= 0.0 || width < min_w)
         continue;
      if(max_w > 0.0 && width > max_w)
         continue;

      // at least partially inside the frozen day range
      if(gap_hi < g_day_low || gap_lo > g_day_high)
         continue;

      g_fvg_active     = true;
      g_fvg_is_buy     = is_buy_setup;
      g_fvg_entry_edge = edge_near;
      g_fvg_far_edge   = edge_far;
      g_fvg_mid        = (gap_lo + gap_hi) * 0.5;
      g_fvg_width      = width;
      g_pending_placed = false;
      return true;
     }
   return false;
  }

// Per-closed-bar Silver Bullet state machine. Caller guarantees QM_IsNewBar().
// Returns TRUE (with req populated as a pending STOP) only on the bar where the
// FVG midpoint is touched and a pending stop should be placed.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Input sanity
   if(liquidity_sweep_max_candles < 1 || fractal_strength < 1 || fractal_lookback < 1 ||
      mss_confirmation_time_lapse < 0 || fvg_min_size <= 0.0 || stop_loss_multiplier <= 0.0 ||
      risk_to_reward_ratio <= 0.0 || atr_fvg_period < 1)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int min_bars = fractal_lookback + fractal_strength + atr_fvg_period + 5;
   if(Bars(_Symbol, tf) < min_bars) // perf-allowed: bounded structure scan after closed-bar gate
      return false;

   const int cutoff_min = QM_ParseHHMM(cutoff_time);
   if(cutoff_min < 0)
      return false;

   // The just-closed bar is shift 1.
   const datetime bar_time = iTime(_Symbol, tf, 1); // perf-allowed: closed-bar timestamp
   if(bar_time <= 0)
      return false;
   const long   bar_day  = QM_BrokerDayKey(bar_time);
   const int    bar_mins = QM_BrokerMinutesOfDay(bar_time);

   // Day rollover -> reset all state for the new broker day.
   if(bar_day != g_day_key)
      QM_ResetDayState(bar_day);

   // Day already consumed/void -> nothing more.
   if(g_day_phase == 4)
      return false;

   const double bar_high  = iHigh(_Symbol, tf, 1);  // perf-allowed: closed-bar OHLC
   const double bar_low   = iLow(_Symbol, tf, 1);   // perf-allowed: closed-bar OHLC
   const double bar_close = iClose(_Symbol, tf, 1); // perf-allowed: closed-bar OHLC
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return false;

   // ---- Step 1: build day range until cutoff, then freeze ----------------
   if(!g_range_frozen)
     {
      if(g_day_high <= 0.0 || bar_high > g_day_high)
         g_day_high = bar_high;
      if(g_day_low <= 0.0 || bar_low < g_day_low)
         g_day_low = bar_low;

      // Freeze once this closed bar is at/after the cutoff minute.
      if(bar_mins >= cutoff_min)
        {
         if(g_day_high > g_day_low)
           {
            g_range_frozen = true;
            g_day_phase = 1;
           }
        }
      // Before/at cutoff we only track the range; no entry work yet.
      return false;
     }

   // ---- Step 2: first liquidity sweep (break then return within N bars) ---
   if(g_day_phase == 1)
     {
      // Detect a break + return on THIS closed bar:
      //  - sell setup: bar wicked above day_high but CLOSED back inside.
      //  - buy setup : bar wicked below day_low  but CLOSED back inside.
      // "return within N bars" is satisfied here because we register only when
      // a single bar both breaks and closes back inside (worst case immediate),
      // or a prior break is followed by a close-back-inside within N bars.
      static int  break_age_high = -1;   // bars since a high break still pending return
      static int  break_age_low  = -1;
      // NOTE: these statics are reset implicitly by phase transitions/day reset
      // via the guards below (we re-init when leaving phase 1).

      // Re-init the break trackers on the first bar of phase 1 of a new day.
      if(g_bars_since_sweep == 0 && break_age_high == -2)
        {
         break_age_high = -1;
         break_age_low  = -1;
        }

      const bool broke_high = (bar_high > g_day_high);
      const bool broke_low  = (bar_low  < g_day_low);
      const bool back_inside = (bar_close <= g_day_high && bar_close >= g_day_low);

      // age existing pending breaks
      if(break_age_high >= 0)
        {
         break_age_high++;
         if(break_age_high > liquidity_sweep_max_candles)
            break_age_high = -1;
        }
      if(break_age_low >= 0)
        {
         break_age_low++;
         if(break_age_low > liquidity_sweep_max_candles)
            break_age_low = -1;
        }

      bool registered = false;
      bool reg_is_buy = false;

      // sell setup: high swept then close back inside
      if(broke_high)
        {
         if(back_inside)
           {
            registered = true; reg_is_buy = false;     // immediate break+return
           }
         else
            break_age_high = 0;                          // break open, await return
        }
      else if(break_age_high >= 0 && back_inside)
        {
         registered = true; reg_is_buy = false;
        }

      // buy setup: low swept then close back inside (only if no sell registered)
      if(!registered)
        {
         if(broke_low)
           {
            if(back_inside)
              {
               registered = true; reg_is_buy = true;
              }
            else
               break_age_low = 0;
           }
         else if(break_age_low >= 0 && back_inside)
           {
            registered = true; reg_is_buy = true;
           }
        }

      if(registered)
        {
         g_sweep_is_buy     = reg_is_buy;
         g_sweep_time       = bar_time;
         g_sweep_bar_index  = 1;
         g_bars_since_sweep = 0;
         g_mss_confirmed    = false;
         break_age_high     = -2;  // mark "left phase 1"
         break_age_low      = -2;

         // ---- Step 3: locate the MSS fractal level (scan back from sweep) --
         double level = 0.0;
         if(QM_FindFractalLevel(reg_is_buy, /*sweep_shift=*/1, level) && level > 0.0)
           {
            g_mss_level = level;
            g_day_phase = 2;
           }
         else
           {
            // No fractal level -> setup void for the day.
            g_day_phase = 4;
           }
        }
      return false;
     }

   // ---- Step 4: MSS confirmation (a bar CLOSES beyond the level) ----------
   if(g_day_phase == 2)
     {
      g_bars_since_sweep++;
      // time-lapse limit (0 = until end of day)
      if(mss_confirmation_time_lapse > 0 && g_bars_since_sweep > mss_confirmation_time_lapse)
        {
         g_day_phase = 4;
         return false;
        }

      bool confirmed = false;
      if(g_sweep_is_buy)
         confirmed = (bar_close > g_mss_level);   // close above level for a buy
      else
         confirmed = (bar_close < g_mss_level);   // close below level for a sell

      if(confirmed)
        {
         g_mss_confirmed = true;
         // ---- Step 5: locate first valid FVG --------------------------------
         if(QM_FindFVG(g_sweep_is_buy, /*sweep_shift=*/1))
            g_day_phase = 3;
         else
            g_day_phase = 4;   // no qualifying FVG -> void for the day
        }
      return false;
     }

   // ---- Step 6: midpoint touch -> place pending STOP ----------------------
   if(g_day_phase == 3 && g_fvg_active && !g_pending_placed)
     {
      // Detected on a completed bar: bar's range touches the FVG midpoint.
      const bool touched = (bar_high >= g_fvg_mid && bar_low <= g_fvg_mid);
      if(!touched)
         return false;

      // Don't place if a position is already open for this magic (single pos v1).
      if(QM_HasOpenPositionThisMagic())
        {
         g_day_phase = 4;
         return false;
        }

      const QM_OrderType side = g_fvg_is_buy ? QM_BUY_STOP : QM_SELL_STOP;
      const double entry = g_fvg_entry_edge;

      // ---- Step 7: SL beyond the FVG by its width * mult ------------------
      const double raw_sl = g_fvg_is_buy
                            ? (g_fvg_far_edge - g_fvg_width * stop_loss_multiplier)
                            : (g_fvg_far_edge + g_fvg_width * stop_loss_multiplier);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);

      // ---- Step 8: TP = entry +/- (SL distance * RRR) ---------------------
      const double tp = QM_TakeRR(_Symbol, g_fvg_is_buy ? QM_BUY : QM_SELL,
                                  entry, sl, risk_to_reward_ratio);

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || point <= 0.0)
        {
         g_day_phase = 4;
         return false;
        }
      // Geometry sanity: stop must sit on the correct side of entry.
      if(g_fvg_is_buy && sl >= entry)
        { g_day_phase = 4; return false; }
      if(!g_fvg_is_buy && sl <= entry)
        { g_day_phase = 4; return false; }
      if(MathAbs(entry - sl) / point < 2.0)
        { g_day_phase = 4; return false; }

      req.type   = side;
      req.price  = entry;          // pending STOP level (TRADE_ACTION_PENDING in QM_Entry)
      req.sl     = sl;
      req.tp     = tp;
      req.reason = g_fvg_is_buy ? "SB_FVG_BUY" : "SB_FVG_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;

      g_pending_placed = true;
      // Single setup per day consumed once the pending is issued.
      g_day_phase = 4;
      return true;
     }

   return false;
  }

// Per-tick management: FVG invalidation of a live pending + EOD pending cancel.
void Strategy_ManageOpenPosition()
  {
   if(_Period != PERIOD_M15 || !QM_StrategyTimesValid())
      return;

   const datetime now = TimeCurrent();

   // EOD: at/after closing_time, cancel any leftover pending order.
   const int closing_min = QM_ParseHHMM(closing_time);
   if(closing_min >= 0)
     {
      const int now_min = QM_BrokerMinutesOfDay(now);
      // closing_time 00:00 == end of day; treat the final bar window as "EOD"
      // by triggering when broker minute-of-day >= closing_min AND closing_min>0,
      // OR when closing_min==0 (midnight) we cancel at the day's last evaluated
      // bars (handled at day rollover in Strategy_EntrySignal + here when now is
      // very late). For a non-zero closing time the >= test applies directly.
      const bool eod = (closing_min == 0) ? (now_min >= 23 * 60 + 45)
                                          : (now_min >= closing_min);
      if(eod)
         QM_CancelAllPendings("sb_eod_cancel_pending");
     }

   // FVG invalidation: if a live pending exists and a CLOSED bar closed beyond
   // the opposite FVG edge, the FVG is destroyed -> cancel the pending.
   if(g_fvg_active && g_pending_placed)
     {
      const ulong pend = QM_FindPendingStop();
      if(pend != 0)
        {
         const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
         const double cclose = iClose(_Symbol, tf, 1); // perf-allowed: closed-bar close for invalidation
         if(cclose > 0.0)
           {
            // buy FVG: opposite (far) edge is the lower edge -> close below it kills it.
            // sell FVG: opposite (far) edge is the upper edge -> close above it kills it.
            const bool invalid = g_fvg_is_buy ? (cclose < g_fvg_far_edge)
                                              : (cclose > g_fvg_far_edge);
            if(invalid)
              {
               QM_TM_RemovePendingOrder(pend, "sb_fvg_invalidated");
               g_fvg_active = false;
              }
           }
        }
     }
  }

// Per-tick exit: EOD flat + prior-day stale-pending cleanup.
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_M15 || !QM_StrategyTimesValid())
      return false;

   const datetime now = TimeCurrent();

   // Day-start cleanup: if the live broker day differs from the state day,
   // cancel any stale prior-day pending orders left around.
   const long now_day = QM_BrokerDayKey(now);
   if(g_day_key >= 0 && now_day != g_day_key)
      QM_CancelAllPendings("sb_prior_day_pending_cleanup");

   if(!close_positions_at_closing_time)
      return false;

   const int closing_min = QM_ParseHHMM(closing_time);
   if(closing_min < 0)
      return false;

   const int now_min = QM_BrokerMinutesOfDay(now);
   const bool eod = (closing_min == 0) ? (now_min >= 23 * 60 + 45)
                                       : (now_min >= closing_min);
   return eod;   // OnTick closes any open position for this magic when true.
  }

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

   // Per-tick: trade management (FVG invalidation + EOD pending cancel).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (EOD flat).
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

   // Per-closed-bar: entry-signal evaluation.
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
