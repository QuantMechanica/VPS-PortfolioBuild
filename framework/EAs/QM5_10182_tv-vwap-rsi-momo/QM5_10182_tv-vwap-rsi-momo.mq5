#property strict
#property version   "5.0"
#property description "QM5_10182 TradingView VWAP RSI momentum"

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
input int    qm_ea_id                   = 10182;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H1;
input int    strategy_vwap_period              = 20;
input int    strategy_rsi_period               = 14;
input int    strategy_rsi_ema_period           = 3;
input int    strategy_sma_fast_period          = 50;
input int    strategy_sma_slow_period          = 100;
input int    strategy_trigger_lookback         = 20;
input int    strategy_atr_period               = 14;
input double strategy_atr_stop_mult            = 2.0;
input double strategy_percent_stop             = 4.0;
input double strategy_max_spread_stop_fraction = 0.15;
input int    strategy_time_stop_bars           = 64;

double g_vwap_rsi_1 = 0.0;
double g_vwap_rsi_2 = 0.0;
datetime g_signal_bar_time = 0;

ENUM_TIMEFRAMES Strategy_TF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
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

bool Strategy_LoadRates(const int bars_needed, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   const int count = MathMax(10, bars_needed);
   return (CopyRates(_Symbol, Strategy_TF(), 0, count, rates) >= count);
  }

double Strategy_RollingVwap(MqlRates &rates[], const int shift)
  {
   const int period = MathMax(2, strategy_vwap_period);
   double pv_sum = 0.0;
   double volume_sum = 0.0;

   for(int offset = 0; offset < period; ++offset)
     {
      const int idx = shift + offset;
      const double high = rates[idx].high;
      const double low = rates[idx].low;
      const double close = rates[idx].close;
      if(high <= 0.0 || low <= 0.0 || close <= 0.0)
         return 0.0;

      const double volume = (rates[idx].tick_volume > 0) ? (double)rates[idx].tick_volume : 1.0;
      const double typical = (high + low + close) / 3.0;
      pv_sum += typical * volume;
      volume_sum += volume;
     }

   if(volume_sum <= 0.0)
      return 0.0;
   return pv_sum / volume_sum;
  }

double Strategy_VwapRsiRaw(MqlRates &rates[], const int shift)
  {
   const int period = MathMax(2, strategy_rsi_period);
   double gain_sum = 0.0;
   double loss_sum = 0.0;

   for(int offset = 0; offset < period; ++offset)
     {
      const double newer = Strategy_RollingVwap(rates, shift + offset);
      const double older = Strategy_RollingVwap(rates, shift + offset + 1);
      if(newer <= 0.0 || older <= 0.0)
         return 0.0;

      const double change = newer - older;
      if(change > 0.0)
         gain_sum += change;
      else
         loss_sum += -change;
     }

   const double avg_gain = gain_sum / period;
   const double avg_loss = loss_sum / period;
   if(avg_loss <= 0.0)
      return 100.0;
   const double rs = avg_gain / avg_loss;
   return 100.0 - (100.0 / (1.0 + rs));
  }

double Strategy_VwapRsiEma(MqlRates &rates[], const int shift)
  {
   const int ema_period = MathMax(1, strategy_rsi_ema_period);
   const double alpha = 2.0 / (ema_period + 1.0);
   double ema = 0.0;

   for(int offset = ema_period - 1; offset >= 0; --offset)
     {
      const double raw = Strategy_VwapRsiRaw(rates, shift + offset);
      if(raw <= 0.0)
         return 0.0;
      if(offset == ema_period - 1)
         ema = raw;
      else
         ema = alpha * raw + (1.0 - alpha) * ema;
     }

   return ema;
  }

bool Strategy_UpdateSignalState()
  {
   const int lookback = MathMax(3, strategy_trigger_lookback);
   const int bars_needed = strategy_vwap_period + strategy_rsi_period + strategy_rsi_ema_period + lookback + 8;
   MqlRates rates[];
   if(!Strategy_LoadRates(bars_needed, rates))
      return false;

   g_vwap_rsi_1 = Strategy_VwapRsiEma(rates, 1);
   g_vwap_rsi_2 = Strategy_VwapRsiEma(rates, 2);
   g_signal_bar_time = rates[1].time;
   return (g_vwap_rsi_1 > 0.0 && g_vwap_rsi_2 > 0.0);
  }

bool Strategy_ShallowDipLong(MqlRates &rates[])
  {
   bool reached_high = false;
   bool dipped = false;
   const int lookback = MathMax(3, strategy_trigger_lookback);
   for(int shift = lookback + 1; shift >= 2; --shift)
     {
      const double value = Strategy_VwapRsiEma(rates, shift);
      if(value <= 0.0)
         return false;
      if(value >= 75.0)
         reached_high = true;
      if(reached_high && value <= 70.0)
         dipped = true;
     }
   return (reached_high && dipped && g_vwap_rsi_1 > g_vwap_rsi_2);
  }

