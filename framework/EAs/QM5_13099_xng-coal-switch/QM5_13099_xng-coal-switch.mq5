#property strict
#property version   "5.0"
#property description "QM5_13099 XNG coal-switching demand-floor reclaim"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13099 - XNG Coal-Switching Demand-Floor Reclaim
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - spring / early-autumn price-sensitive fuel-switching windows
//   - bottom-quartile 252-D1 closing-price rank
//   - bullish SMA reclaim confirms the demand floor before entry
//   - ATR stop/target, rank/SMA/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13099;
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
input int    strategy_spring_start_month   = 4;
input int    strategy_spring_start_day     = 1;
input int    strategy_spring_end_month     = 5;
input int    strategy_spring_end_day       = 31;
input int    strategy_autumn_start_month   = 9;
input int    strategy_autumn_start_day     = 1;
input int    strategy_autumn_end_month     = 10;
input int    strategy_autumn_end_day       = 15;
input int    strategy_price_rank_lookback  = 252;
input double strategy_entry_price_percentile = 0.25;
input double strategy_exit_price_percentile  = 0.55;
input int    strategy_reclaim_sma_period   = 10;
input int    strategy_atr_period           = 20;
input double strategy_min_range_atr        = 0.55;
input double strategy_min_close_location   = 0.65;
input double strategy_exit_sma_buffer_atr  = 0.30;
input double strategy_atr_sl_mult          = 2.80;
input double strategy_atr_tp_mult          = 3.80;
input int    strategy_max_hold_days        = 25;
input int    strategy_max_spread_points    = 2500;

int g_last_entry_season_key = 0;
int g_candidate_season_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_ValidMonthDay(const int month, const int day)
  {
   return (month >= 1 && month <= 12 && day >= 1 && day <= 31);
  }

bool Strategy_DateWithin(const int month_day,
                         const int start_month,
                         const int start_day,
                         const int end_month,
                         const int end_day)
  {
   const int start_md = start_month * 100 + start_day;
   const int end_md = end_month * 100 + end_day;
   if(start_md > end_md)
      return false;
   return (month_day >= start_md && month_day <= end_md);
  }

