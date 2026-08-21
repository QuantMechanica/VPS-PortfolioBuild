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
input int    qm_ea_id                   = 20108;
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
input int    strategy_entry_ema_period = 34;
input int    strategy_entry_ema_shift  = 16;
input int    strategy_stop_ema_period  = 144;
input double strategy_tp_pips          = 17.0;

int      g_str024_h_entry = INVALID_HANDLE;
int      g_str024_h_stop = INVALID_HANDLE;
datetime g_str024_last_entry_bar = 0;
datetime g_str024_last_data_log_bar = 0;

bool Strategy024_EnsureHandles()
  {
   if(g_str024_h_entry == INVALID_HANDLE)
      g_str024_h_entry =
         QM_IndMA(_Symbol,
                  PERIOD_M5,
                  strategy_entry_ema_period,
                  MODE_EMA,
                  PRICE_CLOSE);
   if(g_str024_h_stop == INVALID_HANDLE)
      g_str024_h_stop =
         QM_IndMA(_Symbol,
                  PERIOD_M5,
                  strategy_stop_ema_period,
                  MODE_EMA,
                  PRICE_CLOSE);
   return (g_str024_h_entry != INVALID_HANDLE &&
           g_str024_h_stop != INVALID_HANDLE);
  }

datetime Strategy024_CurrentBarTime()
  {
   return (datetime)SeriesInfoInteger(_Symbol,
                                      PERIOD_M5,
                                      SERIES_LASTBAR_DATE);
  }

void Strategy024_LogDataMissing(const string component)
  {
   const datetime bar_time = Strategy024_CurrentBarTime();
   if(bar_time > 0 && bar_time == g_str024_last_data_log_bar)
      return;
   g_str024_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-024\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

double Strategy024_TradeTick()
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy024_AlignStop(const bool long_side,
                             const double raw_price)
  {
   const double tick = Strategy024_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   const double units =
      long_side
      ? MathFloor(scaled + 1e-9)
      : MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol, units * tick);
  }

bool Strategy024_HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

bool Strategy024_StopsLegal(const QM_OrderType side,
                            const double sl,
                            const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy024_TradeTick();
   if(point <= 0.0 || tick <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum =
      MathMax(tick, (double)stops_level * point);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;

   if(QM_OrderTypeIsBuy(side))
      return (sl < bid &&
              bid - sl + tick * 0.1 >= minimum &&
              tp > ask &&
              tp - ask + tick * 0.1 >= minimum);
   return (sl > ask &&
           sl - ask + tick * 0.1 >= minimum &&
           tp < bid &&
           bid - tp + tick * 0.1 >= minimum);
  }

double Strategy024_TakeAtPips(const QM_OrderType side,
                              const double entry,
                              const double pips)
  {
   // The public fixed-pip helper exposes the symbol's canonical pip unit.
   // Scale that framework-owned unit so the declared double input remains
   // valid for future fractional Q03 domains without hand-rolled digit logic.
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

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5 ||
      strategy_entry_ema_period <= 1 ||
      strategy_entry_ema_shift < 0 ||
      strategy_stop_ema_period <= 1 ||
      !MathIsValidNumber(strategy_tp_pips) ||
      strategy_tp_pips <= 0.0)
      return true;

   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;

   const int longest_period =
      (strategy_entry_ema_period > strategy_stop_ema_period)
      ? strategy_entry_ema_period
      : strategy_stop_ema_period;
   const int warmup_needed =
      longest_period + strategy_entry_ema_shift + 5;
   const long bars_available =
      SeriesInfoInteger(_Symbol, PERIOD_M5, SERIES_BARS_COUNT);
   if(bars_available < warmup_needed)
      return true;
   if(!Strategy024_EnsureHandles())
      return true;
   return (!QM_IndicatorWarmupReady(g_str024_h_entry,
                                    0, 1, warmup_needed, "STR-024_entry_ema") ||
           !QM_IndicatorWarmupReady(g_str024_h_stop,
                                    0, 1, warmup_needed, "STR-024_stop_ema"));
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime forming_time = Strategy024_CurrentBarTime();
   if(forming_time <= 0)
     {
      Strategy024_LogDataMissing("forming_m5_time");
      return false;
     }
   if(forming_time == g_str024_last_entry_bar)
      return false;
   g_str024_last_entry_bar = forming_time;

   if(Strategy024_HasOwnPosition())
      return false;
   if(!Strategy024_EnsureHandles())
     {
      Strategy024_LogDataMissing("ema_handles");
      return false;
     }

   MqlRates bar1;
   MqlRates bar2;
   if(!QM_ReadBar(_Symbol, PERIOD_M5, 1, bar1) ||
      !QM_ReadBar(_Symbol, PERIOD_M5, 2, bar2))
     {
      Strategy024_LogDataMissing("closed_m5_bars");
      return false;
     }

   const int trigger_shift1 = 1 + strategy_entry_ema_shift;
   const int trigger_shift2 = 2 + strategy_entry_ema_shift;
   const double trigger1 =
      QM_IndicatorReadBuffer(g_str024_h_entry,
                             0,
                             trigger_shift1);
   const double trigger2 =
      QM_IndicatorReadBuffer(g_str024_h_entry,
                             0,
                             trigger_shift2);
   const double stop_ema1 =
      QM_IndicatorReadBuffer(g_str024_h_stop, 0, 1);
   if(trigger1 <= 0.0 || trigger2 <= 0.0 || stop_ema1 <= 0.0)
     {
      Strategy024_LogDataMissing("ema_buffers");
      return false;
     }

   const bool long_signal =
      (bar1.close > trigger1 && bar2.close <= trigger2);
   const bool short_signal =
      (bar1.close < trigger1 && bar2.close >= trigger2);
   if(!long_signal && !short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry =
      long_signal
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
     {
      Strategy024_LogDataMissing("market_price");
      return false;
     }

   const double sl =
      Strategy024_AlignStop(long_signal, stop_ema1);
   const double tp =
      Strategy024_TakeAtPips(req.type,
                             entry,
                             strategy_tp_pips);
   if((long_signal && sl >= entry) ||
      (short_signal && sl <= entry) ||
      !Strategy024_StopsLegal(req.type, sl, tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-024\",\"reason\":\"stop_geometry\",\"dir\":\"%s\",\"entry\":%.8f,\"ema144\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            QM_LoggerEscapeJson(long_signal ? "LONG" : "SHORT"),
            entry,
            stop_ema1,
            sl,
            tp));
      return false;
     }

   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      long_signal ? "STR024_EMA_BREACH_LONG"
                  : "STR024_EMA_BREACH_SHORT";
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-024\",\"dir\":\"%s\",\"bar_time\":%I64d,\"close1\":%.8f,\"trigger1\":%.8f,\"close2\":%.8f,\"trigger2\":%.8f,\"ema144\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
         QM_LoggerEscapeJson(long_signal ? "LONG" : "SHORT"),
         (long)bar1.time,
         bar1.close,
         trigger1,
         bar2.close,
         trigger2,
         stop_ema1,
         sl,
         tp));
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
