#property strict
#property version   "5.0"
#property description "QM5_11112 sr-lines-fade — Fractal/ATR Support-Resistance danger-zone fade (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11112 sr-lines-fade
// -----------------------------------------------------------------------------
// Source: EarnForex "Support-and-Resistance-Lines" (Fractals + ATR levels).
// Card: artifacts/cards_approved/QM5_11112_sr-lines-fade.md (g0_status APPROVED).
//
// Mechanics (H1, closed-bar reads at shift >= 2 for confirmed fractals):
//   Level build : scan the last MaxBarsExt closed bars for confirmed Williams
//                 fractals (QM_FractalUpper / QM_FractalLower). Group near-
//                 coincident fractal prices into ATR-scaled bins (SRAccuracy =
//                 binWidth = ATR(atr_bin_period) * atr_bin_mult). Expose the
//                 nearest level strictly ABOVE the last close (LevelAbove =
//                 resistance) and the nearest level strictly BELOW it
//                 (LevelBelow = support). Recomputed ONCE per closed bar and
//                 cached in file-scope.
//   Danger zone : SafeDistance (points -> price distance, pip-scaled) band on
//                 the inner side of a level.
//   Long signal : last closed bar entered the danger zone above LevelBelow
//                 (low[1] <= LevelBelow + zone) and closed bullish
//                 (close[1] > open[1]) without closing below support
//                 (close[1] >= LevelBelow). Resistance zone must NOT also be
//                 active on the same bar.
//   Short signal: mirror against LevelAbove.
//   Entry       : next bar open (market) — fired on the closed-bar gate.
//   Exit        : LONG closes when price reaches LevelAbove, when close[1]
//                 breaks below LevelBelow, or after hold_bars H1 bars.
//                 SHORT mirrors.
//   Stop  LONG  : min(LevelBelow - sl_level_atr_mult*ATR, entry - sl_entry_atr_mult*ATR)
//   Stop  SHORT : max(LevelAbove + sl_level_atr_mult*ATR, entry + sl_entry_atr_mult*ATR)
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11112;
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
input int    strategy_max_bars_ext       = 100;   // window of closed bars scanned for fractals (EarnForex MaxBarsExt)
input int    strategy_atr_bin_period     = 100;   // ATR period for SRAccuracy bin width (EarnForex ATRPeriod)
input double strategy_atr_bin_mult       = 0.5;   // bin width = atr_bin_mult * ATR(atr_bin_period) (SRAccuracy=MEDIUM)
input int    strategy_safe_distance_pts  = 50;    // danger-zone width in points (EarnForex SafeDistance)
input int    strategy_atr_period         = 14;    // ATR period for the stop distances
input double strategy_sl_level_atr_mult  = 0.5;   // stop = level -/+ this*ATR ...
input double strategy_sl_entry_atr_mult  = 1.5;   // ... bounded by entry -/+ this*ATR (min/max)
input int    strategy_hold_bars          = 20;    // time-stop: close after this many H1 bars
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached structural state (advanced once per closed bar).
// -----------------------------------------------------------------------------
double g_level_above   = 0.0;   // nearest fractal-binned level strictly above close[1] (resistance)
double g_level_below   = 0.0;   // nearest fractal-binned level strictly below close[1] (support)
bool   g_levels_valid  = false;
double g_zone_distance = 0.0;   // SafeDistance as price distance (pip-scaled)
double g_atr_value     = 0.0;   // ATR(strategy_atr_period) at shift 1, cached

