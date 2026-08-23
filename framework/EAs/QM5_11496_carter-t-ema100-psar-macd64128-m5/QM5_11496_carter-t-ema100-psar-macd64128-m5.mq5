#property strict
#property version   "5.0"
#property description "QM5_11496 Carter-T EMA100 + PSAR + MACD(64,128,9) Trend Confirmation (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11496
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11496;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_M5;
input int             strategy_ema_period         = 100;
input double          strategy_psar_step          = 0.01;
input double          strategy_psar_maximum       = 0.01;
input int             strategy_macd_fast          = 64;
input int             strategy_macd_slow          = 128;
input int             strategy_macd_signal        = 9;
input double          strategy_sl_buffer_pips     = 3.0;
input double          strategy_sl_cap_pips        = 20.0;
input double          strategy_tp_rr_ratio        = 2.0;
input int             strategy_max_spread_pips    = 15;

// -----------------------------------------------------------------------------
// Strategy helper functions
// -----------------------------------------------------------------------------

double Strategy_PipSize(const string symbol)
{
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
}

bool Strategy_HasOpenPosition()
{
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
      return true;
   }
   return false;
}

bool Strategy_SpreadAllowsEntry()
{
   if(strategy_max_spread_pips <= 0)
      return true;
   const double pip = Strategy_PipSize(_Symbol);
   if(pip <= 0.0)
      return true;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread_pips = (ask - bid) / pip;
   return (spread_pips <= (double)strategy_max_spread_pips);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double ema100_1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double psar_1   = QM_SAR(_Symbol, strategy_timeframe, strategy_psar_step, strategy_psar_maximum, 1);
   const double macd_1   = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);

   if(ema100_1 <= 0.0 || psar_1 <= 0.0)
      return false;

   const double pip = Strategy_PipSize(_Symbol);
   if(pip <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, strategy_timeframe, 1, 1, rates) != 1)
      return false;

   const double close_1 = rates[0].close;
   const double low_1   = rates[0].low;
   const double high_1  = rates[0].high;

   const bool long_signal  = (close_1 > ema100_1 && psar_1 < low_1 && macd_1 > 0.0);
   const bool short_signal = (close_1 < ema100_1 && psar_1 > high_1 && macd_1 < 0.0);

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (side == QM_BUY) ? ask : bid;

   const double buffer = strategy_sl_buffer_pips * pip;
   const double cap_dist = strategy_sl_cap_pips * pip;

   double sl = 0.0;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      sl = psar_1 - buffer;
      if(entry - sl > cap_dist || sl >= entry)
         sl = entry - cap_dist;
      const double sl_dist = entry - sl;
      tp = entry + strategy_tp_rr_ratio * sl_dist;
   }
   else
   {
      sl = psar_1 + buffer;
      if(sl - entry > cap_dist || sl <= entry)
         sl = entry + cap_dist;
      const double sl_dist = sl - entry;
      tp = entry - strategy_tp_rr_ratio * sl_dist;
   }

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);

   if((side == QM_BUY && (sl >= entry || tp <= entry)) ||
      (side == QM_SELL && (sl <= entry || tp >= entry)))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "CARTER_EMA100_PSAR_MACD_LONG" : "CARTER_EMA100_PSAR_MACD_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
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
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
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
