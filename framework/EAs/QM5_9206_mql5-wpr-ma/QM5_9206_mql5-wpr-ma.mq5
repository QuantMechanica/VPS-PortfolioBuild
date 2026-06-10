#property strict
#property version   "5.0"
#property description "QM5_9206 — Williams %R + EMA50 H1 trend filter"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_9206 mql5-wpr-ma
// Strategy: Enter long when Williams %R(14) crosses above -50 and close is
// above EMA(50); enter short when WPR crosses below -50 and close is below
// EMA(50). Exit on opposite WPR cross, EMA cross, or 40-bar time stop.
// SL = ATR(14)*1.5, TP = 2R.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 9206;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

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
input int    strategy_wpr_period    = 14;
input int    strategy_ema_period    = 50;
input int    strategy_atr_period    = 14;
input double strategy_sl_atr_mult   = 1.5;
input double strategy_tp_rr         = 2.0;
input int    strategy_max_hold_bars = 40;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false; // no additional time/regime filter; framework handles news + Friday
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // No pyramid: skip if already in a position for this magic
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Read last two closed bars (shift=1 most-recent closed, shift=2 previous)
   const double wpr_curr = QM_WPR(_Symbol, PERIOD_H1, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, PERIOD_H1, strategy_wpr_period, 2);
   const double atr      = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const int    trend    = QM_Sig_Price_Above_MA(_Symbol, PERIOD_H1, strategy_ema_period, 0, 1);

   if(atr <= 0.0)
      return false;

   const double sl_dist = atr * strategy_sl_atr_mult;

   // Long: WPR crossed above -50 AND close above EMA(50)
   if(wpr_prev <= -50.0 && wpr_curr > -50.0 && trend > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type        = QM_BUY;
      req.price       = 0.0;
      req.sl          = entry - sl_dist;
      req.tp          = entry + sl_dist * strategy_tp_rr;
      req.reason      = "wpr_cross_up+ema_bull";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   // Short: WPR crossed below -50 AND close below EMA(50)
   if(wpr_prev >= -50.0 && wpr_curr < -50.0 && trend < 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type        = QM_SELL;
      req.price       = 0.0;
      req.sl          = entry + sl_dist;
      req.tp          = entry - sl_dist * strategy_tp_rr;
      req.reason      = "wpr_cross_down+ema_bear";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No dynamic SL/TP management; initial SL/TP handles risk control
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pt       = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime           pos_open = (datetime)PositionGetInteger(POSITION_TIME);

      // Failsafe time exit: strategy_max_hold_bars H1 bars (approximate via calendar hours)
      if((int)((TimeCurrent() - pos_open) / 3600) >= strategy_max_hold_bars)
         return true;

      // Read last two closed bars for signal-based exit
      const double wpr_curr = QM_WPR(_Symbol, PERIOD_H1, strategy_wpr_period, 1);
      const double wpr_prev = QM_WPR(_Symbol, PERIOD_H1, strategy_wpr_period, 2);
      const int    trend    = QM_Sig_Price_Above_MA(_Symbol, PERIOD_H1, strategy_ema_period, 0, 1);

      if(pt == POSITION_TYPE_BUY)
        {
         // Exit long: WPR crosses back below -50 OR close falls below EMA(50)
         if((wpr_prev >= -50.0 && wpr_curr < -50.0) || trend < 0)
            return true;
        }
      else if(pt == POSITION_TYPE_SELL)
        {
         // Exit short: WPR crosses back above -50 OR close rises above EMA(50)
         if((wpr_prev <= -50.0 && wpr_curr > -50.0) || trend > 0)
            return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 in OnTick
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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
