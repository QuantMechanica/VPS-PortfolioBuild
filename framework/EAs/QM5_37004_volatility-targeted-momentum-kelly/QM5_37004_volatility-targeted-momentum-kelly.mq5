#property strict
#property version   "5.0"
#property description "QM5_37004 Volatility-Targeted Momentum with Half-Kelly Sizing (Marcos Lopez de Prado)"
// Strategy Card: QM5_37004 (volatility-targeted-momentum-kelly), G0 APPROVED.
// Source: Lopez de Prado, M. (2018). Advances in Financial Machine Learning. Backtrader Engine.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37004 — Volatility-Targeted Momentum
// -----------------------------------------------------------------------------
// Evaluates 12-month (252-day) momentum and 200-day SMA on D1 closed bars:
//   - Long Entry:  Momentum_12M[1] > 0 AND Close[1] > SMA(200, D1)[1]
//   - Short Entry: Momentum_12M[1] < 0 AND Close[1] < SMA(200, D1)[1]
//   - Stop Loss:   2.0 * ATR(14, D1)[1]
//   - Management:  Trailing Chandelier ATR stop at 3.0 * ATR(14, D1)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37004;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

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
input double strategy_vol_target_pct      = 10.0;   // Card InpVolTargetPct: annualized target volatility
input int    strategy_momentum_days       = 252;    // Card InpMomentumDays: exponential D1 momentum span
input double strategy_kelly_fraction      = 0.50;   // Card InpKellyFraction: fractional-Kelly multiplier
input double strategy_base_risk_percent   = 0.50;   // Card InpRiskPercent: live risk ceiling
input int    strategy_sma_period          = 200;    // Trend baseline SMA period
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 2.00;   // Stop loss ATR multiplier
input double strategy_trail_atr_mult      = 3.00;   // Chandelier trailing ATR multiplier
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input double strategy_daily_loss_halt_pct = 2.00;   // Realized-loss entry halt
input double strategy_daily_hard_stop_pct = 2.50;   // Daily equity hard stop
input double strategy_total_dd_halt_pct   = 5.00;   // Total drawdown hard stop
input double strategy_max_slippage_ticks  = 3.00;   // Market-order slippage ceiling in ticks

// -----------------------------------------------------------------------------
// Cached State
// -----------------------------------------------------------------------------

const int    STRATEGY_VOL_LOOKBACK_DAYS = 20;
const int    STRATEGY_MAX_MOMENTUM_DAYS = 300;
const double STRATEGY_WIN_PROBABILITY   = 0.685;
const double STRATEGY_REWARD_RISK       = 2.5;

double g_cached_close1          = 0.0;
double g_cached_atr1            = 0.0;
double g_cached_sma200          = 0.0;
double g_cached_momentum        = 0.0;
double g_cached_annual_vol      = 0.0;
double g_cached_position_weight = 0.0;
double g_strategy_initial_equity = 0.0;
bool   g_cached_state_valid     = false;

bool Strategy_ConfigValid()
{
   if(strategy_vol_target_pct < 5.0 || strategy_vol_target_pct > 15.0 ||
      strategy_momentum_days < 100 || strategy_momentum_days > STRATEGY_MAX_MOMENTUM_DAYS ||
      strategy_kelly_fraction < 0.25 || strategy_kelly_fraction > 0.75 ||
      strategy_base_risk_percent < 0.20 || strategy_base_risk_percent > 1.00)
      return false;
   if(strategy_sma_period <= 1 || strategy_atr_period <= 1 ||
      strategy_sl_atr_mult <= 0.0 || strategy_trail_atr_mult <= 0.0 ||
      strategy_spread_atr_mult <= 0.0 || strategy_max_slippage_ticks <= 0.0 ||
      strategy_max_slippage_ticks > 3.0)
      return false;
   if(MathAbs(strategy_daily_loss_halt_pct - 2.0) > 1e-8 ||
      MathAbs(strategy_daily_hard_stop_pct - 2.5) > 1e-8 ||
      MathAbs(strategy_total_dd_halt_pct - 5.0) > 1e-8)
      return false;
   return true;
}

