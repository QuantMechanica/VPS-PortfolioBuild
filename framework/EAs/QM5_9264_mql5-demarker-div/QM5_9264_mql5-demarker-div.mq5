#property strict
#property version   "5.0"
#property description "QM5_9264 MQL5 DeMarker divergence"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9264;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_demarker_period     = 14;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 1.0;
input double strategy_take_profit_rr      = 1.8;
input double strategy_demarker_overbought = 0.70;
input double strategy_demarker_oversold   = 0.30;
input double strategy_demarker_midline    = 0.50;
input int    strategy_time_exit_bars      = 36;

double g_signal_bar_low   = 0.0;
double g_signal_bar_high  = 0.0;

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &position_time)
{
   ptype = POSITION_TYPE_BUY;
   position_time = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
   }

   return false;
}

bool Strategy_NoTradeFilter()
{
   if(_Period != PERIOD_H1)
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

   ENUM_POSITION_TYPE ptype;
   datetime pos_time = 0;
   if(Strategy_GetOurPosition(ptype, pos_time))
      return false;

   if(strategy_demarker_period <= 0 || strategy_atr_period <= 0 || strategy_take_profit_rr <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 3, rates) != 3)
      return false;

   const double demarker1 = QM_DeMarker(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_demarker_period, 1);
   const double demarker2 = QM_DeMarker(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_demarker_period, 2);
   const double atr1 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);

   if(demarker1 <= 0.0 || demarker2 <= 0.0 || atr1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Bullish Divergence: Lower Low in price with Higher Low in DeMarker (and DeMarker < 0.50)
   if(rates[0].low < rates[1].low && demarker1 > demarker2 && demarker1 < strategy_demarker_midline)
   {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, rates[0].low - strategy_sl_atr_mult * atr1);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_take_profit_rr);
      req.reason = "DEMARKER_BULL_DIV";
      g_signal_bar_low = rates[0].low;
      g_signal_bar_high = rates[0].high;
      return (req.tp > ask);
   }

   // Bearish Divergence: Higher High in price with Lower High in DeMarker (and DeMarker > 0.50)
   if(rates[0].high > rates[1].high && demarker1 < demarker2 && demarker1 > strategy_demarker_midline)
   {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, rates[0].high + strategy_sl_atr_mult * atr1);
      if(sl <= 0.0 || sl <= bid)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_take_profit_rr);
      req.reason = "DEMARKER_BEAR_DIV";
      g_signal_bar_low = rates[0].low;
      g_signal_bar_high = rates[0].high;
      return (req.tp > 0.0 && req.tp < bid);
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   ENUM_POSITION_TYPE ptype;
   datetime position_time = 0;
   if(!Strategy_GetOurPosition(ptype, position_time))
   {
      g_signal_bar_low = 0.0;
      g_signal_bar_high = 0.0;
      return false;
   }

   // Time exit
   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds_per_bar > 0 && strategy_time_exit_bars > 0 && position_time > 0)
   {
      if((TimeCurrent() - position_time) >= strategy_time_exit_bars * seconds_per_bar)
         return true;
   }

   // Indicator and price-close exits
   const double demarker1 = QM_DeMarker(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_demarker_period, 1);
   if(demarker1 <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, rates) != 1)
      return false;

   if(ptype == POSITION_TYPE_BUY)
   {
      // Exit long if DeMarker reaches overbought level OR price closes below signal bar low
      if(demarker1 >= strategy_demarker_overbought)
         return true;
      if(g_signal_bar_low > 0.0 && rates[0].close < g_signal_bar_low)
         return true;
   }
   else if(ptype == POSITION_TYPE_SELL)
   {
      // Exit short if DeMarker reaches oversold level OR price closes above signal bar high
      if(demarker1 <= strategy_demarker_oversold)
         return true;
      if(g_signal_bar_high > 0.0 && rates[0].close > g_signal_bar_high)
         return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9264_mql5-demarker-div\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
