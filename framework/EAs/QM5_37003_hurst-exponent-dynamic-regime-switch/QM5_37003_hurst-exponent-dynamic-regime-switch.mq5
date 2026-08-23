#property strict
#property version   "5.0"
#property description "QM5_37003 Hurst Exponent Dynamic Regime Switching Engine (Mandelbrot / Python Quant Group)"
// Strategy Card: QM5_37003 (hurst-exponent-dynamic-regime-switch), G0 APPROVED.
// Source: Mandelbrot, B. (1997). Fractals and Scaling in Finance. VectorBT Implementation.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37003 — Hurst Exponent Dynamic Regime Switching
// -----------------------------------------------------------------------------
// Evaluates rolling Rescaled Range (R/S) Hurst Exponent H on H1 closed bars:
//   - H > 0.55 (Trending Mode):
//       Long:  Close[1] > max_20(High) -> buy, SL = 1.5*ATR, TP = 2.0*SL_dist
//       Short: Close[1] < min_20(Low)  -> sell, SL = 1.5*ATR, TP = 2.0*SL_dist
//   - H < 0.45 (Mean-Reversion Mode):
//       Long:  Close[1] <= Lower_BB[1] -> buy, SL = 1.5*ATR, TP = Midline BB
//       Short: Close[1] >= Upper_BB[1] -> sell, SL = 1.5*ATR, TP = Midline BB
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37003;
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
input int    strategy_hurst_lookback      = 100;    // Hurst R/S lookback bars
input double strategy_trend_hurst         = 0.55;   // Minimum Hurst for trending regime
input double strategy_revert_hurst        = 0.45;   // Maximum Hurst for mean-reversion regime
input int    strategy_donchian_period     = 20;     // Donchian breakout channel period
input int    strategy_bb_period           = 20;     // Bollinger Bands period
input double strategy_bb_dev              = 2.00;   // Bollinger Bands deviation
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.50;   // Stop loss ATR multiplier
input double strategy_trend_tp_rr         = 2.00;   // Take profit R:R multiplier in trend mode
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input double strategy_daily_loss_halt_pct = 2.0;    // Account realized-loss entry halt
input double strategy_daily_hard_stop_pct = 2.5;    // Restart-safe daily equity stop
input double strategy_total_dd_halt_pct   = 5.0;    // Account-level total-DD signal threshold
input double strategy_per_trade_risk_cap_pct = 0.5; // Framework per-trade risk cap

// -----------------------------------------------------------------------------
// Cached State
// -----------------------------------------------------------------------------

double g_cached_hurst             = 0.5;
double g_cached_atr1              = 0.0;
double g_cached_bb_upper          = 0.0;
double g_cached_bb_lower          = 0.0;
double g_cached_bb_middle         = 0.0;
int    g_cached_donchian_breakout = 0;

bool Strategy_ConfigValid()
{
   if(strategy_hurst_lookback < 10 || strategy_trend_hurst <= strategy_revert_hurst)
      return false;
   if(strategy_donchian_period < 2 || strategy_bb_period < 2 || strategy_bb_dev <= 0.0)
      return false;
   if(strategy_atr_period < 2 || strategy_sl_atr_mult <= 0.0 ||
      strategy_trend_tp_rr <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_total_dd_halt_pct <= 0.0)
      return false;
   return (strategy_per_trade_risk_cap_pct > 0.0 && strategy_per_trade_risk_cap_pct <= 1.0);
}

