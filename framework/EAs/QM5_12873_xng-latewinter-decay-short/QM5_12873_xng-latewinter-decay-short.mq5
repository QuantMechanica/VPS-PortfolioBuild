#property strict
#property version   "5.0"
#property description "QM5_12873 XNG Late-Winter Decay Short"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12873 - XNG Late-Winter Decay Short
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - trades only during the late-winter shoulder transition, Feb 15-Mar 31
//   - enters at most once per broker week
//   - short-only after price has decayed from the winter high and fast SMA slope
//     confirms downside continuation
// Runtime uses MT5 OHLC/broker calendar only; no EIA, storage, weather, API,
// CSV, forecast, power-load, or futures-curve feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12873;
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
input int    strategy_start_month          = 2;
input int    strategy_start_day            = 15;
input int    strategy_end_month            = 3;
input int    strategy_end_day              = 31;
input int    strategy_fast_period          = 21;
input int    strategy_slope_lookback_days  = 5;
input int    strategy_winter_high_lookback = 45;
input double strategy_min_drawdown_atr     = 1.20;
input double strategy_min_decay_slope_atr  = 0.15;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 7;
input int    strategy_max_spread_points    = 2500;

int g_last_entry_week_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DateKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon * 100 + dt.day;
  }

int Strategy_WeekKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + (dt.day_of_year / 7);
  }

bool Strategy_ValidSeasonParams()
  {
   if(strategy_start_month < 1 || strategy_start_month > 12)
      return false;
   if(strategy_end_month < 1 || strategy_end_month > 12)
      return false;
   if(strategy_start_day < 1 || strategy_start_day > 31)
      return false;
   if(strategy_end_day < 1 || strategy_end_day > 31)
      return false;

   const int start_key = strategy_start_month * 100 + strategy_start_day;
   const int end_key = strategy_end_month * 100 + strategy_end_day;
   return (start_key <= end_key);
  }

bool Strategy_InLateWinterWindow(const datetime t)
  {
   const int date_key = Strategy_DateKey(t);
   if(date_key <= 0 || !Strategy_ValidSeasonParams())
      return false;

   const int start_key = strategy_start_month * 100 + strategy_start_day;
   const int end_key = strategy_end_month * 100 + strategy_end_day;
   return (date_key >= start_key && date_key <= end_key);
  }

bool Strategy_IsFirstTradingBarOfWeek()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: weekly calendar gate.
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: weekly calendar gate.
   if(current_bar <= 0 || closed_bar <= 0)
      return false;
   return (Strategy_WeekKey(current_bar) != Strategy_WeekKey(closed_bar));
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

bool Strategy_LoadDecayState(double &close_last,
                             double &fast_sma,
                             double &fast_slope_atr,
                             double &winter_high,
                             double &drawdown_atr,
                             double &atr_last,
                             datetime &current_bar_time,
                             datetime &closed_bar_time)
  {
   current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate.
   closed_bar_time = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: prior closed D1 signal bar.
   close_last = iClose(_Symbol, PERIOD_D1, 1);      // perf-allowed: prior closed D1 signal bar.
   if(current_bar_time <= 0 || closed_bar_time <= 0 || close_last <= 0.0)
      return false;

   const int fast_period = MathMax(2, strategy_fast_period);
   const int slope_lookback = MathMax(1, strategy_slope_lookback_days);
   const int slope_shift = 1 + slope_lookback;
   const int high_lookback = MathMax(5, strategy_winter_high_lookback);

   fast_sma = QM_SMA(_Symbol, PERIOD_D1, fast_period, 1, PRICE_CLOSE);
   const double fast_sma_past = QM_SMA(_Symbol, PERIOD_D1, fast_period, slope_shift, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(fast_sma <= 0.0 || fast_sma_past <= 0.0 || atr_last <= 0.0)
      return false;

   winter_high = 0.0;
   for(int shift = 1; shift <= high_lookback; ++shift)
     {
      const double bar_high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 winter-high lookback for structural decay gate.
      if(bar_high <= 0.0)
         return false;
      if(bar_high > winter_high)
         winter_high = bar_high;
     }
   if(winter_high <= 0.0 || winter_high <= close_last)
      return false;

   fast_slope_atr = (fast_sma - fast_sma_past) / atr_last;
   drawdown_atr = (winter_high - close_last) / atr_last;
   return (MathIsValidNumber(fast_slope_atr) && MathIsValidNumber(drawdown_atr));
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double fast_sma = 0.0;
   double fast_slope_atr = 0.0;
   double winter_high = 0.0;
   double drawdown_atr = 0.0;
   double atr_last = 0.0;
   datetime current_bar_time = 0;
   datetime closed_bar_time = 0;
   if(!Strategy_LoadDecayState(close_last,
                               fast_sma,
                               fast_slope_atr,
                               winter_high,
                               drawdown_atr,
                               atr_last,
                               current_bar_time,
                               closed_bar_time))
      return;

   const bool in_window = Strategy_InLateWinterWindow(current_bar_time);
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

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = false;

      if(pos_type != POSITION_TYPE_SELL)
         should_close = true;
      if(!in_window)
         should_close = true;
      if(close_last > fast_sma)
         should_close = true;
      if(fast_slope_atr >= 0.0)
         should_close = true;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

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
   if(!Strategy_ValidSeasonParams())
      return true;
   if(strategy_fast_period <= 1)
      return true;
   if(strategy_slope_lookback_days <= 0 || strategy_winter_high_lookback <= 1)
      return true;
   if(strategy_min_drawdown_atr <= 0.0 || strategy_min_decay_slope_atr <= 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12873_XNG_LATEWINTER_DECAY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(!Strategy_IsFirstTradingBarOfWeek())
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double close_last = 0.0;
   double fast_sma = 0.0;
   double fast_slope_atr = 0.0;
   double winter_high = 0.0;
   double drawdown_atr = 0.0;
   double atr_last = 0.0;
   datetime current_bar_time = 0;
   datetime closed_bar_time = 0;
   if(!Strategy_LoadDecayState(close_last,
                               fast_sma,
                               fast_slope_atr,
                               winter_high,
                               drawdown_atr,
                               atr_last,
                               current_bar_time,
                               closed_bar_time))
      return false;

   const int current_week_key = Strategy_WeekKey(current_bar_time);
   if(current_week_key <= 0 || current_week_key == g_last_entry_week_key)
      return false;
   if(!Strategy_InLateWinterWindow(current_bar_time) || !Strategy_InLateWinterWindow(closed_bar_time))
      return false;
   if(close_last >= fast_sma)
      return false;
   if(fast_slope_atr > -strategy_min_decay_slope_atr)
      return false;
   if(drawdown_atr < strategy_min_drawdown_atr)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "XNG_LATEWINTER_DECAY_SHORT";
   g_last_entry_week_key = current_week_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12873\",\"ea\":\"xng-latewinter-decay-short\"}");
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
