#property strict
#property version   "5.0"
#property description "QM5_10359 Elite Trader opening gap fade"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10359;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_gap_percent         = 0.006;
input int    strategy_inactive_stop_bars  = 15;
input double strategy_stop_gap_mult       = 1.25;
input double strategy_first_range_atr_max = 0.8;
input int    strategy_atr_period          = 14;
input int    strategy_session_open_hhmm   = 1630;
input int    strategy_entry_window_minutes = 10;
input int    strategy_min_stop_spreads    = 4;

int g_last_day_key = -1;
bool g_trade_armed_today = false;

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int MinutesOfDayFromHhmm(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
  }

int MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool IsInEntryWindow(const datetime t)
  {
   const int now_min = MinutesOfDay(t);
   const int open_min = MinutesOfDayFromHhmm(strategy_session_open_hhmm);
   return (now_min >= open_min && now_min <= open_min + strategy_entry_window_minutes);
  }

void RefreshSessionState()
  {
   const int key = DayKey(TimeCurrent());
   if(key != g_last_day_key)
     {
      g_last_day_key = key;
      g_trade_armed_today = false;
     }
  }

bool HasOurPosition()
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

bool Strategy_NoTradeFilter()
  {
   RefreshSessionState();
   if(HasOurPosition())
      return false;
   return !IsInEntryWindow(TimeCurrent());
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_inactive_stop_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   RefreshSessionState();
   if(g_trade_armed_today || strategy_gap_percent <= 0.0 || strategy_inactive_stop_bars <= 0)
      return false;
   // perf-allowed: bespoke opening-gap structural reads (session-open time,
   // prior-day OHLC + first session-bar OHLC) at fixed closed-bar shift 1; no
   // QM_* reader exists for raw OHLC and the work is gated once-per-closed-bar
   // by QM_IsNewBar in OnTick.
   const datetime first_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: session-open time of last closed bar, single shift-1 read
   if(first_bar_time <= 0 || Hhmm(first_bar_time) != strategy_session_open_hhmm)
      return false;
   const double prev_close = iClose(_Symbol, PERIOD_D1, 1);    // perf-allowed
   const double prev_high = iHigh(_Symbol, PERIOD_D1, 1);      // perf-allowed
   const double prev_low = iLow(_Symbol, PERIOD_D1, 1);        // perf-allowed
   const double session_open = iOpen(_Symbol, _Period, 1);     // perf-allowed
   const double first_high = iHigh(_Symbol, _Period, 1);       // perf-allowed
   const double first_low = iLow(_Symbol, _Period, 1);         // perf-allowed
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(prev_close <= 0.0 || prev_high <= 0.0 || prev_low <= 0.0 ||
      session_open <= 0.0 || first_high <= 0.0 || first_low <= 0.0 || atr <= 0.0)
      return false;

   const double gap = MathAbs(prev_close - session_open);
   if(gap < prev_close * strategy_gap_percent)
      return false;

   const double first_range = first_high - first_low;
   if(first_range <= 0.0 || first_range > strategy_first_range_atr_max * atr)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || spread <= 0.0)
      return false;

   const double stop_dist = strategy_stop_gap_mult * gap;
   if(stop_dist < strategy_min_stop_spreads * spread)
      return false;

   if(session_open > prev_high)
     {
      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(first_low, _Digits);
      req.sl = NormalizeDouble(req.price + stop_dist, _Digits);
      req.tp = NormalizeDouble(req.price - gap, _Digits);
      req.reason = "ET_GAP_UP_FADE_SELL_STOP";
      g_trade_armed_today = true;
      return true;
     }

   if(session_open < prev_low)
     {
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(first_high, _Digits);
      req.sl = NormalizeDouble(req.price - stop_dist, _Digits);
      req.tp = NormalizeDouble(req.price + gap, _Digits);
      req.reason = "ET_GAP_DOWN_FADE_BUY_STOP";
      g_trade_armed_today = true;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int hold_seconds = strategy_inactive_stop_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(hold_seconds <= 0)
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
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && TimeCurrent() - opened >= hold_seconds)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10359_et-gap-fade\"}");
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
