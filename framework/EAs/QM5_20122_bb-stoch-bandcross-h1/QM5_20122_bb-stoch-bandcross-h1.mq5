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
input int    qm_ea_id                   = 20122;
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
input int    strategy_bb_period  = 20;
input double strategy_bb_dev     = 2.0;
input int    strategy_stoch_k    = 14;
input int    strategy_stoch_d    = 3;
input int    strategy_stoch_slow = 3;
input double strategy_tp_pips    = 50.0;
input double strategy_sl_pips    = 50.0;
input double strategy_trail_pips = 15.0;

int      g_str067_h_bands = INVALID_HANDLE;
int      g_str067_h_stoch = INVALID_HANDLE;
datetime g_str067_last_entry_bar = 0;
datetime g_str067_last_data_log_bar = 0;

bool Strategy067_ConfigValid()
  {
   return (strategy_bb_period > 1 &&
           MathIsValidNumber(strategy_bb_dev) &&
           strategy_bb_dev > 0.0 &&
           strategy_stoch_k > 1 &&
           strategy_stoch_d > 0 &&
           strategy_stoch_slow > 0 &&
           MathIsValidNumber(strategy_tp_pips) &&
           strategy_tp_pips > 0.0 &&
           MathIsValidNumber(strategy_sl_pips) &&
           strategy_sl_pips > 0.0 &&
           MathIsValidNumber(strategy_trail_pips) &&
           strategy_trail_pips > 0.0);
  }

bool Strategy067_EnsureHandles()
  {
   if(g_str067_h_bands == INVALID_HANDLE)
      g_str067_h_bands =
         QM_IndBands(_Symbol,
                     PERIOD_H1,
                     strategy_bb_period,
                     strategy_bb_dev,
                     PRICE_CLOSE);
   if(g_str067_h_stoch == INVALID_HANDLE)
      g_str067_h_stoch =
         QM_IndStoch(_Symbol,
                     PERIOD_H1,
                     strategy_stoch_k,
                     strategy_stoch_d,
                     strategy_stoch_slow);
   return (g_str067_h_bands != INVALID_HANDLE &&
           g_str067_h_stoch != INVALID_HANDLE);
  }

bool Strategy067_HandlesReady()
  {
   if(!Strategy067_EnsureHandles())
      return false;
   return (QM_IndicatorWarmupReady(g_str067_h_bands,
                                   0,
                                   1,
                                   30,
                                   "STR-067_bands") &&
           QM_IndicatorWarmupReady(g_str067_h_stoch,
                                   0,
                                   1,
                                   30,
                                   "STR-067_stoch"));
  }

void Strategy067_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str067_last_data_log_bar)
      return;
   g_str067_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-067\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

bool Strategy067_HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

double Strategy067_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy067_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy067_TradeTick();
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

bool Strategy067_StopsLegal(const QM_OrderType side,
                            const double sl,
                            const double tp)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy067_TradeTick();
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || tick <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      sl <= 0.0 || tp <= 0.0)
      return false;

   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level)
      ? stops_level
      : freeze_level;
   const double minimum =
      MathMax(tick, (double)broker_level * point);
   if(side == QM_BUY)
      return (sl < bid && tp > ask &&
              bid - sl + tick * 0.1 >= minimum &&
              tp - ask + tick * 0.1 >= minimum);
   if(side == QM_SELL)
      return (sl > ask && tp < bid &&
              sl - ask + tick * 0.1 >= minimum &&
              bid - tp + tick * 0.1 >= minimum);
   return false;
  }

