#property strict
#property version   "5.0"
#property description "QM5_10959 FTMO Market Profile 80 Percent Value Return"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10959;
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
input int    strategy_session_start_hour       = 16;
input int    strategy_session_start_minute     = 30;
input int    strategy_session_end_hour         = 23;
input int    strategy_session_end_minute       = 0;
input int    strategy_profile_lookback_bars    = 500;
input double strategy_value_area_fraction      = 0.70;
input int    strategy_atr_period               = 14;
input double strategy_min_va_width_atr_h1      = 1.0;
input double strategy_max_va_width_atr_h1      = 4.0;
input double strategy_stop_atr_cap_mult        = 1.20;
input int    strategy_confirm_blocks           = 2;
input double strategy_tp1_close_percent        = 50.0;
input int    strategy_be_buffer_points         = 0;
input int    strategy_max_spread_points        = 0;

struct MP80_Profile
  {
   double vah;
   double val;
   double poc;
   double high;
   double low;
   int    session_key;
   bool   ok;
  };

struct MP80_CurrentSession
  {
   int    session_key;
   double session_open;
   double long_stop_low;
   double short_stop_high;
   int    long_confirms;
   int    short_confirms;
   bool   ok;
  };

int    g_attempt_session_key = 0;
int    g_active_session_key = 0;
double g_active_poc = 0.0;
bool   g_tp1_done = false;

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_SessionStartMinutes()
  {
   return strategy_session_start_hour * 60 + strategy_session_start_minute;
  }

int Strategy_SessionEndMinutes()
  {
   return strategy_session_end_hour * 60 + strategy_session_end_minute;
  }

bool Strategy_IsInRegularSession(const datetime t)
  {
   const int start_min = Strategy_SessionStartMinutes();
   const int end_min = Strategy_SessionEndMinutes();
   const int minute = Strategy_MinutesOfDay(t);
   if(start_min == end_min)
      return true;
   if(start_min < end_min)
      return (minute >= start_min && minute < end_min);
   return (minute >= start_min || minute < end_min);
  }

int Strategy_SessionKey(const datetime t)
  {
   const int start_min = Strategy_SessionStartMinutes();
   const int end_min = Strategy_SessionEndMinutes();
   const int minute = Strategy_MinutesOfDay(t);
   datetime session_date = t;
   if(start_min > end_min && minute < end_min)
      session_date = t - 86400;
   return Strategy_DateKey(session_date);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
  }

int Strategy_FindPreviousSessionKey(const MqlRates &rates[], const int count, const int current_key)
  {
   int previous_key = 0;
   for(int i = 0; i < count; ++i)
     {
      if(!Strategy_IsInRegularSession(rates[i].time))
         continue;
      const int key = Strategy_SessionKey(rates[i].time);
      if(key < current_key && key > previous_key)
         previous_key = key;
     }
   return previous_key;
  }

bool Strategy_BuildProfile(const MqlRates &rates[], const int count, const int profile_key, MP80_Profile &profile)
  {
   profile.ok = false;
   profile.vah = 0.0;
   profile.val = 0.0;
   profile.poc = 0.0;
   profile.high = 0.0;
   profile.low = 0.0;
   profile.session_key = profile_key;

   bool have = false;
   long best_volume = -1;
   double best_tpo_price = 0.0;
   for(int i = 0; i < count; ++i)
     {
      if(!Strategy_IsInRegularSession(rates[i].time))
         continue;
      if(Strategy_SessionKey(rates[i].time) != profile_key)
         continue;

      if(!have)
        {
         profile.high = rates[i].high;
         profile.low = rates[i].low;
         have = true;
        }
      else
        {
         if(rates[i].high > profile.high)
            profile.high = rates[i].high;
         if(rates[i].low < profile.low)
            profile.low = rates[i].low;
        }

      if(rates[i].tick_volume > best_volume)
        {
         best_volume = rates[i].tick_volume;
         best_tpo_price = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
        }
     }

   if(!have || profile.high <= profile.low || best_tpo_price <= 0.0)
      return false;

   const double range = profile.high - profile.low;
   double width = range * strategy_value_area_fraction;
   if(width <= 0.0 || strategy_value_area_fraction <= 0.0 || strategy_value_area_fraction > 1.0)
      return false;

   profile.poc = MathMax(profile.low, MathMin(profile.high, best_tpo_price));
   profile.val = profile.poc - width * 0.5;
   profile.vah = profile.poc + width * 0.5;

   if(profile.val < profile.low)
     {
      profile.vah += (profile.low - profile.val);
      profile.val = profile.low;
     }
   if(profile.vah > profile.high)
     {
      profile.val -= (profile.vah - profile.high);
      profile.vah = profile.high;
     }

   profile.val = MathMax(profile.low, profile.val);
   profile.vah = MathMin(profile.high, profile.vah);
   profile.ok = (profile.vah > profile.val && profile.poc > profile.val && profile.poc < profile.vah);
   return profile.ok;
  }

