#property strict
#property version   "5.0"
#property description "QM5_10846 TradingView Growth Breakout EMA RVOL Stoch RSI"

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
input int    qm_ea_id                   = 10846;
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
input int    strategy_fast_ema_period       = 20;
input int    strategy_slow_ema_period       = 50;
input int    strategy_breakout_lookback     = 10;
input int    strategy_high_lookback_bars    = 252;
input double strategy_fast_ema_proximity    = 0.02;
input double strategy_high_proximity        = 0.05;
input int    strategy_rvol_lookback         = 20;
input double strategy_rvol_threshold        = 1.5;
input int    strategy_rsi_period            = 14;
input int    strategy_stoch_rsi_period      = 14;
input int    strategy_stoch_k_smooth        = 3;
input int    strategy_stoch_d_smooth        = 3;
input double strategy_stoch_overbought      = 80.0;
input int    strategy_atr_period            = 14;
input double strategy_atr_sl_mult           = 2.5;
input double strategy_max_spread_stop_frac  = 0.15;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &position_type)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_CopyBars(MqlRates &rates[], const int bars_needed)
  {
   if(bars_needed <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates); // perf-allowed: bounded OHLC/tick-volume breakout scan runs only from Strategy_EntrySignal after framework QM_IsNewBar().
   return (copied >= bars_needed);
  }

double Strategy_MaxHigh(const MqlRates &rates[], const int first_shift, const int lookback)
  {
   double max_high = 0.0;
   for(int i = first_shift; i < first_shift + lookback; ++i)
     {
      if(rates[i].high <= 0.0)
         continue;
      if(max_high <= 0.0 || rates[i].high > max_high)
         max_high = rates[i].high;
     }

   return max_high;
  }

double Strategy_AverageTickVolume(const MqlRates &rates[], const int first_shift, const int lookback)
  {
   double volume_sum = 0.0;
   int samples = 0;
   for(int i = first_shift; i < first_shift + lookback; ++i)
     {
      if(rates[i].tick_volume <= 0)
         continue;
      volume_sum += (double)rates[i].tick_volume;
      samples++;
     }

   if(samples <= 0)
      return 0.0;
   return volume_sum / (double)samples;
  }

double Strategy_StochRsiRaw(const int shift)
  {
   if(strategy_rsi_period <= 0 || strategy_stoch_rsi_period <= 1)
      return 0.0;

   double lowest = 0.0;
   double highest = 0.0;
   for(int i = shift; i < shift + strategy_stoch_rsi_period; ++i)
     {
      const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, i, PRICE_CLOSE);
      if(rsi <= 0.0)
         return 0.0;
      if(i == shift || rsi < lowest)
         lowest = rsi;
      if(i == shift || rsi > highest)
         highest = rsi;
     }

   const double current = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift, PRICE_CLOSE);
   if(highest <= lowest || current <= 0.0)
      return 50.0;

   return 100.0 * (current - lowest) / (highest - lowest);
  }

double Strategy_StochRsiK(const int shift)
  {
   if(strategy_stoch_k_smooth <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = shift; i < shift + strategy_stoch_k_smooth; ++i)
      sum += Strategy_StochRsiRaw(i);

   return sum / (double)strategy_stoch_k_smooth;
  }

