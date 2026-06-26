#property strict
#property version   "5.0"
#property description "QM5_1540 Alpha Architect VIX-Regime Trend Top-2 Rotation"

#include <QM/QM_Common.mqh>

#define STRATEGY_SYMBOL_COUNT 9

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX",
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX"
  };

int g_symbol_slots[STRATEGY_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6, 7, 8};

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1540;
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
input string strategy_vix_symbol          = "VIX.DWX";
input int    strategy_vix_sma_slow_d1     = 40;
input int    strategy_vix_sma_fast_d1     = 20;
input double strategy_vix_green_max       = 18.0;
input double strategy_vix_red_min         = 32.0;
input int    strategy_green_lookback_mo   = 10;
input int    strategy_yellow_lookback_mo  = 3;
input int    strategy_red_lookback_mo     = 1;
input int    strategy_month_proxy_bars    = 21;
input int    strategy_top_slots           = 2;
input int    strategy_min_daily_bars      = 220;
input int    strategy_vix_stale_days      = 2;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.0;
input double strategy_spread_atr_mult     = 0.25;

int  g_my_symbol_idx = -1;
int  g_target_position[STRATEGY_SYMBOL_COUNT];
bool g_targets_ready = false;
bool g_rebalance_happened = false;
bool g_vix_data_ok = false;
int  g_last_month_key = -1;
int  g_active_slot_count = 0;

int Strategy_SymbolIndex(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == symbol)
         return i;
   return -1;
  }

int Strategy_SymbolSlot(const string symbol)
  {
   const int idx = Strategy_SymbolIndex(symbol);
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_symbol_slots[idx];
  }

void Strategy_ResetTargets()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      g_target_position[i] = 0;
   g_active_slot_count = 0;
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 12 + dt.mon;
  }

int Strategy_TradingDaysBetween(datetime older, datetime newer)
  {
   if(older <= 0 || newer <= older)
      return 0;

   int days = 0;
   datetime cursor = older + 86400;
   while(cursor <= newer && days <= 20)
     {
      MqlDateTime dt;
      TimeToStruct(cursor, dt);
      if(dt.day_of_week >= 1 && dt.day_of_week <= 5)
         days++;
      cursor += 86400;
     }
   return days;
  }

bool Strategy_VixLookbackBars(int &lookback_bars)
  {
   lookback_bars = 0;
   g_vix_data_ok = false;

   if(strategy_vix_symbol == "" ||
      strategy_vix_sma_fast_d1 < 2 ||
      strategy_vix_sma_slow_d1 < strategy_vix_sma_fast_d1 ||
      strategy_month_proxy_bars < 1)
      return false;

   if(!QM_SymbolAssertOrLog(strategy_vix_symbol))
      return false;

   const datetime vix_bar_time = iTime(strategy_vix_symbol, PERIOD_D1, 1); // perf-allowed: fixed closed-bar VIX freshness check.
   const datetime ref_time = iTime(_Symbol, PERIOD_D1, 1);                 // perf-allowed: fixed closed-bar freshness anchor.
   if(vix_bar_time <= 0 || ref_time <= 0)
      return false;
   if(Strategy_TradingDaysBetween(vix_bar_time, ref_time) > MathMax(0, strategy_vix_stale_days))
      return false;

   const double vix_sma40 = QM_SMA(strategy_vix_symbol, PERIOD_D1, strategy_vix_sma_slow_d1, 1, PRICE_CLOSE);
   const double vix_sma20 = QM_SMA(strategy_vix_symbol, PERIOD_D1, strategy_vix_sma_fast_d1, 1, PRICE_CLOSE);
   if(vix_sma40 <= 0.0 || vix_sma20 <= 0.0)
      return false;

   int months = strategy_yellow_lookback_mo;
   if(vix_sma40 <= strategy_vix_green_max)
      months = strategy_green_lookback_mo;
   else if(vix_sma20 >= strategy_vix_red_min)
      months = strategy_red_lookback_mo;

   lookback_bars = MathMax(1, months) * MathMax(1, strategy_month_proxy_bars);
   g_vix_data_ok = true;
   return true;
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_ConfigureSplitRisk()
  {
   const int slots = MathMax(1, g_active_slot_count);
   const double k = 1.0 / (double)slots;

   if(RISK_PERCENT > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_PERCENT, RISK_PERCENT * k, 0.0, PORTFOLIO_WEIGHT);
   if(RISK_FIXED > 0.0)
      return QM_RiskSizerConfigure(QM_RISK_MODE_FIXED, 0.0, RISK_FIXED * k, PORTFOLIO_WEIGHT);
   return false;
  }

double Strategy_ReturnForSymbol(const string symbol, const int lookback_bars)
  {
   if(!QM_SymbolAssertOrLog(symbol))
      return -DBL_MAX;

   const int min_bars = MathMax(strategy_min_daily_bars, lookback_bars + 2);
   if(Bars(symbol, PERIOD_D1) < min_bars) // perf-allowed: monthly O(1) warmup guard; no QM_Bars helper exists.
      return -DBL_MAX;

   const double recent = QM_SMA(symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double prior = QM_SMA(symbol, PERIOD_D1, 1, 1 + lookback_bars, PRICE_CLOSE);
   if(recent <= 0.0 || prior <= 0.0)
      return -DBL_MAX;

   return recent / prior - 1.0;
  }

void Strategy_ComputeTargetPositions()
  {
   Strategy_ResetTargets();
   g_targets_ready = false;

   int lookback_bars = 0;
   if(!Strategy_VixLookbackBars(lookback_bars))
     {
      g_targets_ready = true;
      return;
     }

   double returns[STRATEGY_SYMBOL_COUNT];
   int rank[STRATEGY_SYMBOL_COUNT];
   int valid_count = 0;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      rank[i] = i;
      returns[i] = Strategy_ReturnForSymbol(g_strategy_symbols[i], lookback_bars);
      if(returns[i] > -DBL_MAX / 2.0)
         valid_count++;
     }

   const int slots = MathMax(1, MathMin(strategy_top_slots, STRATEGY_SYMBOL_COUNT));
   if(valid_count < slots)
     {
      g_targets_ready = true;
      return;
     }

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT - 1; ++i)
      for(int j = i + 1; j < STRATEGY_SYMBOL_COUNT; ++j)
         if(returns[rank[j]] > returns[rank[i]])
           {
            const int tmp = rank[i];
            rank[i] = rank[j];
            rank[j] = tmp;
           }

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT && g_active_slot_count < slots; ++i)
     {
      const int idx = rank[i];
      if(returns[idx] <= 0.0 || returns[idx] <= -DBL_MAX / 2.0)
         continue;
      g_target_position[idx] = 1;
      g_active_slot_count++;
     }

   g_targets_ready = true;
  }

