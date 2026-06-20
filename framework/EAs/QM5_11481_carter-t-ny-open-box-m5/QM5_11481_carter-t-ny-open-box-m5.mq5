#property strict
#property version   "5.0"
#property description "QM5_11481 Carter-T NY Open Box Breakout M5"

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
input int    qm_ea_id                   = 11481;
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
input int    strategy_box_bars                 = 12;
input int    strategy_box_start_shift          = 12;
input double strategy_breakout_fraction        = 0.20;
input double strategy_tp_box_mult              = 4.0;
input int    strategy_order_valid_minutes      = 60;
input int    strategy_position_time_stop_minutes = 120;
input int    strategy_box_max_pips             = 60;
input int    strategy_spread_cap_pips          = 15;
input int    strategy_ny_open_utc_hour         = 13;
input int    strategy_ny_open_utc_minute       = 0;
input bool   strategy_skip_friday_entries      = true;

int g_session_order_day_key = 0;

int Strategy_DateKeyUTC(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(broker_time), dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

bool Strategy_CurrentBarOpenUTC(MqlDateTime &utc_bar)
  {
   datetime bar_times[];
   ArrayResize(bar_times, 1);
   const int copied = CopyTime(_Symbol, PERIOD_M5, 0, 1, bar_times); // perf-allowed: one current M5 bar time inside closed-bar entry hook
   if(copied != 1 || bar_times[0] <= 0)
      return false;
   TimeToStruct(QM_BrokerToUTC(bar_times[0]), utc_bar);
   return true;
  }

bool Strategy_IsFridayUTC(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(broker_time), dt);
   return (dt.day_of_week == 5);
  }

bool Strategy_ReadBox(double &box_high, double &box_low)
  {
   box_high = 0.0;
   box_low = 0.0;
   if(strategy_box_bars <= 0 || strategy_box_start_shift < 1)
      return false;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_M5, strategy_box_start_shift, strategy_box_bars, rates); // perf-allowed: bounded 12-bar Carter box inside closed-bar entry hook
   if(copied != strategy_box_bars)
      return false;

   box_high = rates[0].high;
   box_low = rates[0].low;
   for(int i = 1; i < copied; ++i)
     {
      if(rates[i].high > box_high)
         box_high = rates[i].high;
      if(rates[i].low < box_low)
         box_low = rates[i].low;
     }

   return (box_high > box_low && box_low > 0.0);
  }

bool Strategy_IsOurPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
      return true;
     }
   return false;
  }

bool Strategy_HasOurPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_RemoveOurPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_RemoveExpiredPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_order_valid_minutes <= 0)
      return;

   const datetime now = TimeCurrent();
   const int max_age = strategy_order_valid_minutes * 60;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= max_age)
         QM_TM_RemovePendingOrder(ticket, "CARTER_ORDER_EXPIRY");
     }
  }

void Strategy_CloseTimedOutPositions()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_position_time_stop_minutes <= 0)
      return;

   const datetime now = TimeCurrent();
   const int max_age = strategy_position_time_stop_minutes * 60;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && now - open_time >= max_age)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

void Strategy_InitRequest(QM_EntryRequest &req,
                          const QM_OrderType order_type,
                          const double price,
                          const double sl,
                          const double tp,
                          const string reason)
  {
   req.type = order_type;
   req.price = QM_StopRulesNormalizePrice(_Symbol, price);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_order_valid_minutes * 60;
  }

bool Strategy_PlaceSessionStops(const double box_high, const double box_low)
  {
   const double box_height = box_high - box_low;
   if(box_height <= 0.0)
      return false;

   const double max_box = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_box_max_pips);
   if(max_box > 0.0 && box_height > max_box)
      return false;

   const double buy_trigger = box_high + strategy_breakout_fraction * box_height;
   const double sell_trigger = box_low - strategy_breakout_fraction * box_height;

   QM_EntryRequest buy_req;
   Strategy_InitRequest(buy_req,
                        QM_BUY_STOP,
                        buy_trigger,
                        box_low,
                        buy_trigger + strategy_tp_box_mult * box_height,
                        "CARTER_NY_BOX_BUY_STOP");

   QM_EntryRequest sell_req;
   Strategy_InitRequest(sell_req,
                        QM_SELL_STOP,
                        sell_trigger,
                        box_high,
                        sell_trigger - strategy_tp_box_mult * box_height,
                        "CARTER_NY_BOX_SELL_STOP");

   ulong buy_ticket = 0;
   ulong sell_ticket = 0;
   const bool buy_ok = QM_TM_OpenPosition(buy_req, buy_ticket);
   const bool sell_ok = QM_TM_OpenPosition(sell_req, sell_ticket);
   return (buy_ok || sell_ok);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
      return true;

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

   const datetime broker_now = TimeCurrent();
   if(strategy_skip_friday_entries && Strategy_IsFridayUTC(broker_now))
      return false;

   MqlDateTime utc_bar;
   if(!Strategy_CurrentBarOpenUTC(utc_bar))
      return false;
   if(utc_bar.hour != strategy_ny_open_utc_hour || utc_bar.min != strategy_ny_open_utc_minute)
      return false;

   const int day_key = Strategy_DateKeyUTC(broker_now);
   if(day_key <= 0 || g_session_order_day_key == day_key)
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_HasOurPendingStops())
      return false;

   double box_high = 0.0;
   double box_low = 0.0;
   if(!Strategy_ReadBox(box_high, box_low))
      return false;

   g_session_order_day_key = day_key;
   Strategy_PlaceSessionStops(box_high, box_low);
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOurOpenPosition())
      Strategy_RemoveOurPendingStops("CARTER_OCO_FILLED");
   else
      Strategy_RemoveExpiredPendingStops();

   Strategy_CloseTimedOutPositions();
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
