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
input int    qm_ea_id                   = 20102;
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
input bool strategy_sma_filter = false;
input int strategy_sma_period = 34;
input double strategy_sl_pips = 12.5;
input double strategy_tp_pips = 25.0;
input int strategy_day_anchor_utc_hour = 22;

int g_str003_h_sma = INVALID_HANDLE;
datetime g_str003_last_entry_bar = 0;
datetime g_str003_last_data_log_bar = 0;
long g_str003_day_key = LONG_MIN;
double g_str003_prev_high = 0.0;
double g_str003_prev_low = 0.0;
bool g_str003_long_done = false;
bool g_str003_short_done = false;

bool Strategy003_EnsureSmaHandle()
  {
   if(!strategy_sma_filter)
      return true;
   if(g_str003_h_sma == INVALID_HANDLE)
      g_str003_h_sma = QM_IndMA(_Symbol,
                                PERIOD_H1,
                                strategy_sma_period,
                                MODE_SMA,
                                PRICE_CLOSE);
   return (g_str003_h_sma != INVALID_HANDLE);
  }

bool Strategy003_CurrentBarTime(datetime &bar_time)
  {
   bar_time = 0;
   MqlRates forming_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 0, forming_bar))
      return false;
   bar_time = forming_bar.time;
   return (bar_time > 0);
  }

void Strategy003_LogDataMissing(const string component)
  {
   datetime bar_time = 0;
   Strategy003_CurrentBarTime(bar_time);
   if(bar_time > 0 && bar_time == g_str003_last_data_log_bar)
      return;
   g_str003_last_data_log_bar = bar_time;
   QM_LogEvent(QM_WARN,
               SETUP_DATA_MISSING,
               StringFormat("{\"strategy\":\"STR-003\",\"component\":\"%s\",\"bar_time\":%I64d}",
                            QM_LoggerEscapeJson(component),
                            (long)bar_time));
  }

long Strategy003_DayKey(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      return LONG_MIN;
   const long shifted =
      (long)utc_time -
      (long)strategy_day_anchor_utc_hour * 3600;
   return shifted / 86400;
  }

bool Strategy003_HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

bool Strategy003_LoadClosedWindow(MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   // This copy runs only after the hook's own H1 new-bar guard.
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, 40, rates); // perf-allowed: bounded 40-bar cyclic-day replay
   return (copied == 40);
  }

bool Strategy003_RebuildDayState(const MqlRates &rates[],
                                 const long current_key,
                                 double &prev_high,
                                 double &prev_low,
                                 bool &long_done,
                                 bool &short_done)
  {
   prev_high = -DBL_MAX;
   prev_low = DBL_MAX;
   long_done = false;
   short_done = false;
   const long previous_key = current_key - 1;
   bool have_previous = false;
   bool crossed_older_boundary = false;
   const int copied = ArraySize(rates);

   for(int i = 0; i < copied; ++i)
     {
      const long key = Strategy003_DayKey(rates[i].time);
      if(key == previous_key)
        {
         have_previous = true;
         if(rates[i].high > prev_high)
            prev_high = rates[i].high;
         if(rates[i].low < prev_low)
            prev_low = rates[i].low;
        }
      else if(key < previous_key && have_previous)
         crossed_older_boundary = true;
     }
   if(!have_previous ||
      !crossed_older_boundary ||
      prev_high <= 0.0 ||
      prev_low <= 0.0 ||
      prev_high <= prev_low)
      return false;

   // Replay all older closed bars in the current cyclic day so a restart
   // preserves first-close consumption without files.
   for(int i = copied - 2; i >= 1; --i)
     {
      if(Strategy003_DayKey(rates[i].time) != current_key)
         continue;
      const double close_now = rates[i].close;
      const double close_before = rates[i + 1].close;
      if(close_now > prev_high && close_before <= prev_high)
         long_done = true;
      if(close_now < prev_low && close_before >= prev_low)
         short_done = true;
     }
   return true;
  }

double Strategy003_StopAtFractionalPips(const QM_OrderType side,
                                        const double entry,
                                        const double pips)
  {
   // The public fixed-pip helper takes an integer. Use its exact one-pip
   // symbol conversion, then the framework distance primitive, preserving
   // the source's fractional 12.5-pip stop without hand-rolled digit logic.
   const double one_pip_stop =
      QM_StopFixedPips(_Symbol, side, entry, 1);
   const double pip_distance = MathAbs(entry - one_pip_stop);
   if(pip_distance <= 0.0 || pips <= 0.0)
      return 0.0;
   return QM_StopRulesStopFromDistance(_Symbol,
                                       side,
                                       entry,
                                       pip_distance * pips);
  }

double Strategy003_TakeAtFractionalPips(const QM_OrderType side,
                                        const double entry,
                                        const double pips)
  {
   const double one_pip_take =
      QM_TakeFixedPips(_Symbol, side, entry, 1);
   const double pip_distance = MathAbs(one_pip_take - entry);
   if(pip_distance <= 0.0 || pips <= 0.0)
      return 0.0;
   return QM_StopRulesTakeFromDistance(_Symbol,
                                       side,
                                       entry,
                                       pip_distance * pips);
  }

