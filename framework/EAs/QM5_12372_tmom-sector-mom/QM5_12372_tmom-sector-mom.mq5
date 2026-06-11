#property strict
#property version   "5.0"
#property description "QM5_12372 ThewindMom Sector Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12372;
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
input int    strategy_lookback_returns       = 12;
input int    strategy_top_n                  = 3;
input bool   strategy_positive_momentum_gate = false;
input int    strategy_min_warmup_returns     = 17;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 2.0;
input double strategy_max_spread_points      = 0.0;

#define QM5_12372_SYMBOL_COUNT 4

string g_symbols[QM5_12372_SYMBOL_COUNT] =
  {
   "NDX.DWX", "WS30.DWX", "SP500.DWX", "GDAXI.DWX"
  };

int g_slots[QM5_12372_SYMBOL_COUNT] = {0, 1, 2, 3};

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_12372_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

bool Strategy_HasOpenPosition()
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

int Strategy_WeekKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + (dt.day_of_year / 7);
  }

bool Strategy_IsWeeklyRebalanceBar()
  {
   if(_Period != PERIOD_D1)
      return false;

   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: one D1 timestamp read for weekly basket rotation.
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one D1 timestamp read for weekly basket rotation.
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   return (Strategy_WeekKey(closed_bar) != Strategy_WeekKey(current_bar));
  }

bool Strategy_TrailingReturn(const string symbol, double &out_return)
  {
   out_return = 0.0;
   const int lookback = MathMax(1, strategy_lookback_returns);
   const int min_bars = MathMax(strategy_min_warmup_returns, lookback + 5) + 2;

   if(!QM_SymbolAssertOrLog(symbol))
      return false;
   SymbolSelect(symbol, true);
   if(Bars(symbol, PERIOD_D1) < min_bars) // perf-allowed: D1 basket warmup check inside closed-bar ranking.
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1); // perf-allowed: cumulative-return basket ranking on closed D1 bars.
   const double old_close = iClose(symbol, PERIOD_D1, lookback + 1); // perf-allowed: cumulative-return basket ranking on closed D1 bars.
   if(recent_close <= 0.0 || old_close <= 0.0)
      return false;

   out_return = (recent_close / old_close) - 1.0;
   return true;
  }

int Strategy_RankForCurrentSymbol(double &out_current_score)
  {
   out_current_score = 0.0;
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[QM5_12372_SYMBOL_COUNT];
   int indexes[QM5_12372_SYMBOL_COUNT];
   int count = 0;

   for(int i = 0; i < QM5_12372_SYMBOL_COUNT; ++i)
     {
      double score = 0.0;
      if(!Strategy_TrailingReturn(g_symbols[i], score))
         continue;
      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   const int needed = MathMin(QM5_12372_SYMBOL_COUNT, MathMax(1, strategy_top_n));
   if(count < needed)
      return 0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] > scores[i])
           {
            const double tmp_score = scores[i];
            scores[i] = scores[j];
            scores[j] = tmp_score;
            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }

   for(int rank = 0; rank < count; ++rank)
      if(indexes[rank] == current_index)
        {
         out_current_score = scores[rank];
         return rank + 1;
        }

   return 0;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= strategy_max_spread_points);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_lookback_returns <= 0 || strategy_top_n <= 0)
      return true;
   if(strategy_min_warmup_returns < strategy_lookback_returns + 5)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(!Strategy_IsWeeklyRebalanceBar())
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double current_score = 0.0;
   const int rank = Strategy_RankForCurrentSymbol(current_score);
   const int top_n = MathMin(QM5_12372_SYMBOL_COUNT, MathMax(1, strategy_top_n));
   if(rank <= 0 || rank > top_n)
      return false;
   if(strategy_positive_momentum_gate && current_score <= 0.0)
      return false;

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= entry_price)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.reason = "QM5_12372_TOPN_SECTOR_MOM_LONG";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card defines only the hard ATR stop; no trailing, partial, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return false;
   if(!Strategy_IsWeeklyRebalanceBar())
      return false;

   double current_score = 0.0;
   const int rank = Strategy_RankForCurrentSymbol(current_score);
   const int top_n = MathMin(QM5_12372_SYMBOL_COUNT, MathMax(1, strategy_top_n));
   if(rank <= 0 || rank > top_n)
      return true;
   if(strategy_positive_momentum_gate && current_score <= 0.0)
      return true;
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_min_warmup_returns + 5, strategy_lookback_returns + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12372\",\"ea\":\"tmom-sector-mom\"}");
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
