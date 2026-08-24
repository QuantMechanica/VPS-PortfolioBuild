#property strict
#property version   "5.0"
#property description "QM5_34003 Triple Timeframe Williams %R Trend Pullback (ATC Champion)"
// Strategy Card: QM5_34003 (triple-timeframe-williams-r-champion), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>

// ======================================================================
// QuantMechanica V5 EA: QM5_34003
// ======================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 34003;
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
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_wpr_period          = 14;     // Williams %R period across all timeframes
input double strategy_h4_trend_long       = -35.0;  // H4 macro trend threshold for Long (>=)
input double strategy_h4_trend_short      = -65.0;  // H4 macro trend threshold for Short (<=)
input double strategy_h1_trend_mid        = -50.0;  // H1 intermediate trend threshold
input double strategy_m15_pullback_long   = -80.0;  // M15 pullback extreme for Long (<=)
input double strategy_m15_pullback_short  = -20.0;  // M15 pullback extreme for Short (>=)
input int    strategy_atr_period          = 14;     // @TR period for stop-loss and spread sizing
input double strategy_sl_atr_mult         = 1.5;    // Initial SL in ATR multiples
input double strategy_tp_rr_mult          = 2.5;     // 1:2.5 Risk:Reward multiplier for TP
input int    strategy_spread_atr_period   = 14;     // Spread filter ATR period
input double strategy_spread_atr_mult     = 1.8;    // Spread filter threshold
input int    strategy_max_open_positions = 1;      // Card: one position per strategy instance
input int    strategy_max_slippage_ticks  = 3;      // Card: maximum three ticks on market entry
input double strategy_daily_loss_halt_pct = 2.0;    // Card: realized-loss entry halt
input double strategy_daily_hard_stop_pct = 2.5;    // Card: daily equity hard stop
input double strategy_total_dd_stop_pct   = 5.0;    // Card: total equity drawdown stop

double g_initial_equity = 0.0;

// -----------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool Strategy_ValidateInputs()
{
   if(strategy_wpr_period < 10 || strategy_wpr_period > 28 ||
      strategy_atr_period < 1 || strategy_spread_atr_period < 1)
      return false;
   if(strategy_h4_trend_long <= strategy_h4_trend_short ||
      strategy_m15_pullback_long >= strategy_m15_pullback_short)
      return false;
   if(strategy_sl_atr_mult <= 0.0 || strategy_tp_rr_mult <= 0.0 ||
      strategy_spread_atr_mult <= 0.0 || strategy_max_open_positions != 1)
      return false;
   if(strategy_max_slippage_ticks <= 0 || strategy_max_slippage_ticks > 3)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > 2.0 ||
      strategy_daily_hard_stop_pct < strategy_daily_loss_halt_pct ||
      strategy_daily_hard_stop_pct > 2.5 ||
      strategy_total_dd_stop_pct < strategy_daily_hard_stop_pct ||
      strategy_total_dd_stop_pct > 5.0)
      return false;
   return true;
}

int StrategyDeviationPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return strategy_max_slippage_ticks;
   return (int)MathMax(1.0,
                       MathCeil(strategy_max_slippage_ticks * tick_size / point));
}

bool StrategyDailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   return (realized_pnl <=
           -(day_start_balance * strategy_daily_loss_halt_pct / 100.0));
}

bool StrategyTotalDrawdownBreached()
{
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   return (g_initial_equity > 0.0 && equity_now > 0.0 &&
           equity_now <= g_initial_equity *
                         (1.0 - strategy_total_dd_stop_pct / 100.0));
}

// -----------------------------------------------------------------------
// Strategy hooks
// ----------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   const int hhmm = GetBarHhmm(utc_now);
   if(hhmm >= 2355 || hhmm <= 5)
      return true;

   if(StrategyDailyRealizedLossHalt() || StrategyTotalDrawdownBreached())
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_spread_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
         return true;
   }
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

   if(QM_TM_OpenPositionCount(magic) >= strategy_max_open_positions)
      return false;

   const double wpr_h4  = QM_WPR(_Symbol, PERIOD_H4, strategy_wpr_period, 1);
   const double wpr_h1  = QM_WPR(_Symbol, PERIOD_H1, strategy_wpr_period, 1);
   const double wpr_m15 = QM_WPR(_Symbol, PERIOD_M15, strategy_wpr_period, 1);
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);

   if(atr_m15 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double sl_dist = strategy_sl_atr_mult * atr_m15;
   const double tp_dist = strategy_tp_rr_mult * sl_dist;

   // Long entry: H4 >= -35 AND H1 >= -50 AND M15 <= -80
   if(wpr_h4 >= strategy_h4_trend_long && wpr_h1 >= strategy_h1_trend_mid && wpr_m15 <= strategy_m15_pullback_long)
   {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, ask + tp_dist);
      req.reason = "QMU_34003_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   // Short entry: H4 <= -65 AND H1 <= -50 AND M15 >= -20
   if(wpr_h4 <= strategy_h4_trend_short && wpr_h1 <= strategy_h1_trend_mid && wpr_m15 >= strategy_m15_pullback_short)
   {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bid + sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, bid - tp_dist);
      req.reason = "QMU_34003_SELL";
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
   // SL/TP are broker-side. The only additional mechanically specified exit
   // is the card's 5% total-equity hard stop.
   return StrategyTotalDrawdownBreached();
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------
// Framework wiring
// ----------------------------------------------------------------------

int OnInit()
{
   if(!Strategy_ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_M15,
                                            QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                            "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     StrategyDeviationPoints(),
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_stop_pct,
                         1.0))
      return INIT_FAILED;

   g_initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_initial_equity <= 0.0)
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_34003\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;

   const bool strategy_new_bar = QM_IsNewBar(_Symbol, PERIOD_M15);
   if(strategy_new_bar)
      QM_EquityStreamOnNewBar();

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
      return;
   }

   if(!strategy_new_bar) return;
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(Strategy_NoTradeFilter()) return;

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
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
