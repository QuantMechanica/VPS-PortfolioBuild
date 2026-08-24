#property strict
#property version   "5.0"
#property description "QM5_41005 Richard Donchian 50-Day CTA Benchmark"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41005
// Richard Donchian 50-Day CTA Trend Following Benchmark
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41005;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    InpEntryLookback           = 50;     // Donchian entry breakout bars
input int    InpExitLookback            = 20;     // Donchian exit channel bars
input int    InpAtrPeriod               = 20;     // ATR period for stop loss
input double InpAtrSlMult               = 3.0;    // ATR stop loss multiplier
input double InpSpreadAtrMult           = 1.8;    // Max spread as multiple of D1 ATR(14)
input double InpDailyLossEntryHaltPct   = 2.0;    // Account realised-loss entry halt
input double InpDailyHardStopPct        = 2.5;    // Daily equity-loss hard stop
input double InpTotalDrawdownStopPct    = 5.0;    // Portfolio drawdown hard stop

double g_spread_atr       = 0.0;
double g_stop_atr         = 0.0;
int    g_entry_breakout   = 0;
int    g_exit_breakout    = 0;
bool   g_state_ready      = false;
int    g_daily_loss_day   = -1;
bool   g_daily_entry_halt = true;

int StrategyDayKey(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
}

datetime StrategyDayStart(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

void StrategyRefreshDailyEntryHalt(const bool force_refresh)
{
   const datetime now = TimeCurrent();
   const int day_key = StrategyDayKey(now);
   if(!force_refresh && day_key == g_daily_loss_day)
      return;

   g_daily_loss_day = day_key;
   g_daily_entry_halt = true;
   const datetime day_start = StrategyDayStart(now);
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
   g_daily_entry_halt = (realised <= -(InpDailyLossEntryHaltPct / 100.0) * day_start_balance);
}

bool CalculateDonchianBreakout(const MqlRates &rates[],
                               const int lookback,
                               int &breakout)
{
   breakout = 0;
   const int required = lookback + 1;
   if(lookback < 1 || ArraySize(rates) < required)
      return false;

   double channel_high = -DBL_MAX;
   double channel_low = DBL_MAX;
   for(int i = 1; i <= lookback; ++i)
   {
      channel_high = MathMax(channel_high, rates[i].high);
      channel_low = MathMin(channel_low, rates[i].low);
   }

   const double closed_price = rates[0].close;
   if(closed_price <= 0.0 || channel_high == -DBL_MAX || channel_low == DBL_MAX)
      return false;
   if(closed_price > channel_high)
      breakout = 1;
   else if(closed_price < channel_low)
      breakout = -1;
   return true;
}

void AdvanceState_OnNewBar()
{
   g_spread_atr = 0.0;
   g_stop_atr = 0.0;
   g_entry_breakout = 0;
   g_exit_breakout = 0;
   g_state_ready = false;

   if(InpEntryLookback < 1 || InpExitLookback < 1 || InpAtrPeriod < 1)
      return;

   const int max_lookback = (InpEntryLookback > InpExitLookback) ? InpEntryLookback : InpExitLookback;
   const int required = max_lookback + 1;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, required, rates); // perf-allowed: one bounded new-bar-only channel buffer
   if(copied != required || ArraySize(rates) < required)
      return;

   const double spread_atr = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
   const double stop_atr = QM_ATR(_Symbol, PERIOD_D1, InpAtrPeriod, 1);
   if(spread_atr <= 0.0 || stop_atr <= 0.0)
      return;

   g_spread_atr = spread_atr;
   g_stop_atr = stop_atr;
   if(!CalculateDonchianBreakout(rates, InpEntryLookback, g_entry_breakout) ||
      !CalculateDonchianBreakout(rates, InpExitLookback, g_exit_breakout))
      return;
   g_state_ready = true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   StrategyRefreshDailyEntryHalt(false);
   if(g_daily_entry_halt)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      if(g_spread_atr > 0.0 && (ask - bid) > InpSpreadAtrMult * g_spread_atr)
         return true;
   }

   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(TimeCurrent()), dt);
   if((dt.hour == 23 && dt.min >= 55) || (dt.hour == 0 && dt.min < 5))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_state_ready)
      return false;

   const int brk = g_entry_breakout;
   if(brk == 0)
      return false;

   if(g_stop_atr <= 0.0)
      return false;

   if(brk > 0)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - InpAtrSlMult * g_stop_atr);
      req.tp = 0.0;
      req.reason = "DONCHIAN50_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }
   else if(brk < 0)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bid + InpAtrSlMult * g_stop_atr);
      req.tp = 0.0;
      req.reason = "DONCHIAN50_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   if(!g_state_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_exit_breakout < 0)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_exit_breakout > 0)
         return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(InpEntryLookback < 30 || InpEntryLookback > 80 ||
      InpExitLookback < 10 || InpExitLookback > 30 ||
      InpAtrPeriod < 1 || InpAtrSlMult <= 0.0 || InpSpreadAtrMult <= 0.0 ||
      InpDailyLossEntryHaltPct <= 0.0 || InpDailyLossEntryHaltPct > 100.0 ||
      InpDailyHardStopPct <= 0.0 || InpDailyHardStopPct > 100.0 ||
      InpTotalDrawdownStopPct <= 0.0 || InpTotalDrawdownStopPct > 100.0)
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                          QM_FrameworkMagic(),
                          InpDailyHardStopPct,
                          InpTotalDrawdownStopPct,
                          1.0))
      return INIT_FAILED;

   StrategyRefreshDailyEntryHalt(true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_41005\",\"ea\":\"richard-donchian-50day-cta-benchmark\"}");
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

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
   {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
   }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!is_new_bar) return;
   if(Strategy_NoTradeFilter()) return;
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
   StrategyRefreshDailyEntryHalt(true);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
