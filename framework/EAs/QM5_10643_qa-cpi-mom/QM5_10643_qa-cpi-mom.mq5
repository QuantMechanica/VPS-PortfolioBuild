#property strict
#property version   "5.0"
#property description "QM5_10643 Quant Arb CPI Surprise Index Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10643;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input datetime strategy_release_time                  = D'2024.01.11 15:30:00';
input bool     strategy_event_values_valid            = true;
input double   strategy_actual_cpi                    = 3.0;
input double   strategy_expected_cpi                  = 3.2;
input double   strategy_surprise_threshold_pp         = 0.10;
input int      strategy_entry_delay_seconds           = 5;
input int      strategy_entry_window_seconds          = 90;
input int      strategy_release_time_uncertainty_sec  = 0;
input int      strategy_atr_period                    = 14;
input double   strategy_confirm_atr_mult              = 0.25;
input double   strategy_stop_atr_mult                 = 1.0;
input int      strategy_time_exit_minutes             = 15;
input double   strategy_pre_release_median_spread_pts = 40.0;
input double   strategy_spread_cap_mult               = 3.0;

bool   g_event_signal_fired = false;
double g_release_open = 0.0;

double Strategy_CurrentSpreadPoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0 || ask < bid)
      return DBL_MAX;
   return (ask - bid) / point;
  }

double Strategy_CurrentMid()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return 0.0;
   return (bid + ask) * 0.5;
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

bool Strategy_ResolveReleaseOpen()
  {
   if(g_release_open > 0.0)
      return true;
   if(strategy_release_time <= 0)
      return false;

   const int release_shift = iBarShift(_Symbol, PERIOD_M1, strategy_release_time, false);
   if(release_shift < 0)
      return false;

   g_release_open = iOpen(_Symbol, PERIOD_M1, release_shift); // perf-allowed: one release-bar anchor lookup for the event timestamp.
   return (g_release_open > 0.0);
  }

bool Strategy_EventInputsReady()
  {
   if(!strategy_event_values_valid)
      return false;
   if(strategy_release_time <= 0)
      return false;
   if(strategy_release_time_uncertainty_sec > 5)
      return false;
   if(strategy_surprise_threshold_pp <= 0.0 ||
      strategy_entry_delay_seconds < 0 ||
      strategy_entry_window_seconds <= strategy_entry_delay_seconds ||
      strategy_atr_period <= 0 ||
      strategy_confirm_atr_mult <= 0.0 ||
      strategy_stop_atr_mult <= 0.0 ||
      strategy_time_exit_minutes <= 0 ||
      strategy_pre_release_median_spread_pts <= 0.0 ||
      strategy_spread_cap_mult <= 0.0)
      return false;
   return true;
  }

bool Strategy_WithinEntryWindow(const datetime broker_now)
  {
   const int elapsed_seconds = (int)(broker_now - strategy_release_time);
   return (elapsed_seconds >= strategy_entry_delay_seconds &&
           elapsed_seconds <= strategy_entry_window_seconds);
  }

// No Trade Filter: parameter and timeframe safety. Entry-specific time,
// spread, and CPI-event news gates are enforced inside Strategy_EntrySignal so
// open-position management and exits remain active outside the entry window.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M1)
      return true;
   return !Strategy_EventInputsReady();
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

   if(g_event_signal_fired || Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_WithinEntryWindow(broker_now))
      return false;

   const double spread_points = Strategy_CurrentSpreadPoints();
   if(spread_points == DBL_MAX ||
      spread_points > strategy_pre_release_median_spread_pts * strategy_spread_cap_mult)
      return false;

   if(!Strategy_ResolveReleaseOpen())
      return false;

   const double surprise = strategy_actual_cpi - strategy_expected_cpi;
   if(MathAbs(surprise) < strategy_surprise_threshold_pp)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period, 1);
   const double mid = Strategy_CurrentMid();
   if(atr <= 0.0 || mid <= 0.0)
      return false;

   const double confirm_distance = atr * strategy_confirm_atr_mult;
   if(surprise <= -strategy_surprise_threshold_pp &&
      mid >= g_release_open + confirm_distance)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_stop_atr_mult);
      req.reason = "CPI_COOL_SURPRISE_LONG";
      g_event_signal_fired = (req.sl > 0.0 && req.sl < ask);
      return g_event_signal_fired;
     }

   if(surprise >= strategy_surprise_threshold_pp &&
      mid <= g_release_open - confirm_distance)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr, strategy_stop_atr_mult);
      req.reason = "CPI_HOT_SURPRISE_SHORT";
      g_event_signal_fired = (req.sl > bid);
      return g_event_signal_fired;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(market_price <= 0.0 || point <= 0.0)
         continue;

      const double risk_distance = MathAbs(open_price - current_sl);
      const double favorable_move = is_buy ? (market_price - open_price)
                                           : (open_price - market_price);
      if(risk_distance <= 0.0 || favorable_move < risk_distance)
         continue;

      const double spread_buffer = Strategy_CurrentSpreadPoints() * point;
      if(spread_buffer <= 0.0 || spread_buffer == DBL_MAX)
         continue;

      const double be_sl = is_buy ? (open_price + spread_buffer)
                                  : (open_price - spread_buffer);
      const bool improves = is_buy ? (be_sl > current_sl + point * 0.5)
                                   : (be_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, be_sl, "cpi_plus_1r_breakeven_spread_buffer");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(entry_time > 0 && TimeCurrent() - entry_time >= strategy_time_exit_minutes * 60)
         return true;

      if(!Strategy_ResolveReleaseOpen())
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && bid <= g_release_open)
            return true;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && ask >= g_release_open)
            return true;
        }
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10643_qa-cpi-mom\"}");
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
