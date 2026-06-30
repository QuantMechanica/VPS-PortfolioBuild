#property strict
#property version   "5.0"
#property description "QM5_1446 DeMark TD Open Range Projection H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1446;
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
input ENUM_TIMEFRAMES strategy_signal_tf             = PERIOD_H4;
input int             strategy_atr_period            = 20;
input int             strategy_d1_sma_period         = 50;
input double          strategy_gap_min_d1_atr_mult   = 0.40;
input double          strategy_gap_max_d1_atr_mult   = 2.50;
input int             strategy_return_window_h4_bars = 4;
input double          strategy_entry_slippage_atr    = 0.15;
input double          strategy_sl_atr_mult           = 0.50;
input double          strategy_sl_cap_atr_mult       = 2.00;
input double          strategy_tp1_close_fraction    = 0.60;
input int             strategy_time_stop_bars        = 6;
input int             strategy_eod_close_hour_broker = 22;
input bool            strategy_news_filter_enabled   = true;
input int             strategy_news_window_h4_bars   = 2;

struct StrategyDaySetup
  {
   int      day_key;
   datetime reference_time;
   datetime trigger_time;
   double   pd_high;
   double   pd_low;
   double   pd_close;
   double   reference_open;
   double   trigger_open;
   double   trigger_high;
   double   trigger_low;
   double   trigger_close;
   double   day_extreme_high;
   double   day_extreme_low;
   int      direction;
  };

int      g_last_entry_day_key = -1;
ulong    g_tp1_done_tickets[128];
int      g_tp1_done_count = 0;
double   g_active_tp1_price = 0.0;
int      g_active_direction = 0;
int      g_active_day_key = -1;

ENUM_TIMEFRAMES Strategy_TF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf;
  }

void Strategy_ResetSetup(StrategyDaySetup &setup)
  {
   setup.day_key = -1;
   setup.reference_time = 0;
   setup.trigger_time = 0;
   setup.pd_high = 0.0;
   setup.pd_low = 0.0;
   setup.pd_close = 0.0;
   setup.reference_open = 0.0;
   setup.trigger_open = 0.0;
   setup.trigger_high = 0.0;
   setup.trigger_low = 0.0;
   setup.trigger_close = 0.0;
   setup.day_extreme_high = 0.0;
   setup.day_extreme_low = 0.0;
   setup.direction = 0;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_IsFridayLastH4BeforeClose(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   if(dt.day_of_week != 5)
      return false;

   int close_hour = qm_friday_close_hour_broker;
   if(close_hour < 0)
      close_hour = 0;
   if(close_hour > 23)
      close_hour = 23;
   return (dt.hour >= close_hour - 4);
  }

bool Strategy_HasTp1Done(const ulong ticket)
  {
   for(int i = 0; i < g_tp1_done_count; ++i)
      if(g_tp1_done_tickets[i] == ticket)
         return true;
   return false;
  }

void Strategy_MarkTp1Done(const ulong ticket)
  {
   if(ticket == 0 || Strategy_HasTp1Done(ticket))
      return;
   if(g_tp1_done_count >= 128)
      return;
   g_tp1_done_tickets[g_tp1_done_count] = ticket;
   g_tp1_done_count++;
  }

bool Strategy_SelectOpenPosition(ulong &ticket,
                                 ENUM_POSITION_TYPE &ptype,
                                 double &volume,
                                 double &open_price,
                                 datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   volume = 0.0;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
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

      ticket = pos_ticket;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int Strategy_CopyH4Rates(MqlRates &rates[])
  {
   ArrayResize(rates, 0);
   int bars_needed = strategy_atr_period * 4;
   if(bars_needed < 80)
      bars_needed = 80;
   const int copied = CopyRates(_Symbol, Strategy_TF(), 1, bars_needed, rates); // perf-allowed: bounded H4 structural envelope read; EntrySignal is called only after the framework QM_IsNewBar gate.
   return copied;
  }

bool Strategy_BuildDaySetup(StrategyDaySetup &setup)
  {
   Strategy_ResetSetup(setup);

   MqlRates rates[];
   const int copied = Strategy_CopyH4Rates(rates);
   if(copied < 12)
      return false;

   int trigger_idx = -1;
   datetime trigger_time = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time > trigger_time)
        {
         trigger_time = rates[i].time;
         trigger_idx = i;
        }
     }
   if(trigger_idx < 0 || trigger_time <= 0)
      return false;

   const int day_key = Strategy_DayKey(trigger_time);
   datetime reference_time = 0;
   int reference_idx = -1;
   int bars_into_day = 0;
   double day_high = -DBL_MAX;
   double day_low = DBL_MAX;

   for(int i = 0; i < copied; ++i)
     {
      if(Strategy_DayKey(rates[i].time) != day_key)
         continue;

      if(reference_time == 0 || rates[i].time < reference_time)
        {
         reference_time = rates[i].time;
         reference_idx = i;
        }

      if(rates[i].time <= trigger_time)
        {
         bars_into_day++;
         if(rates[i].high > day_high)
            day_high = rates[i].high;
         if(rates[i].low < day_low)
            day_low = rates[i].low;
        }
     }

   if(reference_idx < 0 || bars_into_day <= 0 || bars_into_day > strategy_return_window_h4_bars)
      return false;

   int prior_day_key = -1;
   for(int i = 0; i < copied; ++i)
     {
      const int key = Strategy_DayKey(rates[i].time);
      if(key < day_key && key > prior_day_key)
         prior_day_key = key;
     }
   if(prior_day_key < 0)
      return false;

   double pd_high = -DBL_MAX;
   double pd_low = DBL_MAX;
   double pd_close = 0.0;
   datetime pd_close_time = 0;
   int pd_bars = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(Strategy_DayKey(rates[i].time) != prior_day_key)
         continue;
      pd_bars++;
      if(rates[i].high > pd_high)
         pd_high = rates[i].high;
      if(rates[i].low < pd_low)
         pd_low = rates[i].low;
      if(rates[i].time > pd_close_time)
        {
         pd_close_time = rates[i].time;
         pd_close = rates[i].close;
        }
     }

   if(pd_bars <= 0 || pd_high <= 0.0 || pd_low <= 0.0 || pd_high <= pd_low || pd_close <= 0.0)
      return false;

   setup.day_key = day_key;
   setup.reference_time = reference_time;
   setup.trigger_time = trigger_time;
   setup.pd_high = pd_high;
   setup.pd_low = pd_low;
   setup.pd_close = pd_close;
   setup.reference_open = rates[reference_idx].open;
   setup.trigger_open = rates[trigger_idx].open;
   setup.trigger_high = rates[trigger_idx].high;
   setup.trigger_low = rates[trigger_idx].low;
   setup.trigger_close = rates[trigger_idx].close;
   setup.day_extreme_high = day_high;
   setup.day_extreme_low = day_low;

   if(setup.reference_open > pd_high && setup.trigger_low < pd_high)
      setup.direction = -1;
   else if(setup.reference_open < pd_low && setup.trigger_high > pd_low)
      setup.direction = 1;

   return (setup.direction != 0);
  }

