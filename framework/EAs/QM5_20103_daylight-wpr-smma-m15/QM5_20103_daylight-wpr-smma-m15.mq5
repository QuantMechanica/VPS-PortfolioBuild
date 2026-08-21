#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 20103;
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
input int strategy_ma_period = 5;
input int strategy_ma_displacement = 5;
input int strategy_wpr_period = 14;
input int strategy_sub_fast_period = 8;
input int strategy_sub_slow_period = 21;
input double strategy_sub_daylight_min = 4.0;
input int strategy_atr_period = 14;
input double strategy_emergency_atr_mult = 4.0;
input int strategy_smma_seed_depth = 400;

int g_str004_h_ma = INVALID_HANDLE;
int g_str004_h_wpr = INVALID_HANDLE;
int g_str004_h_atr = INVALID_HANDLE;
datetime g_str004_last_entry_bar = 0;
datetime g_str004_last_exit_eval_bar = 0;
datetime g_str004_last_exit_action_bar = 0;
datetime g_str004_last_data_log_bar = 0;
datetime g_str004_sub_cache_bar = 0;
bool g_str004_sub_cache_valid = false;
double g_str004_sub_fast_1 = 0.0;
double g_str004_sub_fast_2 = 0.0;
double g_str004_sub_slow_1 = 0.0;
double g_str004_sub_slow_2 = 0.0;

bool Strategy004_EnsureHandles()
  {
   if(g_str004_h_ma == INVALID_HANDLE)
      g_str004_h_ma = QM_IndMA(_Symbol,
                               PERIOD_M15,
                               strategy_ma_period,
                               MODE_SMMA,
                               PRICE_CLOSE);
   if(g_str004_h_wpr == INVALID_HANDLE)
      g_str004_h_wpr =
         QM_IndWPR(_Symbol, PERIOD_M15, strategy_wpr_period);
   if(g_str004_h_atr == INVALID_HANDLE)
      g_str004_h_atr =
         QM_IndATR(_Symbol, PERIOD_M15, strategy_atr_period);
   return (g_str004_h_ma != INVALID_HANDLE &&
           g_str004_h_wpr != INVALID_HANDLE &&
           g_str004_h_atr != INVALID_HANDLE);
  }

bool Strategy004_CurrentBarTime(datetime &bar_time)
  {
   bar_time = 0;
   MqlRates forming_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_M15, 0, forming_bar))
      return false;
   bar_time = forming_bar.time;
   return (bar_time > 0);
  }

void Strategy004_LogDataMissing(const string component)
  {
   datetime bar_time = 0;
   Strategy004_CurrentBarTime(bar_time);
   if(bar_time > 0 && bar_time == g_str004_last_data_log_bar)
      return;
   g_str004_last_data_log_bar = bar_time;
   QM_LogEvent(QM_WARN,
               SETUP_DATA_MISSING,
               StringFormat("{\"strategy\":\"STR-004\",\"component\":\"%s\",\"bar_time\":%I64d}",
                            QM_LoggerEscapeJson(component),
                            (long)bar_time));
  }

double Strategy004_TradeTick()
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

bool Strategy004_HasOwnPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy004_WprValueValid(const double value)
  {
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE &&
           value >= -100.000001 &&
           value <= 0.000001);
  }

bool Strategy004_SeedAverage(const double &wpr[],
                             const int period,
                             const int seed_depth,
                             double &seed)
  {
   seed = 0.0;
   const int first_index = seed_depth - 1;
   const int last_index = first_index + period - 1;
   if(period <= 0 ||
      first_index < 0 ||
      last_index >= ArraySize(wpr))
      return false;
   for(int i = first_index; i <= last_index; ++i)
     {
      if(!Strategy004_WprValueValid(wpr[i]))
         return false;
      seed += wpr[i];
     }
   seed /= (double)period;
   return MathIsValidNumber(seed);
  }

