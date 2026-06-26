#property strict
#property version   "5.0"
#property description "QM5_12575 EIA XNG Seasonal Demand Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12575 - EIA XNG Seasonal Demand Trend
// -----------------------------------------------------------------------------
// D1 monthly structural natural-gas sleeve:
//   - Long months: Nov, Dec, Jan, Feb, Jul, Aug
//   - Short months: Apr, May, Sep, Oct
//   - Neutral: Mar, Jun
// Entry occurs only at month roll and only when the closed D1 price confirms
// direction versus SMA(63). Runtime uses MT5 OHLC only; no external EIA data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12575;
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
input int    strategy_trend_period        = 63;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_spread_points   = 800;

int g_last_entry_month_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_MonthFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon;
  }

bool Strategy_IsFirstBarOfMonth()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: monthly calendar gate needs D1 bar timestamps
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: monthly calendar gate needs D1 bar timestamps
   if(current_bar <= 0 || closed_bar <= 0)
      return false;
   return (Strategy_MonthKey(current_bar) != Strategy_MonthKey(closed_bar));
  }

int Strategy_SeasonDirection(const int month)
  {
   if(month == 11 || month == 12 || month == 1 || month == 2 || month == 7 || month == 8)
      return 1;
   if(month == 4 || month == 5 || month == 9 || month == 10)
      return -1;
   return 0;
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

bool Strategy_CloseAndSma(double &close_last, double &sma_last)
  {
   close_last = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   return (close_last > 0.0 && sma_last > 0.0);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double sma_last = 0.0;
   if(!Strategy_CloseAndSma(close_last, sma_last))
      return;

   const int month = Strategy_MonthFromTime(iTime(_Symbol, PERIOD_D1, 0)); // perf-allowed: monthly calendar gate needs D1 bar timestamp
   const int season_dir = Strategy_SeasonDirection(month);
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;
      if(pos_type == POSITION_TYPE_BUY)
         should_close = (season_dir != 1 || close_last < sma_last);
      if(pos_type == POSITION_TYPE_SELL)
         should_close = (season_dir != -1 || close_last > sma_last);

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12575_EIA_XNG_SEASON";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(!Strategy_IsFirstBarOfMonth())
      return false;

   const int current_month_key = Strategy_MonthKey(iTime(_Symbol, PERIOD_D1, 0)); // perf-allowed: monthly rebalance key needs D1 bar timestamp
   if(current_month_key <= 0 || current_month_key == g_last_entry_month_key)
      return false;
   g_last_entry_month_key = current_month_key;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double close_last = 0.0;
   double sma_last = 0.0;
   if(!Strategy_CloseAndSma(close_last, sma_last))
      return false;

   const int month = Strategy_MonthFromTime(iTime(_Symbol, PERIOD_D1, 0)); // perf-allowed: monthly seasonal direction needs D1 bar timestamp
   const int season_dir = Strategy_SeasonDirection(month);
   if(season_dir == 0)
      return false;

   if(season_dir > 0 && close_last <= sma_last)
      return false;
   if(season_dir < 0 && close_last >= sma_last)
      return false;

   req.type = (season_dir > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (season_dir > 0) ? "EIA_XNG_SEASON_LONG" : "EIA_XNG_SEASON_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12575\",\"ea\":\"eia-xng-season\"}");
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
