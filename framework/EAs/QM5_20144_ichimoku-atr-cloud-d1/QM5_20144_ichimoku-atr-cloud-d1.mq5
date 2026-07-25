#property strict
#property version   "5.0"
#property description "QM5_20144 ichimoku-atr-cloud-d1 (V5)"

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
input int    qm_ea_id                   = 9999;
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
input int    strategy_tenkan         = 9;
input int    strategy_kijun          = 26;
input int    strategy_senkou_b       = 65;
input int    strategy_atr_period     = 20;
input double strategy_atr_cloud_mult = 1.0;

int      g_str118_ichimoku_handle = INVALID_HANDLE;
int      g_str118_atr_handle = INVALID_HANDLE;
datetime g_str118_last_entry_bar = 0;
datetime g_str118_last_manage_bar = 0;
datetime g_str118_last_exit_attempt_bar = 0;
datetime g_str118_last_data_log_bar = 0;
ulong    g_str118_managed_position_id = 0;
int      g_str118_managed_direction = 0;
bool     g_str118_exit_required = false;
bool     g_str118_long_locked = false;
bool     g_str118_short_locked = false;
bool     g_str118_long_reset_seen = false;
bool     g_str118_short_reset_seen = false;

struct STR118_SNAPSHOT
  {
   datetime bar_time;
   double   close;
   double   tenkan;
   double   kijun;
   double   span_a;
   double   span_b;
   double   cloud_top;
   double   cloud_bottom;
   double   atr;
   bool     long_state;
   bool     short_state;
  };

bool Strategy118_ConfigValid()
  {
   const bool senkou_variant =
      (strategy_senkou_b == 52 ||
       strategy_senkou_b == 65 ||
       strategy_senkou_b == 100);
   return (strategy_tenkan == 9 &&
           strategy_kijun == 26 &&
           senkou_variant &&
           strategy_atr_period == 20 &&
           MathIsValidNumber(strategy_atr_cloud_mult) &&
           MathAbs(strategy_atr_cloud_mult - 1.0) < 1e-9);
  }

bool Strategy118_EnsureHandles()
  {
   if(g_str118_ichimoku_handle == INVALID_HANDLE)
     {
      const string key =
         StringFormat("STR118_ICHI|%s|%d|%d|%d|%d",
                      _Symbol,
                      (int)PERIOD_D1,
                      strategy_tenkan,
                      strategy_kijun,
                      strategy_senkou_b);
      g_str118_ichimoku_handle =
         QM_IndicatorsLookup(key);
      if(g_str118_ichimoku_handle == INVALID_HANDLE)
        {
         const int raw_handle =
            iIchimoku(_Symbol, PERIOD_D1, strategy_tenkan, strategy_kijun, strategy_senkou_b); // perf-allowed: native displaced Senkou buffers are required by the final spec; handle is registered in the framework pool, never lazy-created per tick
         g_str118_ichimoku_handle =
            QM_IndicatorsRegister(key,
                                  raw_handle);
        }
     }
   if(g_str118_atr_handle == INVALID_HANDLE)
      g_str118_atr_handle =
         QM_IndATR(_Symbol,
                   PERIOD_D1,
                   strategy_atr_period);
   return (g_str118_ichimoku_handle != INVALID_HANDLE &&
           g_str118_atr_handle != INVALID_HANDLE);
  }

int Strategy118_WarmupBars()
  {
   int required = 130;
   if(strategy_senkou_b +
      strategy_kijun + 5 > required)
      required =
         strategy_senkou_b +
         strategy_kijun + 5;
   return required;
  }

bool Strategy118_HandlesReady()
  {
   if(!Strategy118_EnsureHandles())
      return false;
   const int required = Strategy118_WarmupBars();
   return (BarsCalculated(g_str118_ichimoku_handle) >=
              required &&
           BarsCalculated(g_str118_atr_handle) >=
              required);
  }

bool Strategy118_CurrentD1Bar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_D1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-D1 clock for strategy-owned entry/exit/re-arm guards
   return (bar_time > 0);
  }

void Strategy118_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str118_last_data_log_bar)
      return;
   g_str118_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-118\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

bool Strategy118_ManualMidpoint(const int period,
                                const int ending_shift,
                                double &midpoint)
  {
   midpoint = 0.0;
   if(period <= 0 ||
      ending_shift < 1)
      return false;

   double highs[];
   double lows[];
   ArrayResize(highs, period);
   ArrayResize(lows, period);
   if(CopyHigh(_Symbol, PERIOD_D1, ending_shift, period, highs) != period) // perf-allowed: bounded OnInit-only causal Ichimoku self-test window
      return false;
   if(CopyLow(_Symbol, PERIOD_D1, ending_shift, period, lows) != period) // perf-allowed: bounded OnInit-only causal Ichimoku self-test window
      return false;

   double highest = highs[0];
   double lowest = lows[0];
   for(int i = 1; i < period; ++i)
     {
      if(highs[i] > highest)
         highest = highs[i];
      if(lows[i] < lowest)
         lowest = lows[i];
     }
   midpoint = (highest + lowest) * 0.5;
   return (MathIsValidNumber(midpoint) &&
           midpoint > 0.0);
  }

