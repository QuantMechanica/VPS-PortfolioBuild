#property strict
#property version   "5.0"
#property description "QM5_1235 Connors RSI-2 Mean Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1235;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe        = PERIOD_D1;
input int             strategy_rsi_period       = 2;
input int             strategy_sma_trend_period = 200;
input int             strategy_sma_exit_period  = 5;
input int             strategy_atr_period       = 14;
input double          strategy_entry_rsi_long   = 10.0;
input double          strategy_entry_rsi_short  = 90.0;
input double          strategy_exit_rsi_long    = 70.0;
input double          strategy_exit_rsi_short   = 30.0;
input double          strategy_atr_stop_mult    = 3.0;
input int             strategy_max_hold_bars    = 10;
input int             strategy_min_history_bars = 220;
input bool            strategy_enable_shorts    = true;
input bool            strategy_use_sma_slope    = false;
input int             strategy_sma_slope_bars   = 20;
input double          strategy_max_spread_points = 0.0;

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_timeframe != PERIOD_D1)
      return true;
   if(_Period != strategy_timeframe)
      return true;

   if(strategy_max_spread_points > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if(ask > bid && ((ask - bid) / point) > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "CONNORS_RSI2";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int slope_bars = MathMax(1, strategy_sma_slope_bars);
   const int history_shift = MathMax(strategy_min_history_bars - strategy_sma_trend_period + 1,
                                     1 + slope_bars);
   const double close_1 = QM_SMA(_Symbol, strategy_timeframe, 1, 1);
   const double sma_200 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_trend_period, 1);
   const double sma_200_then = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_trend_period, history_shift);
   const double rsi_2 = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
   const double atr_14 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(close_1 <= 0.0 || sma_200 <= 0.0 || sma_200_then <= 0.0 || rsi_2 <= 0.0 || atr_14 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(close_1 > sma_200 && rsi_2 < strategy_entry_rsi_long)
     {
      if(strategy_use_sma_slope && sma_200 <= sma_200_then)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_14, strategy_atr_stop_mult);
      req.reason = "CONNORS_RSI2_LONG";
      return (req.sl > 0.0 && req.sl < ask - point);
     }

   bool short_allowed_for_symbol = strategy_enable_shorts;
   if(StringFind(_Symbol, "XAUUSD") >= 0 ||
      StringFind(_Symbol, "NDX") >= 0 ||
      StringFind(_Symbol, "WS30") >= 0 ||
      StringFind(_Symbol, "GDAXI") >= 0 ||
      StringFind(_Symbol, "UK100") >= 0)
      short_allowed_for_symbol = false;

   if(short_allowed_for_symbol && close_1 < sma_200 && rsi_2 > strategy_entry_rsi_short)
     {
      if(strategy_use_sma_slope && sma_200 >= sma_200_then)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr_14, strategy_atr_stop_mult);
      req.reason = "CONNORS_RSI2_SHORT";
      return (req.sl > bid + point);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, scale-in, or martingale.
  }

bool Strategy_ExitSignal()
  {
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const double close_1 = QM_SMA(_Symbol, strategy_timeframe, 1, 1);
      const double sma_5 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_exit_period, 1);
      const double rsi_2 = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
      if(close_1 <= 0.0 || sma_5 <= 0.0 || rsi_2 <= 0.0)
         return false;

      const int hold_seconds = PeriodSeconds(strategy_timeframe) * MathMax(1, strategy_max_hold_bars);
      if(open_time > 0 && TimeCurrent() - open_time >= hold_seconds)
         return true;

      if(ptype == POSITION_TYPE_BUY && (close_1 > sma_5 || rsi_2 > strategy_exit_rsi_long))
         return true;
      if(ptype == POSITION_TYPE_SELL && (close_1 < sma_5 || rsi_2 < strategy_exit_rsi_short))
         return true;

      return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1235\",\"ea\":\"QM5_1235_connors-rsi2\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
