#property strict
#property version   "5.0"
#property description "QM5_2024 Pring Trend Deviation Oscillator H4"

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
input int    qm_ea_id                   = 2024;
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
input int    strategy_long_ma_period          = 65;
input int    strategy_stat_period             = 200;
input double strategy_band_sd_mult            = 2.0;
input double strategy_extreme_sd_mult         = 2.5;
input double strategy_rearm_sd_mult           = 0.5;
input double strategy_min_tdo_sd_pct          = 0.5;
input int    strategy_d1_ema_period           = 50;
input int    strategy_atr_period              = 20;
input double strategy_initial_stop_atr_mult   = 2.5;
input double strategy_trail_atr_mult          = 2.5;
input double strategy_conflict_trail_atr_mult = 1.5;
input double strategy_trail_trigger_atr_mult  = 1.5;
input int    strategy_time_stop_bars          = 30;
input double strategy_spread_atr_mult         = 0.30;
input int    strategy_warmup_bars             = 280;

bool   g_tdo_cache_ready      = false;
double g_tdo_value_curr       = 0.0;
double g_tdo_mean_curr        = 0.0;
double g_tdo_sd_curr          = 0.0;
double g_tdo_value_prev       = 0.0;
double g_tdo_mean_prev        = 0.0;
double g_tdo_sd_prev          = 0.0;
double g_tdo_bar_open_curr    = 0.0;
double g_tdo_bar_high_curr    = 0.0;
double g_tdo_bar_low_curr     = 0.0;
double g_tdo_bar_close_curr   = 0.0;
bool   g_tdo_long_cycle_armed = true;
bool   g_tdo_short_cycle_armed = true;

bool Strategy_TdoAtShift(MqlRates &rates[],
                         const int copied,
                         const int shift,
                         const int long_period,
                         double &out_tdo)
  {
   out_tdo = 0.0;
   if(shift < 0 || long_period < 2 || shift + long_period > copied)
      return false;

   double sum_close = 0.0;
   for(int i = shift; i < shift + long_period; ++i)
     {
      if(rates[i].close <= 0.0)
         return false;
      sum_close += rates[i].close;
     }

   const double long_ma = sum_close / (double)long_period;
   if(long_ma <= 0.0)
      return false;

   out_tdo = 100.0 * (rates[shift].close - long_ma) / long_ma;
   return true;
  }

bool Strategy_TdoStats(MqlRates &rates[],
                       const int copied,
                       const int first_shift,
                       const int long_period,
                       const int stat_period,
                       double &out_mean,
                       double &out_sd)
  {
   out_mean = 0.0;
   out_sd = 0.0;
   if(first_shift < 0 || stat_period < 2)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   for(int i = first_shift; i < first_shift + stat_period; ++i)
     {
      double tdo = 0.0;
      if(!Strategy_TdoAtShift(rates, copied, i, long_period, tdo))
         return false;
      sum += tdo;
      sum_sq += tdo * tdo;
     }

   out_mean = sum / (double)stat_period;
   double variance = (sum_sq / (double)stat_period) - (out_mean * out_mean);
   if(variance < 0.0 && variance > -0.00000001)
      variance = 0.0;
   if(variance < 0.0)
      return false;

   out_sd = MathSqrt(variance);
   return true;
  }

