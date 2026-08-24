#property strict
#property version   "5.1"
#property description "QM5_9166 Alpha Architect Volatility-Sorted MA Timing"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9166
// -----------------------------------------------------------------------------
// Once per calendar month, rank the availability-checked 13-symbol DWX basket
// by annualized realized volatility over 252 completed D1 returns. Seal the
// highest-volatility quintile for that month, then apply the card's average of
// the last 10 completed month-end closes to the host symbol. Runtime basket
// reads are explicit, bounded, guarded, and performed at most once per D1 bar
// until the current-month snapshot succeeds.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9166;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_months        = 10;
input int    strategy_vol_lookback_days = 252;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 3.0;
input int    strategy_min_warmup_bars   = 252;
input bool   strategy_enable_shorts     = false;

// Slot order is identical to magic_numbers.csv and every canonical setfile.
string g_strategy_basket[13] =
  {
   "GDAXI.DWX", "NDX.DWX", "SP500.DWX", "UK100.DWX", "WS30.DWX",
   "XAUUSD.DWX", "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX",
   "USDCHF.DWX", "AUDUSD.DWX", "USDCAD.DWX", "NZDUSD.DWX"
  };

int    g_snapshot_month_key       = 0;
int    g_snapshot_attempt_day_key = 0;
bool   g_snapshot_ready           = false;
bool   g_host_selected            = false;
int    g_host_rank                = -1;
int    g_valid_universe_count     = 0;
int    g_active_sleeve_count      = 0;
double g_host_realized_vol        = 0.0;
double g_host_month_close         = 0.0;
double g_host_sma_month_end       = 0.0;

int Strategy_MaxInt(const int left, const int right)
  {
   return (left > right) ? left : right;
  }

bool Strategy_ParametersValid()
  {
   if(strategy_sma_months < 2 || strategy_sma_months > 24)
      return false;
   if(strategy_vol_lookback_days < 20 || strategy_vol_lookback_days > 504)
      return false;
   if(strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(strategy_min_warmup_bars < strategy_vol_lookback_days)
      return false;
   return true;
  }

bool Strategy_HostRegistrationMatches()
  {
   const int count = ArraySize(g_strategy_basket);
   if(qm_magic_slot_offset < 0 || qm_magic_slot_offset >= count)
      return false;
   return (g_strategy_basket[qm_magic_slot_offset] == _Symbol);
  }

bool Strategy_MonthStart(const int month_key, datetime &month_start)
  {
   month_start = 0;
   const int year = month_key / 100;
   const int month = month_key % 100;
   if(year < 1970 || month < 1 || month > 12)
      return false;

   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = year;
   parts.mon = month;
   parts.day = 1;
   month_start = StructToTime(parts);
   return (month_start > 0);
  }

bool Strategy_HasOpenPosition(int &position_type, ulong &out_ticket)
  {
   position_type = -1;
   out_ticket = 0;
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

      position_type = (int)PositionGetInteger(POSITION_TYPE);
      out_ticket = ticket;
      return true;
     }
   return false;
  }

bool Strategy_MonthHasConfirmedEntry(const int month_key, bool &has_entry)
  {
   has_entry = false;
   datetime month_start = 0;
   if(!Strategy_MonthStart(month_key, month_start))
      return false;
   const datetime now = TimeCurrent();
   if(now < month_start || !HistorySelect(month_start, now))
      return false;

   const int magic = QM_FrameworkMagic();
   const int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind == DEAL_ENTRY_IN || entry_kind == DEAL_ENTRY_INOUT)
        {
         has_entry = true;
         return true;
        }
     }
   return true;
  }