bool Strategy004_RecomputeSubCache()
  {
   datetime forming_time = 0;
   if(!Strategy004_CurrentBarTime(forming_time))
      return false;
   if(forming_time == g_str004_sub_cache_bar)
      return g_str004_sub_cache_valid;
   g_str004_sub_cache_bar = forming_time;
   g_str004_sub_cache_valid = false;

   if(!Strategy004_EnsureHandles())
      return false;
   const int value_count =
      strategy_smma_seed_depth + strategy_sub_slow_period - 1;
   if(value_count <= 0)
      return false;
   double wpr[];
   if(ArrayResize(wpr, value_count) != value_count)
      return false;
   // Bounded O(seed_depth) work once per newly closed M15 bar. The framework
   // reader owns CopyBuffer, preserving the indicator-pool/build corset.
   int non_zero_values = 0;
   for(int closed_shift = 1;
       closed_shift <= value_count;
       ++closed_shift)
     {
      const double value =
         QM_IndicatorReadBuffer(g_str004_h_wpr, 0, closed_shift);
      if(!Strategy004_WprValueValid(value))
         return false;
      wpr[closed_shift - 1] = value;
      if(MathAbs(value) > 1e-12)
         non_zero_values++;
     }
   if(non_zero_values == 0)
      return false;

   double fast = 0.0;
   double slow = 0.0;
   if(!Strategy004_SeedAverage(wpr,
                               strategy_sub_fast_period,
                               strategy_smma_seed_depth,
                               fast) ||
      !Strategy004_SeedAverage(wpr,
                               strategy_sub_slow_period,
                               strategy_smma_seed_depth,
                               slow))
      return false;

   double fast_1 = 0.0;
   double fast_2 = 0.0;
   double slow_1 = 0.0;
   double slow_2 = 0.0;
   for(int closed_shift = strategy_smma_seed_depth - 1;
       closed_shift >= 1;
       --closed_shift)
     {
      const double value = wpr[closed_shift - 1];
      if(!Strategy004_WprValueValid(value))
         return false;
      fast =
         (fast * (strategy_sub_fast_period - 1) + value) /
         (double)strategy_sub_fast_period;
      slow =
         (slow * (strategy_sub_slow_period - 1) + value) /
         (double)strategy_sub_slow_period;
      if(closed_shift == 2)
        {
         fast_2 = fast;
         slow_2 = slow;
        }
      else if(closed_shift == 1)
        {
         fast_1 = fast;
         slow_1 = slow;
        }
     }
   if(!MathIsValidNumber(fast_1) ||
      !MathIsValidNumber(fast_2) ||
      !MathIsValidNumber(slow_1) ||
      !MathIsValidNumber(slow_2))
      return false;
   g_str004_sub_fast_1 = fast_1;
   g_str004_sub_fast_2 = fast_2;
   g_str004_sub_slow_1 = slow_1;
   g_str004_sub_slow_2 = slow_2;
   g_str004_sub_cache_valid = true;
   return true;
  }

double Strategy004_NormalizeStopAway(const QM_OrderType side,
                                     const double raw_price)
  {
   const double tick = Strategy004_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   const double aligned =
      QM_OrderTypeIsBuy(side)
      ? MathFloor(scaled + 1e-9) * tick
      : MathCeil(scaled - 1e-9) * tick;
   return QM_TM_NormalizePrice(_Symbol, aligned);
  }

