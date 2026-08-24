#property strict
#property version   "5.1"
#property description "QM5_41011 Tokyo-to-London Interbank Flow Handover Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41011
// Tokyo-to-London Interbank Flow Handover Breakout
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41011;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    InpRangeStartHourUTC       = 6;      // Handover pre-range start hour UTC (06:00)
input int    InpRangeStartMinUTC        = 0;      // Handover pre-range start minute UTC
input int    InpRangeEndHourUTC         = 6;      // Handover pre-range end hour UTC (06:45, exclusive)
input int    InpRangeEndMinUTC          = 45;     // Handover pre-range end minute UTC
input int    InpEntryStartHourUTC       = 7;      // Entry window start hour UTC (07:00)
input int    InpEntryStartMinUTC        = 0;      // Entry window start minute UTC
input int    InpEntryEndHourUTC         = 7;      // Entry window end hour UTC (07:30, exclusive)
input int    InpEntryEndMinUTC          = 30;     // Entry window end minute UTC
input int    InpTimeStopHourUTC         = 12;     // Daily position time-stop exit hour UTC (12:00)
input double InpBufferPips              = 2.0;    // Breakout entry buffer in whole pips
input double InpMinAtrPips              = 15.0;   // Card minimum ATR in whole pips
input int    InpAtrPeriod               = 14;     // Volatility filter ATR period
input double InpSpreadAtrMult           = 1.8;    // Max spread as multiple of M15 ATR(14)
input double InpRrMultiplier            = 2.0;    // Card target: multiple of handover range width
input double InpDailyLossLimitPct       = 2.0;    // Realised-loss entry halt
input double InpDailyDrawdownHardStopPct = 2.5;   // Equity hard stop from daily anchor
input double InpTotalDrawdownStopPct    = 5.0;    // Account/portfolio total drawdown stop
input double InpMaxSlippageTicks        = 3.0;    // Maximum market-order slippage in ticks

const int    STRATEGY_M15_MINUTES          = 15;
const int    STRATEGY_MAX_RANGE_BARS       = 8;

double g_cached_range_high = 0.0;
double g_cached_range_low  = 0.0;
int    g_cached_range_day  = -1;
bool   g_cached_traded     = true;
double g_cached_atr_1      = 0.0;
double g_cached_close_1    = 0.0;
int    g_cached_bar_minute_utc = -1;
int    g_daily_loss_day    = -1;
bool   g_daily_entry_halt  = true;

int StrategyMinutes(const int hour, const int minute)
{
   return hour * 60 + minute;
}

int StrategyUtcDayKey(const datetime broker_time)
{
   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(broker_time), dt);
   return dt.year * 1000 + dt.day_of_year;
}

datetime StrategyUtcDayStartBroker(const datetime broker_time)
{
   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(broker_time), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return QM_UTCToBroker(StructToTime(dt));
}

bool StrategyInputsValid()
{
   if(InpRangeStartHourUTC < 0 || InpRangeStartHourUTC > 23 ||
      InpRangeEndHourUTC < 0 || InpRangeEndHourUTC > 23 ||
      InpEntryStartHourUTC < 0 || InpEntryStartHourUTC > 23 ||
      InpEntryEndHourUTC < 0 || InpEntryEndHourUTC > 23 ||
      InpTimeStopHourUTC < 0 || InpTimeStopHourUTC > 23)
      return false;

   if(InpRangeStartMinUTC < 0 || InpRangeStartMinUTC > 59 ||
      InpRangeEndMinUTC < 0 || InpRangeEndMinUTC > 59 ||
      InpEntryStartMinUTC < 0 || InpEntryStartMinUTC > 59 ||
      InpEntryEndMinUTC < 0 || InpEntryEndMinUTC > 59)
      return false;

   const int range_minutes = StrategyMinutes(InpRangeEndHourUTC, InpRangeEndMinUTC) -
                             StrategyMinutes(InpRangeStartHourUTC, InpRangeStartMinUTC);
   const int entry_minutes = StrategyMinutes(InpEntryEndHourUTC, InpEntryEndMinUTC) -
                             StrategyMinutes(InpEntryStartHourUTC, InpEntryStartMinUTC);
   if(range_minutes <= 0 || range_minutes % STRATEGY_M15_MINUTES != 0 ||
      range_minutes / STRATEGY_M15_MINUTES > STRATEGY_MAX_RANGE_BARS ||
      entry_minutes <= 0)
      return false;

   return (InpBufferPips >= 0.0 && InpMinAtrPips > 0.0 && InpAtrPeriod > 0 &&
           InpSpreadAtrMult > 0.0 && InpRrMultiplier > 0.0 &&
           MathAbs(InpDailyLossLimitPct - 2.0) <= 1e-9 &&
           MathAbs(InpDailyDrawdownHardStopPct - 2.5) <= 1e-9 &&
           MathAbs(InpTotalDrawdownStopPct - 5.0) <= 1e-9 &&
           InpMaxSlippageTicks > 0.0 && InpMaxSlippageTicks <= 3.0);
}

