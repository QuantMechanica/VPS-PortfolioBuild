#property strict
#property version   "5.0"
#property description "QM5_1219 Carver EWMAC acceleration"

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
input int    qm_ea_id                   = 1219;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
#define QM5_1219_SYMBOL_COUNT 8

input int    strategy_fast_period        = 32;
input int    strategy_vol_lookback       = 25;
input double strategy_forecast_scalar    = 10.0;
input double strategy_entry_forecast     = 2.0;
input double strategy_forecast_cap       = 20.0;
input int    strategy_atr_period         = 20;
input double strategy_stop_atr_mult      = 2.5;
input int    strategy_min_extra_bars     = 30;
input int    strategy_max_spread_points  = 0;

string g_strategy_symbols[QM5_1219_SYMBOL_COUNT] = {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "GDAXI.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
};

int g_strategy_slots[QM5_1219_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6, 7};

bool   g_forecast_ready = false;
double g_forecast_value = 0.0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1219_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_strategy_slots[idx];
  }

double Strategy_Clamp(const double value, const double lower, const double upper)
  {
   return MathMax(lower, MathMin(upper, value));
  }

bool Strategy_HasEnoughD1Bars(const int signal_shift)
  {
   const int fast = MathMax(2, strategy_fast_period);
   const int slow = 4 * fast;
   const int needed = signal_shift + slow + fast + MathMax(2, strategy_vol_lookback) +
                      MathMax(0, strategy_min_extra_bars) + 2;
   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 0, needed, closes); // perf-allowed
   return (copied >= needed);
  }

double Strategy_CloseChangeStdDev(const int start_shift, const int lookback)
  {
   if(start_shift < 1 || lookback < 2)
      return 0.0;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, start_shift, lookback + 1, closes); // perf-allowed
   if(copied < lookback + 1)
      return 0.0;

   double sum = 0.0;
   double sum_sq = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      if(closes[i] <= 0.0 || closes[i + 1] <= 0.0)
         return 0.0;
      const double change = closes[i] - closes[i + 1];
      sum += change;
      sum_sq += change * change;
     }

   const double count = (double)lookback;
   const double mean = sum / count;
   const double variance = (sum_sq / count) - mean * mean;
   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance);
  }

bool Strategy_EwmacAtShift(const int signal_shift, double &out_ewmac)
  {
   out_ewmac = 0.0;
   const int fast = MathMax(2, strategy_fast_period);
   const int slow = 4 * fast;
   const int vol_lookback = MathMax(2, strategy_vol_lookback);

   const double fast_ema = QM_EMA(_Symbol, PERIOD_D1, fast, signal_shift);
   const double slow_ema = QM_EMA(_Symbol, PERIOD_D1, slow, signal_shift);
   const double sigma = Strategy_CloseChangeStdDev(signal_shift, vol_lookback);
   if(fast_ema <= 0.0 || slow_ema <= 0.0 || sigma <= 0.0)
      return false;

   out_ewmac = (fast_ema - slow_ema) / sigma;
   return true;
  }

bool Strategy_ForecastAtShift(const int signal_shift, double &out_forecast)
  {
   out_forecast = 0.0;
   const int fast = MathMax(2, strategy_fast_period);
   if(!Strategy_HasEnoughD1Bars(signal_shift))
      return false;

   double ewmac_now = 0.0;
   double ewmac_lagged = 0.0;
   if(!Strategy_EwmacAtShift(signal_shift, ewmac_now))
      return false;
   if(!Strategy_EwmacAtShift(signal_shift + fast, ewmac_lagged))
      return false;

   const double raw_accel = ewmac_now - ewmac_lagged;
   const double cap = MathAbs(strategy_forecast_cap);
   out_forecast = Strategy_Clamp(strategy_forecast_scalar * raw_accel, -cap, cap);
   return true;
  }

bool Strategy_UpdateForecastCache()
  {
   double forecast = 0.0;
   if(!Strategy_ForecastAtShift(1, forecast))
     {
      g_forecast_ready = false;
      g_forecast_value = 0.0;
      return false;
     }

   g_forecast_ready = true;
   g_forecast_value = forecast;
   return true;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points == 0)
      return true;
   if(spread_points < 0)
      return true;
   return (spread_points <= strategy_max_spread_points);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(Strategy_SlotForCurrentSymbol() != qm_magic_slot_offset)
      return true;
   if(strategy_fast_period < 2 || strategy_vol_lookback < 2 || strategy_atr_period < 2)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_forecast_scalar <= 0.0)
      return true;
   if(strategy_forecast_cap <= 0.0 || strategy_stop_atr_mult <= 0.0)
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
   req.reason = "CARVER_ACCEL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_UpdateForecastCache())
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const bool long_signal = (g_forecast_value > strategy_entry_forecast);
   const bool short_signal = (g_forecast_value < -strategy_entry_forecast);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = long_signal ? "ACCEL_LONG" : "ACCEL_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies only the emergency ATR stop and forecast-zero exits.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!g_forecast_ready)
      return false;

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
      if(pos_type == POSITION_TYPE_BUY && g_forecast_value < 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_forecast_value > 0.0)
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
