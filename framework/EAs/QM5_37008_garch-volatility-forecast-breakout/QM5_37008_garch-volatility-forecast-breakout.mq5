#property strict
#property version   "5.0"
#property description "QM5_37008 GARCH(1,1) Volatility Forecast Breakout Engine"
// Strategy Card: QM5_37008 (garch-volatility-forecast-breakout), G0 APPROVED.
// Source: Engle, R. (1982). Autoregressive Conditional Heteroskedasticity.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37008 — GARCH(1,1) Volatility Forecast Breakout Engine
// -----------------------------------------------------------------------------
// Evaluates rolling GARCH(1,1) variance forecast sigma_{t+1}^2 on D1 closed bars:
//   - sigma_{t+1}^2 = omega + alpha * eps_t^2 + beta * sigma_t^2
//   - Cone = Open[1] +/- 1.50 * sigma_{t+1}
//   - Trend Filter = SMA(50, D1)[1]
//   - Long Entry:  Close[1] > Open[1] + 1.50 * sigma_{t+1} AND Close[1] > SMA(50, D1)[1] -> BUY
//   - Short Entry: Close[1] < Open[1] - 1.50 * sigma_{t+1} AND Close[1] < SMA(50, D1)[1] -> SELL
//   - SL = 1.0 * sigma_{t+1}, TP = 2.0 * SL_Distance (1:2.0 R:R)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37008;
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
input double strategy_omega               = 0.00001; // GARCH constant variance parameter
input double strategy_alpha               = 0.08;    // ARCH shock persistence parameter
input double strategy_beta                = 0.90;    // GARCH lagged variance persistence parameter
input double strategy_cone_multiplier     = 1.50;    // Volatility breakout cone multiplier
input int    strategy_trend_sma_period    = 50;      // Trend filter baseline SMA period
input int    strategy_atr_period          = 14;      // ATR period for spread filter
input double strategy_sl_sigma_mult       = 1.00;    // Stop loss sigma multiplier
input double strategy_tp_rr_mult          = 2.00;    // Take profit R:R multiplier
input double strategy_spread_atr_mult     = 1.80;    // Spread filter ATR multiplier
input int    strategy_max_slippage_ticks  = 3;       // Card maximum market-order deviation
input double strategy_daily_loss_halt_pct = 2.0;     // Account realized-loss entry halt
input double strategy_daily_hard_stop_pct = 2.5;     // Restart-safe daily equity stop
input double strategy_total_dd_halt_pct   = 5.0;     // Account-level total-DD stop
input double strategy_per_trade_risk_cap_pct = 0.5;  // Framework per-trade risk cap

const int STRATEGY_UNIVERSE_SIZE = 3;
string g_universe_symbols[3] = {"SP500.DWX", "NDX.DWX", "XAUUSD.DWX"};
int g_universe_slots[3] = {0, 1, 2};

// -----------------------------------------------------------------------------
// Cached State
// -----------------------------------------------------------------------------

double g_cached_sigma_price = 0.0;
double g_cached_trend_sma   = 0.0;
double g_cached_atr1        = 0.0;
double g_cached_open1       = 0.0;
double g_cached_close1      = 0.0;
bool   g_cached_valid       = false;

int Strategy_SymbolSlot()
{
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
   {
      if(g_universe_symbols[i] == _Symbol)
         return g_universe_slots[i];
   }
   return qm_magic_slot_offset;
}

bool Strategy_ConfigValid()
{
   if(strategy_omega <= 0.0 || strategy_alpha < 0.0 || strategy_beta < 0.0 ||
      (strategy_alpha + strategy_beta) >= 1.0)
      return false;
   if(strategy_cone_multiplier <= 0.0 || strategy_trend_sma_period < 2 ||
      strategy_atr_period < 2 || strategy_sl_sigma_mult <= 0.0 ||
      strategy_tp_rr_mult <= 0.0 || strategy_spread_atr_mult <= 0.0 ||
      strategy_max_slippage_ticks <= 0)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_total_dd_halt_pct <= 0.0)
      return false;
   return (strategy_per_trade_risk_cap_pct > 0.0 &&
           strategy_per_trade_risk_cap_pct <= 1.0);
}

int Strategy_DeviationPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return strategy_max_slippage_ticks;
   return (int)MathMax(1.0,
                       MathCeil(strategy_max_slippage_ticks * tick_size / point));
}