bool Strategy_CalculateRealizedVol(const string symbol,
                                   const datetime month_start,
                                   double &annualized_vol)
  {
   annualized_vol = 0.0;
   if(!QM_SymbolAssertOrLog(symbol) || strategy_vol_lookback_days < 2)
      return false;

   const int required = strategy_vol_lookback_days + 1;
   MqlRates rates[];
   // perf-allowed: exact bounded completed-D1 window, once per basket symbol
   // per monthly snapshot; never called from the ordinary per-tick path.
   const int copied = CopyRates(symbol,
                                PERIOD_D1,
                                (datetime)(month_start - 1),
                                required,
                                rates);
   if(copied != required || ArraySize(rates) != required)
      return false;

   double sum = 0.0;
   for(int i = 0; i < required; ++i)
     {
      if(rates[i].time <= 0 || rates[i].time >= month_start ||
         rates[i].close <= 0.0 || !MathIsValidNumber(rates[i].close))
         return false;
      if(i > 0 && rates[i].time <= rates[i - 1].time)
         return false;
     }
   for(int i = 1; i < required; ++i)
     {
      const double daily_return = MathLog(rates[i].close / rates[i - 1].close);
      if(!MathIsValidNumber(daily_return))
         return false;
      sum += daily_return;
     }

   const double mean = sum / (double)strategy_vol_lookback_days;
   double variance_sum = 0.0;
   for(int i = 1; i < required; ++i)
     {
      const double daily_return = MathLog(rates[i].close / rates[i - 1].close);
      const double difference = daily_return - mean;
      variance_sum += difference * difference;
     }
   if(variance_sum <= 0.0 || !MathIsValidNumber(variance_sum))
      return false;

   annualized_vol = MathSqrt(variance_sum /
                             (double)(strategy_vol_lookback_days - 1)) *
                    MathSqrt(252.0);
   return (annualized_vol > 0.0 && MathIsValidNumber(annualized_vol));
  }

bool Strategy_ReadCompletedMonthEnds(const datetime month_start,
                                     double &completed_month_close,
                                     double &sma_month_end)
  {
   completed_month_close = 0.0;
   sma_month_end = 0.0;
   const int month_scan = strategy_sma_months * 32 + 5;
   const int required = Strategy_MaxInt(strategy_min_warmup_bars + 1,
                                        month_scan);
   MqlRates rates[];
   // perf-allowed: bounded D1 scan once per monthly snapshot. D1 is used to
   // derive exact month-end observations because DWX MN1 bars are not a
   // reliable tester contract.
   const int copied = CopyRates(_Symbol,
                                PERIOD_D1,
                                (datetime)(month_start - 1),
                                required,
                                rates);
   if(copied != required || ArraySize(rates) != required)
      return false;
   for(int i = 0; i < required; ++i)
     {
      if(rates[i].time <= 0 || rates[i].time >= month_start ||
         rates[i].close <= 0.0 || !MathIsValidNumber(rates[i].close))
         return false;
      if(i > 0 && rates[i].time <= rates[i - 1].time)
         return false;
     }

   int found = 0;
   int previous_month_key = 0;
   double sum = 0.0;
   for(int i = required - 1; i >= 0 && found < strategy_sma_months; --i)
     {
      MqlDateTime parts;
      TimeToStruct(rates[i].time, parts);
      const int observation_month = parts.year * 100 + parts.mon;
      if(observation_month == previous_month_key)
         continue;
      if(found == 0)
         completed_month_close = rates[i].close;
      sum += rates[i].close;
      previous_month_key = observation_month;
      found++;
     }
   if(found != strategy_sma_months || completed_month_close <= 0.0)
      return false;

   sma_month_end = sum / (double)strategy_sma_months;
   return (sma_month_end > 0.0 && MathIsValidNumber(sma_month_end));
  }

int Strategy_ActiveSleeveCount(const int valid_count)
  {
   if(valid_count < 3)
      return 0;
   int count = (valid_count + 4) / 5; // ceil(valid_count * 20%)
   if(valid_count < 10 && count < 3)
      count = 3;                     // card's minimum-universe fallback
   if(count > valid_count)
      count = valid_count;
   return count;
  }

