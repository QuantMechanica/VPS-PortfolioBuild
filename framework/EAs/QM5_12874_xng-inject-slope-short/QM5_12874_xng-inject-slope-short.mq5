#property strict
#property version   "5.0"
#property description "QM5_12874 XNG Injection-Season Slope Short"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12874 - XNG Injection-Season Slope Short
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - trades only during the April-October storage injection regime
//   - enters at most once per eligible month
//   - short-only when prior close, fast/slow SMA alignment, and SMA slopes confirm
// Runtime uses MT5 OHLC/broker calendar only; no EIA, storage, weather, API,
// CSV, forecast, power-load, or futures-curve feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12874;
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
input int    strategy_fast_period          = 21;
input int    strategy_slow_period          = 63;
input int    strategy_slope_lookback_days  = 10;
input double strategy_min_fast_slope_atr   = 0.20;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 28;
input int    strategy_max_spread_points    = 2500;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthFromTime(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon;
  }

bool Strategy_InInjectionWindow(const datetime t)
  {
   const int month = Strategy_MonthFromTime(t);
   return (month >= 4 && month <= 10);
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

bool Strategy_LoadSlopeState(double &close_last,
                             double &fast_sma,
                             double &slow_sma,
                             double &fast_slope_atr,
                             double &slow_slope_atr,
                             double &atr_last,
                             datetime &current_bar_time)
  {
   current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate.
   close_last = iClose(_Symbol, PERIOD_D1, 1);      // perf-allowed: prior closed D1 signal bar.
   if(current_bar_time <= 0 || close_last <= 0.0)
      return false;

   const int fast_period = MathMax(2, strategy_fast_period);
   const int slow_period = MathMax(fast_period + 1, strategy_slow_period);
   const int slope_lookback = MathMax(1, strategy_slope_lookback_days);
   const int slope_shift = 1 + slope_lookback;

   fast_sma = QM_SMA(_Symbol, PERIOD_D1, fast_period, 1, PRICE_CLOSE);
   slow_sma = QM_SMA(_Symbol, PERIOD_D1, slow_period, 1, PRICE_CLOSE);
   const double fast_sma_past = QM_SMA(_Symbol, PERIOD_D1, fast_period, slope_shift, PRICE_CLOSE);
   const double slow_sma_past = QM_SMA(_Symbol, PERIOD_D1, slow_period, slope_shift, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(fast_sma <= 0.0 || slow_sma <= 0.0 || fast_sma_past <= 0.0 || slow_sma_past <= 0.0 || atr_last <= 0.0)
      return false;

   fast_slope_atr = (fast_sma - fast_sma_past) / atr_last;
   slow_slope_atr = (slow_sma - slow_sma_past) / atr_last;
   return (MathIsValidNumber(fast_slope_atr) && MathIsValidNumber(slow_slope_atr));
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double fast_sma = 0.0;
   double slow_sma = 0.0;
   double fast_slope_atr = 0.0;
   double slow_slope_atr = 0.0;
   double atr_last = 0.0;
   datetime current_bar_time = 0;
   if(!Strategy_LoadSlopeState(close_last,
                               fast_sma,
                               slow_sma,
                               fast_slope_atr,
                               slow_slope_atr,
                               atr_last,
                               current_bar_time))
      return;

   const bool in_window = Strategy_InInjectionWindow(current_bar_time);
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
   if(strategy_fast_period <= 1 || strategy_slow_period <= strategy_fast_period)
      return true;
   if(strategy_slope_lookback_days <= 0 || strategy_min_fast_slope_atr <= 0.0)
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
   req.reason = "QM5_12874_XNG_INJECT_SLOPE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Latched exactly once per broker-calendar month via the framework's D1
   // calendar tracker. Must be called unconditionally on every invocation
   // (before any early-return) so the month-transition edge is never missed
   // while a position is held or spread/data checks fail on that bar.
   const bool is_first_bar_of_month = QM_IsNewCalendarPeriod(PERIOD_MN1);
   if(!is_first_bar_of_month)
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
   double slow_sma = 0.0;
   double fast_slope_atr = 0.0;
   double slow_slope_atr = 0.0;
   double atr_last = 0.0;
   datetime current_bar_time = 0;
   if(!Strategy_LoadSlopeState(close_last,
                               fast_sma,
                               slow_sma,
                               fast_slope_atr,
                               slow_slope_atr,
                               atr_last,
                               current_bar_time))
      return false;

   if(!Strategy_InInjectionWindow(current_bar_time))
      return false;
   if(close_last >= slow_sma)
      return false;
   if(fast_sma >= slow_sma)
      return false;
   if(fast_slope_atr > -strategy_min_fast_slope_atr)
      return false;
   if(slow_slope_atr >= 0.0)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "XNG_INJECT_SLOPE_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12874\",\"ea\":\"xng-inject-slope-short\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Position management and rule-based exits (season end / fast-SMA
   // recovery / slope flip / max-hold) must keep running through news
   // windows -- the news gate below blocks NEW entries only. See the
   // 2026-07-02 audit finding (QM5_12821 OnTick, commit dc418a720) for the
   // canonical order this mirrors.
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
