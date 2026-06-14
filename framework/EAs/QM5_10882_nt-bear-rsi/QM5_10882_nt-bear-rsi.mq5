#property strict
#property version   "5.0"
#property description "QM5_10882 NexusTrade bear-market RSI mean reversion proxy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy card: QM5_10882 nt-bear-rsi, G0 APPROVED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10882;
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
input int    strategy_rsi_period             = 14;
input double strategy_rsi_entry_threshold    = 32.0;
input double strategy_rsi_exit_threshold     = 50.0;
input int    strategy_sp500_sma_period       = 200;
input int    strategy_chart_sma_period       = 100;
input int    strategy_atr_period             = 14;
input double strategy_atr_stop_mult          = 2.5;
input int    strategy_atr_median_lookback    = 252;
input double strategy_atr_median_max_mult    = 2.5;
input int    strategy_time_stop_d1_bars      = 20;
input int    strategy_cooldown_d1_bars       = 5;
input bool   strategy_single_symbol_mode     = false;
input int    strategy_max_spread_points      = 0;

#define STRATEGY_SYMBOL_COUNT 3

string   g_strategy_symbols[STRATEGY_SYMBOL_COUNT] = {"SP500.DWX", "NDX.DWX", "WS30.DWX"};
int      g_strategy_slots[STRATEGY_SYMBOL_COUNT]   = {0, 1, 2};
bool     g_had_open_position                       = false;
datetime g_last_exit_time                          = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_strategy_slots[idx];
  }

double Strategy_CloseD1(const string symbol, const int shift)
  {
   if(!QM_SymbolAssertOrLog(symbol))
      return 0.0;
   return QM_SMA(symbol, PERIOD_D1, 1, shift, PRICE_CLOSE);
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

bool Strategy_GetOpenPosition(double &entry_price, datetime &entry_time)
  {
   entry_price = 0.0;
   entry_time = 0;
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

      entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      return (entry_price > 0.0 && entry_time > 0);
     }
   return false;
  }

void Strategy_UpdatePositionState()
  {
   const bool has_position = Strategy_HasOpenPosition();
   if(g_had_open_position && !has_position)
      g_last_exit_time = TimeCurrent();
   g_had_open_position = has_position;
  }

int Strategy_D1BarsSince(const datetime t)
  {
   if(t <= 0)
      return 999999;
   const int shift = iBarShift(_Symbol, PERIOD_D1, t, false);
   if(shift < 0)
      return 999999;
   return shift;
  }

bool Strategy_InCooldown()
  {
   if(g_last_exit_time <= 0 || strategy_cooldown_d1_bars <= 0)
      return false;
   return (Strategy_D1BarsSince(g_last_exit_time) < strategy_cooldown_d1_bars);
  }

bool Strategy_ParamsValid()
  {
   return (strategy_rsi_period > 1 &&
           strategy_rsi_entry_threshold > 0.0 &&
           strategy_rsi_exit_threshold > strategy_rsi_entry_threshold &&
           strategy_sp500_sma_period > 1 &&
           strategy_chart_sma_period > 1 &&
           strategy_atr_period > 1 &&
           strategy_atr_stop_mult > 0.0 &&
           strategy_atr_median_lookback >= 20 &&
           strategy_atr_median_max_mult > 0.0 &&
           strategy_time_stop_d1_bars > 0 &&
           strategy_cooldown_d1_bars >= 0);
  }

bool Strategy_BearOrWeak()
  {
   const double sp500_close = Strategy_CloseD1("SP500.DWX", 1);
   const double sp500_sma = QM_SMA("SP500.DWX", PERIOD_D1, strategy_sp500_sma_period, 1, PRICE_CLOSE);
   const double chart_close = Strategy_CloseD1(_Symbol, 1);
   const double chart_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_chart_sma_period, 1, PRICE_CLOSE);

   if(sp500_close <= 0.0 || sp500_sma <= 0.0 || chart_close <= 0.0 || chart_sma <= 0.0)
      return false;
   return (sp500_close < sp500_sma || chart_close < chart_sma);
  }

bool Strategy_CurrentHasLowestRSI()
  {
   const int current_idx = Strategy_CurrentSymbolIndex();
   if(current_idx < 0)
      return false;

   const double current_rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   if(current_rsi <= 0.0)
      return false;

   if(strategy_single_symbol_mode)
      return (current_rsi <= strategy_rsi_entry_threshold);

   double lowest_rsi = DBL_MAX;
   int lowest_idx = -1;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      const string sym = g_strategy_symbols[i];
      if(!QM_SymbolAssertOrLog(sym))
         continue;
      const double rsi = QM_RSI(sym, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
      if(rsi <= 0.0)
         continue;
      if(rsi < lowest_rsi)
        {
         lowest_rsi = rsi;
         lowest_idx = i;
        }
     }

   if(lowest_idx < 0)
      return false;
   return (lowest_idx == current_idx || current_rsi <= strategy_rsi_entry_threshold);
  }

bool Strategy_ATRMedianOk()
  {
   const double atr_now = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_now <= 0.0)
      return false;

   double atr_values[];
   ArrayResize(atr_values, strategy_atr_median_lookback);
   int samples = 0;
   for(int shift = 1; shift <= strategy_atr_median_lookback; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;
      atr_values[samples] = atr;
      samples++;
     }

   if(samples < MathMin(20, strategy_atr_median_lookback))
      return false;
   ArrayResize(atr_values, samples);
   ArraySort(atr_values);

   double median = 0.0;
   const int mid = samples / 2;
   if((samples % 2) == 0)
      median = 0.5 * (atr_values[mid - 1] + atr_values[mid]);
   else
      median = atr_values[mid];

   if(median <= 0.0)
      return false;
   return (atr_now <= strategy_atr_median_max_mult * median);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   Strategy_UpdatePositionState();

   if(_Period != PERIOD_D1)
      return true;

   const int symbol_idx = Strategy_CurrentSymbolIndex();
   if(symbol_idx < 0)
      return true;

   if(g_strategy_slots[symbol_idx] != qm_magic_slot_offset)
      return true;

   if(!Strategy_ParamsValid())
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
   req.reason = "QM5_10882_D1_BEAR_RSI_LONG";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(Strategy_InCooldown())
      return false;
   if(!Strategy_BearOrWeak())
      return false;
   if(!Strategy_CurrentHasLowestRSI())
      return false;
   if(!Strategy_ATRMedianOk())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed initial ATR stop only; no trailing, break-even, or partial close.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   double entry_price = 0.0;
   datetime entry_time = 0;
   if(!Strategy_GetOpenPosition(entry_price, entry_time))
      return false;

   const double rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi >= strategy_rsi_exit_threshold)
      return true;

   const double close_d1 = Strategy_CloseD1(_Symbol, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_d1 > 0.0 && atr > 0.0 && close_d1 < entry_price - strategy_atr_stop_mult * atr)
      return true;

   if(Strategy_D1BarsSince(entry_time) >= strategy_time_stop_d1_bars)
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, 300);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10882\",\"ea\":\"QM5_10882_nt_bear_rsi\"}");
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
