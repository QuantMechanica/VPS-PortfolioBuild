#property strict
#property version   "5.0"
#property description "QM5_10993 FTMO ATR FVG Expansion (ftmo-atr-fvg)"
// Strategy Card: QM5_10993_ftmo-atr-fvg, G0 APPROVED 2026-05-22.
// Source: FTMO Academy, "ATR: Technical Indicator", 2025.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — FTMO ATR FVG Expansion
// -----------------------------------------------------------------------------
// Mechanical implementation of the card:
//   - Trend filter: close above/below EMA(100).
//   - Volatility expansion: ATR(14) above its 50-bar median.
//   - Breakout: a recent closed candle pierces an ATR-offset channel built from
//     the prior 20-bar high/low (atr_high_ref / atr_low_ref).
//   - Entry: first pullback into the midpoint of a Fair Value Gap formed inside
//     the breakout impulse, provided the pullback bar closes back on the
//     breakout side of the gap (does not close back inside the prior range).
//   - SL: 1.5*ATR from entry, capped beyond the FVG boundary if that is farther.
//   - TP: 2.0R.
//   - Exits: EMA(20) close against the position once +1.5R is reached, or a
//     32-bar time stop.
// All per-bar work runs under the framework QM_IsNewBar() gate in OnTick.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10993;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_M30; // Card base TF.
input int             strategy_atr_period         = 14;    // Card: ATR(14).
input int             strategy_ema_period         = 100;   // Card: EMA(100) trend.
input int             strategy_atr_median_lookback = 50;   // Card: 50-bar ATR median.
input int             strategy_channel_lookback   = 20;    // Card: prior 20-bar high/low.
input double          strategy_atr_ref_mult       = 0.25;  // Card: 0.25*ATR channel offset.
input int             strategy_breakout_lookback  = 6;     // Impulse window scanned for breakout candle.
input double          strategy_breakout_range_atr_max = 2.5; // Card: skip breakout range > 2.5*ATR.
input int             strategy_fvg_lookback       = 8;     // FVG scan depth inside the impulse.
input double          strategy_fvg_min_atr        = 0.20;  // Card: skip FVG height < 0.20*ATR.
input double          strategy_sl_atr_mult        = 1.5;   // Card: SL = 1.5*ATR.
input double          strategy_tp_r_multiple      = 2.0;   // Card: TP = 2.0R.
input int             strategy_runner_ema_period  = 20;    // Card: EMA(20) runner exit.
input double          strategy_runner_after_r     = 1.5;   // Card: runner active after +1.5R.
input int             strategy_time_exit_bars     = 32;    // Card: time exit after 32 bars.

// -----------------------------------------------------------------------------
// Strategy helpers (closed-bar only; called from QM_IsNewBar-gated path).
// -----------------------------------------------------------------------------

// Highest high over the closed-bar shift range [from_shift, to_shift].
double HighestHighRange(const int from_shift, const int to_shift)
  {
   if(from_shift < 1 || to_shift < from_shift)
      return 0.0;
   double hi = -DBL_MAX;
   for(int s = from_shift; s <= to_shift; ++s)
     {
      const double h = iHigh(_Symbol, strategy_timeframe, s); // perf-allowed: bespoke ATR channel structure.
      if(h > 0.0)
         hi = MathMax(hi, h);
     }
   return (hi <= -DBL_MAX) ? 0.0 : hi;
  }

// Lowest low over the closed-bar shift range [from_shift, to_shift].
double LowestLowRange(const int from_shift, const int to_shift)
  {
   if(from_shift < 1 || to_shift < from_shift)
      return 0.0;
   double lo = DBL_MAX;
   for(int s = from_shift; s <= to_shift; ++s)
     {
      const double l = iLow(_Symbol, strategy_timeframe, s); // perf-allowed: bespoke ATR channel structure.
      if(l > 0.0)
         lo = MathMin(lo, l);
     }
   return (lo >= DBL_MAX) ? 0.0 : lo;
  }