bool AdvanceState_OnNewBar()
{
   g_cached_state_valid = false;
   g_cached_close1 = 0.0;
   g_cached_momentum = 0.0;
   g_cached_annual_vol = 0.0;
   g_cached_position_weight = 0.0;

   g_cached_atr1   = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   g_cached_sma200 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   if(g_cached_atr1 <= 0.0 || g_cached_sma200 <= 0.0)
      return false;

   const int return_count = MathMax(strategy_momentum_days, STRATEGY_VOL_LOOKBACK_DAYS);
   const int close_count = return_count + 1;
   if(close_count < 2 || close_count > STRATEGY_MAX_MOMENTUM_DAYS + 1)
      return false;

   double closes[];
   if(ArrayResize(closes, close_count) != close_count)
      return false;
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, close_count, closes); // perf-allowed: one bounded closed-D1 read per new bar for the card momentum and volatility estimators.
   if(copied != close_count || ArraySize(closes) < close_count)
      return false;
   for(int i = 0; i < close_count; ++i)
      if(closes[i] <= 0.0 || !MathIsValidNumber(closes[i]))
         return false;

   g_cached_close1 = closes[0];

   // Standard exponential span weights: the newest closed-bar log return has
   // weight 1 and each older return decays by (1 - 2/(span+1)).
   const double alpha = 2.0 / ((double)strategy_momentum_days + 1.0);
   const double decay = 1.0 - alpha;
   double momentum_weight = 1.0;
   double momentum_weight_sum = 0.0;
   double weighted_log_return = 0.0;
   for(int i = 0; i < strategy_momentum_days; ++i)
   {
      if(i >= ArraySize(closes))
         return false;
      const double log_return = MathLog(closes[i] / closes[i + 1]);
      weighted_log_return += momentum_weight * log_return;
      momentum_weight_sum += momentum_weight;
      momentum_weight *= decay;
   }
   if(momentum_weight_sum <= 0.0)
      return false;
   g_cached_momentum = weighted_log_return / momentum_weight_sum;

   double mean_return = 0.0;
   for(int i = 0; i < STRATEGY_VOL_LOOKBACK_DAYS; ++i)
   {
      if(i >= ArraySize(closes))
         return false;
      mean_return += MathLog(closes[i] / closes[i + 1]);
   }
   mean_return /= (double)STRATEGY_VOL_LOOKBACK_DAYS;

   double squared_deviation_sum = 0.0;
   for(int i = 0; i < STRATEGY_VOL_LOOKBACK_DAYS; ++i)
   {
      if(i >= ArraySize(closes))
         return false;
      const double log_return = MathLog(closes[i] / closes[i + 1]);
      const double deviation = log_return - mean_return;
      squared_deviation_sum += deviation * deviation;
   }
   g_cached_annual_vol = MathSqrt(squared_deviation_sum /
                                  (double)(STRATEGY_VOL_LOOKBACK_DAYS - 1)) *
                         MathSqrt(252.0);
   if(g_cached_annual_vol <= 0.0 || !MathIsValidNumber(g_cached_annual_vol))
      return false;

   const double full_kelly = STRATEGY_WIN_PROBABILITY -
                             (1.0 - STRATEGY_WIN_PROBABILITY) / STRATEGY_REWARD_RISK;
   const double fractional_kelly = strategy_kelly_fraction * full_kelly;
   g_cached_position_weight = ((strategy_vol_target_pct / 100.0) /
                               g_cached_annual_vol) * fractional_kelly;
   if(g_cached_position_weight <= 0.0 || !MathIsValidNumber(g_cached_position_weight))
      return false;

   g_cached_state_valid = true;
   return true;
}