bool Strategy_BuildMonthlySnapshot(const int month_key)
  {
   datetime month_start = 0;
   if(!Strategy_MonthStart(month_key, month_start))
      return false;

   const int basket_count = ArraySize(g_strategy_basket);
   double volatility[];
   bool available[];
   if(ArrayResize(volatility, basket_count) != basket_count ||
      ArrayResize(available, basket_count) != basket_count)
      return false;

   int valid_count = 0;
   bool host_available = false;
   double host_volatility = 0.0;
   for(int slot = 0; slot < basket_count; ++slot)
     {
      volatility[slot] = 0.0;
      available[slot] = Strategy_CalculateRealizedVol(g_strategy_basket[slot],
                                                       month_start,
                                                       volatility[slot]);
      if(available[slot])
         valid_count++;
      if(slot == qm_magic_slot_offset)
        {
         host_available = available[slot];
         host_volatility = volatility[slot];
        }
     }

   const int selected_count = Strategy_ActiveSleeveCount(valid_count);
   const int host_slot = qm_magic_slot_offset;
   if(selected_count <= 0 || host_slot < 0 || host_slot >= basket_count ||
      ArraySize(volatility) != basket_count ||
      ArraySize(available) != basket_count || !host_available)
      return false;

   int host_rank = 0;
   for(int slot = 0; slot < basket_count; ++slot)
     {
      if(!available[slot] || slot == host_slot)
         continue;
      if(volatility[slot] > host_volatility ||
         (volatility[slot] == host_volatility && slot < host_slot))
         host_rank++;
     }

   double completed_month_close = 0.0;
   double sma_month_end = 0.0;
   if(!Strategy_ReadCompletedMonthEnds(month_start,
                                       completed_month_close,
                                       sma_month_end))
      return false;

   g_snapshot_month_key = month_key;
   g_snapshot_ready = true;
   g_host_selected = (host_rank < selected_count);
   g_host_rank = host_rank;
   g_valid_universe_count = valid_count;
   g_active_sleeve_count = selected_count;
   g_host_realized_vol = host_volatility;
   g_host_month_close = completed_month_close;
   g_host_sma_month_end = sma_month_end;

   QM_LogEvent(QM_INFO,
               "MONTHLY_VOLATILITY_SNAPSHOT",
               StringFormat(
                  "{\"month\":%d,\"host\":\"%s\",\"valid_universe\":%d,\"active_sleeves\":%d,\"host_rank\":%d,\"selected\":%s,\"host_vol\":%.12f,\"month_close\":%.10f,\"sma_month_end\":%.10f}",
                  month_key,
                  _Symbol,
                  valid_count,
                  selected_count,
                  host_rank,
                  g_host_selected ? "true" : "false",
                  g_host_realized_vol,
                  g_host_month_close,
                  g_host_sma_month_end));
   return true;
  }

bool Strategy_EnsureMonthlySnapshot()
  {
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   if(month_key <= 0)
      return false;
   if(g_snapshot_ready && g_snapshot_month_key == month_key)
      return true;

   const int day_key = QM_CalendarPeriodKey(PERIOD_D1);
   if(day_key <= 0 || g_snapshot_attempt_day_key == day_key)
      return false;

   g_snapshot_attempt_day_key = day_key;
   g_snapshot_ready = false;
   g_snapshot_month_key = 0;
   g_host_selected = false;
   g_host_rank = -1;
   g_valid_universe_count = 0;
   g_active_sleeve_count = 0;
   g_host_realized_vol = 0.0;
   g_host_month_close = 0.0;
   g_host_sma_month_end = 0.0;

   if(Strategy_BuildMonthlySnapshot(month_key))
      return true;

   QM_LogEvent(QM_WARN,
               "MONTHLY_VOLATILITY_SNAPSHOT_REJECTED",
               StringFormat("{\"month\":%d,\"reason\":\"incomplete_or_invalid_basket_evidence\"}",
                            month_key));
   return false;
  }

bool Strategy_MedianSpreadD1(const string symbol,
                             const int lookback,
                             double &median_spread)
  {
   median_spread = 0.0;
   if(lookback != 20 || !QM_SymbolAssertOrLog(symbol))
      return false;

   MqlRates rates[];
   // perf-allowed: exact bounded 20-bar completed-D1 spread sample, evaluated
   // only by the once-per-new-D1-bar entry path.
   const int copied = CopyRates(symbol, PERIOD_D1, 1, lookback, rates);
   if(copied != lookback || ArraySize(rates) != lookback)
      return false;

   double spreads[];
   if(ArrayResize(spreads, lookback) != lookback)
      return false;
   for(int i = 0; i < lookback; ++i)
     {
      if(rates[i].time <= 0 || rates[i].spread <= 0)
         return false;
      spreads[i] = (double)rates[i].spread;
     }
   if(ArraySize(spreads) != lookback)
      return false;

   ArraySort(spreads);
   median_spread = (spreads[lookback / 2 - 1] +
                    spreads[lookback / 2]) / 2.0;
   return (median_spread > 0.0 && MathIsValidNumber(median_spread));
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || !(ask > bid) || point <= 0.0)
      return false;

   const double current_spread = (ask - bid) / point;
   if(current_spread <= 0.0 || !MathIsValidNumber(current_spread))
      return false;

   double median_spread = 0.0;
   if(!Strategy_MedianSpreadD1(_Symbol, 20, median_spread) ||
      median_spread <= 0.0)
      return false;

   return (current_spread <= 2.5 * median_spread);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Entry-only admission. It is deliberately called after management and exits.
