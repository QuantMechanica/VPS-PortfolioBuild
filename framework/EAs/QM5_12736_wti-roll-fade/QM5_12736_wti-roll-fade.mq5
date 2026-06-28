#property strict
#property version   "5.0"
#property description "QM5_12736 WTI ETF Roll-Pressure Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12736 - WTI ETF Roll-Pressure Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - trades only during the early-month crude-oil ETF roll-pressure window
//   - shorts after D1 downside confirmation below a slow mean
//   - exits at roll-window end, trend recovery, month change, or fixed max hold
// Runtime uses MT5 OHLC/broker calendar only; no ETF feed, futures curve, CFTC
// feed, COT data, API, CSV, or external roll schedule.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12736;
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
input int    strategy_roll_start_trading_day = 5;
input int    strategy_roll_end_trading_day   = 9;
input double strategy_min_down_return_pct    = 0.10;
input int    strategy_trend_period           = 20;
input int    strategy_atr_period             = 20;
input double strategy_atr_sl_mult            = 2.50;
input int    strategy_max_hold_days          = 5;
input int    strategy_max_spread_points      = 1000;

int g_last_entry_month_key = 0;

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

int Strategy_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_TradingDayOfMonth(const datetime t)
  {
   if(t <= 0)
      return 0;

   MqlDateTime target;
   TimeToStruct(t, target);
   int count = 0;

   for(int shift = 0; shift < 80; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 trading-day-of-month calendar gate, new-bar gated.
      if(bar_time <= 0)
         break;

      MqlDateTime bar_dt;
      TimeToStruct(bar_time, bar_dt);
      if(bar_dt.year < target.year || (bar_dt.year == target.year && bar_dt.mon < target.mon))
         break;
      if(bar_dt.year == target.year && bar_dt.mon == target.mon && bar_dt.day <= target.day)
         ++count;
     }

   return count;
  }

bool Strategy_InRollWindow(const datetime current_bar_time)
  {
   const int td = Strategy_TradingDayOfMonth(current_bar_time);
   return (td >= strategy_roll_start_trading_day && td <= strategy_roll_end_trading_day);
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

bool Strategy_LoadClosedState(double &close_last,
                              double &close_prev,
                              double &return_pct,
                              double &sma_last,
                              datetime &signal_time,
                              int &signal_day_key)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 2, rates) < 2) // perf-allowed: prior D1 roll-pressure confirmation state, new-bar gated.
      return false;

   signal_time = rates[0].time;
   signal_day_key = Strategy_DayKey(signal_time);
   close_last = rates[0].close;
   close_prev = rates[1].close;
   if(close_last <= 0.0 || close_prev <= 0.0 || signal_day_key <= 0)
      return false;

   return_pct = ((close_last / close_prev) - 1.0) * 100.0;
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(sma_last <= 0.0)
      return false;

   return MathIsValidNumber(return_pct);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 roll-window exit gate.
   const int current_td = Strategy_TradingDayOfMonth(current_bar_time);
   const int current_month_key = Strategy_MonthKey(current_bar_time);
   const bool in_roll_window = Strategy_InRollWindow(current_bar_time);

   double close_last = 0.0;
   double close_prev = 0.0;
   double return_pct = 0.0;
   double sma_last = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   const bool have_state = Strategy_LoadClosedState(close_last, close_prev, return_pct,
                                                    sma_last, signal_time, signal_day_key);

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
      const int opened_month_key = Strategy_MonthKey(opened);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(!in_roll_window || current_td > strategy_roll_end_trading_day)
         should_close = true;
      if(opened_month_key > 0 && current_month_key > 0 && opened_month_key != current_month_key)
         should_close = true;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(pos_type != POSITION_TYPE_SELL)
         should_close = true;
      if(have_state && pos_type == POSITION_TYPE_SELL && close_last > sma_last)
         should_close = true;

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
   if(strategy_roll_start_trading_day < 1 || strategy_roll_end_trading_day < strategy_roll_start_trading_day)
      return true;
   if(strategy_roll_end_trading_day > 23)
      return true;
   if(strategy_min_down_return_pct <= 0.0 || strategy_trend_period <= 1)
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
   req.reason = "QM5_12736_WTI_ROLL_FADE";
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

   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 roll-window entry calendar gate.
   if(current_bar_time <= 0)
      return false;
   if(!Strategy_InRollWindow(current_bar_time))
      return false;

   const int current_month_key = Strategy_MonthKey(current_bar_time);
   if(current_month_key <= 0 || current_month_key == g_last_entry_month_key)
      return false;

   double close_last = 0.0;
   double close_prev = 0.0;
   double return_pct = 0.0;
   double sma_last = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   if(!Strategy_LoadClosedState(close_last, close_prev, return_pct, sma_last,
                                signal_time, signal_day_key))
      return false;
   if(return_pct > -strategy_min_down_return_pct)
      return false;
   if(close_last >= sma_last)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_SELL);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_SELL, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "WTI_ETF_ROLL_PRESSURE_SHORT";
   g_last_entry_month_key = current_month_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12736\",\"ea\":\"wti-roll-fade\"}");
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
