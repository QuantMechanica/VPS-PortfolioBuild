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
input int    qm_ea_id                   = 20112;
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
input int    strategy_ema_period      = 9;
input double strategy_min_gap_pips    = 5.0;
input double strategy_sl_buffer_pips  = 1.0;
input double strategy_rr              = 2.0;

enum Strategy036_Direction
  {
   STR036_NONE = 0,
   STR036_LONG = 1,
   STR036_SHORT = -1
  };

int                   g_str036_h_ema = INVALID_HANDLE;
Strategy036_Direction g_str036_direction = STR036_NONE;
bool                  g_str036_consumed = true;
bool                  g_str036_replayed = false;
datetime              g_str036_cross_time = 0;
datetime              g_str036_last_processed_bar = 0;
datetime              g_str036_last_data_log_bar = 0;

datetime Strategy036_CurrentM15Bar()
  {
   return (datetime)SeriesInfoInteger(_Symbol,
                                      PERIOD_M15,
                                      SERIES_LASTBAR_DATE);
  }

void Strategy036_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str036_last_data_log_bar)
      return;
   g_str036_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-036\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

bool Strategy036_ConfigValid()
  {
   return (strategy_ema_period > 1 &&
           MathIsValidNumber(strategy_min_gap_pips) &&
           strategy_min_gap_pips > 0.0 &&
           MathIsValidNumber(strategy_sl_buffer_pips) &&
           strategy_sl_buffer_pips >= 0.0 &&
           MathIsValidNumber(strategy_rr) &&
           strategy_rr > 0.0);
  }

bool Strategy036_EnsureHandle()
  {
   if(g_str036_h_ema == INVALID_HANDLE)
      g_str036_h_ema =
         QM_IndMA(_Symbol,
                  PERIOD_M15,
                  strategy_ema_period,
                  MODE_EMA,
                  PRICE_CLOSE);
   return (g_str036_h_ema != INVALID_HANDLE);
  }

bool Strategy036_ValidEMA(const double value)
  {
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE &&
           value > 0.0);
  }

double Strategy036_PipDistance()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

double Strategy036_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy036_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy036_TradeTick();
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

bool Strategy036_HasOwnPosition()
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

bool Strategy036_LongCross(const MqlRates &bar,
                           const MqlRates &prior,
                           const double ema,
                           const double prior_ema)
  {
   return (bar.close > ema &&
           prior.close <= prior_ema);
  }

bool Strategy036_ShortCross(const MqlRates &bar,
                            const MqlRates &prior,
                            const double ema,
                            const double prior_ema)
  {
   return (bar.close < ema &&
           prior.close >= prior_ema);
  }

bool Strategy036_CandidateQualifies(
   const Strategy036_Direction direction,
   const MqlRates &bar,
   const MqlRates &prior,
   const double ema,
   const double pip)
  {
   if(pip <= 0.0 || direction == STR036_NONE)
      return false;
   const double minimum_gap =
      strategy_min_gap_pips * pip;
   if(direction == STR036_LONG)
      return (bar.low - ema + pip * 1e-7 >= minimum_gap &&
              bar.close > prior.high);
   return (ema - bar.high + pip * 1e-7 >= minimum_gap &&
           bar.close < prior.low);
  }

bool Strategy036_ReplayState()
  {
   if(!Strategy036_EnsureHandle())
      return false;
   const int calculated =
      BarsCalculated(g_str036_h_ema);
   if(calculated < 20)
      return false;
   int requested = calculated -
                   strategy_ema_period - 2;
   if(requested > 512)
      requested = 512;
   if(requested < 3)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded new-bar-gated setup replay (integration review 2026-07-24)
                PERIOD_M15,
                1,
                requested,
                rates); // perf-allowed: bounded one-time restart replay of the rolling setup
   if(copied < 3)
      return false;

   const double pip = Strategy036_PipDistance();
   if(pip <= 0.0)
      return false;

   g_str036_direction = STR036_NONE;
   g_str036_consumed = true;
   g_str036_cross_time = 0;

   for(int shift = copied - 1; shift >= 1; --shift)
     {
      const MqlRates bar = rates[shift - 1];
      const MqlRates prior = rates[shift];
      const double ema =
         QM_IndicatorReadBuffer(g_str036_h_ema,
                                0,
                                shift);
      const double prior_ema =
         QM_IndicatorReadBuffer(g_str036_h_ema,
                                0,
                                shift + 1);
      if(!Strategy036_ValidEMA(ema) ||
         !Strategy036_ValidEMA(prior_ema))
         return false;

      if(Strategy036_LongCross(bar,
                               prior,
                               ema,
                               prior_ema))
        {
         g_str036_direction = STR036_LONG;
         g_str036_consumed = false;
         g_str036_cross_time = bar.time;
         continue;
        }
      if(Strategy036_ShortCross(bar,
                                prior,
                                ema,
                                prior_ema))
        {
         g_str036_direction = STR036_SHORT;
         g_str036_consumed = false;
         g_str036_cross_time = bar.time;
         continue;
        }
      if(!g_str036_consumed &&
         Strategy036_CandidateQualifies(
            g_str036_direction,
            bar,
            prior,
            ema,
            pip))
         g_str036_consumed = true;
     }

   g_str036_last_processed_bar = rates[0].time;
   g_str036_replayed = true;
   return true;
  }

