#property strict
#property version   "5.0"
#property description "QM5_20138 stoch-ema50-pullback-h4 (V5)"

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
input int    strategy_stoch_k          = 5;
input int    strategy_stoch_d          = 3;
input int    strategy_stoch_slowing    = 3;
input double strategy_zone_low         = 20.0;
input double strategy_zone_high        = 80.0;
input int    strategy_ema_period       = 50;
input double strategy_sl_buffer_pips   = 10.0;
input double strategy_tp_r             = 3.0;

int      g_str085_stoch_handle = INVALID_HANDLE;
int      g_str085_ema_handle = INVALID_HANDLE;
datetime g_str085_last_entry_bar = 0;
datetime g_str085_last_rejected_trail_bar = 0;
datetime g_str085_last_data_log_bar = 0;
ulong    g_str085_managed_position_id = 0;

bool Strategy085_ConfigValid()
  {
   return (strategy_stoch_k > 0 &&
           strategy_stoch_d > 0 &&
           strategy_stoch_slowing > 0 &&
           strategy_ema_period > 1 &&
           MathIsValidNumber(strategy_zone_low) &&
           MathIsValidNumber(strategy_zone_high) &&
           strategy_zone_low >= 0.0 &&
           strategy_zone_high <= 100.0 &&
           strategy_zone_low < strategy_zone_high &&
           MathIsValidNumber(strategy_sl_buffer_pips) &&
           strategy_sl_buffer_pips > 0.0 &&
           MathIsValidNumber(strategy_tp_r) &&
           strategy_tp_r > 0.0);
  }

int Strategy085_CloseCloseStochHandle()
  {
   const string key =
      StringFormat("STOCH_CC|%s|%d|%d|%d|%d",
                   _Symbol,
                   (int)PERIOD_H4,
                   strategy_stoch_k,
                   strategy_stoch_d,
                   strategy_stoch_slowing);
   int handle = QM_IndicatorsLookup(key);
   if(handle != INVALID_HANDLE)
      return handle;
   handle =
      iStochastic(_Symbol, // perf-allowed: STO_CLOSECLOSE unavailable via QM_IndStoch (STO_LOWHIGH only); handle is QM_IndicatorsRegister-pooled, not lazy
                  PERIOD_H4,
                  strategy_stoch_k,
                  strategy_stoch_d,
                  strategy_stoch_slowing,
                  MODE_SMA,
                  STO_CLOSECLOSE);
   return QM_IndicatorsRegister(key, handle);
  }

bool Strategy085_EnsureHandles()
  {
   if(g_str085_stoch_handle == INVALID_HANDLE)
      g_str085_stoch_handle =
         Strategy085_CloseCloseStochHandle();
   if(g_str085_ema_handle == INVALID_HANDLE)
      g_str085_ema_handle =
         QM_IndMA(_Symbol,
                  PERIOD_H4,
                  strategy_ema_period,
                  MODE_EMA,
                  PRICE_CLOSE);
   return (g_str085_stoch_handle != INVALID_HANDLE &&
           g_str085_ema_handle != INVALID_HANDLE);
  }

bool Strategy085_HandlesReady()
  {
   if(!Strategy085_EnsureHandles())
      return false;
   int required = 60;
   if(strategy_ema_period + 5 > required)
      required = strategy_ema_period + 5;
   if(strategy_stoch_k + strategy_stoch_d +
      strategy_stoch_slowing + 5 > required)
      required = strategy_stoch_k +
                 strategy_stoch_d +
                 strategy_stoch_slowing + 5;
   return (QM_IndicatorWarmupReady(g_str085_stoch_handle,
                                   0, 1, required, "STR-085_stoch") &&
           QM_IndicatorWarmupReady(g_str085_ema_handle,
                                   0, 1, required, "STR-085_ema"));
  }

bool Strategy085_CurrentBar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H4,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-H4 clock for entry and rejected-modify pacing
   return (bar_time > 0);
  }

