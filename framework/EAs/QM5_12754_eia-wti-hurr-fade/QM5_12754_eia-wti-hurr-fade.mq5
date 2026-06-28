#property strict
#property version   "5.0"
#property description "QM5_12754 EIA WTI Hurricane-Season Failed-Spike Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12754 - EIA WTI Hurricane-Season Failed-Spike Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - trades only XTIUSD.DWX during the peak hurricane-risk window
//   - shorts failed upside spike/rejection bars stretched above a slow D1 mean
//   - exits at mean reversion, window end, a short max-hold guard, or ATR stop
// Runtime uses MT5 OHLC only; no EIA, hurricane, refinery, weather, API, or CSV.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12754;
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
input int    strategy_atr_period             = 20;
input int    strategy_mean_period            = 50;
input double strategy_min_range_atr          = 0.90;
input double strategy_min_body_ratio         = 0.35;
input double strategy_reversal_tail_ratio    = 0.35;
input double strategy_min_stretch_atr        = 1.10;
input double strategy_atr_sl_mult            = 2.75;
input int    strategy_max_hold_days          = 5;
input int    strategy_start_month            = 8;
input int    strategy_end_month              = 10;
input int    strategy_max_spread_points      = 1000;

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

bool Strategy_MonthInRange(const int month, const int start_month, const int end_month)
  {
   if(month < 1 || month > 12 || start_month < 1 || start_month > 12 || end_month < 1 || end_month > 12)
      return false;
   if(start_month <= end_month)
      return (month >= start_month && month <= end_month);
   return (month >= start_month || month <= end_month);
  }

bool Strategy_IsHurricaneFadeMonth(const int month)
  {
   return Strategy_MonthInRange(month, strategy_start_month, strategy_end_month);
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
                              double &atr_last,
                              double &sma_last,
                              int &signal_day_key,
                              int &signal_month)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, rates) < 1) // perf-allowed: prior D1 hurricane fade state, new-bar gated.
      return false;

   bar_open = rates[0].open;
   bar_high = rates[0].high;
   bar_low = rates[0].low;
   bar_close = rates[0].close;
   signal_day_key = Strategy_DayKey(rates[0].time);
   signal_month = Strategy_MonthFromTime(rates[0].time);

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_mean_period, 1, PRICE_CLOSE);

   if(bar_open <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return false;
   if(bar_high <= bar_low || atr_last <= 0.0 || sma_last <= 0.0)
      return false;
   if(signal_day_key <= 0 || signal_month < 1 || signal_month > 12)
      return false;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double bar_open = 0.0;
   double bar_high = 0.0;
   double bar_low = 0.0;
   double bar_close = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   int signal_day_key = 0;
   int signal_month = 0;
   const bool have_state = Strategy_LoadClosedState(bar_open, bar_high, bar_low, bar_close,
                                                    atr_last, sma_last, signal_day_key, signal_month);
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
         if(!Strategy_IsHurricaneFadeMonth(signal_month))
            should_close = true;
         if(pos_type == POSITION_TYPE_SELL && bar_close <= sma_last)
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
   if(strategy_atr_period <= 0 || strategy_mean_period <= 1)
      return true;
   if(strategy_min_range_atr <= 0.0 || strategy_min_body_ratio <= 0.0 || strategy_min_body_ratio > 1.0)
      return true;
   if(strategy_reversal_tail_ratio <= 0.0 || strategy_reversal_tail_ratio >= 0.5)
      return true;
   if(strategy_min_stretch_atr <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   if(strategy_start_month < 1 || strategy_start_month > 12 || strategy_end_month < 1 || strategy_end_month > 12)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12754_EIA_WTI_HURR_FADE";
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
   double atr_last = 0.0;
   double sma_last = 0.0;
   int signal_day_key = 0;
   int signal_month = 0;
   if(!Strategy_LoadClosedState(bar_open, bar_high, bar_low, bar_close,
                                atr_last, sma_last, signal_day_key, signal_month))
      return false;
   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;
   if(!Strategy_IsHurricaneFadeMonth(signal_month))
      return false;

   const double bar_range = bar_high - bar_low;
   const double bar_body = bar_close - bar_open;
   const double body_ratio = MathAbs(bar_body) / bar_range;
   const double close_location = (bar_close - bar_low) / bar_range;
   const double upside_stretch = (bar_high - sma_last) / atr_last;

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

   req.reason = "EIA_WTI_HURRICANE_FADE_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12754\",\"ea\":\"eia-wti-hurr-fade\"}");
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
