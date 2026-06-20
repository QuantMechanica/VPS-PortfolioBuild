#property strict
#property version   "5.0"
#property description "QM5_2132 Pring KST-Histogram H4"

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
input int    qm_ea_id                   = 2132;
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
input int    strategy_roc1_period          = 10;
input int    strategy_roc2_period          = 15;
input int    strategy_roc3_period          = 20;
input int    strategy_roc4_period          = 30;
input int    strategy_smooth1_period       = 10;
input int    strategy_smooth2_period       = 10;
input int    strategy_smooth3_period       = 10;
input int    strategy_smooth4_period       = 15;
input double strategy_weight1              = 1.0;
input double strategy_weight2              = 2.0;
input double strategy_weight3              = 3.0;
input double strategy_weight4              = 4.0;
input int    strategy_signal_period        = 9;
input int    strategy_divergence_window    = 20;
input int    strategy_min_peak_separation  = 5;
input int    strategy_atr_period           = 20;
input double strategy_initial_atr_mult     = 0.5;
input double strategy_trail_atr_mult       = 3.0;
input double strategy_trail_trigger_atr    = 2.0;
input int    strategy_d1_ema_period        = 50;
input int    strategy_hist_std_period      = 50;
input double strategy_cross_std_mult       = 0.05;
input double strategy_hist_noise_mult      = 0.30;
input int    strategy_rearm_bars           = 60;
input int    strategy_cooldown_bars        = 5;
input int    strategy_max_hold_h4_bars     = 120;
input int    strategy_warmup_h4_bars       = 200;

MqlRates g_kst_rates[];

bool   g_kst_state_valid      = false;
bool   g_signal_long_a        = false;
bool   g_signal_long_b        = false;
bool   g_signal_short_a       = false;
bool   g_signal_short_b       = false;
bool   g_exit_long_signal     = false;
bool   g_exit_short_signal    = false;
bool   g_position_seen        = false;
int    g_bars_after_long_a    = 100000;
int    g_bars_after_short_a   = 100000;
int    g_pause_after_exit     = 100000;
double g_entry_bar_low        = 0.0;
double g_entry_bar_high       = 0.0;

int MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

int MaxRocPeriod()
  {
   int result = strategy_roc1_period;
   result = MaxInt(result, strategy_roc2_period);
   result = MaxInt(result, strategy_roc3_period);
   result = MaxInt(result, strategy_roc4_period);
   return result;
  }

int MaxSmoothPeriod()
  {
   int result = strategy_smooth1_period;
   result = MaxInt(result, strategy_smooth2_period);
   result = MaxInt(result, strategy_smooth3_period);
   result = MaxInt(result, strategy_smooth4_period);
   return result;
  }

bool StrategyParamsValid()
  {
   return strategy_roc1_period > 0 &&
          strategy_roc2_period > 0 &&
          strategy_roc3_period > 0 &&
          strategy_roc4_period > 0 &&
          strategy_smooth1_period > 0 &&
          strategy_smooth2_period > 0 &&
          strategy_smooth3_period > 0 &&
          strategy_smooth4_period > 0 &&
          strategy_signal_period > 0 &&
          strategy_divergence_window >= 6 &&
          strategy_min_peak_separation > 0 &&
          strategy_atr_period > 0 &&
          strategy_initial_atr_mult > 0.0 &&
          strategy_trail_atr_mult > 0.0 &&
          strategy_trail_trigger_atr > 0.0 &&
          strategy_d1_ema_period > 0 &&
          strategy_hist_std_period > 1 &&
          strategy_cross_std_mult >= 0.0 &&
          strategy_hist_noise_mult >= 0.0 &&
          strategy_rearm_bars >= 0 &&
          strategy_cooldown_bars >= 0 &&
          strategy_max_hold_h4_bars > 0 &&
          strategy_warmup_h4_bars > 0;
  }

double RocAt(const int roc_period, const int shift)
  {
   const int old_shift = shift + roc_period;
   if(shift < 0 || old_shift >= ArraySize(g_kst_rates))
      return 0.0;
   const double old_close = g_kst_rates[old_shift].close;
   const double close_now = g_kst_rates[shift].close;
   if(old_close <= 0.0 || close_now <= 0.0)
      return 0.0;
   return ((close_now - old_close) / old_close) * 100.0;
  }

