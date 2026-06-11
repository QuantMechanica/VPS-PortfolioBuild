#property strict
#property version   "5.0"
#property description "QM5_12450 EA31337 MA Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12450;
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
input int                strategy_ma_period                = 22;
input ENUM_MA_METHOD     strategy_ma_method                = MODE_LWMA;
input ENUM_APPLIED_PRICE strategy_ma_price                 = PRICE_TYPICAL;
input double             strategy_signal_open_level_pips   = 7.0;
input int                strategy_extreme_lookback_bars    = 4;
input double             strategy_max_spread_pips          = 4.0;
input int                strategy_fixed_sl_pips            = 80;
input int                strategy_fixed_tp_pips            = 80;
input double             strategy_source_stop_offset_pips  = 2.0;
input int                strategy_atr_period               = 14;
input double             strategy_atr_sl_mult              = 2.0;
input int                strategy_time_exit_bars           = 30;

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

double Strategy_MA(const ENUM_TIMEFRAMES tf, const int shift)
  {
   switch(strategy_ma_method)
     {
      case MODE_EMA:
         return QM_EMA(_Symbol, tf, strategy_ma_period, shift, strategy_ma_price);
      case MODE_SMMA:
         return QM_SMMA(_Symbol, tf, strategy_ma_period, shift, strategy_ma_price);
      case MODE_LWMA:
         return QM_LWMA(_Symbol, tf, strategy_ma_period, shift, strategy_ma_price);
      case MODE_SMA:
      default:
         return QM_SMA(_Symbol, tf, strategy_ma_period, shift, strategy_ma_price);
     }
  }

bool Strategy_TrendSignal(const int desired_direction)
  {
   if(strategy_ma_period < 1 || strategy_extreme_lookback_bars < 4)
      return false;

   const ENUM_TIMEFRAMES chart_tf = (ENUM_TIMEFRAMES)_Period;
   const double pip = Strategy_PipSize();
   if(pip <= 0.0)
      return false;

   const double level = strategy_signal_open_level_pips * pip;
   const double chart_1 = Strategy_MA(chart_tf, 1);
   const double chart_2 = Strategy_MA(chart_tf, 2);
   const double d1_1 = Strategy_MA(PERIOD_D1, 1);
   const double d1_2 = Strategy_MA(PERIOD_D1, 2);
   if(chart_1 <= 0.0 || chart_2 <= 0.0 || d1_1 <= 0.0 || d1_2 <= 0.0)
      return false;

   const double d1_delta = d1_1 - d1_2;
   if(MathAbs(d1_delta) <= level)
      return false;

   if(desired_direction > 0)
     {
      if(chart_1 <= chart_2 || d1_delta <= level)
         return false;
      for(int shift = 2; shift <= strategy_extreme_lookback_bars; ++shift)
        {
         const double v = Strategy_MA(chart_tf, shift);
         if(v <= 0.0 || chart_1 < v)
            return false;
        }
      return true;
     }

   if(desired_direction < 0)
     {
      if(chart_1 >= chart_2 || d1_delta >= -level)
         return false;
      for(int shift = 2; shift <= strategy_extreme_lookback_bars; ++shift)
        {
         const double v = Strategy_MA(chart_tf, shift);
         if(v <= 0.0 || chart_1 > v)
            return false;
        }
      return true;
     }

   return false;
  }

double Strategy_SourceStyleStop(const QM_OrderType side, const double entry)
  {
   const double pip = Strategy_PipSize();
   const double d1_ma = Strategy_MA(PERIOD_D1, 1);
   if(pip <= 0.0 || d1_ma <= 0.0 || entry <= 0.0)
      return 0.0;

   const double offset = strategy_source_stop_offset_pips * pip;
   const double candidate = (side == QM_BUY) ? d1_ma - offset : d1_ma + offset;
   if(side == QM_BUY && candidate >= entry)
      return 0.0;
   if(side == QM_SELL && candidate <= entry)
      return 0.0;
   return candidate;
  }

double Strategy_ProtectiveStop(const QM_OrderType side, const double entry)
  {
   double sl = Strategy_SourceStyleStop(side, entry);
   if(sl > 0.0)
      return sl;

   sl = QM_StopFixedPips(_Symbol, side, entry, strategy_fixed_sl_pips);
   if(sl > 0.0)
      return sl;

   return QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
  }

bool Strategy_NoTradeFilter()
  {
   const double pip = Strategy_PipSize();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(pip <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_pips = (ask - bid) / pip;
   return (spread_pips > strategy_max_spread_pips);
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

   int direction = 0;
   if(Strategy_TrendSignal(1))
      direction = 1;
   else if(Strategy_TrendSignal(-1))
      direction = -1;
   else
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = Strategy_ProtectiveStop(side, entry);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_fixed_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "EA31337_MATREND_LONG" : "EA31337_MATREND_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime now = TimeCurrent();
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const int max_hold_seconds = MathMax(1, strategy_time_exit_bars) * period_seconds;

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
      if(opened > 0 && max_hold_seconds > 0 && now - opened >= max_hold_seconds)
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && Strategy_TrendSignal(-1))
         return true;
      if(ptype == POSITION_TYPE_SELL && Strategy_TrendSignal(1))
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
