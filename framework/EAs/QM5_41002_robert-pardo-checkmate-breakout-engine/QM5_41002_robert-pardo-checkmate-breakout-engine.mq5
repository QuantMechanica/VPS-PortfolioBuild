#property strict
#property version   "5.0"
#property description "QM5_41002 Robert Pardo Checkmate Currency Breakout Engine"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41002
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41002;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf                 = PERIOD_H4;
input int             strategy_donchian_bars             = 10;
input int             strategy_atr_period                = 14;
input int             strategy_atr_slope_shift           = 5;
input double          strategy_atr_sl_mult               = 1.5;
input double          strategy_tp_rr_mult                = 2.0;
input int             strategy_rollover_start_hhmm       = 2355;
input int             strategy_rollover_end_hhmm         = 5;
input double          strategy_spread_filter_mult        = 1.8;
input int             strategy_max_positions            = 1;
input int             strategy_max_slippage_ticks        = 3;
input double          strategy_daily_loss_halt_pct       = 2.0;
input double          strategy_daily_hard_stop_pct       = 2.5;
input double          strategy_total_dd_halt_pct         = 5.0;
input double          strategy_per_trade_risk_cap_pct    = 0.5;

// Closed-bar state. EntrySignal and per-tick management read only this cache.
double g_atr_1         = 0.0;
double g_atr_slope_ref = 0.0;
double g_entry_upper   = 0.0;
double g_entry_lower   = 0.0;
double g_trail_upper   = 0.0;
double g_trail_lower   = 0.0;
double g_close_1       = 0.0;
int    g_signal        = 0;
bool   g_state_ready   = false;

bool StrategyConfigValid()
  {
   if(strategy_signal_tf != PERIOD_H4)
      return false;
   if(strategy_donchian_bars < 2 || strategy_atr_period < 2)
      return false;
   if(strategy_atr_slope_shift <= 1)
      return false;
   if(strategy_atr_sl_mult <= 0.0 || strategy_tp_rr_mult <= 0.0)
      return false;
   if(strategy_spread_filter_mult <= 0.0 || strategy_max_positions != 1)
      return false;
   if(strategy_max_slippage_ticks <= 0)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_total_dd_halt_pct <= 0.0)
      return false;
   if(strategy_per_trade_risk_cap_pct <= 0.0 || strategy_per_trade_risk_cap_pct > 1.0)
      return false;
   if(strategy_rollover_start_hhmm < 0 || strategy_rollover_start_hhmm > 2359)
      return false;
   if(strategy_rollover_end_hhmm < 0 || strategy_rollover_end_hhmm > 2359)
      return false;
   if((strategy_rollover_start_hhmm % 100) > 59 || (strategy_rollover_end_hhmm % 100) > 59)
      return false;
   return true;
  }

int StrategyHhmm(const datetime value)
  {
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.hour * 100 + parts.min;
  }

bool StrategyInRolloverWindow(const datetime value)
  {
   const int hhmm = StrategyHhmm(value);
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      return (hhmm >= strategy_rollover_start_hhmm || hhmm < strategy_rollover_end_hhmm);
   return (hhmm >= strategy_rollover_start_hhmm && hhmm < strategy_rollover_end_hhmm);
  }

bool StrategyDailyEntryHalt()
  {
   // The approved card declares a 2.0% entry halt and a distinct 2.5% hard
   // stop. Reuse the framework's restart-safe broker-day equity anchor so the
   // entry layer cannot reset its daily budget after an EA restart. Existing
   // exposure remains manageable until the framework hard stop trips.
   if(g_qm_ks_day_start_equity <= 0.0)
      return true;

   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity_now <= 0.0)
      return true;

   const double pnl_pct = ((equity_now - g_qm_ks_day_start_equity) /
                           g_qm_ks_day_start_equity) * 100.0;
   return (pnl_pct <= -strategy_daily_loss_halt_pct);
  }

