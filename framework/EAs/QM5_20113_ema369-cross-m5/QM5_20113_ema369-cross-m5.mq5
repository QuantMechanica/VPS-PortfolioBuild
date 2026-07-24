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
input int    qm_ea_id                   = 20113;
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
input int    strategy_ema_fast = 3;
input int    strategy_ema_mid  = 6;
input int    strategy_ema_slow = 9;
input double strategy_tp_pips  = 10.0;
input double strategy_sl_pips  = 20.0;

int      g_str038_h_fast = INVALID_HANDLE;
int      g_str038_h_mid = INVALID_HANDLE;
int      g_str038_h_slow = INVALID_HANDLE;
datetime g_str038_last_entry_bar = 0;
datetime g_str038_last_exit_bar = 0;
datetime g_str038_suppress_entry_bar = 0;
datetime g_str038_last_data_log_bar = 0;

datetime Strategy038_CurrentM5Bar()
  {
   return (datetime)SeriesInfoInteger(_Symbol,
                                      PERIOD_M5,
                                      SERIES_LASTBAR_DATE);
  }

void Strategy038_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str038_last_data_log_bar)
      return;
   g_str038_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-038\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

bool Strategy038_ConfigValid()
  {
   return (strategy_ema_fast > 0 &&
           strategy_ema_mid > strategy_ema_fast &&
           strategy_ema_slow > strategy_ema_mid &&
           MathIsValidNumber(strategy_tp_pips) &&
           strategy_tp_pips > 0.0 &&
           MathIsValidNumber(strategy_sl_pips) &&
           strategy_sl_pips > 0.0);
  }

bool Strategy038_EnsureHandles()
  {
   if(g_str038_h_fast == INVALID_HANDLE)
      g_str038_h_fast =
         QM_IndMA(_Symbol,
                  PERIOD_M5,
                  strategy_ema_fast,
                  MODE_EMA,
                  PRICE_CLOSE);
   if(g_str038_h_mid == INVALID_HANDLE)
      g_str038_h_mid =
         QM_IndMA(_Symbol,
                  PERIOD_M5,
                  strategy_ema_mid,
                  MODE_EMA,
                  PRICE_CLOSE);
   if(g_str038_h_slow == INVALID_HANDLE)
      g_str038_h_slow =
         QM_IndMA(_Symbol,
                  PERIOD_M5,
                  strategy_ema_slow,
                  MODE_EMA,
                  PRICE_CLOSE);
   return (g_str038_h_fast != INVALID_HANDLE &&
           g_str038_h_mid != INVALID_HANDLE &&
           g_str038_h_slow != INVALID_HANDLE);
  }

bool Strategy038_ValidEMA(const double value)
  {
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE &&
           value > 0.0);
  }

bool Strategy038_ReadEMASet(const int shift,
                            double &fast,
                            double &mid,
                            double &slow)
  {
   fast = 0.0;
   mid = 0.0;
   slow = 0.0;
   if(shift < 1 || !Strategy038_EnsureHandles())
      return false;
   fast =
      QM_IndicatorReadBuffer(g_str038_h_fast, 0, shift);
   mid =
      QM_IndicatorReadBuffer(g_str038_h_mid, 0, shift);
   slow =
      QM_IndicatorReadBuffer(g_str038_h_slow, 0, shift);
   return (Strategy038_ValidEMA(fast) &&
           Strategy038_ValidEMA(mid) &&
           Strategy038_ValidEMA(slow));
  }

bool Strategy038_AboveAll(const double fast,
                          const double mid,
                          const double slow)
  {
   return (fast > mid && fast > slow);
  }

bool Strategy038_BelowAll(const double fast,
                          const double mid,
                          const double slow)
  {
   return (fast < mid && fast < slow);
  }

double Strategy038_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy038_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy038_TradeTick();
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

double Strategy038_PipDistance()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

bool Strategy038_OwnPositionType(
   ENUM_POSITION_TYPE &position_type,
   ulong &position_ticket)
  {
   position_type = POSITION_TYPE_BUY;
   position_ticket = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(
            POSITION_TYPE);
      position_ticket = ticket;
      return true;
     }
   return false;
  }

