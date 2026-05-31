#property strict
#property version   "5.0"
#property description "QM5_10554 MQL5 Fractal Force Index zero-cross"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10554;
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
input int            strategy_e_period       = 30;
input int            strategy_normal_speed   = 30;
input ENUM_MA_METHOD strategy_ma_method      = MODE_SMA;
input ENUM_APPLIED_VOLUME strategy_volume_type = VOLUME_TICK;
input int            strategy_atr_period     = 14;
input double         strategy_atr_sl_mult    = 2.0;
input double         strategy_rr_target      = 1.5;

int g_last_frforce_cross = 0;

double Strategy_ClosePrice(const int shift)
  {
   return iClose(_Symbol, _Period, shift);
  }

double Strategy_AveragePrice(const int period, const int shift, const ENUM_MA_METHOD method)
  {
   if(period <= 0 || shift < 0)
      return 0.0;

   if(method == MODE_EMA)
     {
      double ema = Strategy_ClosePrice(shift + period);
      if(ema <= 0.0)
         return 0.0;
      const double alpha = 2.0 / (period + 1.0);
      for(int i = period - 1; i >= 0; --i)
        {
         const double price = Strategy_ClosePrice(shift + i);
         if(price <= 0.0)
            return 0.0;
         ema = price * alpha + ema * (1.0 - alpha);
        }
      return ema;
     }

   if(method == MODE_SMMA)
     {
      double smma = Strategy_ClosePrice(shift + period);
      if(smma <= 0.0)
         return 0.0;
      const int prev_weight = period - 1;
      for(int i = period - 1; i >= 0; --i)
        {
         const double price = Strategy_ClosePrice(shift + i);
         if(price <= 0.0)
            return 0.0;
         smma = (smma * prev_weight + price) / period;
        }
      return smma;
     }

   double sum = 0.0;
   double weight_sum = 0.0;
   for(int i = period - 1; i >= 0; --i)
     {
      const double price = Strategy_ClosePrice(shift + i);
      if(price <= 0.0)
         return 0.0;

      if(method == MODE_LWMA)
        {
         const double weight = (double)(period - i);
         sum += price * weight;
         weight_sum += weight;
        }
      else
        {
         sum += price;
         weight_sum += 1.0;
        }
     }

   if(weight_sum <= 0.0)
      return 0.0;
   return sum / weight_sum;
  }

int Strategy_FractalSpeed(const int shift)
  {
   const int period = strategy_e_period;
   if(period < 2 || strategy_normal_speed < 1)
      return 0;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = 0; i < period; ++i)
     {
      const double price = Strategy_ClosePrice(shift + i);
      if(price <= 0.0)
         return 0;
      highest = MathMax(highest, price);
      lowest = MathMin(lowest, price);
     }

   const double range = highest - lowest;
   if(range <= 0.0)
      return strategy_normal_speed;

   double length = 0.0;
   double prior_diff = 0.0;
   bool have_prior = false;
   for(int i = 0; i < period; ++i)
     {
      const double price = Strategy_ClosePrice(shift + i);
      const double diff = (price - lowest) / range;
      if(have_prior)
         length += MathSqrt(MathPow(diff - prior_diff, 2.0) + (1.0 / MathPow(period, 2.0)));
      prior_diff = diff;
      have_prior = true;
     }

   if(length <= 0.0)
      return strategy_normal_speed;

   const double fdi = 1.0 + (MathLog(length) + MathLog(2.0)) / MathLog(2.0 * (period - 1));
   const double hurst = 2.0 - fdi;
   if(hurst <= 0.0)
      return strategy_normal_speed;

   const double beta = (1.0 / hurst) / 2.0;
   int speed = (int)MathRound(strategy_normal_speed * beta);
   if(speed < 1)
      speed = 1;
   if(speed > 200)
      speed = 200;
   return speed;
  }

double Strategy_FractalForceIndex(const int shift)
  {
   const int speed = Strategy_FractalSpeed(shift);
   if(speed <= 0)
      return 0.0;

   const double ma_now = Strategy_AveragePrice(speed, shift, strategy_ma_method);
   const double ma_prev = Strategy_AveragePrice(speed, shift + 1, strategy_ma_method);
   if(ma_now <= 0.0 || ma_prev <= 0.0)
      return 0.0;

   long vol = 0;
   if(strategy_volume_type == VOLUME_REAL)
      vol = (long)iVolume(_Symbol, _Period, shift);
   else
      vol = (long)iTickVolume(_Symbol, _Period, shift);
   if(vol <= 0)
      return 0.0;

   return (double)vol * (ma_now - ma_prev);
  }

int Strategy_CalcClosedBarCross()
  {
   const double f1 = Strategy_FractalForceIndex(1);
   const double f2 = Strategy_FractalForceIndex(2);
   if(f1 > 0.0 && f2 <= 0.0)
      return 1;
   if(f1 < 0.0 && f2 >= 0.0)
      return -1;
   return 0;
  }

bool Strategy_HasPosition()
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

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "FRFORCE_ZERO_CROSS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_frforce_cross = Strategy_CalcClosedBarCross();
   if(g_last_frforce_cross == 0)
      return false;
   if(Strategy_HasPosition())
      return false;

   const QM_OrderType side = (g_last_frforce_cross > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_target);
   req.reason = (side == QM_BUY) ? "FRFORCE_LONG_ZERO_CROSS" : "FRFORCE_SHORT_ZERO_CROSS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(g_last_frforce_cross == 0)
      return false;

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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((pos_type == POSITION_TYPE_BUY && g_last_frforce_cross < 0) ||
         (pos_type == POSITION_TYPE_SELL && g_last_frforce_cross > 0))
        {
         g_last_frforce_cross = 0;
         return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10554\",\"strategy\":\"mql5-frforce\"}");
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
