#property strict
#property version   "5.0"
#property description "QM5_1240 Bandy Percent-Rank Mean Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1240;
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
input int             strategy_return_bars       = 3;
input int             strategy_prank_lookback     = 100;
input int             strategy_sma_trend_period   = 200;
input int             strategy_sma_guard_period   = 20;
input int             strategy_sma_exit_period    = 5;
input int             strategy_atr_period         = 14;
input double          strategy_entry_prank_long   = 10.0;
input double          strategy_entry_prank_short  = 90.0;
input double          strategy_exit_prank_long    = 55.0;
input double          strategy_exit_prank_short   = 45.0;
input double          strategy_long_crash_mult    = 0.94;
input double          strategy_short_extension_mult = 1.06;
input double          strategy_atr_stop_mult      = 2.5;
input int             strategy_max_hold_bars      = 8;
input int             strategy_min_history_bars   = 260;
input int             strategy_median_tr_period   = 100;
input double          strategy_tr_spike_mult      = 3.0;
input int             strategy_spread_days        = 60;
input double          strategy_spread_mult        = 2.0;
input bool            strategy_enable_shorts      = true;

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

double Strategy_RetN(const int shift)
  {
   const int bars = MathMax(1, strategy_return_bars);
   const double close_now = iClose(_Symbol, strategy_timeframe, shift);
   const double close_then = iClose(_Symbol, strategy_timeframe, shift + bars);
   if(close_now <= 0.0 || close_then <= 0.0)
      return EMPTY_VALUE;

   return close_now / close_then - 1.0;
  }

double Strategy_PercentRankRet(const int shift)
  {
   const double sample = Strategy_RetN(shift);
   if(sample == EMPTY_VALUE)
      return EMPTY_VALUE;

   const int lookback = MathMax(2, strategy_prank_lookback);
   int valid = 0;
   int below_or_equal = 0;

   for(int i = shift; i < shift + lookback; ++i)
     {
      const double value = Strategy_RetN(i);
      if(value == EMPTY_VALUE)
         continue;

      valid++;
      if(value <= sample)
         below_or_equal++;
     }

   if(valid < 2)
      return EMPTY_VALUE;

   return 100.0 * (double)(below_or_equal - 1) / (double)(valid - 1);
  }

double Strategy_TrueRange(const int shift)
  {
   const double high = iHigh(_Symbol, strategy_timeframe, shift);
   const double low = iLow(_Symbol, strategy_timeframe, shift);
   const double prev_close = iClose(_Symbol, strategy_timeframe, shift + 1);
   if(high <= 0.0 || low <= 0.0 || prev_close <= 0.0)
      return 0.0;

   return MathMax(high - low, MathMax(MathAbs(high - prev_close), MathAbs(low - prev_close)));
  }

double Strategy_MedianTrueRange()
  {
   const int lookback = MathMax(2, strategy_median_tr_period);
   double values[];
   ArrayResize(values, lookback);
   int count = 0;

   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double tr = Strategy_TrueRange(shift);
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

bool Strategy_TrueRangeOk()
  {
   const double current_tr = Strategy_TrueRange(1);
   const double median_tr = Strategy_MedianTrueRange();
   if(current_tr <= 0.0 || median_tr <= 0.0)
      return false;

   return (current_tr <= median_tr * strategy_tr_spike_mult);
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

   double values[];
   ArrayResize(values, strategy_spread_days);
   int count = 0;

   for(int shift = 1; shift <= strategy_spread_days; ++shift)
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

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "BANDY_PRANK_MR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int warmup = MathMax(strategy_min_history_bars,
                              strategy_sma_trend_period + strategy_prank_lookback + strategy_return_bars + 5);
   if(Bars(_Symbol, strategy_timeframe) < warmup)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   if(!Strategy_TrueRangeOk() || !Strategy_SpreadOk())
      return false;

   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   const double sma_200 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_trend_period, 1);
   const double sma_20 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_guard_period, 1);
   const double prank = Strategy_PercentRankRet(1);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_1 <= 0.0 || sma_200 <= 0.0 || sma_20 <= 0.0 || prank == EMPTY_VALUE ||
      atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(close_1 > sma_200 && prank <= strategy_entry_prank_long && close_1 > sma_20 * strategy_long_crash_mult)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
      req.reason = "BANDY_PRANK_LONG";
      return (req.sl > 0.0 && req.sl < ask - point);
     }

   if(strategy_enable_shorts && close_1 < sma_200 && prank >= strategy_entry_prank_short &&
      close_1 < sma_20 * strategy_short_extension_mult)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr, strategy_atr_stop_mult);
      req.reason = "BANDY_PRANK_SHORT";
      return (req.sl > bid + point);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline uses the initial ATR protective stop; no trailing stop.
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

   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   const double sma_5 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_exit_period, 1);
   const double prank = Strategy_PercentRankRet(1);
   if(close_1 <= 0.0 || sma_5 <= 0.0 || prank == EMPTY_VALUE)
      return false;

   if(Strategy_BarsHeld(open_time) >= strategy_max_hold_bars)
     {
      g_exit_now = true;
      return true;
     }

   if(ptype == POSITION_TYPE_BUY && (prank >= strategy_exit_prank_long || close_1 > sma_5))
      g_exit_now = true;
   else if(ptype == POSITION_TYPE_SELL && (prank <= strategy_exit_prank_short || close_1 < sma_5))
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1240\",\"ea\":\"QM5_1240_bandy-prank-mr\"}");
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