bool Strategy_NoTradeFilter()
  {
   if(!g_snapshot_ready ||
      g_snapshot_month_key != QM_CalendarPeriodKey(PERIOD_MN1))
      return true;
   if(!g_host_selected || g_active_sleeve_count <= 0)
      return true;
   if(!Strategy_SpreadAllowsEntry())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_snapshot_ready || !g_host_selected ||
      g_active_sleeve_count <= 0 || g_host_month_close <= 0.0 ||
      g_host_sma_month_end <= 0.0)
      return false;

   int position_type = -1;
   ulong ticket = 0;
   if(Strategy_HasOpenPosition(position_type, ticket))
      return false;

   bool has_confirmed_entry = false;
   if(!Strategy_MonthHasConfirmedEntry(g_snapshot_month_key,
                                       has_confirmed_entry) ||
      has_confirmed_entry)
      return false;

   const bool go_long = (g_host_month_close > g_host_sma_month_end);
   const bool go_short = (strategy_enable_shorts &&
                          g_host_month_close < g_host_sma_month_end);
   if(!go_long && !go_short)
      return false;

   req.type = go_long ? QM_BUY : QM_SELL;
   req.price = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol,
                       req.type,
                       req.price,
                       strategy_atr_period,
                       strategy_atr_sl_mult);
   req.reason = go_long ? "AA_VOL_QUINTILE_SMA10M_LONG"
                        : "AA_VOL_QUINTILE_SMA10M_SHORT";
   if(req.sl <= 0.0)
      return false;
   if(go_long && req.sl >= req.price)
      return false;
   if(go_short && req.sl <= req.price)
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_EnsureMonthlySnapshot();
   // Card specifies no trailing stop, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   int position_type = -1;
   ulong ticket = 0;
   if(!Strategy_HasOpenPosition(position_type, ticket))
      return false;
   if(!g_snapshot_ready ||
      g_snapshot_month_key != QM_CalendarPeriodKey(PERIOD_MN1))
      return false;
   if(!g_host_selected)
      return true;
   if(position_type == (int)POSITION_TYPE_BUY)
      return (g_host_month_close <= g_host_sma_month_end);
   if(position_type == (int)POSITION_TYPE_SELL)
      return (g_host_month_close >= g_host_sma_month_end);
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

bool Strategy_OpenWithDistributedRisk(const QM_EntryRequest &req,
                                      ulong &out_ticket)
  {
   out_ticket = 0;
   if(g_active_sleeve_count <= 0)
      return false;

   QM_RiskMode mode = QM_RISK_MODE_UNSET;
   double basket_budget = 0.0;
   if(RISK_FIXED > 0.0 && RISK_PERCENT == 0.0)
     {
      mode = QM_RISK_MODE_FIXED;
      basket_budget = RISK_FIXED;
     }
   else if(RISK_PERCENT > 0.0 && RISK_FIXED == 0.0)
     {
      mode = QM_RISK_MODE_PERCENT;
      basket_budget = RISK_PERCENT;
     }
   else
      return false;

   const double sleeve_budget = basket_budget /
                                (double)g_active_sleeve_count;
   if(sleeve_budget <= 0.0 || !MathIsValidNumber(sleeve_budget))
      return false;

   // The explicit risk overload applies the framework's PORTFOLIO_WEIGHT after
   // this equal split, so aggregate requested risk is basket_budget * weight.
   return QM_TM_OpenPosition(req,
                             out_ticket,
                             QM_FrameworkMagic(),
                             mode,
                             sleeve_budget);
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   if(_Period != PERIOD_D1 ||
      !Strategy_ParametersValid() ||
      !Strategy_HostRegistrationMatches())
     {
      QM_LogEvent(QM_ERROR,
                  "STRATEGY_INIT_FAILED",
                  "{\"reason\":\"timeframe_parameters_or_host_registration\"}");
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_SymbolGuardInit(g_strategy_basket);
   const int warmup = Strategy_MaxInt(strategy_min_warmup_bars + 1,
                                      Strategy_MaxInt(strategy_vol_lookback_days + 1,
                                                      strategy_sma_months * 32 + 5));
   QM_BasketWarmupHistory(g_strategy_basket, PERIOD_D1, warmup);
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // Snapshot refresh and risk-reducing exits precede every entry-only gate.
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;
   QM_EquityStreamOnNewBar();

   if(Strategy_NoTradeFilter())
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(Strategy_OpenWithDistributedRisk(req, out_ticket))
         QM_LogEvent(QM_INFO,
                     "MONTHLY_ENTRY_CONFIRMED",
                     StringFormat("{\"month\":%d,\"ticket\":%I64u,\"active_sleeves\":%d}",
                                  g_snapshot_month_key,
                                  out_ticket,
                                  g_active_sleeve_count));
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
