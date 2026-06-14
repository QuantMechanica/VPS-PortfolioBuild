#property strict
#property version   "5.0"
#property description "QM5_1068 Carver rolling-range breakout forecast"

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
input int    qm_ea_id                   = 1068;
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
input int    strategy_lookback_d1_bars   = 80;
input double strategy_entry_forecast     = 2.0;
input double strategy_forecast_scalar    = 40.0;
input double strategy_forecast_cap       = 20.0;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Time: D1 rebalance cadence is enforced by the framework new-bar gate.
   // Spread: new-entry spread cap is evaluated inside Strategy_EntrySignal.
   // News: central framework check plus Strategy_NewsFilterHook below.
   if(strategy_lookback_d1_bars < 2 || strategy_lookback_d1_bars > 512)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_forecast_scalar <= 0.0 || strategy_forecast_cap <= 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_spread_median_days < 1 || strategy_spread_median_days > 64 || strategy_spread_mult <= 0.0)
      return true;

   if(_Symbol != "GDAXI.DWX" &&
      _Symbol != "NDX.DWX" &&
      _Symbol != "WS30.DWX" &&
      _Symbol != "EURUSD.DWX" &&
      _Symbol != "GBPUSD.DWX" &&
      _Symbol != "USDJPY.DWX" &&
      _Symbol != "XAUUSD.DWX" &&
      _Symbol != "XTIUSD.DWX")
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
   req.reason = "QM5_1068_RANGE_FORECAST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, strategy_lookback_d1_bars, closes); // perf-allowed: bounded D1 rolling close range; caller gates EntrySignal with QM_IsNewBar().
   if(copied != strategy_lookback_d1_bars)
      return false;

   double roll_max = -DBL_MAX;
   double roll_min = DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      const double close_i = closes[i];
      if(close_i <= 0.0)
         return false;
      roll_max = MathMax(roll_max, close_i);
      roll_min = MathMin(roll_min, close_i);
     }

   if(roll_max <= roll_min)
      return false;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   int spreads[];
   ArraySetAsSeries(spreads, true);
   const int spread_copied = CopySpread(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, spreads); // perf-allowed: bounded D1 spread sample; caller gates EntrySignal with QM_IsNewBar().
   if(spread_copied > 0 && current_spread > 0)
     {
      double spread_values[64];
      int spread_count = 0;
      for(int i = 0; i < spread_copied && spread_count < 64; ++i)
        {
         if(spreads[i] <= 0)
            continue;
         spread_values[spread_count] = (double)spreads[i];
         spread_count++;
        }

      if(spread_count > 0)
        {
         for(int i = 0; i < spread_count - 1; ++i)
            for(int j = i + 1; j < spread_count; ++j)
               if(spread_values[j] < spread_values[i])
                 {
                  const double tmp = spread_values[i];
                  spread_values[i] = spread_values[j];
                  spread_values[j] = tmp;
                 }

         const double median_spread = ((spread_count % 2) == 1)
                                      ? spread_values[spread_count / 2]
                                      : 0.5 * (spread_values[spread_count / 2 - 1] + spread_values[spread_count / 2]);
         if(median_spread > 0.0 && (double)current_spread > median_spread * strategy_spread_mult)
            return false;
        }
     }

   const double roll_mean = 0.5 * (roll_max + roll_min);
   double forecast = strategy_forecast_scalar * (closes[0] - roll_mean) / (roll_max - roll_min);
   forecast = MathMax(-strategy_forecast_cap, MathMin(strategy_forecast_cap, forecast));

   int direction = 0;
   if(forecast > strategy_entry_forecast)
      direction = 1;
   else if(forecast < -strategy_entry_forecast)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1068_FORECAST_LONG" : "QM5_1068_FORECAST_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies only the initial ATR emergency stop; no trailing, BE, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_position = false;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, strategy_lookback_d1_bars, closes); // perf-allowed: bounded D1 rolling close range; exit check is gated by QM_IsNewBar(_Symbol, PERIOD_D1).
   if(copied != strategy_lookback_d1_bars)
      return false;

   double roll_max = -DBL_MAX;
   double roll_min = DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      const double close_i = closes[i];
      if(close_i <= 0.0)
         return false;
      roll_max = MathMax(roll_max, close_i);
      roll_min = MathMin(roll_min, close_i);
     }

   if(roll_max <= roll_min)
      return false;

   const double roll_mean = 0.5 * (roll_max + roll_min);
   double forecast = strategy_forecast_scalar * (closes[0] - roll_mean) / (roll_max - roll_min);
   forecast = MathMax(-strategy_forecast_cap, MathMin(strategy_forecast_cap, forecast));

   if(pos_type == POSITION_TYPE_BUY && forecast < 0.0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && forecast > 0.0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the central framework news filter for P8 variants.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1068\",\"ea\":\"carver-breakout-range\"}");
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