bool Strategy118_CloudSelfTest()
  {
   if(!Strategy118_HandlesReady())
      return false;

   // The cloud displayed on closed bar 1 was calculated kijun bars earlier:
   // source index = 1 + displacement = 27 for the 9/26/65 baseline.
   const int source_shift =
      1 + strategy_kijun;
   double native_a[1];
   double native_b[1];
   if(CopyBuffer(g_str118_ichimoku_handle, 2, source_shift, 1, native_a) != 1) // perf-allowed: one-value OnInit-only native Senkou-A displacement check
      return false;
   if(CopyBuffer(g_str118_ichimoku_handle, 3, source_shift, 1, native_b) != 1) // perf-allowed: one-value OnInit-only native Senkou-B displacement check
      return false;

   double manual_tenkan = 0.0;
   double manual_kijun = 0.0;
   double manual_b = 0.0;
   if(!Strategy118_ManualMidpoint(strategy_tenkan,
                                  source_shift,
                                  manual_tenkan) ||
      !Strategy118_ManualMidpoint(strategy_kijun,
                                  source_shift,
                                  manual_kijun) ||
      !Strategy118_ManualMidpoint(strategy_senkou_b,
                                  source_shift,
                                  manual_b))
      return false;
   const double manual_a =
      (manual_tenkan + manual_kijun) * 0.5;

   const double tick =
      MathMax(SymbolInfoDouble(_Symbol,
                               SYMBOL_TRADE_TICK_SIZE),
              SymbolInfoDouble(_Symbol,
                               SYMBOL_POINT));
   const double tolerance =
      MathMax(tick * 2.0,
              MathMax(MathAbs(manual_a),
                      MathAbs(manual_b)) * 1e-8);
   const bool pass =
      MathIsValidNumber(native_a[0]) &&
      MathIsValidNumber(native_b[0]) &&
      native_a[0] != EMPTY_VALUE &&
      native_b[0] != EMPTY_VALUE &&
      MathAbs(native_a[0] - manual_a) <= tolerance &&
      MathAbs(native_b[0] - manual_b) <= tolerance;
   if(!pass)
      QM_LogEvent(
         QM_ERROR,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-118\",\"reason\":\"ichimoku_causal_self_test\",\"source_shift\":%d,\"native_a\":%.10f,\"manual_a\":%.10f,\"native_b\":%.10f,\"manual_b\":%.10f,\"tolerance\":%.10f}",
            source_shift,
            native_a[0],
            manual_a,
            native_b[0],
            manual_b,
            tolerance));
   return pass;
  }

bool Strategy118_Init()
  {
   if(_Period != PERIOD_D1 ||
      !Strategy118_ConfigValid() ||
      !Strategy118_HandlesReady())
      return false;
   return Strategy118_CloudSelfTest();
  }

bool Strategy118_ReadLine(const int buffer,
                          const int shift,
                          double &value)
  {
   value = 0.0;
   if(buffer < 0 ||
      shift < 1 ||
      !Strategy118_HandlesReady())
      return false;
   value =
      QM_IndicatorReadBuffer(
         g_str118_ichimoku_handle,
         buffer,
         shift); // perf-allowed: pooled one-value native Ichimoku read at a closed causal shift
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE &&
           value > 0.0);
  }