double Strategy_StochRsiD(const int shift)
  {
   if(strategy_stoch_d_smooth <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = shift; i < shift + strategy_stoch_d_smooth; ++i)
      sum += Strategy_StochRsiK(i);

   return sum / (double)strategy_stoch_d_smooth;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   if(tf != PERIOD_D1 && tf != PERIOD_H4)
      return true;

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_spread_stop_frac <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(atr <= 0.0 || point <= 0.0 || spread_points < 0)
      return true;

   const double emergency_stop_distance = atr * strategy_atr_sl_mult;
   const double spread_distance = (double)spread_points * point;
   if(spread_distance > emergency_stop_distance * strategy_max_spread_stop_frac)
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
   req.reason = "TV_GROWTH_BREAKOUT_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_fast_ema_period <= 0 ||
      strategy_slow_ema_period <= strategy_fast_ema_period ||
      strategy_breakout_lookback <= 0 ||
      strategy_high_lookback_bars <= strategy_breakout_lookback ||
      strategy_fast_ema_proximity <= 0.0 ||
      strategy_high_proximity <= 0.0 ||
      strategy_rvol_lookback <= 0 ||
      strategy_rvol_threshold <= 0.0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_stoch_overbought <= 0.0)
      return false;

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy_GetOurPosition(existing_type))
      return false;

   const int bars_needed = MathMax(strategy_high_lookback_bars + 2,
                                   MathMax(strategy_breakout_lookback + 2,
                                           strategy_rvol_lookback + 2));
   MqlRates rates[];
   if(!Strategy_CopyBars(rates, bars_needed))
      return false;

   const double close_1 = rates[1].close;
   if(close_1 <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast_ema_1 = QM_EMA(_Symbol, tf, strategy_fast_ema_period, 1, PRICE_CLOSE);
   const double slow_ema_1 = QM_EMA(_Symbol, tf, strategy_slow_ema_period, 1, PRICE_CLOSE);
   const double fast_ema_2 = QM_EMA(_Symbol, tf, strategy_fast_ema_period, 2, PRICE_CLOSE);
   const double slow_ema_2 = QM_EMA(_Symbol, tf, strategy_slow_ema_period, 2, PRICE_CLOSE);
   if(fast_ema_1 <= 0.0 || slow_ema_1 <= 0.0 || fast_ema_2 <= 0.0 || slow_ema_2 <= 0.0)
      return false;

   if(MathAbs(close_1 - fast_ema_1) / fast_ema_1 > strategy_fast_ema_proximity)
      return false;

   const double high_52w = Strategy_MaxHigh(rates, 1, strategy_high_lookback_bars);
   if(high_52w <= 0.0 || close_1 < high_52w * (1.0 - strategy_high_proximity))
      return false;

   const double breakout_high = Strategy_MaxHigh(rates, 2, strategy_breakout_lookback);
   if(breakout_high <= 0.0 || close_1 <= breakout_high)
      return false;

   const double avg_volume = Strategy_AverageTickVolume(rates, 2, strategy_rvol_lookback);
   if(avg_volume <= 0.0 || (double)rates[1].tick_volume < avg_volume * strategy_rvol_threshold)
      return false;

   const bool ema_filter = (fast_ema_2 <= slow_ema_2 && fast_ema_1 > slow_ema_1) ||
                           (close_1 > fast_ema_1);
   if(!ema_filter)
      return false;

   const double stoch_k = Strategy_StochRsiK(1);
   const double stoch_d = Strategy_StochRsiD(1);
   if(stoch_k <= stoch_d || stoch_k >= strategy_stoch_overbought)
      return false;

   const double entry = QM_EntryMarketPrice(QM_BUY);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy_GetOurPosition(position_type))
      return false;
   if(position_type != POSITION_TYPE_BUY)
      return false;

   if(strategy_slow_ema_period <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close_1 = QM_SMA(_Symbol, tf, 1, 1, PRICE_CLOSE);
   const double close_2 = QM_SMA(_Symbol, tf, 1, 2, PRICE_CLOSE);
   const double slow_ema_1 = QM_EMA(_Symbol, tf, strategy_slow_ema_period, 1, PRICE_CLOSE);
   const double slow_ema_2 = QM_EMA(_Symbol, tf, strategy_slow_ema_period, 2, PRICE_CLOSE);
   if(close_1 <= 0.0 || close_2 <= 0.0 || slow_ema_1 <= 0.0 || slow_ema_2 <= 0.0)
      return false;

   return (close_2 >= slow_ema_2 && close_1 < slow_ema_1);
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
