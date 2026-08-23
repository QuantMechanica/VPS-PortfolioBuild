#property strict
#property version   "5.0"
#property description "QM5_9963 Bandy linear-regression slope sign-flip trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9963;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_D1;
input int             strategy_slope_window       = 20;
input int             strategy_regime_sma_period  = 200;
input double          strategy_min_slope_atr_mult = 0.05;
input int             strategy_atr_period         = 14;
input double          strategy_stop_atr_mult      = 2.5;
input int             strategy_max_hold_bars      = 45;

datetime g_slope_cache_bar   = 0;
bool     g_slope_cache_valid = false;
double   g_slope_cache_curr  = 0.0;
double   g_slope_cache_prev  = 0.0;

ulong    g_exit_cache_ticket = 0;
datetime g_exit_cache_bar    = 0;
bool     g_exit_cache_value  = false;

bool Strategy_InputsValid()
  {
   return strategy_slope_window >= 2 &&
          strategy_regime_sma_period >= 2 &&
          strategy_min_slope_atr_mult >= 0.0 &&
          strategy_atr_period >= 1 &&
          strategy_stop_atr_mult > 0.0 &&
          strategy_max_hold_bars >= 1;
  }

bool Strategy_FindPosition(ulong &ticket,
                           ENUM_POSITION_TYPE &position_type,
                           datetime &opened_at)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   opened_at = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_OLSSlope(const int base_shift, double &slope)
  {
   slope = 0.0;
   if(base_shift < 1 || strategy_slope_window < 2)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   for(int i = 0; i < strategy_slope_window; ++i)
     {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol, strategy_timeframe, base_shift + i, bar) ||
         bar.close <= 0.0)
         return false;
      // Most recent observation is x=0; older observations are negative.
      const double x = -(double)i;
      sum_x += x;
      sum_y += bar.close;
      sum_xx += x * x;
      sum_xy += x * bar.close;
     }

   const double n = (double)strategy_slope_window;
   const double denominator = n * sum_xx - sum_x * sum_x;
   if(denominator <= 0.0)
      return false;
   slope = (n * sum_xy - sum_x * sum_y) / denominator;
   return MathIsValidNumber(slope);
  }

bool Strategy_CurrentSlopes(double &slope_curr, double &slope_prev)
  {
   slope_curr = 0.0;
   slope_prev = 0.0;
   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 1, signal_bar))
      return false;

   if(g_slope_cache_bar == signal_bar.time)
     {
      slope_curr = g_slope_cache_curr;
      slope_prev = g_slope_cache_prev;
      return g_slope_cache_valid;
     }

   double calculated_curr = 0.0;
   double calculated_prev = 0.0;
   g_slope_cache_valid =
      Strategy_OLSSlope(1, calculated_curr) &&
      Strategy_OLSSlope(2, calculated_prev);
   if(!g_slope_cache_valid)
     {
      // Do not cache a transient history-read failure for the entire D1 bar.
      g_slope_cache_bar = 0;
      return false;
     }
   g_slope_cache_bar = signal_bar.time;
   g_slope_cache_curr = calculated_curr;
   g_slope_cache_prev = calculated_prev;
   slope_curr = g_slope_cache_curr;
   slope_prev = g_slope_cache_prev;
   return g_slope_cache_valid;
  }

int Strategy_ClosedBarsSinceEntry(const datetime opened_at, const int limit)
  {
   if(opened_at <= 0 || limit <= 0)
      return 0;
   const int bar_seconds = PeriodSeconds(strategy_timeframe);
   if(bar_seconds <= 0)
      return 0;

   int count = 0;
   for(int shift = 1; shift <= limit; ++shift)
     {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol, strategy_timeframe, shift, bar))
         break;
      if(bar.time + bar_seconds <= opened_at)
         break;
      count++;
     }
   return count;
  }

bool Strategy_NoTradeFilter()
  {
   return ((ENUM_TIMEFRAMES)_Period != strategy_timeframe);
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

   if(!Strategy_InputsValid())
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   if(Strategy_FindPosition(ticket, position_type, opened_at))
      return false;

   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 1, signal_bar))
      return false;

   double slope_curr = 0.0;
   double slope_prev = 0.0;
   if(!Strategy_CurrentSlopes(slope_curr, slope_prev))
      return false;

   const bool flip_up = slope_prev <= 0.0 && slope_curr > 0.0;
   const bool flip_down = slope_prev >= 0.0 && slope_curr < 0.0;
   if(!flip_up && !flip_down)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double regime = QM_SMA(
      _Symbol, strategy_timeframe, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(atr <= 0.0 || regime <= 0.0 ||
      MathAbs(slope_curr) < strategy_min_slope_atr_mult * atr)
      return false;

   QM_OrderType side = QM_BUY;
   if(flip_up && signal_bar.close > regime)
      side = QM_BUY;
   else if(flip_down && signal_bar.close < regime)
      side = QM_SELL;
   else
      return false;

   const double entry = QM_OrderTypeIsBuy(side)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double stop = QM_StopATRFromValue(
      _Symbol, side, entry, atr, strategy_stop_atr_mult);
   if(stop <= 0.0)
      return false;

   req.type = side;
   req.sl = stop;
   req.reason = QM_OrderTypeIsBuy(side)
                ? "LR_SLOPE_FLIP_UP"
                : "LR_SLOPE_FLIP_DOWN";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // The card specifies only a server SL and closed-bar strategy exits.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime opened_at;
   if(!Strategy_FindPosition(ticket, position_type, opened_at))
     {
      g_exit_cache_ticket = 0;
      g_exit_cache_bar = 0;
      g_exit_cache_value = false;
      return false;
     }

   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 1, signal_bar))
      return false;
   if(g_exit_cache_ticket == ticket && g_exit_cache_bar == signal_bar.time)
      return g_exit_cache_value;

   double slope_curr = 0.0;
   double slope_prev = 0.0;
   const bool slopes_ok = Strategy_CurrentSlopes(slope_curr, slope_prev);
   const bool flip_up = slopes_ok && slope_prev <= 0.0 && slope_curr > 0.0;
   const bool flip_down = slopes_ok && slope_prev >= 0.0 && slope_curr < 0.0;
   const bool opposite_flip =
      (position_type == POSITION_TYPE_BUY && flip_down) ||
      (position_type == POSITION_TYPE_SELL && flip_up);

   g_exit_cache_ticket = ticket;
   g_exit_cache_bar = signal_bar.time;
   g_exit_cache_value = opposite_flip ||
      Strategy_ClosedBarsSinceEntry(opened_at, strategy_max_hold_bars) >=
         strategy_max_hold_bars;
   return g_exit_cache_value;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;
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
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
      return;

   QM_EquityStreamOnNewBar();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(
         _Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