bool Strategy118_ReadSnapshot(const int display_shift,
                              STR118_SNAPSHOT &snapshot)
  {
   ZeroMemory(snapshot);
   if(display_shift < 1 ||
      !Strategy118_HandlesReady())
      return false;

   MqlRates bar;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_D1,
                  display_shift,
                  bar)) // perf-allowed: one closed D1 record, bounded once per forming D1 bar
      return false;

   const int cloud_source_shift =
      display_shift + strategy_kijun;
   double tenkan = 0.0;
   double kijun = 0.0;
   double span_a = 0.0;
   double span_b = 0.0;
   if(!Strategy118_ReadLine(0,
                            display_shift,
                            tenkan) ||
      !Strategy118_ReadLine(1,
                            display_shift,
                            kijun) ||
      !Strategy118_ReadLine(2,
                            cloud_source_shift,
                            span_a) ||
      !Strategy118_ReadLine(3,
                            cloud_source_shift,
                            span_b))
      return false;

   const double atr =
      QM_IndicatorReadBuffer(
         g_str118_atr_handle,
         0,
         display_shift); // perf-allowed: pooled one-value Wilder ATR20 read at a closed D1 shift
   if(!MathIsValidNumber(atr) ||
      atr == EMPTY_VALUE ||
      atr <= 0.0 ||
      !MathIsValidNumber(bar.close) ||
      bar.close <= 0.0)
      return false;

   snapshot.bar_time = bar.time;
   snapshot.close = bar.close;
   snapshot.tenkan = tenkan;
   snapshot.kijun = kijun;
   snapshot.span_a = span_a;
   snapshot.span_b = span_b;
   snapshot.cloud_top = MathMax(span_a,
                                span_b);
   snapshot.cloud_bottom = MathMin(span_a,
                                   span_b);
   snapshot.atr = atr;
   snapshot.long_state =
      (tenkan > kijun &&
       bar.close >
          snapshot.cloud_top +
          strategy_atr_cloud_mult * atr);
   snapshot.short_state =
      (tenkan < kijun &&
       bar.close <
          snapshot.cloud_bottom -
          strategy_atr_cloud_mult * atr);
   return (snapshot.cloud_top >
              snapshot.cloud_bottom &&
           snapshot.cloud_bottom > 0.0);
  }

bool Strategy118_FindOwnPosition(ulong &ticket,
                                 ENUM_POSITION_TYPE &position_type,
                                 ulong &position_id)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   position_id = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate =
         PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) !=
            magic ||
         PositionGetString(POSITION_SYMBOL) !=
            _Symbol)
         continue;
      ticket = candidate;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(
            POSITION_TYPE);
      position_id =
         (ulong)PositionGetInteger(
            POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

bool Strategy118_HasOwnPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   ulong position_id = 0;
   return Strategy118_FindOwnPosition(ticket,
                                      position_type,
                                      position_id);
  }

bool Strategy118_ClosedByProtectiveStop(const ulong position_id)
  {
   if(position_id == 0 ||
      !HistorySelectByPosition(position_id))
      return false;
   const int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; --i)
     {
      const ulong deal_ticket =
         HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(
            deal_ticket,
            DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY)
         continue;
      const ENUM_DEAL_REASON reason =
         (ENUM_DEAL_REASON)HistoryDealGetInteger(
            deal_ticket,
            DEAL_REASON);
      if(reason == DEAL_REASON_SL)
         return true;
     }
   return false;
  }

void Strategy118_ObservePositionLifecycle(const bool has_position,
                                          const ENUM_POSITION_TYPE position_type,
                                          const ulong position_id)
  {
   if(has_position)
     {
      if(position_id != g_str118_managed_position_id)
        {
         g_str118_managed_position_id =
            position_id;
         g_str118_managed_direction =
            (position_type == POSITION_TYPE_BUY)
            ? 1
            : -1;
         g_str118_exit_required = false;
         g_str118_last_exit_attempt_bar = 0;
        }
      return;
     }

   if(g_str118_managed_position_id == 0)
      return;
   if(Strategy118_ClosedByProtectiveStop(
         g_str118_managed_position_id))
     {
      if(g_str118_managed_direction > 0)
        {
         g_str118_long_locked = true;
         g_str118_long_reset_seen = false;
        }
      else if(g_str118_managed_direction < 0)
        {
         g_str118_short_locked = true;
         g_str118_short_reset_seen = false;
        }
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_STATE",
         StringFormat(
            "{\"strategy\":\"STR-118\",\"event\":\"protective_stop_lock\",\"position_id\":%I64u,\"direction\":%d}",
            g_str118_managed_position_id,
            g_str118_managed_direction));
     }
   g_str118_managed_position_id = 0;
   g_str118_managed_direction = 0;
   g_str118_exit_required = false;
   g_str118_last_exit_attempt_bar = 0;
  }

void Strategy118_UpdateRearmLocks(const bool long_state,
                                  const bool short_state)
  {
   if(g_str118_long_locked)
     {
      if(!long_state)
         g_str118_long_reset_seen = true;
      else if(g_str118_long_reset_seen)
        {
         g_str118_long_locked = false;
         g_str118_long_reset_seen = false;
        }
     }
   if(g_str118_short_locked)
     {
      if(!short_state)
         g_str118_short_reset_seen = true;
      else if(g_str118_short_reset_seen)
        {
         g_str118_short_locked = false;
         g_str118_short_reset_seen = false;
        }
     }
  }

double Strategy118_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick =
         SymbolInfoDouble(_Symbol,
                          SYMBOL_POINT);
   return tick;
  }

double Strategy118_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy118_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol,
                               units * tick);
  }

