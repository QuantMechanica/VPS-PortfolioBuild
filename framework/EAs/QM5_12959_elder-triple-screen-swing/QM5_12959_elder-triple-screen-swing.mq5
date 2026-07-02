#property strict
#property version   "5.0"
#property description "QM5_12959 Elder triple screen swing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12959;
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
input int    strategy_sma_regime_period   = 200;
input int    strategy_rsi_period          = 14;
input double strategy_rsi_long_max        = 30.0;
input double strategy_rsi_short_min       = 70.0;
input int    strategy_pending_expiry_hours = 24;
input double strategy_rr_target           = 2.0;
input int    strategy_swing_lookback_h4   = 10;
input int    strategy_entry_buffer_points = 5;
input int    strategy_sl_buffer_points    = 5;

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "NDX.DWX")
      return 0;
   if(_Symbol == "XAUUSD.DWX")
      return 1;
   return -1;
  }

bool Strategy_IsTarget()
  {
   return (_Period == PERIOD_H4 && Strategy_ExpectedSlot() == qm_magic_slot_offset);
  }

double Strategy_HighestHigh(const ENUM_TIMEFRAMES tf, const int start_shift, const int count)
  {
   if(count <= 0 || start_shift < 1)
      return 0.0;
   double best = 0.0;
   for(int shift = start_shift; shift < start_shift + count; ++shift)
     {
      const double value = iHigh(_Symbol, tf, shift);
      if(value <= 0.0)
         return 0.0;
      if(best <= 0.0 || value > best)
         best = value;
     }
   return best;
  }

double Strategy_LowestLow(const ENUM_TIMEFRAMES tf, const int start_shift, const int count)
  {
   if(count <= 0 || start_shift < 1)
      return 0.0;
   double best = 0.0;
   for(int shift = start_shift; shift < start_shift + count; ++shift)
     {
      const double value = iLow(_Symbol, tf, shift);
      if(value <= 0.0)
         return 0.0;
      if(best <= 0.0 || value < best)
         best = value;
     }
   return best;
  }

bool Strategy_HasOpenOrPending()
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

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

int Strategy_D1Direction()
  {
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double sma200 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_regime_period, 1, PRICE_CLOSE);
   if(close1 <= 0.0 || sma200 <= 0.0)
      return 0;
   if(close1 > sma200)
      return 1;
   if(close1 < sma200)
      return -1;
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(strategy_sma_regime_period <= 1 || strategy_rsi_period <= 1)
      return true;
   if(strategy_rsi_long_max <= 0.0 || strategy_rsi_short_min >= 100.0)
      return true;
   if(strategy_rsi_long_max >= strategy_rsi_short_min)
      return true;
   if(strategy_pending_expiry_hours <= 0 || strategy_rr_target <= 0.0)
      return true;
   if(strategy_swing_lookback_h4 <= 1 || strategy_entry_buffer_points < 0 || strategy_sl_buffer_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "ELDER_TRIPLE_SCREEN";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_pending_expiry_hours * 3600;

   if(Strategy_HasOpenOrPending())
      return false;

   const int direction = Strategy_D1Direction();
   if(direction == 0)
      return false;

   const double rsi_h4 = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi_h4 <= 0.0)
      return false;
   if(direction > 0 && rsi_h4 >= strategy_rsi_long_max)
      return false;
   if(direction < 0 && rsi_h4 <= strategy_rsi_short_min)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double entry_buffer = MathMax((double)strategy_entry_buffer_points, (double)spread_points) * point;
   const double sl_buffer = (double)strategy_sl_buffer_points * point;

   const double h1_high = iHigh(_Symbol, PERIOD_H1, 1);
   const double h1_low = iLow(_Symbol, PERIOD_H1, 1);
   if(h1_high <= 0.0 || h1_low <= 0.0)
      return false;

   if(direction > 0)
     {
      req.type = QM_BUY_STOP;
      req.price = QM_StopRulesNormalizePrice(_Symbol, h1_high + entry_buffer);
      const double swing_low = Strategy_LowestLow(PERIOD_H4, 1, strategy_swing_lookback_h4);
      req.sl = QM_StopRulesNormalizePrice(_Symbol, swing_low - sl_buffer);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(req.price <= ask + point * 0.5 || req.sl <= 0.0 || req.sl >= req.price)
         return false;
     }
   else
     {
      req.type = QM_SELL_STOP;
      req.price = QM_StopRulesNormalizePrice(_Symbol, h1_low - entry_buffer);
      const double swing_high = Strategy_HighestHigh(PERIOD_H4, 1, strategy_swing_lookback_h4);
      req.sl = QM_StopRulesNormalizePrice(_Symbol, swing_high + sl_buffer);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(req.price >= bid - point * 0.5 || req.sl <= 0.0 || req.sl <= req.price)
         return false;
     }

   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_rr_target);
   if(req.tp <= 0.0)
      return false;
   req.reason = (direction > 0) ? "ELDER_TRIPLE_LONG_STOP" : "ELDER_TRIPLE_SHORT_STOP";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12959\",\"ea\":\"elder-triple-screen-swing\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
