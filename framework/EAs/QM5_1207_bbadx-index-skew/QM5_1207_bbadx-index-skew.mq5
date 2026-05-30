#property strict
#property version   "5.0"
#property description "QM5_1207 Bollinger breakout with ADX index filter"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1207;
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
input int    strategy_timeframe_minutes  = 1440;
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 2.0;
input int    strategy_adx_period         = 14;
input double strategy_adx_threshold      = 20.0;
input int    strategy_atr_period         = 20;
input double strategy_stop_atr_cap       = 3.0;
input int    strategy_min_bars           = 60;
input int    strategy_max_hold_bars      = 5;
input int    strategy_max_spread_points  = 350;
input bool   strategy_allow_ports        = true;

datetime g_last_signal_bar = 0;

ENUM_TIMEFRAMES Strategy_Timeframe()
  {
   return PERIOD_D1;
  }

int Strategy_SymbolSlot()
  {
   if(_Symbol == "GER40.DWX")
      return 0;
   if(strategy_allow_ports && _Symbol == "UK100.DWX")
      return 1;
   if(strategy_allow_ports && _Symbol == "JPN225.DWX")
      return 2;
   return -1;
  }

bool Strategy_TimeframeSupported()
  {
   return (_Period == Strategy_Timeframe());
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

bool Strategy_StopDistanceAllowed(const QM_OrderType type, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(type == QM_BUY && sl >= entry)
      return false;
   if(type == QM_SELL && sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

double Strategy_CappedBandStop(const QM_OrderType side,
                               const double entry,
                               const double lower_band,
                               const double upper_band,
                               const double atr)
  {
   if(side == QM_BUY)
     {
      const double band_stop = lower_band;
      const double capped_stop = entry - atr * strategy_stop_atr_cap;
      return NormalizeDouble(MathMax(band_stop, capped_stop), _Digits);
     }

   const double band_stop = upper_band;
   const double capped_stop = entry + atr * strategy_stop_atr_cap;
   return NormalizeDouble(MathMin(band_stop, capped_stop), _Digits);
  }

bool Strategy_NoTradeFilter()
  {
   const int slot = Strategy_SymbolSlot();
   if(slot < 0 || slot != qm_magic_slot_offset)
      return true;
   if(!Strategy_TimeframeSupported())
      return true;
   if(strategy_bb_period < 2 || strategy_bb_deviation <= 0.0)
      return true;
   if(strategy_adx_period < 2 || strategy_adx_threshold < 0.0)
      return true;
   if(strategy_atr_period < 2 || strategy_stop_atr_cap <= 0.0)
      return true;
   if(strategy_min_bars < 1 || strategy_max_hold_bars < 1)
      return true;

   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
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

   if(Strategy_HasOpenPosition())
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_Timeframe();
   if(iBars(_Symbol, tf) < strategy_min_bars)
      return false;

   const datetime signal_bar = iTime(_Symbol, tf, 1);
   if(signal_bar <= 0 || signal_bar == g_last_signal_bar)
      return false;

   const double close1 = iClose(_Symbol, tf, 1);
   const double upper1 = QM_BB_Upper(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower1 = QM_BB_Lower(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double adx1 = QM_ADX(_Symbol, tf, strategy_adx_period, 1);
   const double atr1 = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(close1 <= 0.0 || upper1 <= 0.0 || lower1 <= 0.0 || adx1 <= 0.0 || atr1 <= 0.0)
      return false;
   if(adx1 < strategy_adx_threshold)
      return false;

   const bool long_signal = (close1 > upper1);
   const bool short_signal = (close1 < lower1);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = Strategy_CappedBandStop(side, entry, lower1, upper1, atr1);
   if(!Strategy_StopDistanceAllowed(side, entry, sl))
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.reason = long_signal ? "BBADX_INDEX_LONG" : "BBADX_INDEX_SHORT";
   g_last_signal_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const ENUM_TIMEFRAMES tf = Strategy_Timeframe();
   const double close1 = iClose(_Symbol, tf, 1);
   const double middle1 = QM_BB_Middle(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   if(close1 <= 0.0 || middle1 <= 0.0)
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && close1 < middle1)
         return true;
      if(pos_type == POSITION_TYPE_SELL && close1 > middle1)
         return true;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, tf, opened_at, false);
      if(open_shift >= strategy_max_hold_bars)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1207\",\"ea\":\"bbadx-index-skew\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
