#property strict
#property version   "5.0"
#property description "QM5_12725 EIA XNG Pre-Storage Compression Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12725 - EIA XNG Pre-Storage Compression Trend
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - entries only at the start of expected EIA storage-report D1 bars
//   - requires prior-bar compression plus SMA/momentum directional confirmation
//   - exits after the report window or on SMA trend failure
// Runtime uses MT5 OHLC only; no EIA feed, storage surprise feed, CSV, or API.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12725;
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
input int    strategy_trend_period           = 63;
input int    strategy_momentum_period        = 5;
input int    strategy_compression_lookback   = 5;
input double strategy_compression_atr_mult   = 0.85;
input double strategy_atr_sl_mult            = 3.0;
input int    strategy_max_hold_days          = 2;
input int    strategy_max_spread_points      = 2500;

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

bool Strategy_PreStorageDay(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   return (dt.day_of_week == 3 || dt.day_of_week == 4 || dt.day_of_week == 5);
  }

bool Strategy_CurrentBarIsPreStorageDay()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 EIA storage calendar gate.
   if(current_bar <= 0)
      return false;
   return Strategy_PreStorageDay(current_bar);
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

bool Strategy_LoadSetupState(double &close_last,
                             double &close_momentum_ref,
                             double &atr_last,
                             double &sma_last,
                             double &avg_range,
                             int &signal_day_key)
  {
   const int max_needed = MathMax(strategy_momentum_period, strategy_compression_lookback) + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, max_needed, rates) < max_needed) // perf-allowed: prior D1 compression/momentum state, new-bar gated.
      return false;

   close_last = rates[0].close;
   close_momentum_ref = rates[strategy_momentum_period].close;
   signal_day_key = Strategy_DayKey(iTime(_Symbol, PERIOD_D1, 0)); // perf-allowed: D1 signal de-duplication key, new-bar gated.
   if(close_last <= 0.0 || close_momentum_ref <= 0.0 || signal_day_key <= 0)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;

   avg_range = 0.0;
   for(int i = 0; i < strategy_compression_lookback; ++i)
     {
      const double range = rates[i].high - rates[i].low;
      if(range <= 0.0)
         return false;
      avg_range += range;
     }
   avg_range /= (double)strategy_compression_lookback;
   return MathIsValidNumber(avg_range);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double close_momentum_ref = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double avg_range = 0.0;
   int signal_day_key = 0;
   const bool have_state = Strategy_LoadSetupState(close_last,
                                                   close_momentum_ref,
                                                   atr_last,
                                                   sma_last,
                                                   avg_range,
                                                   signal_day_key);
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
         if(pos_type == POSITION_TYPE_BUY && close_last < sma_last)
            should_close = true;
         if(pos_type == POSITION_TYPE_SELL && close_last > sma_last)
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
   if(strategy_atr_period <= 0 || strategy_trend_period <= 1 || strategy_momentum_period <= 0)
      return true;
   if(strategy_compression_lookback <= 0 || strategy_compression_atr_mult <= 0.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12725_EIA_XNG_PRESTOR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(!Strategy_CurrentBarIsPreStorageDay())
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
   double close_momentum_ref = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double avg_range = 0.0;
   int signal_day_key = 0;
   if(!Strategy_LoadSetupState(close_last, close_momentum_ref, atr_last, sma_last, avg_range, signal_day_key))
      return false;
   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;

   if(avg_range > atr_last * strategy_compression_atr_mult)
      return false;

   int direction = 0;
   if(close_last > sma_last && close_last > close_momentum_ref)
      direction = 1;
   else if(close_last < sma_last && close_last < close_momentum_ref)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "EIA_XNG_PRESTOR_LONG" : "EIA_XNG_PRESTOR_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12725\",\"ea\":\"eia-xng-prestor\"}");
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