bool Strategy_UpdateTdoSnapshot()
  {
   g_tdo_cache_ready = false;

   int long_period = strategy_long_ma_period;
   if(long_period < 2)
      long_period = 2;
   int stat_period = strategy_stat_period;
   if(stat_period < 2)
      stat_period = 2;
   int bars_required = stat_period + long_period + 2;
   if(strategy_warmup_bars > bars_required)
      bars_required = strategy_warmup_bars;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, bars_required, rates); // perf-allowed: bounded derived TDO window, called only from Strategy_EntrySignal after framework QM_IsNewBar gate.
   if(copied < bars_required)
      return false;
   ArraySetAsSeries(rates, true);

   double curr_tdo = 0.0;
   double prev_tdo = 0.0;
   double curr_mean = 0.0;
   double curr_sd = 0.0;
   double prev_mean = 0.0;
   double prev_sd = 0.0;

   if(!Strategy_TdoAtShift(rates, copied, 0, long_period, curr_tdo))
      return false;
   if(!Strategy_TdoAtShift(rates, copied, 1, long_period, prev_tdo))
      return false;
   if(!Strategy_TdoStats(rates, copied, 0, long_period, stat_period, curr_mean, curr_sd))
      return false;
   if(!Strategy_TdoStats(rates, copied, 1, long_period, stat_period, prev_mean, prev_sd))
      return false;

   g_tdo_value_curr = curr_tdo;
   g_tdo_mean_curr = curr_mean;
   g_tdo_sd_curr = curr_sd;
   g_tdo_value_prev = prev_tdo;
   g_tdo_mean_prev = prev_mean;
   g_tdo_sd_prev = prev_sd;
   g_tdo_bar_open_curr = rates[0].open;
   g_tdo_bar_high_curr = rates[0].high;
   g_tdo_bar_low_curr = rates[0].low;
   g_tdo_bar_close_curr = rates[0].close;
   g_tdo_cache_ready = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > atr * strategy_spread_atr_mult)
      return true;

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

   if(!Strategy_UpdateTdoSnapshot())
      return false;

   if(g_tdo_sd_curr > 0.0 &&
      MathAbs(g_tdo_value_curr - g_tdo_mean_curr) <= strategy_rearm_sd_mult * g_tdo_sd_curr)
     {
      g_tdo_long_cycle_armed = true;
      g_tdo_short_cycle_armed = true;
     }

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(g_tdo_sd_curr < strategy_min_tdo_sd_pct || g_tdo_sd_prev <= 0.0)
      return false;

   const double upper_curr = g_tdo_mean_curr + strategy_band_sd_mult * g_tdo_sd_curr;
   const double lower_curr = g_tdo_mean_curr - strategy_band_sd_mult * g_tdo_sd_curr;
   const double upper_prev = g_tdo_mean_prev + strategy_band_sd_mult * g_tdo_sd_prev;
   const double lower_prev = g_tdo_mean_prev - strategy_band_sd_mult * g_tdo_sd_prev;
   const double mid_curr = (g_tdo_bar_high_curr + g_tdo_bar_low_curr) * 0.5;
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool bearish_exhaustion =
      (g_tdo_bar_close_curr < g_tdo_bar_open_curr &&
       g_tdo_bar_close_curr < mid_curr);
   const bool bullish_exhaustion =
      (g_tdo_bar_close_curr > g_tdo_bar_open_curr &&
       g_tdo_bar_close_curr > mid_curr);

   const bool short_touch =
      (g_tdo_value_prev > upper_prev &&
       (g_tdo_value_prev - g_tdo_mean_prev) > strategy_extreme_sd_mult * g_tdo_sd_prev &&
       g_tdo_value_curr <= upper_curr);
   const bool long_touch =
      (g_tdo_value_prev < lower_prev &&
       (g_tdo_mean_prev - g_tdo_value_prev) > strategy_extreme_sd_mult * g_tdo_sd_prev &&
       g_tdo_value_curr >= lower_curr);

   if(g_tdo_short_cycle_armed && short_touch && bearish_exhaustion)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol,
                  g_tdo_bar_high_curr + atr * strategy_initial_stop_atr_mult);
      req.tp = 0.0;
      req.reason = "TDO_SHORT_EXTREME_FADE";
      if(req.sl <= bid)
         return false;
      g_tdo_short_cycle_armed = false;
      return true;
     }

   if(g_tdo_long_cycle_armed && long_touch && bullish_exhaustion)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol,
                  g_tdo_bar_low_curr - atr * strategy_initial_stop_atr_mult);
      req.tp = 0.0;
      req.reason = "TDO_LONG_EXTREME_FADE";
      if(req.sl <= 0.0 || req.sl >= ask)
         return false;
      g_tdo_long_cycle_armed = false;
      return true;
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

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market_price <= 0.0)
         continue;

      const double move_in_favor = is_buy ? (market_price - open_price)
                                          : (open_price - market_price);
      if(move_in_favor < atr * strategy_trail_trigger_atr_mult)
         continue;

      double trail_mult = strategy_trail_atr_mult;
      if(g_tdo_cache_ready && d1_ema > 0.0)
        {
         if(is_buy && g_tdo_bar_close_curr < d1_ema)
            trail_mult = strategy_conflict_trail_atr_mult;
         if(!is_buy && g_tdo_bar_close_curr > d1_ema)
            trail_mult = strategy_conflict_trail_atr_mult;
        }

      QM_TM_TrailATR(ticket, strategy_atr_period, trail_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(PERIOD_H4);
   int max_hold_bars = strategy_time_stop_bars;
   if(max_hold_bars < 1)
      max_hold_bars = 1;
   const long max_hold_seconds = (long)seconds_per_bar * (long)max_hold_bars;
   const datetime now = TimeCurrent();
   const double upper_fail = g_tdo_mean_curr + (strategy_band_sd_mult + 0.5) * g_tdo_sd_curr;
   const double lower_fail = g_tdo_mean_curr - (strategy_band_sd_mult + 0.5) * g_tdo_sd_curr;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(entry_time > 0 && max_hold_seconds > 0 &&
         (long)(now - entry_time) >= max_hold_seconds)
         return true;

      if(!g_tdo_cache_ready || g_tdo_sd_curr <= 0.0)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_SELL)
        {
         if(g_tdo_value_curr <= g_tdo_mean_curr)
            return true;
         if(g_tdo_value_curr > upper_fail)
            return true;
        }
      else if(position_type == POSITION_TYPE_BUY)
        {
         if(g_tdo_value_curr >= g_tdo_mean_curr)
            return true;
         if(g_tdo_value_curr < lower_fail)
            return true;
        }
     }

   return false;
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
