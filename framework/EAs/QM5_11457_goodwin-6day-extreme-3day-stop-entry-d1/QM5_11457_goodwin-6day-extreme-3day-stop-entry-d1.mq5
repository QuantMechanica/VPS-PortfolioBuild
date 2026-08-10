#property strict
#property version   "5.0"
#property description "QM5_11457 Goodwin 6-Day Extreme -> 3-Day Stop Entry (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11457
// Source: Andrew Goodwin, "Trading Secrets of the Inner Circle" (1997), Strategy 6.
// Card: cards_approved/QM5_11457_goodwin-6day-extreme-3day-stop-entry-d1.md
// Exploratory FX port of an S&P-futures system (R1 informational per card).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11457;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_extreme_lookback = 6;     // N-bar closing extreme trigger
input int    strategy_stop_lookback    = 3;     // N-bar closing extreme for stop-order price
input int    strategy_hold_bars        = 4;     // time exit: bars_held >= this closes (5-bar total hold)
input int    strategy_atr_period       = 14;
input double strategy_atr_sl_mult      = 1.5;
input double strategy_atr_tp_mult      = 2.0;
input int    strategy_sl_cap_pips      = 100;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Removes any pending stop order this EA holds on this symbol so a fresh one
// can be placed at an updated price (Goodwin: "update stop order each day").
void CancelStaleStopOrders(const int magic)
{
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      QM_TM_RemovePendingOrder(ticket, "daily_stop_order_refresh");
   }
}

bool Strategy_NoTradeFilter()
{
   return false;
}

// LONG setup: Close[1] is a new N-bar closing low -> place BUYSTOP at the
// M-bar closing high (only enter once price starts recovering).
// SHORT setup: mirror on a new N-bar closing high -> SELLSTOP at the M-bar
// closing low. Cancels and re-places the stop order fresh every new D1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   CancelStaleStopOrders(magic);

   const int idx_low_n = iLowest(_Symbol, PERIOD_D1, MODE_CLOSE, strategy_extreme_lookback, 2);
   const int idx_high_n = iHighest(_Symbol, PERIOD_D1, MODE_CLOSE, strategy_extreme_lookback, 2);
   if(idx_low_n < 0 || idx_high_n < 0)
      return false;
   const double lowest_n = iClose(_Symbol, PERIOD_D1, idx_low_n);
   const double highest_n = iClose(_Symbol, PERIOD_D1, idx_high_n);
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   if(lowest_n <= 0.0 || highest_n <= 0.0 || close1 <= 0.0)
      return false;

   const bool long_setup = (close1 < lowest_n);
   const bool short_setup = (close1 > highest_n);
   if(long_setup == short_setup)
      return false;

   const int idx_stop = long_setup
                         ? iHighest(_Symbol, PERIOD_D1, MODE_CLOSE, strategy_stop_lookback, 2)
                         : iLowest(_Symbol, PERIOD_D1, MODE_CLOSE, strategy_stop_lookback, 2);
   if(idx_stop < 0)
      return false;
   const double stop_price = iClose(_Symbol, PERIOD_D1, idx_stop);
   if(stop_price <= 0.0)
      return false;

   const double atr1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr1 <= 0.0)
      return false;

   const QM_OrderType side = long_setup ? QM_BUY_STOP : QM_SELL_STOP;
   const double entry = QM_StopRulesNormalizePrice(_Symbol, stop_price);

   const double sl_cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double sl_atr_dist = atr1 * strategy_atr_sl_mult;
   const double sl_dist = (sl_cap_dist > 0.0) ? MathMin(sl_atr_dist, sl_cap_dist) : sl_atr_dist;
   const double tp_dist = atr1 * strategy_atr_tp_mult;
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_dist);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_dist);
   req.reason = long_setup ? "GOODWIN_6DAY_EXTREME_BUYSTOP" : "GOODWIN_6DAY_EXTREME_SELLSTOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition()
{
}

// Fixed 5-bar hold (Goodwin: no protective stop originally, time exit is the
// risk management). bars_held counts closed D1 bars since the entry bar.
bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      if(bars_held >= strategy_hold_bars)
         return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
