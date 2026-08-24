#property strict
#property version   "5.0"
#property description "QM5_37005 Dr. Ernest P. Chan Bollinger & ADX Mean Reversion"
// Strategy Card: QM5_37005 (chan-bollinger-adx-mean-reversion), G0 APPROVED.
// Source: Chan, E. P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37005 — Bollinger & ADX Mean Reversion
// -----------------------------------------------------------------------------
// Evaluates Bollinger Bands (20, 2.0) and ADX (14) on H1 closed bars:
//   - ADX < 20.0 (Stationary non-trending regime filter)
//   - Long Entry:  ADX[1] < 20.0 AND Low[1] <= LowerBB[1] AND Close[1] > Open[1]
//                  -> BUY,  SL = 1.5*ATR(14), TP = SMA(20) Midline
//   - Short Entry: ADX[1] < 20.0 AND High[1] >= UpperBB[1] AND Close[1] < Open[1]
//                  -> SELL, SL = 1.5*ATR(14), TP = SMA(20) Midline
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37005;
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
input int    strategy_bb_period           = 20;     // Bollinger Bands period
input double strategy_bb_dev              = 2.00;   // Bollinger Bands standard deviation multiplier
input int    strategy_adx_period          = 14;     // ADX period
input double strategy_max_adx             = 20.0;   // Maximum ADX ranging filter ceiling
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.50;   // Stop loss ATR multiplier
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_max_spread_points   = 100;    // Absolute spread cap in points
input double strategy_daily_loss_limit_pct          = 2.00; // Entry halt on daily realized loss
input double strategy_daily_drawdown_hard_stop_pct  = 2.50; // Daily equity hard stop
input double strategy_total_drawdown_stop_pct       = 5.00; // Total equity drawdown hard stop
input double strategy_max_slippage_ticks            = 3.00; // Market-order slippage ceiling

// -----------------------------------------------------------------------------
// Cached State
// -----------------------------------------------------------------------------

double g_cached_adx       = 0.0;
double g_cached_bb_upper  = 0.0;
double g_cached_bb_lower  = 0.0;
double g_cached_bb_middle = 0.0;
double g_cached_atr1      = 0.0;
double g_cached_open1     = 0.0;
double g_cached_high1     = 0.0;
double g_cached_low1      = 0.0;
double g_cached_close1    = 0.0;
bool   g_cached_valid     = false;
int    g_daily_loss_day   = -1;
bool   g_daily_entry_halt = true;

bool StrategyInputsValid()
{
   return (strategy_bb_period >= 14 && strategy_bb_period <= 30 &&
           strategy_bb_dev >= 1.5 && strategy_bb_dev <= 2.5 &&
           strategy_adx_period >= 7 && strategy_adx_period <= 25 &&
           strategy_max_adx >= 15.0 && strategy_max_adx <= 25.0 &&
           strategy_atr_period >= 7 && strategy_atr_period <= 30 &&
           strategy_sl_atr_mult >= 1.0 && strategy_sl_atr_mult <= 3.0 &&
           strategy_spread_atr_mult >= 1.0 && strategy_spread_atr_mult <= 3.0 &&
           strategy_max_spread_points >= 50 && strategy_max_spread_points <= 300 &&
           MathAbs(strategy_daily_loss_limit_pct - 2.0) <= 1e-9 &&
           MathAbs(strategy_daily_drawdown_hard_stop_pct - 2.5) <= 1e-9 &&
           MathAbs(strategy_total_drawdown_stop_pct - 5.0) <= 1e-9 &&
           MathAbs(strategy_max_slippage_ticks - 3.0) <= 1e-9);
}

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

// The card's 2.0% limit is account-wide daily realized P&L. Refresh at the
// broker-day boundary and after trade transactions; history failures fail closed.
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

   double realized = 0.0;
   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;
      realized += HistoryDealGetDouble(deal, DEAL_PROFIT);
      realized += HistoryDealGetDouble(deal, DEAL_SWAP);
      realized += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      realized += HistoryDealGetDouble(deal, DEAL_FEE);
   }

   const double day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE) - realized;
   if(day_start_balance <= 0.0)
      return;

   g_daily_entry_halt =
      (realized <= -(strategy_daily_loss_limit_pct / 100.0) * day_start_balance);
}