double SmoothedRocAt(const int roc_period, const int smooth_period, const int shift)
  {
   if(smooth_period <= 0)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < smooth_period; ++i)
      sum += RocAt(roc_period, shift + i);
   return sum / (double)smooth_period;
  }

double KstAt(const int shift)
  {
   return strategy_weight1 * SmoothedRocAt(strategy_roc1_period, strategy_smooth1_period, shift) +
          strategy_weight2 * SmoothedRocAt(strategy_roc2_period, strategy_smooth2_period, shift) +
          strategy_weight3 * SmoothedRocAt(strategy_roc3_period, strategy_smooth3_period, shift) +
          strategy_weight4 * SmoothedRocAt(strategy_roc4_period, strategy_smooth4_period, shift);
  }

double SignalAt(const int shift)
  {
   if(strategy_signal_period <= 0)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < strategy_signal_period; ++i)
      sum += KstAt(shift + i);
   return sum / (double)strategy_signal_period;
  }

double HistAt(const int shift)
  {
   return KstAt(shift) - SignalAt(shift);
  }

double HistStdDev(const int start_shift, const int period)
  {
   if(period <= 1)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < period; ++i)
      sum += HistAt(start_shift + i);

   const double mean = sum / (double)period;
   double variance = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double diff = HistAt(start_shift + i) - mean;
      variance += diff * diff;
     }
   return MathSqrt(variance / (double)period);
  }

bool FindBullishDivergence()
  {
   int recent = -1;
   int older = -1;
   for(int shift = 2; shift <= strategy_divergence_window; ++shift)
     {
      const double h = HistAt(shift);
      if(h < HistAt(shift - 1) && h < HistAt(shift + 1))
        {
         if(recent < 0)
            recent = shift;
         else if(MathAbs(shift - recent) >= strategy_min_peak_separation)
           {
            older = shift;
            break;
           }
        }
     }

   if(recent < 0 || older < 0)
      return false;
   if(older >= ArraySize(g_kst_rates) || recent >= ArraySize(g_kst_rates))
      return false;

   return g_kst_rates[recent].low < g_kst_rates[older].low &&
          HistAt(recent) > HistAt(older);
  }

bool FindBearishDivergence()
  {
   int recent = -1;
   int older = -1;
   for(int shift = 2; shift <= strategy_divergence_window; ++shift)
     {
      const double h = HistAt(shift);
      if(h > HistAt(shift - 1) && h > HistAt(shift + 1))
        {
         if(recent < 0)
            recent = shift;
         else if(MathAbs(shift - recent) >= strategy_min_peak_separation)
           {
            older = shift;
            break;
           }
        }
     }

   if(recent < 0 || older < 0)
      return false;
   if(older >= ArraySize(g_kst_rates) || recent >= ArraySize(g_kst_rates))
      return false;

   return g_kst_rates[recent].high > g_kst_rates[older].high &&
          HistAt(recent) < HistAt(older);
  }