bool Strategy067_StopLegal(const ENUM_POSITION_TYPE position_type,
                           const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy067_TradeTick();
   if(point <= 0.0 || tick <= 0.0 || candidate <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level)
      ? stops_level
      : freeze_level;
   const double minimum =
      MathMax(tick, (double)broker_level * point);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 &&
              candidate < bid &&
              bid - candidate + tick * 0.1 >= minimum);
     }
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 &&
           candidate > ask &&
           candidate - ask + tick * 0.1 >= minimum);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1 ||
      !Strategy067_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   // Trailing must keep running if indicator history becomes temporarily
   // unavailable after an entry.
   if(Strategy067_HasOwnPosition())
      return false;
   return !Strategy067_HandlesReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlRates bar0;
   MqlRates bar1;
   MqlRates bar2;
   MqlRates bar3;
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 0, bar0) ||
      !QM_ReadBar(_Symbol, PERIOD_H1, 1, bar1) ||
      !QM_ReadBar(_Symbol, PERIOD_H1, 2, bar2) ||
      !QM_ReadBar(_Symbol, PERIOD_H1, 3, bar3))
     {
      Strategy067_LogDataMissing("h1_bars", 0);
      return false;
     }
   if(bar0.time == g_str067_last_entry_bar)
      return false;
   g_str067_last_entry_bar = bar0.time;

   if(!Strategy067_HandlesReady())
     {
      Strategy067_LogDataMissing("bands_or_stochastic",
                                 bar0.time);
      return false;
     }

   const double upper2 =
      QM_IndicatorReadBuffer(g_str067_h_bands, 1, 2);
   const double upper3 =
      QM_IndicatorReadBuffer(g_str067_h_bands, 1, 3);
   const double lower2 =
      QM_IndicatorReadBuffer(g_str067_h_bands, 2, 2);
   const double lower3 =
      QM_IndicatorReadBuffer(g_str067_h_bands, 2, 3);
   const double stoch_main =
      QM_IndicatorReadBuffer(g_str067_h_stoch, 0, 1);
   const double stoch_signal =
      QM_IndicatorReadBuffer(g_str067_h_stoch, 1, 1);
   if(!MathIsValidNumber(upper2) ||
      !MathIsValidNumber(upper3) ||
      !MathIsValidNumber(lower2) ||
      !MathIsValidNumber(lower3) ||
      !MathIsValidNumber(stoch_main) ||
      !MathIsValidNumber(stoch_signal) ||
      upper2 == EMPTY_VALUE ||
      upper3 == EMPTY_VALUE ||
      lower2 == EMPTY_VALUE ||
      lower3 == EMPTY_VALUE ||
      stoch_main == EMPTY_VALUE ||
      stoch_signal == EMPTY_VALUE ||
      upper2 <= lower2 ||
      upper3 <= lower3 ||
      stoch_main < 0.0 ||
      stoch_main > 100.0 ||
      stoch_signal < 0.0 ||
      stoch_signal > 100.0)
     {
      Strategy067_LogDataMissing("closed_indicator_values",
                                 bar0.time);
      return false;
     }

   const bool bullish_confirm = (bar1.close > bar1.open);
   const bool bearish_confirm = (bar1.close < bar1.open);
   const bool buy_confirm =
      (stoch_main > stoch_signal &&
       bullish_confirm &&
       stoch_main < 80.0);
   const bool sell_confirm =
      (stoch_main < stoch_signal &&
       bearish_confirm &&
       stoch_main > 20.0);

   // Fixed precedence: out-upper, out-lower, back-upper, back-lower.
   int signal_case = 0;
   if(bar3.close <= upper3 &&
      bar2.close > upper2 &&
      buy_confirm)
      signal_case = 1;
   else if(bar3.close >= lower3 &&
           bar2.close < lower2 &&
           sell_confirm)
      signal_case = 2;
   else if(bar3.close > upper3 &&
           bar2.close < upper2 &&
           sell_confirm)
      signal_case = 3;
   else if(bar3.close < lower3 &&
           bar2.close > lower2 &&
           buy_confirm)
      signal_case = 4;

   if(signal_case == 0 ||
      Strategy067_HasOwnPosition())
      return false;

   const bool is_long =
      (signal_case == 1 || signal_case == 4);
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double pip =
      QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid ||
      pip <= 0.0)
     {
      Strategy067_LogDataMissing("market_or_pip_metadata",
                                 bar0.time);
      return false;
     }

   const double entry = is_long ? ask : bid;
   req.type = is_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl =
      Strategy067_AlignPrice(
         is_long
         ? entry - strategy_sl_pips * pip
         : entry + strategy_sl_pips * pip,
         is_long ? -1 : 1);
   req.tp =
      Strategy067_AlignPrice(
         is_long
         ? entry + strategy_tp_pips * pip
         : entry - strategy_tp_pips * pip,
         is_long ? 1 : -1);
   if(!Strategy067_StopsLegal(req.type, req.sl, req.tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-067\",\"reason\":\"stop_geometry\",\"case\":%d,\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            signal_case,
            (long)bar0.time,
            entry,
            req.sl,
            req.tp));
      return false;
     }

   req.reason =
      StringFormat("STR067_C%d_%I64d",
                   signal_case,
                   (long)bar0.time);
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-067\",\"case\":%d,\"dir\":\"%s\",\"bar_time\":%I64d,\"stoch_main\":%.8f,\"stoch_signal\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
         signal_case,
         QM_LoggerEscapeJson(is_long ? "LONG" : "SHORT"),
         (long)bar0.time,
         stoch_main,
         stoch_signal,
         req.sl,
         req.tp));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double pip =
      QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   const double tick = Strategy067_TradeTick();
   if(pip <= 0.0 || tick <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(
            POSITION_TYPE);
      const double open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl =
         PositionGetDouble(POSITION_SL);
      const bool is_long =
         (position_type == POSITION_TYPE_BUY);
      const double market =
         is_long
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0)
         continue;

      const double profit_distance =
         is_long
         ? market - open_price
         : open_price - market;
      if(!(profit_distance >
           strategy_trail_pips * pip))
         continue;

      const double candidate =QM_TM_NormalizePrice(_Symbol, Strategy067_AlignPrice(
            is_long
            ? market - strategy_trail_pips * pip
            : market + strategy_trail_pips * pip,
            is_long ? -1 : 1));
      if(candidate <= 0.0)
         continue;

      const bool tightens_by_step =
         (current_sl <= 0.0) ||
         (is_long
          ? candidate - current_sl + tick * 0.1 >= pip
          : current_sl - candidate + tick * 0.1 >= pip);
      if(!tightens_by_step ||
         !Strategy067_StopLegal(position_type,
                                candidate))
         continue;

      QM_TM_MoveSL(ticket,
                   candidate,
                   "STR067_TRAIL15");
     }
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
