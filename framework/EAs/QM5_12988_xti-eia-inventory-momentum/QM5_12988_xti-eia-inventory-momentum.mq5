#property strict
#property version   "5.0"
#property description "QM5_12988 XTI EIA inventory momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12988 - XTI EIA Inventory Momentum
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - uses Wednesday/Thursday D1 bars as WPSR proxy reaction bars
//   - requires two same-direction weekly reactions plus Donchian confirmation
//   - ATR stop, SMA/time exits, no external data feed
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12988;
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
input int    strategy_atr_period          = 20;
input int    strategy_trend_period        = 80;
input int    strategy_breakout_lookback   = 20;
input int    strategy_event_search_bars   = 10;
input int    strategy_min_event_gap_days  = 4;
input int    strategy_max_event_gap_days  = 10;
input double strategy_min_event_move_atr  = 0.50;
input double strategy_atr_sl_mult         = 2.75;
input int    strategy_max_hold_days       = 10;
input int    strategy_max_spread_points   = 1000;

int g_last_signal_day_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_IsWpsrProxyDay(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   return (dt.day_of_week == 3 || dt.day_of_week == 4);
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_FindPreviousEventShift(const datetime latest_time, int &previous_shift)
  {
   previous_shift = -1;
   const int min_gap_seconds = MathMax(1, strategy_min_event_gap_days) * 86400;
   const int max_gap_seconds = MathMax(strategy_min_event_gap_days, strategy_max_event_gap_days) * 86400;

   for(int shift = 2; shift <= strategy_event_search_bars + 1; ++shift)
     {
      const datetime candidate_time = iTime(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 event search behind new-bar gate.
      if(candidate_time <= 0)
         return false;
      if(!Strategy_IsWpsrProxyDay(candidate_time))
         continue;

      const int gap_seconds = (int)(latest_time - candidate_time);
      if(gap_seconds >= min_gap_seconds && gap_seconds <= max_gap_seconds)
        {
         previous_shift = shift;
         return true;
        }
     }
   return false;
  }

bool Strategy_DonchianExcludingSignal(double &highest_high, double &lowest_low)
  {
   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;

   const int lookback = MathMax(5, strategy_breakout_lookback);
   for(int shift = 2; shift < lookback + 2; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 breakout state behind new-bar gate.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: D1 breakout state behind new-bar gate.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);
     }

   return (highest_high > 0.0 && lowest_low > 0.0 && highest_high >= lowest_low);
  }

bool Strategy_LoadMomentumState(int &direction,
                                double &atr_last,
                                double &sma_last,
                                int &signal_day_key)
  {
   direction = 0;
   atr_last = 0.0;
   sma_last = 0.0;
   signal_day_key = 0;

   const datetime latest_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 calendar event gate.
   if(latest_time <= 0 || !Strategy_IsWpsrProxyDay(latest_time))
      return false;

   int previous_shift = -1;
   if(!Strategy_FindPreviousEventShift(latest_time, previous_shift))
      return false;

   const double latest_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: closed D1 event state.
   const double latest_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: closed D1 event state.
   const double latest_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: closed D1 event state.
   const double latest_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 event state.
   const double previous_open = iOpen(_Symbol, PERIOD_D1, previous_shift);   // perf-allowed: prior weekly D1 event bar behind new-bar gate.
   const double previous_close = iClose(_Symbol, PERIOD_D1, previous_shift); // perf-allowed: prior weekly D1 event bar behind new-bar gate.
   if(latest_open <= 0.0 || latest_high <= 0.0 || latest_low <= 0.0 || latest_close <= 0.0)
      return false;
   if(previous_open <= 0.0 || previous_close <= 0.0 || latest_high <= latest_low)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;

   const double latest_body = latest_close - latest_open;
   const double previous_body = previous_close - previous_open;
   if(latest_body == 0.0 || previous_body == 0.0)
      return false;

   if(latest_body > 0.0 && previous_body > 0.0)
      direction = 1;
   else if(latest_body < 0.0 && previous_body < 0.0)
      direction = -1;
   else
      return false;

   const double event_move = latest_close - previous_close;
   if(direction > 0 && event_move < strategy_min_event_move_atr * atr_last)
      return false;
   if(direction < 0 && event_move > -strategy_min_event_move_atr * atr_last)
      return false;

   double breakout_high = 0.0;
   double breakout_low = 0.0;
   if(!Strategy_DonchianExcludingSignal(breakout_high, breakout_low))
      return false;

   if(direction > 0)
     {
      if(latest_close <= sma_last || latest_close <= breakout_high)
         return false;
     }
   else
     {
      if(latest_close >= sma_last || latest_close >= breakout_low)
         return false;
     }

   signal_day_key = Strategy_DayKey(latest_time);
   return (signal_day_key > 0);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 trend exit behind new-bar gate.
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      bool should_close = false;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(close_last > 0.0 && sma_last > 0.0)
        {
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pos_type == POSITION_TYPE_BUY && close_last < sma_last)
            should_close = true;
         if(pos_type == POSITION_TYPE_SELL && close_last > sma_last)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_atr_period <= 0 || strategy_trend_period <= 1)
      return true;
   if(strategy_breakout_lookback < 5 || strategy_event_search_bars < 3)
      return true;
   if(strategy_min_event_gap_days <= 0 || strategy_max_event_gap_days < strategy_min_event_gap_days)
      return true;
   if(strategy_min_event_move_atr < 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12988_XTI_EIA_INV_MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   int direction = 0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   int signal_day_key = 0;
   if(!Strategy_LoadMomentumState(direction, atr_last, sma_last, signal_day_key))
      return false;
   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "XTI_WPSR_2W_MOM_LONG" : "XTI_WPSR_2W_MOM_SHORT";
   g_last_signal_day_key = signal_day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12988\",\"ea\":\"xti-eia-inventory-momentum\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
