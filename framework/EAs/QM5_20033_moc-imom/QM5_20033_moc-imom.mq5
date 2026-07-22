#property strict
#property version   "5.0"
#property description "QM5_20033 market-on-close intraday momentum"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20033_moc-imom, G0 APPROVED 2026-07-22.
// Exact session times come from fixed broker-clock inputs on UTC weekdays.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20033;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M30;
input int    strategy_us_open_hour_broker = 16;
input int    strategy_us_open_minute_broker = 30;
input int    strategy_us_entry_hour_broker = 22;
input int    strategy_us_entry_minute_broker = 30;
input int    strategy_us_close_hour_broker = 23;
input int    strategy_us_close_minute_broker = 0;
input int    strategy_xetra_open_hour_broker = 10;
input int    strategy_xetra_open_minute_broker = 0;
input int    strategy_xetra_entry_hour_broker = 18;
input int    strategy_xetra_entry_minute_broker = 0;
input int    strategy_xetra_close_hour_broker = 18;
input int    strategy_xetra_close_minute_broker = 30;
// Tester Groups applies venue commission to fills; zero disables this optional
// native spread guard, matching the proven QM5_12969 execution baseline.
input int    strategy_max_spread_points   = 0;

datetime g_last_attempt_entry_broker = 0;
datetime g_active_exit_broker = 0;

int RouteIndex(const string symbol)
  {
   if(symbol == "SP500.DWX") return 0;
   if(symbol == "NDX.DWX") return 1;
   if(symbol == "WS30.DWX") return 2;
   if(symbol == "GDAXI.DWX") return 3;
   return -1;
  }

bool IsRoutedSymbol(const string symbol)
  {
   return (RouteIndex(symbol) >= 0);
  }

int DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime BrokerDateTime(const int date_key, const int hour, const int minute)
  {
   if(date_key < 19000101 || hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = date_key / 10000;
   parts.mon = (date_key / 100) % 100;
   parts.day = date_key % 100;
   parts.hour = hour;
   parts.min = minute;
   return StructToTime(parts);
  }

bool IsUtcWeekday(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   return (parts.day_of_week >= 1 && parts.day_of_week <= 5);
  }

bool ResolveSessionTimes(const string symbol,
                         const int date_key,
                         datetime &open_broker,
                         datetime &first30_broker,
                         datetime &entry_broker,
                         datetime &exit_broker)
  {
   open_broker = 0;
   first30_broker = 0;
   entry_broker = 0;
   exit_broker = 0;
   const int route = RouteIndex(symbol);
   if(route < 0)
      return false;
   const bool xetra = (route == 3);
   const int open_hour = xetra ? strategy_xetra_open_hour_broker
                               : strategy_us_open_hour_broker;
   const int open_minute = xetra ? strategy_xetra_open_minute_broker
                                 : strategy_us_open_minute_broker;
   const int entry_hour = xetra ? strategy_xetra_entry_hour_broker
                                : strategy_us_entry_hour_broker;
   const int entry_minute = xetra ? strategy_xetra_entry_minute_broker
                                  : strategy_us_entry_minute_broker;
   const int close_hour = xetra ? strategy_xetra_close_hour_broker
                                : strategy_us_close_hour_broker;
   const int close_minute = xetra ? strategy_xetra_close_minute_broker
                                  : strategy_us_close_minute_broker;
   open_broker = BrokerDateTime(date_key, open_hour, open_minute);
   first30_broker = open_broker + 30 * 60;
   entry_broker = BrokerDateTime(date_key, entry_hour, entry_minute);
   exit_broker = BrokerDateTime(date_key, close_hour, close_minute);
   return (open_broker > 0 && first30_broker > open_broker &&
           entry_broker >= first30_broker &&
           exit_broker - entry_broker == 30 * 60);
  }

bool FindOurPosition(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool TickMid(const MqlTick &tick, double &mid)
  {
   mid = 0.0;
   if(tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      return false;
   mid = 0.5 * (tick.bid + tick.ask);
   return (mid > 0.0);
  }

bool OpeningIntervalMove(const datetime open_utc,
                         const datetime first30_utc,
                         double &open_move_signed)
  {
   open_move_signed = 0.0;
   MqlTick ticks[];
   const ulong from_msc = (ulong)open_utc * 1000;
   const ulong to_msc = (ulong)first30_utc * 1000 - 1;
   const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, from_msc, to_msc);
   if(copied <= 0)
      return false;

   double open_mid = 0.0;
   double close_mid = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(TickMid(ticks[i], open_mid))
         break;
     }
   for(int i = copied - 1; i >= 0; --i)
     {
      if(TickMid(ticks[i], close_mid))
         break;
     }
   if(open_mid <= 0.0 || close_mid <= 0.0)
      return false;

   open_mid = QM_TM_NormalizePrice(_Symbol, open_mid);
   close_mid = QM_TM_NormalizePrice(_Symbol, close_mid);
   open_move_signed = close_mid - open_mid;
   return (MathIsValidNumber(open_move_signed));
  }

bool TradeGeometryAndVolumeAllow(const double entry_price, const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   if(risk_per_lot <= 0.0)
      return false;

   const double sl_points = stop_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || sl_points < (double)stop_level)
      return false;

   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0 ||
      lots < volume_min || lots > volume_max)
      return false;
   const double aligned = volume_min + MathRound((lots - volume_min) / volume_step) * volume_step;
   return (MathAbs(aligned - lots) <= volume_step * 1.0e-6);
  }

