#property strict
#property version   "5.0"
#property description "QM5_11736 RFS Cutting Points BB RSI ADX M5"

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
input int    qm_ea_id                   = 11736;
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
input int    strategy_bb_period         = 20;
input double strategy_bb_deviation      = 2.0;
input int    strategy_rsi_period        = 7;
input double strategy_rsi_oversold      = 30.0;
input double strategy_rsi_overbought    = 70.0;
input int    strategy_adx_period        = 14;
input double strategy_adx_max           = 30.0;
input int    strategy_sl_pips           = 3;
input int    strategy_trade_start_hour  = 0;
input int    strategy_trade_end_hour    = 24;
input int    strategy_max_spread_pips   = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_trade_start_hour != 0 || strategy_trade_end_hour != 24)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      const int start_hour = MathMax(0, MathMin(23, strategy_trade_start_hour));
      const int end_hour = MathMax(0, MathMin(24, strategy_trade_end_hour));
      bool in_session = true;
      if(start_hour < end_hour)
         in_session = (dt.hour >= start_hour && dt.hour < end_hour);
      else if(start_hour > end_hour)
         in_session = (dt.hour >= start_hour || dt.hour < end_hour);
      if(!in_session)
         return true;
     }

   if(strategy_max_spread_pips > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
      if(ask > 0.0 && bid > 0.0 && ask > bid && max_spread > 0.0 && (ask - bid) > max_spread)
         return true;
     }

   return false;
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

   if(strategy_bb_period <= 1 || strategy_rsi_period <= 1 || strategy_adx_period <= 1 ||
      strategy_bb_deviation <= 0.0 || strategy_sl_pips <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double lower_setup = QM_BB_Lower(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 2, PRICE_CLOSE);
   const double upper_setup = QM_BB_Upper(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 2, PRICE_CLOSE);
   const double lower_return = QM_BB_Lower(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double upper_return = QM_BB_Upper(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double middle_return = QM_BB_Middle(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double rsi_setup = QM_RSI(_Symbol, tf, strategy_rsi_period, 2, PRICE_CLOSE);
   const double adx_setup = QM_ADX(_Symbol, tf, strategy_adx_period, 2);
   // perf-allowed: single closed-bar close reads implement the card's return-close trigger; no QM close reader exists.
   const double close_setup = iClose(_Symbol, tf, 2);
   const double close_return = iClose(_Symbol, tf, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(lower_setup <= 0.0 || upper_setup <= 0.0 || lower_return <= 0.0 ||
      upper_return <= 0.0 || middle_return <= 0.0 || close_setup <= 0.0 ||
      close_return <= 0.0 || sl_buffer <= 0.0 || point <= 0.0)
      return false;

   if(close_setup <= lower_setup && rsi_setup < strategy_rsi_oversold &&
      adx_setup < strategy_adx_max && close_return > lower_return && ask > 0.0)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, lower_return - sl_buffer);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, middle_return);
      if(sl <= 0.0 || tp <= 0.0 || sl >= ask - point || tp <= ask + point)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "cutting_points_bb_rsi_adx_long";
      return true;
     }

   if(close_setup >= upper_setup && rsi_setup > strategy_rsi_overbought &&
      adx_setup < strategy_adx_max && close_return < upper_return && bid > 0.0)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, upper_return + sl_buffer);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, middle_return);
      if(sl <= 0.0 || tp <= 0.0 || sl <= bid + point || tp >= bid - point)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "cutting_points_bb_rsi_adx_short";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double mid = QM_BB_Middle(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(magic <= 0 || mid <= 0.0 || point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double target_tp = QM_StopRulesNormalizePrice(_Symbol, mid);
      if(target_tp <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         if(bid <= 0.0 || target_tp <= bid + point)
            continue;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         if(ask <= 0.0 || target_tp >= ask - point)
            continue;
        }
      else
         continue;

      if(current_tp <= 0.0 || MathAbs(current_tp - target_tp) > point * 0.5)
         QM_TM_MoveTP(ticket, target_tp, "bb_middle_dynamic_tp");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // framework enforces the card's 30-minute high-impact news blackout
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
