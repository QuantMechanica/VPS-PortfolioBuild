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
input int    strategy_bb_period             = 20;
input double strategy_bb_outer_stddev       = 3.0;
input double strategy_bb_inner_stddev       = 2.0;
input int    strategy_adx_period            = 14;
input double strategy_adx_max_for_range     = 25.0;
input int    strategy_sl_pips               = 18;
input double strategy_rr_target_partial     = 1.0;
input double strategy_rr_target_full        = 2.0;
input int    strategy_trade_window_utc_start_hhmm = 600;
input int    strategy_trade_window_utc_end_hhmm   = 2000;
input double strategy_partial_close_fraction = 0.50;
input int    strategy_fractal_shift         = 2;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   const int hhmm = dt.hour * 100 + dt.min;

   if(strategy_trade_window_utc_start_hhmm <= strategy_trade_window_utc_end_hhmm)
      return (hhmm < strategy_trade_window_utc_start_hhmm ||
              hhmm >= strategy_trade_window_utc_end_hhmm);

   return (hhmm < strategy_trade_window_utc_start_hhmm &&
           hhmm >= strategy_trade_window_utc_end_hhmm);
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

   if(strategy_bb_period < 2 ||
      strategy_bb_outer_stddev <= strategy_bb_inner_stddev ||
      strategy_bb_inner_stddev <= 0.0 ||
      strategy_adx_period < 2 ||
      strategy_sl_pips <= 0 ||
      strategy_rr_target_full <= 0.0)
      return false;

   const double step1_close = iClose(_Symbol, PERIOD_CURRENT, 2); // perf-allowed: fixed closed-bar Step-1 close from the card.
   const double step2_close = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: fixed closed-bar Step-2 re-entry close from the card.
   const double step1_high = iHigh(_Symbol, PERIOD_CURRENT, 2);   // perf-allowed: fixed closed-bar Step-1 swing high for SL placement.
   const double step1_low = iLow(_Symbol, PERIOD_CURRENT, 2);     // perf-allowed: fixed closed-bar Step-1 swing low for SL placement.
   if(step1_close <= 0.0 || step2_close <= 0.0 || step1_high <= 0.0 || step1_low <= 0.0)
      return false;

   const double outer_upper_step1 = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_outer_stddev, 2);
   const double outer_lower_step1 = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_outer_stddev, 2);
   const double inner_upper_step2 = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_inner_stddev, 1);
   const double inner_lower_step2 = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_inner_stddev, 1);
   const double adx_step2 = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(outer_upper_step1 <= 0.0 || outer_lower_step1 <= 0.0 ||
      inner_upper_step2 <= 0.0 || inner_lower_step2 <= 0.0 ||
      adx_step2 <= 0.0 || sl_dist <= 0.0)
      return false;
   if(adx_step2 >= strategy_adx_max_for_range)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(step1_close >= outer_upper_step1 && step2_close < inner_upper_step2)
     {
      const double entry = bid;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, step1_high + sl_dist);
      if(sl <= entry)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target_full);
      req.reason = "LIEN_XTREME_FADE_SHORT";
      return (req.tp > 0.0);
     }

   if(step1_close <= outer_lower_step1 && step2_close > inner_lower_step2)
     {
      const double entry = ask;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, step1_low - sl_dist);
      if(sl >= entry)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target_full);
      req.reason = "LIEN_XTREME_FADE_LONG";
      return (req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || current_sl <= 0.0 || volume <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double risk_distance = MathAbs(open_price - current_sl);
      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(current_tp > 0.0 && risk_distance > 0.0 && moved >= risk_distance * strategy_rr_target_partial)
        {
         double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_close_fraction);
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(close_lots >= min_lot && close_lots < volume)
           {
            if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
               QM_TM_MoveTP(ticket, 0.0, "partial_1r_remove_full_tp_for_fractal_trail");
           }
         continue;
        }

      if(current_tp > 0.0)
         continue;

      const double fractal = is_buy ? QM_FractalLower(_Symbol, PERIOD_CURRENT, strategy_fractal_shift)
                                    : QM_FractalUpper(_Symbol, PERIOD_CURRENT, strategy_fractal_shift);
      if(fractal <= 0.0 || fractal == EMPTY_VALUE)
         continue;

      const double target_sl = QM_TM_NormalizePrice(_Symbol, fractal);
      if(target_sl <= 0.0)
         continue;

      if(is_buy)
        {
         if(target_sl > current_sl && target_sl < market_price)
            QM_TM_MoveSL(ticket, target_sl, "trail_long_m15_fractal");
        }
      else
        {
         if(target_sl < current_sl && target_sl > market_price)
            QM_TM_MoveSL(ticket, target_sl, "trail_short_m15_fractal");
        }
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
