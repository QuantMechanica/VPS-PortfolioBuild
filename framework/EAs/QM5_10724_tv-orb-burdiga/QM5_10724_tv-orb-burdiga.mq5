#property strict
#property version   "5.0"
#property description "QM5_10724 TradingView ORB Retest by Burdiga84"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10724;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_or_minutes          = 30;
input int    strategy_us_or_start_hhmm    = 1530;
input int    strategy_eu_or_start_hhmm    = 900;
input int    strategy_us_session_end_hhmm = 2200;
input int    strategy_eu_session_end_hhmm = 1730;
input int    strategy_min_bars_after_break = 1;
input int    strategy_setup_timeout_bars  = 20;
input int    strategy_atr_period          = 14;
input double strategy_min_or_atr_mult     = 0.40;
input double strategy_max_or_atr_mult     = 3.00;
input double strategy_reward_risk         = 1.50;
input double strategy_be_width_fraction   = 0.50;
input int    strategy_be_buffer_points    = 0;
input int    strategy_max_spread_points   = 0;

int    g_session_day_key = 0;
double g_or_high = 0.0;
double g_or_low = 0.0;
bool   g_or_has_range = false;
bool   g_or_locked = false;
bool   g_skip_day = false;
bool   g_trade_taken_today = false;
int    g_break_direction = 0;
int    g_bars_since_break = 0;

int HhmmToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

int MinutesToHhmm(int minutes)
  {
   while(minutes < 0)
      minutes += 24 * 60;
   minutes = minutes % (24 * 60);
   return (minutes / 60) * 100 + (minutes % 60);
  }

int HhmmAddMinutes(const int hhmm, const int add_minutes)
  {
   const int base = HhmmToMinutes(hhmm);
   if(base < 0)
      return hhmm;
   return MinutesToHhmm(base + add_minutes);
  }

int BrokerDayKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int BrokerHhmm(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 100 + dt.min;
  }

bool HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

bool IsEuSessionSymbol()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "UK100") >= 0);
  }

int SessionStartHhmm()
  {
   return IsEuSessionSymbol() ? strategy_eu_or_start_hhmm : strategy_us_or_start_hhmm;
  }

int SessionEndHhmm()
  {
   return IsEuSessionSymbol() ? strategy_eu_session_end_hhmm : strategy_us_session_end_hhmm;
  }

int OrEndHhmm()
  {
   return HhmmAddMinutes(SessionStartHhmm(), strategy_or_minutes);
  }

void ResetSessionState(const int day_key)
  {
   g_session_day_key = day_key;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_or_has_range = false;
   g_or_locked = false;
   g_skip_day = false;
   g_trade_taken_today = false;
   g_break_direction = 0;
   g_bars_since_break = 0;
  }

bool ReadClosedBar(MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, 1, rates); // perf-allowed: OR state advances only inside Strategy_EntrySignal after QM_IsNewBar().
   if(copied != 1)
      return false;
   bar = rates[0];
   return true;
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
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }
   return false;
  }

bool HasOurPosition()
  {
   ulong ticket = 0;
   return SelectOurPosition(ticket);
  }

bool SessionEndReached()
  {
   const int now_hhmm = BrokerHhmm(TimeCurrent());
   const int end_hhmm = SessionEndHhmm();
   const int start_hhmm = SessionStartHhmm();
   if(start_hhmm <= end_hhmm)
      return (now_hhmm >= end_hhmm);
   return (now_hhmm >= end_hhmm && now_hhmm < start_hhmm);
  }

void LockOpeningRangeIfReady(const int now_hhmm)
  {
   if(g_or_locked || !g_or_has_range || !HhmmInWindow(now_hhmm, OrEndHhmm(), SessionEndHhmm()))
      return;

   g_or_locked = true;
   const double width = g_or_high - g_or_low;
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(width <= 0.0 || atr <= 0.0 || width < strategy_min_or_atr_mult * atr || width > strategy_max_or_atr_mult * atr)
      g_skip_day = true;
  }

