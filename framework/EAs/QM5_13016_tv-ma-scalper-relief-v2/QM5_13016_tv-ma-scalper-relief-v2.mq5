#property strict
#property version   "5.0"
#property description "QM5_13016 TradingView MA Scalper Relief Rally v2 (exit surgery)"
// Strategy Card: QM5_13016 (tv-ma-scalper-relief-v2), G0 APPROVED 2026-07-04.
// Source: Coinrule, Moving Average Scalper, TradingView, 2021-04-29.
//
// EXIT SURGERY v2 — parent QM5_10115
// Surgical delta 1: add strategy_min_hold_bars = 16 (4h in M15); suppress MA-crossover
// exit within first 16 M15 bars. Evidence: 84 trades in <2h bucket, WR 36%,
// TIME_MGMT x42 = early MA-flip noise before relief rally matures.
// Surgical delta 2: strategy_max_hold_bars 96 -> 192 (24h -> 48h ceiling).
// Evidence: 55 trades in 1-3d bucket, WR 67%, all TIME_MGMT = 24h ceiling kills.
// Evidence: EXIT_SURGERY_SCAN_2026-07-04.md §3.7; hold-gradient WR 36%->67%.
// SL unchanged (Tier-B parked). All other logic IDENTICAL to parent QM5_10115.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13016;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M15;
input int             strategy_sma_fast_period    = 9;
input int             strategy_sma_mid_period     = 50;
input int             strategy_sma_slow_period    = 100;
input int             strategy_sma_regime_period  = 200;
input int             strategy_sma_slope_bars     = 20;
input int             strategy_atr_period         = 14;
input double          strategy_atr_sl_mult        = 2.0;
input int             strategy_structure_lookback = 20;
// v2 surgical change 2: extended from 96 -> 192 M15 bars (24h -> 48h ceiling).
// Evidence: EXIT_SURGERY_SCAN_2026-07-04.md §3.7 — 55 trades in 1-3d bucket have
// WR 67% and avg net +368, all killed as TIME_MGMT by the 24h ceiling.
input int             strategy_max_hold_bars      = 192;
// v2 surgical input: minimum hold before MA-crossover exit is allowed.
// Evidence: EXIT_SURGERY_SCAN_2026-07-04.md §3.7 — 84 trades in <2h bucket have
// WR 36% and TIME_MGMT x42 = MA-crossover signal fires within first 4h (16 M15
// bars) while the relief-rally is still fighting M15 noise. Suppressing the
// MA-crossover exit for the first 4h removes these premature kills.
input int             strategy_min_hold_bars      = 16;
input double          strategy_max_spread_stop_frac = 0.10;

bool Strategy_NoTradeFilter()
  {
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

   if(strategy_sma_fast_period <= 0 || strategy_sma_mid_period <= 0 ||
      strategy_sma_slow_period <= 0 || strategy_sma_regime_period <= 0 ||
      strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_structure_lookback <= 0 || strategy_max_spread_stop_frac < 0.0)
      return false;

   const double fast_1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_fast_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_fast_period, 2, PRICE_CLOSE);
   const double mid_1  = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_mid_period, 1, PRICE_CLOSE);
   const double mid_2  = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_mid_period, 2, PRICE_CLOSE);
   const double slow_1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_slow_period, 1, PRICE_CLOSE);
   const double reg_1  = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_regime_period, 1, PRICE_CLOSE);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || mid_1 <= 0.0 || mid_2 <= 0.0 ||
      slow_1 <= 0.0 || reg_1 <= 0.0)
      return false;

   if(!(fast_2 <= mid_2 && fast_1 > mid_1))
      return false;
   if(!(mid_1 < slow_1 && slow_1 < reg_1))
      return false;

   const double reg_prior = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_regime_period,
                                   1 + strategy_sma_slope_bars, PRICE_CLOSE);
   if(reg_prior <= 0.0)
      return false;
   if(reg_1 > reg_prior)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double atr_sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   const double structure_sl = QM_StopStructure(_Symbol, QM_BUY, entry, strategy_structure_lookback);
   if(atr_sl <= 0.0 || structure_sl <= 0.0)
      return false;

   const double sl = MathMin(atr_sl, structure_sl);
   if(sl <= 0.0 || sl >= entry)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   const double spread = entry - bid;
   if(stop_distance <= 0.0 || spread < 0.0 || spread > stop_distance * strategy_max_spread_stop_frac)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "TV_MA_SCALPER_RELIEF_V2_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, break-even, partial, or pyramiding management.
  }

bool Strategy_ExitSignal()
  {
   if(strategy_sma_fast_period <= 0 || strategy_sma_regime_period <= 0)
      return false;

   const double fast_1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_fast_period, 1, PRICE_CLOSE);
   const double fast_2 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_fast_period, 2, PRICE_CLOSE);
   const double reg_1  = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_regime_period, 1, PRICE_CLOSE);
   const double reg_2  = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_regime_period, 2, PRICE_CLOSE);
   const bool ma_exit_signal = (fast_1 > 0.0 && fast_2 > 0.0 && reg_1 > 0.0 && reg_2 > 0.0 &&
                                fast_2 <= reg_2 && fast_1 > reg_1);

   const int magic = QM_FrameworkMagic();
   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_signal_tf);
   const int tf_seconds = PeriodSeconds(strategy_signal_tf);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const long elapsed = TimeCurrent() - opened_at;

      const bool time_exit = (hold_seconds > 0 && opened_at > 0 && elapsed >= hold_seconds);

      // v2 surgical guard: suppress MA-crossover exit within strategy_min_hold_bars
      // (16 M15 bars = 4h). The TIME_MGMT x42 kills in the <2h bucket are MA-crossover
      // noise before the relief rally matures. Evidence: §3.7 EXIT_SURGERY_SCAN.
      const int hold_bars_elapsed = (tf_seconds > 0) ? (int)(elapsed / tf_seconds) : 0;
      const bool min_hold_passed = (strategy_min_hold_bars <= 0 ||
                                    hold_bars_elapsed >= strategy_min_hold_bars);
      const bool ma_exit = (ma_exit_signal && min_hold_passed);

      if(ma_exit || time_exit)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13016_tv_ma_scalper_relief_v2\",\"surgery\":\"min_hold_bars_16_and_max_hold_bars_96to192\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

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

   if(!QM_IsNewBar())
      return;

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
