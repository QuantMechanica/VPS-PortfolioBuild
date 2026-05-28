#property strict
#property version   "5.0"
#property description "QM5_1242 Connors Double Seven"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1242;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_D1;
input int             strategy_sma_trend_period   = 200;
input int             strategy_extreme_lookback   = 7;
input int             strategy_atr_period         = 14;
input double          strategy_atr_stop_mult      = 3.0;
input bool            strategy_enable_hard_stop   = true;
input double          strategy_hard_stop_r_mult   = 2.0;
input int             strategy_max_hold_bars      = 12;
input int             strategy_min_history_bars   = 220;
input bool            strategy_enable_shorts      = true;
input int             strategy_median_tr_bars     = 100;
input double          strategy_range_mult         = 3.0;
input int             strategy_spread_days        = 60;
input double          strategy_spread_mult        = 2.0;

datetime g_last_exit_bar = 0;
bool     g_exit_now      = false;

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

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

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_LowestLow(const int lookback, const int start_shift)
  {
   double value = DBL_MAX;
   for(int shift = start_shift; shift < start_shift + lookback; ++shift)
     {
      const double low = iLow(_Symbol, strategy_timeframe, shift);
      if(low <= 0.0)
         return 0.0;
      value = MathMin(value, low);
     }
   return (value == DBL_MAX ? 0.0 : value);
  }

double Strategy_HighestHigh(const int lookback, const int start_shift)
  {
   double value = 0.0;
   for(int shift = start_shift; shift < start_shift + lookback; ++shift)
     {
      const double high = iHigh(_Symbol, strategy_timeframe, shift);
      if(high <= 0.0)
         return 0.0;
      value = MathMax(value, high);
     }
   return value;
  }

double Strategy_MedianTrueRange()
  {
   const int bars = MathMax(1, strategy_median_tr_bars);
   double values[];
   ArrayResize(values, bars);
   int count = 0;

   for(int shift = 1; shift <= bars; ++shift)
     {
      const double high = iHigh(_Symbol, strategy_timeframe, shift);
      const double low = iLow(_Symbol, strategy_timeframe, shift);
      const double prev_close = iClose(_Symbol, strategy_timeframe, shift + 1);
      if(high <= 0.0 || low <= 0.0 || prev_close <= 0.0)
         continue;

      const double tr = MathMax(high - low, MathMax(MathAbs(high - prev_close), MathAbs(low - prev_close)));
      if(tr > 0.0)
        {
         values[count] = tr;
         count++;
        }
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);

   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

bool Strategy_RangeOk()
  {
   const double high_1 = iHigh(_Symbol, strategy_timeframe, 1);
   const double low_1 = iLow(_Symbol, strategy_timeframe, 1);
   const double median_tr = Strategy_MedianTrueRange();
   if(high_1 <= 0.0 || low_1 <= 0.0 || median_tr <= 0.0)
      return true;

   return ((high_1 - low_1) <= median_tr * strategy_range_mult);
  }

double Strategy_MedianSpreadForEntryHour()
  {
   if(strategy_spread_days <= 0)
      return 0.0;

   const datetime signal_bar_time = iTime(_Symbol, strategy_timeframe, 1);
   if(signal_bar_time <= 0)
      return 0.0;

   MqlDateTime signal_dt;
   TimeToStruct(signal_bar_time, signal_dt);

   const int max_shift = MathMax(1, strategy_spread_days);
   double values[];
   ArrayResize(values, max_shift);
   int count = 0;

   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const datetime t = iTime(_Symbol, strategy_timeframe, shift);
      if(t <= 0)
         continue;

      MqlDateTime dt;
      TimeToStruct(t, dt);
      if(dt.hour != signal_dt.hour)
         continue;

      const double spread = (double)iSpread(_Symbol, strategy_timeframe, shift);
      if(spread > 0.0)
        {
         values[count] = spread;
         count++;
        }
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);

   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

bool Strategy_SpreadOk()
  {
   const double median_spread = Strategy_MedianSpreadForEntryHour();
   if(median_spread <= 0.0)
      return true;

   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0.0)
      return false;

   return (current_spread <= median_spread * strategy_spread_mult);
  }

