#property strict
#property version   "5.0"
#property description "QM5_9984 TradingView BB Outside-Candle Scalping"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
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
input int    qm_ea_id                   = 9984;
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
// FW1 2026-05-23 - Two-axis news filter per Vault Q09.
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
// FW2 2026-05-23 - only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period                 = 20;
input double strategy_bb_deviation              = 2.0;
input int    strategy_ema_tp1_period            = 8;
input int    strategy_ema_tp2_period            = 12;
input int    strategy_ema_tp3_period            = 26;
input bool   strategy_use_ema200_filter         = true;
input int    strategy_trend_ema_period          = 200;
input int    strategy_atr_period                = 14;
input double strategy_atr_sl_mult               = 1.0;
input double strategy_spread_atr_mult           = 0.6;
input bool   strategy_skip_first_session_bar    = true;
input int    strategy_session_start_hour_broker = 0;
input int    strategy_session_start_min_broker  = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(strategy_spread_atr_mult > 0.0 && ask > bid)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
      if(atr > 0.0 && (ask - bid) > strategy_spread_atr_mult * atr)
         return true;
     }

   if(strategy_skip_first_session_bar)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      const int tf_minutes = PeriodSeconds(PERIOD_CURRENT) / 60;
      const int current_minutes = dt.hour * 60 + dt.min;
      const int session_minutes = strategy_session_start_hour_broker * 60 + strategy_session_start_min_broker;
      const int window_minutes = (tf_minutes > 0) ? tf_minutes : 5;
      if(current_minutes >= session_minutes && current_minutes < session_minutes + window_minutes)
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

   if(strategy_bb_period < 2 ||
      strategy_bb_deviation <= 0.0 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   const double upper = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(upper <= 0.0 || lower <= 0.0 || atr <= 0.0)
      return false;

   const double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);   // perf-allowed: one closed candle endpoint required by card outside-band rule.
   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: one closed candle endpoint required by card outside-band rule.
   const double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);     // perf-allowed: one closed candle extreme required by card ATR SL rule.
   const double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);   // perf-allowed: one closed candle extreme required by card ATR SL rule.
   if(open1 <= 0.0 || close1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   if(strategy_use_ema200_filter)
     {
      const double trend_ema = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_trend_ema_period, 1, PRICE_CLOSE);
      if(trend_ema <= 0.0)
         return false;

      if(open1 > upper && close1 > upper && close1 <= trend_ema)
         return false;
      if(open1 < lower && close1 < lower && close1 >= trend_ema)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(open1 > upper && close1 > upper)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, low1 - atr * strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "BB_OUTSIDE_CANDLE_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(open1 < lower && close1 < lower)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, high1 + atr * strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "BB_OUTSIDE_CANDLE_SHORT";
      return (req.sl > bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   static ulong  tracked_tickets[32];
   static double initial_lots[32];
   static bool   tp1_done[32];
   static bool   tp2_done[32];
   static bool   tp3_done[32];

   for(int s = 0; s < 32; ++s)
     {
      if(tracked_tickets[s] != 0 && !PositionSelectByTicket(tracked_tickets[s]))
        {
         tracked_tickets[s] = 0;
         initial_lots[s] = 0.0;
         tp1_done[s] = false;
         tp2_done[s] = false;
         tp3_done[s] = false;
        }
     }

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

      int slot = -1;
      int empty_slot = -1;
      for(int s = 0; s < 32; ++s)
        {
         if(tracked_tickets[s] == ticket)
            slot = s;
         if(empty_slot < 0 && tracked_tickets[s] == 0)
            empty_slot = s;
        }

      if(slot < 0)
        {
         if(empty_slot < 0)
            return;
         slot = empty_slot;
         tracked_tickets[slot] = ticket;
         initial_lots[slot] = PositionGetDouble(POSITION_VOLUME);
         tp1_done[slot] = false;
         tp2_done[slot] = false;
         tp3_done[slot] = false;
        }

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_lots = PositionGetDouble(POSITION_VOLUME);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || current_lots <= 0.0 || bid <= 0.0 || ask <= 0.0)
         continue;

      const double target1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_tp1_period, 1, PRICE_CLOSE);
      const double target2 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_tp2_period, 1, PRICE_CLOSE);
      const double target3 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_tp3_period, 1, PRICE_CLOSE);
      if(target1 <= 0.0 || target2 <= 0.0 || target3 <= 0.0)
         continue;

      bool hit1 = false;
      bool hit2 = false;
      bool hit3 = false;
      if(is_buy)
        {
         hit1 = (target1 > open_price && bid >= target1);
         hit2 = (target2 > open_price && bid >= target2);
         hit3 = (target3 > open_price && bid >= target3);
        }
      else
        {
         hit1 = (target1 < open_price && ask <= target1);
         hit2 = (target2 < open_price && ask <= target2);
         hit3 = (target3 < open_price && ask <= target3);
        }

      double lots_to_close = 0.0;
      if(!tp1_done[slot] && hit1)
        {
         lots_to_close = QM_TM_NormalizeVolume(_Symbol, initial_lots[slot] * 0.33);
         if(lots_to_close > 0.0 && lots_to_close < current_lots && QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
            tp1_done[slot] = true;
         return;
        }

      if(!tp2_done[slot] && hit2)
        {
         lots_to_close = QM_TM_NormalizeVolume(_Symbol, initial_lots[slot] * 0.33);
         if(lots_to_close > 0.0 && lots_to_close < current_lots && QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
            tp2_done[slot] = true;
         return;
        }

      if(!tp3_done[slot] && hit3)
        {
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            tp3_done[slot] = true;
         return;
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   bool have_buy = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      have_position = true;
      have_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      break;
     }

   if(!have_position)
      return false;

   const double middle = QM_BB_Middle(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: one closed candle close required by card basis-cross exit.
   if(middle <= 0.0 || close1 <= 0.0)
      return false;

   if(have_buy && close1 < middle)
      return true;
   if(!have_buy && close1 > middle)
      return true;

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
// Framework wiring - do NOT edit below this line unless you know why.
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
   // FW1 - 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
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
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 - emit end-of-day equity snapshot if the day rolled
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
