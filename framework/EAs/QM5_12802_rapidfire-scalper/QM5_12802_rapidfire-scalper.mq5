#property strict
#property version   "5.0"
#property description "QM5_12802 RapidFire Scalper"

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
input int    qm_ea_id                   = 12802;
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
input ENUM_TIMEFRAMES strategy_timeframe                  = PERIOD_M5;
input int             strategy_sma_period                 = 60;
input double          strategy_sar_step                   = 0.20;
input double          strategy_sar_maximum                = 0.20;
input int             strategy_profile_mode               = 0;      // 0=auto, 1=fixed-points, 2=percent-of-price.
input int             strategy_fixed_sl_points            = 200;
input int             strategy_fixed_tp_points            = 200;
input double          strategy_percent_sl                 = 0.40;
input double          strategy_percent_tp                 = 0.40;
input int             strategy_session_start_hour_broker  = 8;
input int             strategy_session_end_hour_broker    = 23;
input bool            strategy_allow_monday               = true;
input bool            strategy_allow_tuesday              = true;
input bool            strategy_allow_wednesday            = true;
input bool            strategy_allow_thursday             = true;
input bool            strategy_allow_friday               = true;
input bool            strategy_allow_saturday             = false;
input bool            strategy_allow_sunday               = false;
input int             strategy_trailing_mode              = 1;      // 0=off, 1=fixed, 2=previous-candle, 3=fast-EMA.
input int             strategy_trailing_trigger_points    = 20;
input int             strategy_trailing_points            = 10;
input double          strategy_trailing_trigger_pct_of_sl = 10.0;
input double          strategy_trailing_distance_pct_of_sl = 5.0;
input int             strategy_previous_candle_shift      = 1;
input int             strategy_fast_ma_period             = 5;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   bool allowed_day = false;
   if(now.day_of_week == 0)
      allowed_day = strategy_allow_sunday;
   else if(now.day_of_week == 1)
      allowed_day = strategy_allow_monday;
   else if(now.day_of_week == 2)
      allowed_day = strategy_allow_tuesday;
   else if(now.day_of_week == 3)
      allowed_day = strategy_allow_wednesday;
   else if(now.day_of_week == 4)
      allowed_day = strategy_allow_thursday;
   else if(now.day_of_week == 5)
      allowed_day = strategy_allow_friday;
   else if(now.day_of_week == 6)
      allowed_day = strategy_allow_saturday;

   bool in_session = true;
   const int start_hour = strategy_session_start_hour_broker;
   const int end_hour = strategy_session_end_hour_broker;
   if(start_hour >= 0 && start_hour <= 23 && end_hour >= 0 && end_hour <= 23 && start_hour != end_hour)
     {
      if(start_hour < end_hour)
         in_session = (now.hour >= start_hour && now.hour < end_hour);
      else
         in_session = (now.hour >= start_hour || now.hour < end_hour);
     }

   if(allowed_day && in_session)
      return false;

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
      return false; // let Strategy_ExitSignal force-flat the session/day breach.
     }

   return true;
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

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   bool allowed_day = false;
   if(now.day_of_week == 0)
      allowed_day = strategy_allow_sunday;
   else if(now.day_of_week == 1)
      allowed_day = strategy_allow_monday;
   else if(now.day_of_week == 2)
      allowed_day = strategy_allow_tuesday;
   else if(now.day_of_week == 3)
      allowed_day = strategy_allow_wednesday;
   else if(now.day_of_week == 4)
      allowed_day = strategy_allow_thursday;
   else if(now.day_of_week == 5)
      allowed_day = strategy_allow_friday;
   else if(now.day_of_week == 6)
      allowed_day = strategy_allow_saturday;
   if(!allowed_day)
      return false;

   bool in_session = true;
   const int start_hour = strategy_session_start_hour_broker;
   const int end_hour = strategy_session_end_hour_broker;
   if(start_hour >= 0 && start_hour <= 23 && end_hour >= 0 && end_hour <= 23 && start_hour != end_hour)
     {
      if(start_hour < end_hour)
         in_session = (now.hour >= start_hour && now.hour < end_hour);
      else
         in_session = (now.hour >= start_hour || now.hour < end_hour);
     }
   if(!in_session)
      return false;

   if(strategy_sma_period <= 1 || strategy_sar_step <= 0.0 || strategy_sar_maximum <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double sma = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_period, 1, PRICE_CLOSE);
   const double sar = QM_SAR(_Symbol, strategy_timeframe, strategy_sar_step, strategy_sar_maximum, 1);
   if(sma <= 0.0 || sar <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   double entry_price = ask;
   if(ask > sma && ask > sar)
     {
      side = QM_BUY;
      entry_price = ask;
      req.reason = "RAPIDFIRE_SMA60_SAR_LONG";
     }
   else if(bid < sma && bid < sar)
     {
      side = QM_SELL;
      entry_price = bid;
      req.reason = "RAPIDFIRE_SMA60_SAR_SHORT";
     }
   else
      return false;

   bool percent_profile = false;
   if(strategy_profile_mode == 2)
      percent_profile = true;
   else if(strategy_profile_mode == 0 && StringFind(_Symbol, "XAU") >= 0)
      percent_profile = true;

   double sl_distance = 0.0;
   double tp_distance = 0.0;
   if(percent_profile)
     {
      if(strategy_percent_sl <= 0.0 || strategy_percent_tp <= 0.0)
         return false;
      sl_distance = entry_price * strategy_percent_sl / 100.0;
      tp_distance = entry_price * strategy_percent_tp / 100.0;
     }
   else
     {
      if(strategy_fixed_sl_points <= 0 || strategy_fixed_tp_points <= 0)
         return false;
      sl_distance = strategy_fixed_sl_points * point;
      tp_distance = strategy_fixed_tp_points * point;
     }

   if(sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, QM_OrderTypeIsBuy(side) ? entry_price - sl_distance : entry_price + sl_distance);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, QM_OrderTypeIsBuy(side) ? entry_price + tp_distance : entry_price - tp_distance);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   // Trade Entry: source trend-stack, single-position enforcement is handled by QM_Entry.
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(strategy_trailing_mode <= 0)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || bid <= 0.0 || ask <= 0.0)
         continue;

      bool percent_profile = false;
      if(strategy_profile_mode == 2)
         percent_profile = true;
      else if(strategy_profile_mode == 0 && StringFind(_Symbol, "XAU") >= 0)
         percent_profile = true;

      double base_sl_distance = 0.0;
      double trigger_distance = 0.0;
      double trail_distance = 0.0;
      if(percent_profile)
        {
         base_sl_distance = open_price * strategy_percent_sl / 100.0;
         trigger_distance = base_sl_distance * strategy_trailing_trigger_pct_of_sl / 100.0;
         trail_distance = base_sl_distance * strategy_trailing_distance_pct_of_sl / 100.0;
        }
      else
        {
         trigger_distance = strategy_trailing_trigger_points * point;
         trail_distance = strategy_trailing_points * point;
        }
      if(trigger_distance <= 0.0 || trail_distance <= 0.0)
         continue;

      const double market = is_buy ? bid : ask;
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < trigger_distance)
         continue;

      double new_sl = 0.0;
      if(strategy_trailing_mode == 1)
         new_sl = is_buy ? (bid - trail_distance) : (ask + trail_distance);
      else if(strategy_trailing_mode == 2)
        {
         const int shift = (strategy_previous_candle_shift < 1) ? 1 : strategy_previous_candle_shift;
         new_sl = is_buy ? iLow(_Symbol, strategy_timeframe, shift)   // perf-allowed: single closed-bar candle trail read.
                         : iHigh(_Symbol, strategy_timeframe, shift); // perf-allowed: single closed-bar candle trail read.
        }
      else if(strategy_trailing_mode == 3)
         new_sl = QM_EMA(_Symbol, strategy_timeframe, strategy_fast_ma_period, 1, PRICE_CLOSE);
      else
         continue;

      new_sl = QM_StopRulesNormalizePrice(_Symbol, new_sl);
      if(new_sl <= 0.0)
         continue;

      if(is_buy)
        {
         if(new_sl > current_sl + point * 0.5 && new_sl > open_price && new_sl < bid)
            QM_TM_MoveSL(ticket, new_sl, "RAPIDFIRE_TRAIL_LONG");
        }
      else
        {
         if((current_sl <= 0.0 || new_sl < current_sl - point * 0.5) && new_sl < open_price && new_sl > ask)
            QM_TM_MoveSL(ticket, new_sl, "RAPIDFIRE_TRAIL_SHORT");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   bool allowed_day = false;
   if(now.day_of_week == 0)
      allowed_day = strategy_allow_sunday;
   else if(now.day_of_week == 1)
      allowed_day = strategy_allow_monday;
   else if(now.day_of_week == 2)
      allowed_day = strategy_allow_tuesday;
   else if(now.day_of_week == 3)
      allowed_day = strategy_allow_wednesday;
   else if(now.day_of_week == 4)
      allowed_day = strategy_allow_thursday;
   else if(now.day_of_week == 5)
      allowed_day = strategy_allow_friday;
   else if(now.day_of_week == 6)
      allowed_day = strategy_allow_saturday;

   bool in_session = true;
   const int start_hour = strategy_session_start_hour_broker;
   const int end_hour = strategy_session_end_hour_broker;
   if(start_hour >= 0 && start_hour <= 23 && end_hour >= 0 && end_hour <= 23 && start_hour != end_hour)
     {
      if(start_hour < end_hour)
         in_session = (now.hour >= start_hour && now.hour < end_hour);
      else
         in_session = (now.hour >= start_hour || now.hour < end_hour);
     }

   return (!allowed_day || !in_session);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
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
