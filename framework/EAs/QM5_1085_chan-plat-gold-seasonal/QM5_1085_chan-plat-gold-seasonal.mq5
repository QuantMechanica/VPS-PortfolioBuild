#property strict
#property version   "5.0"
#property description "QM5_1085 Chan platinum-gold seasonal proxy"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1085;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_month       = 2;
input int    strategy_entry_day         = 26;
input int    strategy_exit_month        = 4;
input int    strategy_exit_day          = 19;
input int    strategy_spread_atr_period = 20;
input double strategy_spread_atr_mult   = 3.0;
input double strategy_xag_hedge_ratio   = 1.0;
input int    strategy_max_spread_points = 0;
input int    strategy_order_deviation_points = 20;

#define STRATEGY_LEG_COUNT 2

string g_leg_symbols[STRATEGY_LEG_COUNT] = {"XAUUSD.DWX", "XAGUSD.DWX"};
int    g_leg_slots[STRATEGY_LEG_COUNT]   = {0, 1};
int    g_leg_dirs[STRATEGY_LEG_COUNT]    = {1, -1};

bool Strategy_HasDwxSuffix(const string symbol)
  {
   return (StringFind(symbol, ".DWX") == StringLen(symbol) - 4);
  }

int Strategy_CurrentLegIndex()
  {
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
     {
      if(_Symbol == g_leg_symbols[i])
         return i;
     }
   return -1;
  }

bool Strategy_SymbolSlotAllowed()
  {
   const int idx = Strategy_CurrentLegIndex();
   return (idx >= 0 && qm_magic_slot_offset == g_leg_slots[idx]);
  }

bool Strategy_LegsDataAllowed()
  {
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
     {
      if(!Strategy_HasDwxSuffix(g_leg_symbols[i]))
         return false;
      SymbolSelect(g_leg_symbols[i], true);
      if(Bars(g_leg_symbols[i], PERIOD_D1) < strategy_spread_atr_period + 3)
         return false;
      if(strategy_max_spread_points > 0)
        {
         const long spread = SymbolInfoInteger(g_leg_symbols[i], SYMBOL_SPREAD);
         if(spread <= 0 || spread > strategy_max_spread_points)
            return false;
        }
     }
   return true;
  }

datetime Strategy_DateForYear(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   return StructToTime(dt);
  }

bool Strategy_CrossedDate(const datetime previous_bar, const datetime last_bar,
                          const int month, const int day)
  {
   if(previous_bar <= 0 || last_bar <= 0)
      return false;

   MqlDateTime last_dt;
   TimeToStruct(last_bar, last_dt);
   const datetime target = Strategy_DateForYear(last_dt.year, month, day);
   return (previous_bar < target && last_bar >= target);
  }

int Strategy_LastClosedBarYear()
  {
   const datetime last_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(last_bar <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(last_bar, dt);
   return dt.year;
  }

double Strategy_SpreadAtShift(const int shift)
  {
   const double xau = iClose(g_leg_symbols[0], PERIOD_D1, shift);
   const double xag = iClose(g_leg_symbols[1], PERIOD_D1, shift);
   if(xau <= 0.0 || xag <= 0.0)
      return EMPTY_VALUE;
   return xau - strategy_xag_hedge_ratio * xag;
  }

double Strategy_SpreadAtr()
  {
   const int n = MathMax(2, strategy_spread_atr_period);
   if(Bars(g_leg_symbols[0], PERIOD_D1) < n + 3 || Bars(g_leg_symbols[1], PERIOD_D1) < n + 3)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const double curr = Strategy_SpreadAtShift(shift);
      const double prev = Strategy_SpreadAtShift(shift + 1);
      if(curr == EMPTY_VALUE || prev == EMPTY_VALUE)
         return 0.0;
      sum += MathAbs(curr - prev);
      ++samples;
     }

   return (samples > 0) ? sum / (double)samples : 0.0;
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
     {
      if(symbol != g_leg_symbols[i])
         continue;
      const int magic = QM_MagicChecked(qm_ea_id, g_leg_slots[i], symbol);
      return ((int)PositionGetInteger(POSITION_MAGIC) == magic);
     }
   return false;
  }

int Strategy_OpenLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         ++count;
     }
   return count;
  }

double Strategy_OpenSpread()
  {
   double xau_open = 0.0;
   double xag_open = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(symbol == g_leg_symbols[0])
         xau_open = open_price;
      else if(symbol == g_leg_symbols[1])
         xag_open = open_price;
     }

   if(xau_open <= 0.0 || xag_open <= 0.0)
      return EMPTY_VALUE;
   return xau_open - strategy_xag_hedge_ratio * xag_open;
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_OpenLeg(const int leg_index)
  {
   const string symbol = g_leg_symbols[leg_index];
   const bool buy_leg = (g_leg_dirs[leg_index] > 0);
   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double spread_atr = Strategy_SpreadAtr();
   if(entry <= 0.0 || point <= 0.0 || spread_atr <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return false;

   const double stop_dist = spread_atr * strategy_spread_atr_mult;
   QM_BasketOrderRequest breq;
   breq.symbol = symbol;
   breq.type = buy_leg ? QM_BUY : QM_SELL;
   breq.price = 0.0;
   breq.sl = buy_leg ? entry - stop_dist : entry + stop_dist;
   breq.tp = 0.0;
   breq.lots = QM_LotsForRisk(symbol, stop_dist / point) / (double)STRATEGY_LEG_COUNT;
   breq.reason = "QM5_1085_CHAN_FEB26_APR19_PROXY";
   breq.symbol_slot = g_leg_slots[leg_index];
   breq.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                strategy_order_deviation_points,
                                breq,
                                ticket);
  }

bool Strategy_OpenPair()
  {
   if(Strategy_OpenLegCount() > 0)
      return false;

   bool opened = false;
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
     {
      if(Strategy_OpenLeg(i))
         opened = true;
     }
   return opened;
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(!Strategy_SymbolSlotAllowed())
      return true;
   if(!Strategy_LegsDataAllowed())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1085_BASKET_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime last_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime prev_bar = iTime(_Symbol, PERIOD_D1, 2);
   if(!Strategy_CrossedDate(prev_bar, last_bar, strategy_entry_month, strategy_entry_day))
      return false;
   if(Strategy_OpenLegCount() > 0)
      return false;

   Strategy_OpenPair();
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(Strategy_OpenLegCount() <= 0)
      return false;

   const datetime last_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime prev_bar = iTime(_Symbol, PERIOD_D1, 2);
   if(Strategy_CrossedDate(prev_bar, last_bar, strategy_exit_month, strategy_exit_day))
     {
      Strategy_ClosePair(QM_EXIT_TIME_STOP);
      return false;
     }

   const double open_spread = Strategy_OpenSpread();
   const double current_spread = Strategy_SpreadAtShift(1);
   const double spread_atr = Strategy_SpreadAtr();
   if(open_spread == EMPTY_VALUE || current_spread == EMPTY_VALUE || spread_atr <= 0.0)
      return false;

   const double stop_level = open_spread - strategy_spread_atr_mult * spread_atr;
   if(current_spread <= stop_level)
      Strategy_ClosePair(QM_EXIT_STRATEGY);

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
     {
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(g_leg_symbols[i], broker_time, qm_news_temporal, qm_news_compliance))
            return true;
        }
      else if(!QM_NewsAllowsTrade(g_leg_symbols[i], broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
      SymbolSelect(g_leg_symbols[i], true);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1085\",\"strategy\":\"chan-plat-gold-seasonal\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
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