bool Strategy038_StopsLegal(const QM_OrderType side,
                            const double sl,
                            const double tp)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy038_TradeTick();
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
   if(_Period != PERIOD_M5 ||
      !Strategy038_ConfigValid())
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_M5,
                        SERIES_BARS_COUNT);
   const int warmup =
      (strategy_ema_slow + 5 > 14)
      ? strategy_ema_slow + 5
      : 14;
   if(bars_available < warmup ||
      !Strategy038_EnsureHandles())
      return true;
   return (BarsCalculated(g_str038_h_fast) < warmup ||
           BarsCalculated(g_str038_h_mid) < warmup ||
           BarsCalculated(g_str038_h_slow) < warmup);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime forming_time =
      Strategy038_CurrentM5Bar();
   if(forming_time <= 0)
     {
      Strategy038_LogDataMissing("forming_m5_time", 0);
      return false;
     }
   if(forming_time == g_str038_last_entry_bar)
      return false;
   g_str038_last_entry_bar = forming_time;
   if(forming_time == g_str038_suppress_entry_bar)
      return false;

   ENUM_POSITION_TYPE position_type;
   ulong position_ticket = 0;
   if(Strategy038_OwnPositionType(position_type,
                                  position_ticket))
      return false;

   double fast1 = 0.0;
   double mid1 = 0.0;
   double slow1 = 0.0;
   double fast2 = 0.0;
   double mid2 = 0.0;
   double slow2 = 0.0;
   if(!Strategy038_ReadEMASet(1,
                              fast1,
                              mid1,
                              slow1) ||
      !Strategy038_ReadEMASet(2,
                              fast2,
                              mid2,
                              slow2))
     {
      Strategy038_LogDataMissing("ema_buffers",
                                 forming_time);
      return false;
     }

   const bool long_signal =
      (Strategy038_AboveAll(fast1, mid1, slow1) &&
       !Strategy038_AboveAll(fast2, mid2, slow2));
   const bool short_signal =
      (Strategy038_BelowAll(fast1, mid1, slow1) &&
       !Strategy038_BelowAll(fast2, mid2, slow2));
   if(!long_signal && !short_signal)
      return false;

   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double pip = Strategy038_PipDistance();
   if(bid <= 0.0 || ask <= 0.0 || ask < bid ||
      pip <= 0.0)
     {
      Strategy038_LogDataMissing("market_or_pip_metadata",
                                 forming_time);
      return false;
     }

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? ask : bid;
   const double raw_sl =
      long_signal
      ? entry - strategy_sl_pips * pip
      : entry + strategy_sl_pips * pip;
   const double raw_tp =
      long_signal
      ? entry + strategy_tp_pips * pip
      : entry - strategy_tp_pips * pip;
   const double sl =
      Strategy038_AlignPrice(raw_sl,
                             long_signal ? -1 : 1);
   const double tp =
      Strategy038_AlignPrice(raw_tp,
                             long_signal ? 1 : -1);
   if(!Strategy038_StopsLegal(req.type, sl, tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-038\",\"reason\":\"stop_geometry\",\"dir\":\"%s\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            QM_LoggerEscapeJson(
               long_signal ? "LONG" : "SHORT"),
            (long)forming_time,
            entry,
            sl,
            tp));
      return false;
     }

   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      StringFormat(long_signal
                   ? "STR038_L_%I64d"
                   : "STR038_S_%I64d",
                   (long)forming_time);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-038\",\"dir\":\"%s\",\"bar_time\":%I64d,\"ema3\":%.8f,\"ema6\":%.8f,\"ema9\":%.8f,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
         QM_LoggerEscapeJson(
            long_signal ? "LONG" : "SHORT"),
         (long)forming_time,
         fast1,
         mid1,
         slow1,
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
   const datetime forming_time =
      Strategy038_CurrentM5Bar();
   if(forming_time <= 0)
     {
      Strategy038_LogDataMissing("forming_m5_time", 0);
      return false;
     }
   if(forming_time == g_str038_last_exit_bar)
      return false;
   g_str038_last_exit_bar = forming_time;

   ENUM_POSITION_TYPE position_type;
   ulong position_ticket = 0;
   if(!Strategy038_OwnPositionType(position_type,
                                   position_ticket))
      return false;

   double fast1 = 0.0;
   double mid1 = 0.0;
   double slow1 = 0.0;
   if(!Strategy038_ReadEMASet(1,
                              fast1,
                              mid1,
                              slow1))
     {
      Strategy038_LogDataMissing("exit_ema_buffers",
                                 forming_time);
      return false;
     }

   const bool exit_long =
      (position_type == POSITION_TYPE_BUY &&
       Strategy038_BelowAll(fast1, mid1, slow1));
   const bool exit_short =
      (position_type == POSITION_TYPE_SELL &&
       Strategy038_AboveAll(fast1, mid1, slow1));
   if(!exit_long && !exit_short)
      return false;

   // The framework calls EntrySignal later in the same evaluation. Suppress
   // that bar so this opposite condition closes only; it never reverses.
   g_str038_suppress_entry_bar = forming_time;
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_EXIT",
      StringFormat(
         "{\"strategy\":\"STR-038\",\"ticket\":%I64u,\"reason\":\"opposite_full_cross\",\"bar_time\":%I64d,\"ema3\":%.8f,\"ema6\":%.8f,\"ema9\":%.8f}",
         position_ticket,
         (long)forming_time,
         fast1,
         mid1,
         slow1));
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