//+------------------------------------------------------------------+
//| Rescaled Range (R/S) Hurst Exponent Calculator                   |
//| Evaluated strictly over closed bars [shift .. shift + lookback]  |
//+------------------------------------------------------------------+
double CalculateHurst(const string sym, const ENUM_TIMEFRAMES tf, const int lookback, const int shift=1)
{
   if(lookback < 10) return 0.5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, tf, shift, lookback + 1, rates) < lookback + 1) // perf-allowed: closed-bar Hurst rates vector
      return 0.5;

   double mean_ret = 0.0;
   double rets[];
   ArrayResize(rets, lookback);
   for(int i = 0; i < lookback; ++i)
   {
      double p1 = rates[i].close;
      double p0 = rates[i+1].close;
      if(p0 <= 0.0) return 0.5;
      rets[i] = MathLog(p1 / p0);
      mean_ret += rets[i];
   }
   mean_ret /= (double)lookback;

   double var = 0.0;
   double cum = 0.0;
   double max_cum = -1e9;
   double min_cum = 1e9;
   for(int i = 0; i < lookback; ++i)
   {
      double dev = rets[i] - mean_ret;
      var += dev * dev;
      cum += dev;
      if(cum > max_cum) max_cum = cum;
      if(cum < min_cum) min_cum = cum;
   }
   double std_dev = MathSqrt(var / (double)lookback);
   if(std_dev <= 1e-12) return 0.5;
   double range = max_cum - min_cum;
   if(range <= 0.0) return 0.5;
   double rs = range / std_dev;
   if(rs <= 0.0) return 0.5;
   double h = MathLog(rs) / MathLog((double)lookback);
   return h;
}

void AdvanceState_OnNewBar()
{
   g_cached_hurst             = CalculateHurst(_Symbol, PERIOD_H1, strategy_hurst_lookback, 1);
   g_cached_atr1              = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   g_cached_bb_upper          = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_cached_bb_lower          = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_cached_bb_middle         = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_cached_donchian_breakout = QM_Sig_Range_Breakout(_Symbol, PERIOD_H1, strategy_donchian_period, 1);
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
   if(ask <= 0.0 || bid <= 0.0 || g_cached_atr1 <= 0.0)
      return true;
   if(ask > bid && (ask - bid) > (strategy_spread_atr_mult * g_cached_atr1))
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
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed H1 bar close reference
   if(close1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // 1. Trending Mode (Hurst > InpTrendHurst)
   if(g_cached_hurst > strategy_trend_hurst)
   {
      if(g_cached_donchian_breakout > 0) // Close[1] > max_20(High)
      {
         req.type   = QM_BUY;
         req.reason = "QM5_37003_TREND_BUY";
         req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
         req.tp     = QM_TakeRR(_Symbol, QM_BUY, ask, req.sl, strategy_trend_tp_rr);
      }
      else if(g_cached_donchian_breakout < 0) // Close[1] < min_20(Low)
      {
         req.type   = QM_SELL;
         req.reason = "QM5_37003_TREND_SELL";
         req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_sl_atr_mult);
         req.tp     = QM_TakeRR(_Symbol, QM_SELL, bid, req.sl, strategy_trend_tp_rr);
      }
      else
      {
         return false;
      }
   }
   // 2. Mean-Reversion Mode (Hurst < InpRevertHurst)
   else if(g_cached_hurst < strategy_revert_hurst)
   {
      if(g_cached_bb_lower > 0.0 && close1 <= g_cached_bb_lower)
      {
         req.type   = QM_BUY;
          req.reason = "QM5_37003_REVERT_BUY";
          req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
          if(g_cached_bb_middle <= ask)
             return false;
          req.tp = g_cached_bb_middle;
      }
      else if(g_cached_bb_upper > 0.0 && close1 >= g_cached_bb_upper)
      {
         req.type   = QM_SELL;
          req.reason = "QM5_37003_REVERT_SELL";
          req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_sl_atr_mult);
          if(g_cached_bb_middle <= 0.0 || g_cached_bb_middle >= bid)
             return false;
          req.tp = g_cached_bb_middle;
      }
      else
      {
         return false;
      }
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

      const string comment = PositionGetString(POSITION_COMMENT);
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(StringFind(comment, "REVERT") >= 0 && g_cached_bb_middle > 0.0)
      {
         if(pos_type == POSITION_TYPE_BUY)
         {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(bid >= g_cached_bb_middle)
            {
               QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
               continue;
            }
         }
         else if(pos_type == POSITION_TYPE_SELL)
         {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(ask <= g_cached_bb_middle)
            {
               QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
               continue;
            }
         }
      }
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
      return;

   AdvanceState_OnNewBar();

   if(Strategy_NoTradeFilter())
      return;

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
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