// Median of ATR(period) over the last `count` closed bars. Returns 0 on failure.
double AtrMedian(const int count)
  {
   if(count < 1)
      return 0.0;
   double vals[];
   ArrayResize(vals, count);
   int n = 0;
   for(int s = 1; s <= count; ++s)
     {
      const double a = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, s);
      if(a > 0.0)
        {
         vals[n] = a;
         ++n;
        }
     }
   if(n <= 0)
      return 0.0;
   ArrayResize(vals, n);
   ArraySort(vals);
   return (n % 2 == 0) ? (0.5 * (vals[n / 2 - 1] + vals[n / 2])) : vals[n / 2];
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card relies on framework news gating + per-entry volatility/FVG filters.
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

   if(strategy_atr_period <= 1 || strategy_ema_period <= 1 || strategy_atr_median_lookback < 2)
      return false;
   if(strategy_channel_lookback < 1 || strategy_breakout_lookback < 1 || strategy_fvg_lookback < 2)
      return false;

   const double atr1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ema1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double close1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: closed-bar trend/retrace confirmation.
   const double low1 = iLow(_Symbol, strategy_timeframe, 1);     // perf-allowed: bespoke FVG retrace geometry.
   const double high1 = iHigh(_Symbol, strategy_timeframe, 1);   // perf-allowed: bespoke FVG retrace geometry.
   const double low2 = iLow(_Symbol, strategy_timeframe, 2);     // perf-allowed: first-retrace check.
   const double high2 = iHigh(_Symbol, strategy_timeframe, 2);   // perf-allowed: first-retrace check.
   if(atr1 <= 0.0 || ema1 <= 0.0 || close1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0 ||
      low2 <= 0.0 || high2 <= 0.0)
      return false;

   // Volatility expansion: current ATR above its 50-bar median.
   const double atr_med = AtrMedian(strategy_atr_median_lookback);
   if(atr_med <= 0.0 || atr1 <= atr_med)
      return false;

   // ATR-offset channel built from the bars PRIOR to the breakout impulse,
   // so a breakout candle inside the impulse can actually pierce it.
   const int chan_from = strategy_breakout_lookback + 1;
   const int chan_to   = strategy_breakout_lookback + strategy_channel_lookback;
   const double hh_chan = HighestHighRange(chan_from, chan_to);
   const double ll_chan = LowestLowRange(chan_from, chan_to);
   if(hh_chan <= 0.0 || ll_chan <= 0.0)
      return false;
   const double atr_high_ref = hh_chan + strategy_atr_ref_mult * atr1;
   const double atr_low_ref  = ll_chan - strategy_atr_ref_mult * atr1;

   // Breakout candle scan inside the impulse window. The breakout candle must
   // close beyond the channel AND have range <= 2.5*ATR.
   bool breakout_long = false;
   bool breakout_short = false;
   for(int s = 1; s <= strategy_breakout_lookback; ++s)
     {
      const double bc = iClose(_Symbol, strategy_timeframe, s); // perf-allowed: bespoke breakout scan.
      const double bh = iHigh(_Symbol, strategy_timeframe, s);  // perf-allowed: bespoke breakout scan.
      const double bl = iLow(_Symbol, strategy_timeframe, s);   // perf-allowed: bespoke breakout scan.
      if(bc <= 0.0 || bh <= 0.0 || bl <= 0.0)
         continue;
      const double brange = bh - bl;
      if(brange > strategy_breakout_range_atr_max * atr1)
         continue;
      if(bc > atr_high_ref)
         breakout_long = true;
      if(bc < atr_low_ref)
         breakout_short = true;
     }

   // Most-recent FVG inside the impulse. Bullish 3-bar gap: low[k] > high[k+2].
   double long_lower = 0.0, long_upper = 0.0;
   double short_lower = 0.0, short_upper = 0.0;
   for(int k = 2; k <= strategy_fvg_lookback; ++k)
     {
      const double newer_low  = iLow(_Symbol, strategy_timeframe, k);      // perf-allowed: bespoke FVG scan.
      const double newer_high = iHigh(_Symbol, strategy_timeframe, k);     // perf-allowed: bespoke FVG scan.
      const double older_high = iHigh(_Symbol, strategy_timeframe, k + 2); // perf-allowed: bespoke FVG scan.
      const double older_low  = iLow(_Symbol, strategy_timeframe, k + 2);  // perf-allowed: bespoke FVG scan.
      if(newer_low <= 0.0 || newer_high <= 0.0 || older_high <= 0.0 || older_low <= 0.0)
         continue;

      if(long_lower <= 0.0 && newer_low > older_high)
        {
         const double height = newer_low - older_high;
         if(height >= strategy_fvg_min_atr * atr1)
           {
            long_lower = older_high;
            long_upper = newer_low;
           }
        }
      if(short_upper <= 0.0 && newer_high < older_low)
        {
         const double height = older_low - newer_high;
         if(height >= strategy_fvg_min_atr * atr1)
           {
            short_lower = newer_high;
            short_upper = older_low;
           }
        }
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   // LONG: trend up + expansion + breakout above channel + first pullback into
   // the upper half of the bullish FVG that closes back above the midpoint
   // (does not close back inside the prior range).
   if(close1 > ema1 && breakout_long && long_lower > 0.0 && long_upper > long_lower)
     {
      const double mid = 0.5 * (long_lower + long_upper);
      const bool first_retrace = (low1 <= long_upper && low1 >= mid && close1 > mid && low2 > long_upper);
      if(first_retrace)
        {
         double sl = ask - strategy_sl_atr_mult * atr1;
         if(long_lower < sl)            // FVG low farther than ATR stop → cap below FVG.
            sl = long_lower;
         const double risk = ask - sl;
         if(sl > 0.0 && risk > point)
           {
            req.type = QM_BUY;
            req.price = 0.0;
            req.sl = sl;
            req.tp = ask + strategy_tp_r_multiple * risk;
            req.reason = "ATR_FVG_LONG";
            return true;
           }
        }
     }

   // SHORT: mirror of the long case.
   if(close1 < ema1 && breakout_short && short_upper > short_lower && short_lower > 0.0)
     {
      const double mid = 0.5 * (short_lower + short_upper);
      const bool first_retrace = (high1 >= short_lower && high1 <= mid && close1 < mid && high2 < short_lower);
      if(first_retrace)
        {
         double sl = bid + strategy_sl_atr_mult * atr1;
         if(short_upper > sl)           // FVG high farther than ATR stop → cap above FVG.
            sl = short_upper;
         const double risk = sl - bid;
         if(sl > 0.0 && risk > point)
           {
            req.type = QM_SELL;
            req.price = 0.0;
            req.sl = sl;
            req.tp = bid - strategy_tp_r_multiple * risk;
            req.reason = "ATR_FVG_SHORT";
            return true;
           }
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Card uses fixed SL/TP plus the discretionary exits in Strategy_ExitSignal;
// no trailing/break-even is specified, so this stays a no-op.
void Strategy_ManageOpenPosition()
  {
   // Intentionally empty — card defines no in-trade SL/TP adjustment.
  }

// Return TRUE to close the open position now: EMA(20) close against the
// position once +1.5R is reached, or the 32-bar time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);

      // Time exit after N bars.
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int tf_seconds = PeriodSeconds(strategy_timeframe);
      if(open_time > 0 && tf_seconds > 0 &&
         TimeCurrent() - open_time >= (long)strategy_time_exit_bars * tf_seconds)
         return true;

      // Runner exit: EMA(20) close against position once +1.5R reached.
      if(open_price > 0.0 && current_sl > 0.0)
        {
         const double init_risk = MathAbs(open_price - current_sl);
         const bool is_buy = (pos_type == POSITION_TYPE_BUY);
         const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                            : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(init_risk > 0.0 && market_price > 0.0)
           {
            const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
            if(moved >= strategy_runner_after_r * init_risk)
              {
               const double ema_run = QM_EMA(_Symbol, strategy_timeframe, strategy_runner_ema_period, 1);
               const double close1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: closed-bar runner exit.
               if(ema_run > 0.0 && close1 > 0.0)
                 {
                  if(is_buy && close1 < ema_run)
                     return true;
                  if(!is_buy && close1 > ema_run)
                     return true;
                 }
              }
           }
        }
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
