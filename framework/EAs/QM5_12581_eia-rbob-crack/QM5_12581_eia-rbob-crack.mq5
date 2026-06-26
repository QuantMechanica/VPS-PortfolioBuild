#property strict
#property version   "5.0"
#property description "QM5_12581 EIA RBOB Crack Spread Seasonal Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12581 - EIA RBOB Crack Spread Seasonal Breakout
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - long XTIUSD breakouts during gasoline crack-spread support months
//   - short XTIUSD breakdowns during the autumn crack-spread decline window
// Runtime uses MT5 OHLC only; no external EIA/RBOB/refinery data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12581;
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
input int    strategy_entry_channel       = 20;
input int    strategy_exit_channel        = 10;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 70;
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

int Strategy_MonthFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon;
  }

int Strategy_RegimeDirection(const int month)
  {
   if(month >= 3 && month <= 8)
      return 1;
   if(month == 9 || month == 10)
      return -1;
   return 0;
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

bool Strategy_Channel(const int lookback, double &highest_high, double &lowest_low)
  {
   if(lookback <= 0)
      return false;

   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;
   for(int shift = 2; shift < lookback + 2; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 channel breakout math on closed bars.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: D1 channel breakout math on closed bars.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);
     }

   return (highest_high > 0.0 && lowest_low > 0.0 && highest_high >= lowest_low);
  }

bool Strategy_LoadClosedState(double &close_last,
                              double &entry_high,
                              double &entry_low,
                              double &exit_high,
                              double &exit_low,
                              int &month,
                              int &day_key)
  {
   const datetime closed_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 seasonal calendar key.
   if(closed_bar_time <= 0)
      return false;

   close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 channel breakout math on closed bars.
   if(close_last <= 0.0)
      return false;

   month = Strategy_MonthFromTime(closed_bar_time);
   day_key = Strategy_DayKey(closed_bar_time);
   if(!Strategy_Channel(strategy_entry_channel, entry_high, entry_low))
      return false;
   if(!Strategy_Channel(strategy_exit_channel, exit_high, exit_low))
      return false;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double entry_high = 0.0;
   double entry_low = 0.0;
   double exit_high = 0.0;
   double exit_low = 0.0;
   int month = 0;
   int day_key = 0;
   if(!Strategy_LoadClosedState(close_last, entry_high, entry_low, exit_high, exit_low, month, day_key))
      return;

   const int regime_dir = Strategy_RegimeDirection(month);
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

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
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = (opened > 0 && now - opened >= hold_seconds);

      if(pos_type == POSITION_TYPE_BUY)
         should_close = should_close || (regime_dir != 1) || (close_last < exit_low);
      if(pos_type == POSITION_TYPE_SELL)
         should_close = should_close || (regime_dir != -1) || (close_last > exit_high);

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
   if(strategy_entry_channel <= 1 || strategy_exit_channel <= 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12581_EIA_RBOB_CRACK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double close_last = 0.0;
   double entry_high = 0.0;
   double entry_low = 0.0;
   double exit_high = 0.0;
   double exit_low = 0.0;
   int month = 0;
   int day_key = 0;
   if(!Strategy_LoadClosedState(close_last, entry_high, entry_low, exit_high, exit_low, month, day_key))
      return false;
   if(day_key <= 0 || day_key == g_last_signal_day_key)
      return false;

   const int regime_dir = Strategy_RegimeDirection(month);
   if(regime_dir == 0)
      return false;

   if(regime_dir > 0 && close_last <= entry_high)
      return false;
   if(regime_dir < 0 && close_last >= entry_low)
      return false;

   req.type = (regime_dir > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (regime_dir > 0) ? "EIA_RBOB_CRACK_LONG_BREAKOUT" : "EIA_RBOB_CRACK_SHORT_BREAKDOWN";
   g_last_signal_day_key = day_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12581\",\"ea\":\"eia-rbob-crack\"}");
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
