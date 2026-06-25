#property strict
#property version   "5.0"
#property description "QM5_9515 lt-multi-rule — Leveraged Trading Combined Momentum Breakout Carry"

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
input int    qm_ea_id                   = 9515;
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
input int    strategy_risk_atr_period       = 25;
input int    strategy_sl_atr_period         = 20;
input double strategy_sl_atr_mult           = 2.5;
input double strategy_entry_threshold       = 2.0;
input int    strategy_min_valid_blocks      = 2;
input int    strategy_min_momentum_pairs    = 3;
input int    strategy_min_breakout_horizons = 3;
input int    strategy_spread_lookback       = 20;
input double strategy_spread_cap_mult       = 2.0;
input double strategy_mom_scalar_2_8        = 180.8;
input double strategy_mom_scalar_4_16       = 124.32;
input double strategy_mom_scalar_8_32       = 83.84;
input double strategy_mom_scalar_16_64      = 57.12;
input double strategy_mom_scalar_32_128     = 38.24;
input double strategy_mom_scalar_64_256     = 25.28;
input double strategy_breakout_scalar_10    = 28.6;
input double strategy_breakout_scalar_20    = 31.6;
input double strategy_breakout_scalar_40    = 32.7;
input double strategy_breakout_scalar_80    = 33.5;
input double strategy_breakout_scalar_160   = 33.5;
input double strategy_breakout_scalar_320   = 33.5;

double g_combined_forecast = 0.0;
int    g_valid_blocks      = 0;
double g_spread_history[20];
int    g_spread_idx        = 0;
int    g_spread_count      = 0;

double ForecastClamp(const double value)
  {
   if(value > 20.0)
      return 20.0;
   if(value < -20.0)
      return -20.0;
   return value;
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

void UpdateSpreadHistory()
  {
   const double spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_spread_history[g_spread_idx] = spread_pts;
   g_spread_idx = (g_spread_idx + 1) % 20;
   if(g_spread_count < strategy_spread_lookback && g_spread_count < 20)
      g_spread_count++;
  }

double MedianSpread()
  {
   if(g_spread_count <= 0)
      return 0.0;

   double values[20];
   const int n = g_spread_count;
   for(int i = 0; i < n; ++i)
      values[i] = g_spread_history[i];

   for(int i = 0; i < n - 1; ++i)
      for(int j = i + 1; j < n; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((n % 2) == 0)
      return (values[n / 2 - 1] + values[n / 2]) / 2.0;
   return values[n / 2];
  }

double ComputeMomentumForecast(int &valid_pairs)
  {
   valid_pairs = 0;
   const int fast_periods[6] = {2, 4, 8, 16, 32, 64};
   const int slow_periods[6] = {8, 16, 32, 64, 128, 256};
   const double scalars[6] = {strategy_mom_scalar_2_8,
                              strategy_mom_scalar_4_16,
                              strategy_mom_scalar_8_32,
                              strategy_mom_scalar_16_64,
                              strategy_mom_scalar_32_128,
                              strategy_mom_scalar_64_256};

   const double risk_units = QM_ATR(_Symbol, PERIOD_D1, strategy_risk_atr_period, 1);
   if(risk_units <= 0.0 || risk_units > 1e8)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < 6; ++i)
     {
      const double sma_fast = QM_SMA(_Symbol, PERIOD_D1, fast_periods[i], 1);
      const double sma_slow = QM_SMA(_Symbol, PERIOD_D1, slow_periods[i], 1);
      if(sma_fast <= 0.0 || sma_fast > 1e8 || sma_slow <= 0.0 || sma_slow > 1e8)
         continue;

      sum += ForecastClamp((sma_fast - sma_slow) / risk_units * scalars[i]);
      valid_pairs++;
     }

   if(valid_pairs < strategy_min_momentum_pairs)
      return 0.0;
   return sum / (double)valid_pairs;
  }

double ComputeBreakoutForecast(int &valid_horizons)
  {
   valid_horizons = 0;
   const int lookbacks[6] = {10, 20, 40, 80, 160, 320};
   const double scalars[6] = {strategy_breakout_scalar_10,
                              strategy_breakout_scalar_20,
                              strategy_breakout_scalar_40,
                              strategy_breakout_scalar_80,
                              strategy_breakout_scalar_160,
                              strategy_breakout_scalar_320};

   const int total_bars = Bars(_Symbol, PERIOD_D1); // perf-allowed: rolling close-window forecast, called only on D1 rebalance.
   if(total_bars < 321)
      return 0.0;

   const double close_now = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 close for rolling breakout forecast.
   if(close_now <= 0.0)
      return 0.0;

   double sum = 0.0;
   for(int k = 0; k < 6; ++k)
     {
      const int lookback = lookbacks[k];
      if(total_bars < lookback + 1)
         continue;

      double roll_max = -DBL_MAX;
      double roll_min = DBL_MAX;
      for(int i = 1; i <= lookback; ++i)
        {
         const double close_i = iClose(_Symbol, PERIOD_D1, i); // perf-allowed: bounded D1 rolling close-window forecast.
         if(close_i <= 0.0)
            continue;
         if(close_i > roll_max)
            roll_max = close_i;
         if(close_i < roll_min)
            roll_min = close_i;
        }

      if(roll_max <= roll_min || roll_max <= 0.0)
         continue;

      const double roll_avg = (roll_max + roll_min) / 2.0;
      sum += ForecastClamp((close_now - roll_avg) / (roll_max - roll_min) * scalars[k]);
      valid_horizons++;
     }

   if(valid_horizons < strategy_min_breakout_horizons)
      return 0.0;
   return sum / (double)valid_horizons;
  }

void RefreshForecastState()
  {
   UpdateSpreadHistory();

   int valid_pairs = 0;
   int valid_horizons = 0;
   const double momentum = ComputeMomentumForecast(valid_pairs);
   const double breakout = ComputeBreakoutForecast(valid_horizons);

   double sum = 0.0;
   int blocks = 0;
   if(valid_pairs >= strategy_min_momentum_pairs)
     {
      sum += momentum;
      blocks++;
     }
   if(valid_horizons >= strategy_min_breakout_horizons)
     {
      sum += breakout;
      blocks++;
     }

   g_valid_blocks = blocks;
   g_combined_forecast = (blocks > 0) ? ForecastClamp(sum / (double)blocks) : 0.0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(g_spread_count >= 5)
     {
      const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      const double median_spread = MedianSpread();
      if(current_spread > 0.0 && median_spread > 0.0 &&
         current_spread > strategy_spread_cap_mult * median_spread)
         return true;
     }
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   RefreshForecastState();

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_valid_blocks < strategy_min_valid_blocks)
      return false;
   if(HasOpenPosition())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_combined_forecast > strategy_entry_threshold)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_sl_atr_period, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "LT_MULTI_RULE_LONG";
      return (req.sl > 0.0);
     }

   if(g_combined_forecast < -strategy_entry_threshold)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_sl_atr_period, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "LT_MULTI_RULE_SHORT";
      return (req.sl > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!HasOpenPosition())
      return;

   if(QM_IsNewBar(_Symbol, PERIOD_D1))
      RefreshForecastState();
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_valid_blocks < strategy_min_valid_blocks)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_combined_forecast <= 0.0)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_combined_forecast >= 0.0)
         return true;
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
