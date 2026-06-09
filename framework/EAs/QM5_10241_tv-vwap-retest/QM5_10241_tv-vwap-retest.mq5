#property strict
#property version   "5.0"
#property description "QM5_10241 TradingView VWAP retest continuation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10241;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_session_start_hour       = 8;
input int    strategy_session_end_hour         = 21;
input bool   strategy_session_close_flat       = true;
input bool   strategy_allow_shorts             = true;
input int    strategy_atr_period               = 14;
input double strategy_atr_sl_mult              = 1.0;
input double strategy_atr_tp_mult              = 1.5;
input int    strategy_retest_max_bars          = 6;
input int    strategy_max_trades_per_day       = 2;
input int    strategy_volume_lookback          = 20;
input double strategy_volume_spike_mult        = 1.2;
input double strategy_rejection_wick_frac      = 0.30;
input double strategy_retest_tolerance_atr     = 0.15;
input double strategy_min_vwap_distance_atr    = 0.0;
input int    strategy_max_spread_points        = 80;

double g_session_pv_sum = 0.0;
double g_session_vol_sum = 0.0;
double g_session_vwap = 0.0;
double g_prev_close = 0.0;
double g_prev_vwap = 0.0;
int    g_session_day_key = 0;
int    g_setup_dir = 0;
int    g_setup_age = 0;
int    g_trades_today = 0;
double g_volume_window[128];
int    g_volume_count = 0;
int    g_volume_index = 0;
double g_volume_sum = 0.0;

int BarDayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

bool HourInSession(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

bool TradingSessionOpen(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return HourInSession(dt.hour, strategy_session_start_hour, strategy_session_end_hour);
  }

bool SessionCloseReached(const datetime t)
  {
   if(!strategy_session_close_flat || strategy_session_start_hour == strategy_session_end_hour)
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(strategy_session_start_hour < strategy_session_end_hour)
      return (dt.hour >= strategy_session_end_hour);
   return (dt.hour >= strategy_session_end_hour && dt.hour < strategy_session_start_hour);
  }

void ResetSessionState(const int day_key)
  {
   g_session_day_key = day_key;
   g_session_pv_sum = 0.0;
   g_session_vol_sum = 0.0;
   g_session_vwap = 0.0;
   g_prev_close = 0.0;
   g_prev_vwap = 0.0;
   g_setup_dir = 0;
   g_setup_age = 0;
   g_trades_today = 0;
   g_volume_count = 0;
   g_volume_index = 0;
   g_volume_sum = 0.0;
   ArrayInitialize(g_volume_window, 0.0);
  }

void AddVolumeSample(const double volume)
  {
   int lookback = strategy_volume_lookback;
   if(lookback < 1)
      lookback = 1;
   if(lookback > 128)
      lookback = 128;

   if(g_volume_count < lookback)
     {
      g_volume_window[g_volume_index] = volume;
      g_volume_sum += volume;
      g_volume_count++;
     }
   else
     {
      g_volume_sum -= g_volume_window[g_volume_index];
      g_volume_window[g_volume_index] = volume;
      g_volume_sum += volume;
     }

   g_volume_index++;
   if(g_volume_index >= lookback)
      g_volume_index = 0;
  }

bool HasOurPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool BullishConfirmation(const MqlRates &bar, const double vwap)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0 || bar.close <= bar.open || bar.close <= vwap)
      return false;

   const double lower_wick = MathMin(bar.open, bar.close) - bar.low;
   return (lower_wick >= range * strategy_rejection_wick_frac);
  }

bool BearishConfirmation(const MqlRates &bar, const double vwap)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0 || bar.close >= bar.open || bar.close >= vwap)
      return false;

   const double upper_wick = bar.high - MathMax(bar.open, bar.close);
   return (upper_wick >= range * strategy_rejection_wick_frac);
  }

bool ReadClosedBar(MqlRates &bar)
  {
   MqlRates rates[1];
   ArraySetAsSeries(rates, true);
   // QM_IsNewBar() gate is applied by framework OnTick before Strategy_EntrySignal.
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, rates) != 1)
      return false;
   bar = rates[0];
   return (bar.time > 0 && bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0);
  }

void ApplyNewSetupIfBreakout(const MqlRates &bar, const double atr)
  {
   if(g_prev_vwap <= 0.0 || g_prev_close <= 0.0 || atr <= 0.0)
      return;

   const double distance = MathAbs(bar.close - g_session_vwap);
   const bool distance_ok = (strategy_min_vwap_distance_atr <= 0.0 ||
                             distance >= atr * strategy_min_vwap_distance_atr);
   if(!distance_ok)
      return;

   if(g_prev_close <= g_prev_vwap && bar.close > g_session_vwap)
     {
      g_setup_dir = 1;
      g_setup_age = 0;
     }
   else if(strategy_allow_shorts && g_prev_close >= g_prev_vwap && bar.close < g_session_vwap)
     {
      g_setup_dir = -1;
      g_setup_age = 0;
     }
  }

bool Strategy_NoTradeFilter()
  {
   const bool has_position = HasOurPosition();
   if(!TradingSessionOpen(TimeCurrent()) && !has_position)
      return true;

   if(strategy_max_spread_points > 0 && !has_position)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
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

   if(HasOurPosition() || g_trades_today >= strategy_max_trades_per_day)
      return false;

   MqlRates bar;
   if(!ReadClosedBar(bar) || !TradingSessionOpen(bar.time))
      return false;

   const int day_key = BarDayKey(bar.time);
   if(day_key != g_session_day_key)
      ResetSessionState(day_key);

   const double volume = (double)bar.tick_volume;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(volume <= 0.0 || atr <= 0.0)
      return false;

   const double prior_volume_avg = (g_volume_count > 0) ? (g_volume_sum / g_volume_count) : volume;
   const bool volume_spike = (strategy_volume_spike_mult <= 0.0 ||
                              volume >= prior_volume_avg * strategy_volume_spike_mult);

   const double typical = (bar.high + bar.low + bar.close) / 3.0;
   g_session_pv_sum += typical * volume;
   g_session_vol_sum += volume;
   if(g_session_vol_sum <= 0.0)
      return false;
   g_session_vwap = g_session_pv_sum / g_session_vol_sum;

   bool fire = false;
   QM_OrderType side = QM_BUY;
   string reason = "";
   const double tolerance = atr * strategy_retest_tolerance_atr;

   if(g_setup_dir != 0)
     {
      g_setup_age++;
      if(g_setup_age <= strategy_retest_max_bars && volume_spike)
        {
         if(g_setup_dir > 0 && bar.low <= g_session_vwap + tolerance &&
            BullishConfirmation(bar, g_session_vwap))
           {
            fire = true;
            side = QM_BUY;
            reason = "VWAP_RETEST_LONG";
           }
         else if(g_setup_dir < 0 && strategy_allow_shorts &&
                 bar.high >= g_session_vwap - tolerance &&
                 BearishConfirmation(bar, g_session_vwap))
           {
            fire = true;
            side = QM_SELL;
            reason = "VWAP_RETEST_SHORT";
           }
        }

      if(fire || g_setup_age > strategy_retest_max_bars)
        {
         g_setup_dir = 0;
         g_setup_age = 0;
        }
     }

   if(!fire)
      ApplyNewSetupIfBreakout(bar, atr);

   g_prev_close = bar.close;
   g_prev_vwap = g_session_vwap;
   AddVolumeSample(volume);

   if(!fire)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_atr_tp_mult);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   g_trades_today++;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   return (HasOurPosition() && SessionCloseReached(TimeCurrent()));
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10241_tv-vwap-retest\"}");
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
