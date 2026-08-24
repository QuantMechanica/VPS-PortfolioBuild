#property strict
#property version   "5.0"
#property description "QM5_41006 Man AHL Multi-Speed EWMA Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41006
// Man AHL Multi-Speed EWMA Composite Trend Engine
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41006;
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
input double InpForecastThreshold       = 0.35;   // Minimum composite score threshold to enter
input int    InpVolWindow               = 60;     // Realized close-return volatility window
input int    InpAtrSlPeriod             = 14;     // Stop loss ATR period
input double InpAtrSlMult               = 2.5;    // Stop loss ATR multiplier
input double InpSpreadAtrMult           = 1.8;    // Max spread as multiple of D1 ATR(14)
input double InpDailyLossEntryHaltPct    = 2.0;    // Account realised-loss entry halt
input double InpDailyHardStopPct         = 2.5;    // Daily equity-loss hard stop
input double InpTotalDrawdownStopPct     = 5.0;    // Portfolio drawdown hard stop

double g_forecast1         = 0.0;
double g_forecast2         = 0.0;
double g_stop_atr          = 0.0;
double g_spread_atr        = 0.0;
bool   g_forecast_ready    = false;
bool   g_rebalance_due     = false;
bool   g_rebalance_entries_allowed = false;
int    g_rebalance_pending_direction = 0;
int    g_daily_loss_day    = -1;
bool   g_daily_entry_halt  = true;

// -----------------------------------------------------------------------------
// Helper math
// -----------------------------------------------------------------------------

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

// Sample standard deviation of D1 close-to-close returns, converted back to
// price units so it is dimensionally compatible with the EWMA price spread.
// One bounded buffer serves both required shifts and is loaded only on a new bar.
bool LoadRealizedVolatilityCloses(double &closes[])
{
   const int required = InpVolWindow + 2;
   if(required < 4)
      return false;

   ArrayResize(closes, required);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, required, closes); // perf-allowed: one bounded new-bar-only volatility buffer
   return (copied == required && ArraySize(closes) >= required);
}

bool CalculateRealizedVolatility(const double &closes[], const int offset, double &sigma)
{
   sigma = 0.0;
   const int required = offset + InpVolWindow + 1;
   if(InpVolWindow < 2 || offset < 0 || ArraySize(closes) < required)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   for(int i = 0; i < InpVolWindow; ++i)
   {
      const double c0 = closes[offset + i];
      const double c1 = closes[offset + i + 1];
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;
      const double daily_return = c0 / c1 - 1.0;
      if(!MathIsValidNumber(daily_return))
         return false;
      sum += daily_return;
      sum_sq += daily_return * daily_return;
   }

   const double n = (double)InpVolWindow;
   double variance = (sum_sq - (sum * sum) / n) / (n - 1.0);
   if(variance < 0.0 && variance > -1e-12)
      variance = 0.0;
   if(variance <= 0.0 || !MathIsValidNumber(variance))
      return false;

   sigma = closes[offset] * MathSqrt(variance);
   return (sigma > 0.0 && MathIsValidNumber(sigma));
}

bool CalculateForecast(const int shift, const double sigma, double &forecast)
{
   forecast = 0.0;
   if(shift < 1 || sigma <= 0.0 || !MathIsValidNumber(sigma))
      return false;

   const int pairs_fast[6] = {2, 4, 8, 16, 32, 64};
   const int pairs_slow[6] = {8, 16, 32, 64, 128, 256};

   double sum = 0.0;
   for(int k = 0; k < 6; ++k)
   {
      const double ema_f = QM_EMA(_Symbol, PERIOD_D1, pairs_fast[k], shift);
      const double ema_s = QM_EMA(_Symbol, PERIOD_D1, pairs_slow[k], shift);
      if(ema_f <= 0.0 || ema_s <= 0.0 ||
         !MathIsValidNumber(ema_f) || !MathIsValidNumber(ema_s))
         return false;
      sum += (ema_f - ema_s) / sigma;
   }

   forecast = sum / 6.0;
   forecast = MathMax(-1.0, MathMin(1.0, forecast));
   return MathIsValidNumber(forecast);
}

