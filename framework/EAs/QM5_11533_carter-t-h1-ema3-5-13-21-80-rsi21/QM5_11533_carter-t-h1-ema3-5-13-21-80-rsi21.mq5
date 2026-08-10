#property strict
#property version   "5.0"
#property description "QM5_11533 Carter-T H1 EMA(3/5/13/21/80) Ribbon + RSI(21)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11533
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", System #7.
// Card: cards_approved/QM5_11533_carter-t-h1-ema3-5-13-21-80-rsi21.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11533;
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
input int    strategy_ema_fast          = 3;
input int    strategy_ema_signal        = 5;
input int    strategy_ema_medium1       = 13;
input int    strategy_ema_medium2       = 21;
input int    strategy_ema_baseline      = 80;
input int    strategy_rsi_period        = 21;
input double strategy_rsi_threshold     = 50.0;
input int    strategy_sl_pips           = 25;    // P2 fallback stop
input int    strategy_max_spread_pips   = 15;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Fast-signal EMA3/EMA5 cross plus medium (EMA13/EMA21) and structural (EMA80)
// ribbon alignment, confirmed by RSI(21) vs 50. Card LONG/SHORT bullets read
// "both cross EMA13"; the Mechanik prose clarifies this as EMA3 and EMA5 both
// positioned beyond EMA13 AND EMA21 (medium confirmation), not a fresh cross
// event on the medium EMAs.
bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(spread_cap <= 0.0)
      return true;
   if((ask - bid) > spread_cap)
      return true;

   return false;
}

bool RibbonLongSignal()
{
   const double ema3_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 1);
   const double ema5_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_signal, 1);
   const double ema3_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 2);
   const double ema5_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_signal, 2);
   const double ema13_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_medium1, 1);
   const double ema21_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_medium2, 1);
   const double ema80_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_baseline, 1);
   const double rsi_1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);

   const bool cross_up = (ema3_2 <= ema5_2) && (ema3_1 > ema5_1);
   const bool medium_confirm = (ema3_1 > ema13_1) && (ema5_1 > ema13_1) &&
                               (ema3_1 > ema21_1) && (ema5_1 > ema21_1);
   const bool structural = (ema13_1 > ema80_1) && (ema21_1 > ema80_1);

   return cross_up && medium_confirm && structural && (rsi_1 > strategy_rsi_threshold);
}

bool RibbonShortSignal()
{
   const double ema3_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 1);
   const double ema5_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_signal, 1);
   const double ema3_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 2);
   const double ema5_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_signal, 2);
   const double ema13_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_medium1, 1);
   const double ema21_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_medium2, 1);
   const double ema80_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_baseline, 1);
   const double rsi_1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);

   const bool cross_dn = (ema3_2 >= ema5_2) && (ema3_1 < ema5_1);
   const bool medium_confirm = (ema3_1 < ema13_1) && (ema5_1 < ema13_1) &&
                               (ema3_1 < ema21_1) && (ema5_1 < ema21_1);
   const bool structural = (ema13_1 < ema80_1) && (ema21_1 < ema80_1);

   return cross_dn && medium_confirm && structural && (rsi_1 < strategy_rsi_threshold);
}

// Market entry at open of bar[0]. Fixed pip SL (card gives no ATR/TP model;
// the exit is purely indicator-driven, see Strategy_ExitSignal).
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   const bool long_sig = RibbonLongSignal();
   const bool short_sig = RibbonShortSignal();
   if(long_sig == short_sig)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5)   // No Friday entry (card filter)
      return false;

   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(sl_dist <= 0.0)
      return false;

   const QM_OrderType side = long_sig ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_dist);
   req.tp = 0.0;
   req.reason = long_sig ? "CARTER_RIBBON_RSI_BUY" : "CARTER_RIBBON_RSI_SELL";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition()
{
}

// Indicator-driven exit: EMA3/EMA5 reverse cross OR RSI recrosses 50 against
// the open position's direction.
bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_position = false;
   long ptype = -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      has_position = true;
      ptype = PositionGetInteger(POSITION_TYPE);
      break;
   }
   if(!has_position)
      return false;

   const double ema3_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 1);
   const double ema5_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_signal, 1);
   const double rsi_1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);

   if(ptype == POSITION_TYPE_BUY)
      return (ema3_1 < ema5_1) || (rsi_1 < strategy_rsi_threshold);
   if(ptype == POSITION_TYPE_SELL)
      return (ema3_1 > ema5_1) || (rsi_1 > strategy_rsi_threshold);
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
