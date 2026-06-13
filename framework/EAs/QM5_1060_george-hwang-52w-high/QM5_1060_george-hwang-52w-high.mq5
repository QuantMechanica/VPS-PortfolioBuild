#property strict
#property version   "5.0"
#property description "QM5_1060 George-Hwang 52-Week-High Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1060;
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
input int    strategy_lookback_d1_bars     = 252;
input int    strategy_rank_slots_each_side = 2;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 4.0;
input double strategy_pullback_close_ratio = 0.85;
input double strategy_volatility_gate      = 0.03;
input int    strategy_spread_median_days   = 20;
input double strategy_spread_mult          = 3.0;

const int STRATEGY_UNIVERSE_SIZE = 11;
string g_universe_symbols[11] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX", "USDCAD.DWX",
   "USDCHF.DWX", "NZDUSD.DWX", "XAUUSD.DWX", "NDX.DWX", "WS30.DWX",
   "GDAXI.DWX"
  };
int g_universe_slots[11] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

int  g_month_key             = 0;
int  g_cached_rank_direction = 0;     // +1 top-2 long, -1 bottom-2 short, 0 not selected.
bool g_monthly_entry_due     = false;
bool g_monthly_close_due     = false;
bool g_pullback_close_due    = false;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_universe_slots[idx];
  }

int Strategy_CurrentMonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
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

int Strategy_OpenPositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return 1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

bool Strategy_Proximity(const string symbol, double &out_proximity)
  {
   out_proximity = 0.0;
   if(strategy_lookback_d1_bars <= 1)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;
   if(Bars(symbol, PERIOD_D1) < strategy_lookback_d1_bars + 5) // perf-allowed: D1 history guard for explicit basket inside D1 new-bar state advance.
      return false;

   const double close_value = iClose(symbol, PERIOD_D1, 1); // perf-allowed: card-defined 52w proximity, called only from D1 new-bar state advance.
   if(close_value <= 0.0)
      return false;

   double max_high = 0.0;
   for(int shift = 1; shift <= strategy_lookback_d1_bars; ++shift)
     {
      const double high_value = iHigh(symbol, PERIOD_D1, shift); // perf-allowed: bounded 252-bar high, called only from D1 new-bar state advance.
      if(high_value <= 0.0)
         continue;
      if(max_high <= 0.0 || high_value > max_high)
         max_high = high_value;
     }

   if(max_high <= 0.0)
      return false;

   out_proximity = close_value / max_high;
   return (out_proximity > 0.0);
  }

int Strategy_RankDirection()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[11];
   int indexes[11];
   int count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      double score = 0.0;
      if(!Strategy_Proximity(g_universe_symbols[i], score))
         continue;
      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   const int slots = MathMin(strategy_rank_slots_each_side, count / 2);
   if(slots <= 0)
      return 0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] < scores[i])
           {
            const double tmp_score = scores[i];
            scores[i] = scores[j];
            scores[j] = tmp_score;
            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }

   for(int i = 0; i < slots; ++i)
      if(indexes[i] == current_index)
         return -1;

   for(int i = count - slots; i < count; ++i)
      if(indexes[i] == current_index)
         return 1;

   return 0;
  }

double Strategy_MedianDailySpreadPoints()
  {
   const int n = strategy_spread_median_days;
   if(n <= 0 || n > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded monthly spread median; EntrySignal runs only after D1 state advance.
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_VolatilityAllowsEntry()
  {
   if(strategy_volatility_gate <= 0.0)
      return true;

   const double close_value = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed D1 close inside D1 new-bar entry path.
   if(close_value <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   return ((atr_value / close_value) <= strategy_volatility_gate);
  }

void Strategy_AdvanceStateOnD1Bar()
  {
   g_monthly_entry_due = false;
   g_monthly_close_due = false;
   g_pullback_close_due = false;

   const int current_month = Strategy_CurrentMonthKey();
   if(current_month != g_month_key)
     {
      g_month_key = current_month;
      g_monthly_close_due = Strategy_HasOpenPosition();
      g_cached_rank_direction = Strategy_RankDirection();
      g_monthly_entry_due = (g_cached_rank_direction != 0);
      return;
     }

   if(Strategy_OpenPositionDirection() > 0)
     {
      double proximity = 0.0;
      if(Strategy_Proximity(_Symbol, proximity))
         g_pullback_close_due = (proximity < strategy_pullback_close_ratio);
     }
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_rank_slots_each_side <= 0)
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

   if(!g_monthly_entry_due)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(!Strategy_VolatilityAllowsEntry())
      return false;

   const int direction = g_cached_rank_direction;
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1060_52WH_LONG_TOP2" : "QM5_1060_52WH_SHORT_BOTTOM2";
   g_monthly_entry_due = false;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies the initial 4x ATR stop only; no trailing, break-even, or partial close.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   return (g_monthly_close_due || g_pullback_close_due);
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

   QM_SymbolGuardInit(g_universe_symbols);
   QM_BasketWarmupHistory(g_universe_symbols, PERIOD_D1, strategy_lookback_d1_bars + 10);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1060\",\"ea\":\"george-hwang-52w-high\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();
   Strategy_AdvanceStateOnD1Bar();

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
