#property strict
#property version   "5.0"
#property description "QM5_10712 TradingView ICT Session Breakout Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10712;
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
input int    strategy_session_boundary_hour_cet = 8;
input int    strategy_broker_to_cet_hours       = -1;
input int    strategy_reentry_pips              = 5;
input int    strategy_entry_tolerance_pips      = 5;
input int    strategy_min_bars_after_break      = 3;
input int    strategy_sl_pips                   = 10;
input int    strategy_tp_pips                   = 20;
input int    strategy_atr_period                = 14;
input double strategy_atr_sl_mult               = 1.0;
input double strategy_atr_tp_mult               = 2.0;
input double strategy_max_spread_stop_fraction  = 0.15;
input int    strategy_session_scan_bars         = 600;
input bool   strategy_day_end_flat_enabled      = true;
input int    strategy_day_end_flat_hour_broker  = 23;

struct StrategySetup
  {
   bool   valid;
   int    direction;
   double prev_high;
   double prev_low;
   double reentry_line;
  };

int Strategy_BrokerHour(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour;
  }

datetime Strategy_CurrentSessionStartBroker(const datetime broker_time)
  {
   const datetime cet_time = broker_time + (strategy_broker_to_cet_hours * 3600);
   MqlDateTime dt;
   TimeToStruct(cet_time, dt);
   dt.hour = strategy_session_boundary_hour_cet;
   dt.min = 0;
   dt.sec = 0;
   datetime boundary_cet = StructToTime(dt);
   if(cet_time < boundary_cet)
      boundary_cet -= 86400;
   return boundary_cet - (strategy_broker_to_cet_hours * 3600);
  }

double Strategy_PipDistance(const int pips)
  {
   if(pips <= 0)
      return 0.0;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return pips * point * pip_factor;
  }

bool Strategy_UsesFxPips()
  {
   const string root = StringSubstr(_Symbol, 0, 6);
   return (root == "EURUSD" || root == "GBPUSD");
  }

bool Strategy_BuildSetup(StrategySetup &setup)
  {
   setup.valid = false;
   setup.direction = 0;
   setup.prev_high = 0.0;
   setup.prev_low = 0.0;
   setup.reentry_line = 0.0;

   if(strategy_session_boundary_hour_cet < 0 || strategy_session_boundary_hour_cet > 23)
      return false;

   const datetime now = TimeCurrent();
   const datetime session_start = Strategy_CurrentSessionStartBroker(now);
   const datetime prev_start = session_start - 86400;
   const datetime prev_end = session_start;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int scan_bars = MathMax(100, strategy_session_scan_bars);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, scan_bars, rates); // perf-allowed: bounded session-range structural scan, called only after framework QM_IsNewBar gate.
   if(copied <= 0)
      return false;

   bool have_prev = false;
   for(int i = copied - 1; i >= 0; --i)
     {
      const datetime t = rates[i].time;
      if(t < prev_start || t >= prev_end)
         continue;
      if(!have_prev)
        {
         setup.prev_high = rates[i].high;
         setup.prev_low = rates[i].low;
         have_prev = true;
        }
      else
        {
         setup.prev_high = MathMax(setup.prev_high, rates[i].high);
         setup.prev_low = MathMin(setup.prev_low, rates[i].low);
        }
     }

   if(!have_prev || setup.prev_high <= setup.prev_low)
      return false;

   const double reentry_dist = Strategy_PipDistance(strategy_reentry_pips);
   if(reentry_dist <= 0.0)
      return false;

   bool broke = false;
   bool reentered = false;
   int bars_after_break = 0;
   int direction = 0;
   double reentry_line = 0.0;

   for(int i = copied - 1; i >= 0; --i)
     {
      const datetime t = rates[i].time;
      if(t < session_start)
         continue;

      const bool long_break = (rates[i].open < setup.prev_high && rates[i].close > setup.prev_high);
      const bool short_break = (rates[i].open > setup.prev_low && rates[i].close < setup.prev_low);

      if(!broke)
        {
         if(long_break)
           {
            broke = true;
            direction = 1;
            bars_after_break = 0;
            reentry_line = setup.prev_high - reentry_dist;
           }
         else if(short_break)
           {
            broke = true;
            direction = -1;
            bars_after_break = 0;
            reentry_line = setup.prev_low + reentry_dist;
           }
         continue;
        }

      bars_after_break++;

      if((direction == 1 && short_break) || (direction == -1 && long_break))
        {
         broke = false;
         reentered = false;
         direction = 0;
         reentry_line = 0.0;
         bars_after_break = 0;
         continue;
        }

      if(bars_after_break >= strategy_min_bars_after_break)
        {
         if(direction == 1 && rates[i].low <= reentry_line)
            reentered = true;
         if(direction == -1 && rates[i].high >= reentry_line)
            reentered = true;
        }
     }

   if(!broke || !reentered || direction == 0 || reentry_line <= 0.0)
      return false;

   const double tolerance = Strategy_PipDistance(strategy_entry_tolerance_pips);
   if(tolerance <= 0.0)
      return false;

   const double last_high = rates[0].high;
   const double last_low = rates[0].low;
   const bool latest_retest = (last_low <= reentry_line + tolerance && last_high >= reentry_line - tolerance);
   if(!latest_retest)
      return false;

   setup.valid = true;
   setup.direction = direction;
   setup.reentry_line = reentry_line;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5 && _Period != PERIOD_M15)
      return true;

   if(strategy_day_end_flat_enabled &&
      Strategy_BrokerHour(TimeCurrent()) >= strategy_day_end_flat_hour_broker)
      return true;

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

   StrategySetup setup;
   if(!Strategy_BuildSetup(setup))
      return false;

   const QM_OrderType side = (setup.direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(Strategy_UsesFxPips())
     {
      sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
      tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
     }
   else
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
      tp = QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_atr_tp_mult);
     }

   if(sl <= 0.0 || tp <= 0.0)
      return false;

   const double planned_stop_distance = MathAbs(entry - sl);
   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(planned_stop_distance <= 0.0 || spread < 0.0)
      return false;
   if(spread > planned_stop_distance * strategy_max_spread_stop_fraction)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (setup.direction > 0) ? "ICT_RETEST_LONG" : "ICT_RETEST_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   if(!strategy_day_end_flat_enabled)
      return false;
   return (Strategy_BrokerHour(TimeCurrent()) >= strategy_day_end_flat_hour_broker);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10712_tv-ict-retest\"}");
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
