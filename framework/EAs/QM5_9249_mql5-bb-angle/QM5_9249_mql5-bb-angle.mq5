#property strict
#property version   "5.0"
#property description "QM5_9249 Bollinger Band Angle Skew (H1)"
// rework v2 2026-06-16 — QM_BB_* calls omitted the `deviation` arg, so the intended shift (1/2/3) landed in the deviation slot and shift collapsed to 1; every band read the SAME bar at deviation 1/2/3, making the angle/skew logic meaningless and the width filter unsatisfiable (~0 trades). Restored deviation=strategy_bb_dev so shift indexes consecutive bars again.

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9249 — mql5-bb-angle
// Card: QM5_9249_mql5-bb-angle.md  Source: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
// Long: BB lower-band angle > upper-band angle + breakout close > upper band.
// Short: BB upper-band angle > lower-band angle + breakout close < lower band.
// Exit: price crosses middle band or 36-bar time stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9249;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period           = 20;    // Bollinger Band period
input double strategy_bb_dev              = 2.0;   // Bollinger Band deviation
input double strategy_skew_factor         = 1.0;   // lower_move >= skew_factor * upper_move (long)
input int    strategy_atr_period          = 14;    // ATR period for stop-loss
input double strategy_atr_sl_mult         = 1.6;   // SL = entry +/- ATR * mult
input double strategy_tp_r_mult           = 2.0;   // TP = R * this multiple
input int    strategy_width_sma_period    = 50;    // Bandwidth volatility filter SMA period
input int    strategy_max_hold_bars       = 36;    // Failsafe: close after N H1 bars

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Bollinger Band values for last 3 closed bars (card [0]=shift1, [1]=shift2, [2]=shift3)
   const double lower0 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1);
   const double lower1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 2);
   const double lower2 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 3);
   const double upper0 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1);
   const double upper1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 2);
   const double upper2 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 3);
   const double mid0   = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1);

   if(lower0 <= 0.0 || upper0 <= 0.0 || mid0 <= 0.0)
      return false;

   // Close of last closed bar (QM_SMA period=1 = raw close)
   const double close0 = QM_SMA(_Symbol, PERIOD_H1, 1, 1);
   if(close0 <= 0.0)
      return false;

   // Bandwidth volatility filter: current width > SMA(width, 50 bars)
   // Runs once per new bar — O(50) is within perf budget
   const double width0 = upper0 - lower0;
   double width_sum = width0;
   for(int i = 2; i <= strategy_width_sma_period; i++)
      width_sum += QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, i)
                 - QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, i);
   const double width_sma = width_sum / strategy_width_sma_period;

   if(width0 <= width_sma)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // One position per magic
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   // Long: rising lower band (steeper than upper) + close above upper band
   const double lower_rise = lower0 - lower2;
   const double upper_rise = upper0 - upper2;
   const bool   long_skew  = (lower0 > lower1) && (lower1 > lower2)
                           && (upper0 >= upper1) && (upper1 >= upper2)
                           && (lower_rise >= strategy_skew_factor * upper_rise);
   const bool   long_confirm = (close0 > upper0);

   if(long_skew && long_confirm)
     {
      const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl_dist  = atr * strategy_atr_sl_mult;
      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = ask - sl_dist;
      req.tp                 = ask + sl_dist * strategy_tp_r_mult;
      req.reason             = "BB_ANGLE_LONG";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // Short: falling upper band (steeper than lower) + close below lower band
   const double upper_drop = upper2 - upper0;
   const double lower_drop = lower2 - lower0;
   const bool   short_skew = (upper0 < upper1) && (upper1 < upper2)
                           && (lower0 <= lower1) && (lower1 <= lower2)
                           && (upper_drop >= strategy_skew_factor * lower_drop);
   const bool   short_confirm = (close0 < lower0);

   if(short_skew && short_confirm)
     {
      const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl_dist  = atr * strategy_atr_sl_mult;
      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = bid + sl_dist;
      req.tp                 = bid - sl_dist * strategy_tp_r_mult;
      req.reason             = "BB_ANGLE_SHORT";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing or partial close — SL/TP and signal exit manage full lifecycle.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Failsafe time exit: 36 H1 bars after entry
      const datetime pos_time    = (datetime)PositionGetInteger(POSITION_TIME);
      const int      bars_elapsed = (int)((TimeCurrent() - pos_time) / PeriodSeconds(PERIOD_H1));
      if(bars_elapsed >= strategy_max_hold_bars)
         return true;

      // Middle-band exit
      const double mid      = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1);
      const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(ptype == POSITION_TYPE_BUY  && bid < mid)
         return true;
      if(ptype == POSITION_TYPE_SELL && bid > mid)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// ---------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb\",\"ea\":\"QM5_9249_mql5-bb-angle\"}");
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
