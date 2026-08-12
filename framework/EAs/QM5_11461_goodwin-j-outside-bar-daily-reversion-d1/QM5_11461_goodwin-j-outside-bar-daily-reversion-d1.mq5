#property strict
#property version   "5.0"
#property description "QM5_11461 Goodwin-J Outside Bar Daily Reversion (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11461
// Source: Jarrod Goodwin, "Beat the Markets Strategy Guidebook" (~2020),
//         adapted from Larry Williams (1999).
// Card: cards_approved/QM5_11461_goodwin-j-outside-bar-daily-reversion-d1.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11461;
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
input int    strategy_sl_pips          = 200;   // Goodwin's fixed hard stop
input int    strategy_hold_bars        = 1;      // P2 simplification: exit at next D1 open regardless

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

// Outside bar (High[1]>High[2] && Low[1]<Low[2]) that closes beyond the prior
// day's extreme is a short-term exhaustion signal -> fade it. No Friday
// setups (Close[1] is the setup bar, i.e. bar index 1). Market entry at the
// open of bar[0]; fixed 200-pip SL; 1-bar hold (no discretionary TP).
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   const double high1 = iHigh(_Symbol, PERIOD_D1, 1);
   const double high2 = iHigh(_Symbol, PERIOD_D1, 2);
   const double low1 = iLow(_Symbol, PERIOD_D1, 1);
   const double low2 = iLow(_Symbol, PERIOD_D1, 2);
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   if(high1 <= 0.0 || high2 <= 0.0 || low1 <= 0.0 || low2 <= 0.0 || close1 <= 0.0)
      return false;

   const bool outside_bar = (high1 > high2) && (low1 < low2);
   if(!outside_bar)
      return false;

   MqlDateTime dt;
   TimeToStruct(iTime(_Symbol, PERIOD_D1, 1), dt);
   if(dt.day_of_week == 5)   // Friday setup bar excluded
      return false;

   const bool long_setup = (close1 < low2);    // bearish close below prior low -> fade with a buy
   const bool short_setup = (close1 > high2);  // bullish close above prior high -> fade with a sell
   if(long_setup == short_setup)
      return false;

   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(sl_dist <= 0.0)
      return false;

   const QM_OrderType side = long_setup ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_dist);
   req.tp = 0.0;
   req.reason = long_setup ? "GOODWINJ_OUTSIDE_BAR_FADE_BUY" : "GOODWINJ_OUTSIDE_BAR_FADE_SELL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition()
{
}

// P2 simplification of Goodwin's profit-check exit: hold exactly one D1 bar,
// then close regardless of P&L (SL may fire earlier via broker-side order).
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
