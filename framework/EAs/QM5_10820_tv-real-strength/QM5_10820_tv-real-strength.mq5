#property strict
#property version   "5.0"
#property description "QM5_10820 TradingView Real Strength Scalper"

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
input int    qm_ea_id                   = 10820;
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
enum Strategy_StopMode
  {
   STRATEGY_STOP_FIXED_PERCENT = 0,
   STRATEGY_STOP_ATR           = 1
  };

input double            strategy_strength_threshold    = 1.0;
input int               strategy_hist_ema_period       = 5;
input int               strategy_roc_period            = 1;
input int               strategy_adx_period            = 14;
input double            strategy_adx_min               = 14.0;
input int               strategy_volume_ma_period      = 20;
input double            strategy_volume_ratio_min      = 1.2;
input bool              strategy_sma_filter_enabled    = true;
input int               strategy_sma_fast_period       = 30;
input int               strategy_sma_slow_period       = 60;
input int               strategy_min_hold_bars         = 3;
input double            strategy_flip_threshold        = 0.8;
input double            strategy_best_hist_pullback    = 0.25;
input Strategy_StopMode strategy_stop_mode             = STRATEGY_STOP_FIXED_PERCENT;
input double            strategy_fixed_stop_pct        = 1.0;
input int               strategy_atr_period            = 14;
input double            strategy_atr_stop_mult         = 1.2;

double g_hist_current = 0.0;
double g_hist_previous = 0.0;
double g_last_adx = 0.0;
double g_last_plus_di = 0.0;
double g_last_minus_di = 0.0;
double g_last_volume_ratio = 0.0;
double g_last_sma_fast = 0.0;
double g_last_sma_slow = 0.0;
bool   g_hist_initialized = false;
bool   g_state_ready = false;

bool   g_position_was_open = false;
bool   g_strategy_exit_requested = false;
ulong  g_active_ticket = 0;
ENUM_POSITION_TYPE g_last_position_type = POSITION_TYPE_BUY;
double g_last_position_sl = 0.0;
double g_best_favorable_hist = 0.0;
bool   g_block_long_after_stop = false;
bool   g_block_short_after_stop = false;

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &ptype,
                                datetime &open_time,
                                double &sl)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;
   sl = 0.0;

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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      sl = PositionGetDouble(POSITION_SL);
      return true;
     }

   return false;
  }

bool Strategy_SmaConfirms(const ENUM_POSITION_TYPE ptype)
  {
   if(!strategy_sma_filter_enabled)
      return true;
   if(g_last_sma_fast <= 0.0 || g_last_sma_slow <= 0.0)
      return false;
   if(ptype == POSITION_TYPE_BUY)
      return (g_last_sma_fast > g_last_sma_slow);
   return (g_last_sma_fast < g_last_sma_slow);
  }

bool Strategy_SmaReversedAgainst(const ENUM_POSITION_TYPE ptype)
  {
   if(!strategy_sma_filter_enabled)
      return false;
   if(g_last_sma_fast <= 0.0 || g_last_sma_slow <= 0.0)
      return false;
   if(ptype == POSITION_TYPE_BUY)
      return (g_last_sma_fast < g_last_sma_slow);
   return (g_last_sma_fast > g_last_sma_slow);
  }

double Strategy_VolumeRatio(const int shift)
  {
   if(strategy_volume_ma_period < 1 || shift < 1)
      return 0.0;
   const long last_volume = iVolume(_Symbol, _Period, shift); // perf-allowed: broker tick-volume proxy, bounded closed-bar read.
   if(last_volume <= 0)
      return 0.0;

   double volume_sum = 0.0;
   int samples = 0;
   for(int i = shift + 1; i <= shift + strategy_volume_ma_period; ++i)
     {
      const long v = iVolume(_Symbol, _Period, i); // perf-allowed: bounded volume moving average after framework new-bar gate.
      if(v <= 0)
         continue;
      volume_sum += (double)v;
      samples++;
     }

   if(samples <= 0 || volume_sum <= 0.0)
      return 0.0;
   return (double)last_volume / (volume_sum / (double)samples);
  }

