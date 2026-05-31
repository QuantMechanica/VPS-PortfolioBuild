#property strict
#property version   "5.0"
#property description "QM5_10544 MQL5 Forex Profit EMA SAR Cross"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10544;
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
input ENUM_TIMEFRAMES strategy_timeframe      = PERIOD_H1;
input int    strategy_ema_fast_period         = 10;
input int    strategy_ema_mid_period          = 25;
input int    strategy_ema_slow_period         = 50;
input double strategy_sar_step                = 0.02;
input double strategy_sar_maximum             = 0.20;
input int    strategy_sar_warmup_bars         = 120;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 1.50;
input double strategy_target_rr               = 1.50;
input int    strategy_min_profit_points       = 0;
input int    strategy_max_spread_points       = 0;

bool Strategy_ReadSAR(const int shift, double &out_sar)
  {
   out_sar = 0.0;
   if(shift < 1 || strategy_sar_step <= 0.0 || strategy_sar_maximum <= 0.0 ||
      strategy_sar_warmup_bars < 10)
      return false;

   const int available_bars = Bars(_Symbol, strategy_timeframe);
   const int start = MathMin(strategy_sar_warmup_bars, available_bars - 2);
   if(start <= shift + 2)
      return false;

   double high_start = iHigh(_Symbol, strategy_timeframe, start);
   double low_start = iLow(_Symbol, strategy_timeframe, start);
   double close_start = iClose(_Symbol, strategy_timeframe, start);
   double close_next = iClose(_Symbol, strategy_timeframe, start - 1);
   if(high_start <= 0.0 || low_start <= 0.0 || close_start <= 0.0 || close_next <= 0.0)
      return false;

   bool uptrend = (close_next >= close_start);
   double sar = uptrend ? low_start : high_start;
   double ep = uptrend ? high_start : low_start;
   double af = strategy_sar_step;

   for(int i = start - 1; i >= shift; --i)
     {
      const double high_i = iHigh(_Symbol, strategy_timeframe, i);
      const double low_i = iLow(_Symbol, strategy_timeframe, i);
      const double high_prev = iHigh(_Symbol, strategy_timeframe, i + 1);
      const double low_prev = iLow(_Symbol, strategy_timeframe, i + 1);
      if(high_i <= 0.0 || low_i <= 0.0 || high_prev <= 0.0 || low_prev <= 0.0)
         return false;

      sar = sar + af * (ep - sar);

      if(uptrend)
        {
         sar = MathMin(sar, low_prev);
         if(low_i < sar)
           {
            uptrend = false;
            sar = ep;
            ep = low_i;
            af = strategy_sar_step;
           }
         else if(high_i > ep)
           {
            ep = high_i;
            af = MathMin(af + strategy_sar_step, strategy_sar_maximum);
           }
        }
      else
        {
         sar = MathMax(sar, high_prev);
         if(high_i > sar)
           {
            uptrend = true;
            sar = ep;
            ep = high_i;
            af = strategy_sar_step;
           }
         else if(low_i < ep)
           {
            ep = low_i;
            af = MathMin(af + strategy_sar_step, strategy_sar_maximum);
           }
        }
     }

   out_sar = sar;
   return (out_sar > 0.0);
  }

bool Strategy_HasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

int Strategy_EMASARCrossSignal()
  {
   if(strategy_ema_fast_period <= 0 ||
      strategy_ema_mid_period <= 0 ||
      strategy_ema_slow_period <= 0)
      return 0;

   const int warmup = MathMax(strategy_ema_slow_period, strategy_atr_period) + 5;
   if(Bars(_Symbol, strategy_timeframe) < warmup)
      return 0;

   const double fast1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double fast2 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast_period, 2, PRICE_CLOSE);
   const double mid1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_mid_period, 1, PRICE_CLOSE);
   const double mid2 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_mid_period, 2, PRICE_CLOSE);
   const double slow1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_slow_period, 1, PRICE_CLOSE);
   const double slow2 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_slow_period, 2, PRICE_CLOSE);
   const double close1 = iClose(_Symbol, strategy_timeframe, 1);
   double sar1 = 0.0;

   if(fast1 <= 0.0 || fast2 <= 0.0 || mid1 <= 0.0 || mid2 <= 0.0 ||
      slow1 <= 0.0 || slow2 <= 0.0 || close1 <= 0.0 || !Strategy_ReadSAR(1, sar1))
      return 0;

   const bool long_cross = (fast2 <= mid2 && fast2 <= slow2 && fast1 > mid1 && fast1 > slow1 && sar1 < close1);
   const bool short_cross = (fast2 >= mid2 && fast2 >= slow2 && fast1 < mid1 && fast1 < slow1 && sar1 > close1);

   if(long_cross)
      return 1;
   if(short_cross)
      return -1;
   return 0;
  }

// No Trade Filter (time, spread, news): framework handles time, news and
// Friday close; this hook only applies the card-neutral spread ceiling.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points < 0 || spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry: EMA10 crosses both EMA25 and EMA50 on a closed H1 bar, with
// Parabolic SAR on the same side as the card requires.
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

   const int signal = Strategy_EMASARCrossSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_target_rr);
   if(entry <= 0.0 || atr <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "FOREXPROF_EMA_SAR_LONG" : "FOREXPROF_EMA_SAR_SHORT";
   return true;
  }

// Trade Management: the card baseline uses broker SL/TP only.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: close after minimum profit when EMA10 turns opposite.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_ema_fast_period <= 0)
      return false;

   const double ema1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double ema2 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast_period, 2, PRICE_CLOSE);
   const double ema3 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast_period, 3, PRICE_CLOSE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ema1 <= 0.0 || ema2 <= 0.0 || ema3 <= 0.0 || point <= 0.0)
      return false;

   const bool fast_turn_down = (ema3 < ema2 && ema1 < ema2);
   const bool fast_turn_up = (ema3 > ema2 && ema1 > ema2);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_price = (position_type == POSITION_TYPE_BUY)
                                   ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || current_price <= 0.0)
         continue;

      double profit_points = 0.0;
      if(position_type == POSITION_TYPE_BUY)
         profit_points = (current_price - open_price) / point;
      else
         profit_points = (open_price - current_price) / point;

      if(profit_points < strategy_min_profit_points)
         continue;

      if(position_type == POSITION_TYPE_BUY && fast_turn_down)
         return true;
      if(position_type == POSITION_TYPE_SELL && fast_turn_up)
         return true;
     }

   return false;
  }

// News Filter Hook: no card-specific override; central framework news mode applies.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
