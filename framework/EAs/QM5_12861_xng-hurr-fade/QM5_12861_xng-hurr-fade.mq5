#property strict
#property version   "5.0"
#property description "QM5_12861 XNG Hurricane Failed-Spike Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12861 - XNG Hurricane Failed-Spike Fade
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - trades only XNGUSD.DWX during the Atlantic hurricane fade window
//   - shorts failed upside spike/rejection bars stretched above a slow D1 mean
//   - exits on mean reversion, channel invalidation, season end, time, or ATR
// Runtime uses MT5 OHLC and broker calendar only; no weather, EIA, API, or CSV.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12861;
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
input int    strategy_start_month          = 8;
input int    strategy_start_day            = 15;
input int    strategy_end_month            = 10;
input int    strategy_end_day              = 31;
input int    strategy_reject_lookback      = 20;
input int    strategy_exit_channel         = 10;
input int    strategy_trend_period         = 63;
input int    strategy_atr_period           = 20;
input double strategy_min_range_atr        = 1.00;
input double strategy_min_body_ratio       = 0.30;
input double strategy_reversal_tail_ratio  = 0.35;
input double strategy_min_stretch_atr      = 1.25;
input double strategy_atr_sl_mult          = 3.25;
input int    strategy_max_hold_days        = 7;
input int    strategy_max_spread_points    = 2500;

int g_last_signal_day_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DateCode(const int month, const int day)
  {
   return month * 100 + day;
  }

bool Strategy_InDateWindow(const datetime t)
  {
   if(t <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int current_code = Strategy_DateCode(dt.mon, dt.day);
   const int start_code = Strategy_DateCode(strategy_start_month, strategy_start_day);
   const int end_code = Strategy_DateCode(strategy_end_month, strategy_end_day);

   if(start_code <= end_code)
      return (current_code >= start_code && current_code <= end_code);
   return (current_code >= start_code || current_code <= end_code);
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

bool Strategy_LoadClosedState(double &bar_open,
                              double &bar_high,
                              double &bar_low,
                              double &bar_close,
                              double &reject_high,
                              double &exit_high,
                              double &atr_last,
                              double &sma_last,
                              datetime &signal_time,
                              int &signal_day_key)
  {
   const int max_channel = MathMax(strategy_reject_lookback, strategy_exit_channel);
   const int bars_needed = max_channel + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates) < bars_needed) // perf-allowed: D1 hurricane failed-spike state, new-bar gated.
      return false;

   signal_time = rates[0].time;
   signal_day_key = Strategy_DayKey(signal_time);
   bar_open = rates[0].open;
   bar_high = rates[0].high;
   bar_low = rates[0].low;
   bar_close = rates[0].close;

   reject_high = rates[1].high;
   for(int i = 2; i <= strategy_reject_lookback; ++i)
     {
      if(rates[i].high > reject_high)
         reject_high = rates[i].high;
     }

   exit_high = rates[1].high;
   for(int j = 2; j <= strategy_exit_channel; ++j)
     {
      if(rates[j].high > exit_high)
         exit_high = rates[j].high;
     }

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);

   if(signal_time <= 0 || signal_day_key <= 0)
      return false;
   if(bar_open <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return false;
   if(bar_high <= bar_low || reject_high <= 0.0 || exit_high <= 0.0)
      return false;
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double bar_open = 0.0;
   double bar_high = 0.0;
   double bar_low = 0.0;
   double bar_close = 0.0;
   double reject_high = 0.0;
   double exit_high = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   const bool have_state = Strategy_LoadClosedState(bar_open, bar_high, bar_low, bar_close,
                                                    reject_high, exit_high,
                                                    atr_last, sma_last,
                                                    signal_time, signal_day_key);

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
      bool should_close = (opened > 0 && now - opened >= hold_seconds);

      if(have_state)
        {
         if(!Strategy_InDateWindow(signal_time))
            should_close = true;
         if(pos_type == POSITION_TYPE_SELL)
           {
            if(bar_close <= sma_last || bar_close > exit_high)
               should_close = true;
           }
         else
           {
            should_close = true;
           }
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
   if(strategy_start_month < 1 || strategy_start_month > 12)
      return true;
   if(strategy_end_month < 1 || strategy_end_month > 12)
      return true;
   if(strategy_start_day < 1 || strategy_start_day > 31)
      return true;
   if(strategy_end_day < 1 || strategy_end_day > 31)
      return true;
   if(strategy_reject_lookback < 2 || strategy_exit_channel < 2)
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 0)
      return true;
   if(strategy_min_range_atr <= 0.0 || strategy_min_body_ratio <= 0.0 || strategy_min_body_ratio > 1.0)
      return true;
   if(strategy_reversal_tail_ratio <= 0.0 || strategy_reversal_tail_ratio >= 0.5)
      return true;
   if(strategy_min_stretch_atr <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12861_XNG_HURR_FADE";
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

   double bar_open = 0.0;
   double bar_high = 0.0;
   double bar_low = 0.0;
   double bar_close = 0.0;
   double reject_high = 0.0;
   double exit_high = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   if(!Strategy_LoadClosedState(bar_open, bar_high, bar_low, bar_close,
                                reject_high, exit_high, atr_last, sma_last,
                                signal_time, signal_day_key))
      return false;

   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;
   if(!Strategy_InDateWindow(signal_time))
      return false;

   const double bar_range = bar_high - bar_low;
   const double bar_body = bar_close - bar_open;
   const double body_ratio = MathAbs(bar_body) / bar_range;
   const double close_location = (bar_close - bar_low) / bar_range;
   const double upside_stretch = (bar_high - sma_last) / atr_last;

   if(bar_high < reject_high)
      return false;
   if(bar_range < strategy_min_range_atr * atr_last)
      return false;
   if(body_ratio < strategy_min_body_ratio)
      return false;
   if(upside_stretch < strategy_min_stretch_atr)
      return false;
   if(bar_close <= sma_last)
      return false;
   if(bar_body >= 0.0)
      return false;
   if(close_location > strategy_reversal_tail_ratio)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "XNG_HURRICANE_FAILED_SPIKE_FADE_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12861\",\"ea\":\"xng-hurr-fade\"}");
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