void AdvanceOrbState()
  {
   const datetime broker_now = TimeCurrent();
   const int today = BrokerDayKey(broker_now);
   if(g_session_day_key != today)
      ResetSessionState(today);

   MqlRates bar;
   if(!ReadClosedBar(bar) || BrokerDayKey(bar.time) != today)
      return;

   const int bar_hhmm = BrokerHhmm(bar.time);
   if(!g_or_locked && HhmmInWindow(bar_hhmm, SessionStartHhmm(), OrEndHhmm()))
     {
      if(!g_or_has_range)
        {
         g_or_high = bar.high;
         g_or_low = bar.low;
         g_or_has_range = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, bar.high);
         g_or_low = MathMin(g_or_low, bar.low);
        }
     }

   LockOpeningRangeIfReady(BrokerHhmm(broker_now));
  }

bool BuildMarketRequest(QM_EntryRequest &req, const int direction)
  {
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || g_or_high <= g_or_low)
      return false;

   req.sl = QM_StopRulesNormalizePrice(_Symbol, (direction > 0) ? g_or_low : g_or_high);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_reward_risk);
   req.reason = (direction > 0) ? "ORB_RETEST_LONG" : "ORB_RETEST_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(direction > 0 && !(req.sl < entry && req.tp > entry))
      return false;
   if(direction < 0 && !(req.sl > entry && req.tp < entry))
      return false;
   return true;
  }

bool RetestSignal(QM_EntryRequest &req)
  {
   MqlRates bar;
   if(!ReadClosedBar(bar))
      return false;

   const double midpoint = (g_or_high + g_or_low) * 0.5;
   if(g_break_direction > 0)
     {
      g_bars_since_break++;
      if(bar.low < midpoint || g_bars_since_break > strategy_setup_timeout_bars)
        {
         g_break_direction = 0;
         return false;
        }
      if(g_bars_since_break >= strategy_min_bars_after_break && bar.low <= g_or_high && bar.close > g_or_high)
         return BuildMarketRequest(req, 1);
      return false;
     }

   if(g_break_direction < 0)
     {
      g_bars_since_break++;
      if(bar.high > midpoint || g_bars_since_break > strategy_setup_timeout_bars)
        {
         g_break_direction = 0;
         return false;
        }
      if(g_bars_since_break >= strategy_min_bars_after_break && bar.high >= g_or_low && bar.close < g_or_low)
         return BuildMarketRequest(req, -1);
      return false;
     }

   if(bar.high > g_or_high)
     {
      g_break_direction = 1;
      g_bars_since_break = 0;
     }
   else if(bar.low < g_or_low)
     {
      g_break_direction = -1;
      g_bars_since_break = 0;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): news is handled by the framework and
   // Strategy_NewsFilterHook; this hook blocks new entries outside the session
   // and optionally during excessive spread while still allowing position exits.
   if(HasOurPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const int today = BrokerDayKey(broker_now);
   if(g_session_day_key != 0 && g_session_day_key != today)
      return false;

   const int now_hhmm = BrokerHhmm(broker_now);
   if(!HhmmInWindow(now_hhmm, SessionStartHhmm(), SessionEndHhmm()))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask > 0.0 && bid > 0.0 && point > 0.0 && ((ask - bid) / point) > strategy_max_spread_points)
         return true;
     }

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

   AdvanceOrbState();

   if(g_trade_taken_today || g_skip_day || !g_or_locked || SessionEndReached() || HasOurPosition())
      return false;

   if(RetestSignal(req))
     {
      g_trade_taken_today = true;
      g_break_direction = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: optional breakeven after unrealized profit reaches
   // 50% of the opening-range width, matching the card baseline.
   if(!g_or_locked || g_or_high <= g_or_low || strategy_be_width_fraction <= 0.0)
      return;

   ulong ticket = 0;
   if(!SelectOurPosition(ticket))
      return;

   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return;

   const double trigger = (g_or_high - g_or_low) * strategy_be_width_fraction;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double buffer = strategy_be_buffer_points * point;
   if(position_type == POSITION_TYPE_BUY && bid - entry >= trigger && current_sl < entry)
      QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, entry + buffer), "or_width_breakeven");
   if(position_type == POSITION_TYPE_SELL && entry - ask >= trigger && (current_sl > entry || current_sl <= 0.0))
      QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, entry - buffer), "or_width_breakeven");
  }

bool Strategy_ExitSignal()
  {
   // Trade Close: force flat at session end; SL/TP and Friday close are
   // handled by framework trade management and broker stops.
   return (SessionEndReached() && HasOurPosition());
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; defer to the framework axes.
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