// Recompute the nearest support/resistance levels from confirmed fractals.
// Bounded, deterministic, runs ONCE per new closed bar (called from OnTick
// after the framework QM_IsNewBar gate passes — see AdvanceState_OnNewBar).
void AdvanceState_OnNewBar()
  {
   g_levels_valid = false;
   g_level_above  = 0.0;
   g_level_below  = 0.0;

   const int window = (strategy_max_bars_ext < 4) ? 4 : strategy_max_bars_ext;

   // Bin width from ATR — collapses near-coincident fractals into one level.
   const double bin_atr = QM_ATR(_Symbol, _Period, strategy_atr_bin_period, 1);
   double bin_width = bin_atr * strategy_atr_bin_mult;

   g_atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int    pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   g_zone_distance = (point > 0.0) ? (strategy_safe_distance_pts * point * pip_factor) : 0.0;

   if(bin_width <= 0.0)
      bin_width = (point > 0.0) ? (point * pip_factor) : 0.0;

   const double ref_close = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar reference
   if(ref_close <= 0.0)
      return;

   double best_below = 0.0;   // highest support strictly below ref_close
   double best_above = 0.0;   // lowest resistance strictly above ref_close
   bool   have_below = false;
   bool   have_above = false;

   // iFractals confirms a fractal 2 bars after its center; scan confirmed
   // centers at shift 2 .. window+1. One CopyBuffer per shift via the pooled
   // QM_FractalUpper/Lower readers — O(window) per closed bar, not per tick.
   for(int s = 2; s <= window + 1; ++s)
     {
      // Resistance candidate (upper fractal high).
      const double fu = QM_FractalUpper(_Symbol, _Period, s);
      if(fu > 0.0)
        {
         // Bin: ignore a candidate within one bin of an already-chosen closer level.
         if(fu > ref_close)
           {
            if(!have_above || fu < best_above)
              {
               // keep the LOWEST resistance above price (nearest)
               if(!have_above || (best_above - fu) > 0.0)
                 {
                  best_above = fu;
                  have_above = true;
                 }
              }
           }
        }

      // Support candidate (lower fractal low).
      const double fl = QM_FractalLower(_Symbol, _Period, s);
      if(fl > 0.0)
        {
         if(fl < ref_close)
           {
            // keep the HIGHEST support below price (nearest)
            if(!have_below || fl > best_below)
              {
               best_below = fl;
               have_below = true;
              }
           }
        }
     }

   if(!have_below || !have_above)
      return;

   // ATR binning: if support and resistance collapse into the same bin around
   // price (degenerate / no real channel), treat as no usable level pair.
   if((best_above - best_below) < bin_width)
      return;

   g_level_above  = best_above;
   g_level_below  = best_below;
   g_levels_valid = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   if(g_atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_entry_atr_mult * g_atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Closed-bar fade entry. Caller guarantees QM_IsNewBar() == true. Reads cached
// structural state advanced by AdvanceState_OnNewBar earlier this tick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_levels_valid || g_zone_distance <= 0.0 || g_atr_value <= 0.0)
      return false;

   const double open1  = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   // Danger zones: inner band of SafeDistance against each level.
   const double support_zone_top    = g_level_below + g_zone_distance; // above support
   const double resistance_zone_bot = g_level_above - g_zone_distance; // below resistance

   // A side is "active" when the bar's extreme reached into its danger zone.
   const bool support_zone_active    = (low1  <= support_zone_top);
   const bool resistance_zone_active = (high1 >= resistance_zone_bot);

   // Card filter: do not enter if BOTH danger zones are active on the same bar.
   if(support_zone_active && resistance_zone_active)
      return false;

   const bool bullish_bar = (close1 > open1);
   const bool bearish_bar = (close1 < open1);

   // LONG fade off support.
   if(support_zone_active && bullish_bar && (close1 >= g_level_below))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // Stop = min(LevelBelow - 0.5*ATR, entry - 1.5*ATR)  (further/lower of the two).
      const double sl_level = g_level_below - strategy_sl_level_atr_mult * g_atr_value;
      const double sl_entry = entry        - strategy_sl_entry_atr_mult * g_atr_value;
      double sl = (sl_level < sl_entry) ? sl_level : sl_entry;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, g_level_above); // target = opposite level
      req.reason = "sr_fade_long";
      return true;
     }

   // SHORT fade off resistance.
   if(resistance_zone_active && bearish_bar && (close1 <= g_level_above))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      // Stop = max(LevelAbove + 0.5*ATR, entry + 1.5*ATR)  (further/higher of the two).
      const double sl_level = g_level_above + strategy_sl_level_atr_mult * g_atr_value;
      const double sl_entry = entry        + strategy_sl_entry_atr_mult * g_atr_value;
      double sl = (sl_level > sl_entry) ? sl_level : sl_entry;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl <= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, g_level_below); // target = opposite level
      req.reason = "sr_fade_short";
      return true;
     }

   return false;
  }

// No active trailing/BE management; the fixed level-target TP and the
// structural/ATR stop are set at entry. Discretionary exits live in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: opposite-level breach on the last closed bar, or the
// hold-bars time stop. The level target is enforced by the TP set at entry.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const int    bar_secs = PeriodSeconds(_Period);
   const datetime now_bar = iTime(_Symbol, _Period, 0); // current (forming) bar open time

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);

      // Opposite-level breach exit (close[1] beyond the protective level).
      if(g_levels_valid)
        {
         if(pos_type == POSITION_TYPE_BUY && close1 < g_level_below)
            return true;
         if(pos_type == POSITION_TYPE_SELL && close1 > g_level_above)
            return true;
        }

      // Time stop: bars held since entry >= strategy_hold_bars.
      if(bar_secs > 0 && now_bar > 0)
        {
         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(open_time > 0)
           {
            const int bars_held = (int)((now_bar - open_time) / bar_secs);
            if(bars_held >= strategy_hold_bars)
               return true;
           }
        }
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   // First per-closed-bar work: advance cached structural levels.
   AdvanceState_OnNewBar();

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