bool Strategy003_StopsLegal(const QM_OrderType side,
                            const double sl,
                            const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum =
      MathMax(point, (double)stops_level * point);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(side))
      return (sl < bid && bid - sl + point * 0.1 >= minimum &&
              tp > ask && tp - ask + point * 0.1 >= minimum);
   return (sl > ask && sl - ask + point * 0.1 >= minimum &&
           tp < bid && bid - tp + point * 0.1 >= minimum);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1 ||
      strategy_sma_period <= 1 ||
      strategy_sl_pips <= 0.0 ||
      strategy_tp_pips <= 0.0 ||
      strategy_day_anchor_utc_hour < 0 ||
      strategy_day_anchor_utc_hour >= 24)
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol, PERIOD_H1, SERIES_BARS_COUNT);
   if(bars_available < 60)
      return true;
   if(!Strategy003_EnsureSmaHandle())
      return true;
   if(strategy_sma_filter &&
      !QM_IndicatorWarmupReady(g_str003_h_sma,
                               0,
                               1,
                               strategy_sma_period + 5,
                               "STR-003_sma"))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy003_CurrentBarTime(forming_time))
     {
      Strategy003_LogDataMissing("forming_bar");
      return false;
     }
   if(forming_time == g_str003_last_entry_bar)
      return false;
   g_str003_last_entry_bar = forming_time;

   MqlRates rates[];
   if(!Strategy003_LoadClosedWindow(rates))
     {
      Strategy003_LogDataMissing("cyclic_day_window");
      return false;
     }
   const long current_key = Strategy003_DayKey(rates[0].time);
   if(current_key == LONG_MIN)
     {
      Strategy003_LogDataMissing("utc_day_key");
      return false;
     }

   double prev_high = 0.0;
   double prev_low = 0.0;
   bool replay_long_done = false;
   bool replay_short_done = false;
   if(!Strategy003_RebuildDayState(rates,
                                   current_key,
                                   prev_high,
                                   prev_low,
                                   replay_long_done,
                                   replay_short_done))
     {
      Strategy003_LogDataMissing("complete_previous_cyclic_day");
      return false;
     }
   g_str003_day_key = current_key;
   g_str003_prev_high = prev_high;
   g_str003_prev_low = prev_low;
   g_str003_long_done = replay_long_done;
   g_str003_short_done = replay_short_done;

   const bool long_event =
      !g_str003_long_done &&
      rates[0].close > g_str003_prev_high &&
      rates[1].close <= g_str003_prev_high;
   const bool short_event =
      !g_str003_short_done &&
      rates[0].close < g_str003_prev_low &&
      rates[1].close >= g_str003_prev_low;
   if(!long_event && !short_event)
      return false;

   // Consumption precedes position/filter/stop vetoes: no late chase.
   if(long_event)
      g_str003_long_done = true;
   if(short_event)
      g_str003_short_done = true;
   if(Strategy003_HasOwnPosition())
      return false;

   double sma1 = 0.0;
   if(strategy_sma_filter)
     {
      if(!Strategy003_EnsureSmaHandle())
        {
         Strategy003_LogDataMissing("sma_handle");
         return false;
        }
      sma1 = QM_IndicatorReadBuffer(g_str003_h_sma, 0, 1);
      if(sma1 <= 0.0)
        {
         Strategy003_LogDataMissing("sma_buffer");
         return false;
        }
      if(long_event && rates[0].close <= sma1)
         return false;
      if(short_event && rates[0].close >= sma1)
         return false;
     }

   req.type = long_event ? QM_BUY : QM_SELL;
   const double entry =
      long_event
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
     {
      Strategy003_LogDataMissing("market_price");
      return false;
     }
   const double sl =
      Strategy003_StopAtFractionalPips(req.type,
                                       entry,
                                       strategy_sl_pips);
   const double tp =
      Strategy003_TakeAtFractionalPips(req.type,
                                       entry,
                                       strategy_tp_pips);
   if(!Strategy003_StopsLegal(req.type, sl, tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-003\",\"reason\":\"stops_level\",\"dir\":\"%s\",\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"day_key\":%I64d}",
            long_event ? "LONG" : "SHORT",
            entry,
            sl,
            tp,
            current_key));
      return false;
     }

   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      long_event ? "STR003_PDBE_LONG" : "STR003_PDBE_SHORT";
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-003\",\"dir\":\"%s\",\"close\":%.8f,\"level\":%.8f,\"sma\":%.8f,\"day_key\":%I64d,\"sl\":%.8f,\"tp\":%.8f}",
         long_event ? "LONG" : "SHORT",
         rates[0].close,
         long_event ? g_str003_prev_high : g_str003_prev_low,
         sma1,
         current_key,
         sl,
         tp));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Source baseline is set-and-forget: fixed server-side SL/TP only.
  }

bool Strategy_ExitSignal()
  {
   return false;
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
