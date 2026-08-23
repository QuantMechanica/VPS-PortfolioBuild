#property strict
#property version   "5.0"
#property description "QM5_35008 Robopip Short-Term Bollinger Reversion System"
// Strategy Card: QM5_35008 (short-term-bollinger-reversion-system), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_35008
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 35008;
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
input int    strategy_bb_period           = 20;     // Bollinger Bands MA period
input double strategy_bb_dev              = 2.50;   // Bollinger Bands standard deviation
input int    strategy_rsi_period          = 14;     // RSI oscillator period
input double strategy_rsi_oversold        = 30.0;   // RSI oversold threshold
input double strategy_rsi_overbought      = 70.0;   // RSI overbought threshold
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.50;   // Stop loss distance as ATR multiplier
input int    strategy_entry_start_hhmm    = 1800;   // Session entry window start (GMT hhmm)
input int    strategy_entry_end_hhmm      = 2200;   // Session entry window end (GMT hhmm)
input int    strategy_exit_hhmm           = 2300;   // Time exit cutoff before rollover (GMT hhmm)
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input double strategy_daily_loss_halt_pct = 2.0;    // Daily realized loss entry halt percent
input double strategy_daily_hard_stop_pct = 2.5;    // Maximum daily drawdown hard stop percent
input double strategy_total_dd_halt_pct   = 5.0;    // Maximum total drawdown stop percent
input double strategy_per_trade_risk_cap_pct = 0.5; // Per-trade risk cap percent

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int StrategyHhmm(const datetime value)
{
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.hour * 100 + parts.min;
}

bool StrategyInRolloverWindow(const datetime utc_time)
{
   const int hhmm = StrategyHhmm(utc_time);
   return (hhmm >= 2355 || hhmm < 5);
}

bool StrategyDailyEntryHalt()
{
   if(g_qm_ks_day_start_equity <= 0.0)
      return false;

   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity_now <= 0.0)
      return true;

   const double pnl_pct = ((equity_now - g_qm_ks_day_start_equity) / g_qm_ks_day_start_equity) * 100.0;
   return (pnl_pct <= -strategy_daily_loss_halt_pct);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);

   // 1. Rollover Blackout in UTC (23:55 to 00:05 GMT)
   if(StrategyInRolloverWindow(utc_now))
      return true;

   // 2. Spread Filter (> 1.8 * ATR(14, M15)[1])
   const double atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
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

   // 3. Daily Loss Limit (2.0% entry halt)
   if(StrategyDailyEntryHalt())
      return true;

   // 4. Max Open Positions (>= 1)
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) >= 1)
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

   const ENUM_TIMEFRAMES tf = PERIOD_M15;
   const datetime t_1 = iTime(_Symbol, tf, 1);
   if(t_1 <= 0) return false;

   const datetime utc_1 = QM_BrokerToUTC(t_1);
   const int hhmm_1 = StrategyHhmm(utc_1);
   if(hhmm_1 < strategy_entry_start_hhmm || hhmm_1 > strategy_entry_end_hhmm)
      return false;

   const double low_1   = iLow(_Symbol, tf, 1);   // perf-allowed: closed-bar low behind QM_IsNewBar()
   const double high_1  = iHigh(_Symbol, tf, 1);  // perf-allowed: closed-bar high behind QM_IsNewBar()
   const double close_1 = iClose(_Symbol, tf, 1); // perf-allowed: closed-bar close behind QM_IsNewBar()
   const double open_1  = iOpen(_Symbol, tf, 1);  // perf-allowed: closed-bar open behind QM_IsNewBar()

   if(low_1 <= 0.0 || high_1 <= 0.0 || close_1 <= 0.0 || open_1 <= 0.0)
      return false;

   const double bb_mid_1   = QM_SMA(_Symbol, tf, strategy_bb_period, 1);
   const double bb_upper_1 = QM_BB_Upper(_Symbol, tf, strategy_bb_period, strategy_bb_dev, 1);
   const double bb_lower_1 = QM_BB_Lower(_Symbol, tf, strategy_bb_period, strategy_bb_dev, 1);
   const double rsi_1      = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double atr_1      = QM_ATR(_Symbol, tf, strategy_atr_period, 1);

   if(bb_mid_1 <= 0.0 || bb_upper_1 <= 0.0 || bb_lower_1 <= 0.0 || rsi_1 <= 0.0 || atr_1 <= 0.0)
      return false;

   // 1. Long Entry: Low[1] <= LowerBB[1] AND Close[1] > Open[1] AND RSI[1] <= 30.0
   if((low_1 <= bb_lower_1) && (close_1 > open_1) && (rsi_1 <= strategy_rsi_oversold))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;
      const double sl = exec_price - strategy_sl_atr_mult * atr_1;
      const double tp = bb_mid_1;

      if(sl <= 0.0 || sl >= exec_price || tp <= exec_price)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "bb_reversion_long";
      return true;
   }

   // 2. Short Entry: High[1] >= UpperBB[1] AND Close[1] < Open[1] AND RSI[1] >= 70.0
   if((high_1 >= bb_upper_1) && (close_1 < open_1) && (rsi_1 >= strategy_rsi_overbought))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;
      const double sl = exec_price + strategy_sl_atr_mult * atr_1;
      const double tp = bb_mid_1;

      if(sl <= 0.0 || sl <= exec_price || tp >= exec_price)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "bb_reversion_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const int hhmm_utc = StrategyHhmm(utc_now);
   if(hhmm_utc >= strategy_exit_hhmm && hhmm_utc < 2355)
      return true;
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
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
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
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;

   // 1. Manage open positions and evaluate exit signals before entry filters
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

   // 2. News filter check
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   // 3. Entry-only filter (spread, rollover in UTC, 2% daily loss halt, max open positions)
   if(Strategy_NoTradeFilter()) return;

   // 4. Bar evaluation for entry
   if(!QM_IsNewBar(_Symbol, PERIOD_M15)) return;
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
