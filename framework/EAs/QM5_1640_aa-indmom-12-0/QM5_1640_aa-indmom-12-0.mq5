#property strict
#property version   "5.1"
#property description "QM5_1640 Alpha Architect Industry Momentum 12-0 Top-5"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1640
// -----------------------------------------------------------------------------
// Card: aa-indmom-12-0 (source ede348b4-0fa7-5be1-baa8-09e9089b67b7)
// Monthly cross-sectional long-only momentum over the approved DWX index proxy
// universe. The snapshot uses only completed MN1 bars: Close(1)/Close(13)-1.
// The positive top five are held until the next monthly snapshot.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1640;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_min_monthly_bars     = 14;
input int    strategy_top_slots            = 5;
input int    strategy_atr_period_d1         = 20;
input double strategy_sl_atr_mult           = 3.0;
input int    strategy_spread_median_days    = 20;
input double strategy_spread_median_mult    = 2.5;

// The other four card candidates (FCHI/SPA35/NETH25/STOXX50E) are absent from
// the governed active DWX symbol matrix. basket_manifest.json records that
// availability decision. Existing registry allocations are never repurposed.
const int STRATEGY_UNIVERSE_SIZE = 5;
string g_universe_symbols[STRATEGY_UNIVERSE_SIZE] =
  {
   "GDAXI.DWX", "NDX.DWX", "SP500.DWX", "UK100.DWX", "WS30.DWX"
  };
int g_universe_slots[STRATEGY_UNIVERSE_SIZE] = {0, 1, 2, 3, 4};

bool   g_snapshot_selected[STRATEGY_UNIVERSE_SIZE];
double g_snapshot_scores[STRATEGY_UNIVERSE_SIZE];
int    g_snapshot_month_key = 0;
bool   g_snapshot_valid = false;
int    g_last_entry_rebalance_key = 0;
QM_ExitReason g_strategy_exit_reason = QM_EXIT_STRATEGY;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0 || index >= ArraySize(g_universe_slots))
      return -1;
   return g_universe_slots[index];
  }

int Strategy_MonthKey(const datetime when)
  {
   MqlDateTime parts;
   TimeToStruct(when, parts);
   return parts.year * 100 + parts.mon;
  }

bool Strategy_LoadMonthlyReturn(const string symbol, double &out_score)
  {
   out_score = 0.0;
   if(strategy_min_monthly_bars < 14 || strategy_min_monthly_bars > 120)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   double closes[];
   const int required = strategy_min_monthly_bars;
   const int copied = CopyClose(symbol, PERIOD_MN1, 1, required, closes); // perf-allowed: one bounded completed-month cross-sectional snapshot per calendar month.
   if(copied != required || ArraySize(closes) < required)
      return false;

   // CopyClose stores the oldest requested element first. These indices stay
   // Close(1) and Close(13) even when the minimum-history input exceeds 14.
   const int latest_index = copied - 1;
   const int past_index = copied - 13;
   if(latest_index < 0 || past_index < 0 ||
      latest_index >= ArraySize(closes) || past_index >= ArraySize(closes))
      return false;

   const double close_1 = closes[latest_index];
   const double close_13 = closes[past_index];
   if(close_1 <= 0.0 || close_13 <= 0.0)
      return false;

   out_score = close_1 / close_13 - 1.0;
   return MathIsValidNumber(out_score);
  }

bool Strategy_RefreshMonthlySnapshot()
  {
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   if(month_key <= 0)
      return false;
   if(month_key == g_snapshot_month_key)
      return g_snapshot_valid;

   g_snapshot_month_key = month_key;
   g_snapshot_valid = false;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      g_snapshot_selected[i] = false;
      g_snapshot_scores[i] = 0.0;
     }

   // The governed universe is atomic: missing history for any constituent
   // invalidates this month's snapshot rather than silently changing ranks.
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(!Strategy_LoadMonthlyReturn(g_universe_symbols[i], g_snapshot_scores[i]))
         return false;

   int ranked[STRATEGY_UNIVERSE_SIZE];
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      ranked[i] = i;

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE - 1; ++i)
      for(int j = i + 1; j < STRATEGY_UNIVERSE_SIZE; ++j)
        {
         const int left = ranked[i];
         const int right = ranked[j];
         const bool score_precedes = (g_snapshot_scores[right] > g_snapshot_scores[left]);
         const bool tie_precedes =
            (g_snapshot_scores[right] == g_snapshot_scores[left] &&
             StringCompare(g_universe_symbols[right], g_universe_symbols[left]) < 0);
         if(score_precedes || tie_precedes)
           {
            ranked[i] = right;
            ranked[j] = left;
           }
        }

   const int selected_limit = (int)MathMin(strategy_top_slots, STRATEGY_UNIVERSE_SIZE);
   if(selected_limit <= 0)
      return false;
   for(int rank = 0; rank < selected_limit; ++rank)
     {
      if(rank >= ArraySize(ranked))
         return false;
      const int symbol_index = ranked[rank];
      if(symbol_index < 0 || symbol_index >= ArraySize(g_snapshot_scores))
         return false;
      if(g_snapshot_scores[symbol_index] > 0.0)
         g_snapshot_selected[symbol_index] = true;
     }

   g_snapshot_valid = true;
   return true;
  }