bool Strategy_InputsValid()
  {
   return (strategy_signal_tf == PERIOD_M30 &&
           strategy_us_open_hour_broker == 16 &&
           strategy_us_open_minute_broker == 30 &&
           strategy_us_entry_hour_broker == 22 &&
           strategy_us_entry_minute_broker == 30 &&
           strategy_us_close_hour_broker == 23 &&
           strategy_us_close_minute_broker == 0 &&
           strategy_xetra_open_hour_broker == 10 &&
           strategy_xetra_open_minute_broker == 0 &&
           strategy_xetra_entry_hour_broker == 18 &&
           strategy_xetra_entry_minute_broker == 0 &&
           strategy_xetra_close_hour_broker == 18 &&
           strategy_xetra_close_minute_broker == 30);
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(FindOurPosition(open_time))
      return false;
   if(!IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      !Strategy_InputsValid())
      return true;
   return Strategy_WideSpread();
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

   if(!IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf ||
      !Strategy_InputsValid())
      return false;
   const datetime current_bar_broker = iTime(_Symbol, strategy_signal_tf, 0); // perf-allowed: exact broker-clock entry bar behind QM_IsNewBar.
   if(current_bar_broker <= 0)
      return false;
   datetime open_broker = 0;
   datetime first30_broker = 0;
   datetime entry_broker = 0;
   datetime exit_broker = 0;
   if(!ResolveSessionTimes(_Symbol,
                           DateKey(current_bar_broker),
                           open_broker,
                           first30_broker,
                           entry_broker,
                           exit_broker) ||
      current_bar_broker != entry_broker ||
      !IsUtcWeekday(entry_broker) ||
      entry_broker == g_last_attempt_entry_broker)
      return false;

   double open_move_signed = 0.0;
   if(!OpeningIntervalMove(QM_BrokerToUTC(open_broker),
                           QM_BrokerToUTC(first30_broker),
                           open_move_signed) || open_move_signed == 0.0)
      return false;

   const bool buy = (open_move_signed > 0.0);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double entry_price = buy ? ask : bid;
   const double open_move = MathAbs(open_move_signed);
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol,
                                                        buy ? entry_price - open_move
                                                            : entry_price + open_move);
   if(stop_price <= 0.0 || stop_price == entry_price ||
      !TradeGeometryAndVolumeAllow(entry_price, stop_price))
      return false;

   req.type = buy ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.reason = buy ? "MOC_IMOM_FIRST30_LONG" : "MOC_IMOM_FIRST30_SHORT";
   g_last_attempt_entry_broker = entry_broker;
   g_active_exit_broker = exit_broker;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!FindOurPosition(open_time))
      g_active_exit_broker = 0;
  }

bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!FindOurPosition(open_time))
      return false;
   if(g_active_exit_broker <= 0)
     {
      datetime open_broker = 0;
      datetime first30_broker = 0;
      datetime entry_broker = 0;
      datetime exit_broker = 0;
      if(ResolveSessionTimes(_Symbol,
                             DateKey(open_time),
                             open_broker,
                             first30_broker,
                             entry_broker,
                             exit_broker))
         g_active_exit_broker = exit_broker;
      else
         g_active_exit_broker = open_time + 30 * 60;
     }
   return (TimeCurrent() >= g_active_exit_broker);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // Baseline card explicitly applies no generic news filter.
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — retained from framework/templates/EA_Skeleton.mq5.
// -----------------------------------------------------------------------------

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

   string allowed_symbols[4] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX"};
   QM_SymbolGuardInit(allowed_symbols);
   QM_BasketWarmupHistory(allowed_symbols, strategy_signal_tf, 64);

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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
   ZeroMemory(req);
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
