#property strict
#property version   "5.0"
#property description "QM5_12812 XNG Monthly Opening Range Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12812 - XNG Monthly Opening Range Breakout
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - first N completed D1 bars of each month define the opening range
//   - one confirmed breakout package per month, symmetric long/short
//   - exits on failed breakout, SMA failure, new-month boundary, or max hold
// Runtime uses MT5 OHLC/broker calendar only; no storage/weather/API/CSV/feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12812;
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
input int    strategy_opening_days        = 5;
input int    strategy_atr_period          = 20;
input int    strategy_trend_period        = 80;
input double strategy_min_open_range_atr  = 0.60;
input double strategy_max_open_range_atr  = 5.00;
input double strategy_entry_buffer_atr    = 0.10;
input double strategy_min_close_location  = 0.56;
input double strategy_atr_sl_mult         = 3.25;
input double strategy_atr_tp_mult         = 5.00;
input int    strategy_max_hold_days       = 12;
input int    strategy_max_spread_points   = 1500;

int g_last_entry_month_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_SameMonth(const datetime t, const int year, const int month)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year == year && dt.mon == month);
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

bool Strategy_LoadMonthState(double &close_last,
                             double &opening_high,
                             double &opening_low,
                             double &atr_last,
                             double &sma_last,
                             double &open_range,
                             double &close_location,
                             datetime &signal_time,
                             int &signal_month_key,
                             int &month_bar_count)
  {
   close_last = 0.0;
   opening_high = 0.0;
   opening_low = 0.0;
   atr_last = 0.0;
   sma_last = 0.0;
   open_range = 0.0;
   close_location = 0.0;
   signal_time = 0;
   signal_month_key = 0;
   month_bar_count = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 70, rates); // perf-allowed: D1 month-opening range is evaluated only after QM_IsNewBar.
   if(copied < strategy_opening_days + 1)
      return false;

   signal_time = rates[0].time;
   MqlDateTime sig_dt;
   TimeToStruct(signal_time, sig_dt);
   signal_month_key = sig_dt.year * 100 + sig_dt.mon;

   for(int i = 0; i < copied; ++i)
     {
      if(!Strategy_SameMonth(rates[i].time, sig_dt.year, sig_dt.mon))
         break;
      ++month_bar_count;
     }

   if(month_bar_count <= strategy_opening_days)
      return false;

   int used = 0;
   for(int idx = month_bar_count - 1; idx >= 0 && used < strategy_opening_days; --idx)
     {
      if(used == 0)
        {
         opening_high = rates[idx].high;
         opening_low = rates[idx].low;
        }
      else
        {
         if(rates[idx].high > opening_high)
            opening_high = rates[idx].high;
         if(rates[idx].low < opening_low)
            opening_low = rates[idx].low;
        }
      ++used;
     }

   if(used != strategy_opening_days || opening_high <= opening_low)
      return false;

   close_last = rates[0].close;
   const double high_last = rates[0].high;
   const double low_last = rates[0].low;
   const double range_last = high_last - low_last;
   open_range = opening_high - opening_low;
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(close_last <= 0.0 || high_last <= low_last || open_range <= 0.0)
      return false;
   if(atr_last <= 0.0 || sma_last <= 0.0 || range_last <= 0.0)
      return false;

   close_location = (close_last - low_last) / range_last;
   return MathIsValidNumber(close_location);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double opening_high = 0.0;
   double opening_low = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double open_range = 0.0;
   double close_location = 0.0;
   datetime signal_time = 0;
   int signal_month_key = 0;
   int month_bar_count = 0;
   const bool have_state = Strategy_LoadMonthState(close_last,
                                                   opening_high,
                                                   opening_low,
                                                   atr_last,
                                                   sma_last,
                                                   open_range,
                                                   close_location,
                                                   signal_time,
                                                   signal_month_key,
                                                   month_bar_count);
   if(signal_month_key == 0)
      signal_month_key = Strategy_MonthKey(iTime(_Symbol, PERIOD_D1, 1)); // perf-allowed: D1 month boundary check is evaluated only after QM_IsNewBar.

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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      const int open_month_key = Strategy_MonthKey(opened);
      if(signal_month_key > 0 && open_month_key > 0 && signal_month_key != open_month_key)
         should_close = true;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(have_state && pos_type == POSITION_TYPE_BUY)
        {
         if(close_last < opening_high || close_last < sma_last)
            should_close = true;
        }
      else if(have_state && pos_type == POSITION_TYPE_SELL)
        {
         if(close_last > opening_low || close_last > sma_last)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_opening_days < 2 || strategy_opening_days > 10)
      return true;
   if(strategy_atr_period <= 0 || strategy_trend_period <= 1)
      return true;
   if(strategy_min_open_range_atr <= 0.0 || strategy_max_open_range_atr <= strategy_min_open_range_atr)
      return true;
   if(strategy_entry_buffer_atr < 0.0)
      return true;
   if(strategy_min_close_location <= 0.5 || strategy_min_close_location > 1.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
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
   req.reason = "QM5_12812_XNG_MONTH_ORB";
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
   double opening_high = 0.0;
   double opening_low = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double open_range = 0.0;
   double close_location = 0.0;
   datetime signal_time = 0;
   int signal_month_key = 0;
   int month_bar_count = 0;
   if(!Strategy_LoadMonthState(close_last,
                               opening_high,
                               opening_low,
                               atr_last,
                               sma_last,
                               open_range,
                               close_location,
                               signal_time,
                               signal_month_key,
                               month_bar_count))
      return false;

   if(signal_month_key <= 0 || signal_month_key == g_last_entry_month_key)
      return false;
   if(open_range < strategy_min_open_range_atr * atr_last)
      return false;
   if(open_range > strategy_max_open_range_atr * atr_last)
      return false;

   const double buffer = strategy_entry_buffer_atr * atr_last;
   int direction = 0;
   if(close_last > opening_high + buffer &&
      close_last > sma_last &&
      close_location >= strategy_min_close_location)
      direction = 1;
   else if(close_last < opening_low - buffer &&
           close_last < sma_last &&
           close_location <= (1.0 - strategy_min_close_location))
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_tp_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (direction > 0) ? "XNG_MONTH_OPEN_RANGE_BREAKOUT_LONG" : "XNG_MONTH_OPEN_RANGE_BREAKOUT_SHORT";
   g_last_entry_month_key = signal_month_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12812\",\"ea\":\"xng-month-orb\"}");
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