void AdvanceState_OnNewBar()
{
   g_forecast1 = 0.0;
   g_forecast2 = 0.0;
   g_stop_atr = 0.0;
   g_spread_atr = 0.0;
   g_forecast_ready = false;
   g_rebalance_due = true;

   double closes[];
   if(!LoadRealizedVolatilityCloses(closes))
      return;

   double sigma1 = 0.0;
   double sigma2 = 0.0;
   if(!CalculateRealizedVolatility(closes, 0, sigma1) ||
      !CalculateRealizedVolatility(closes, 1, sigma2))
      return;

   double forecast1 = 0.0;
   double forecast2 = 0.0;
   if(!CalculateForecast(1, sigma1, forecast1) ||
      !CalculateForecast(2, sigma2, forecast2))
      return;

   const double stop_atr = QM_ATR(_Symbol, PERIOD_D1, InpAtrSlPeriod, 1);
   const double spread_atr = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
   if(stop_atr <= 0.0 || spread_atr <= 0.0)
      return;

   g_forecast1 = forecast1;
   g_forecast2 = forecast2;
   g_stop_atr = stop_atr;
   g_spread_atr = spread_atr;
   g_forecast_ready = true;
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
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   TimeToStruct(utc_now, dt);
   if((dt.hour == 23 && dt.min >= 55) || (dt.hour == 0 && dt.min < 5))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_forecast_ready || g_stop_atr <= 0.0)
      return false;

   const double s1 = g_forecast1;
   const double s2 = g_forecast2;
   if(g_rebalance_pending_direction != 0 &&
      ((g_rebalance_pending_direction > 0 && s1 <= 0.0) ||
       (g_rebalance_pending_direction < 0 && s1 >= 0.0)))
      g_rebalance_pending_direction = 0;

   // Long: S_t crosses above +InpForecastThreshold
   if((s1 >= InpForecastThreshold && s2 < InpForecastThreshold) ||
      (g_rebalance_pending_direction > 0 && s1 > 0.0))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - InpAtrSlMult * g_stop_atr);
      req.tp = 0.0;
      req.reason = "MAN_AHL_EWMA_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_rebalance_pending_direction = 1;
      return true;
   }

   // Short: S_t crosses below -InpForecastThreshold
   if((s1 <= -InpForecastThreshold && s2 > -InpForecastThreshold) ||
      (g_rebalance_pending_direction < 0 && s1 < 0.0))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bid + InpAtrSlMult * g_stop_atr);
      req.tp = 0.0;
      req.reason = "MAN_AHL_EWMA_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_rebalance_pending_direction = -1;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   if(!g_rebalance_due)
      return;
   g_rebalance_due = false;

   if(!g_forecast_ready)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool same_direction = (ptype == POSITION_TYPE_BUY && g_forecast1 > 0.0) ||
                                  (ptype == POSITION_TYPE_SELL && g_forecast1 < 0.0);
      // A same-direction resize requires an immediate framework-governed
      // reopen. If entry gates are closed, retain the current exposure until
      // the next D1 rebalance instead of liquidating it accidentally.
      if(same_direction && !g_rebalance_entries_allowed)
         continue;

      if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
         g_rebalance_pending_direction = same_direction
            ? (g_forecast1 > 0.0 ? 1 : -1)
            : 0;
   }
}

bool Strategy_ExitSignal()
{
   // Forecast-driven close/reopen sizing is handled once per D1 bar in the
   // management hook, so no separate fixed liquidation rule is added here.
   return false;
}

bool Strategy_OpenAtForecastRisk(const QM_EntryRequest &req)
{
   const double exposure = MathMin(1.0, MathAbs(g_forecast1));
   if(exposure <= 0.0)
      return false;

   QM_RiskMode risk_mode = QM_RISK_MODE_UNSET;
   double risk_value = 0.0;
   if(RISK_FIXED > 0.0 && RISK_PERCENT == 0.0)
   {
      risk_mode = QM_RISK_MODE_FIXED;
      risk_value = RISK_FIXED * exposure;
   }
   else if(RISK_PERCENT > 0.0 && RISK_FIXED == 0.0)
   {
      risk_mode = QM_RISK_MODE_PERCENT;
      risk_value = RISK_PERCENT * exposure;
   }
   else
      return false;

   ulong out_ticket = 0;
   const bool opened = QM_TM_OpenPosition(req, out_ticket, 0, risk_mode, risk_value);
   if(opened)
      g_rebalance_pending_direction = 0;
   return opened;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(InpForecastThreshold <= 0.0 || InpForecastThreshold > 1.0 ||
      InpVolWindow < 2 || InpAtrSlPeriod < 1 || InpAtrSlMult <= 0.0 ||
      InpSpreadAtrMult <= 0.0 || InpDailyLossEntryHaltPct <= 0.0 ||
      InpDailyHardStopPct <= 0.0 || InpTotalDrawdownStopPct <= 0.0)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_41006\",\"ea\":\"man-ahl-multispeed-ewma-trend\"}");
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

   const bool strategy_blocks_entry = Strategy_NoTradeFilter();
   const bool custom_news_blocks_entry = Strategy_NewsFilterHook(broker_now);

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);

   g_rebalance_entries_allowed =
      (!strategy_blocks_entry && !custom_news_blocks_entry && news_allows);

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

   QM_EntryRequest req;
   ZeroMemory(req);
   const bool entry_requested =
      (is_new_bar || g_rebalance_pending_direction != 0) && Strategy_EntrySignal(req);

   if(!g_rebalance_entries_allowed)
      return;

   if(entry_requested)
      Strategy_OpenAtForecastRisk(req);
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
