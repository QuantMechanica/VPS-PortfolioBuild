#property strict
#property version   "5.0"
#property description "QM5_1096 Unger Donchian Channel Trend Following"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_1096 unger-donchian-channel-tf
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1096;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_donchian_period      = 20;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 2.5;
input double strategy_vol_floor_ratio      = 0.004;
input int    strategy_spread_median_days   = 20;
input double strategy_spread_median_mult   = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_donchian_period < 1 || strategy_atr_period < 1)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_vol_floor_ratio < 0.0)
      return true;
   if(strategy_spread_median_days < 1 || strategy_spread_median_days > 64)
      return true;
   if(strategy_spread_median_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   double spreads[64];
   int count = 0;
   // perf-allowed: bounded D1 spread sample for the card's 20-day median spread filter.
   for(int shift = 1; shift <= strategy_spread_median_days; ++shift)
     {
      const long spread_i = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread_i <= 0)
         continue;
      spreads[count] = (double)spread_i;
      count++;
     }

   if(count <= 0)
      return false;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(spreads[j] < spreads[i])
           {
            const double tmp = spreads[i];
            spreads[i] = spreads[j];
            spreads[j] = tmp;
           }

   double median_spread = spreads[count / 2];
   if((count % 2) == 0)
      median_spread = 0.5 * (spreads[(count / 2) - 1] + spreads[count / 2]);

   return ((double)current_spread > median_spread * strategy_spread_median_mult);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double upper = -DBL_MAX;
   double lower = DBL_MAX;
   // perf-allowed: Donchian channel is structural high/low logic; EntrySignal is called only after QM_IsNewBar().
   for(int shift = 2; shift <= strategy_donchian_period + 1; ++shift)
     {
      const double high_i = iHigh(_Symbol, PERIOD_D1, shift);
      const double low_i = iLow(_Symbol, PERIOD_D1, shift);
      if(high_i <= 0.0 || low_i <= 0.0 || high_i < low_i)
         return false;
      if(high_i > upper)
         upper = high_i;
      if(low_i < lower)
         lower = low_i;
     }

   if(upper <= 0.0 || lower <= 0.0 || upper <= lower)
      return false;

   // perf-allowed: closed-bar close read for the Donchian breakout trigger.
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_1 <= 0.0 || atr <= 0.0)
      return false;
   if((atr / close_1) < strategy_vol_floor_ratio)
      return false;

   if(close_1 > upper)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_atr_sl_mult);
      if(req.sl <= 0.0 || req.sl >= entry)
         return false;
      req.reason = "QM5_1096_DONCHIAN_LONG";
      return true;
     }

   if(close_1 < lower)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_atr_sl_mult);
      if(req.sl <= 0.0 || req.sl <= entry)
         return false;
      req.reason = "QM5_1096_DONCHIAN_SHORT";
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double risk = is_buy ? (open_price - current_sl) : (current_sl - open_price);
      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(risk > 0.0 && moved >= risk)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_sl_mult);
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double upper = -DBL_MAX;
   double lower = DBL_MAX;
   // perf-allowed: bounded Donchian opposite-channel exit scan.
   for(int shift = 2; shift <= strategy_donchian_period + 1; ++shift)
     {
      const double high_i = iHigh(_Symbol, PERIOD_D1, shift);
      const double low_i = iLow(_Symbol, PERIOD_D1, shift);
      if(high_i <= 0.0 || low_i <= 0.0 || high_i < low_i)
         return false;
      if(high_i > upper)
         upper = high_i;
      if(low_i < lower)
         lower = low_i;
     }

   if(upper <= 0.0 || lower <= 0.0 || upper <= lower)
      return false;

   // perf-allowed: closed-bar close read for opposite-channel exit.
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);
   if(close_1 <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close_1 < lower)
         return true;
      if(ptype == POSITION_TYPE_SELL && close_1 > upper)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1096\",\"ea\":\"unger-donchian-channel-tf\"}");
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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
