#property strict
#property version   "5.0"
#property description "QM5_12405 Twelve-Month Cycle Return Rank"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12405;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cycle_offset_months = 12;
input int    strategy_return_window_months = 1;
input int    strategy_bucket_size          = 1;
input int    strategy_min_valid_symbols   = 5;
input int    strategy_warmup_months       = 14;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input double strategy_basket_stop_r       = 6.0;
input int    strategy_spread_lookback_days = 60;
input double strategy_spread_mult         = 2.0;

#define QM5_12405_SYMBOL_COUNT 5

string g_symbols[QM5_12405_SYMBOL_COUNT] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX"
  };

int g_slots[QM5_12405_SYMBOL_COUNT] = {0, 1, 2, 3, 4};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key  = 0;
bool g_basket_stop_active      = false;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_12405_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

int Strategy_CurrentMagic()
  {
   return QM_FrameworkMagic();
  }

int Strategy_MonthKeyFromTime(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthEndClosedBar()
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 2, bars) != 2) // perf-allowed: two D1 bars to detect a monthly rebalance boundary.
      return false;

   const int current_key = Strategy_MonthKeyFromTime(bars[0].time);
   const int closed_key  = Strategy_MonthKeyFromTime(bars[1].time);
   return (current_key != closed_key);
  }

int Strategy_RebalanceKey()
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, bars) != 1) // perf-allowed: one closed D1 bar for monthly rebalance identity.
      return 0;
   return Strategy_MonthKeyFromTime(bars[0].time);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = Strategy_CurrentMagic();
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

