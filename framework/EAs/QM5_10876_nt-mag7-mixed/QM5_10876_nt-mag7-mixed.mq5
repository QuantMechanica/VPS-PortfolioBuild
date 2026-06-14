#property strict
#property version   "5.0"
#property description "QM5_10876 NexusTrade MAG7 mixed-condition monthly rebalance"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy card: QM5_10876 nt-mag7-mixed, G0 APPROVED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10876;
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
input int    strategy_sma_period             = 30;
input int    strategy_low_lookback_d1_bars   = 252;
input double strategy_low_distance_mult      = 1.05;
input int    strategy_rsi_period             = 14;
input double strategy_rsi_threshold          = 28.0;
input double strategy_proxy_rsi_threshold    = 33.0;
input int    strategy_atr_period             = 20;
input double strategy_atr_sl_mult            = 3.0;
input int    strategy_min_history_d1_bars    = 260;
input int    strategy_max_spread_points      = 0;
input bool   strategy_enable_profit_take     = false;
input double strategy_profit_take_pct        = 25.0;

#define STRATEGY_SYMBOL_COUNT 3

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] = {"SP500.DWX", "NDX.DWX", "WS30.DWX"};
int    g_strategy_slots[STRATEGY_SYMBOL_COUNT]   = {0, 1, 2};
int    g_last_entry_rebalance_key = 0;
int    g_last_exit_rebalance_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
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

int Strategy_CurrentMonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_FirstD1BarOfMonthKey()
  {
   datetime current_bar[1];
   datetime previous_bar[1];
   if(CopyTime(_Symbol, PERIOD_D1, 0, 1, current_bar) != 1) // perf-allowed: one schedule read inside closed-bar entry gate.
      return 0;
   if(CopyTime(_Symbol, PERIOD_D1, 1, 1, previous_bar) != 1) // perf-allowed: one schedule read inside closed-bar entry gate.
      return 0;

   MqlDateTime cur_dt;
   MqlDateTime prev_dt;
   TimeToStruct(current_bar[0], cur_dt);
   TimeToStruct(previous_bar[0], prev_dt);
   if(cur_dt.year == prev_dt.year && cur_dt.mon == prev_dt.mon)
      return 0;

   return cur_dt.year * 100 + cur_dt.mon;
  }

double Strategy_LastClosedClose(const string symbol)
  {
   double close_values[1];
   if(CopyClose(symbol, PERIOD_D1, 1, 1, close_values) != 1) // perf-allowed: one closed close on monthly rebalance decision.
      return 0.0;
   return close_values[0];
  }

double Strategy_LowestClosedLow(const string symbol, const int lookback_bars)
  {
   if(lookback_bars <= 0)
      return 0.0;

   double lows[];
   ArrayResize(lows, lookback_bars);
   const int copied = CopyLow(symbol, PERIOD_D1, 1, lookback_bars, lows); // perf-allowed: fixed 252-bar low scan only on monthly rebalance decisions.
   if(copied < lookback_bars)
      return 0.0;

   double lowest = DBL_MAX;
   for(int i = 0; i < copied; ++i)
      if(lows[i] > 0.0 && lows[i] < lowest)
         lowest = lows[i];

   if(lowest >= DBL_MAX)
      return 0.0;
   return lowest;
  }

string Strategy_MarketProxySymbol()
  {
   if(_Symbol == "SP500.DWX")
      return _Symbol;
   return "SP500.DWX";
  }

bool Strategy_Eligible()
  {
   if(strategy_sma_period <= 0 ||
      strategy_low_lookback_d1_bars <= 0 ||
      strategy_rsi_period <= 0 ||
      strategy_low_distance_mult <= 0.0)
      return false;

   const int warmup_bars = MathMax(strategy_min_history_d1_bars,
                                   MathMax(strategy_low_lookback_d1_bars,
                                           MathMax(strategy_sma_period, strategy_rsi_period)));
   double warmup_check[1];
   if(CopyClose(_Symbol, PERIOD_D1, warmup_bars, 1, warmup_check) != 1) // perf-allowed: warmup availability check on monthly rebalance decisions.
      return false;

   const double close_last = Strategy_LastClosedClose(_Symbol);
   const double sma30 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double low52 = Strategy_LowestClosedLow(_Symbol, strategy_low_lookback_d1_bars);
   const double rsi14 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   const string proxy_symbol = Strategy_MarketProxySymbol();
   const double proxy_rsi14 = QM_RSI(proxy_symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);

   if(close_last <= 0.0 || sma30 <= 0.0 || low52 <= 0.0 || rsi14 <= 0.0 || proxy_rsi14 <= 0.0)
      return false;

   int count_true = 0;
   if(close_last > sma30)
      count_true++;
   if(close_last <= strategy_low_distance_mult * low52)
      count_true++;
   if(rsi14 < strategy_rsi_threshold && proxy_rsi14 > strategy_proxy_rsi_threshold)
      count_true++;

   return (count_true >= 1 && count_true <= 2);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   const int symbol_idx = Strategy_CurrentSymbolIndex();
   if(symbol_idx < 0)
      return true;

   if(g_strategy_slots[symbol_idx] != qm_magic_slot_offset)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10876_MONTHLY_MIXED_CONDITIONS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int rebalance_key = Strategy_FirstD1BarOfMonthKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_Eligible())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!strategy_enable_profit_take || strategy_profit_take_pct <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(open_price <= 0.0 || bid <= 0.0)
         continue;

      const double return_pct = 100.0 * (bid - open_price) / open_price;
      if(return_pct >= strategy_profit_take_pct)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.day > 7)
      return false;

   const int month_key = Strategy_CurrentMonthKey();
   if(month_key <= 0 || month_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = month_key;

   if(!Strategy_HasOpenPosition())
      return false;
   return !Strategy_Eligible();
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_SymbolGuardInit(g_strategy_symbols);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1,
                          MathMax(strategy_min_history_d1_bars,
                                  strategy_low_lookback_d1_bars + strategy_atr_period + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10876\",\"ea\":\"nt-mag7-mixed\"}");
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