bool Strategy_BuildCurrentSession(const MqlRates &rates[], const int count, const int current_key,
                                  const MP80_Profile &profile, MP80_CurrentSession &state)
  {
   state.ok = false;
   state.session_key = current_key;
   state.session_open = 0.0;
   state.long_stop_low = 0.0;
   state.short_stop_high = 0.0;
   state.long_confirms = 0;
   state.short_confirms = 0;

   bool have_session_bar = false;
   bool long_reentered = false;
   bool short_reentered = false;

   for(int i = count - 1; i >= 0; --i)
     {
      if(!Strategy_IsInRegularSession(rates[i].time))
         continue;
      if(Strategy_SessionKey(rates[i].time) != current_key)
         continue;

      if(!have_session_bar)
        {
         state.session_open = rates[i].open;
         have_session_bar = true;
        }

      if(rates[i].close > profile.val)
        {
         if(!long_reentered)
           {
            state.long_stop_low = rates[i].low;
            long_reentered = true;
            state.long_confirms = 1;
           }
         else
           {
            if(rates[i].low < state.long_stop_low)
               state.long_stop_low = rates[i].low;
            state.long_confirms++;
           }
        }
      else
        {
         long_reentered = false;
         state.long_confirms = 0;
         state.long_stop_low = 0.0;
        }

      if(rates[i].close < profile.vah)
        {
         if(!short_reentered)
           {
            state.short_stop_high = rates[i].high;
            short_reentered = true;
            state.short_confirms = 1;
           }
         else
           {
            if(rates[i].high > state.short_stop_high)
               state.short_stop_high = rates[i].high;
            state.short_confirms++;
           }
        }
      else
        {
         short_reentered = false;
         state.short_confirms = 0;
         state.short_stop_high = 0.0;
        }
     }

   state.ok = have_session_bar;
   return state.ok;
  }

bool Strategy_LoadSessionData(MP80_Profile &profile, MP80_CurrentSession &state)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int requested = MathMax(strategy_profile_lookback_bars, 120);
   const int copied = CopyRates(_Symbol, PERIOD_M30, 1, requested, rates); // perf-allowed: closed-bar session profile snapshot
   if(copied < 80)
      return false;

   if(!Strategy_IsInRegularSession(rates[0].time))
      return false;

   const int current_key = Strategy_SessionKey(rates[0].time);
   const int previous_key = Strategy_FindPreviousSessionKey(rates, copied, current_key);
   if(previous_key <= 0)
      return false;

   if(!Strategy_BuildProfile(rates, copied, previous_key, profile))
      return false;
   if(!Strategy_BuildCurrentSession(rates, copied, current_key, profile, state))
      return false;

   return true;
  }

double Strategy_NormalizedPrice(const double price)
  {
   return NormalizeDouble(price, _Digits);
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): news is handled by framework and hook.
   if(Strategy_HasOpenPosition())
      return false;

   const datetime now = TimeCurrent();
   if(!Strategy_IsInRegularSession(now))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(point <= 0.0 || bid <= 0.0 || ask <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: previous-session value-area return with two M30 confirmations.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   MP80_Profile profile;
   MP80_CurrentSession state;
   if(!Strategy_LoadSessionData(profile, state))
      return false;

   if(g_attempt_session_key == state.session_key)
      return false;

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double atr_m30 = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   if(atr_h1 <= 0.0 || atr_m30 <= 0.0)
      return false;

   const double va_width = profile.vah - profile.val;
   if(va_width < strategy_min_va_width_atr_h1 * atr_h1 ||
      va_width > strategy_max_va_width_atr_h1 * atr_h1)
      return false;

   const int confirms_required = MathMax(1, strategy_confirm_blocks);
   const double cap_distance = strategy_stop_atr_cap_mult * atr_m30;

   if(state.session_open < profile.val && state.long_confirms >= confirms_required)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0 || profile.vah <= entry || profile.poc <= entry)
         return false;

      double sl = state.long_stop_low;
      if(sl <= 0.0 || entry - sl > cap_distance)
         sl = entry - cap_distance;
      sl = Strategy_NormalizedPrice(sl);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = Strategy_NormalizedPrice(profile.vah);
      req.reason = "FTMO_MP80_LONG";
      g_attempt_session_key = state.session_key;
      g_active_session_key = state.session_key;
      g_active_poc = Strategy_NormalizedPrice(profile.poc);
      g_tp1_done = false;
      return true;
     }

   if(state.session_open > profile.vah && state.short_confirms >= confirms_required)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0 || profile.val >= entry || profile.poc >= entry)
         return false;

      double sl = state.short_stop_high;
      if(sl <= 0.0 || sl - entry > cap_distance)
         sl = entry + cap_distance;
      sl = Strategy_NormalizedPrice(sl);
      if(sl <= entry)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = Strategy_NormalizedPrice(profile.val);
      req.reason = "FTMO_MP80_SHORT";
      g_attempt_session_key = state.session_key;
      g_active_session_key = state.session_key;
      g_active_poc = Strategy_NormalizedPrice(profile.poc);
      g_tp1_done = false;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: TP1 at POC, then move stop to breakeven.
   if(g_tp1_done || g_active_poc <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0 || open_price <= 0.0)
         continue;

      const bool touched_poc = is_buy ? (market >= g_active_poc) : (market <= g_active_poc);
      if(!touched_poc)
         continue;

      if(strategy_tp1_close_percent > 0.0 && strategy_tp1_close_percent < 100.0 && volume > 0.0)
         QM_TM_PartialClose(ticket, volume * strategy_tp1_close_percent / 100.0, QM_EXIT_STRATEGY);

      const double be = is_buy ? open_price + strategy_be_buffer_points * point
                               : open_price - strategy_be_buffer_points * point;
      QM_TM_MoveSL(ticket, Strategy_NormalizedPrice(be), "FTMO_MP80_TP1_BE");
      g_tp1_done = true;
     }
  }

bool Strategy_ExitSignal()
  {
   // Trade Close: close any remaining position at the regular-session end.
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime now = TimeCurrent();
   if(g_active_session_key > 0 && Strategy_SessionKey(now) != g_active_session_key)
      return true;

   const int start_min = Strategy_SessionStartMinutes();
   const int end_min = Strategy_SessionEndMinutes();
   const int minute = Strategy_MinutesOfDay(now);
   if(start_min < end_min && minute >= end_min)
      return true;
   if(start_min > end_min && minute >= end_min && minute < start_min)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: defer high-impact macro release windows to V5 news filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10959_ftmo-mp-80\"}");
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
