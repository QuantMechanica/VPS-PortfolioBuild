#property strict
#property version   "5.0"
#property description "QM5_20142 mtf-ema25-align-h4 (V5)"

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
input int    strategy_ema_period    = 25;
input int    strategy_atr_period    = 14;
input int    strategy_confirm_bars = 1;
input double strategy_sl_atr       = 2.0;
input double strategy_tp_atr       = 3.0;

#define STR088_TF_COUNT 4

ENUM_TIMEFRAMES g_str088_timeframes[STR088_TF_COUNT] =
  {
   PERIOD_M15,
   PERIOD_H1,
   PERIOD_H4,
   PERIOD_D1
  };
int g_str088_ema_handles[STR088_TF_COUNT] =
  {
   INVALID_HANDLE,
   INVALID_HANDLE,
   INVALID_HANDLE,
   INVALID_HANDLE
  };
int      g_str088_atr_handle = INVALID_HANDLE;
datetime g_str088_last_entry_bar = 0;
datetime g_str088_last_data_log_bar = 0;

bool Strategy088_ConfigValid()
  {
   return (strategy_ema_period > 1 &&
           strategy_atr_period > 1 &&
           strategy_confirm_bars >= 1 &&
           strategy_confirm_bars <= 3 &&
           MathIsValidNumber(strategy_sl_atr) &&
           strategy_sl_atr > 0.0 &&
           MathIsValidNumber(strategy_tp_atr) &&
           (MathAbs(strategy_tp_atr - 3.0) < 1e-9 ||
            MathAbs(strategy_tp_atr - 4.0) < 1e-9));
  }

bool Strategy088_EnsureHandles()
  {
   for(int i = 0; i < STR088_TF_COUNT; ++i)
     {
      if(g_str088_ema_handles[i] == INVALID_HANDLE)
         g_str088_ema_handles[i] =
            QM_IndMA(_Symbol,
                     g_str088_timeframes[i],
                     strategy_ema_period,
                     MODE_EMA,
                     PRICE_CLOSE);
      if(g_str088_ema_handles[i] == INVALID_HANDLE)
         return false;
     }
   if(g_str088_atr_handle == INVALID_HANDLE)
      g_str088_atr_handle =
         QM_IndATR(_Symbol,
                   PERIOD_H4,
                   strategy_atr_period);
   return (g_str088_atr_handle != INVALID_HANDLE);
  }

int Strategy088_WarmupBars()
  {
   int required = 50;
   if(strategy_ema_period +
      strategy_confirm_bars + 5 > required)
      required =
         strategy_ema_period +
         strategy_confirm_bars + 5;
   if(strategy_atr_period + 5 > required)
      required = strategy_atr_period + 5;
   return required;
  }

bool Strategy088_HandlesReady()
  {
   if(!Strategy088_EnsureHandles())
      return false;
   const int required = Strategy088_WarmupBars();
   for(int i = 0; i < STR088_TF_COUNT; ++i)
      if(!QM_IndicatorWarmupReady(g_str088_ema_handles[i],
                                  0,
                                  1,
                                  required,
                                  "STR-088_ema_" + IntegerToString(i)))
         return false;
   return QM_IndicatorWarmupReady(g_str088_atr_handle,
                                  0,
                                  1,
                                  required,
                                  "STR-088_atr");
  }

bool Strategy088_CurrentH4Bar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H4,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-H4 clock for the strategy-owned once-per-bar guard
   return (bar_time > 0);
  }

void Strategy088_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str088_last_data_log_bar)
      return;
   g_str088_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-088\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

bool Strategy088_HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) ==
            magic &&
         PositionGetString(POSITION_SYMBOL) ==
            _Symbol)
         return true;
     }
   return false;
  }

double Strategy088_TradeTick()
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

double Strategy088_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy088_TradeTick();
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

bool Strategy088_EntryGeometryLegal(
   const bool buy_side,
   const double entry,
   const double sl,
   const double tp)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy088_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level)
      ? stops_level
      : freeze_level;
   const double minimum =
      MathMax(tick,
              (double)broker_level * point);
   if(buy_side)
      return (sl < entry &&
              tp > entry &&
              entry - sl + tick * 0.1 >= minimum &&
              tp - entry + tick * 0.1 >= minimum);
   return (sl > entry &&
           tp < entry &&
           sl - entry + tick * 0.1 >= minimum &&
           entry - tp + tick * 0.1 >= minimum);
  }

datetime Strategy088_LastSundayUTC(
   const int year,
   const int month,
   const int hour_utc)
  {
   MqlDateTime next_month;
   ZeroMemory(next_month);
   next_month.year = year;
   next_month.mon = month + 1;
   next_month.day = 1;
   if(next_month.mon > 12)
     {
      next_month.mon = 1;
      next_month.year++;
     }
   datetime last_day =
      StructToTime(next_month) - 86400;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(last_day <= 0 ||
      !TimeToStruct(last_day, parts))
      return 0;
   last_day -= parts.day_of_week * 86400;
   return last_day + hour_utc * 3600;
  }

int Strategy088_LondonOffsetSecondsUTC(
   const datetime utc)
  {
   if(utc <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(utc, parts))
      return 0;
   const datetime summer_start =
      Strategy088_LastSundayUTC(parts.year, 3, 1);
   const datetime summer_end =
      Strategy088_LastSundayUTC(parts.year, 10, 1);
   if(summer_start > 0 &&
      summer_end > summer_start &&
      utc >= summer_start &&
      utc < summer_end)
      return 3600;
   return 0;
  }

