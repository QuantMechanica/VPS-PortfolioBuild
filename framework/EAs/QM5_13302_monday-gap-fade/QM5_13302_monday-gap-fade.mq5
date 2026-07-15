#property strict
#property version   "5.0"
#property description "QM5_13302 Regular-Session Monday Gap Fade"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13302;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;    // Wilder ATR(14) on D1 (Frozen Mechanics #2)
input double strategy_gap_threshold_atr   = 0.15;  // |Open - priorClose| >= 0.15 * priorATR14 (#4)
input double strategy_stop_atr_mult       = 0.75;  // initial stop distance = 0.75 * priorATR14 (#6)

// Frozen Mechanics #9: max one trade per carrier per Monday. Survives an
// EA restart mid-day because the key is the D1 calendar date, not a
// per-instance counter.
int g_qm_last_signal_day_key = 0;

int Strategy_DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

bool Strategy_HasOurOpenPosition()
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

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// Frozen Mechanics #3: the first Monday H1 bar must sit on a frozen regular
// broker session boundary, queried live via SymbolInfoSessionTrade -- never
// a hardcoded UTC hour. A missing or atypical boundary produces no trade.
bool Strategy_IsFrozenMondaySessionOpen(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   if(dt.day_of_week != MONDAY)
      return false;

   datetime session_from = 0;
   datetime session_to = 0;
   if(!SymbolInfoSessionTrade(_Symbol, MONDAY, 0, session_from, session_to))
      return false;

   MqlDateTime sdt;
   TimeToStruct(session_from, sdt);
   return (dt.hour == sdt.hour && dt.min == sdt.min);
  }

// Frozen Mechanics #2: signal row must be calendar-adjacent Friday->Monday,
// exactly three calendar days on the D1 series; holiday/export gaps are
// discarded. Returns the prior (Friday) D1 close and Wilder ATR(14).
bool Strategy_ReadPriorDayContext(double &out_prior_close, double &out_prior_atr)
  {
   out_prior_close = 0.0;
   out_prior_atr = 0.0;

   const datetime d1_current = iTime(_Symbol, PERIOD_D1, 0);
   const datetime d1_prior   = iTime(_Symbol, PERIOD_D1, 1);
   if(d1_current <= 0 || d1_prior <= 0)
      return false;

   if(Strategy_DayOfWeek(d1_current) != MONDAY || Strategy_DayOfWeek(d1_prior) != FRIDAY)
      return false;
   if(d1_current - d1_prior != 3 * 86400)
      return false;

   const double prior_close = iClose(_Symbol, PERIOD_D1, 1);
   const double prior_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(prior_close <= 0.0 || prior_atr <= 0.0)
      return false;

   out_prior_close = prior_close;
   out_prior_atr = prior_atr;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): framework handles news and Friday
   // close. Monday session timing and OHLC validity are card entry conditions
   // evaluated inline in Strategy_EntrySignal.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if(Strategy_HasOurOpenPosition())
      return false; // Frozen Mechanics #8/#9: no overnight/scaling/re-entry position

   const datetime current_bar_time = iTime(_Symbol, PERIOD_H1, 0);
   const datetime previous_bar_time = iTime(_Symbol, PERIOD_H1, 1);
   if(current_bar_time <= 0 || previous_bar_time <= 0)
      return false;

   const bool first_monday_bar = (Strategy_DayOfWeek(current_bar_time) == MONDAY &&
                                  Strategy_DayOfWeek(previous_bar_time) == FRIDAY);
   if(!first_monday_bar)
      return false;

   const int day_key = QM_CalendarPeriodKey(PERIOD_D1);
   if(day_key == 0 || day_key == g_qm_last_signal_day_key)
      return false; // Frozen Mechanics #9: max one trade per carrier per Monday

   if(!Strategy_IsFrozenMondaySessionOpen(current_bar_time))
      return false;

   const double open_price = iOpen(_Symbol, PERIOD_H1, 0);
   const double high_price = iHigh(_Symbol, PERIOD_H1, 0);
   const double low_price = iLow(_Symbol, PERIOD_H1, 0);
   const double close_price = iClose(_Symbol, PERIOD_H1, 0);
   if(open_price <= 0.0 || high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0)
      return false;
   if(high_price < low_price || open_price > high_price || open_price < low_price)
      return false; // Frozen Mechanics #3: OHLC-inconsistent boundary -> no trade

   double prior_close = 0.0;
   double prior_atr = 0.0;
   if(!Strategy_ReadPriorDayContext(prior_close, prior_atr))
      return false;

   const double gap = open_price - prior_close;
   const double gap_abs = MathAbs(gap);
   if(gap_abs < strategy_gap_threshold_atr * prior_atr)
      return false; // Frozen Mechanics #4

   int direction = 0;
   if(gap < 0.0)
      direction = 1;    // Open below prior close -> Long (Frozen Mechanics #5)
   else if(gap > 0.0)
      direction = -1;   // Open above prior close -> Short
   else
      return false;     // tie -> no signal

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   const double entry_price = (side == QM_BUY) ? ask : bid;

   const double stop_distance = strategy_stop_atr_mult * prior_atr;
   if(stop_distance <= 0.0)
      return false; // Frozen Mechanics #5: nonpositive stop distance -> no signal

   const double sl = QM_StopRulesStopFromDistance(_Symbol, side, entry_price, stop_distance);
   const double tp = QM_StopRulesNormalizePrice(_Symbol, prior_close);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   if(side == QM_BUY && tp <= entry_price)
      return false; // Frozen Mechanics #5: invalid geometry -> no signal
   if(side == QM_SELL && tp >= entry_price)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (direction > 0) ? "MONDAY_GAP_FADE_LONG" : "MONDAY_GAP_FADE_SHORT";

   g_qm_last_signal_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: card specifies no trailing, break-even, partial close,
   // pyramiding, or recovery. Stop/target are broker-native SL/TP set at entry
   // (Frozen Mechanics #7): the tester's Model 4 real-tick fill engine
   // resolves same-bar stop-before-target and conservative gap-through-target
   // booking natively -- not reimplemented here.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition())
      return false;

   const datetime current_bar_time = iTime(_Symbol, PERIOD_H1, 0);
   const datetime previous_bar_time = iTime(_Symbol, PERIOD_H1, 1);
   if(current_bar_time <= 0 || previous_bar_time <= 0)
      return false;

   // Frozen Mechanics #8: neither stop nor target hit -> exit at the last
   // available H1 close of the SAME broker day. Fires once, on the H1 bar
   // rollover out of Monday (no overnight/weekend hold).
   if(Strategy_DayOfWeek(previous_bar_time) == MONDAY && Strategy_DayOfWeek(current_bar_time) != MONDAY)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // FUNDED_STANDARD_MODE carrier-restricted-event blackout is delegated to
   // the framework's temporal/compliance news gate (qm_news_temporal /
   // qm_news_compliance) below, same as every other V5 EA.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13302\",\"strategy\":\"monday-gap-fade\"}");
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
