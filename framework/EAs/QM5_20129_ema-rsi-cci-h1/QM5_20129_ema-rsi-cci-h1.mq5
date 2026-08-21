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
input int    qm_ea_id                   = 20129;
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
input int    strategy_ema_fast   = 5;
input int    strategy_ema_slow   = 12;
input int    strategy_rsi_period = 21;
input int    strategy_cci_period = 80;
input double strategy_level      = 50.0;
input double strategy_sl_pips    = 50.0; // source range 35-60

int      g_str075_fast_handle = INVALID_HANDLE;
int      g_str075_slow_handle = INVALID_HANDLE;
int      g_str075_rsi_handle = INVALID_HANDLE;
int      g_str075_cci_handle = INVALID_HANDLE;
datetime g_str075_last_entry_bar = 0;
datetime g_str075_last_exit_eval_bar = 0;
datetime g_str075_last_exit_attempt_bar = 0;
datetime g_str075_last_data_log_bar = 0;
ulong    g_str075_exit_position_id = 0;
bool     g_str075_exit_latched = false;

bool Strategy075_ConfigValid()
  {
   return (strategy_ema_fast > 1 &&
           strategy_ema_slow > strategy_ema_fast &&
           strategy_rsi_period > 1 &&
           strategy_cci_period > 1 &&
           MathIsValidNumber(strategy_level) &&
           strategy_level > 0.0 &&
           strategy_level < 100.0 &&
           MathIsValidNumber(strategy_sl_pips) &&
           strategy_sl_pips >= 35.0 &&
           strategy_sl_pips <= 60.0);
  }

bool Strategy075_EnsureHandles()
  {
   if(g_str075_fast_handle == INVALID_HANDLE)
      g_str075_fast_handle =
         QM_IndMA(_Symbol,
                  PERIOD_H1,
                  strategy_ema_fast,
                  MODE_EMA,
                  PRICE_CLOSE);
   if(g_str075_slow_handle == INVALID_HANDLE)
      g_str075_slow_handle =
         QM_IndMA(_Symbol,
                  PERIOD_H1,
                  strategy_ema_slow,
                  MODE_EMA,
                  PRICE_CLOSE);
   if(g_str075_rsi_handle == INVALID_HANDLE)
      g_str075_rsi_handle =
         QM_IndRSI(_Symbol,
                   PERIOD_H1,
                   strategy_rsi_period,
                   PRICE_CLOSE);
   if(g_str075_cci_handle == INVALID_HANDLE)
      g_str075_cci_handle =
         QM_IndCCI(_Symbol,
                   PERIOD_H1,
                   strategy_cci_period,
                   PRICE_TYPICAL);
   return (g_str075_fast_handle != INVALID_HANDLE &&
           g_str075_slow_handle != INVALID_HANDLE &&
           g_str075_rsi_handle != INVALID_HANDLE &&
           g_str075_cci_handle != INVALID_HANDLE);
  }

int Strategy075_WarmupBars()
  {
   int required = 90;
   if(strategy_ema_slow + 10 > required)
      required = strategy_ema_slow + 10;
   if(strategy_rsi_period + 10 > required)
      required = strategy_rsi_period + 10;
   if(strategy_cci_period + 10 > required)
      required = strategy_cci_period + 10;
   return required;
  }

bool Strategy075_HandlesReady()
  {
   if(!Strategy075_EnsureHandles())
      return false;
   const int required = Strategy075_WarmupBars();
   return (QM_IndicatorWarmupReady(g_str075_fast_handle,
                                   0, 1, required, "STR-075_fast_ema") &&
           QM_IndicatorWarmupReady(g_str075_slow_handle,
                                   0, 1, required, "STR-075_slow_ema") &&
           QM_IndicatorWarmupReady(g_str075_rsi_handle,
                                   0, 1, required, "STR-075_rsi") &&
           QM_IndicatorWarmupReady(g_str075_cci_handle,
                                   0, 1, required, "STR-075_cci"));
  }

bool Strategy075_CurrentBar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-H1 clock for entry and exit guards
   return (bar_time > 0);
  }

void Strategy075_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str075_last_data_log_bar)
      return;
   g_str075_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-075\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

bool Strategy075_IndicatorValid(const double value)
  {
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE);
  }

bool Strategy075_ReadClosedValues(
   const int shift,
   double &fast,
   double &slow,
   double &rsi,
   double &cci)
  {
   fast =
      QM_IndicatorReadBuffer(g_str075_fast_handle,
                             0,
                             shift);
   slow =
      QM_IndicatorReadBuffer(g_str075_slow_handle,
                             0,
                             shift);
   rsi =
      QM_IndicatorReadBuffer(g_str075_rsi_handle,
                             0,
                             shift);
   cci =
      QM_IndicatorReadBuffer(g_str075_cci_handle,
                             0,
                             shift);
   return (Strategy075_IndicatorValid(fast) &&
           Strategy075_IndicatorValid(slow) &&
           Strategy075_IndicatorValid(rsi) &&
           Strategy075_IndicatorValid(cci) &&
           fast > 0.0 &&
           slow > 0.0 &&
           rsi >= 0.0 &&
           rsi <= 100.0);
  }

