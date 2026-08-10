#property strict
#property version   "5.0"
#property description "QM5_11301 tc-m5-macd1-stoch-ema5-open-close"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11301
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11301;
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
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 1;
input int    strategy_stoch_k           = 5;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input int    strategy_stop_pips         = 20;

// -----------------------------------------------------------------------------
// Strategy helper functions
// -----------------------------------------------------------------------------

bool Strategy_IsTradingSession(const datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   // London open (10:00 Broker time) to NY close (00:00 Broker time)
   return (dt.hour >= 10 && dt.hour < 24);
}

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

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
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

   // Session filter: London + NY (10:00 to 24:00 broker time)
   if(!Strategy_IsTradingSession(TimeCurrent()))
      return true;

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

   // 1. Stochastic (5,3,3)
   double k1 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   double k2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);

   // 2. MACD (12,26,1)
   double macd1 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   double macd2 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);

   // 3. Candle Body
   MqlRates bar1;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 1, bar1))
      return false;

   // 4. EMA5 Open/Close
   double ema5_close_1 = QM_EMA(_Symbol, strategy_timeframe, 5, 1, PRICE_CLOSE);
   double ema5_close_2 = QM_EMA(_Symbol, strategy_timeframe, 5, 2, PRICE_CLOSE);
   double ema5_open_1  = QM_EMA(_Symbol, strategy_timeframe, 5, 1, PRICE_OPEN);
   double ema5_open_2  = QM_EMA(_Symbol, strategy_timeframe, 5, 2, PRICE_OPEN);

   // LONG entry
   bool long_stoch = (k2 < 20.0 && k1 >= 20.0 && k1 <= 80.0);
   bool long_macd  = (macd1 > macd2);
   bool long_candle = (bar1.close > bar1.open);
   bool long_ema    = (ema5_close_2 <= ema5_open_2 && ema5_close_1 > ema5_open_1);

   if(long_stoch && long_macd && long_candle && long_ema)
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0) return false;
      double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_stop_pips);
      if(sl <= 0.0) return false;

      req.type = QM_BUY;
      req.price = entry;
      req.sl = sl;
      req.tp = 0.0; // Hold to reverse signal
      req.reason = "TC_M5_1_LONG";
      return true;
   }

   // SHORT entry
   bool short_stoch = (k2 > 80.0 && k1 <= 80.0 && k1 >= 20.0);
   bool short_macd  = (macd1 < macd2);
   bool short_candle = (bar1.close < bar1.open);
   bool short_ema    = (ema5_close_2 >= ema5_open_2 && ema5_close_1 < ema5_open_1);

   if(short_stoch && short_macd && short_candle && short_ema)
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return false;
      double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_stop_pips);
      if(sl <= 0.0) return false;

      req.type = QM_SELL;
      req.price = entry;
      req.sl = sl;
      req.tp = 0.0; // Hold to reverse signal
      req.reason = "TC_M5_1_SHORT";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   ENUM_POSITION_TYPE position_type;
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(position_type, ticket))
      return false;

   // EMA5 Open/Close crossover for exit
   double ema5_close_1 = QM_EMA(_Symbol, strategy_timeframe, 5, 1, PRICE_CLOSE);
   double ema5_close_2 = QM_EMA(_Symbol, strategy_timeframe, 5, 2, PRICE_CLOSE);
   double ema5_open_1  = QM_EMA(_Symbol, strategy_timeframe, 5, 1, PRICE_OPEN);
   double ema5_open_2  = QM_EMA(_Symbol, strategy_timeframe, 5, 2, PRICE_OPEN);

   if(position_type == POSITION_TYPE_BUY)
   {
      return (ema5_close_2 >= ema5_open_2 && ema5_close_1 < ema5_open_1);
   }
   else if(position_type == POSITION_TYPE_SELL)
   {
      return (ema5_close_2 <= ema5_open_2 && ema5_close_1 > ema5_open_1);
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
