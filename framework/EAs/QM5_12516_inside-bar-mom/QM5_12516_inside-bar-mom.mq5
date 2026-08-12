#property strict
#property version   "5.0"
#property description "QM5_12516 inside-bar-mom — Inside Bar Momentum Stop-Entry (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12516 inside-bar-mom
// -----------------------------------------------------------------------------
// Source: Backtest Rookies / Rookie1 "Tradingview: Inside Bar Momentum
//   Strategy" (2018-07-13). Card: artifacts/cards_approved/
//   QM5_12516_inside-bar-mom.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads only; H1 primary):
//   shift 1 is the inside bar and shift 2 is the prior/mother bar.
//   A bullish mother bar arms a buy stop 10% of its range above its high.
//   A bearish mother bar arms a sell stop 10% of its range below its low.
//   Stops and targets are placed at the card's exact 20% and 80% offsets.
//   Each fresh inside bar cancels the prior pending order and closes any open
//   position for this magic before the replacement stop-entry is submitted.
//
// Symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, SP500.DWX — all present in
// dwx_symbol_matrix.csv; no porting required. SP500.DWX is backtest-only.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12516;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_entry_buf_pct     = 0.10;   // stop-entry buffer = range * this beyond the mother extreme
input double strategy_sl_pct            = 0.20;   // stop  offset from the mother extreme, as a fraction of range
input double strategy_tp_pct            = 0.80;   // target offset from the mother extreme, as a fraction of range

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard needed (.DWX models zero spread;
// fail-open). All structural work lives on the closed-bar entry path.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Inside-bar momentum entry. Caller guarantees QM_IsNewBar() == true.
// Reads closed bars only (shifts 1..3); a handful of OHLC reads = perf-allowed.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // perf-allowed: fixed two-bar structural OHLC read behind QM_IsNewBar().
   const double mother_high  = iHigh(_Symbol, _Period, 2);
   const double mother_low   = iLow(_Symbol, _Period, 2);
   const double mother_open  = iOpen(_Symbol, _Period, 2);
   const double mother_close = iClose(_Symbol, _Period, 2);
   const double inside_high  = iHigh(_Symbol, _Period, 1);
   const double inside_low   = iLow(_Symbol, _Period, 1);

   if(mother_high <= 0.0 || mother_low <= 0.0 || inside_high <= 0.0 || inside_low <= 0.0)
      return false;

   const bool inside_bar = (inside_high < mother_high && inside_low > mother_low);
   if(!inside_bar)
      return false;

   const double prior_range = mother_high - mother_low;
   if(prior_range <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!QM_TM_RemovePendingOrder(ticket, "inside_bar_replace"))
         return false;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
     }

   const bool mother_bull = (mother_close > mother_open);
   const bool mother_bear = (mother_close < mother_open);
   if(!mother_bull && !mother_bear)
      return false;

   const double entry_buf = prior_range * strategy_entry_buf_pct;
   if(mother_bull)
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, mother_high + entry_buf);
      const double sl = QM_TM_NormalizePrice(_Symbol, mother_high - prior_range * strategy_sl_pct);
      const double tp = QM_TM_NormalizePrice(_Symbol, mother_high + prior_range * strategy_tp_pct);
      if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || !(sl < entry && tp > entry))
         return false;

      req.type   = QM_BUY_STOP;
      req.price  = entry;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "inside_bar_mom_long";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   const double entry = QM_TM_NormalizePrice(_Symbol, mother_low - entry_buf);
   const double sl = QM_TM_NormalizePrice(_Symbol, mother_low + prior_range * strategy_sl_pct);
   const double tp = QM_TM_NormalizePrice(_Symbol, mother_low - prior_range * strategy_tp_pct);
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || !(sl > entry && tp < entry))
      return false;

   req.type   = QM_SELL_STOP;
   req.price  = entry;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "inside_bar_mom_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Fixed SL/TP only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// Replacement behaviour: when a fresh inside bar forms (shift 2 contained in
// the mother at shift 3) while a position is open, the source cancels/replaces
// and closes the current trade before arming the new setup. One inside-bar
// detection per closed bar = single event; no two-cross trap.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
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

   Strategy_ManageOpenPosition();

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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
