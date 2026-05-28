#property strict
#property version   "5.0"
#property description "QM5_10041 ForexFactory 5-Min Bollinger DeMarker ADX Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10041;
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
input int    strategy_bb_period          = 14;
input double strategy_bb_deviation       = 2.0;
input int    strategy_demarker_period    = 14;
input double strategy_demarker_high      = 0.70;
input double strategy_demarker_low       = 0.30;
input int    strategy_adx_period         = 14;
input double strategy_adx_min            = 40.0;
input int    strategy_ema_period         = 14;
input int    strategy_h4_atr_period      = 100;
input double strategy_sl_atr_mult        = 10.0;
input int    strategy_tp_pips            = 20;
input int    strategy_band_window_pips   = 5;
input int    strategy_max_sl_pips        = 600;
input int    strategy_d1_atr_period      = 14;
input double strategy_d1_atr_cap_mult    = 6.0;
input int    strategy_time_stop_days     = 5;
input int    strategy_max_spread_points  = 35;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double Strategy_DeMarker(const int period, const int shift)
  {
   if(period <= 0 || shift < 1)
      return EMPTY_VALUE;

   double demax_sum = 0.0;
   double demin_sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double high_now = iHigh(_Symbol, PERIOD_M5, i);
      const double high_prev = iHigh(_Symbol, PERIOD_M5, i + 1);
      const double low_now = iLow(_Symbol, PERIOD_M5, i);
      const double low_prev = iLow(_Symbol, PERIOD_M5, i + 1);
      if(high_now <= 0.0 || high_prev <= 0.0 || low_now <= 0.0 || low_prev <= 0.0)
         return EMPTY_VALUE;

      if(high_now > high_prev)
         demax_sum += high_now - high_prev;
      if(low_now < low_prev)
         demin_sum += low_prev - low_now;
     }

   const double denom = demax_sum + demin_sum;
   if(denom <= 0.0)
      return 0.5;
   return demax_sum / denom;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5)
      return true;

   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int minute_of_week = (dt.day_of_week * 24 * 60) + (dt.hour * 60) + dt.min;
   if(minute_of_week < 15)
      return true;

   const int friday_last_trade_minute = (5 * 24 * 60) - 15;
   if(minute_of_week >= friday_last_trade_minute)
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

   const double pip = Strategy_PipSize();
   if(pip <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M5, 1);
   const double upper = QM_BB_Upper(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1, PRICE_LOW);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1, PRICE_HIGH);
   const double demarker = Strategy_DeMarker(strategy_demarker_period, 1);
   const double adx = QM_ADX(_Symbol, PERIOD_M5, strategy_adx_period, 1);
   if(close1 <= 0.0 || upper <= 0.0 || lower <= 0.0 || demarker == EMPTY_VALUE || adx <= 0.0)
      return false;

   if(adx < strategy_adx_min)
      return false;
   if(!(demarker > strategy_demarker_high || demarker < strategy_demarker_low))
      return false;

   const double h4_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_h4_atr_period, 1);
   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_d1_atr_period, 1);
   if(h4_atr <= 0.0 || d1_atr <= 0.0)
      return false;

   const double sl_dist = h4_atr * strategy_sl_atr_mult;
   if(sl_dist <= 0.0)
      return false;
   if(sl_dist > strategy_max_sl_pips * pip)
      return false;
   if(sl_dist > strategy_d1_atr_cap_mult * d1_atr)
      return false;

   const double window = strategy_band_window_pips * pip;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(MathAbs(close1 - upper) <= window)
     {
      req.type = QM_BUY;
      req.sl = NormalizeDouble(ask - sl_dist, digits);
      req.tp = NormalizeDouble(ask + (strategy_tp_pips * pip), digits);
      req.reason = "FF_BB_DEMARKER_ADX_LONG";
      return true;
     }

   if(MathAbs(close1 - lower) <= window)
     {
      req.type = QM_SELL;
      req.sl = NormalizeDouble(bid + sl_dist, digits);
      req.tp = NormalizeDouble(bid - (strategy_tp_pips * pip), digits);
      req.reason = "FF_BB_DEMARKER_ADX_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double ema = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1, PRICE_TYPICAL);
   const double close1 = iClose(_Symbol, PERIOD_M5, 1);
   if(ema <= 0.0 || close1 <= 0.0)
      return false;

   const int max_hold_seconds = strategy_time_stop_days * 24 * 60 * 60;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(max_hold_seconds > 0 && TimeCurrent() - opened >= max_hold_seconds)
         return true;

      const double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit <= 0.0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 < ema)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 > ema)
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
