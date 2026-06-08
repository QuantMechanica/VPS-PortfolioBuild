#property strict
#property version   "5.0"
#property description "QM5_11370 Forex Profit System EMA3 PSAR H1"

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
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 11370;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H1;
input ENUM_TIMEFRAMES strategy_psar_confirm_tf    = PERIOD_M15;
input int             strategy_ema_fast           = 10;
input int             strategy_ema_mid            = 25;
input int             strategy_ema_slow           = 50;
input double          strategy_psar_step          = 0.02;
input double          strategy_psar_maximum       = 0.20;
input int             strategy_initial_sl_cap_pips = 30;
input int             strategy_ema50_buffer_points = 3;
input int             strategy_max_spread_pips    = 20;
input bool            strategy_session_filter_enabled = true;
input int             strategy_london_open_hour_broker = 8;
input int             strategy_ny_open_hour_broker = 13;
input int             strategy_session_window_hours = 5;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Framework news gates run before this hook. Session and spread are entry-only
   // filters so EMA50 trailing and strategy exits remain active after entry.
   return false;
  }

double Strategy_PipSize(const string symbol)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
  }

bool Strategy_ReadClose(const string symbol,
                        const ENUM_TIMEFRAMES tf,
                        const int shift,
                        double &out_close)
  {
   out_close = 0.0;
   double values[];
   ArraySetAsSeries(values, true);
   const int copied = CopyClose(symbol, tf, shift, 1, values); // perf-allowed: one closed-bar value; no framework close reader exists.
   if(copied != 1)
      return false;
   out_close = values[0];
   return (out_close > 0.0);
  }

int Strategy_PSARHandle(const string symbol, const ENUM_TIMEFRAMES tf)
  {
   const string key = StringFormat("SAR|%s|%d|%.5f|%.5f",
                                   symbol,
                                   (int)tf,
                                   strategy_psar_step,
                                   strategy_psar_maximum);
   int handle = QM_IndicatorsLookup(key);
   if(handle != INVALID_HANDLE)
      return handle;

   handle = iSAR(symbol, tf, strategy_psar_step, strategy_psar_maximum);
   return QM_IndicatorsRegister(key, handle);
  }

