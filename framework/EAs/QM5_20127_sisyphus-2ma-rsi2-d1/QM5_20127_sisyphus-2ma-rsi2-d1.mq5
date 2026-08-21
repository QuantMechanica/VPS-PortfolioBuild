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
input int    qm_ea_id                   = 20127;
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
input int    strategy_ma_slow            = 200;
input int    strategy_ma_fast            = 5;
input int    strategy_rsi_period         = 2;
input double strategy_buy_level          = 5.0;
input double strategy_sell_level         = 95.0;
input int    strategy_atr_period         = 14;
input double strategy_emergency_atr_mult = 4.0; // HOUSE catastrophe stop; source has no hard SL/TP

int      g_str073_slow_handle = INVALID_HANDLE;
int      g_str073_fast_handle = INVALID_HANDLE;
int      g_str073_rsi_handle = INVALID_HANDLE;
int      g_str073_atr_handle = INVALID_HANDLE;
datetime g_str073_last_entry_bar = 0;
datetime g_str073_last_exit_eval_bar = 0;
datetime g_str073_last_exit_attempt_bar = 0;
datetime g_str073_last_data_log_bar = 0;
ulong    g_str073_exit_position_id = 0;
bool     g_str073_exit_latched = false;

bool Strategy073_ConfigValid()
  {
   return (strategy_ma_slow > strategy_ma_fast &&
           strategy_ma_fast > 1 &&
           strategy_rsi_period > 1 &&
           MathIsValidNumber(strategy_buy_level) &&
           MathIsValidNumber(strategy_sell_level) &&
           strategy_buy_level > 0.0 &&
           strategy_buy_level < strategy_sell_level &&
           strategy_sell_level < 100.0 &&
           strategy_atr_period > 1 &&
           MathIsValidNumber(
              strategy_emergency_atr_mult) &&
           strategy_emergency_atr_mult > 0.0);
  }

bool Strategy073_EnsureHandles()
  {
   if(g_str073_slow_handle == INVALID_HANDLE)
      g_str073_slow_handle =
         QM_IndMA(_Symbol,
                  PERIOD_D1,
                  strategy_ma_slow,
                  MODE_SMA,
                  PRICE_CLOSE);
   if(g_str073_fast_handle == INVALID_HANDLE)
      g_str073_fast_handle =
         QM_IndMA(_Symbol,
                  PERIOD_D1,
                  strategy_ma_fast,
                  MODE_SMA,
                  PRICE_CLOSE);
   if(g_str073_rsi_handle == INVALID_HANDLE)
      g_str073_rsi_handle =
         QM_IndRSI(_Symbol,
                   PERIOD_D1,
                   strategy_rsi_period,
                   PRICE_CLOSE);
   if(g_str073_atr_handle == INVALID_HANDLE)
      g_str073_atr_handle =
         QM_IndATR(_Symbol,
                   PERIOD_D1,
                   strategy_atr_period);
   return (g_str073_slow_handle != INVALID_HANDLE &&
           g_str073_fast_handle != INVALID_HANDLE &&
           g_str073_rsi_handle != INVALID_HANDLE &&
           g_str073_atr_handle != INVALID_HANDLE);
  }

bool Strategy073_HandlesReady()
  {
   if(!Strategy073_EnsureHandles())
      return false;
   const int required =
      (strategy_ma_slow + 5 > 205)
      ? strategy_ma_slow + 5
      : 205;
   return (QM_IndicatorWarmupReady(g_str073_slow_handle,
                                   0, 1, required, "STR-073_slow_ma") &&
           QM_IndicatorWarmupReady(g_str073_fast_handle,
                                   0, 1, required, "STR-073_fast_ma") &&
           QM_IndicatorWarmupReady(g_str073_rsi_handle,
                                   0, 1, required, "STR-073_rsi") &&
           QM_IndicatorWarmupReady(g_str073_atr_handle,
                                   0, 1, required, "STR-073_atr"));
  }

bool Strategy073_CurrentBar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_D1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-D1 clock for entry, exit, and retry guards
   return (bar_time > 0);
  }

void Strategy073_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str073_last_data_log_bar)
      return;
   g_str073_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-073\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

