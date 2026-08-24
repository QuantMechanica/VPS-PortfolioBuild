#property strict
#property version   "5.0"
#property description "QM5_33007 George Pruitt King Keltner Channel Trend Buster"
// Strategy Card: QM5_33007 (george-pruitt-king-keltner-trend-buster), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_33007
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 33007;
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
input int    strategy_ma_period           = 20;   // Mid MA lookback (Typical Price)
input int    strategy_atr_period          = 10;   // ATR channel lookback
input double strategy_atr_multiplier      = 1.50; // Keltner envelope multiplier
input double strategy_sl_atr_multiplier   = 2.0;  // Initial SL in ATR multiples
input double strategy_tp_sl_multiplier    = 2.0;  // 1:2.0 Risk:Reward multiplier
input int    strategy_spread_atr_period   = 14;   // Spread filter ATR period
input double strategy_spread_atr_mult     = 1.8;  // Spread filter threshold
input double strategy_daily_realized_loss_halt_pct = 2.0; // Entry halt, UTC day
input double strategy_daily_drawdown_hard_stop_pct = 2.5; // Flatten vs UTC-day start balance
input double strategy_total_drawdown_stop_pct       = 5.0; // Flatten vs initial equity
input double strategy_max_slippage_ticks            = 3.0; // Maximum market-order deviation

double g_strategy_initial_equity = 0.0;
double g_strategy_day_start_balance = 0.0;
int    g_strategy_utc_day_key = -1;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool Strategy_UTCSessionBounds(const datetime broker_now,
                               int &day_key,
                               datetime &broker_day_start)
{
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   if(utc_now <= 0)
      return false;

   MqlDateTime utc_dt;
   TimeToStruct(utc_now, utc_dt);
   day_key = utc_dt.year * 1000 + utc_dt.day_of_year;
   utc_dt.hour = 0;
   utc_dt.min = 0;
   utc_dt.sec = 0;
   const datetime utc_day_start = StructToTime(utc_dt);
   broker_day_start = QM_UTCToBroker(utc_day_start);
   return (broker_day_start > 0 && broker_day_start <= broker_now);
}

bool Strategy_DailyRealizedPnl(const datetime broker_now,
                               int &day_key,
                               double &realized_pnl,
                               double &day_start_balance)
{
   datetime broker_day_start = 0;
   if(!Strategy_UTCSessionBounds(broker_now, day_key, broker_day_start))
      return false;
   if(!HistorySelect(broker_day_start, broker_now))
      return false;

   realized_pnl = 0.0;
   const int deal_count = HistoryDealsTotal();
   if(deal_count < 0)
      return false;

   for(int i = 0; i < deal_count; ++i)
   {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         return false;

      const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;

      // Account-level realized P&L includes entry/exit commissions and fees.
      realized_pnl += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      realized_pnl += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
      realized_pnl += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
      realized_pnl += HistoryDealGetDouble(deal_ticket, DEAL_FEE);
   }

   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   day_start_balance = balance_now - realized_pnl;
   return (MathIsValidNumber(realized_pnl) &&
           MathIsValidNumber(day_start_balance) &&
           day_start_balance > 0.0);
}

bool Strategy_RefreshDailyRiskState(const datetime broker_now)
{
   int day_key = -1;
   datetime broker_day_start = 0;
   if(!Strategy_UTCSessionBounds(broker_now, day_key, broker_day_start))
      return false;
   if(day_key == g_strategy_utc_day_key && g_strategy_day_start_balance > 0.0)
      return true;

   double realized_pnl = 0.0;
   double day_start_balance = 0.0;
   if(!Strategy_DailyRealizedPnl(broker_now, day_key, realized_pnl, day_start_balance))
      return false;

   g_strategy_utc_day_key = day_key;
   g_strategy_day_start_balance = day_start_balance;
   return true;
}

bool Strategy_EnforceHardStops()
{
   const datetime broker_now = TimeCurrent();
   if(!Strategy_RefreshDailyRiskState(broker_now))
   {
      QM_KillSwitchTrip("KS_STRATEGY_RISK_DATA_ERROR",
                        "{\"reason\":\"daily_risk_state_unavailable\"}");
      return false;
   }

   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!MathIsValidNumber(equity_now) || equity_now <= 0.0)
   {
      QM_KillSwitchTrip("KS_STRATEGY_RISK_DATA_ERROR",
                        "{\"reason\":\"account_equity_invalid\"}");
      return false;
   }

   const double daily_drawdown_pct =
      MathMax(0.0, (g_strategy_day_start_balance - equity_now) /
                        g_strategy_day_start_balance * 100.0);
   if(daily_drawdown_pct >= strategy_daily_drawdown_hard_stop_pct)
   {
      QM_KillSwitchTrip("KS_STRATEGY_DAILY_DRAWDOWN",
                        StringFormat("{\"day_start_balance\":%.2f,\"equity_now\":%.2f,\"drawdown_pct\":%.6f,\"limit_pct\":%.6f}",
                                     g_strategy_day_start_balance,
                                     equity_now,
                                     daily_drawdown_pct,
                                     strategy_daily_drawdown_hard_stop_pct));
      return false;
   }

   const double total_drawdown_pct =
      MathMax(0.0, (g_strategy_initial_equity - equity_now) /
                        g_strategy_initial_equity * 100.0);
   if(total_drawdown_pct >= strategy_total_drawdown_stop_pct)
   {
      QM_KillSwitchTrip("KS_STRATEGY_TOTAL_DRAWDOWN",
                        StringFormat("{\"initial_equity\":%.2f,\"equity_now\":%.2f,\"drawdown_pct\":%.6f,\"limit_pct\":%.6f}",
                                     g_strategy_initial_equity,
                                     equity_now,
                                     total_drawdown_pct,
                                     strategy_total_drawdown_stop_pct));
      return false;
   }

   return true;
}