void Strategy085_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str085_last_data_log_bar)
      return;
   g_str085_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-085\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

bool Strategy085_IndicatorValid(const double value)
  {
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE &&
           value >= 0.0);
  }

double Strategy085_TradeTick()
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

double Strategy085_PipSize()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

double Strategy085_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy085_TradeTick();
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

bool Strategy085_FindOwnPosition(
   ulong &ticket,
   ENUM_POSITION_TYPE &position_type,
   double &open_price,
   double &current_sl,
   double &current_tp,
   ulong &position_id)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   current_tp = 0.0;
   position_id = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
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
      current_tp =
         PositionGetDouble(POSITION_TP);
      position_id =
         (ulong)PositionGetInteger(
            POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

bool Strategy085_HasOwnPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   ulong position_id = 0;
   return Strategy085_FindOwnPosition(ticket,
                                      position_type,
                                      open_price,
                                      current_sl,
                                      current_tp,
                                      position_id);
  }

bool Strategy085_EntryGeometryLegal(
   const bool buy_side,
   const double entry,
   const double sl,
   const double tp)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy085_TradeTick();
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

bool Strategy085_PositionStopLegal(
   const ENUM_POSITION_TYPE position_type,
   const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy085_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      candidate <= 0.0)
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
   if(_Period != PERIOD_H4 ||
      !Strategy085_ConfigValid())
      return !Strategy085_HasOwnPosition();
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   if(Strategy085_HasOwnPosition())
      return false;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H4,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) warmup gate
   if(bars_available < 60)
      return true;
   return !Strategy085_HandlesReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy085_CurrentBar(forming_time))
     {
      Strategy085_LogDataMissing("forming_h4_bar", 0);
      return false;
     }
   if(forming_time == g_str085_last_entry_bar)
      return false;
   g_str085_last_entry_bar = forming_time;

   if(_Period != PERIOD_H4 ||
      !Strategy085_ConfigValid() ||
      Strategy085_HasOwnPosition() ||
      !Strategy085_HandlesReady())
      return false;

   const double k_1 =
      QM_IndicatorReadBuffer(g_str085_stoch_handle, 0, 1); // perf-allowed: pooled one-value CopyBuffer, closed H4 shift 1
   const double d_1 =
      QM_IndicatorReadBuffer(g_str085_stoch_handle, 1, 1); // perf-allowed: pooled one-value CopyBuffer, closed H4 shift 1
   const double k_2 =
      QM_IndicatorReadBuffer(g_str085_stoch_handle, 0, 2); // perf-allowed: pooled one-value CopyBuffer, closed H4 shift 2
   const double d_2 =
      QM_IndicatorReadBuffer(g_str085_stoch_handle, 1, 2); // perf-allowed: pooled one-value CopyBuffer, closed H4 shift 2
   const double ema_1 =
      QM_IndicatorReadBuffer(g_str085_ema_handle, 0, 1); // perf-allowed: pooled one-value CopyBuffer, closed H4 shift 1
   const double ema_2 =
      QM_IndicatorReadBuffer(g_str085_ema_handle, 0, 2); // perf-allowed: pooled one-value CopyBuffer, closed H4 shift 2
   MqlRates signal_bar;
   if(!Strategy085_IndicatorValid(k_1) ||
      !Strategy085_IndicatorValid(d_1) ||
      !Strategy085_IndicatorValid(k_2) ||
      !Strategy085_IndicatorValid(d_2) ||
      !Strategy085_IndicatorValid(ema_1) ||
      !Strategy085_IndicatorValid(ema_2) ||
      ema_1 <= 0.0 || ema_2 <= 0.0 ||
      !QM_ReadBar(_Symbol, PERIOD_H4, 1, signal_bar)) // perf-allowed: one closed-H4 CopyRates record for the signal-bar extreme
     {
      Strategy085_LogDataMissing("closed_h4_inputs",
                                 forming_time);
      return false;
     }

   const bool long_signal =
      (k_2 <= d_2 &&
       k_1 > d_1 &&
       k_1 <= strategy_zone_low &&
       d_1 <= strategy_zone_low &&
       ema_1 > ema_2);
   const bool short_signal =
      (k_2 >= d_2 &&
       k_1 < d_1 &&
       k_1 >= strategy_zone_high &&
       d_1 >= strategy_zone_high &&
       ema_1 < ema_2);
   if(long_signal == short_signal)
      return false;

   const bool buy_side = long_signal;
   const double entry =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double pip = Strategy085_PipSize();
   const double buffer =
      strategy_sl_buffer_pips * pip;
   if(entry <= 0.0 || pip <= 0.0 ||
      buffer <= 0.0 ||
      signal_bar.low <= 0.0 ||
      signal_bar.high <= signal_bar.low)
      return false;

   const double sl =
      Strategy085_AlignPrice(
         buy_side
         ? signal_bar.low - buffer
         : signal_bar.high + buffer,
         buy_side ? -1 : 1);
   const double risk = MathAbs(entry - sl);
   const double tp =
      Strategy085_AlignPrice(
         buy_side
         ? entry + strategy_tp_r * risk
         : entry - strategy_tp_r * risk,
         buy_side ? 1 : -1);
   if(risk <= 0.0 ||
      !Strategy085_EntryGeometryLegal(buy_side,
                                      entry,
                                      sl,
                                      tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-085\",\"reason\":\"entry_geometry\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            (long)forming_time,
            entry,
            sl,
            tp));
      return false;
     }

   req.type = buy_side ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      buy_side
      ? "STR085_STOCH_EMA_LONG"
      : "STR085_STOCH_EMA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   ulong position_id = 0;
   if(!Strategy085_FindOwnPosition(ticket,
                                   position_type,
                                   open_price,
                                   current_sl,
                                   current_tp,
                                   position_id))
     {
      g_str085_managed_position_id = 0;
      g_str085_last_rejected_trail_bar = 0;
      return;
     }

   if(position_id != g_str085_managed_position_id)
     {
      g_str085_managed_position_id = position_id;
      g_str085_last_rejected_trail_bar = 0;
     }

   datetime forming_time = 0;
   if(!Strategy085_CurrentBar(forming_time))
      return;
   if(g_str085_last_rejected_trail_bar == forming_time)
      return;
   if(open_price <= 0.0 ||
      current_tp <= 0.0 ||
      strategy_tp_r <= 0.0)
      return;

   // The original R survives stop ratchets because TP is fixed at exactly 3R.
   const double initial_r =
      MathAbs(current_tp - open_price) /
      strategy_tp_r;
   const double tick = Strategy085_TradeTick();
   if(initial_r <= 0.0 || tick <= 0.0)
      return;

   const bool buy_side =
      (position_type == POSITION_TYPE_BUY);
   const double market =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;
   const double candidate =QM_TM_NormalizePrice(_Symbol, Strategy085_AlignPrice(
         buy_side
         ? market - initial_r
         : market + initial_r,
         buy_side ? -1 : 1));
   const bool tightens =
      (candidate > 0.0) &&
      (buy_side
       ? candidate > current_sl + tick * 0.5
       : (current_sl <= 0.0 ||
          candidate < current_sl - tick * 0.5));
   if(!tightens ||
      !Strategy085_PositionStopLegal(position_type,
                                     candidate))
      return;

   if(QM_TM_MoveSL(ticket,
                   candidate,
                   "STR085_FIXED_ORIGINAL_R_TRAIL"))
      g_str085_last_rejected_trail_bar = 0;
   else
      // A rejected modify is retried no earlier than the next forming H4 bar.
      g_str085_last_rejected_trail_bar = forming_time;
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // central fail-closed news gate remains authoritative
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
