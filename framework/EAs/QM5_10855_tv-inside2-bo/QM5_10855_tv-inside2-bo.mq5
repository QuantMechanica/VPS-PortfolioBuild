#property strict
#property version   "5.0"
#property description "QM5_10855 TradingView True Two-Inside Candle Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10855;
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
// Default 0.0 = no rejection.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period             = 14;
input double strategy_mother_min_atr_mult    = 0.25;
input double strategy_mother_max_atr_mult    = 2.50;
input double strategy_stop_buffer_atr_mult   = 0.10;
input double strategy_rr_target              = 1.50;
input int    strategy_entry_offset_points    = 1;
input int    strategy_order_expiry_bars      = 8;
input double strategy_spread_stop_max_ratio  = 0.15;

bool IsOurPendingStopType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool HasOurOpenPosition()
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

bool HasOurPendingStops()
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
      if(IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }

   return false;
  }

void RemoveOurPendingStops(const string reason)
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
      if(!IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool StopsLevelAllows(const double entry, const double sl, const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point <= 0.0 || stops_level <= 0)
      return true;

   const double min_dist = stops_level * point;
   return (MathAbs(entry - sl) >= min_dist && MathAbs(entry - tp) >= min_dist);
  }

bool BuildStopRequest(const QM_OrderType side,
                      const double entry,
                      const double sl,
                      const double tp,
                      const int expiry_seconds,
                      const string reason,
                      QM_EntryRequest &req)
  {
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || expiry_seconds <= 0)
      return false;
   if(!StopsLevelAllows(entry, sl, tp))
      return false;

   req.type = side;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;
   return true;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 ||
      strategy_mother_min_atr_mult <= 0.0 ||
      strategy_mother_max_atr_mult <= strategy_mother_min_atr_mult ||
      strategy_stop_buffer_atr_mult <= 0.0 ||
      strategy_rr_target <= 0.0 ||
      strategy_entry_offset_points <= 0 ||
      strategy_order_expiry_bars <= 0 ||
      strategy_spread_stop_max_ratio <= 0.0)
      return false;

   if(HasOurOpenPosition() || HasOurPendingStops())
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, 3, bars); // perf-allowed: exact three-bar inside-candle structure, called only after framework QM_IsNewBar.
   if(copied != 3)
      return false;

   const MqlRates inside2 = bars[0];
   const MqlRates inside1 = bars[1];
   const MqlRates mother  = bars[2];
   if(mother.high <= mother.low)
      return false;

   if(inside1.high >= mother.high || inside1.low <= mother.low)
      return false;
   if(inside2.high >= mother.high || inside2.low <= mother.low)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 3);
   if(atr <= 0.0)
      return false;

   const double mother_width = mother.high - mother.low;
   if(mother_width > atr * strategy_mother_max_atr_mult)
      return false;
   if(mother_width < atr * strategy_mother_min_atr_mult)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0 || ask <= bid)
      return false;

   const double offset = point * strategy_entry_offset_points;
   const int expiry_seconds = strategy_order_expiry_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(expiry_seconds <= 0)
      return false;

   const double buy_entry = mother.high + offset;
   const double sell_entry = mother.low - offset;
   const double buy_sl = mother.low - atr * strategy_stop_buffer_atr_mult;
   const double sell_sl = mother.high + atr * strategy_stop_buffer_atr_mult;
   const double buy_tp = QM_TakeRR(_Symbol, QM_BUY_STOP, buy_entry, buy_sl, strategy_rr_target);
   const double sell_tp = QM_TakeRR(_Symbol, QM_SELL_STOP, sell_entry, sell_sl, strategy_rr_target);
   if(buy_tp <= 0.0 || sell_tp <= 0.0)
      return false;

   const double buy_stop_dist = MathAbs(buy_entry - buy_sl);
   const double sell_stop_dist = MathAbs(sell_entry - sell_sl);
   const double spread = ask - bid;
   const double min_stop_dist = MathMin(buy_stop_dist, sell_stop_dist);
   if(min_stop_dist <= 0.0 || spread > min_stop_dist * strategy_spread_stop_max_ratio)
      return false;

   QM_EntryRequest buy_req;
   if(!BuildStopRequest(QM_BUY_STOP, buy_entry, buy_sl, buy_tp, expiry_seconds, "two_inside_buy_stop", buy_req))
      return false;
   if(!BuildStopRequest(QM_SELL_STOP, sell_entry, sell_sl, sell_tp, expiry_seconds, "two_inside_sell_stop", req))
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   if(HasOurOpenPosition())
      RemoveOurPendingStops("opposite_stop_after_fill");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10855_tv_inside2_bo\"}");
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
