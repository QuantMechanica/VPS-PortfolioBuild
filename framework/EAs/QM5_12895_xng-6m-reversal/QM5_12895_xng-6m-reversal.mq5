#property strict
#property version   "5.0"
#property description "QM5_12895 XNG 6M Overextension Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12895 - XNG 6M Overextension Fade
// -----------------------------------------------------------------------------
// D1 structural XNG sleeve:
//   - evaluates one monthly overextension setup on XNGUSD.DWX
//   - fades fixed 120-D1-bar natural-gas return extremes
//   - requires price to be stretched from SMA(20) by an ATR multiple
//   - exits by 6M-return zero-cross, max-hold guard, or ATR stop
// Runtime uses MT5 OHLC only; no storage feed, weather feed, API, CSV, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12895;
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
input int    strategy_lookback_days        = 120;
input int    strategy_sma_period           = 20;
input int    strategy_atr_period           = 20;
input double strategy_fade_threshold_pct   = 20.0;
input double strategy_stretch_atr_mult     = 1.5;
input double strategy_atr_sl_mult          = 2.5;
input int    strategy_max_hold_days        = 40;
input int    strategy_max_spread_points    = 2500;

int g_last_signal_month_key = -1;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   if(t <= 0)
      return -1;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsFirstD1BarOfMonth(const datetime t)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);

   const datetime prev_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 calendar gate.
   if(prev_bar_time <= 0)
      return false;
   MqlDateTime prev_dt;
   TimeToStruct(prev_bar_time, prev_dt);
   return (dt.year != prev_dt.year || dt.mon != prev_dt.mon);
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

bool Strategy_LoadReversalState(double &half_year_return_pct,
                                double &atr_last,
                                double &sma_last,
                                double &stretch_atr,
                                int &signal_month_key,
                                const bool require_monthly_gate)
  {
   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 monthly calendar gate.
   if(require_monthly_gate && !Strategy_IsFirstD1BarOfMonth(current_bar_time))
      return false;

   signal_month_key = Strategy_MonthKey(current_bar_time);

   int lookback = strategy_lookback_days;
   if(lookback < 30)
      lookback = 30;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int close_count = CopyClose(_Symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed: bounded D1 return window behind new-bar.
   if(close_count < lookback + 1)
      return false;

   int sma_period = strategy_sma_period;
   if(sma_period < 2)
      sma_period = 2;

   double sma_closes[];
   ArraySetAsSeries(sma_closes, true);
   const int sma_count = CopyClose(_Symbol, PERIOD_D1, 1, sma_period, sma_closes); // perf-allowed: bounded D1 SMA confirmation behind new-bar.
   if(sma_count < sma_period)
      return false;

   double sma_sum = 0.0;
   for(int i = 0; i < sma_period; ++i)
      sma_sum += sma_closes[i];

   const double close_last = closes[0];
   const double close_lookback = closes[lookback];
   if(close_last <= 0.0 || close_lookback <= 0.0)
      return false;

   sma_last = sma_sum / (double)sma_period;
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(signal_month_key < 0)
      return false;
   if(sma_last <= 0.0)
      return false;
   if(atr_last <= 0.0)
      return false;

   half_year_return_pct = 100.0 * ((close_last / close_lookback) - 1.0);
   stretch_atr = (close_last - sma_last) / atr_last;
   if(!MathIsValidNumber(half_year_return_pct) || !MathIsValidNumber(stretch_atr))
      return false;

   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   int hold_days = strategy_max_hold_days;
   if(hold_days < 1)
      hold_days = 1;
   const int hold_seconds = hold_days * 86400;

   double half_year_return_pct = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double stretch_atr = 0.0;
   int signal_month_key = -1;
   const bool state_ready = Strategy_LoadReversalState(half_year_return_pct,
                                                       atr_last,
                                                       sma_last,
                                                       stretch_atr,
                                                       signal_month_key,
                                                       false);

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
      bool should_close = false;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(state_ready)
        {
         const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(position_type == POSITION_TYPE_BUY && half_year_return_pct >= 0.0)
            should_close = true;
         if(position_type == POSITION_TYPE_SELL && half_year_return_pct <= 0.0)
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
   if(strategy_lookback_days < 30 || strategy_sma_period <= 1 || strategy_atr_period <= 0)
      return true;
   if(strategy_fade_threshold_pct <= 0.0 || strategy_stretch_atr_mult <= 0.0)
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
   req.reason = "QM5_12895_XNG_6M_REVERSAL";
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

   double half_year_return_pct = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double stretch_atr = 0.0;
   int signal_month_key = -1;
   if(!Strategy_LoadReversalState(half_year_return_pct,
                                  atr_last,
                                  sma_last,
                                  stretch_atr,
                                  signal_month_key,
                                  true))
      return false;
   if(signal_month_key == g_last_signal_month_key)
      return false;

   const double min_return = strategy_fade_threshold_pct;
   const double min_stretch = strategy_stretch_atr_mult;

   int reversal_direction = 0;
   if(half_year_return_pct <= -min_return && stretch_atr <= -min_stretch)
      reversal_direction = 1;
   else if(half_year_return_pct >= min_return && stretch_atr >= min_stretch)
      reversal_direction = -1;
   else
      return false;

   req.type = (reversal_direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (reversal_direction > 0) ? "XNG_6M_REVERSAL_LONG" : "XNG_6M_REVERSAL_SHORT";
   g_last_signal_month_key = signal_month_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12895\",\"ea\":\"xng-6m-reversal\"}");
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