void Strategy_AdvanceStateOnNewBar()
  {
   g_rebalance_happened = false;

   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: monthly rebalance key; no QM_Time helper exists.
   if(closed_bar <= 0)
      return;

   const int month_key = Strategy_DateKey(closed_bar);
   if(g_last_month_key < 0)
     {
      g_last_month_key = month_key;
      Strategy_ComputeTargetPositions();
      g_rebalance_happened = g_targets_ready;
      return;
     }

   if(month_key == g_last_month_key)
      return;

   g_last_month_key = month_key;
   Strategy_ComputeTargetPositions();
   g_rebalance_happened = g_targets_ready;
   QM_LogEvent(QM_INFO, "MONTHLY_REBALANCE",
               StringFormat("{\"month_key\":%d,\"vix_ok\":%s,\"active_slots\":%d}",
                            month_key,
                            g_vix_data_ok ? "true" : "false",
                            g_active_slot_count));
  }

bool Strategy_SpreadTooWide()
  {
   if(strategy_spread_atr_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask <= bid)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0)
      return false;

   return ((ask - bid) > strategy_spread_atr_mult * atr);
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(g_my_symbol_idx < 0)
      return true;
   if(qm_magic_slot_offset != Strategy_SymbolSlot(_Symbol))
      return true;
   if(Strategy_SpreadTooWide())
      return true;
   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1540_AA_VIX_TOP2_NONE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_rebalance_happened || !g_targets_ready || !g_vix_data_ok)
      return false;
   if(g_my_symbol_idx < 0 || g_target_position[g_my_symbol_idx] <= 0)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_ConfigureSplitRisk())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period_d1, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= ask)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "QM5_1540_AA_VIX_TOP2_LONG";
   req.symbol_slot = g_symbol_slots[g_my_symbol_idx];
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // The card specifies no trailing stop, break-even move, partial close, or pyramiding.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_rebalance_happened || !g_targets_ready || g_my_symbol_idx < 0)
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   return (g_target_position[g_my_symbol_idx] <= 0);
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   g_my_symbol_idx = Strategy_SymbolIndex(_Symbol);
   if(g_my_symbol_idx < 0)
     {
      Print("QM5_1540 INIT_FAILED: symbol not in approved universe: ", _Symbol);
      return INIT_FAILED;
     }
   if(qm_magic_slot_offset != Strategy_SymbolSlot(_Symbol))
     {
      Print("QM5_1540 INIT_FAILED: slot mismatch for ", _Symbol,
            " expected=", Strategy_SymbolSlot(_Symbol),
            " got=", qm_magic_slot_offset);
      return INIT_FAILED;
     }

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(g_strategy_symbols[i], true);
   if(strategy_vix_symbol != "")
      SymbolSelect(strategy_vix_symbol, true);

   Strategy_ResetTargets();

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

   string allowed[];
   ArrayResize(allowed, STRATEGY_SYMBOL_COUNT + 1);
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      allowed[i] = g_strategy_symbols[i];
   allowed[STRATEGY_SYMBOL_COUNT] = strategy_vix_symbol;

   QM_SymbolGuardInit(allowed);
   const int warmup = MathMax(300,
                              MathMax(strategy_min_daily_bars,
                                      MathMax(strategy_green_lookback_mo,
                                              MathMax(strategy_yellow_lookback_mo, strategy_red_lookback_mo)) *
                                      MathMax(1, strategy_month_proxy_bars) +
                                      strategy_vix_sma_slow_d1 + strategy_atr_period_d1 + 20));
   QM_BasketWarmupHistory(allowed, PERIOD_D1, warmup);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"card\":\"QM5_1540_aa-vix-trend-top2\",\"symbol_index\":%d}", g_my_symbol_idx));
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_AdvanceStateOnNewBar();
     }

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
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

   if(!is_new_bar)
      return;

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