double Strategy_RocSign(const int shift)
  {
   if(strategy_roc_period < 1 || shift < 1)
      return 0.0;
   const double close_now = iClose(_Symbol, _Period, shift); // perf-allowed: ROC sign needs fixed closed-bar closes.
   const double close_then = iClose(_Symbol, _Period, shift + strategy_roc_period); // perf-allowed: ROC sign needs fixed closed-bar closes.
   if(close_now <= 0.0 || close_then <= 0.0)
      return 0.0;
   if(close_now > close_then)
      return 1.0;
   if(close_now < close_then)
      return -1.0;
   return 0.0;
  }

double Strategy_RawStrength(const int shift)
  {
   const double roc_sign = Strategy_RocSign(shift);
   const double volume_ratio = Strategy_VolumeRatio(shift);
   const double adx = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, shift);
   if(roc_sign == 0.0 || volume_ratio <= 0.0 || adx <= 0.0 || strategy_adx_min <= 0.0)
      return 0.0;
   return roc_sign * volume_ratio * (adx / strategy_adx_min);
  }

void Strategy_UpdatePositionLifecycle()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   double sl;
   const bool has_position = Strategy_SelectOurPosition(ticket, ptype, open_time, sl);

   if(has_position)
     {
      if(!g_position_was_open || g_active_ticket != ticket)
        {
         g_active_ticket = ticket;
         g_best_favorable_hist = g_hist_current;
        }
      else if(ptype == POSITION_TYPE_BUY)
         g_best_favorable_hist = MathMax(g_best_favorable_hist, g_hist_current);
      else
         g_best_favorable_hist = MathMin(g_best_favorable_hist, g_hist_current);

      g_position_was_open = true;
      g_last_position_type = ptype;
      g_last_position_sl = sl;
      return;
     }

   if(g_position_was_open && !g_strategy_exit_requested && g_last_position_sl > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double tolerance = (point > 0.0) ? 5.0 * point : 0.0;
      const bool buy_stopped = (g_last_position_type == POSITION_TYPE_BUY &&
                                bid > 0.0 &&
                                bid <= g_last_position_sl + tolerance);
      const bool sell_stopped = (g_last_position_type == POSITION_TYPE_SELL &&
                                 ask > 0.0 &&
                                 ask >= g_last_position_sl - tolerance);
      if(buy_stopped)
         g_block_long_after_stop = true;
      if(sell_stopped)
         g_block_short_after_stop = true;
     }

   g_position_was_open = false;
   g_strategy_exit_requested = false;
   g_active_ticket = 0;
   g_best_favorable_hist = 0.0;
  }

bool Strategy_RefreshClosedBarState()
  {
   g_state_ready = false;

   if(strategy_hist_ema_period < 1 ||
      strategy_adx_period < 1 ||
      strategy_volume_ma_period < 1 ||
      strategy_sma_fast_period < 1 ||
      strategy_sma_slow_period < 1 ||
      strategy_min_hold_bars < 0 ||
      strategy_best_hist_pullback < 0.0 ||
      strategy_best_hist_pullback > 1.0)
      return false;

   const double raw_now = Strategy_RawStrength(1);
   const double raw_prev = Strategy_RawStrength(2);
   const double alpha = 2.0 / ((double)strategy_hist_ema_period + 1.0);

   if(!g_hist_initialized)
     {
      g_hist_previous = raw_prev;
      g_hist_current = raw_now;
      g_hist_initialized = true;
     }
   else
     {
      g_hist_previous = g_hist_current;
      g_hist_current = alpha * raw_now + (1.0 - alpha) * g_hist_current;
     }

   g_last_adx = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
   g_last_plus_di = QM_ADX_PlusDI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
   g_last_minus_di = QM_ADX_MinusDI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
   g_last_volume_ratio = Strategy_VolumeRatio(1);
   g_last_sma_fast = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_fast_period, 1);
   g_last_sma_slow = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_slow_period, 1);

   if(g_block_long_after_stop && g_hist_current <= 0.0)
      g_block_long_after_stop = false;
   if(g_block_short_after_stop && g_hist_current >= 0.0)
      g_block_short_after_stop = false;

   Strategy_UpdatePositionLifecycle();
   g_state_ready = (g_last_adx > 0.0 && g_last_plus_di > 0.0 && g_last_minus_di > 0.0 && g_last_volume_ratio > 0.0);
   return g_state_ready;
  }

