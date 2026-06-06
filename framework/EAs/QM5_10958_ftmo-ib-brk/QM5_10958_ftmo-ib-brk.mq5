#property strict
#property version   "5.0"
#property description "QM5_10958 FTMO Initial Balance Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10958;
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
input int    strategy_atr_period                 = 14;
input double strategy_ib_width_min_atr           = 0.6;
input double strategy_ib_width_max_atr           = 1.4;
input double strategy_sl_buffer_ib_mult          = 0.1;
input double strategy_tp1_be_ib_mult             = 1.0;
input double strategy_final_tp_ib_mult           = 1.5;
input double strategy_spread_stop_max_fraction   = 0.08;
input int    strategy_fx_ib_start_hhmm           = 900;
input int    strategy_fx_ib_end_hhmm             = 1000;
input int    strategy_fx_session_close_hhmm      = 1700;
input int    strategy_index_ib_start_hhmm        = 1530;
input int    strategy_index_ib_end_hhmm          = 1630;
input int    strategy_index_session_close_hhmm   = 2200;
input int    strategy_lookback_bars              = 96;
input int    strategy_news_post_breakout_minutes = 30;

int      g_session_day_key = 0;
bool     g_trade_taken_session = false;
datetime g_last_breakout_time = 0;
double   g_last_ib_width = 0.0;

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool IsCardSymbol()
  {
   return (_Symbol == "EURUSD.DWX" ||
           _Symbol == "GBPUSD.DWX" ||
           _Symbol == "NDX.DWX" ||
           _Symbol == "WS30.DWX");
  }

bool IsFxSessionSymbol()
  {
   return (_Symbol == "EURUSD.DWX" || _Symbol == "GBPUSD.DWX");
  }

void SessionTimes(int &ib_start, int &ib_end, int &session_close)
  {
   if(IsFxSessionSymbol())
     {
      ib_start = strategy_fx_ib_start_hhmm;
      ib_end = strategy_fx_ib_end_hhmm;
      session_close = strategy_fx_session_close_hhmm;
      return;
     }

   ib_start = strategy_index_ib_start_hhmm;
   ib_end = strategy_index_ib_end_hhmm;
   session_close = strategy_index_session_close_hhmm;
  }

void ResetSessionIfNeeded(const int day_key)
  {
   if(day_key == g_session_day_key)
      return;

   g_session_day_key = day_key;
   g_trade_taken_session = false;
   g_last_breakout_time = 0;
   g_last_ib_width = 0.0;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
  }

bool SelectOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ticket = t;
      return true;
     }

   return false;
  }

double NormalizedPrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(!IsCardSymbol())
      return true;

   if(HasOurOpenPosition())
      return false;

   int ib_start, ib_end, session_close;
   SessionTimes(ib_start, ib_end, session_close);
   const int now_hhmm = Hhmm(TimeCurrent());
   return (now_hhmm < ib_end || now_hhmm >= session_close);
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

   if(_Period != PERIOD_M15 || !IsCardSymbol())
      return false;

   const int lookback = MathMax(strategy_lookback_bars, 16);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: bounded structural IB scan, called only after the framework QM_IsNewBar gate.
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, lookback, rates);
   if(copied < 8)
      return false;

   const int closed_day_key = DateKey(rates[0].time);
   ResetSessionIfNeeded(closed_day_key);

   if(g_trade_taken_session || HasOurOpenPosition())
      return false;

   int ib_start, ib_end, session_close;
   SessionTimes(ib_start, ib_end, session_close);

   const int closed_hhmm = Hhmm(rates[0].time);
   if(closed_hhmm < ib_end || closed_hhmm >= session_close)
      return false;

   double ib_high = -DBL_MAX;
   double ib_low = DBL_MAX;
   int ib_bars = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(DateKey(rates[i].time) != closed_day_key)
         continue;
      const int bar_hhmm = Hhmm(rates[i].time);
      if(bar_hhmm < ib_start || bar_hhmm >= ib_end)
         continue;

      ib_high = MathMax(ib_high, rates[i].high);
      ib_low = MathMin(ib_low, rates[i].low);
      ib_bars++;
     }

   if(ib_bars < 3 || ib_high <= 0.0 || ib_low <= 0.0 || ib_high <= ib_low)
      return false;

   const double ib_width = ib_high - ib_low;
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false;

   if(ib_width < strategy_ib_width_min_atr * atr_h1 ||
      ib_width > strategy_ib_width_max_atr * atr_h1)
      return false;

   const double prev_close = (copied > 1) ? rates[1].close : 0.0;
   const double breakout_close = rates[0].close;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(prev_close <= 0.0 || breakout_close <= 0.0 || ask <= 0.0 || bid <= 0.0 || spread < 0.0)
      return false;

   if(breakout_close > ib_high && prev_close <= ib_high)
     {
      const double entry_price = ask;
      const double sl = ib_low - strategy_sl_buffer_ib_mult * ib_width;
      const double stop_distance = entry_price - sl;
      if(stop_distance <= 0.0 || spread > strategy_spread_stop_max_fraction * stop_distance)
         return false;

      req.type = QM_BUY;
      req.sl = NormalizedPrice(sl);
      req.tp = NormalizedPrice(entry_price + strategy_final_tp_ib_mult * ib_width);
      req.reason = "IB_BREAKOUT_LONG";
      g_trade_taken_session = true;
      g_last_breakout_time = rates[0].time + PeriodSeconds(PERIOD_M15);
      g_last_ib_width = ib_width;
      return true;
     }

   if(breakout_close < ib_low && prev_close >= ib_low)
     {
      const double entry_price = bid;
      const double sl = ib_high + strategy_sl_buffer_ib_mult * ib_width;
      const double stop_distance = sl - entry_price;
      if(stop_distance <= 0.0 || spread > strategy_spread_stop_max_fraction * stop_distance)
         return false;

      req.type = QM_SELL;
      req.sl = NormalizedPrice(sl);
      req.tp = NormalizedPrice(entry_price - strategy_final_tp_ib_mult * ib_width);
      req.reason = "IB_BREAKOUT_SHORT";
      g_trade_taken_session = true;
      g_last_breakout_time = rates[0].time + PeriodSeconds(PERIOD_M15);
      g_last_ib_width = ib_width;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   if(!SelectOurPosition(ticket))
      return;

   const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   if(open_price <= 0.0)
      return;

   double width = g_last_ib_width;
   if(width <= 0.0 && current_tp > 0.0 && strategy_final_tp_ib_mult > 0.0)
      width = MathAbs(current_tp - open_price) / strategy_final_tp_ib_mult;
   if(width <= 0.0)
      return;

   const double trigger_distance = strategy_tp1_be_ib_mult * width;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || trigger_distance <= 0.0)
      return;

   if(pos_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid >= open_price + trigger_distance &&
         (current_sl <= 0.0 || current_sl < open_price - point * 0.5))
         QM_TM_MoveSL(ticket, NormalizedPrice(open_price), "IB_TP1_BE");
      return;
     }

   if(pos_type == POSITION_TYPE_SELL)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= open_price - trigger_distance &&
         (current_sl <= 0.0 || current_sl > open_price + point * 0.5))
         QM_TM_MoveSL(ticket, NormalizedPrice(open_price), "IB_TP1_BE");
     }
  }

bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;

   int ib_start, ib_end, session_close;
   SessionTimes(ib_start, ib_end, session_close);
   return (Hhmm(TimeCurrent()) >= session_close);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(g_last_breakout_time <= 0 || strategy_news_post_breakout_minutes <= 0)
      return false;

   const datetime post_breakout_end = g_last_breakout_time + strategy_news_post_breakout_minutes * 60;
   if(broker_time > post_breakout_end)
      return false;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10958_ftmo_ib_brk\"}");
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
