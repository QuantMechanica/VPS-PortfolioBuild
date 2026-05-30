#property strict
#property version   "5.0"
#property description "QM5_1191 Quantpedia Pair Switch SP500 Gold"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1191;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_months    = 3;
input int    strategy_rebalance_months   = 1;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_stale_exit_days    = 70;
input int    strategy_min_monthly_bars   = 8;
input double strategy_spread_median_mult = 3.0;
input int    strategy_spread_warmup_days = 20;
input int    strategy_max_spread_points  = 0;

#define QM5_1191_SYMBOL_COUNT 2
#define QM5_1191_SPREAD_WINDOW 20

string g_symbols[QM5_1191_SYMBOL_COUNT] = {"SP500.DWX", "XAUUSD.DWX"};

datetime g_last_seen_d1_bar = 0;
int      g_spread_count = 0;
int      g_spread_index = 0;
double   g_spread_points[QM5_1191_SPREAD_WINDOW];
int      g_last_entry_key = 0;
int      g_last_exit_key = 0;

int Strategy_MonthKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_CurrentSymbolSlot()
  {
   for(int i = 0; i < QM5_1191_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_SelectSymbols()
  {
   bool ok = true;
   for(int i = 0; i < QM5_1191_SYMBOL_COUNT; ++i)
      ok = (SymbolSelect(g_symbols[i], true) && ok);
   return ok;
  }

bool Strategy_IsQuarterStartMonth(const int month)
  {
   return (month == 1 || month == 4 || month == 7 || month == 10);
  }

bool Strategy_IsRebalanceEvent(datetime &signal_day, int &rebalance_key)
  {
   signal_day = 0;
   rebalance_key = 0;

   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prior_day = iTime(_Symbol, PERIOD_D1, 1);
   if(current_day <= 0 || prior_day <= 0)
      return false;

   const int current_key = Strategy_MonthKey(current_day);
   const int prior_key = Strategy_MonthKey(prior_day);
   if(current_key <= 0 || prior_key <= 0 || current_key == prior_key)
      return false;

   MqlDateTime dt;
   TimeToStruct(current_day, dt);
   const int interval = MathMax(1, strategy_rebalance_months);
   if(interval >= 3 && !Strategy_IsQuarterStartMonth(dt.mon))
      return false;

   signal_day = prior_day;
   rebalance_key = current_key;
   return true;
  }

bool Strategy_TrailingReturn(const string symbol, double &ret)
  {
   ret = 0.0;
   if(!SymbolSelect(symbol, true))
      return false;

   const int lookback = MathMax(1, strategy_lookback_months);
   const int required = MathMax(strategy_min_monthly_bars, lookback + 2);
   if(iBars(symbol, PERIOD_MN1) < required)
      return false;

   const double last_close = iClose(symbol, PERIOD_MN1, 1);
   const double prior_close = iClose(symbol, PERIOD_MN1, 1 + lookback);
   if(last_close <= 0.0 || prior_close <= 0.0)
      return false;

   ret = (last_close / prior_close) - 1.0;
   return MathIsValidNumber(ret);
  }

int Strategy_WinningSlot()
  {
   double spx_return = 0.0;
   double gold_return = 0.0;
   if(!Strategy_TrailingReturn(g_symbols[0], spx_return))
      return -1;
   if(!Strategy_TrailingReturn(g_symbols[1], gold_return))
      return -1;

   const double eps = 0.00000001;
   if(MathAbs(spx_return - gold_return) <= eps)
      return -1;
   return (spx_return > gold_return) ? 0 : 1;
  }

void Strategy_UpdateSpreadSample()
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_D1, 0);
   if(bar_time <= 0 || bar_time == g_last_seen_d1_bar)
      return;

   g_last_seen_d1_bar = bar_time;
   g_spread_points[g_spread_index] = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_spread_index = (g_spread_index + 1) % QM5_1191_SPREAD_WINDOW;
   if(g_spread_count < QM5_1191_SPREAD_WINDOW)
      ++g_spread_count;
  }