// Account-wide realised P&L is refreshed on the UTC day boundary and after
// each trade transaction. A history failure keeps entries fail-closed.
void StrategyRefreshDailyEntryHalt(const bool force_refresh)
{
   const datetime now = TimeCurrent();
   const int day_key = StrategyUtcDayKey(now);
   if(!force_refresh && day_key == g_daily_loss_day)
      return;

   g_daily_loss_day = day_key;
   g_daily_entry_halt = true;
   const datetime day_start = StrategyUtcDayStartBroker(now);
   if(day_start <= 0 || !HistorySelect(day_start, now))
      return;

   double realised = 0.0;
   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;
      realised += HistoryDealGetDouble(deal, DEAL_PROFIT);
      realised += HistoryDealGetDouble(deal, DEAL_SWAP);
      realised += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      realised += HistoryDealGetDouble(deal, DEAL_FEE);
   }

   const double day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE) - realised;
   if(day_start_balance <= 0.0)
      return;

   g_daily_entry_halt =
      (realised <= -(InpDailyLossLimitPct / 100.0) * day_start_balance);
}

// Restore the one-opportunity-per-UTC-day state from deal history so an EA
// restart cannot create a second handover entry. History failure fails closed.
void StrategyRestoreDailyTradeState(const datetime broker_time)
{
   g_cached_traded = true;
   const datetime day_start = StrategyUtcDayStartBroker(broker_time);
   if(day_start <= 0 || !HistorySelect(day_start, broker_time))
      return;

   const long magic = (long)QM_FrameworkMagic();
   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         return;
   }
   g_cached_traded = false;
}

bool StrategyBuildRange(const MqlDateTime &closed_bar_utc)
{
   g_cached_range_high = 0.0;
   g_cached_range_low = 0.0;

   const int range_start_minute = StrategyMinutes(InpRangeStartHourUTC, InpRangeStartMinUTC);
   const int range_end_minute = StrategyMinutes(InpRangeEndHourUTC, InpRangeEndMinUTC);
   const int expected_bars = (range_end_minute - range_start_minute) / STRATEGY_M15_MINUTES;
   if(expected_bars <= 0 || expected_bars > STRATEGY_MAX_RANGE_BARS)
      return false;

   MqlDateTime range_end_dt = closed_bar_utc;
   range_end_dt.hour = InpRangeEndHourUTC;
   range_end_dt.min = InpRangeEndMinUTC;
   range_end_dt.sec = 0;
   const datetime range_end_utc = StructToTime(range_end_dt);
   const datetime newest_range_time_broker = QM_UTCToBroker(range_end_utc - 1);
   const int newest_range_shift = iBarShift(_Symbol, PERIOD_M15, newest_range_time_broker, false); // perf-allowed: bounded card-defined range lookup, called only after QM_IsNewBar.
   if(newest_range_shift < 1)
      return false;

   MqlRates range_rates[];
   if(ArrayResize(range_rates, expected_bars) != expected_bars)
      return false;
   const int copied = CopyRates(_Symbol, PERIOD_M15, newest_range_shift, expected_bars, range_rates); // perf-allowed: at most eight card-defined M15 bars behind the new-bar gate.
   if(copied != expected_bars || ArraySize(range_rates) < expected_bars)
      return false;

   double highest = 0.0;
   double lowest = DBL_MAX;
   for(int i = 0; i < expected_bars; ++i)
   {
      MqlDateTime bar_utc;
      TimeToStruct(QM_BrokerToUTC(range_rates[i].time), bar_utc);
      const int bar_minute = StrategyMinutes(bar_utc.hour, bar_utc.min);
      if(bar_utc.year != closed_bar_utc.year ||
         bar_utc.day_of_year != closed_bar_utc.day_of_year ||
         bar_minute < range_start_minute || bar_minute >= range_end_minute)
         return false;
      if(range_rates[i].high > highest)
         highest = range_rates[i].high;
      if(range_rates[i].low > 0.0 && range_rates[i].low < lowest)
         lowest = range_rates[i].low;
   }

   if(highest <= 0.0 || lowest == DBL_MAX || highest <= lowest)
      return false;
   g_cached_range_high = highest;
   g_cached_range_low = lowest;
   return true;
}

