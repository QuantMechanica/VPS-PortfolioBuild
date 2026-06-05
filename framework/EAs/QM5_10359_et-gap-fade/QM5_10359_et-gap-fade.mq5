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
input double strategy_gap_percent          = 0.006;
input int    strategy_inactive_stop_bars   = 15;
input double strategy_stop_gap_mult        = 1.25;
input double strategy_first_range_atr_max  = 0.8;
input int    strategy_atr_period           = 14;
input int    strategy_us_session_open_hhmm = 1630;
input int    strategy_eu_session_open_hhmm = 1000;
input int    strategy_entry_window_minutes = 10;
input int    strategy_min_stop_spreads     = 4;

// -----------------------------------------------------------------------------
// Strategy hooks - implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (time/spread/news no-trade layer).
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int now_minutes = dt.hour * 60 + dt.min;
   const bool is_eu_symbol = (StringFind(_Symbol, "GDAXI") >= 0 ||
                              StringFind(_Symbol, "GER40") >= 0 ||
                              StringFind(_Symbol, "DE30") >= 0 ||
                              StringFind(_Symbol, "UK100") >= 0);
   const int open_hhmm = is_eu_symbol ? strategy_eu_session_open_hhmm : strategy_us_session_open_hhmm;
   const int open_minutes = (open_hhmm / 100) * 60 + (open_hhmm % 100);
   return (now_minutes < open_minutes ||
           now_minutes > open_minutes + MathMax(0, strategy_entry_window_minutes));
  }

// Populate `req` with one first-bar stop entry when the opening gap qualifies.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_inactive_stop_bars) * PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   if(strategy_gap_percent <= 0.0 || strategy_inactive_stop_bars <= 0 ||
      strategy_stop_gap_mult <= 0.0 || strategy_atr_period <= 0)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int today_key = now_dt.year * 1000 + now_dt.day_of_year;
   static int traded_day_key = -1;
   if(traded_day_key == today_key)
      return false;

   const bool is_eu_symbol = (StringFind(_Symbol, "GDAXI") >= 0 ||
                              StringFind(_Symbol, "GER40") >= 0 ||
                              StringFind(_Symbol, "DE30") >= 0 ||
                              StringFind(_Symbol, "UK100") >= 0);
   const int open_hhmm = is_eu_symbol ? strategy_eu_session_open_hhmm : strategy_us_session_open_hhmm;

   // perf-allowed: opening-gap structure requires fixed closed-bar OHLC reads.
   const datetime first_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed
   if(first_bar_time <= 0)
      return false;

   MqlDateTime first_dt;
   TimeToStruct(first_bar_time, first_dt);
   const int first_hhmm = first_dt.hour * 100 + first_dt.min;
   if(first_hhmm != open_hhmm)
      return false;

   const double prev_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double prev_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed
   const double prev_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed
   const double session_open = iOpen(_Symbol, _Period, 1);  // perf-allowed
   const double first_high = iHigh(_Symbol, _Period, 1);    // perf-allowed
   const double first_low = iLow(_Symbol, _Period, 1);      // perf-allowed
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

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(ask <= 0.0 || bid <= 0.0 || spread <= 0.0)
      return false;

   const double stop_dist = strategy_stop_gap_mult * gap;
   if(stop_dist < MathMax(1, strategy_min_stop_spreads) * spread)
      return false;

   if(session_open > prev_high)
     {
      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(first_low, _Digits);
      req.sl = NormalizeDouble(req.price + stop_dist, _Digits);
      req.tp = NormalizeDouble(req.price - gap, _Digits);
      req.reason = "ET_GAP_UP_FADE_SELL_STOP";
      traded_day_key = today_key;
      return true;
     }

   if(session_open < prev_low)
     {
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(first_high, _Digits);
      req.sl = NormalizeDouble(req.price - stop_dist, _Digits);
      req.tp = NormalizeDouble(req.price + gap, _Digits);
      req.reason = "ET_GAP_DOWN_FADE_BUY_STOP";
      traded_day_key = today_key;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial exits.
  }

bool Strategy_ExitSignal()
  {
   const int hold_seconds = MathMax(1, strategy_inactive_stop_bars) * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
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

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