bool Strategy_ShoulderSeasonKey(const datetime when, int &season_key)
  {
   season_key = 0;
   if(when <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(when, dt);
   const int month_day = dt.mon * 100 + dt.day;

   if(Strategy_DateWithin(month_day,
                          strategy_spring_start_month,
                          strategy_spring_start_day,
                          strategy_spring_end_month,
                          strategy_spring_end_day))
     {
      season_key = dt.year * 10 + 1;
      return true;
     }

   if(Strategy_DateWithin(month_day,
                          strategy_autumn_start_month,
                          strategy_autumn_start_day,
                          strategy_autumn_end_month,
                          strategy_autumn_end_day))
     {
      season_key = dt.year * 10 + 2;
      return true;
     }

   return false;
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

bool Strategy_PricePercentile(const int start_shift,
                              const int lookback,
                              double &percentile)
  {
   percentile = 0.0;
   const int n = MathMax(60, lookback);
   const double current_close = iClose(_Symbol, PERIOD_D1, start_shift); // perf-allowed: completed D1 rank behind new-bar gate.
   if(current_close <= 0.0)
      return false;

   int valid = 0;
   int below_or_equal = 0;
   for(int i = 0; i < n; ++i)
     {
      const double sample_close = iClose(_Symbol, PERIOD_D1, start_shift + i); // perf-allowed: one compact annual D1 rank scan per new bar.
      if(sample_close <= 0.0)
         continue;
      ++valid;
      if(sample_close <= current_close)
         ++below_or_equal;
     }

   if(valid < MathMin(126, n / 2))
      return false;

   percentile = (double)below_or_equal / (double)valid;
   return MathIsValidNumber(percentile);
  }

bool Strategy_LoadDemandFloorState(double &atr_last,
                                   double &price_percentile,
                                   int &season_key)
  {
   atr_last = 0.0;
   price_percentile = 0.0;
   season_key = 0;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 signal date behind new-bar gate.
   if(signal_time <= 0 || !Strategy_ShoulderSeasonKey(signal_time, season_key))
      return false;
   if(season_key == g_last_entry_season_key)
      return false;

   const double signal_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 signal bar.
   const double signal_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 signal bar.
   const double prior_close = iClose(_Symbol, PERIOD_D1, 2);  // perf-allowed: completed D1 reclaim context.
   if(signal_open <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0 ||
      signal_close <= 0.0 || prior_close <= 0.0 || signal_high <= signal_low)
      return false;

   if(!Strategy_PricePercentile(1, strategy_price_rank_lookback, price_percentile))
      return false;
   if(price_percentile > strategy_entry_price_percentile)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_reclaim_sma_period, 1, PRICE_CLOSE);
   const double sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_reclaim_sma_period, 2, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0 || sma_prior <= 0.0)
      return false;

   if(prior_close > sma_prior || signal_close <= sma_last)
      return false;
   if(signal_close <= signal_open)
      return false;

   const double signal_range = signal_high - signal_low;
   const double close_location = (signal_close - signal_low) / signal_range;
   if(signal_range < strategy_min_range_atr * atr_last)
      return false;
   if(close_location < strategy_min_close_location)
      return false;

   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 management bar behind new-bar gate.
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_reclaim_sma_period, 1, PRICE_CLOSE);
   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   double price_percentile = 0.0;
   const bool percentile_ready = Strategy_PricePercentile(1,
                                                           strategy_price_rank_lookback,
                                                           price_percentile);

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

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         should_close = true;
      if(percentile_ready && price_percentile >= strategy_exit_price_percentile)
         should_close = true;
      if(close_last > 0.0 && sma_last > 0.0 && atr_last > 0.0 &&
         close_last < sma_last - strategy_exit_sma_buffer_atr * atr_last)
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
   if(!Strategy_ValidMonthDay(strategy_spring_start_month, strategy_spring_start_day) ||
      !Strategy_ValidMonthDay(strategy_spring_end_month, strategy_spring_end_day) ||
      !Strategy_ValidMonthDay(strategy_autumn_start_month, strategy_autumn_start_day) ||
      !Strategy_ValidMonthDay(strategy_autumn_end_month, strategy_autumn_end_day))
      return true;
   if(strategy_spring_start_month * 100 + strategy_spring_start_day >
      strategy_spring_end_month * 100 + strategy_spring_end_day)
      return true;
   if(strategy_autumn_start_month * 100 + strategy_autumn_start_day >
      strategy_autumn_end_month * 100 + strategy_autumn_end_day)
      return true;
   if(strategy_price_rank_lookback < 60)
      return true;
   if(strategy_entry_price_percentile <= 0.0 || strategy_entry_price_percentile >= 1.0)
      return true;
   if(strategy_exit_price_percentile <= strategy_entry_price_percentile ||
      strategy_exit_price_percentile > 1.0)
      return true;
   if(strategy_reclaim_sma_period <= 1 || strategy_atr_period <= 1)
      return true;
   if(strategy_min_range_atr <= 0.0 || strategy_min_close_location <= 0.0 ||
      strategy_min_close_location >= 1.0)
      return true;
   if(strategy_exit_sma_buffer_atr < 0.0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13099_XNG_COAL_SWITCH";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_candidate_season_key = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double atr_last = 0.0;
   double price_percentile = 0.0;
   int season_key = 0;
   if(!Strategy_LoadDemandFloorState(atr_last, price_percentile, season_key))
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || req.sl >= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = NormalizeDouble(entry_price + strategy_atr_tp_mult * atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= entry_price)
      return false;

   req.reason = "XNG_COAL_SWITCH_DEMAND_FLOOR_LONG";
   g_candidate_season_key = season_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13099\",\"ea\":\"xng-coal-switch\"}");
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
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket) && out_ticket > 0)
         g_last_entry_season_key = g_candidate_season_key;
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

