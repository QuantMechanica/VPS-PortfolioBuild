#property strict
#property version   "5.0"
#property description "QM5_10191 TradingView Gold Two-Bar Volume Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10191;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_volume_sma_period = 20;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.0;
input double strategy_atr_tp_mult       = 1.5;
input double strategy_source_tp_price   = 5.0;
input double strategy_max_spread_atr    = 0.15;
input int    strategy_max_hold_bars     = 12;

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5 && _Period != PERIOD_M15 && _Period != PERIOD_M30)
      return true;

   if(strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0 || strategy_max_spread_atr <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double stop_distance = atr * strategy_atr_sl_mult;
   if(stop_distance <= 0.0)
      return true;

   return ((ask - bid) > stop_distance * strategy_max_spread_atr);
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

   if(strategy_volume_sma_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0 ||
      strategy_source_tp_price <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   double volume_sum_1 = 0.0;
   double volume_sum_2 = 0.0;
   int samples_1 = 0;
   int samples_2 = 0;
   for(int shift = 1; shift <= strategy_volume_sma_period; ++shift)
     {
      const long volume_1 = iVolume(_Symbol, _Period, shift);
      const long volume_2 = iVolume(_Symbol, _Period, shift + 1);
      if(volume_1 > 0)
        {
         volume_sum_1 += (double)volume_1;
         samples_1++;
        }
      if(volume_2 > 0)
        {
         volume_sum_2 += (double)volume_2;
         samples_2++;
        }
     }
   if(samples_1 != strategy_volume_sma_period || samples_2 != strategy_volume_sma_period)
      return false;

   const double open_1 = iOpen(_Symbol, _Period, 1);
   const double close_1 = iClose(_Symbol, _Period, 1);
   const double open_2 = iOpen(_Symbol, _Period, 2);
   const double close_2 = iClose(_Symbol, _Period, 2);
   const long volume_1 = iVolume(_Symbol, _Period, 1);
   const long volume_2 = iVolume(_Symbol, _Period, 2);
   const double volume_sma_1 = volume_sum_1 / (double)strategy_volume_sma_period;
   const double volume_sma_2 = volume_sum_2 / (double)strategy_volume_sma_period;

   if(open_1 <= 0.0 || close_1 <= open_1 || open_2 <= 0.0 || close_2 <= open_2)
      return false;
   if(volume_1 <= 0 || volume_2 <= 0)
      return false;
   if((double)volume_1 <= volume_sma_1 || (double)volume_2 <= volume_sma_2)
      return false;
   if(volume_1 <= volume_2)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(ask <= 0.0 || atr <= 0.0)
      return false;

   const double sl_distance = atr * strategy_atr_sl_mult;
   const double tp_distance = MathMax(strategy_source_tp_price, atr * strategy_atr_tp_mult);
   if(sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = NormalizeDouble(ask - sl_distance, _Digits);
   req.tp = NormalizeDouble(ask + tp_distance, _Digits);
   req.reason = "two_bullish_volume_bars";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or add-on logic.
  }

bool Strategy_ExitSignal()
  {
   if(strategy_volume_sma_period < 2 || strategy_max_hold_bars < 1)
      return false;

   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      have_position = true;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(!have_position)
      return false;

   if(open_time > 0)
     {
      const int bars_since_open = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, open_time, false);
      if(bars_since_open >= strategy_max_hold_bars)
         return true;
     }

   double volume_sum_1 = 0.0;
   double volume_sum_2 = 0.0;
   int samples_1 = 0;
   int samples_2 = 0;
   for(int shift = 1; shift <= strategy_volume_sma_period; ++shift)
     {
      const long volume_1 = iVolume(_Symbol, _Period, shift);
      const long volume_2 = iVolume(_Symbol, _Period, shift + 1);
      if(volume_1 > 0)
        {
         volume_sum_1 += (double)volume_1;
         samples_1++;
        }
      if(volume_2 > 0)
        {
         volume_sum_2 += (double)volume_2;
         samples_2++;
        }
     }
   if(samples_1 != strategy_volume_sma_period || samples_2 != strategy_volume_sma_period)
      return false;

   const double open_1 = iOpen(_Symbol, _Period, 1);
   const double close_1 = iClose(_Symbol, _Period, 1);
   const double open_2 = iOpen(_Symbol, _Period, 2);
   const double close_2 = iClose(_Symbol, _Period, 2);
   const long volume_1 = iVolume(_Symbol, _Period, 1);
   const long volume_2 = iVolume(_Symbol, _Period, 2);

   return (open_1 > 0.0 &&
           close_1 > 0.0 &&
           close_1 < open_1 &&
           open_2 > 0.0 &&
           close_2 > 0.0 &&
           close_2 < open_2 &&
           volume_1 > 0 &&
           volume_2 > 0 &&
           (double)volume_1 > volume_sum_1 / (double)strategy_volume_sma_period &&
           (double)volume_2 > volume_sum_2 / (double)strategy_volume_sma_period);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10191_tv_gold_vol2bar\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