bool Strategy088_EntrySessionOpen(
   const datetime broker_time)
  {
   const datetime utc =
      QM_BrokerToUTC(broker_time);
   if(utc <= 0)
      return false;
   const datetime london_civil =
      utc +
      Strategy088_LondonOffsetSecondsUTC(utc);
   const datetime new_york_civil =
      utc +
      (QM_IsUSDSTUTC(utc) ? -4 : -5) * 3600;

   MqlDateTime london;
   MqlDateTime new_york;
   ZeroMemory(london);
   ZeroMemory(new_york);
   if(!TimeToStruct(london_civil, london) ||
      !TimeToStruct(new_york_civil, new_york))
      return false;
   if(london.day_of_week < 1 ||
      london.day_of_week > 5 ||
      new_york.day_of_week < 1 ||
      new_york.day_of_week > 5)
      return false;
   const bool after_london_open =
      (london.hour >= 8);
   const bool before_new_york_close =
      (new_york.hour < 17);
   return (after_london_open &&
           before_new_york_close);
  }

bool Strategy088_ReadAlignment(
   const datetime forming_time,
   bool &long_signal,
   bool &short_signal)
  {
   long_signal = true;
   short_signal = true;
   for(int tf_index = 0;
       tf_index < STR088_TF_COUNT;
       ++tf_index)
     {
      for(int shift = 1;
          shift <= strategy_confirm_bars;
          ++shift)
        {
         MqlRates bar;
         if(!QM_ReadBar(_Symbol,
                        g_str088_timeframes[tf_index],
                        shift,
                        bar)) // perf-allowed: bounded 4xN closed-bar read, shifts 1..3, once per forming H4 bar
           {
            Strategy088_LogDataMissing(
               "mtf_closed_bar",
               forming_time);
            return false;
           }
         const double ema =
            QM_IndicatorReadBuffer(
               g_str088_ema_handles[tf_index],
               0,
               shift); // perf-allowed: pooled one-value EMA read, closed shift 1..3, bounded once per forming H4 bar
         if(!MathIsValidNumber(ema) ||
            ema == EMPTY_VALUE || ema <= 0.0 ||
            !MathIsValidNumber(bar.close) ||
            bar.close <= 0.0)
           {
            Strategy088_LogDataMissing(
               "mtf_ema_value",
               forming_time);
            return false;
           }
         if(bar.close <= ema)
            long_signal = false;
         if(bar.close >= ema)
            short_signal = false;
        }
     }
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy088_HasOwnPosition())
      return false;
   if(_Period != PERIOD_H4 ||
      !Strategy088_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long d1_bars =
      SeriesInfoInteger(_Symbol,
                        PERIOD_D1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) slowest-timeframe warmup gate
   if(d1_bars < Strategy088_WarmupBars())
      return true;
   if(!Strategy088_HandlesReady())
      return true;
   return !Strategy088_EntrySessionOpen(TimeCurrent());
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy088_CurrentH4Bar(forming_time))
     {
      Strategy088_LogDataMissing("forming_h4_bar", 0);
      return false;
     }
   if(forming_time == g_str088_last_entry_bar)
      return false;
   g_str088_last_entry_bar = forming_time;

   if(_Period != PERIOD_H4 ||
      !Strategy088_ConfigValid() ||
      Strategy088_HasOwnPosition() ||
      !Strategy088_HandlesReady() ||
      !Strategy088_EntrySessionOpen(TimeCurrent()))
      return false;

   bool long_signal = false;
   bool short_signal = false;
   if(!Strategy088_ReadAlignment(forming_time,
                                 long_signal,
                                 short_signal) ||
      long_signal == short_signal)
      return false;

   const double atr =
      QM_IndicatorReadBuffer(g_str088_atr_handle,
                             0,
                             1); // perf-allowed: pooled one-value ATR14 read from the just-closed H4 bar
   if(!MathIsValidNumber(atr) ||
      atr == EMPTY_VALUE || atr <= 0.0)
     {
      Strategy088_LogDataMissing("closed_h4_atr",
                                 forming_time);
      return false;
     }

   const bool buy_side = long_signal;
   const double entry =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl =
      Strategy088_AlignPrice(
         buy_side
         ? entry - strategy_sl_atr * atr
         : entry + strategy_sl_atr * atr,
         buy_side ? -1 : 1);
   const double tp =
      Strategy088_AlignPrice(
         buy_side
         ? entry + strategy_tp_atr * atr
         : entry - strategy_tp_atr * atr,
         buy_side ? 1 : -1);
   if(!Strategy088_EntryGeometryLegal(buy_side,
                                      entry,
                                      sl,
                                      tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-088\",\"reason\":\"entry_geometry\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"atr\":%.8f}",
            (long)forming_time,
            entry,
            sl,
            tp,
            atr));
      return false;
     }

   req.type = buy_side ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      buy_side
      ? "STR088_MTF_EMA25_LONG"
      : "STR088_MTF_EMA25_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Fixed SL/TP only; no source-backed trailing or signal exit.
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // central two-axis fail-closed news gate is authoritative
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