bool Strategy_D1BiasAllows(const int direction)
  {
   const double sma_1 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1, PRICE_CLOSE);
   const double sma_2 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 2, PRICE_CLOSE);
   if(sma_1 <= 0.0 || sma_2 <= 0.0)
      return false;

   if(direction > 0)
      return (sma_1 >= sma_2);
   return (sma_1 <= sma_2);
  }

bool Strategy_NewsBlocksReference(const datetime reference_time)
  {
   if(!strategy_news_filter_enabled)
      return false;
   if(!QM_NewsIsAvailable())
      return false;

   datetime utc_time = QM_BrokerToUTC(reference_time);
   if(utc_time <= 0)
      utc_time = TimeGMT();

   int news_bars = strategy_news_window_h4_bars;
   if(news_bars < 0)
      news_bars = 0;
   const int minutes = news_bars * PeriodSeconds(PERIOD_H4) / 60;
   if(minutes <= 0)
      return false;

   return QM_NewsInWindow(utc_time, _Symbol, minutes, minutes, "HIGH");
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_atr_period <= 0 ||
      strategy_d1_sma_period <= 1 ||
      strategy_gap_min_d1_atr_mult < 0.0 ||
      strategy_gap_max_d1_atr_mult <= strategy_gap_min_d1_atr_mult ||
      strategy_return_window_h4_bars <= 0 ||
      strategy_return_window_h4_bars > 12 ||
      strategy_entry_slippage_atr < 0.0 ||
      strategy_sl_atr_mult <= 0.0 ||
      strategy_sl_cap_atr_mult <= 0.0 ||
      strategy_tp1_close_fraction <= 0.0 ||
      strategy_tp1_close_fraction >= 1.0 ||
      strategy_time_stop_bars <= 0 ||
      strategy_eod_close_hour_broker < 0 ||
      strategy_eod_close_hour_broker > 23)
      return true;

   if(Bars(_Symbol, Strategy_TF()) < 100 || Bars(_Symbol, PERIOD_D1) < strategy_d1_sma_period + strategy_atr_period + 5) // perf-allowed: O(1) warm-up availability check only.
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr_h4 = QM_ATR(_Symbol, Strategy_TF(), strategy_atr_period, 1);
   if(atr_h4 <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > (0.25 * atr_h4))
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

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time))
      return false;

   StrategyDaySetup setup;
   if(!Strategy_BuildDaySetup(setup))
      return false;
   if(setup.day_key == g_last_entry_day_key)
      return false;
   if(Strategy_IsFridayLastH4BeforeClose(setup.trigger_time))
      return false;
   if(Strategy_NewsBlocksReference(setup.reference_time))
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double atr_h4 = QM_ATR(_Symbol, Strategy_TF(), strategy_atr_period, 1);
   if(atr_d1 <= 0.0 || atr_h4 <= 0.0)
      return false;

   const double gap = MathAbs(setup.reference_open - setup.pd_close);
   if(gap < strategy_gap_min_d1_atr_mult * atr_d1)
      return false;
   if(gap > strategy_gap_max_d1_atr_mult * atr_d1)
      return false;

   if(setup.direction < 0 && setup.trigger_close >= setup.trigger_open)
      return false;
   if(setup.direction > 0 && setup.trigger_close <= setup.trigger_open)
      return false;
   if(!Strategy_D1BiasAllows(setup.direction))
      return false;

   const QM_OrderType side = (setup.direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (setup.direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double raw_sl = 0.0;
   if(setup.direction > 0)
     {
      raw_sl = MathMin(setup.day_extreme_low, setup.reference_open) - strategy_sl_atr_mult * atr_h4;
      const double capped = entry - strategy_sl_cap_atr_mult * atr_h4;
      if(raw_sl < capped)
         raw_sl = capped;
      if(raw_sl >= entry)
         raw_sl = entry - strategy_sl_atr_mult * atr_h4;
     }
   else
     {
      raw_sl = MathMax(setup.day_extreme_high, setup.reference_open) + strategy_sl_atr_mult * atr_h4;
      const double capped = entry + strategy_sl_cap_atr_mult * atr_h4;
      if(raw_sl > capped)
         raw_sl = capped;
      if(raw_sl <= entry)
         raw_sl = entry + strategy_sl_atr_mult * atr_h4;
     }

   const double tp2 = QM_StopRulesNormalizePrice(_Symbol, setup.pd_close);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(sl <= 0.0 || tp2 <= 0.0)
      return false;
   if(setup.direction > 0 && (sl >= entry || tp2 <= entry))
      return false;
   if(setup.direction < 0 && (sl <= entry || tp2 >= entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp2;
   req.reason = (setup.direction > 0) ? "TD_OPEN_GAP_DOWN_BUY_FADE" : "TD_OPEN_GAP_UP_SELL_FADE";

   g_active_tp1_price = QM_StopRulesNormalizePrice(_Symbol, (setup.reference_open + setup.pd_close) * 0.5);
   g_active_direction = setup.direction;
   g_active_day_key = setup.day_key;
   g_last_entry_day_key = setup.day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time))
      return;

   if(Strategy_HasTp1Done(ticket) || g_active_tp1_price <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0 || volume <= 0.0 || open_price <= 0.0)
      return;

   const bool hit_tp1 = is_buy ? (market >= g_active_tp1_price)
                               : (market <= g_active_tp1_price);
   if(!hit_tp1)
      return;

   const double lots_to_close = volume * strategy_tp1_close_fraction;
   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
     {
      Strategy_MarkTp1Done(ticket);
      QM_TM_MoveSL(ticket, open_price, "td_open_tp1_break_even");
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time))
      return false;

   const datetime now = TimeCurrent();
   if(open_time > 0)
     {
      const int stop_seconds = strategy_time_stop_bars * PeriodSeconds(Strategy_TF());
      if(stop_seconds > 0 && now - open_time >= stop_seconds)
         return true;

      if(Strategy_DayKey(now) != Strategy_DayKey(open_time))
         return true;
     }

   if(Strategy_HHMM(now) >= strategy_eod_close_hour_broker * 100)
      return true;

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
         const ulong close_ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(close_ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(close_ticket, QM_EXIT_STRATEGY);
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