bool Strategy_CurrentSymbolSelected()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0 || index >= ArraySize(g_snapshot_selected))
      return false;
   if(!Strategy_RefreshMonthlySnapshot())
      return false;
   return g_snapshot_selected[index];
  }

bool Strategy_HasOurPosition()
  {
   const int slot = Strategy_CurrentSymbolSlot();
   const int magic = QM_Magic(qm_ea_id, slot);
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

int Strategy_OpenPortfolioPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const int position_magic = (int)PositionGetInteger(POSITION_MAGIC);
      for(int slot_index = 0; slot_index < STRATEGY_UNIVERSE_SIZE; ++slot_index)
        {
         if(slot_index >= ArraySize(g_universe_slots))
            return strategy_top_slots;
         if(position_magic == QM_Magic(qm_ea_id, g_universe_slots[slot_index]))
           {
            ++count;
            break;
           }
        }
     }
   return count;
  }

bool Strategy_FirstD1BarOfMonth()
  {
   datetime bar_times[];
   const int copied = CopyTime(_Symbol, PERIOD_D1, 0, 2, bar_times); // perf-allowed: two-bar month-boundary check, reached only behind QM_IsNewBar.
   if(copied != 2 || ArraySize(bar_times) < 2)
      return false;
   return Strategy_MonthKey(bar_times[0]) != Strategy_MonthKey(bar_times[1]);
  }

bool Strategy_HadEntryThisMonth()
  {
   MqlDateTime start_parts;
   TimeToStruct(TimeCurrent(), start_parts);
   start_parts.day = 1;
   start_parts.hour = 0;
   start_parts.min = 0;
   start_parts.sec = 0;
   const datetime month_start = StructToTime(start_parts);
   if(month_start <= 0 || !HistorySelect(month_start, TimeCurrent()))
      return true;

   const int magic = QM_Magic(qm_ea_id, Strategy_CurrentSymbolSlot());
   if(magic <= 0)
      return true;
   const int deal_count = HistoryDealsTotal();
   for(int i = deal_count - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_median_days > 64 ||
      strategy_spread_median_mult <= 0.0)
      return false;

   MqlRates rates[];
   const int required = strategy_spread_median_days;
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, required, rates); // perf-allowed: one bounded 20-day spread sample per monthly entry decision.
   if(copied != required || ArraySize(rates) < required)
      return false;

   double spreads[];
   ArrayResize(spreads, required);
   if(ArraySize(spreads) < required)
      return false;
   for(int i = 0; i < required; ++i)
     {
      if(i >= ArraySize(rates) || i >= ArraySize(spreads) || rates[i].spread <= 0)
         return false;
      spreads[i] = (double)rates[i].spread;
     }

   ArraySort(spreads);

   double median = spreads[required / 2];
   if((required % 2) == 0)
      median = 0.5 * (spreads[(required / 2) - 1] + spreads[required / 2]);
   if(median <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= bid || bid <= 0.0 || point <= 0.0)
      return false;
   const double current_spread_points = (ask - bid) / point;
   return (current_spread_points > 0.0 &&
           current_spread_points <= strategy_spread_median_mult * median);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   if(strategy_top_slots <= 0 || strategy_top_slots > STRATEGY_UNIVERSE_SIZE)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_sl_atr_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   if(!Strategy_FirstD1BarOfMonth())
      return false;

   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   if(month_key <= 0 || month_key == g_last_entry_rebalance_key)
      return false;
   // Bind this instance to one admission decision for the rebalance month,
   // even when spread or portfolio-cap checks reject the order.
   g_last_entry_rebalance_key = month_key;

   if(Strategy_HasOurPosition() || Strategy_HadEntryThisMonth())
      return false;
   if(!Strategy_CurrentSymbolSelected())
      return false;
   if(Strategy_OpenPortfolioPositions() >= strategy_top_slots)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;
   const double stop = QM_StopATR(_Symbol, QM_BUY, ask,
                                  strategy_atr_period_d1, strategy_sl_atr_mult);
   if(stop <= 0.0 || stop >= ask)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = "QM5_1640_XSMOM_12_0_POSITIVE_TOP5";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Fixed initial ATR stop and monthly membership exit; no active trailing.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;
   if(!Strategy_RefreshMonthlySnapshot())
      return false;
   if(Strategy_CurrentSymbolSelected())
      return false;

   g_strategy_exit_reason = QM_EXIT_STRATEGY;
   return true;
  }

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

   const int symbol_index = Strategy_CurrentSymbolIndex();
   const int symbol_slot = Strategy_CurrentSymbolSlot();
   if(symbol_index < 0 || symbol_slot < 0 || qm_magic_slot_offset != symbol_slot)
      return INIT_FAILED;
   if(QM_MagicChecked(qm_ea_id, symbol_slot, _Symbol) <= 0)
      return INIT_FAILED;

   QM_SymbolGuardInit(g_universe_symbols);
   QM_BasketWarmupHistory(g_universe_symbols, PERIOD_MN1, strategy_min_monthly_bars);
   QM_BasketWarmupHistory(g_universe_symbols, PERIOD_D1,
                          strategy_spread_median_days + strategy_atr_period_d1 + 5);
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_1640\",\"universe\":\"active-index-proxies-5\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   // Risk-reducing paths remain active during all news blackouts.
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
         QM_TM_ClosePosition(ticket, g_strategy_exit_reason);
        }
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
