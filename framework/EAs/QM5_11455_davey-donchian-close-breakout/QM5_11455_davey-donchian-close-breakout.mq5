#property strict
#property version   "5.0"
#property description "QM5_11455 Davey Donchian Close Breakout (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11455
// Source: Kevin J. Davey, "My 5 Favorite Entries" (Entry #4).
// Card: cards_approved/QM5_11455_davey-donchian-close-breakout.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11455;
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
input int    strategy_length          = 20;    // Donchian close lookback (P3 sweeps 10/20/55/200)
input int    strategy_atr_period      = 14;
input double strategy_atr_sl_mult     = 1.5;
input double strategy_atr_tp_mult     = 3.0;
input int    strategy_sl_cap_pips     = 120;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Close-vs-close Donchian breakout: today's close is a new N-bar closing
// extreme. Long when Close[1] >= highest close of the past strategy_length
// bars (excluding bar[1] itself, i.e. bars [2..length+1]); short mirror.
bool DonchianCloseLongSignal()
{
   const int idx = iHighest(_Symbol, PERIOD_D1, MODE_CLOSE, strategy_length, 2);
   if(idx < 0)
      return false;
   const double highest_close = iClose(_Symbol, PERIOD_D1, idx);
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   if(highest_close <= 0.0 || close1 <= 0.0)
      return false;
   return (close1 >= highest_close);
}

bool DonchianCloseShortSignal()
{
   const int idx = iLowest(_Symbol, PERIOD_D1, MODE_CLOSE, strategy_length, 2);
   if(idx < 0)
      return false;
   const double lowest_close = iClose(_Symbol, PERIOD_D1, idx);
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   if(lowest_close <= 0.0 || close1 <= 0.0)
      return false;
   return (close1 <= lowest_close);
}

bool Strategy_NoTradeFilter()
{
   return false;
}

// Market entry at open of bar[0] (approximated by the fresh-bar ask/bid) in
// the direction of the new closing extreme. ATR-scaled SL (capped) and TP.
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   const bool long_sig = DonchianCloseLongSignal();
   const bool short_sig = DonchianCloseShortSignal();
   if(long_sig == short_sig)   // neither fired (both firing on the same bar is degenerate)
      return false;

   const double atr1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr1 <= 0.0)
      return false;

   const QM_OrderType side = long_sig ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl_cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double sl_atr_dist = atr1 * strategy_atr_sl_mult;
   const double sl_dist = (sl_cap_dist > 0.0) ? MathMin(sl_atr_dist, sl_cap_dist) : sl_atr_dist;
   const double tp_dist = atr1 * strategy_atr_tp_mult;
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_dist);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_dist);
   req.reason = long_sig ? "DAVEY_DONCHIAN_CLOSE_BUY" : "DAVEY_DONCHIAN_CLOSE_SELL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition()
{
}

// Reversal: close the open position when a fresh opposite-direction closing
// extreme fires. Runs ahead of the entry check in OnTick, so the opposite
// entry can fill in the same tick once the position is flat.
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

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && DonchianCloseShortSignal())
         return true;
      if(ptype == POSITION_TYPE_SELL && DonchianCloseLongSignal())
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