double Strategy_MedianSpread()
  {
   if(g_spread_count <= 0)
      return 0.0;

   double sample[QM5_1191_SPREAD_WINDOW];
   for(int i = 0; i < g_spread_count; ++i)
      sample[i] = g_spread_points[i];

   for(int i = 0; i < g_spread_count - 1; ++i)
     {
      for(int j = i + 1; j < g_spread_count; ++j)
        {
         if(sample[j] < sample[i])
           {
            const double tmp = sample[i];
            sample[i] = sample[j];
            sample[j] = tmp;
           }
        }
     }

   const int mid = g_spread_count / 2;
   if((g_spread_count % 2) == 1)
      return sample[mid];
   return (sample[mid - 1] + sample[mid]) * 0.5;
  }

bool Strategy_SpreadAllowed()
  {
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && current_spread > strategy_max_spread_points)
      return false;

   const int warmup = MathMin(QM5_1191_SPREAD_WINDOW, MathMax(1, strategy_spread_warmup_days));
   if(strategy_spread_median_mult <= 0.0 || g_spread_count < warmup)
      return true;

   const double median = Strategy_MedianSpread();
   if(median <= 0.0)
      return true;
   return ((double)current_spread <= median * strategy_spread_median_mult);
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at, double &entry_price)
  {
   ticket = 0;
   opened_at = 0;
   entry_price = 0.0;

   const int slot = Strategy_CurrentSymbolSlot();
   if(slot < 0)
      return false;
   const int magic = QM_Magic(qm_ea_id, slot);
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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      return true;
     }

   return false;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   Strategy_UpdateSpreadSample();

   const int slot = Strategy_CurrentSymbolSlot();
   if(slot < 0)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != slot)
      return true;
   if(strategy_lookback_months <= 0 || strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_stale_exit_days <= 0)
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1191_PAIR_SWITCH_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime signal_day = 0;
   int rebalance_key = 0;
   if(!Strategy_IsRebalanceEvent(signal_day, rebalance_key) || g_last_entry_key == rebalance_key)
      return false;

   const int current_slot = Strategy_CurrentSymbolSlot();
   const int winning_slot = Strategy_WinningSlot();
   if(current_slot < 0 || winning_slot != current_slot)
     {
      g_last_entry_key = rebalance_key;
      return false;
     }

   ulong ticket = 0;
   datetime opened_at = 0;
   double entry_price = 0.0;
   if(Strategy_HasOpenPosition(ticket, opened_at, entry_price))
     {
      g_last_entry_key = rebalance_key;
      return false;
     }
   if(!Strategy_SpreadAllowed())
     {
      g_last_entry_key = rebalance_key;
      return false;
     }

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
     {
      g_last_entry_key = rebalance_key;
      return false;
     }

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   req.symbol_slot = current_slot;
   g_last_entry_key = rebalance_key;
   return Strategy_StopDistanceAllowed(entry, req.sl);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies an initial ATR stop plus rebalance and stale-position exits.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   double entry_price = 0.0;
   if(!Strategy_HasOpenPosition(ticket, opened_at, entry_price))
      return false;

   if(TimeCurrent() - opened_at >= (datetime)(strategy_stale_exit_days * 86400))
      return true;

   datetime signal_day = 0;
   int rebalance_key = 0;
   if(!Strategy_IsRebalanceEvent(signal_day, rebalance_key) || g_last_exit_key == rebalance_key)
      return false;
   if(opened_at >= signal_day)
      return false;

   g_last_exit_key = rebalance_key;
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   Strategy_SelectSymbols();

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1191\",\"strategy\":\"qp-pair-switch-spx-gold\"}");
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
      const int magic = QM_Magic(qm_ea_id, Strategy_CurrentSymbolSlot());
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