bool Strategy_InputsValid()
{
   if(_Period != PERIOD_H4)
      return false;
   if(strategy_ma_period < 10 || strategy_ma_period > 50)
      return false;
   if(strategy_atr_period < 5 || strategy_atr_period > 20)
      return false;
   if(strategy_atr_multiplier < 1.0 || strategy_atr_multiplier > 2.5)
      return false;
   if(strategy_sl_atr_multiplier <= 0.0 || strategy_tp_sl_multiplier <= 0.0)
      return false;
   if(strategy_spread_atr_period <= 0 || strategy_spread_atr_mult <= 0.0)
      return false;
   if(MathAbs(strategy_daily_realized_loss_halt_pct - 2.0) > 1e-9 ||
      MathAbs(strategy_daily_drawdown_hard_stop_pct - 2.5) > 1e-9 ||
      MathAbs(strategy_total_drawdown_stop_pct - 5.0) > 1e-9)
      return false;
   if(strategy_max_slippage_ticks <= 0.0 || strategy_max_slippage_ticks > 3.0)
      return false;
   if(RISK_PERCENT > 0.0 && (RISK_PERCENT < 0.20 || RISK_PERCENT > 1.00))
      return false;
   return true;
}

bool Strategy_ConfigureSlippage()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return false;

   const int deviation_points =
      (int)MathFloor(strategy_max_slippage_ticks * tick_size / point + 1e-9);
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());
   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   if(utc_now <= 0)
      return true;

   const int hhmm = GetBarHhmm(utc_now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   int day_key = -1;
   double realized_pnl = 0.0;
   double day_start_balance = 0.0;
   if(!Strategy_DailyRealizedPnl(broker_now, day_key, realized_pnl, day_start_balance))
      return true;
   g_strategy_utc_day_key = day_key;
   g_strategy_day_start_balance = day_start_balance;
   const double realized_loss_pct =
      (realized_pnl < 0.0) ? (-realized_pnl / day_start_balance * 100.0) : 0.0;
   if(realized_loss_pct >= strategy_daily_realized_loss_halt_pct)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H4, strategy_spread_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || point <= 0.0 || atr_1 <= 0.0)
      return true;

   const double spread_pts = (ask - bid) / point;
   const double atr_pts = atr_1 / point;
   if(spread_pts > strategy_spread_atr_mult * atr_pts)
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double mid_ma_1 = QM_SMA(_Symbol, PERIOD_H4, strategy_ma_period, 1, PRICE_TYPICAL);
   const double mid_ma_2 = QM_SMA(_Symbol, PERIOD_H4, strategy_ma_period, 2, PRICE_TYPICAL);
   const double atr_10   = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double close_1  = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: closed-bar evaluation behind QM_IsNewBar()

   if(mid_ma_1 <= 0.0 || mid_ma_2 <= 0.0 || atr_10 <= 0.0 || close_1 <= 0.0)
      return false;

   const double upper_1 = mid_ma_1 + strategy_atr_multiplier * atr_10;
   const double lower_1 = mid_ma_1 - strategy_atr_multiplier * atr_10;
   const double sl_dist = strategy_sl_atr_multiplier * atr_10;
   const double tp_dist = sl_dist * strategy_tp_sl_multiplier;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Long entry: Close[1] > Upper[1] AND Mid_MA[1] > Mid_MA[2]
   if(close_1 > upper_1 && mid_ma_1 > mid_ma_2)
   {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, ask + tp_dist);
      req.reason = "QM5_33007_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   // Short entry: Close[1] < Lower[1] AND Mid_MA[1] < Mid_MA[2]
   if(close_1 < lower_1 && mid_ma_1 < mid_ma_2)
   {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bid + sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, bid - tp_dist);
      req.reason = "QM5_33007_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double mid_ma_1 = QM_SMA(_Symbol, PERIOD_H4, strategy_ma_period, 1, PRICE_TYPICAL);
   const double close_1  = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: closed-bar evaluation behind QM_IsNewBar()
   if(mid_ma_1 <= 0.0 || close_1 <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close_1 < mid_ma_1)
         return true;
      if(ptype == POSITION_TYPE_SELL && close_1 > mid_ma_1)
         return true;
   }

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
   if(!Strategy_InputsValid())
   {
      Print("QM5_33007 init refused: H4 execution identity or card parameter contract invalid");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!Strategy_ConfigureSlippage())
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_drawdown_hard_stop_pct,
                         0.0,
                         1.0))
      return INIT_FAILED;

   g_strategy_initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!MathIsValidNumber(g_strategy_initial_equity) ||
      g_strategy_initial_equity <= 0.0 ||
      !Strategy_RefreshDailyRiskState(TimeCurrent()))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!Strategy_EnforceHardStops()) return;
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;

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

   if(!QM_IsNewBar(_Symbol, PERIOD_H4)) return;
   QM_EquityStreamOnNewBar();

   // News, rollover, daily-realized-loss, and spread gates suppress entries
   // only; management, Friday close, and the card's midline exit stay live.
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(Strategy_NoTradeFilter()) return;

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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