bool RefreshKstState()
  {
   g_kst_state_valid = false;
   g_signal_long_a = false;
   g_signal_long_b = false;
   g_signal_short_a = false;
   g_signal_short_b = false;
   g_exit_long_signal = false;
   g_exit_short_signal = false;
   g_entry_bar_low = 0.0;
   g_entry_bar_high = 0.0;

   if(g_bars_after_long_a < 100000)
      g_bars_after_long_a++;
   if(g_bars_after_short_a < 100000)
      g_bars_after_short_a++;
   if(g_pause_after_exit < 100000)
      g_pause_after_exit++;

   if(!StrategyParamsValid())
      return false;

   int required = MaxRocPeriod() + MaxSmoothPeriod() + strategy_signal_period +
                  strategy_hist_std_period + strategy_divergence_window + 10;
   required = MaxInt(required, strategy_warmup_h4_bars);

   ArraySetAsSeries(g_kst_rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 0, required + 5, g_kst_rates); // perf-allowed: KST histogram is bespoke closed-bar math; EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied < required)
      return false;

   const double h1 = HistAt(1);
   const double h2 = HistAt(2);
   const double h3 = HistAt(3);
   const double h4 = HistAt(4);
   const double hist_std = HistStdDev(1, strategy_hist_std_period);
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1);
   const double close1 = g_kst_rates[1].close;
   const double close4 = g_kst_rates[4].close;
   if(hist_std <= 0.0 || d1_ema <= 0.0 || close1 <= 0.0 || close4 <= 0.0)
      return false;

   const bool meaningful_hist = (MathAbs(h1) >= strategy_hist_noise_mult * hist_std);
   const bool bull_div = FindBullishDivergence();
   const bool bear_div = FindBearishDivergence();
   const bool long_regime = close1 > d1_ema;
   const bool short_regime = close1 < d1_ema;

   g_signal_long_a = meaningful_hist &&
                     h2 <= 0.0 && h1 > 0.0 &&
                     (h1 - h2) >= strategy_cross_std_mult * hist_std &&
                     h1 > h3 && h2 > h4 &&
                     long_regime;

   g_signal_short_a = meaningful_hist &&
                      h2 >= 0.0 && h1 < 0.0 &&
                      (h2 - h1) >= strategy_cross_std_mult * hist_std &&
                      h1 < h3 && h2 < h4 &&
                      short_regime;

   const bool long_b_allowed = (g_bars_after_long_a > strategy_rearm_bars);
   const bool short_b_allowed = (g_bars_after_short_a > strategy_rearm_bars);

   g_signal_long_b = meaningful_hist &&
                     long_b_allowed &&
                     bull_div &&
                     h1 > h2 &&
                     h1 < 0.0 &&
                     close1 > close4 &&
                     long_regime;

   g_signal_short_b = meaningful_hist &&
                      short_b_allowed &&
                      bear_div &&
                      h1 < h2 &&
                      h1 > 0.0 &&
                      close1 < close4 &&
                      short_regime;

   g_exit_long_signal = (h2 >= 0.0 && h1 < 0.0) || bear_div;
   g_exit_short_signal = (h2 <= 0.0 && h1 > 0.0) || bull_div;
   g_entry_bar_low = g_kst_rates[1].low;
   g_entry_bar_high = g_kst_rates[1].high;
   g_kst_state_valid = true;
   return true;
  }

bool FindOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, double &open_price, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

void RefreshPositionTransition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   const bool has_position = FindOurPosition(ticket, position_type, open_price, open_time);
   if(has_position)
     {
      g_position_seen = true;
      return;
     }

   if(g_position_seen)
      g_pause_after_exit = 0;
   g_position_seen = false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > (0.30 * atr))
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

   if(!RefreshKstState())
      return false;

   if(g_pause_after_exit < strategy_cooldown_bars)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || g_entry_bar_low <= 0.0 || g_entry_bar_high <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const bool take_long = g_signal_long_a || g_signal_long_b;
   const bool take_short = !take_long && (g_signal_short_a || g_signal_short_b);
   if(take_long)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_entry_bar_low - strategy_initial_atr_mult * atr);
      req.tp = 0.0;
      req.reason = g_signal_long_a ? "KST_HIST_ZERO_UP" : "KST_HIST_BULL_DIVERGENCE";
      if(req.sl <= 0.0 || (ask > 0.0 && req.sl >= ask))
         return false;
      if(g_signal_long_a)
        {
         g_bars_after_long_a = 0;
         g_bars_after_short_a = 100000;
        }
      return true;
     }

   if(take_short)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_entry_bar_high + strategy_initial_atr_mult * atr);
      req.tp = 0.0;
      req.reason = g_signal_short_a ? "KST_HIST_ZERO_DOWN" : "KST_HIST_BEAR_DIVERGENCE";
      if(req.sl <= 0.0 || (bid > 0.0 && req.sl <= bid))
         return false;
      if(g_signal_short_a)
        {
         g_bars_after_short_a = 0;
         g_bars_after_long_a = 100000;
        }
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   RefreshPositionTransition();

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || open_price <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;

   const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
   if(moved >= strategy_trail_trigger_atr * atr)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
      return false;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   if(g_kst_state_valid)
     {
      if(is_buy && g_exit_long_signal)
        {
         g_pause_after_exit = 0;
         return true;
        }
      if(!is_buy && g_exit_short_signal)
        {
         g_pause_after_exit = 0;
         return true;
        }
     }

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds > 0 && open_time > 0)
     {
      const int held_bars = (int)((TimeCurrent() - open_time) / h4_seconds);
      if(held_bars >= strategy_max_hold_h4_bars)
        {
         g_pause_after_exit = 0;
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
