#property strict
#property version   "5.0"
#property description "QM5_1200 Quantpedia SP500 10-day maximum short fade"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1200;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_extreme_lookback_d1 = 10;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 2.0;
input int    strategy_min_history_d1_bars = 60;
input int    strategy_hold_trading_days   = 1;
input int    strategy_session_close_hour  = 21;
input int    strategy_session_close_min   = 45;
input double strategy_spread_median_mult  = 3.0;
input int    strategy_spread_lookback_m30 = 960;
input bool   strategy_use_sma10_exit      = false;

const string STRATEGY_SYMBOL = "SP500.DWX";

datetime g_last_entry_bar = 0;
datetime g_last_exit_mark = 0;

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinutesOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_HasOpenShort(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      ticket = pos_ticket;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_TradingStatusValid()
  {
   if(!SymbolSelect(_Symbol, true))
      return false;
   return (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED);
  }

bool Strategy_IsTenDayCloseMaximum()
  {
   const int lookback = MathMax(2, strategy_extreme_lookback_d1);
   if(Bars(_Symbol, PERIOD_D1) < lookback + 2)
      return false;

   const double today_close = iClose(_Symbol, PERIOD_D1, 1);
   if(today_close <= 0.0)
      return false;

   for(int shift = 2; shift <= lookback; ++shift)
     {
      const double close_value = iClose(_Symbol, PERIOD_D1, shift);
      if(close_value <= 0.0)
         return false;
      if(today_close < close_value)
         return false;
     }

   return true;
  }

bool Strategy_Sma10Exit()
  {
   if(!strategy_use_sma10_exit)
      return false;
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double sma10 = QM_SMA(_Symbol, PERIOD_D1, 10, 1);
   return (close1 > 0.0 && sma10 > 0.0 && close1 < sma10);
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_spread_median_mult <= 0.0 || strategy_spread_lookback_m30 <= 0)
      return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M30, 1, strategy_spread_lookback_m30, rates); // perf-allowed: helper is called only from the QM_IsNewBar-gated entry path
   if(copied < 20)
      return false;

   double spreads[];
   ArrayResize(spreads, copied);
   int usable = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[usable] = (double)rates[i].spread;
      ++usable;
     }

   if(usable < 20)
      return false;

   ArrayResize(spreads, usable);
   ArraySort(spreads);
   const double median = (usable % 2 == 1)
                         ? spreads[usable / 2]
                         : (spreads[usable / 2 - 1] + spreads[usable / 2]) * 0.5;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median <= 0.0 || current_spread <= 0)
      return false;

   return ((double)current_spread <= median * strategy_spread_median_mult);
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= entry)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(sl - entry) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(!Strategy_TradingStatusValid())
      return true;
   if(strategy_extreme_lookback_d1 < 2 || strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_min_history_d1_bars < strategy_extreme_lookback_d1 + strategy_atr_period_d1)
      return true;
   if(strategy_hold_trading_days < 1)
      return true;
   if(Bars(_Symbol, PERIOD_D1) < strategy_min_history_d1_bars)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime signal_bar = Strategy_LastClosedD1Time();
   if(signal_bar <= 0 || g_last_entry_bar == signal_bar)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenShort(ticket, opened_at))
      return false;

   if(!Strategy_IsTenDayCloseMaximum())
      return false;
   if(!Strategy_SpreadAllowed())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, sl))
      return false;

   req.price = entry;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "QM5_1200_SP500_MAX10_FADE_SHORT";

   g_last_entry_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenShort(ticket, opened_at))
      return false;

   const datetime now = TimeCurrent();
   const datetime closed_bar = Strategy_LastClosedD1Time();
   if(now <= 0 || closed_bar <= 0 || g_last_exit_mark == closed_bar)
      return false;

   if(Strategy_Sma10Exit())
     {
      g_last_exit_mark = closed_bar;
      return true;
     }

   const int close_minutes = strategy_session_close_hour * 60 + strategy_session_close_min;
   if(Strategy_DateKey(now) != Strategy_DateKey(opened_at)
      && Strategy_MinutesOfDay(now) >= close_minutes)
     {
      g_last_exit_mark = closed_bar;
      return true;
     }

   const int bars_since_open = iBarShift(_Symbol, PERIOD_D1, opened_at, false);
   if(bars_since_open > strategy_hold_trading_days)
     {
      g_last_exit_mark = closed_bar;
      return true;
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

   string symbols[1] = {STRATEGY_SYMBOL};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_D1, MathMax(strategy_min_history_d1_bars, strategy_spread_lookback_m30 / 48 + 30));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1200_qp-sp500-max10-fade\"}");
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
      const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
