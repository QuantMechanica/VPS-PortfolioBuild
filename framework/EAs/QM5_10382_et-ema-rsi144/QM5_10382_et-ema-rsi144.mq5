#property strict
#property version   "5.0"
#property description "QM5_10382 Elite Trader EMA RSI 144"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10382;
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
input int    strategy_fast_ema_period     = 144;
input int    strategy_slow_ema_period     = 169;
input int    strategy_rsi_period          = 14;
input double strategy_rsi_oversold        = 35.0;
input double strategy_rsi_overbought      = 65.0;
input int    strategy_rsi_lookback_days   = 5;
input int    strategy_stop_pips           = 20;
input int    strategy_target_pips         = 100;
input int    strategy_nonfx_atr_period    = 20;
input double strategy_nonfx_atr_mult      = 1.0;

// No Trade Filter (time, spread, news): framework handles central news and
// Friday close. Card entry-only gates are kept in Trade Entry so exits and
// trade management are not blocked during the Friday pre-close hour.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: H1 EMA(144/169) cross, recent RSI extreme, stop entry at EMA(144).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_H1)
      return false;
   if(strategy_fast_ema_period <= 0 || strategy_slow_ema_period <= 0 ||
      strategy_rsi_period <= 0 || strategy_rsi_lookback_days <= 0 ||
      strategy_stop_pips <= 0 || strategy_target_pips <= 0 ||
      strategy_nonfx_atr_period <= 0 || strategy_nonfx_atr_mult <= 0.0)
      return false;

   MqlDateTime broker_dt;
   TimeToStruct(TimeCurrent(), broker_dt);
   if(broker_dt.day_of_week == 5 && broker_dt.hour >= qm_friday_close_hour_broker - 1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE pending_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(pending_type == ORDER_TYPE_BUY_STOP || pending_type == ORDER_TYPE_SELL_STOP)
         return false;
     }

   const double fast_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema_period, 1);
   const double fast_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema_period, 2);
   const double slow_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_slow_ema_period, 1);
   const double slow_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_slow_ema_period, 2);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0)
      return false;

   const bool long_cross = (fast_2 <= slow_2 && fast_1 > slow_1);
   const bool short_cross = (fast_2 >= slow_2 && fast_1 < slow_1);
   if(!long_cross && !short_cross)
      return false;

   bool rsi_extreme_seen = false;
   const int rsi_lookback_bars = strategy_rsi_lookback_days * 24;
   for(int shift = 1; shift <= rsi_lookback_bars; ++shift)
     {
      const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift);
      if(rsi <= 0.0)
         continue;
      if(long_cross && rsi <= strategy_rsi_oversold)
        {
         rsi_extreme_seen = true;
         break;
        }
      if(short_cross && rsi >= strategy_rsi_overbought)
        {
         rsi_extreme_seen = true;
         break;
        }
     }
   if(!rsi_extreme_seen)
      return false;

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(tick_size <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const bool non_fx_port = (StringFind(_Symbol, "XAU") >= 0 ||
                             StringFind(_Symbol, "XAG") >= 0 ||
                             StringFind(_Symbol, "XTI") >= 0 ||
                             StringFind(_Symbol, "XNG") >= 0 ||
                             StringFind(_Symbol, "NDX") >= 0 ||
                             StringFind(_Symbol, "WS30") >= 0 ||
                             StringFind(_Symbol, "SP500") >= 0 ||
                             StringFind(_Symbol, "GDAXI") >= 0 ||
                             StringFind(_Symbol, "UK100") >= 0);

   if(long_cross)
     {
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(fast_1 + tick_size, _Digits);
      if(req.price <= ask + tick_size)
         return false;
      req.sl = non_fx_port
               ? QM_StopATR(_Symbol, req.type, req.price, strategy_nonfx_atr_period, strategy_nonfx_atr_mult)
               : QM_StopFixedPips(_Symbol, req.type, req.price, strategy_stop_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, req.price, strategy_target_pips);
      req.reason = "ET_EMA_RSI144_LONG_STOP";
     }
   else
     {
      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(fast_1 - tick_size, _Digits);
      if(req.price >= bid - tick_size)
         return false;
      req.sl = non_fx_port
               ? QM_StopATR(_Symbol, req.type, req.price, strategy_nonfx_atr_period, strategy_nonfx_atr_mult)
               : QM_StopFixedPips(_Symbol, req.type, req.price, strategy_stop_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, req.price, strategy_target_pips);
      req.reason = "ET_EMA_RSI144_SHORT_STOP";
     }

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   const double spread = ask - bid;
   const double stop_distance = MathAbs(req.price - req.sl);
   return (spread > 0.0 && stop_distance >= 4.0 * spread);
  }

// Trade Management: card baseline has no trailing, break-even, scale-in, or partial exits.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: close if EMA(144) crosses back through EMA(169) before SL/TP.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_position = false;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_position = true;
      break;
     }
   if(!have_position)
      return false;

   const double fast_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema_period, 1);
   const double fast_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema_period, 2);
   const double slow_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_slow_ema_period, 1);
   const double slow_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_slow_ema_period, 2);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
      return (fast_2 >= slow_2 && fast_1 < slow_1);
   if(position_type == POSITION_TYPE_SELL)
      return (fast_2 <= slow_2 && fast_1 > slow_1);

   return false;
  }

// News Filter Hook: callable for P8; no strategy-specific news override.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10382_et-ema-rsi144\"}");
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