bool IsRolloverBlackout()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day <= 5)
      return true;
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return true;

   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   if(realized_pnl <= -(day_start_balance * strategy_daily_loss_halt_pct / 100.0))
      return true;

   if(IsRolloverBlackout())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      if(g_cached_atr1 > 0.0 && (ask - bid) > (strategy_spread_atr_mult * g_cached_atr1))
         return true;
   }
   return false;
}

bool Strategy_ResolveScaledRisk(QM_RiskMode &risk_mode, double &risk_value)
{
   risk_mode = QM_RISK_MODE_UNSET;
   risk_value = 0.0;
   if(!g_cached_state_valid || g_cached_position_weight <= 0.0)
      return false;

   if(RISK_FIXED > 0.0 && RISK_PERCENT == 0.0)
   {
      risk_mode = QM_RISK_MODE_FIXED;
      risk_value = RISK_FIXED * g_cached_position_weight;
   }
   else if(RISK_PERCENT > 0.0 && RISK_FIXED == 0.0)
   {
      risk_mode = QM_RISK_MODE_PERCENT;
      risk_value = MathMin(RISK_PERCENT, strategy_base_risk_percent) *
                   g_cached_position_weight;
   }
   return (risk_value > 0.0 && MathIsValidNumber(risk_value));
}

bool Strategy_EnforceTotalDrawdownStop()
{
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_strategy_initial_equity <= 0.0 || equity_now <= 0.0)
      return false;
   const double drawdown_pct = (g_strategy_initial_equity - equity_now) /
                               g_strategy_initial_equity * 100.0;
   if(drawdown_pct < strategy_total_dd_halt_pct)
      return true;

   if(!QM_KillSwitchIsHalted())
      QM_KillSwitchTrip(KS_PORTFOLIO_DD,
                        StringFormat("{\"initial_equity\":%.2f,\"equity_now\":%.2f,\"drawdown_pct\":%.6f,\"halt_pct\":%.6f}",
                                     g_strategy_initial_equity,
                                     equity_now,
                                     drawdown_pct,
                                     strategy_total_dd_halt_pct));
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_cached_state_valid || g_cached_sma200 <= 0.0)
      return false;

   if(g_cached_close1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Long: Momentum_12M > 0 AND Close[1] > SMA(200, D1)[1]
   if(g_cached_momentum > 0.0 && g_cached_close1 > g_cached_sma200)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_37004_MOM_BUY";
      req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
   }
   // Short: Momentum_12M < 0 AND Close[1] < SMA(200, D1)[1]
   else if(g_cached_momentum < 0.0 && g_cached_close1 < g_cached_sma200)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_37004_MOM_SELL";
      req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_sl_atr_mult);
   }
   else
   {
      return false;
   }

   if(req.sl <= 0.0)
      return false;

   return true;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
   }
}

bool Strategy_ExitSignal()
{
   return false;
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
   if(!Strategy_ConfigValid())
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

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_base_risk_percent))
      return INIT_FAILED;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return INIT_FAILED;
   const int deviation_points = (int)MathCeil(strategy_max_slippage_ticks *
                                               tick_size / point);
   if(deviation_points <= 0)
      return INIT_FAILED;
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   g_strategy_initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_strategy_initial_equity <= 0.0 || !AdvanceState_OnNewBar())
      return INIT_FAILED;

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

   if(!Strategy_EnforceTotalDrawdownStop())
      return;
   if(!QM_KillSwitchCheck())
      return;

   if(QM_FrameworkHandleFridayClose())
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   if(!AdvanceState_OnNewBar())
      return;

   QM_EquityStreamOnNewBar();

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

   if(Strategy_NoTradeFilter())
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_RiskMode risk_mode = QM_RISK_MODE_UNSET;
      double risk_value = 0.0;
      if(Strategy_ResolveScaledRisk(risk_mode, risk_value))
         QM_TM_OpenPosition(req, out_ticket, 0, risk_mode, risk_value);
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
