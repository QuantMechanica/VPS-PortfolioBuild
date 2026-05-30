#property strict
#property version   "5.0"
#property description "QM5_10208 TradingView PSAR ATR SMA Trend Trail"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10208;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_H1;
input int    strategy_sma_period               = 100;
input int    strategy_atr_period               = 14;
input double strategy_atr_stop_mult            = 6.0;
input double strategy_psar_start               = 0.02;
input double strategy_psar_increment           = 0.02;
input double strategy_psar_maximum             = 0.20;
input double strategy_max_spread_stop_fraction = 0.15;
input int    strategy_psar_warmup_bars         = 80;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool GetOurPosition(ENUM_POSITION_TYPE &position_type, double &open_price, ulong &ticket)
  {
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      ticket = t;
      return true;
     }

   return false;
  }

bool ComputePSAR(const string sym,
                 const ENUM_TIMEFRAMES tf,
                 const double start_af,
                 const double increment,
                 const double maximum,
                 const int shift,
                 double &sar,
                 bool &uptrend)
  {
   sar = 0.0;
   uptrend = true;

   const int lookback = MathMax(strategy_psar_warmup_bars, 20);
   const int oldest = shift + lookback - 1;
   if(Bars(sym, tf) <= oldest + 3 || start_af <= 0.0 || increment <= 0.0 || maximum <= 0.0)
      return false;

   const double old_close = iClose(sym, tf, oldest);
   const double newer_close = iClose(sym, tf, oldest - 1);
   if(old_close <= 0.0 || newer_close <= 0.0)
      return false;

   uptrend = (newer_close >= old_close);
   double ep = 0.0;
   if(uptrend)
     {
      sar = MathMin(iLow(sym, tf, oldest), iLow(sym, tf, oldest - 1));
      ep = MathMax(iHigh(sym, tf, oldest), iHigh(sym, tf, oldest - 1));
     }
   else
     {
      sar = MathMax(iHigh(sym, tf, oldest), iHigh(sym, tf, oldest - 1));
      ep = MathMin(iLow(sym, tf, oldest), iLow(sym, tf, oldest - 1));
     }

   double af = start_af;
   for(int i = oldest - 2; i >= shift; --i)
     {
      const double high_i = iHigh(sym, tf, i);
      const double low_i = iLow(sym, tf, i);
      const double high_prev1 = iHigh(sym, tf, i + 1);
      const double high_prev2 = iHigh(sym, tf, i + 2);
      const double low_prev1 = iLow(sym, tf, i + 1);
      const double low_prev2 = iLow(sym, tf, i + 2);
      if(high_i <= 0.0 || low_i <= 0.0 || high_prev1 <= 0.0 || high_prev2 <= 0.0 ||
         low_prev1 <= 0.0 || low_prev2 <= 0.0)
         return false;

      sar = sar + af * (ep - sar);
      if(uptrend)
        {
         sar = MathMin(sar, MathMin(low_prev1, low_prev2));
         if(low_i < sar)
           {
            uptrend = false;
            sar = ep;
            ep = low_i;
            af = start_af;
           }
         else if(high_i > ep)
           {
            ep = high_i;
            af = MathMin(af + increment, maximum);
           }
        }
      else
        {
         sar = MathMax(sar, MathMax(high_prev1, high_prev2));
         if(high_i > sar)
           {
            uptrend = true;
            sar = ep;
            ep = high_i;
            af = start_af;
           }
         else if(low_i < ep)
           {
            ep = low_i;
            af = MathMin(af + increment, maximum);
           }
        }
     }

   return (sar > 0.0);
  }

double StrategyStopPrice(const QM_OrderType type, const double entry_price)
  {
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0 || entry_price <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return 0.0;

   if(type == QM_BUY)
      return NormalizeStrategyPrice(entry_price - strategy_atr_stop_mult * atr);
   return NormalizeStrategyPrice(entry_price + strategy_atr_stop_mult * atr);
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return true;

   const double spread = ask - bid;
   const double stop_distance = strategy_atr_stop_mult * atr;
   return (spread > strategy_max_spread_stop_fraction * stop_distance);
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

   if(strategy_sma_period <= 1 || strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return false;

   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   ulong ticket = 0;
   if(GetOurPosition(position_type, open_price, ticket))
      return false;

   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   const double close_2 = iClose(_Symbol, strategy_timeframe, 2);
   const double sma = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_period, 1);
   if(close_1 <= 0.0 || close_2 <= 0.0 || sma <= 0.0)
      return false;

   double psar_1 = 0.0;
   double psar_2 = 0.0;
   bool psar_uptrend_1 = true;
   bool psar_uptrend_2 = true;
   if(!ComputePSAR(_Symbol, strategy_timeframe, strategy_psar_start, strategy_psar_increment,
                   strategy_psar_maximum, 1, psar_1, psar_uptrend_1))
      return false;
   if(!ComputePSAR(_Symbol, strategy_timeframe, strategy_psar_start, strategy_psar_increment,
                   strategy_psar_maximum, 2, psar_2, psar_uptrend_2))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close_1 > sma && psar_1 < close_1 && psar_2 >= close_2 && psar_uptrend_1 && !psar_uptrend_2)
     {
      req.type = QM_BUY;
      req.sl = StrategyStopPrice(req.type, ask);
      req.reason = "PSAR_ATR_SMA_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(close_1 < sma && psar_1 > close_1 && psar_2 <= close_2 && !psar_uptrend_1 && psar_uptrend_2)
     {
      req.type = QM_SELL;
      req.sl = StrategyStopPrice(req.type, bid);
      req.reason = "PSAR_ATR_SMA_SHORT";
      return (req.sl > bid);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   ulong ticket = 0;
   if(!GetOurPosition(position_type, open_price, ticket))
      return;

   QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_stop_mult);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10208\",\"ea\":\"QM5_10208_tv-psar-atr-sma\"}");
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