int Strategy_PositionSide()
  {
   const int magic = Strategy_CurrentMagic();
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         return 1;
      if(ptype == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

bool Strategy_LoadMonthlyCloses(const string symbol, const int required_months, double &month_closes[])
  {
   ArrayResize(month_closes, 0);
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   int bars_needed = required_months * 24;
   if(bars_needed < 420)
      bars_needed = 420;
   if(bars_needed > 800)
      bars_needed = 800;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: bounded D1 window, called only after the framework D1 new-bar gate.
   if(copied <= 0)
      return false;

   int last_month_key = 0;
   for(int i = 0; i < copied && ArraySize(month_closes) < required_months; ++i)
     {
      const int month_key = Strategy_MonthKeyFromTime(rates[i].time);
      if(month_key == last_month_key)
         continue;
      last_month_key = month_key;
      const int next = ArraySize(month_closes);
      ArrayResize(month_closes, next + 1);
      month_closes[next] = rates[i].close;
     }

   return (ArraySize(month_closes) >= required_months);
  }

bool Strategy_CycleScore(const string symbol, double &out_score)
  {
   out_score = 0.0;

   if(strategy_cycle_offset_months < 1 || strategy_return_window_months < 1)
      return false;

   int required_months = strategy_cycle_offset_months + strategy_return_window_months + 1;
   if(required_months < strategy_warmup_months)
      required_months = strategy_warmup_months;

   double closes[];
   if(!Strategy_LoadMonthlyCloses(symbol, required_months, closes))
      return false;

   const int end_idx = strategy_cycle_offset_months;
   const int start_idx = strategy_cycle_offset_months + strategy_return_window_months;
   if(ArraySize(closes) <= start_idx)
      return false;

   const double end_close = closes[end_idx];
   const double start_close = closes[start_idx];
   if(end_close <= 0.0 || start_close <= 0.0)
      return false;

   out_score = (end_close / start_close) - 1.0;
   return true;
  }

void Strategy_SortScores(double &scores[], int &indexes[], const int count)
  {
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
  }

int Strategy_CurrentSelectionSide()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[QM5_12405_SYMBOL_COUNT];
   int indexes[QM5_12405_SYMBOL_COUNT];
   int count = 0;

   for(int i = 0; i < QM5_12405_SYMBOL_COUNT; ++i)
     {
      double score = 0.0;
      if(!Strategy_CycleScore(g_symbols[i], score))
         continue;
      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   if(count < strategy_min_valid_symbols)
      return 0;

   Strategy_SortScores(scores, indexes, count);

   int selected_count = strategy_bucket_size;
   if(selected_count < 1)
      return 0;
   if(selected_count * 2 > count)
      selected_count = count / 2;
   if(selected_count < 1)
      return 0;

   for(int i = 0; i < selected_count; ++i)
      if(indexes[i] == current_index)
         return 1;

   for(int i = count - selected_count; i < count; ++i)
      if(indexes[i] == current_index)
         return -1;

   return 0;
  }

double Strategy_MedianDailySpreadPoints()
  {
   if(strategy_spread_lookback_days <= 0 || strategy_spread_lookback_days > 256)
      return 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_lookback_days, rates); // perf-allowed: bounded spread sample, used only on monthly entry checks.
   if(copied <= 0)
      return 0.0;

   double values[256];
   int count = 0;
   for(int i = 0; i < copied && count < 256; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      values[count] = (double)rates[i].spread;
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
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

double Strategy_PerLegRiskMoney()
  {
   if(RISK_FIXED > 0.0)
      return RISK_FIXED;
   if(RISK_PERCENT > 0.0)
      return AccountInfoDouble(ACCOUNT_EQUITY) * RISK_PERCENT / 100.0;
   return 0.0;
  }

bool Strategy_IsBasketMagic(const int magic)
  {
   for(int i = 0; i < QM5_12405_SYMBOL_COUNT; ++i)
      if(magic == QM_Magic(qm_ea_id, g_slots[i]))
         return true;
   return false;
  }

void Strategy_CloseBasketPositions(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(!Strategy_IsBasketMagic(magic))
         continue;

      QM_TM_ClosePosition(ticket, reason);
     }
  }

void Strategy_UpdateBasketStop()
  {
   if(strategy_basket_stop_r <= 0.0 || g_basket_stop_active)
      return;

   double open_pnl = 0.0;
   int legs = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(!Strategy_IsBasketMagic(magic))
         continue;

      open_pnl += PositionGetDouble(POSITION_PROFIT);
      ++legs;
     }

   if(legs <= 0)
      return;

   const double per_leg_risk = Strategy_PerLegRiskMoney();
   if(per_leg_risk <= 0.0)
      return;

   if(open_pnl <= -strategy_basket_stop_r * per_leg_risk)
     {
      g_basket_stop_active = true;
      Strategy_CloseBasketPositions(QM_EXIT_STRATEGY);
     }
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(Strategy_SlotForCurrentSymbol() != qm_magic_slot_offset)
      return true;
   if(strategy_min_valid_symbols < 2 || strategy_min_valid_symbols > QM5_12405_SYMBOL_COUNT)
      return true;
   if(strategy_bucket_size < 1)
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
   req.reason = "QM5_12405_CYCLE12";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthEndClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(g_basket_stop_active)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int side = Strategy_CurrentSelectionSide();
   if(side == 0)
      return false;

   req.type = (side > 0) ? QM_BUY : QM_SELL;

   const double entry = (side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(side > 0 && req.sl >= entry)
      return false;
   if(side < 0 && req.sl <= entry)
      return false;

   req.reason = (side > 0) ? "QM5_12405_CYCLE12_LONG_WINNER" : "QM5_12405_CYCLE12_SHORT_LOSER";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   Strategy_UpdateBasketStop();
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_IsMonthEndClosedBar())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;

   const int current_position_side = Strategy_PositionSide();
   const int selected_side = Strategy_CurrentSelectionSide();
   if(selected_side == 0)
      return true;
   return (selected_side != current_position_side);
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, 420);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12405\",\"ea\":\"QM5_12405_stock-cycle12\"}");
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

   if(Strategy_ExitSignal())
     {
      const int magic = Strategy_CurrentMagic();
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
