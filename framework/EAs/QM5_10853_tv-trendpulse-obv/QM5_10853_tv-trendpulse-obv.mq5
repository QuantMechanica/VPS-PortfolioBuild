#property strict
#property version   "5.0"
#property description "QM5_10853 TradingView Trend Pulse OBV Breakout"

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
input int    qm_ea_id                   = 10853;
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
input int    strategy_channel_period       = 34;
input double strategy_range_factor         = 2.0;
input int    strategy_regime_ema_period    = 200;
input int    strategy_obv_ema_period       = 34;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 2.0;
input double strategy_max_spread_stop_frac = 0.15;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

bool   g_strategy_snapshot_valid = false;
double g_strategy_close_1        = 0.0;
double g_strategy_midline_1      = 0.0;
double g_strategy_regime_ema_1   = 0.0;

struct StrategyTrendPulseSnapshot
  {
   double close_1;
   double close_2;
   double midline_1;
   double upper_1;
   double upper_2;
   double obv_1;
   double obv_ema_1;
  };

int StrategyMaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

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
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates); // perf-allowed: bounded OHLC/tick-volume Trend Pulse/OBV window runs only from Strategy_EntrySignal after framework QM_IsNewBar().
   return (copied >= bars_needed);
  }

void Strategy_ResetSnapshot()
  {
   g_strategy_snapshot_valid = false;
   g_strategy_close_1 = 0.0;
   g_strategy_midline_1 = 0.0;
   g_strategy_regime_ema_1 = 0.0;
  }

bool Strategy_CalculateTrendPulse(const MqlRates &rates[],
                                  const int count,
                                  StrategyTrendPulseSnapshot &snapshot)
  {
   snapshot.close_1 = 0.0;
   snapshot.close_2 = 0.0;
   snapshot.midline_1 = 0.0;
   snapshot.upper_1 = 0.0;
   snapshot.upper_2 = 0.0;
   snapshot.obv_1 = 0.0;
   snapshot.obv_ema_1 = 0.0;

   if(count < 4 ||
      strategy_channel_period <= 1 ||
      strategy_obv_ema_period <= 1 ||
      strategy_range_factor <= 0.0)
      return false;

   const int oldest = count - 1;
   if(rates[oldest].close <= 0.0 || rates[oldest].high <= 0.0 || rates[oldest].low <= 0.0)
      return false;

   const double channel_alpha = 2.0 / ((double)strategy_channel_period + 1.0);
   const double obv_alpha = 2.0 / ((double)strategy_obv_ema_period + 1.0);

   double price_ema_1 = rates[oldest].close;
   double price_ema_2 = price_ema_1;
   double range_ema_1 = rates[oldest].high - rates[oldest].low;
   double range_ema_2 = range_ema_1;
   double obv = 0.0;
   double obv_ema = 0.0;

   for(int i = oldest; i >= 0; --i)
     {
      const double close_price = rates[i].close;
      const double high_price = rates[i].high;
      const double low_price = rates[i].low;
      if(close_price <= 0.0 || high_price <= 0.0 || low_price <= 0.0 || high_price < low_price)
         return false;

      double true_range = high_price - low_price;
      if(i < oldest)
        {
         const double prev_close = rates[i + 1].close;
         true_range = MathMax(true_range,
                              MathMax(MathAbs(high_price - prev_close),
                                      MathAbs(low_price - prev_close)));

         const double tick_volume = (rates[i].tick_volume > 0) ? (double)rates[i].tick_volume : 0.0;
         if(close_price > prev_close)
            obv += tick_volume;
         else if(close_price < prev_close)
            obv -= tick_volume;

         price_ema_1 = channel_alpha * close_price + (1.0 - channel_alpha) * price_ema_1;
         price_ema_2 = channel_alpha * price_ema_1 + (1.0 - channel_alpha) * price_ema_2;
         range_ema_1 = channel_alpha * true_range + (1.0 - channel_alpha) * range_ema_1;
         range_ema_2 = channel_alpha * range_ema_1 + (1.0 - channel_alpha) * range_ema_2;
         obv_ema = obv_alpha * obv + (1.0 - obv_alpha) * obv_ema;
        }

      const double midline = price_ema_2;
      const double upper = midline + strategy_range_factor * range_ema_2;

      if(i == 2)
        {
         snapshot.close_2 = close_price;
         snapshot.upper_2 = upper;
        }
      else if(i == 1)
        {
         snapshot.close_1 = close_price;
         snapshot.midline_1 = midline;
         snapshot.upper_1 = upper;
         snapshot.obv_1 = obv;
         snapshot.obv_ema_1 = obv_ema;
        }
     }

   return (snapshot.close_1 > 0.0 &&
           snapshot.close_2 > 0.0 &&
           snapshot.midline_1 > 0.0 &&
           snapshot.upper_1 > 0.0 &&
           snapshot.upper_2 > 0.0);
  }

bool Strategy_RefreshSnapshot(StrategyTrendPulseSnapshot &snapshot)
  {
   Strategy_ResetSnapshot();

   const int warmup_channel = StrategyMaxInt(strategy_channel_period * 6, 60);
   const int warmup_obv = StrategyMaxInt(strategy_obv_ema_period * 6, 60);
   const int bars_needed = StrategyMaxInt(warmup_channel, warmup_obv) + 5;

   MqlRates rates[];
   if(!Strategy_CopyBars(rates, bars_needed))
      return false;

   if(!Strategy_CalculateTrendPulse(rates, bars_needed, snapshot))
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double regime_ema = QM_EMA(_Symbol, tf, strategy_regime_ema_period, 1, PRICE_CLOSE);
   if(regime_ema <= 0.0)
      return false;

   g_strategy_close_1 = snapshot.close_1;
   g_strategy_midline_1 = snapshot.midline_1;
   g_strategy_regime_ema_1 = regime_ema;
   g_strategy_snapshot_valid = true;
   return true;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   if(tf != PERIOD_H4 && tf != PERIOD_D1)
      return true;

   if(strategy_channel_period <= 1 ||
      strategy_regime_ema_period <= 1 ||
      strategy_obv_ema_period <= 1 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_range_factor <= 0.0 ||
      strategy_max_spread_stop_frac <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(atr <= 0.0 || point <= 0.0 || spread_points < 0)
      return true;

   const double stop_distance = atr * strategy_atr_sl_mult;
   const double spread_distance = (double)spread_points * point;
   if(spread_distance > stop_distance * strategy_max_spread_stop_frac)
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
   req.reason = "TV_TRENDPULSE_OBV_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   StrategyTrendPulseSnapshot snapshot;
   if(!Strategy_RefreshSnapshot(snapshot))
      return false;

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(Strategy_GetOurPosition(existing_type))
      return false;

   if(snapshot.close_2 > snapshot.upper_2 || snapshot.close_1 <= snapshot.upper_1)
      return false;

   if(snapshot.obv_1 <= snapshot.obv_ema_1)
      return false;

   if(snapshot.close_1 <= g_strategy_regime_ema_1)
      return false;

   const double entry = QM_EntryMarketPrice(QM_BUY);
   if(entry <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
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
   // Card specifies no break-even, trailing stop, partial close, or pyramiding.
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
   if(!g_strategy_snapshot_valid)
      return false;

   return (g_strategy_close_1 < g_strategy_midline_1 ||
           g_strategy_close_1 < g_strategy_regime_ema_1);
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
