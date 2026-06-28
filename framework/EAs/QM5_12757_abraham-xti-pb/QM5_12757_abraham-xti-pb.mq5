#property strict
#property version   "5.0"
#property description "QM5_12757 Abraham WTI Breakout Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12757 - Abraham WTI Breakout Pullback
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - confirm a 20-day channel breakout with MACD zero-line alignment
//   - wait for a later pullback to the old breakout boundary
//   - use a 10-day structural hard stop and ATR(39) trailing stop
// Runtime uses MT5 OHLC and framework indicator helpers only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12757;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_channel_period       = 20;
input int    strategy_stop_period          = 10;
input int    strategy_macd_fast            = 12;
input int    strategy_macd_slow            = 26;
input int    strategy_macd_signal          = 9;
input int    strategy_atr_period           = 39;
input double strategy_atr_trail_mult       = 3.0;
input double strategy_trail_activation_atr = 1.0;
input int    strategy_setup_max_days       = 15;
input int    strategy_max_hold_days        = 45;
input int    strategy_max_spread_points    = 1000;

int      g_setup_direction = 0;
double   g_setup_boundary = 0.0;
datetime g_setup_time = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

void Strategy_ClearSetup()
  {
   g_setup_direction = 0;
   g_setup_boundary = 0.0;
   g_setup_time = 0;
  }

int Strategy_DaysBetween(const datetime later_time, const datetime earlier_time)
  {
   if(later_time <= 0 || earlier_time <= 0 || later_time < earlier_time)
      return 0;
   return (int)((later_time - earlier_time) / 86400);
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

bool Strategy_LoadClosedState(double &high_last,
                              double &low_last,
                              double &close_last,
                              datetime &closed_time,
                              double &channel_high,
                              double &channel_low,
                              double &stop_low,
                              double &stop_high,
                              double &macd_main,
                              double &atr_value)
  {
   const int bars_needed = MathMax(strategy_channel_period + 1, strategy_stop_period);
   if(bars_needed <= 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: bounded D1 channel and structural-stop math, called on closed-bar strategy path.
   if(copied < bars_needed)
      return false;

   high_last = rates[0].high;
   low_last = rates[0].low;
   close_last = rates[0].close;
   closed_time = rates[0].time;
   if(high_last <= 0.0 || low_last <= 0.0 || close_last <= 0.0 || closed_time <= 0)
      return false;

   channel_high = -DBL_MAX;
   channel_low = DBL_MAX;
   for(int i = 1; i <= strategy_channel_period; ++i)
     {
      if(rates[i].high > channel_high)
         channel_high = rates[i].high;
      if(rates[i].low < channel_low)
         channel_low = rates[i].low;
     }

   stop_low = DBL_MAX;
   stop_high = -DBL_MAX;
   for(int j = 0; j < strategy_stop_period; ++j)
     {
      if(rates[j].low < stop_low)
         stop_low = rates[j].low;
      if(rates[j].high > stop_high)
         stop_high = rates[j].high;
     }

   macd_main = QM_MACD_Main(_Symbol,
                            PERIOD_D1,
                            strategy_macd_fast,
                            strategy_macd_slow,
                            strategy_macd_signal,
                            1);
   atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   return (channel_high > 0.0 &&
           channel_low > 0.0 &&
           stop_low > 0.0 &&
           stop_high > 0.0 &&
           atr_value > 0.0);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_SetupExpired(const datetime closed_time)
  {
   if(g_setup_direction == 0 || g_setup_time <= 0)
      return false;
   return (Strategy_DaysBetween(closed_time, g_setup_time) > strategy_setup_max_days);
  }

bool Strategy_BuildEntryRequest(const QM_OrderType side,
                                const double stop_low,
                                const double stop_high,
                                QM_EntryRequest &req)
  {
   req.type = side;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "ABRAHAM_XTI_PULLBACK_LONG" : "ABRAHAM_XTI_PULLBACK_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopStructureFromExtremes(_Symbol, req.type, stop_low, stop_high);
   if(req.sl <= 0.0)
      return false;

   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;
   return true;
  }

void Strategy_MaybeRecordBreakoutSetup(const double close_last,
                                       const double channel_high,
                                       const double channel_low,
                                       const double macd_main,
                                       const datetime closed_time)
  {
   if(close_last > channel_high && macd_main > 0.0)
     {
      g_setup_direction = 1;
      g_setup_boundary = channel_high;
      g_setup_time = closed_time;
      return;
     }

   if(close_last < channel_low && macd_main < 0.0)
     {
      g_setup_direction = -1;
      g_setup_boundary = channel_low;
      g_setup_time = closed_time;
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_channel_period < 5 || strategy_stop_period < 2)
      return true;
   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast || strategy_macd_signal <= 0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_trail_mult <= 0.0 || strategy_trail_activation_atr < 0.0)
      return true;
   if(strategy_setup_max_days <= 0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12757_ABRAHAM_XTI_PB";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double high_last = 0.0;
   double low_last = 0.0;
   double close_last = 0.0;
   datetime closed_time = 0;
   double channel_high = 0.0;
   double channel_low = 0.0;
   double stop_low = 0.0;
   double stop_high = 0.0;
   double macd_main = 0.0;
   double atr_value = 0.0;
   if(!Strategy_LoadClosedState(high_last,
                                low_last,
                                close_last,
                                closed_time,
                                channel_high,
                                channel_low,
                                stop_low,
                                stop_high,
                                macd_main,
                                atr_value))
      return false;

   if(Strategy_SetupExpired(closed_time))
      Strategy_ClearSetup();

   if(g_setup_direction != 0 && g_setup_time != closed_time)
     {
      if((g_setup_direction > 0 && macd_main <= 0.0) ||
         (g_setup_direction < 0 && macd_main >= 0.0))
        {
         Strategy_ClearSetup();
        }
      else if(g_setup_direction > 0 &&
              low_last <= g_setup_boundary &&
              close_last >= g_setup_boundary)
        {
         if(Strategy_BuildEntryRequest(QM_BUY, stop_low, stop_high, req))
           {
            Strategy_ClearSetup();
            return true;
           }
        }
      else if(g_setup_direction < 0 &&
              high_last >= g_setup_boundary &&
              close_last <= g_setup_boundary)
        {
         if(Strategy_BuildEntryRequest(QM_SELL, stop_low, stop_high, req))
           {
            Strategy_ClearSetup();
            return true;
           }
        }
     }

   Strategy_MaybeRecordBreakoutSetup(close_last,
                                     channel_high,
                                     channel_low,
                                     macd_main,
                                     closed_time);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

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
      if(opened > 0 && now - opened >= hold_seconds)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(open_price <= 0.0 || market_price <= 0.0 || atr_value <= 0.0)
         continue;

      const double favorable = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(favorable >= atr_value * strategy_trail_activation_atr)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_trail_mult);
     }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12757\",\"ea\":\"abraham-xti-pb\"}");
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