bool Strategy_ShallowDipShort(MqlRates &rates[])
  {
   bool reached_low = false;
   bool rallied = false;
   const int lookback = MathMax(3, strategy_trigger_lookback);
   for(int shift = lookback + 1; shift >= 2; --shift)
     {
      const double value = Strategy_VwapRsiEma(rates, shift);
      if(value <= 0.0)
         return false;
      if(value <= 25.0)
         reached_low = true;
      if(reached_low && value >= 30.0)
         rallied = true;
     }
   return (reached_low && rallied && g_vwap_rsi_1 < g_vwap_rsi_2);
  }

double Strategy_StopDistance(const double entry)
  {
   const double atr = QM_ATR(_Symbol, Strategy_TF(), strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return 0.0;

   const double pct_distance = entry * MathMax(0.0, strategy_percent_stop) / 100.0;
   const double atr_distance = atr * MathMax(0.0, strategy_atr_stop_mult);
   double distance = 0.0;
   if(pct_distance > 0.0 && atr_distance > 0.0)
      distance = MathMin(pct_distance, atr_distance);
   else if(pct_distance > 0.0)
      distance = pct_distance;
   else
      distance = atr_distance;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || distance <= point)
      return 0.0;

   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(strategy_max_spread_stop_fraction > 0.0 &&
      spread > distance * strategy_max_spread_stop_fraction)
      return 0.0;

   return distance;
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

   if(strategy_vwap_period < 2 || strategy_rsi_period < 2 ||
      strategy_rsi_ema_period < 1 || strategy_sma_fast_period < 2 ||
      strategy_sma_slow_period <= strategy_sma_fast_period ||
      strategy_atr_period <= 0 || strategy_time_stop_bars <= 0)
      return false;

   if(!Strategy_UpdateSignalState())
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_TF();
   MqlRates rates[];
   const int lookback = MathMax(3, strategy_trigger_lookback);
   const int bars_needed = MathMax(strategy_sma_slow_period + 5,
                                  strategy_vwap_period + strategy_rsi_period +
                                  strategy_rsi_ema_period + lookback + 8);
   if(!Strategy_LoadRates(bars_needed, rates))
      return false;

   const double close_1 = rates[1].close;
   if(close_1 <= 0.0)
      return false;

   const double sma_fast = QM_SMA(_Symbol, tf, strategy_sma_fast_period, 1);
   const double sma_slow = QM_SMA(_Symbol, tf, strategy_sma_slow_period, 1);
   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false;

   const bool long_trend = (sma_fast > sma_slow && close_1 > sma_fast);
   const bool short_trend = (sma_fast < sma_slow && close_1 < sma_fast);

   const bool long_extreme = (g_vwap_rsi_2 < 35.0 && g_vwap_rsi_1 > g_vwap_rsi_2);
   const bool long_flip = (g_vwap_rsi_2 <= 50.0 && g_vwap_rsi_1 > 50.0);
   const bool long_reentry = Strategy_ShallowDipLong(rates);

   if(long_trend && (long_extreme || long_flip || long_reentry))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double stop_distance = Strategy_StopDistance(entry);
      if(entry <= 0.0 || stop_distance <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = entry;
      req.sl = Strategy_NormalizePrice(entry - stop_distance);
      req.tp = 0.0;
      req.reason = "TV_VWAP_RSI_MOMO_LONG";
      return (req.sl > 0.0 && req.sl < entry);
     }

   const bool short_extreme = (g_vwap_rsi_2 > 65.0 && g_vwap_rsi_1 < g_vwap_rsi_2);
   const bool short_flip = (g_vwap_rsi_2 >= 50.0 && g_vwap_rsi_1 < 50.0);
   const bool short_reentry = Strategy_ShallowDipShort(rates);

   if(short_trend && (short_extreme || short_flip || short_reentry))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double stop_distance = Strategy_StopDistance(entry);
      if(entry <= 0.0 || stop_distance <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = entry;
      req.sl = Strategy_NormalizePrice(entry + stop_distance);
      req.tp = 0.0;
      req.reason = "TV_VWAP_RSI_MOMO_SHORT";
      return (req.sl > entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no breakeven move, trailing stop, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int period_seconds = PeriodSeconds(Strategy_TF());

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
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);

      if(g_signal_bar_time > 0 && g_vwap_rsi_1 > 0.0 && g_vwap_rsi_2 > 0.0)
        {
         if(is_buy && g_vwap_rsi_2 >= 65.0 && g_vwap_rsi_1 < g_vwap_rsi_2)
            return true;
         if(!is_buy && g_vwap_rsi_2 <= 35.0 && g_vwap_rsi_1 > g_vwap_rsi_2)
            return true;
        }

      if(strategy_time_stop_bars > 0 && period_seconds > 0)
        {
         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(open_time > 0 && TimeCurrent() - open_time >= strategy_time_stop_bars * period_seconds)
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