double ComputeGarchSigma(const double &closes[], const int total_bars)
{
   const int close_count = ArraySize(closes);
   if(total_bars < 50 || total_bars > 100 || close_count < total_bars)
      return 0.0;

   // 1. Compute closed-bar daily simple returns
   int ret_count = total_bars - 1;
   double rets[];
   if(ArrayResize(rets, ret_count) != ret_count)
      return 0.0;
   for(int i = 0; i < ret_count; ++i)
   {
      if(closes[i + 1] > 0.0 && closes[i] > 0.0)
         rets[i] = (closes[i] - closes[i + 1]) / closes[i + 1];
      else
         rets[i] = 0.0;
   }

   // 2. Unconditional sample variance as initialization
   double sum_sq = 0.0;
   int init_sample = MathMin(30, ret_count);
   for(int i = ret_count - 1; i >= ret_count - init_sample; --i)
   {
      if(i < 0 || i >= ArraySize(rets))
         return 0.0;
      sum_sq += rets[i] * rets[i];
   }
   double h = sum_sq / (double)init_sample;
   if(h <= 0.0) h = 0.0001;

   // 3. Forward recursion through time (from oldest to most recent [0] which is bar 1)
   for(int i = ret_count - init_sample - 1; i >= 0; --i)
   {
      double eps_sq = rets[i + 1] * rets[i + 1];
      h = strategy_omega + strategy_alpha * eps_sq + strategy_beta * h;
   }

   // 4. One-step ahead forecast from bar 1
   double eps_1_sq = rets[0] * rets[0];
   double h_forecast = strategy_omega + strategy_alpha * eps_1_sq + strategy_beta * h;
   if(h_forecast <= 0.0) return 0.0;

   double sigma_pct = MathSqrt(h_forecast);
   return sigma_pct * closes[0];
}

void AdvanceState_OnNewBar()
{
   g_cached_atr1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   g_cached_trend_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_sma_period, 1, PRICE_CLOSE);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied_rates = CopyRates(_Symbol, PERIOD_D1, 1, 1, rates); // perf-allowed: one closed D1 bar, read once at init and thereafter behind the D1 new-bar gate.
   if(copied_rates != 1 || ArraySize(rates) < copied_rates)
   {
      g_cached_valid = false;
      return;
   }
   g_cached_open1  = rates[0].open;
   g_cached_close1 = rates[0].close;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int lookback = 100;
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, lookback, closes); // perf-allowed: bounded GARCH warmup, read once at init and thereafter behind the D1 new-bar gate.
   if(copied < 50 || copied > lookback || ArraySize(closes) < copied)
   {
      g_cached_valid = false;
      return;
   }

   g_cached_sigma_price = ComputeGarchSigma(closes, copied);
   g_cached_valid = (g_cached_sigma_price > 0.0 && g_cached_trend_sma > 0.0 && g_cached_atr1 > 0.0);
}

bool IsRolloverBlackout()
{
   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(TimeCurrent()), dt);
   int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day <= 5)
      return true;
   return false;
}

bool Strategy_DailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   return (realized_pnl <= -(day_start_balance * strategy_daily_loss_halt_pct / 100.0));
}

bool Strategy_SpreadAllowsEntry(const double ask, const double bid)
{
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || g_cached_atr1 <= 0.0)
      return false;
   return ((ask - bid) <= (strategy_spread_atr_mult * g_cached_atr1));
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return true;

   if(Strategy_DailyRealizedLossHalt())
      return true;

   if(IsRolloverBlackout())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!Strategy_SpreadAllowsEntry(ask, bid))
      return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = Strategy_SymbolSlot();
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_cached_valid)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // Recheck immediately before constructing an entry so admission is bound to
   // the refreshed ATR(14,D1)[1] and the current executable spread.
   if(!Strategy_SpreadAllowsEntry(ask, bid))
      return false;

   const double cone_distance = strategy_cone_multiplier * g_cached_sigma_price;
   const double sl_dist = strategy_sl_sigma_mult * g_cached_sigma_price;
   const double tp_dist = strategy_tp_rr_mult * sl_dist;
   if(sl_dist <= 0.0)
      return false;

   // Long Breakout: Close[1] > Open[1] + 1.50 * sigma_{t+1} AND Close[1] > SMA(50, D1)[1]
   if(g_cached_close1 > (g_cached_open1 + cone_distance) && g_cached_close1 > g_cached_trend_sma)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_37008_GARCH_BUY";
      req.sl     = ask - sl_dist;
      req.tp     = ask + tp_dist;
      return true;
   }

   // Short Breakout: Close[1] < Open[1] - 1.50 * sigma_{t+1} AND Close[1] < SMA(50, D1)[1]
   if(g_cached_close1 < (g_cached_open1 - cone_distance) && g_cached_close1 < g_cached_trend_sma)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_37008_GARCH_SELL";
      req.sl     = bid + sl_dist;
      req.tp     = bid - tp_dist;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   if(g_cached_open1 <= 0.0 || g_cached_sigma_price <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(magic <= 0 || point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double raw_sl = is_buy ? (g_cached_open1 - g_cached_sigma_price)
                                   : (g_cached_open1 + g_cached_sigma_price);
      const double target_sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
      if(target_sl <= 0.0)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5)
                                    : (target_sl < current_sl - point * 0.5));
      const bool correct_side = is_buy ? (target_sl < bid - point * 0.5)
                                       : (target_sl > ask + point * 0.5);
      if(improves && correct_side)
         QM_TM_MoveSL(ticket, target_sl, "garch_one_sigma_cone_ratchet");
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
                        Strategy_SymbolSlot(),
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

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     Strategy_DeviationPoints(),
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   AdvanceState_OnNewBar();

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

   const bool strategy_new_bar = QM_IsNewBar(_Symbol, PERIOD_D1);
   if(strategy_new_bar)
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
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!strategy_new_bar)
      return;

   if(Strategy_NewsFilterHook(broker_now))
      return;

   if(Strategy_NoTradeFilter())
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
