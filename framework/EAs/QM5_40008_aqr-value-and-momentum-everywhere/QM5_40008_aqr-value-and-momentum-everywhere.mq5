#property strict
#property version   "5.0"
#property description "QM5_40008 AQR Value and Momentum Everywhere Multi-Asset Engine (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_40008 aqr-value-and-momentum-everywhere
// -----------------------------------------------------------------------------
// Source: Asness, C. S., Moskowitz, T. J., & Pedersen, L. H. (2013).
//         Value and Momentum Everywhere. Journal of Finance.
// Card: strategy-seeds/cards/approved/QM5_40008_aqr-value-and-momentum-everywhere.md (APPROVED)
//
// Mechanics (closed-bar, D1):
//   - Momentum Factor (Mt): 12-month return = (P[1] - P[253]) / P[253]
//   - Value Factor (Vt): 5-year mean reversion Z-score = -(P[1] - SMA(1260)) / StdDev(1260)
//   - Cross-sectional Combined Score: 0.50 * Rank(Mt) + 0.50 * Rank(Vt) across universe
//   - Macro Trend Gate: D1 Close[1] vs SMA(200)[1]
//   - Long Entry: CombinedScore >= 0.70 AND Close[1] > SMA(200)[1]
//   - Short Entry: CombinedScore <= 0.30 AND Close[1] < SMA(200)[1]
//   - SL: Entry ± 2.5 * ATR(14, D1)[1]
//   - TP: Quarterly dynamic factor rebalancing (open-ended broker TP)
//   - No-Trade Filter: Spread > 1.8 * ATR(14, D1)[1], Rollover blackout 23:55-00:05 GMT
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 40008;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Loss Limits"
input double strategy_daily_loss_halt_pct = 2.0; // Card: Account daily realized loss >= 2.0%
input double strategy_daily_hard_stop_pct = 2.5; // Card: Maximum daily drawdown hard stop 2.5%
input double strategy_total_dd_stop_pct   = 5.0; // Card: Maximum total drawdown stop 5.0%

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
input ENUM_TIMEFRAMES strategy_signal_tf         = PERIOD_D1;
input int             InpMomDays                 = 252;    // 1-year momentum lookback trading days
input int             InpValDays                 = 1260;   // 5-year valuation mean lookback trading days
input int             InpSMAPeriod               = 200;    // Macro trend baseline SMA period
input double          InpScoreThresholdLong      = 0.70;   // Combined score threshold for long entry
input double          InpScoreThresholdShort     = 0.30;   // Combined score threshold for short entry
input int             InpATRPeriod               = 14;     // Stop Loss ATR period
input double          InpATRMultiplier           = 2.5;    // Stop Loss ATR multiplier
input double          InpSpreadATRMult           = 1.8;    // Max spread multiplier vs ATR(14, D1)
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;

// =============================================================================
// UNIVERSE — mirrors magic_numbers.csv slots 0..3 for QM5_40008
// =============================================================================
string g_universe[4] = {"SP500.DWX", "NDX.DWX", "XTIUSD.DWX", "EURUSD.DWX"};
const int UNIVERSE_SIZE = 4;

// -----------------------------------------------------------------------------
// State Cache & Indicators (Evaluated on new D1 bar)
// -----------------------------------------------------------------------------
double g_last_combined_score = 0.5;
double g_last_sma_200        = 0.0;
double g_last_close1         = 0.0;
double g_last_atr1           = 0.0;
int    g_last_quarter        = -1;
int    g_last_year           = -1;

int StrategyHhmm(const datetime t)
{
   const datetime utc = QM_BrokerToUTC(t);
   MqlDateTime dt;
   TimeToStruct((utc > 0) ? utc : t, dt);
   return dt.hour * 100 + dt.min;
}

bool StrategyInRolloverWindow(const datetime t)
{
   const int hhmm = StrategyHhmm(t);
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      return (hhmm >= strategy_rollover_start_hhmm || hhmm < strategy_rollover_end_hhmm);
   return (hhmm >= strategy_rollover_start_hhmm && hhmm < strategy_rollover_end_hhmm);
}

bool Strategy_ValidateInputs()
{
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct || strategy_total_dd_stop_pct <= 0.0)
      return false;
   if(InpMomDays < 10 || InpValDays < 100 || InpSMAPeriod < 10 || InpATRPeriod < 1 || InpATRMultiplier <= 0.0)
      return false;
   if(InpScoreThresholdLong <= InpScoreThresholdShort)
      return false;
   return true;
}

bool Strategy_DailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   if(realized_pnl < 0.0)
   {
      const double loss_pct = (-realized_pnl / day_start_balance) * 100.0;
      if(loss_pct >= strategy_daily_loss_halt_pct)
         return true;
   }
   return false;
}

bool IsNewQuarter(const datetime broker_time)
{
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int current_quarter = (dt.mon - 1) / 3;
   if(g_last_quarter < 0)
   {
      g_last_quarter = current_quarter;
      g_last_year = dt.year;
      return false;
   }
   if(dt.year != g_last_year || current_quarter != g_last_quarter)
   {
      g_last_quarter = current_quarter;
      g_last_year = dt.year;
      return true;
   }
   return false;
}

