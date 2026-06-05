#property strict
#property version   "5.0"
#property description "QM5_10804 tv-st-long"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10804;
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
input int    strategy_st_atr_period        = 10;
input double strategy_st_multiplier        = 3.0;
input int    strategy_safety_atr_period    = 14;
input double strategy_safety_atr_mult      = 2.0;
input int    strategy_st_warmup_bars       = 200;
input bool   strategy_enable_max_bars_exit = true;
input int    strategy_max_bars_h4          = 120;
input int    strategy_max_bars_d1          = 60;

bool   g_st_ready = false;
int    g_st_trend_closed = 0;
int    g_st_trend_previous = 0;
double g_st_band_closed = 0.0;
double g_st_lower_closed = 0.0;

bool RefreshSuperTrendState()
  {
   g_st_ready = false;
   g_st_trend_closed = 0;
   g_st_trend_previous = 0;
   g_st_band_closed = 0.0;
   g_st_lower_closed = 0.0;

   if(strategy_st_atr_period <= 0 || strategy_st_multiplier <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int min_bars = strategy_st_atr_period + 5;
   const int bars_needed = MathMax(MathMax(strategy_st_warmup_bars, min_bars), 20);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 0, bars_needed, rates); // perf-allowed: SuperTrend needs OHLC; caller is framework new-bar gated.
   if(copied < min_bars)
      return false;

   bool initialized = false;
   int trend = 1;
   double final_upper = 0.0;
   double final_lower = 0.0;
   bool captured_closed = false;
   bool captured_previous = false;

   const int oldest_shift = copied - 2;
   for(int shift = oldest_shift; shift >= 1; --shift)
     {
      const double atr = QM_ATR(_Symbol, tf, strategy_st_atr_period, shift);
      if(atr <= 0.0)
         continue;

      const double hl2 = (rates[shift].high + rates[shift].low) * 0.5;
      const double basic_upper = hl2 + strategy_st_multiplier * atr;
      const double basic_lower = hl2 - strategy_st_multiplier * atr;

      if(!initialized)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         trend = (rates[shift].close >= hl2) ? 1 : -1;
         initialized = true;
        }
      else
        {
         const double prev_upper = final_upper;
         const double prev_lower = final_lower;
         const double prev_close = rates[shift + 1].close;
         final_upper = (basic_upper < prev_upper || prev_close > prev_upper) ? basic_upper : prev_upper;
         final_lower = (basic_lower > prev_lower || prev_close < prev_lower) ? basic_lower : prev_lower;

         if(trend < 0 && rates[shift].close > final_upper)
            trend = 1;
         else if(trend > 0 && rates[shift].close < final_lower)
            trend = -1;
        }

      const double active_band = (trend > 0) ? final_lower : final_upper;
      if(shift == 2)
        {
         g_st_trend_previous = trend;
         captured_previous = true;
        }
      else if(shift == 1)
        {
         g_st_trend_closed = trend;
         g_st_band_closed = active_band;
         g_st_lower_closed = final_lower;
         captured_closed = true;
        }
     }

   g_st_ready = (captured_closed && captured_previous && g_st_band_closed > 0.0);
   return g_st_ready;
  }

bool HasOwnOpenLong()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         return true;
     }

   return false;
  }

int StrategyMaxBars()
  {
   if(_Period == PERIOD_D1)
      return strategy_max_bars_d1;
   if(_Period == PERIOD_H4)
      return strategy_max_bars_h4;
   if(_Period == PERIOD_H1)
      return strategy_max_bars_h4 * 4;
   return 0;
  }

bool MaxBarsExitReached()
  {
   if(!strategy_enable_max_bars_exit)
      return false;

   const int max_bars = StrategyMaxBars();
   if(max_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, tf, open_time, false); // perf-allowed: one position age lookup for optional card time stop.
      if(bars_held >= max_bars)
         return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "TV_ST_LONG_FLIP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!RefreshSuperTrendState())
      return false;

   if(HasOwnOpenLong())
      return false;

   if(!(g_st_trend_previous < 0 && g_st_trend_closed > 0))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double safety_atr = QM_ATR(_Symbol, tf, strategy_safety_atr_period, 1);
   if(safety_atr <= 0.0)
      return false;

   const double atr_floor = ask - safety_atr * strategy_safety_atr_mult;
   double stop_price = MathMin(g_st_lower_closed, atr_floor);
   if(stop_price <= 0.0 || stop_price >= ask - point)
      stop_price = atr_floor;
   if(stop_price <= 0.0 || stop_price >= ask - point)
      return false;

   req.sl = NormalizeDouble(stop_price, _Digits);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!g_st_ready || g_st_trend_closed <= 0 || g_st_band_closed <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const double target_sl = NormalizeDouble(g_st_band_closed, _Digits);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double current_sl = PositionGetDouble(POSITION_SL);
      if(current_sl <= 0.0 || target_sl > current_sl + point * 0.5)
         QM_TM_MoveSL(ticket, target_sl, "supertrend_trail");
     }
  }

bool Strategy_ExitSignal()
  {
   if(g_st_ready && g_st_trend_previous > 0 && g_st_trend_closed < 0)
      return true;

   return MaxBarsExitReached();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10804_tv_st_long\"}");
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