int Strategy_BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   const int shift = iBarShift(_Symbol, strategy_timeframe, open_time, false);
   if(shift < 0)
      return 0;
   return shift;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_timeframe != PERIOD_D1)
      return true;
   if(_Period != strategy_timeframe)
      return true;

   return false;
  }

double Strategy_StopPrice(const QM_OrderType order_type, const double entry_price, const double atr)
  {
   double atr_stop = QM_StopATRFromValue(_Symbol, order_type, entry_price, atr, strategy_atr_stop_mult);
   if(!strategy_enable_hard_stop || atr_stop <= 0.0 || strategy_hard_stop_r_mult <= 0.0)
      return atr_stop;

   const double risk_distance = MathAbs(entry_price - atr_stop);
   if(risk_distance <= 0.0)
      return atr_stop;

   double hard_stop = atr_stop;
   if(order_type == QM_BUY)
      hard_stop = entry_price - (risk_distance * strategy_hard_stop_r_mult);
   else
      hard_stop = entry_price + (risk_distance * strategy_hard_stop_r_mult);

   // The closest protective stop is used when both ATR and hard-stop caps are enabled.
   if(order_type == QM_BUY)
      return MathMax(atr_stop, hard_stop);
   return MathMin(atr_stop, hard_stop);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "CONNORS_DOUBLE7";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int lookback = MathMax(2, strategy_extreme_lookback);
   const int warmup = MathMax(strategy_min_history_bars,
                              strategy_sma_trend_period + strategy_atr_period + strategy_median_tr_bars + lookback + 5);
   if(Bars(_Symbol, strategy_timeframe) < warmup)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   if(!Strategy_RangeOk() || !Strategy_SpreadOk())
      return false;

   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   const double sma_200 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_trend_period, 1);
   const double low_7 = Strategy_LowestLow(lookback, 1);
   const double high_7 = Strategy_HighestHigh(lookback, 1);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_1 <= 0.0 || sma_200 <= 0.0 || low_7 <= 0.0 || high_7 <= 0.0 || atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(close_1 > sma_200 && close_1 <= low_7)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = Strategy_StopPrice(QM_BUY, ask, atr);
      req.reason = "CONNORS_DOUBLE7_LONG";
      return (req.sl > 0.0 && req.sl < ask - point);
     }

   if(strategy_enable_shorts && close_1 < sma_200 && close_1 >= high_7)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = Strategy_StopPrice(QM_SELL, bid, atr);
      req.reason = "CONNORS_DOUBLE7_SHORT";
      return (req.sl > bid + point);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline uses the initial protective stop; no averaging or trailing stop.
  }

bool Strategy_ExitSignal()
  {
   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 0);
   if(bar_time <= 0)
      return false;
   if(bar_time == g_last_exit_bar)
      return g_exit_now;

   g_last_exit_bar = bar_time;
   g_exit_now = false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   const int lookback = MathMax(2, strategy_extreme_lookback);
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   const double low_7 = Strategy_LowestLow(lookback, 1);
   const double high_7 = Strategy_HighestHigh(lookback, 1);
   if(close_1 <= 0.0 || low_7 <= 0.0 || high_7 <= 0.0)
      return false;

   if(Strategy_BarsHeld(open_time) >= strategy_max_hold_bars)
     {
      g_exit_now = true;
      return true;
     }

   if(ptype == POSITION_TYPE_BUY && close_1 >= high_7)
      g_exit_now = true;
   else if(ptype == POSITION_TYPE_SELL && close_1 <= low_7)
      g_exit_now = true;

   return g_exit_now;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1242\",\"ea\":\"QM5_1242_connors-double7\"}");
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