bool Strategy118_StopGeometryLegal(const bool buy_side,
                                   const double entry,
                                   const double sl)
  {
   const double point =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_POINT);
   const double tick = Strategy118_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_FREEZE_LEVEL);
   const double minimum =
      MathMax(tick,
              (double)MathMax(stops_level,
                              freeze_level) * point);
   if(buy_side)
      return (sl < entry &&
              entry - sl + tick * 0.1 >= minimum);
   return (sl > entry &&
           sl - entry + tick * 0.1 >= minimum);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy118_HasOwnPosition())
      return false;
   if(_Period != PERIOD_D1 ||
      !Strategy118_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_D1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) D1 warmup gate
   if(bars_available < Strategy118_WarmupBars())
      return true;
   return !Strategy118_HandlesReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy118_CurrentD1Bar(forming_time))
     {
      Strategy118_LogDataMissing("forming_d1_bar", 0);
      return false;
     }
   if(forming_time == g_str118_last_entry_bar)
      return false;
   g_str118_last_entry_bar = forming_time;

   if(_Period != PERIOD_D1 ||
      !Strategy118_ConfigValid() ||
      Strategy118_HasOwnPosition() ||
      !Strategy118_HandlesReady())
      return false;

   STR118_SNAPSHOT signal;
   if(!Strategy118_ReadSnapshot(1,
                                signal))
     {
      Strategy118_LogDataMissing("entry_snapshot",
                                 forming_time);
      return false;
     }
   Strategy118_UpdateRearmLocks(signal.long_state,
                                signal.short_state);
   if(signal.long_state == signal.short_state)
      return false;

   const bool buy_side =
      signal.long_state;
   if((buy_side && g_str118_long_locked) ||
      (!buy_side && g_str118_short_locked))
      return false;

   const double entry =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl =
      Strategy118_AlignPrice(
         buy_side
         ? signal.cloud_top
         : signal.cloud_bottom,
         buy_side ? -1 : 1);
   if(!Strategy118_StopGeometryLegal(
         buy_side,
         entry,
         sl))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-118\",\"reason\":\"gap_invalid_frozen_cloud_stop\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"cloud_top\":%.8f,\"cloud_bottom\":%.8f}",
            (long)signal.bar_time,
            entry,
            sl,
            signal.cloud_top,
            signal.cloud_bottom));
      return false;
     }

   req.type = buy_side ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason =
      buy_side
      ? "STR118_ATR_CLOUD_LONG"
      : "STR118_ATR_CLOUD_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   datetime forming_time = 0;
   if(!Strategy118_CurrentD1Bar(forming_time))
     {
      Strategy118_LogDataMissing("forming_d1_bar", 0);
      return;
     }

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   ulong position_id = 0;
   const bool has_position =
      Strategy118_FindOwnPosition(ticket,
                                  position_type,
                                  position_id);
   if(has_position)
      Strategy118_ObservePositionLifecycle(
         true,
         position_type,
         position_id);

   if(forming_time == g_str118_last_manage_bar)
      return;
   g_str118_last_manage_bar = forming_time;

   if(!has_position)
      Strategy118_ObservePositionLifecycle(
         false,
         POSITION_TYPE_BUY,
         0);

   STR118_SNAPSHOT current;
   if(!Strategy118_ReadSnapshot(1,
                                current))
     {
      Strategy118_LogDataMissing("manage_snapshot",
                                 forming_time);
      return;
     }
   Strategy118_UpdateRearmLocks(current.long_state,
                                current.short_state);

   if(!has_position)
      return;

   double previous_tenkan = 0.0;
   double previous_kijun = 0.0;
   if(!Strategy118_ReadLine(0,
                            2,
                            previous_tenkan) ||
      !Strategy118_ReadLine(1,
                            2,
                            previous_kijun))
     {
      Strategy118_LogDataMissing("exit_cross_values",
                                 forming_time);
      return;
     }

   const bool opposite_cross =
      (position_type == POSITION_TYPE_BUY)
      ? (previous_tenkan >= previous_kijun &&
         current.tenkan < current.kijun)
      : (previous_tenkan <= previous_kijun &&
         current.tenkan > current.kijun);
   if(opposite_cross)
      g_str118_exit_required = true;

   if(!g_str118_exit_required ||
      forming_time ==
         g_str118_last_exit_attempt_bar)
      return;
   g_str118_last_exit_attempt_bar =
      forming_time;
   if(QM_TM_ClosePosition(ticket,
                          QM_EXIT_STRATEGY))
      g_str118_exit_required = false;
   // Rejections retain exit_required and retry once on the next D1 bar.
  }

bool Strategy_ExitSignal()
  {
   return false; // Manage owns the single-path opposite-cross close
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // current two-axis framework gate is authoritative
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

   if(!Strategy118_Init())
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

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