bool Strategy075_FindOwnPosition(
   ulong &ticket,
   ENUM_POSITION_TYPE &position_type,
   ulong &position_id)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   position_id = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
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

bool Strategy075_OpenedSince(const datetime since_time)
  {
   if(since_time <= 0)
      return true;
   if(!HistorySelect(since_time, TimeCurrent()))
     {
      Strategy075_LogDataMissing(
         "same_bar_entry_history",
         since_time);
      return true;
     }
   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (int)HistoryDealGetInteger(deal,
                                    DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal,
                              DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(
            deal,
            DEAL_ENTRY);
      if(entry_kind == DEAL_ENTRY_IN ||
         entry_kind == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

double Strategy075_PipSize()
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits =
      (int)SymbolInfoInteger(_Symbol,
                             SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return ((digits == 3 || digits == 5)
           ? 10.0 * point
           : point);
  }

double Strategy075_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol,
                              SYMBOL_POINT);
   return tick;
  }

double Strategy075_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy075_TradeTick();
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

bool Strategy075_EntryStopLegal(const QM_OrderType side,
                                const double sl)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy075_TradeTick();
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || tick <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      sl <= 0.0)
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
   if(side == QM_BUY)
      return (sl < bid &&
              bid - sl + tick * 0.1 >= minimum);
   if(side == QM_SELL)
      return (sl > ask &&
              sl - ask + tick * 0.1 >= minimum);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1 ||
      !Strategy075_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) closed-H1 warmup gate shared by both registered slots
   if(bars_available < Strategy075_WarmupBars())
      return true;
   return !Strategy075_HandlesReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy075_CurrentBar(forming_time))
     {
      Strategy075_LogDataMissing("forming_h1_time", 0);
      return false;
     }
   if(forming_time == g_str075_last_entry_bar)
      return false;
   if(!Strategy075_HandlesReady())
     {
      Strategy075_LogDataMissing("entry_indicator_warmup",
                                 forming_time);
      return false;
     }

   double fast1 = 0.0;
   double slow1 = 0.0;
   double rsi1 = 0.0;
   double cci1 = 0.0;
   double fast2 = 0.0;
   double slow2 = 0.0;
   double rsi2 = 0.0;
   double cci2 = 0.0;
   if(!Strategy075_ReadClosedValues(1,
                                    fast1,
                                    slow1,
                                    rsi1,
                                    cci1) ||
      !Strategy075_ReadClosedValues(2,
                                    fast2,
                                    slow2,
                                    rsi2,
                                    cci2))
     {
      Strategy075_LogDataMissing(
         "entry_closed_indicators",
         forming_time);
      return false;
     }
   g_str075_last_entry_bar = forming_time;

   const bool long_signal =
      (fast1 > slow1 &&
       fast2 <= slow2 &&
       rsi1 > strategy_level &&
       cci1 > strategy_level);
   const bool short_signal =
      (fast1 < slow1 &&
       fast2 >= slow2 &&
       rsi1 < strategy_level &&
       cci1 < strategy_level);
   if(!long_signal && !short_signal)
      return false;

   // A successful rule close earlier in this OnTick cannot become an
   // implicit same-evaluation reversal.
   if(g_str075_last_exit_attempt_bar == forming_time)
      return false;
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   ulong position_id = 0;
   if(Strategy075_FindOwnPosition(ticket,
                                  position_type,
                                  position_id) ||
      Strategy075_OpenedSince(forming_time))
      return false;

   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double pip = Strategy075_PipSize();
   if(bid <= 0.0 || ask <= 0.0 ||
      ask < bid || pip <= 0.0)
     {
      Strategy075_LogDataMissing("entry_quotes_or_pip",
                                 forming_time);
      return false;
     }
   const double entry =
      long_signal ? ask : bid;
   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl =
      Strategy075_AlignPrice(
         long_signal
         ? entry - strategy_sl_pips * pip
         : entry + strategy_sl_pips * pip,
         long_signal ? -1 : 1);
   req.tp = 0.0;
   if(!Strategy075_EntryStopLegal(req.type,
                                  req.sl))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-075\",\"reason\":\"fixed_stop_geometry\",\"dir\":\"%s\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"sl_pips\":%.2f}",
            QM_LoggerEscapeJson(
               long_signal ? "LONG" : "SHORT"),
            (long)forming_time,
            entry,
            req.sl,
            strategy_sl_pips));
      return false;
     }

   req.reason =
      StringFormat(long_signal
                   ? "STR075_L_S%d_%I64d"
                   : "STR075_S_S%d_%I64d",
                   qm_magic_slot_offset,
                   (long)forming_time);
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-075\",\"dir\":\"%s\",\"slot\":%d,\"symbol\":\"%s\",\"bar_time\":%I64d,\"ema_fast_1\":%.8f,\"ema_slow_1\":%.8f,\"ema_fast_2\":%.8f,\"ema_slow_2\":%.8f,\"rsi_1\":%.8f,\"cci_1\":%.8f,\"entry\":%.8f,\"sl\":%.8f}",
         QM_LoggerEscapeJson(
            long_signal ? "LONG" : "SHORT"),
         qm_magic_slot_offset,
         QM_LoggerEscapeJson(_Symbol),
         (long)forming_time,
         fast1,
         slow1,
         fast2,
         slow2,
         rsi1,
         cci1,
         entry,
         req.sl));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   datetime forming_time = 0;
   if(!Strategy075_CurrentBar(forming_time))
     {
      Strategy075_LogDataMissing("exit_h1_clock", 0);
      return false;
     }

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   ulong position_id = 0;
   if(!Strategy075_FindOwnPosition(ticket,
                                   position_type,
                                   position_id))
     {
      // Preserve the attempt marker through the EntrySignal call later in
      // the same canonical OnTick; clear it only on a later H1 bar.
      if(forming_time !=
         g_str075_last_exit_attempt_bar)
        {
         g_str075_exit_latched = false;
         g_str075_exit_position_id = 0;
         g_str075_last_exit_eval_bar = 0;
         g_str075_last_exit_attempt_bar = 0;
        }
      return false;
     }

   if(position_id != g_str075_exit_position_id)
     {
      g_str075_exit_position_id = position_id;
      g_str075_exit_latched = false;
      g_str075_last_exit_eval_bar = 0;
      g_str075_last_exit_attempt_bar = 0;
     }

   // A broker-rejected close remains latched, with at most one close request
   // per closed H1 evaluation.
   if(g_str075_exit_latched)
     {
      if(forming_time ==
         g_str075_last_exit_attempt_bar)
         return false;
      g_str075_last_exit_attempt_bar =
         forming_time;
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_EXIT",
         StringFormat(
            "{\"strategy\":\"STR-075\",\"ticket\":%I64u,\"slot\":%d,\"reason\":\"rule_exit_retry\",\"retry_bar\":%I64d}",
            ticket,
            qm_magic_slot_offset,
            (long)forming_time));
      return true;
     }

   if(forming_time ==
      g_str075_last_exit_eval_bar)
      return false;
   if(!Strategy075_HandlesReady())
     {
      Strategy075_LogDataMissing(
         "exit_indicator_warmup",
         forming_time);
      return false;
     }
   double fast1 = 0.0;
   double slow1 = 0.0;
   double rsi1 = 0.0;
   double cci1 = 0.0;
   if(!Strategy075_ReadClosedValues(1,
                                    fast1,
                                    slow1,
                                    rsi1,
                                    cci1))
     {
      Strategy075_LogDataMissing(
         "exit_closed_indicators",
         forming_time);
      return false;
     }
   g_str075_last_exit_eval_bar =
      forming_time;

   const bool exit_long =
      (position_type == POSITION_TYPE_BUY &&
       (fast1 < slow1 ||
        (rsi1 < strategy_level &&
         cci1 < strategy_level)));
   const bool exit_short =
      (position_type == POSITION_TYPE_SELL &&
       (fast1 > slow1 ||
        (rsi1 > strategy_level &&
         cci1 > strategy_level)));
   if(!exit_long && !exit_short)
      return false;

   const bool ema_rule =
      (position_type == POSITION_TYPE_BUY)
      ? (fast1 < slow1)
      : (fast1 > slow1);
   g_str075_exit_latched = true;
   g_str075_last_exit_attempt_bar =
      forming_time;
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_EXIT",
      StringFormat(
         "{\"strategy\":\"STR-075\",\"ticket\":%I64u,\"slot\":%d,\"symbol\":\"%s\",\"reason\":\"%s\",\"bar_time\":%I64d,\"ema_fast\":%.8f,\"ema_slow\":%.8f,\"rsi\":%.8f,\"cci\":%.8f}",
         ticket,
         qm_magic_slot_offset,
         QM_LoggerEscapeJson(_Symbol),
         QM_LoggerEscapeJson(
            ema_rule
            ? "ema_cross_back"
            : "dual_oscillator_against"),
         (long)forming_time,
         fast1,
         slow1,
         rsi1,
         cci1));
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