void AdvanceState_OnNewBar()
{
   g_cached_atr_1 = 0.0;
   g_cached_close_1 = 0.0;
   g_cached_bar_minute_utc = -1;

   MqlRates closed_rates[];
   if(ArrayResize(closed_rates, 1) != 1)
      return;
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, 1, closed_rates); // perf-allowed: one closed bar, called only after QM_IsNewBar.
   if(copied != 1 || ArraySize(closed_rates) < 1)
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, InpAtrPeriod, 1);
   if(atr <= 0.0 || closed_rates[0].close <= 0.0)
      return;

   MqlDateTime closed_bar_utc;
   TimeToStruct(QM_BrokerToUTC(closed_rates[0].time), closed_bar_utc);
   const int day_key = closed_bar_utc.year * 1000 + closed_bar_utc.day_of_year;
   if(day_key != g_cached_range_day)
   {
      g_cached_range_day = day_key;
      g_cached_range_high = 0.0;
      g_cached_range_low = 0.0;
      StrategyRestoreDailyTradeState(closed_rates[0].time);
   }

   g_cached_atr_1 = atr;
   g_cached_close_1 = closed_rates[0].close;

   const int bar_minute = StrategyMinutes(closed_bar_utc.hour, closed_bar_utc.min);
   g_cached_bar_minute_utc = bar_minute;
   const int entry_start = StrategyMinutes(InpEntryStartHourUTC, InpEntryStartMinUTC);
   const int entry_end = StrategyMinutes(InpEntryEndHourUTC, InpEntryEndMinUTC);
   if(bar_minute >= entry_start && bar_minute < entry_end &&
      (g_cached_range_high <= 0.0 || g_cached_range_low <= 0.0))
      StrategyBuildRange(closed_bar_utc);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   StrategyRefreshDailyEntryHalt(false);
   if(g_daily_entry_halt)
      return true;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) >= 1)
      return true;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime dt;
   TimeToStruct(utc_now, dt);
   const int minute_of_day = StrategyMinutes(dt.hour, dt.min);
   if(minute_of_day >= 1435 || minute_of_day < 5)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask > bid && g_cached_atr_1 > 0.0 &&
      (ask - bid) > InpSpreadAtrMult * g_cached_atr_1)
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
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   if(g_cached_traded || g_cached_range_high <= 0.0 || g_cached_range_low <= 0.0 ||
      g_cached_atr_1 <= 0.0 || g_cached_close_1 <= 0.0)
      return false;

   const int entry_start = StrategyMinutes(InpEntryStartHourUTC, InpEntryStartMinUTC);
   const int entry_end = StrategyMinutes(InpEntryEndHourUTC, InpEntryEndMinUTC);
   if(g_cached_bar_minute_utc < entry_start || g_cached_bar_minute_utc >= entry_end)
      return false;

   const double min_atr_dist = QM_StopRulesPipsToPriceDistance(
      _Symbol, (int)MathRound(InpMinAtrPips));
   const double buffer_dist = QM_StopRulesPipsToPriceDistance(
      _Symbol, (int)MathRound(InpBufferPips));
   if(min_atr_dist <= 0.0 || buffer_dist < 0.0 || g_cached_atr_1 < min_atr_dist)
      return false;

   const double range_midpoint = QM_StopRulesNormalizePrice(
      _Symbol, (g_cached_range_high + g_cached_range_low) * 0.5);
   const double range_width = g_cached_range_high - g_cached_range_low;
   if(range_midpoint <= 0.0 || range_width <= 0.0)
      return false;

   if(g_cached_close_1 > g_cached_range_high + buffer_dist)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double tp = QM_StopRulesNormalizePrice(
         _Symbol, ask + InpRrMultiplier * range_width);
      if(ask <= range_midpoint || tp <= ask)
         return false;

      req.type = QM_BUY;
      req.price = ask;
      req.sl = range_midpoint;
      req.tp = tp;
      req.reason = "41011_handover_buy";
      return true;
   }

   if(g_cached_close_1 < g_cached_range_low - buffer_dist)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double tp = QM_StopRulesNormalizePrice(
         _Symbol, bid - InpRrMultiplier * range_width);
      if(bid <= 0.0 || bid >= range_midpoint || tp <= 0.0 || tp >= bid)
         return false;

      req.type = QM_SELL;
      req.price = bid;
      req.sl = range_midpoint;
      req.tp = tp;
      req.reason = "41011_handover_sell";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   MqlDateTime utc_now;
   TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc_now);
   return utc_now.hour >= InpTimeStopHourUTC;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!StrategyInputsValid())
      return INIT_PARAMETERS_INCORRECT;

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

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const int deviation_points = (point > 0.0 && tick_size > 0.0)
      ? (int)MathFloor((InpMaxSlippageTicks * tick_size / point) + 1e-9)
      : 0;
   if(deviation_points < 1)
      return INIT_FAILED;

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_M15,
         QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
         "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         InpDailyDrawdownHardStopPct,
                         InpTotalDrawdownStopPct,
                         1.0))
      return INIT_FAILED;

   StrategyRefreshDailyEntryHalt(true);
   g_cached_range_day = StrategyUtcDayKey(TimeCurrent());
   StrategyRestoreDailyTradeState(TimeCurrent());

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_M15))
      return;
   QM_EquityStreamOnNewBar();
   AdvanceState_OnNewBar();

   // No-trade and news policies gate NEW entries only. Mandatory management,
   // time stops and Friday close have already run above.
   if(Strategy_NoTradeFilter())
      return;
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(
         _Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(
         _Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket) && out_ticket > 0)
         g_cached_traded = true;
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
   StrategyRefreshDailyEntryHalt(true);
   StrategyRestoreDailyTradeState(TimeCurrent());
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
