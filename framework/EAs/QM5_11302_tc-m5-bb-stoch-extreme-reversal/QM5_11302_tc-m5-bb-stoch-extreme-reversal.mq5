#property strict
#property version   "5.0"
#property description "QM5_11302 tc-m5-bb-stoch-extreme-reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11302
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11302;
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
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_M5;
input int    strategy_bb_period         = 20;
input double strategy_bb_deviation      = 2.0;
input int    strategy_stoch_k           = 5;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input int    strategy_stop_pips         = 20;
input int    strategy_tp_pips           = 10;

// -----------------------------------------------------------------------------
// Strategy helper functions
// -----------------------------------------------------------------------------

bool Strategy_HasOurPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(Strategy_HasOurPosition())
      return false;

   // Spread filter (cap: 3 pips)
   double pip_value = (_Digits == 3 || _Digits == 5) ? 10.0 * _Point : _Point;
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / pip_value;
   if(spread > 3.0)
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOurPosition())
      return false;

   if(Strategy_NoTradeFilter())
      return false;

   // Bollinger Bands (20, 2)
   double bb_upper_2 = QM_BB_Upper(_Symbol, strategy_timeframe, strategy_bb_period, strategy_bb_deviation, 2);
   double bb_lower_2 = QM_BB_Lower(_Symbol, strategy_timeframe, strategy_bb_period, strategy_bb_deviation, 2);

   // Stochastic (5, 3, 3)
   double stoch_k_2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);

   // Pullback candle check at shift 1
   MqlRates bar1;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 1, bar1))
      return false;

   // Trend check at shift 2: High[2] > High[3] && High[3] > High[4] for LONG, Low[2] < Low[3] && Low[3] < Low[4] for SHORT
   MqlRates bar2, bar3, bar4;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 2, bar2) ||
      !QM_ReadBar(_Symbol, strategy_timeframe, 3, bar3) ||
      !QM_ReadBar(_Symbol, strategy_timeframe, 4, bar4))
      return false;

   // LONG entry rules:
   // 1. Bar 2 closed above BB Upper
   // 2. Bar 2 Stochastic was overbought (> 80)
   // 3. Uptrend leading up to Bar 2 (High[2] > High[3] && High[3] > High[4])
   // 4. Bar 1 is a red pullback candle (Close[1] < Open[1])
   bool long_bb = (bar2.close > bb_upper_2);
   bool long_stoch = (stoch_k_2 > 80.0);
   bool long_trend = (bar2.high > bar3.high && bar3.high > bar4.high);
   bool long_pullback = (bar1.close < bar1.open);

   if(long_bb && long_stoch && long_trend && long_pullback)
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0) return false;
      double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_stop_pips);
      double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0) return false;

      req.type = QM_BUY;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TC_M5_3_LONG";
      return true;
   }

   // SHORT entry rules:
   // 1. Bar 2 closed below BB Lower
   // 2. Bar 2 Stochastic was oversold (< 20)
   // 3. Downtrend leading up to Bar 2 (Low[2] < Low[3] && Low[3] < Low[4])
   // 4. Bar 1 is a green pullback candle (Close[1] > bar1.open)
   bool short_bb = (bar2.close < bb_lower_2);
   bool short_stoch = (stoch_k_2 < 20.0);
   bool short_trend = (bar2.low < bar3.low && bar3.low < bar4.low);
   bool short_pullback = (bar1.close > bar1.open);

   if(short_bb && short_stoch && short_trend && short_pullback)
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return false;
      double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_stop_pips);
      double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0) return false;

      req.type = QM_SELL;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TC_M5_3_SHORT";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   return false; // Exit on SL/TP only
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