int Strategy_HeldBars(const datetime open_time)
  {
   const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(open_time <= 0 || seconds <= 0)
      return 0;
   const long elapsed = (long)(TimeCurrent() - open_time);
   if(elapsed <= 0)
      return 0;
   return (int)(elapsed / seconds);
  }

double Strategy_StopPrice(const QM_OrderType side, const double entry_price)
  {
   if(entry_price <= 0.0)
      return 0.0;

   if(strategy_stop_mode == STRATEGY_STOP_ATR)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      return QM_StopATRFromValue(_Symbol, side, entry_price, atr, strategy_atr_stop_mult);
     }

   if(strategy_fixed_stop_pct <= 0.0)
      return 0.0;
   const double distance = entry_price * strategy_fixed_stop_pct / 100.0;
   return QM_StopRulesStopFromDistance(_Symbol, side, entry_price, distance);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(!Strategy_RefreshClosedBarState())
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   double sl;
   if(Strategy_SelectOurPosition(ticket, ptype, open_time, sl))
      return false;

   const bool sma_long_ok = (!strategy_sma_filter_enabled || g_last_sma_fast > g_last_sma_slow);
   const bool sma_short_ok = (!strategy_sma_filter_enabled || g_last_sma_fast < g_last_sma_slow);

   const bool long_setup = (g_hist_current > strategy_strength_threshold &&
                            g_hist_current > g_hist_previous &&
                            g_last_adx > strategy_adx_min &&
                            g_last_plus_di > g_last_minus_di &&
                            g_last_volume_ratio > strategy_volume_ratio_min &&
                            sma_long_ok &&
                            !g_block_long_after_stop);

   const bool short_setup = (g_hist_current < -strategy_strength_threshold &&
                             g_hist_current < g_hist_previous &&
                             g_last_adx > strategy_adx_min &&
                             g_last_minus_di > g_last_plus_di &&
                             g_last_volume_ratio > strategy_volume_ratio_min &&
                             sma_short_ok &&
                             !g_block_short_after_stop);

   if(!long_setup && !short_setup)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(long_setup)
     {
      req.type = QM_BUY;
      req.sl = Strategy_StopPrice(req.type, ask);
      req.reason = "real_strength_long";
      return (req.sl > 0.0 && req.sl < ask - point);
     }

   req.type = QM_SELL;
   req.sl = Strategy_StopPrice(req.type, bid);
   req.reason = "real_strength_short";
   return (req.sl > bid + point);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   Strategy_UpdatePositionLifecycle();
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   Strategy_UpdatePositionLifecycle();
   if(!g_state_ready)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   double sl;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_time, sl))
      return false;

   if(Strategy_HeldBars(open_time) < strategy_min_hold_bars)
      return false;

   const bool sma_confirms = Strategy_SmaConfirms(ptype);
   const bool sma_reversed = Strategy_SmaReversedAgainst(ptype);
   bool should_exit = false;

   if(ptype == POSITION_TYPE_BUY)
     {
      if(sma_confirms && g_hist_previous >= 0.0 && g_hist_current < -strategy_flip_threshold)
         should_exit = true;
      if(sma_reversed && g_best_favorable_hist > 0.0 &&
         g_hist_current <= g_best_favorable_hist * (1.0 - strategy_best_hist_pullback))
         should_exit = true;
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      if(sma_confirms && g_hist_previous <= 0.0 && g_hist_current > strategy_flip_threshold)
         should_exit = true;
      if(sma_reversed && g_best_favorable_hist < 0.0 &&
         g_hist_current >= g_best_favorable_hist + MathAbs(g_best_favorable_hist) * strategy_best_hist_pullback)
         should_exit = true;
     }

   if(should_exit)
      g_strategy_exit_requested = true;
   return should_exit;
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