void AdvanceState_OnNewBar()
{
   g_last_combined_score = 0.5;
   g_last_sma_200        = 0.0;
   g_last_close1         = 0.0;
   g_last_atr1           = 0.0;

   double mom_returns[4];
   double val_scores[4];
   bool   valid[4];
   int    my_idx = -1;

   for(int i = 0; i < UNIVERSE_SIZE; ++i)
   {
      mom_returns[i] = -9999.0;
      val_scores[i]  = -9999.0;
      valid[i]       = false;
      const string sym = g_universe[i];
      if(sym == _Symbol)
         my_idx = i;

      const int nbars = iBars(sym, strategy_signal_tf); // perf-allowed: single universe count on D1 new bar
      if(nbars < InpValDays + 2)
         continue;

      const double p1     = iClose(sym, strategy_signal_tf, 1);                  // perf-allowed: closed-bar calculation
      const double p_mom  = iClose(sym, strategy_signal_tf, 1 + InpMomDays);     // perf-allowed: closed-bar calculation
      if(p1 <= 0.0 || p_mom <= 0.0)
         continue;

      const double mean_val = QM_SMA(sym, strategy_signal_tf, InpValDays, 1, PRICE_CLOSE);
      const double bb_upper = QM_BB_Upper(sym, strategy_signal_tf, InpValDays, 1.0, 1, PRICE_CLOSE);
      const double bb_mid   = QM_BB_Middle(sym, strategy_signal_tf, InpValDays, 1.0, 1, PRICE_CLOSE);
      const double std_val  = bb_upper - bb_mid;

      if(mean_val <= 0.0 || std_val <= 0.0)
         continue;

      mom_returns[i] = (p1 - p_mom) / p_mom;
      val_scores[i]  = -(p1 - mean_val) / std_val;
      valid[i]       = true;
   }

   if(my_idx < 0 || !valid[my_idx])
      return;

   int valid_count = 0;
   for(int i = 0; i < UNIVERSE_SIZE; ++i)
   {
      if(valid[i])
         valid_count++;
   }

   if(valid_count < 2)
      return;

   // Cross-sectional ranking across valid universe assets
   int rank_m = 0;
   int rank_v = 0;
   for(int i = 0; i < UNIVERSE_SIZE; ++i)
   {
      if(!valid[i])
         continue;
      if(mom_returns[my_idx] >= mom_returns[i])
         rank_m++;
      if(val_scores[my_idx] >= val_scores[i])
         rank_v++;
   }

   const double norm_rank_m = (double)(rank_m - 1) / (double)(valid_count - 1);
   const double norm_rank_v = (double)(rank_v - 1) / (double)(valid_count - 1);

   g_last_combined_score = 0.50 * norm_rank_m + 0.50 * norm_rank_v;
   g_last_sma_200        = QM_SMA(_Symbol, strategy_signal_tf, InpSMAPeriod, 1, PRICE_CLOSE);
   g_last_close1         = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar calculation
   g_last_atr1           = QM_ATR(_Symbol, strategy_signal_tf, InpATRPeriod, 1);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(StrategyInRolloverWindow(TimeCurrent()))
      return true;

   if(Strategy_DailyRealizedLossHalt())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid && g_last_atr1 > 0.0)
   {
      const double spread = ask - bid;
      if(spread > InpSpreadATRMult * g_last_atr1)
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
   if(QM_TM_OpenPositionCount(magic) >= 1)
      return false;

   if(g_last_close1 <= 0.0 || g_last_sma_200 <= 0.0 || g_last_atr1 <= 0.0)
      return false;

   const double sl_dist = InpATRMultiplier * g_last_atr1;
   if(sl_dist <= 0.0)
      return false;

   // Long Entry: CombinedScore >= 0.70 AND Close[1] > SMA(200)[1]
   if(g_last_combined_score >= InpScoreThresholdLong && g_last_close1 > g_last_sma_200)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, ask - sl_dist);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type   = QM_BUY;
      req.sl     = sl;
      req.tp     = 0.0; // Open-ended quarterly rebalancing exit
      req.reason = "AQR_VALMOM_BUY";
      return (req.sl > 0.0);
   }

   // Short Entry: CombinedScore <= 0.30 AND Close[1] < SMA(200)[1]
   if(g_last_combined_score <= InpScoreThresholdShort && g_last_close1 < g_last_sma_200)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, bid + sl_dist);
      if(sl <= 0.0 || sl <= bid)
         return false;

      req.type   = QM_SELL;
      req.sl     = sl;
      req.tp     = 0.0; // Open-ended quarterly rebalancing exit
      req.reason = "AQR_VALMOM_SELL";
      return (req.sl > 0.0);
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   // No dynamic intra-bar trail required by card; stop loss managed by broker hard stop
}

bool Strategy_ExitSignal()
{
   return IsNewQuarter(TimeCurrent());
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
   if(!Strategy_ValidateInputs())
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

   if(!QM_FrameworkDeclareExecutionContract(strategy_signal_tf,
                                            QM_FRIDAY_CLOSE_CARD_RULE,
                                            "QM5_40008 AQR Value and Momentum Everywhere Multi-Asset Engine D1"))
      return INIT_FAILED;

   QM_KillSwitchInit(qm_ea_id, QM_FrameworkMagic(), strategy_daily_hard_stop_pct, strategy_total_dd_stop_pct, 1.0);

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
