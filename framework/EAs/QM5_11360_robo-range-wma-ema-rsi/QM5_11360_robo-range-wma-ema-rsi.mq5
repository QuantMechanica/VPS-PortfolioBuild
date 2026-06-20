#property strict
#property version   "5.0"
#property description "QM5_11360 RoboForex The Range WMA/EMA/RSI"

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
input int    qm_ea_id                   = 11360;
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
input int    strategy_wma_fast_period       = 5;
input int    strategy_wma_slow_period       = 12;
input int    strategy_ema_fast_period       = 16;
input int    strategy_ema_slow_period       = 30;
input int    strategy_rsi_period            = 14;
input double strategy_rsi_midline           = 50.0;
input int    strategy_stop_buffer_pips      = 5;
input int    strategy_max_stop_pips         = 20;
input int    strategy_max_spread_pips       = 5;
input int    strategy_session_start_hour    = 9;
input int    strategy_session_end_hour      = 23;

bool Strategy_IsValidNumber(const double value)
  {
   return (value > 0.0 && MathIsValidNumber(value));
  }

bool Strategy_InSession(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   if(strategy_session_start_hour == strategy_session_end_hour)
      return true;
   if(strategy_session_start_hour < strategy_session_end_hour)
      return (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
   return (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
  }

bool Strategy_SpreadOK()
  {
   if(strategy_max_spread_pips <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(ask <= 0.0 || bid <= 0.0 || cap <= 0.0)
      return false;

   if(ask > bid && (ask - bid) > cap)
      return false;
   return true;
  }

double Strategy_ChannelStop(const QM_OrderType side, const double entry_price)
  {
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_buffer_pips);
   const double max_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_stop_pips);
   if(!Strategy_IsValidNumber(ema_slow) || buffer <= 0.0 || max_distance <= 0.0 || entry_price <= 0.0)
      return 0.0;

   double stop = 0.0;
   if(side == QM_BUY)
     {
      stop = ema_slow - buffer;
      if(stop >= entry_price)
         return 0.0;
      if((entry_price - stop) > max_distance)
         stop = entry_price - max_distance;
     }
   else if(side == QM_SELL)
     {
      stop = ema_slow + buffer;
      if(stop <= entry_price)
         return 0.0;
      if((stop - entry_price) > max_distance)
         stop = entry_price + max_distance;
     }
   else
      return 0.0;

   return QM_StopRulesNormalizePrice(_Symbol, stop);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_InSession(TimeCurrent()))
      return true;
   if(!Strategy_SpreadOK())
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_wma_fast_period <= 0 ||
      strategy_wma_slow_period <= 0 ||
      strategy_ema_fast_period <= 0 ||
      strategy_ema_slow_period <= 0 ||
      strategy_rsi_period <= 0)
      return false;

   const double wma12_now  = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 1);
   const double wma12_prev = QM_WMA(_Symbol, _Period, strategy_wma_slow_period, 2);
   const double wma5_now   = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 1);
   const double ema16_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema30_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema30_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   const double rsi_now    = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);

   if(!Strategy_IsValidNumber(wma12_now) ||
      !Strategy_IsValidNumber(wma12_prev) ||
      !Strategy_IsValidNumber(wma5_now) ||
      !Strategy_IsValidNumber(ema16_now) ||
      !Strategy_IsValidNumber(ema30_now) ||
      !Strategy_IsValidNumber(ema30_prev) ||
      !Strategy_IsValidNumber(rsi_now))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   const bool long_cross = (wma12_prev < ema30_prev && wma12_now >= ema30_now);
   const bool long_filter = (wma5_now > ema16_now && wma5_now > ema30_now && rsi_now > strategy_rsi_midline);
   if(long_cross && long_filter && ask > 0.0)
     {
      req.type = QM_BUY;
      req.sl = Strategy_ChannelStop(req.type, ask);
      if(req.sl <= 0.0)
         return false;
      req.reason = "WMA12_CROSS_ABOVE_EMA30_RSI";
      return true;
     }

   const bool short_cross = (wma12_prev > ema30_prev && wma12_now <= ema30_now);
   const bool short_filter = (wma5_now < ema16_now && wma5_now < ema30_now && rsi_now < strategy_rsi_midline);
   if(short_cross && short_filter && bid > 0.0)
     {
      req.type = QM_SELL;
      req.sl = Strategy_ChannelStop(req.type, bid);
      if(req.sl <= 0.0)
         return false;
      req.reason = "WMA12_CROSS_BELOW_EMA30_RSI";
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or scale-in logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double wma5_now   = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 1);
   const double wma5_prev  = QM_WMA(_Symbol, _Period, strategy_wma_fast_period, 2);
   const double ema16_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema16_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double rsi_now    = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev   = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);

   if(!Strategy_IsValidNumber(wma5_now) ||
      !Strategy_IsValidNumber(wma5_prev) ||
      !Strategy_IsValidNumber(ema16_now) ||
      !Strategy_IsValidNumber(ema16_prev) ||
      !Strategy_IsValidNumber(rsi_now) ||
      !Strategy_IsValidNumber(rsi_prev))
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         if(wma5_prev > ema16_prev && wma5_now <= ema16_now)
            return true;
         if(rsi_prev > strategy_rsi_midline && rsi_now <= strategy_rsi_midline)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(wma5_prev < ema16_prev && wma5_now >= ema16_now)
            return true;
         if(rsi_prev < strategy_rsi_midline && rsi_now >= strategy_rsi_midline)
            return true;
        }
     }

   return false;
  }

// News Filter Hook
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