bool Strategy036_StopsLegal(const QM_OrderType side,
                            const double sl,
                            const double tp)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy036_TradeTick();
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

   if(QM_OrderTypeIsBuy(side))
      return (sl < bid &&
              tp > ask &&
              bid - sl + tick * 0.1 >= minimum &&
              tp - ask + tick * 0.1 >= minimum);
   return (sl > ask &&
           tp < bid &&
           sl - ask + tick * 0.1 >= minimum &&
           bid - tp + tick * 0.1 >= minimum);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15 ||
      !Strategy036_ConfigValid())
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_M15,
                        SERIES_BARS_COUNT);
   const int warmup =
      (strategy_ema_period + 5 > 20)
      ? strategy_ema_period + 5
      : 20;
   if(bars_available < warmup ||
      !Strategy036_EnsureHandle())
      return true;
   return (BarsCalculated(g_str036_h_ema) < warmup);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime forming_time =
      Strategy036_CurrentM15Bar();
   if(forming_time <= 0)
     {
      Strategy036_LogDataMissing("forming_m15_time", 0);
      return false;
     }
   if(!g_str036_replayed)
     {
      if(!Strategy036_ReplayState())
         Strategy036_LogDataMissing("restart_replay",
                                    forming_time);
      return false;
     }

   MqlRates bar1;
   MqlRates bar2;
   if(!QM_ReadBar(_Symbol, PERIOD_M15, 1, bar1) ||
      !QM_ReadBar(_Symbol, PERIOD_M15, 2, bar2))
     {
      Strategy036_LogDataMissing("closed_m15_bars",
                                 forming_time);
      return false;
     }
   if(bar1.time == g_str036_last_processed_bar)
      return false;
   g_str036_last_processed_bar = bar1.time;

   if(!Strategy036_EnsureHandle())
     {
      Strategy036_LogDataMissing("ema_handle",
                                 forming_time);
      return false;
     }
   const double ema1 =
      QM_IndicatorReadBuffer(g_str036_h_ema, 0, 1);
   const double ema2 =
      QM_IndicatorReadBuffer(g_str036_h_ema, 0, 2);
   if(!Strategy036_ValidEMA(ema1) ||
      !Strategy036_ValidEMA(ema2))
     {
      Strategy036_LogDataMissing("ema_buffers",
                                 forming_time);
      return false;
     }

   if(Strategy036_LongCross(bar1,
                            bar2,
                            ema1,
                            ema2))
     {
      g_str036_direction = STR036_LONG;
      g_str036_consumed = false;
      g_str036_cross_time = bar1.time;
      return false;
     }
   if(Strategy036_ShortCross(bar1,
                             bar2,
                             ema1,
                             ema2))
     {
      g_str036_direction = STR036_SHORT;
      g_str036_consumed = false;
      g_str036_cross_time = bar1.time;
      return false;
     }
   if(g_str036_direction == STR036_NONE ||
      g_str036_consumed ||
      Strategy036_HasOwnPosition())
      return false;

   const double pip = Strategy036_PipDistance();
   if(pip <= 0.0)
     {
      Strategy036_LogDataMissing("pip_metadata",
                                 forming_time);
      return false;
     }
   if(!Strategy036_CandidateQualifies(
         g_str036_direction,
         bar1,
         bar2,
         ema1,
         pip))
      return false;

   // A qualifying candidate consumes the setup even if its executable
   // geometry later fails; this prevents a rejected signal from re-arming.
   g_str036_consumed = true;

   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
     {
      Strategy036_LogDataMissing("market_quotes",
                                 forming_time);
      return false;
     }
   const bool long_side =
      (g_str036_direction == STR036_LONG);
   req.type = long_side ? QM_BUY : QM_SELL;
   const double entry = long_side ? ask : bid;
   const double spread = ask - bid;
   const double buffer =
      strategy_sl_buffer_pips * pip + spread;
   const double raw_sl =
      long_side
      ? bar2.low - buffer
      : bar2.high + buffer;
   const double sl =
      Strategy036_AlignPrice(raw_sl,
                             long_side ? -1 : 1);
   const double risk =
      long_side ? entry - sl : sl - entry;
   const double raw_tp =
      long_side
      ? entry + strategy_rr * risk
      : entry - strategy_rr * risk;
   const double tp =
      Strategy036_AlignPrice(raw_tp,
                             long_side ? 1 : -1);

   if(sl <= 0.0 || tp <= 0.0 || risk <= 0.0 ||
      !Strategy036_StopsLegal(req.type, sl, tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-036\",\"reason\":\"stop_geometry\",\"dir\":\"%s\",\"candidate_bar\":%I64d,\"entry\":%.8f,\"anchor\":%.8f,\"spread\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            QM_LoggerEscapeJson(
               long_side ? "LONG" : "SHORT"),
            (long)bar1.time,
            entry,
            long_side ? bar2.low : bar2.high,
            spread,
            sl,
            tp));
      return false;
     }

   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      StringFormat(long_side
                   ? "STR036_L_%I64d"
                   : "STR036_S_%I64d",
                   (long)g_str036_cross_time);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-036\",\"dir\":\"%s\",\"cross_bar\":%I64d,\"candidate_bar\":%I64d,\"ema\":%.8f,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
         QM_LoggerEscapeJson(
            long_side ? "LONG" : "SHORT"),
         (long)g_str036_cross_time,
         (long)bar1.time,
         ema1,
         entry,
         req.sl,
         req.tp));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
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