void AdvanceState_OnNewBar()
{
   // Clear every decision value before fallible reads so stale data cannot arm
   // a setup. Period-1 pooled MAs provide closed-bar OHLC without raw series calls.
   g_cached_adx = 0.0;
   g_cached_bb_upper = 0.0;
   g_cached_bb_lower = 0.0;
   g_cached_bb_middle = 0.0;
   g_cached_atr1 = 0.0;
   g_cached_open1 = 0.0;
   g_cached_high1 = 0.0;
   g_cached_low1 = 0.0;
   g_cached_close1 = 0.0;
   g_cached_valid = false;

   if(!StrategyInputsValid())
      return;

   const double adx = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   const double bb_upper = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   const double bb_lower = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   const double bb_middle = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   const double atr1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double open1 = QM_SMA(_Symbol, PERIOD_H1, 1, 1, PRICE_OPEN);
   const double high1 = QM_SMA(_Symbol, PERIOD_H1, 1, 1, PRICE_HIGH);
   const double low1 = QM_SMA(_Symbol, PERIOD_H1, 1, 1, PRICE_LOW);
   const double close1 = QM_SMA(_Symbol, PERIOD_H1, 1, 1, PRICE_CLOSE);

   if(adx <= 0.0 || bb_upper <= 0.0 || bb_lower <= 0.0 ||
      bb_middle <= 0.0 || atr1 <= 0.0 || open1 <= 0.0 ||
      high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return;

   g_cached_adx = adx;
   g_cached_bb_upper = bb_upper;
   g_cached_bb_lower = bb_lower;
   g_cached_bb_middle = bb_middle;
   g_cached_atr1 = atr1;
   g_cached_open1 = open1;
   g_cached_high1 = high1;
   g_cached_low1 = low1;
   g_cached_close1 = close1;
   g_cached_valid = true;
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
   StrategyRefreshDailyEntryHalt(false);
   if(g_daily_entry_halt)
      return true;

   if(IsRolloverBlackout())
      return true;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) >= 1)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      if(g_cached_atr1 > 0.0 && (ask - bid) > (strategy_spread_atr_mult * g_cached_atr1))
         return true;
      if(point > 0.0 && strategy_max_spread_points > 0 && (ask - bid) > (strategy_max_spread_points * point))
         return true;
   }
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

   if(!g_cached_valid)
      return false;

   // Ranging regime check: ADX < 20.0
   if(g_cached_adx >= strategy_max_adx)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double sl_dist = strategy_sl_atr_mult * g_cached_atr1;
   if(sl_dist <= 0.0)
      return false;

   // Long: reject the setup if its card-authorized SMA midline TP is not
   // beyond the current entry quote. There is no substitute target.
   if(g_cached_low1 <= g_cached_bb_lower && g_cached_close1 > g_cached_open1)
   {
      if(g_cached_bb_middle <= ask)
         return false;
      req.type   = QM_BUY;
      req.reason = "QM5_37005_BB_ADX_BUY";
      req.sl     = QM_StopATRFromValue(_Symbol, QM_BUY, ask,
                                       g_cached_atr1, strategy_sl_atr_mult);
      req.tp     = g_cached_bb_middle;
      return (req.sl > 0.0 && req.tp > 0.0);
   }
   // Short: same fail-closed midline rule in the opposite direction.
   else if(g_cached_high1 >= g_cached_bb_upper && g_cached_close1 < g_cached_open1)
   {
      if(g_cached_bb_middle >= bid)
         return false;
      req.type   = QM_SELL;
      req.reason = "QM5_37005_BB_ADX_SELL";
      req.sl     = QM_StopATRFromValue(_Symbol, QM_SELL, bid,
                                       g_cached_atr1, strategy_sl_atr_mult);
      req.tp     = g_cached_bb_middle;
      return (req.sl > 0.0 && req.tp > 0.0);
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
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
      ? (int)MathFloor((strategy_max_slippage_ticks * tick_size / point) + 1e-9)
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_drawdown_hard_stop_pct,
                         strategy_total_drawdown_stop_pct,
                         1.0))
      return INIT_FAILED;

   StrategyRefreshDailyEntryHalt(true);

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
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // Management and exits stay reachable while entry-only filters are active.
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

   if(Strategy_NoTradeFilter())
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();

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
   StrategyRefreshDailyEntryHalt(true);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