double Strategy004_EmergencyStop(const QM_OrderType side,
                                 const double entry,
                                 const double atr)
  {
   double candidate =
      QM_StopATRFromValue(_Symbol,
                          side,
                          entry,
                          atr,
                          strategy_emergency_atr_mult);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy004_TradeTick();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(candidate <= 0.0 || point <= 0.0 || tick <= 0.0 ||
      bid <= 0.0 || ask <= 0.0)
      return 0.0;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum =
      MathMax(tick, (double)stops_level * point);

   // Clamp only away from the fill/market; never tighten the 4xATR distance.
   if(QM_OrderTypeIsBuy(side))
     {
      const double legal_max = bid - minimum;
      if(candidate > legal_max)
         candidate = legal_max;
     }
   else
     {
      const double legal_min = ask + minimum;
      if(candidate < legal_min)
         candidate = legal_min;
     }
   candidate = Strategy004_NormalizeStopAway(side, candidate);
   if(candidate <= 0.0 ||
      (QM_OrderTypeIsBuy(side) && candidate >= entry) ||
      (!QM_OrderTypeIsBuy(side) && candidate <= entry))
      return 0.0;
   return candidate;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15 ||
      strategy_ma_period <= 1 ||
      strategy_ma_displacement < 1 ||
      strategy_wpr_period <= 1 ||
      strategy_sub_fast_period <= 1 ||
      strategy_sub_slow_period <= strategy_sub_fast_period ||
      strategy_sub_daylight_min <= 0.0 ||
      strategy_atr_period <= 1 ||
      strategy_emergency_atr_mult <= 0.0 ||
      strategy_smma_seed_depth <
         strategy_sub_slow_period + 2)
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const int warmup_needed =
      strategy_smma_seed_depth +
      strategy_sub_slow_period + 30;
   const long bars_available =
      SeriesInfoInteger(_Symbol, PERIOD_M15, SERIES_BARS_COUNT);
   if(bars_available < warmup_needed)
      return true;
   if(!Strategy004_EnsureHandles())
      return true;
   if(!QM_IndicatorWarmupReady(g_str004_h_ma,
                               0,
                               1,
                               strategy_ma_period + strategy_ma_displacement + 5,
                               "STR-004_ma") ||
      !QM_IndicatorWarmupReady(g_str004_h_wpr,
                               0,
                               1,
                               warmup_needed,
                               "STR-004_wpr") ||
      !QM_IndicatorWarmupReady(g_str004_h_atr,
                               0,
                               1,
                               strategy_atr_period + 5,
                               "STR-004_atr"))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy004_CurrentBarTime(forming_time))
     {
      Strategy004_LogDataMissing("forming_bar");
      return false;
     }
   if(forming_time == g_str004_last_entry_bar)
      return false;
   g_str004_last_entry_bar = forming_time;
   if(forming_time == g_str004_last_exit_action_bar)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(Strategy004_HasOwnPosition(ticket, position_type))
      return false;
   if(!Strategy004_EnsureHandles())
     {
      Strategy004_LogDataMissing("indicator_handles");
      return false;
     }
   if(!Strategy004_RecomputeSubCache())
     {
      Strategy004_LogDataMissing("wpr_smma_cache");
      return false;
     }

   MqlRates bar1;
   MqlRates bar2;
   if(!QM_ReadBar(_Symbol, PERIOD_M15, 1, bar1) ||
      !QM_ReadBar(_Symbol, PERIOD_M15, 2, bar2))
     {
      Strategy004_LogDataMissing("signal_bars");
      return false;
     }
   const double green1 =
      QM_IndicatorReadBuffer(g_str004_h_ma, 0, 1);
   const double red1 =
      QM_IndicatorReadBuffer(g_str004_h_ma,
                             0,
                             1 + strategy_ma_displacement);
   const double green2 =
      QM_IndicatorReadBuffer(g_str004_h_ma, 0, 2);
   const double red2 =
      QM_IndicatorReadBuffer(g_str004_h_ma,
                             0,
                             2 + strategy_ma_displacement);
   const double atr1 =
      QM_IndicatorReadBuffer(g_str004_h_atr, 0, 1);
   const double tick = Strategy004_TradeTick();
   if(green1 <= 0.0 || red1 <= 0.0 ||
      green2 <= 0.0 || red2 <= 0.0 ||
      atr1 <= 0.0 || tick <= 0.0)
     {
      Strategy004_LogDataMissing("indicator_buffers");
      return false;
     }

   const bool long_now =
      green1 - red1 >= tick &&
      bar1.close > green1 &&
      g_str004_sub_slow_1 - g_str004_sub_fast_1 >=
         strategy_sub_daylight_min;
   const bool short_now =
      red1 - green1 >= tick &&
      bar1.close < green1 &&
      g_str004_sub_fast_1 - g_str004_sub_slow_1 >=
         strategy_sub_daylight_min;
   const bool long_before =
      green2 - red2 >= tick &&
      bar2.close > green2 &&
      g_str004_sub_slow_2 - g_str004_sub_fast_2 >=
         strategy_sub_daylight_min;
   const bool short_before =
      red2 - green2 >= tick &&
      bar2.close < green2 &&
      g_str004_sub_fast_2 - g_str004_sub_slow_2 >=
         strategy_sub_daylight_min;
   const bool long_signal = long_now && !long_before;
   const bool short_signal = short_now && !short_before;
   if(!long_signal && !short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry =
      long_signal
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
     {
      Strategy004_LogDataMissing("market_price");
      return false;
     }
   const double sl =
      Strategy004_EmergencyStop(req.type, entry, atr1);
   if(sl <= 0.0)
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-004\",\"reason\":\"emergency_stop\",\"dir\":\"%s\",\"entry\":%.8f,\"atr\":%.8f}",
            long_signal ? "LONG" : "SHORT",
            entry,
            atr1));
      return false;
     }

   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason =
      long_signal ? "STR004_DAYLIGHT_LONG" : "STR004_DAYLIGHT_SHORT";
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-004\",\"dir\":\"%s\",\"close\":%.8f,\"green\":%.8f,\"red\":%.8f,\"sub_fast\":%.8f,\"sub_slow\":%.8f,\"atr\":%.8f,\"sl\":%.8f}",
         long_signal ? "LONG" : "SHORT",
         bar1.close,
         green1,
         red1,
         g_str004_sub_fast_1,
         g_str004_sub_slow_1,
         atr1,
         sl));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Emergency SL is server-side and never moved; no TP or trailing.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy004_HasOwnPosition(ticket, position_type))
      return false;

   datetime forming_time = 0;
   if(!Strategy004_CurrentBarTime(forming_time))
     {
      Strategy004_LogDataMissing("exit_bar");
      return false;
     }
   if(forming_time == g_str004_last_exit_eval_bar)
      return false;
   g_str004_last_exit_eval_bar = forming_time;
   if(!Strategy004_EnsureHandles())
     {
      Strategy004_LogDataMissing("exit_ma_handle");
      return false;
     }
   const double green1 =
      QM_IndicatorReadBuffer(g_str004_h_ma, 0, 1);
   const double red1 =
      QM_IndicatorReadBuffer(g_str004_h_ma,
                             0,
                             1 + strategy_ma_displacement);
   if(green1 <= 0.0 || red1 <= 0.0)
     {
      Strategy004_LogDataMissing("exit_ma_buffer");
      return false;
     }
   const bool recross =
      (position_type == POSITION_TYPE_BUY && red1 >= green1) ||
      (position_type == POSITION_TYPE_SELL && green1 >= red1);
   if(!recross)
      return false;

   g_str004_last_exit_action_bar = forming_time;
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_EXIT",
      StringFormat(
         "{\"strategy\":\"STR-004\",\"ticket\":%I64u,\"reason\":\"ma_recross\",\"green\":%.8f,\"red\":%.8f}",
         ticket,
         green1,
         red1));
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

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