double Strategy_PSAR(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
  {
   return QM_IndicatorReadBuffer(Strategy_PSARHandle(symbol, tf), 0, shift);
  }

bool Strategy_HourInWindow(const int hour, const int start_hour, const int window_hours)
  {
   if(window_hours <= 0)
      return false;
   const int start = ((start_hour % 24) + 24) % 24;
   const int width = MathMin(window_hours, 24);
   const int delta = (hour - start + 24) % 24;
   return (delta >= 0 && delta < width);
  }

bool Strategy_SessionAllowsEntry()
  {
   if(!strategy_session_filter_enabled)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return Strategy_HourInWindow(dt.hour,
                                strategy_london_open_hour_broker,
                                strategy_session_window_hours) ||
          Strategy_HourInWindow(dt.hour,
                                strategy_ny_open_hour_broker,
                                strategy_session_window_hours);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double pip = Strategy_PipSize(_Symbol);
   if(ask <= 0.0 || bid <= 0.0 || pip <= 0.0 || strategy_max_spread_pips <= 0)
      return false;
   return ((ask - bid) / pip <= (double)strategy_max_spread_pips);
  }

bool Strategy_PSARBullish(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const double psar = Strategy_PSAR(_Symbol, tf, shift);
   double close_value = 0.0;
   if(psar <= 0.0 || !Strategy_ReadClose(_Symbol, tf, shift, close_value))
      return false;
   return (psar < close_value);
  }

bool Strategy_PSARBearish(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const double psar = Strategy_PSAR(_Symbol, tf, shift);
   double close_value = 0.0;
   if(psar <= 0.0 || !Strategy_ReadClose(_Symbol, tf, shift, close_value))
      return false;
   return (psar > close_value);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

double Strategy_InitialStop(const QM_OrderType side, const double entry, const double ema50)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double pip = Strategy_PipSize(_Symbol);
   if(point <= 0.0 || pip <= 0.0 || entry <= 0.0 || ema50 <= 0.0)
      return 0.0;

   const double buffer = strategy_ema50_buffer_points * point;
   const double cap_distance = strategy_initial_sl_cap_pips * pip;
   if(side == QM_BUY)
     {
      double sl = ema50 - buffer;
      const double capped = entry - cap_distance;
      if(sl < capped || sl >= entry)
         sl = capped;
      return QM_StopRulesNormalizePrice(_Symbol, sl);
     }

   double sl = ema50 + buffer;
   const double capped = entry + cap_distance;
   if(sl > capped || sl <= entry)
      sl = capped;
   return QM_StopRulesNormalizePrice(_Symbol, sl);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SessionAllowsEntry() || !Strategy_SpreadAllowsEntry())
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_fast, 1);
   const double ema_mid_1  = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_mid, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_slow, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_fast, 2);
   const double ema_mid_2  = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_mid, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_slow, 2);
   if(ema_fast_1 <= 0.0 || ema_mid_1 <= 0.0 || ema_slow_1 <= 0.0 ||
      ema_fast_2 <= 0.0 || ema_mid_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool long_cross = (ema_fast_2 <= ema_mid_2 &&
                            ema_fast_1 > ema_mid_1 &&
                            ema_fast_1 > ema_slow_1 &&
                            ema_mid_1 > ema_slow_1);
   const bool short_cross = (ema_fast_2 >= ema_mid_2 &&
                             ema_fast_1 < ema_mid_1 &&
                             ema_fast_1 < ema_slow_1 &&
                             ema_mid_1 < ema_slow_1);
   if(!long_cross && !short_cross)
      return false;

   const bool psar_h1_bull = Strategy_PSARBullish(strategy_signal_tf, 1);
   const bool psar_h1_bear = Strategy_PSARBearish(strategy_signal_tf, 1);
   const bool psar_m15_bull = Strategy_PSARBullish(strategy_psar_confirm_tf, 1);
   const bool psar_m15_bear = Strategy_PSARBearish(strategy_psar_confirm_tf, 1);

   QM_OrderType side = QM_BUY;
   if(long_cross && psar_h1_bull && psar_m15_bull)
      side = QM_BUY;
   else if(short_cross && psar_h1_bear && psar_m15_bear)
      side = QM_SELL;
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl = Strategy_InitialStop(side, entry, ema_slow_1);
   if(entry <= 0.0 || sl <= 0.0)
      return false;
   if((side == QM_BUY && sl >= entry) || (side == QM_SELL && sl <= entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "FPS_EMA3_PSAR_LONG" : "FPS_EMA3_PSAR_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_TrailTicketToEMA50(const ulong ticket)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return;
   if((int)PositionGetInteger(POSITION_MAGIC) != QM_FrameworkMagic())
      return;

   const double ema50 = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_slow, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ema50 <= 0.0 || point <= 0.0)
      return;

   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double buffer = strategy_ema50_buffer_points * point;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double target = QM_StopRulesNormalizePrice(_Symbol, ema50 - buffer);
      if(bid > open_price && target > 0.0 && target < bid &&
         (current_sl <= 0.0 || target > current_sl + point * 0.5))
         QM_TM_MoveSL(ticket, target, "FPS_TRAIL_EMA50_LONG");
      return;
     }

   if(position_type == POSITION_TYPE_SELL)
     {
      const double target = QM_StopRulesNormalizePrice(_Symbol, ema50 + buffer);
      if(ask < open_price && target > ask &&
         (current_sl <= 0.0 || target < current_sl - point * 0.5))
         QM_TM_MoveSL(ticket, target, "FPS_TRAIL_EMA50_SHORT");
     }
  }

bool Strategy_PositionCrossedAllEMAs(const ENUM_POSITION_TYPE position_type)
  {
   double close_1 = 0.0;
   if(!Strategy_ReadClose(_Symbol, strategy_signal_tf, 1, close_1))
      return false;

   const double ema_fast = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_fast, 1);
   const double ema_mid  = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_mid, 1);
   const double ema_slow = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_slow, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
      return (close_1 < ema_fast && close_1 < ema_mid && close_1 < ema_slow);
   if(position_type == POSITION_TYPE_SELL)
      return (close_1 > ema_fast && close_1 > ema_mid && close_1 > ema_slow);
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      Strategy_TrailTicketToEMA50(ticket);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(Strategy_PositionCrossedAllEMAs(position_type))
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
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
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
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