bool StrategyReadChannel(const int first_shift,
                         const int bars,
                         double &upper,
                         double &lower)
  {
   upper = 0.0;
   lower = 0.0;
   bool have_bar = false;

   for(int offset = 0; offset < bars; ++offset)
     {
      const int shift = first_shift + offset;
      MqlRates bar;
      if(!QM_ReadBar(_Symbol, strategy_signal_tf, shift, bar))
         return false;
      const double bar_high = bar.high;
      const double bar_low = bar.low;
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high < bar_low)
         return false;

      if(!have_bar)
        {
         upper = bar_high;
         lower = bar_low;
         have_bar = true;
        }
      else
        {
         if(bar_high > upper)
            upper = bar_high;
         if(bar_low < lower)
            lower = bar_low;
        }
     }

   return have_bar;
  }

void AdvanceState_OnNewBar()
  {
   g_state_ready = false;
   g_signal = 0;

   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, strategy_signal_tf, 1, signal_bar))
      return;
   const double close_1 = signal_bar.close;
   if(close_1 <= 0.0)
      return;

   // Entry compares the signal bar [1] with the channel that existed before
   // it (bars [2]..[N+1]); including High/Low[1] would make a close breakout
   // mathematically impossible. The trailing boundary includes bar [1].
   double entry_upper = 0.0;
   double entry_lower = 0.0;
   double trail_upper = 0.0;
   double trail_lower = 0.0;
   if(!StrategyReadChannel(2, strategy_donchian_bars, entry_upper, entry_lower))
      return;
   if(!StrategyReadChannel(1, strategy_donchian_bars, trail_upper, trail_lower))
      return;

   const double atr_1 = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double atr_ref = QM_ATR(_Symbol,
                                 strategy_signal_tf,
                                 strategy_atr_period,
                                 strategy_atr_slope_shift);
   if(atr_1 <= 0.0 || atr_ref <= 0.0)
      return;

   g_close_1 = close_1;
   g_entry_upper = entry_upper;
   g_entry_lower = entry_lower;
   g_trail_upper = trail_upper;
   g_trail_lower = trail_lower;
   g_atr_1 = atr_1;
   g_atr_slope_ref = atr_ref;
   g_state_ready = true;

   if(g_atr_1 <= g_atr_slope_ref)
      return;
   if(g_close_1 > g_entry_upper)
      g_signal = 1;
   else if(g_close_1 < g_entry_lower)
      g_signal = -1;
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

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(StrategyInRolloverWindow(QM_BrokerToUTC(TimeCurrent())))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   if(g_state_ready && g_atr_1 > 0.0 && (ask - bid) > g_atr_1 * strategy_spread_filter_mult)
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

   if(!g_state_ready || g_signal == 0 || g_atr_1 <= 0.0)
      return false;
   if(StrategyDailyEntryHalt())
      return false;

   // Re-evaluate the card-authorized spread ceiling after the current H4
   // cache is populated.  The per-tick no-trade hook runs before
   // AdvanceState_OnNewBar(), so relying on it alone would let the first
   // post-init signal bypass the spread check.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   if((ask - bid) > g_atr_1 * strategy_spread_filter_mult)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= strategy_max_positions)
      return false;

   const QM_OrderType side = (g_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? ask : bid;
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol,
                                         side,
                                         entry,
                                         g_atr_1,
                                         strategy_atr_sl_mult);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "CHECKMATE_DONCHIAN_LONG"
                                  : "CHECKMATE_DONCHIAN_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!g_state_ready || g_trail_upper <= 0.0 || g_trail_lower <= 0.0)
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
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(position_type == POSITION_TYPE_BUY)
        {
         const double target_sl = QM_StopRulesNormalizePrice(_Symbol, g_trail_lower);
         if(bid <= target_sl)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_TRAILING);
            continue;
           }
         if(target_sl > 0.0 && target_sl < bid &&
            (current_sl <= 0.0 || target_sl > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "donchian_opposite_boundary");
        }
      else if(position_type == POSITION_TYPE_SELL)
        {
         const double target_sl = QM_StopRulesNormalizePrice(_Symbol, g_trail_upper);
         if(ask >= target_sl)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_TRAILING);
            continue;
           }
         if(target_sl > ask &&
            (current_sl <= 0.0 || target_sl < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "donchian_opposite_boundary");
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
   if(!StrategyConfigValid())
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
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_41002\"}");
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
   if(Strategy_NoTradeFilter())
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

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf))
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
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