bool Strategy073_FindOwnPosition(
   ulong &ticket,
   ENUM_POSITION_TYPE &position_type,
   double &open_price,
   double &current_sl,
   ulong &position_id)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
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
      open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl =
         PositionGetDouble(POSITION_SL);
      position_id =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

bool Strategy073_HasOwnPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   ulong position_id = 0;
   return Strategy073_FindOwnPosition(ticket,
                                      position_type,
                                      open_price,
                                      current_sl,
                                      position_id);
  }

bool Strategy073_OpenedSince(const datetime since_time)
  {
   if(since_time <= 0)
      return true;
   if(!HistorySelect(since_time, TimeCurrent()))
     {
      Strategy073_LogDataMissing(
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

double Strategy073_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy073_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy073_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol, units * tick);
  }

bool Strategy073_EntryStopLegal(
   const QM_OrderType side,
   const double sl)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy073_TradeTick();
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
      MathMax(tick, (double)broker_level * point);
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
   if(_Period != PERIOD_D1 ||
      !Strategy073_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_D1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) 205-bar warmup gate, identical for slots 0-6
   if(bars_available < 205)
      return true;
   return !Strategy073_HandlesReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy073_CurrentBar(forming_time))
     {
      Strategy073_LogDataMissing("forming_d1_time", 0);
      return false;
     }
   if(forming_time == g_str073_last_entry_bar)
      return false;
   if(!Strategy073_HandlesReady())
     {
      Strategy073_LogDataMissing("indicator_warmup",
                                 forming_time);
      return false;
     }

   MqlRates bar1;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_D1,
                  1,
                  bar1)) // perf-allowed: one closed-D1 OHLC read inside the owned entry guard
     {
      Strategy073_LogDataMissing("entry_closed_d1",
                                 forming_time);
      return false;
     }
   const double slow =
      QM_IndicatorReadBuffer(g_str073_slow_handle,
                             0,
                             1);
   const double fast =
      QM_IndicatorReadBuffer(g_str073_fast_handle,
                             0,
                             1);
   const double rsi =
      QM_IndicatorReadBuffer(g_str073_rsi_handle,
                             0,
                             1);
   const double atr =
      QM_IndicatorReadBuffer(g_str073_atr_handle,
                             0,
                             1);
   if(!MathIsValidNumber(slow) ||
      !MathIsValidNumber(fast) ||
      !MathIsValidNumber(rsi) ||
      !MathIsValidNumber(atr) ||
      slow == EMPTY_VALUE ||
      fast == EMPTY_VALUE ||
      rsi == EMPTY_VALUE ||
      atr == EMPTY_VALUE ||
      slow <= 0.0 ||
      fast <= 0.0 ||
      rsi < 0.0 || rsi > 100.0 ||
      atr <= 0.0)
     {
      Strategy073_LogDataMissing(
         "entry_closed_indicators",
         forming_time);
      return false;
     }
   g_str073_last_entry_bar = forming_time;

   // A successful option-1 close earlier in this OnTick must not turn into an
   // immediate same-bar re-entry on a still-extreme RSI close.
   if(g_str073_last_exit_attempt_bar == forming_time ||
      Strategy073_HasOwnPosition() ||
      Strategy073_OpenedSince(forming_time))
      return false;

   const bool long_signal =
      (bar1.close > slow &&
       bar1.close < fast &&
       rsi < strategy_buy_level);
   const bool short_signal =
      (bar1.close < slow &&
       bar1.close > fast &&
       rsi > strategy_sell_level);
   if(!long_signal && !short_signal)
      return false;

   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
     {
      Strategy073_LogDataMissing("entry_quotes",
                                 forming_time);
      return false;
     }
   const double entry = long_signal ? ask : bid;
   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl =
      Strategy073_AlignPrice(
         long_signal
         ? entry -
            strategy_emergency_atr_mult * atr
         : entry +
            strategy_emergency_atr_mult * atr,
         long_signal ? -1 : 1);
   req.tp = 0.0;
   if(!Strategy073_EntryStopLegal(req.type,
                                  req.sl))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-073\",\"reason\":\"house_catastrophe_stop_geometry\",\"dir\":\"%s\",\"bar_time\":%I64d,\"entry\":%.8f,\"atr\":%.8f,\"sl\":%.8f,\"house_stop\":true}",
            QM_LoggerEscapeJson(
               long_signal ? "LONG" : "SHORT"),
            (long)forming_time,
            entry,
            atr,
            req.sl));
      return false;
     }

   req.reason =
      StringFormat(long_signal
                   ? "STR073_L_S%d_%I64d"
                   : "STR073_S_S%d_%I64d",
                   qm_magic_slot_offset,
                   (long)forming_time);
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-073\",\"dir\":\"%s\",\"slot\":%d,\"symbol\":\"%s\",\"bar_time\":%I64d,\"close\":%.8f,\"sma200\":%.8f,\"sma5\":%.8f,\"rsi\":%.8f,\"atr\":%.8f,\"entry\":%.8f,\"sl\":%.8f,\"house_stop\":true}",
         QM_LoggerEscapeJson(
            long_signal ? "LONG" : "SHORT"),
         qm_magic_slot_offset,
         QM_LoggerEscapeJson(_Symbol),
         (long)forming_time,
         bar1.close,
         slow,
         fast,
         rsi,
         atr,
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
   if(!Strategy073_CurrentBar(forming_time))
     {
      Strategy073_LogDataMissing("exit_d1_clock", 0);
      return false;
     }

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   ulong position_id = 0;
   if(!Strategy073_FindOwnPosition(ticket,
                                   position_type,
                                   open_price,
                                   current_sl,
                                   position_id))
     {
      // Keep this bar's attempt marker through the later EntrySignal call.
      if(forming_time != g_str073_last_exit_attempt_bar)
        {
         g_str073_exit_latched = false;
         g_str073_exit_position_id = 0;
         g_str073_last_exit_attempt_bar = 0;
        }
      return false;
     }

   if(position_id != g_str073_exit_position_id)
     {
      g_str073_exit_position_id = position_id;
      g_str073_exit_latched = false;
      g_str073_last_exit_eval_bar = 0;
      g_str073_last_exit_attempt_bar = 0;
     }

   // A rejected touch close remains latched, but broker retries are paced to
   // at most one attempt per D1 bar.
   if(g_str073_exit_latched)
     {
      if(forming_time ==
         g_str073_last_exit_attempt_bar)
         return false;
      g_str073_last_exit_attempt_bar =
         forming_time;
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_EXIT",
         StringFormat(
            "{\"strategy\":\"STR-073\",\"ticket\":%I64u,\"slot\":%d,\"reason\":\"sma5_touch_retry\",\"retry_bar\":%I64d}",
            ticket,
            qm_magic_slot_offset,
            (long)forming_time));
      return true;
     }

   if(forming_time == g_str073_last_exit_eval_bar)
      return false;
   if(!Strategy073_HandlesReady())
     {
      Strategy073_LogDataMissing("exit_indicator_warmup",
                                 forming_time);
      return false;
     }

   MqlRates bar1;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_D1,
                  1,
                  bar1)) // perf-allowed: one closed-D1 high/low read behind the owned exit bar guard
     {
      Strategy073_LogDataMissing("exit_closed_d1",
                                 forming_time);
      return false;
     }
   const double fast =
      QM_IndicatorReadBuffer(g_str073_fast_handle,
                             0,
                             1);
   if(!MathIsValidNumber(fast) ||
      fast == EMPTY_VALUE ||
      fast <= 0.0)
     {
      Strategy073_LogDataMissing("exit_sma5_closed_d1",
                                 forming_time);
      return false;
     }
   g_str073_last_exit_eval_bar = forming_time;

   const bool touched =
      (position_type == POSITION_TYPE_BUY)
      ? (bar1.high >= fast)
      : (bar1.low <= fast);
   if(!touched)
      return false;

   g_str073_exit_latched = true;
   g_str073_last_exit_attempt_bar = forming_time;
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_EXIT",
      StringFormat(
         "{\"strategy\":\"STR-073\",\"ticket\":%I64u,\"slot\":%d,\"symbol\":\"%s\",\"reason\":\"sma5_touch_next_open\",\"bar_time\":%I64d,\"bar_high\":%.8f,\"bar_low\":%.8f,\"sma5\":%.8f,\"next_open_approximation\":true}",
         ticket,
         qm_magic_slot_offset,
         QM_LoggerEscapeJson(_Symbol),
         (long)forming_time,
         bar1.high,
         bar1.low,
         fast));
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
