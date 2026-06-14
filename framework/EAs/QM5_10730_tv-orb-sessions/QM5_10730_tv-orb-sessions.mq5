#property strict
#property version   "5.0"
#property description "QM5_10730 TradingView ORB Sessions Retest"

#include <QM/QM_Common.mqh>

enum StrategySessionModule
  {
   SESSION_ASIA = 0,
   SESSION_LONDON = 1,
   SESSION_NY = 2
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10730;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input StrategySessionModule strategy_session_module = SESSION_NY;
input int    strategy_or_minutes          = 15;
input int    strategy_asia_or_start_hhmm  = 100;
input int    strategy_london_or_start_hhmm = 900;
input int    strategy_ny_or_start_hhmm    = 1530;
input int    strategy_asia_session_end_hhmm = 900;
input int    strategy_london_session_end_hhmm = 1730;
input int    strategy_ny_session_end_hhmm = 2200;
input int    strategy_atr_period          = 14;
input double strategy_max_or_atr_mult     = 3.00;
input double strategy_tp1_close_fraction  = 0.50;
input double strategy_tp2_reward_risk     = 2.00;
input int    strategy_max_spread_points   = 0;

int    g_session_day_key = 0;
double g_or_high = 0.0;
double g_or_low = 0.0;
bool   g_or_has_range = false;
bool   g_or_locked = false;
bool   g_skip_session = false;
bool   g_trade_taken_session = false;
int    g_break_direction = 0;
int    g_bars_since_break = 0;
bool   g_tp1_done = false;

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
   minutes %= 24 * 60;
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

int SessionStartHhmm()
  {
   if(strategy_session_module == SESSION_ASIA)
      return strategy_asia_or_start_hhmm;
   if(strategy_session_module == SESSION_LONDON)
      return strategy_london_or_start_hhmm;
   return strategy_ny_or_start_hhmm;
  }

int SessionEndHhmm()
  {
   if(strategy_session_module == SESSION_ASIA)
      return strategy_asia_session_end_hhmm;
   if(strategy_session_module == SESSION_LONDON)
      return strategy_london_session_end_hhmm;
   return strategy_ny_session_end_hhmm;
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
   g_skip_session = false;
   g_trade_taken_session = false;
   g_break_direction = 0;
   g_bars_since_break = 0;
   g_tp1_done = false;
  }

void ResetSessionIfNeeded(const datetime broker_time)
  {
   const int day_key = BrokerDayKey(broker_time);
   if(g_session_day_key != day_key)
      ResetSessionState(day_key);
  }

bool ReadClosedBar(MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, 1, rates); // perf-allowed: closed-bar-gated ORB structural read.
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
   const int start_hhmm = SessionStartHhmm();
   const int end_hhmm = SessionEndHhmm();
   if(start_hhmm <= end_hhmm)
      return (now_hhmm >= end_hhmm);
   return (now_hhmm >= end_hhmm && now_hhmm < start_hhmm);
  }

bool SpreadTooWide()
  {
   if(strategy_max_spread_points <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask <= bid)
      return true;
   return ((ask - bid) / point > strategy_max_spread_points);
  }

void LockOpeningRangeIfReady(const int now_hhmm)
  {
   if(g_or_locked || !g_or_has_range || !HhmmInWindow(now_hhmm, OrEndHhmm(), SessionEndHhmm()))
      return;

   g_or_locked = true;
   const double width = g_or_high - g_or_low;
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(width <= 0.0 || atr <= 0.0)
      g_skip_session = true;
   else if(strategy_max_or_atr_mult > 0.0 && width > strategy_max_or_atr_mult * atr)
      g_skip_session = true;
  }

void AdvanceOpeningRangeState()
  {
   const datetime broker_now = TimeCurrent();
   ResetSessionIfNeeded(broker_now);

   MqlRates bar;
   if(!ReadClosedBar(bar) || BrokerDayKey(bar.time) != g_session_day_key)
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

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildMarketRequest(QM_EntryRequest &req, const int direction)
  {
   ResetEntryRequest(req);
   if(direction == 0 || g_or_high <= g_or_low)
      return false;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, (direction > 0) ? g_or_low : g_or_high);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp2_reward_risk);
   req.reason = (direction > 0) ? "ORB_SESSIONS_RETEST_LONG" : "ORB_SESSIONS_RETEST_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

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

   if(g_break_direction > 0)
     {
      g_bars_since_break++;
      if(g_bars_since_break >= 1 && bar.low <= g_or_high && bar.close > g_or_high)
         return BuildMarketRequest(req, 1);
      return false;
     }

   if(g_break_direction < 0)
     {
      g_bars_since_break++;
      if(g_bars_since_break >= 1 && bar.high >= g_or_low && bar.close < g_or_low)
         return BuildMarketRequest(req, -1);
      return false;
     }

   if(bar.close > g_or_high)
     {
      g_break_direction = 1;
      g_bars_since_break = 0;
   }
   else if(bar.close < g_or_low)
     {
      g_break_direction = -1;
      g_bars_since_break = 0;
   }
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   ResetSessionIfNeeded(TimeCurrent());

   if(HasOurPosition())
      return false;

   const int now_hhmm = BrokerHhmm(TimeCurrent());
   if(!HhmmInWindow(now_hhmm, SessionStartHhmm(), SessionEndHhmm()))
      return true;

   if(SpreadTooWide())
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);
   AdvanceOpeningRangeState();

   if(g_trade_taken_session || g_skip_session || !g_or_locked || SessionEndReached() || HasOurPosition())
      return false;

   if(RetestSignal(req))
     {
      g_trade_taken_session = true;
      g_break_direction = 0;
      g_tp1_done = false;
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(g_tp1_done || strategy_tp1_close_fraction <= 0.0)
      return;

   ulong ticket = 0;
   if(!SelectOurPosition(ticket))
     {
      g_tp1_done = false;
      return;
     }

   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl = PositionGetDouble(POSITION_SL);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(entry <= 0.0 || sl <= 0.0 || volume <= 0.0 || min_lot <= 0.0)
      return;

   const double risk = MathAbs(entry - sl);
   if(risk <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double trigger = is_buy ? (entry + risk) : (entry - risk);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   if((is_buy && market < trigger) || (!is_buy && market > trigger))
      return;

   const double close_lots = volume * MathMin(strategy_tp1_close_fraction, 1.0);
   if(close_lots < min_lot || volume - close_lots < min_lot)
     {
      g_tp1_done = true;
      return;
     }

   if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
      g_tp1_done = true;
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return (SessionEndReached() && HasOurPosition());
  }

// News Filter Hook
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
