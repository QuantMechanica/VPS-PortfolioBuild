#property strict
#property version   "5.0"
#property description "QM5_10905 Carter SMA3/EMA50 oscillator-confirmation trend cross (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_10905_carter-sma3-ema50
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
// 2014, Strategy #1, p.7 (card QM5_10905_carter-sma3-ema50).
//
// Mechanic (H1, EURUSD source symbol; portable to other DWX FX):
//   TRIGGER (the single cross event):
//     Long : SMA(3) crosses ABOVE EMA(50)  (SMA[1]>EMA[1] && SMA[2]<=EMA[2])
//     Short: SMA(3) crosses BELOW EMA(50)  (SMA[1]<EMA[1] && SMA[2]>=EMA[2])
//   CONFIRMATION (a STATE on the same closed bar — not a second cross event,
//   per .DWX invariant #4: two fresh crosses almost never coincide):
//     Long  confirmed if EITHER
//        Full Stochastic %K[1] > EMA8(Stoch %K)[1]   (oscillator above its EMA)
//        OR MACD main[1]       > EMA8(MACD main)[1]
//     Short confirmed if EITHER oscillator is below its EMA-8.
//   Entry at next bar open (framework opens at market on the closed-bar gate).
//
// Exit:
//   Fixed TP 100 pips, fixed SL 50 pips (set as order prices).
//   Fallback time exit: close after 72 H1 bars of holding.
//
// The "EMA(8) of the oscillator" is an EMA applied to an indicator buffer,
// which MT5's pooled iMA cannot read directly. It is reconstructed once per
// closed bar from a small fixed window of closed-bar oscillator values (a
// bounded loop gated by QM_IsNewBar) — bespoke math, framework readers used
// for the underlying Stochastic / MACD values.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10905;
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
// Moving-average cross (Carter Strategy #1).
input int    Strat_SMA_Fast_Period      = 3;     // fast SMA
input int    Strat_EMA_Slow_Period      = 50;    // slow EMA
// Full Stochastic(50,60,30): %K period, %D period, slowing.
input int    Strat_Stoch_K_Period       = 50;
input int    Strat_Stoch_D_Period       = 60;
input int    Strat_Stoch_Slowing        = 30;
// MACD(65,75,35): fast EMA, slow EMA, signal.
input int    Strat_MACD_Fast            = 65;
input int    Strat_MACD_Slow            = 75;
input int    Strat_MACD_Signal          = 35;
// EMA period applied to each oscillator value (Carter confirmation).
input int    Strat_Osc_EMA_Period       = 8;
// Fixed stop / target / time exit.
input int    Strat_SL_Pips              = 50;    // fixed stop
input int    Strat_TP_Pips              = 100;   // fixed target
input int    Strat_Max_Hold_Bars        = 72;    // H1 bars before time exit

// -----------------------------------------------------------------------------
// Oscillator EMA-8 reconstruction over closed bars.
// -----------------------------------------------------------------------------
// EMA over a buffer is seeded with an SMA of the first `period` samples, then
// advanced forward. We read `period + lookback` closed-bar oscillator values
// (oldest first) and roll the EMA forward so the value at the requested
// `target_shift` is returned. All reads are closed-bar (shift>=1) via pooled
// QM_* readers, so this stays O(period) per call and runs once per new bar.

double Strat_EMA8OfStoch(const int target_shift)
  {
   const int period = Strat_Osc_EMA_Period;
   if(period < 1)
      return 0.0;
   const double alpha = 2.0 / (period + 1.0);
   // Oldest sample we need (largest shift): seed window starts here.
   const int oldest = target_shift + period; // a little extra warmup
   double ema = 0.0;
   double seed_sum = 0.0;
   // Seed with SMA of the `period` oldest samples.
   for(int i = 0; i < period; ++i)
      seed_sum += QM_Stoch_K(_Symbol, PERIOD_CURRENT,
                             Strat_Stoch_K_Period, Strat_Stoch_D_Period,
                             Strat_Stoch_Slowing, oldest - i);
   ema = seed_sum / period;
   // Roll forward from (oldest-period) down to target_shift.
   for(int s = oldest - period; s >= target_shift; --s)
     {
      const double v = QM_Stoch_K(_Symbol, PERIOD_CURRENT,
                                  Strat_Stoch_K_Period, Strat_Stoch_D_Period,
                                  Strat_Stoch_Slowing, s);
      ema = alpha * v + (1.0 - alpha) * ema;
     }
   return ema;
  }

double Strat_EMA8OfMACD(const int target_shift)
  {
   const int period = Strat_Osc_EMA_Period;
   if(period < 1)
      return 0.0;
   const double alpha = 2.0 / (period + 1.0);
   const int oldest = target_shift + period;
   double ema = 0.0;
   double seed_sum = 0.0;
   for(int i = 0; i < period; ++i)
      seed_sum += QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                               Strat_MACD_Fast, Strat_MACD_Slow,
                               Strat_MACD_Signal, oldest - i);
   ema = seed_sum / period;
   for(int s = oldest - period; s >= target_shift; --s)
     {
      const double v = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                    Strat_MACD_Fast, Strat_MACD_Slow,
                                    Strat_MACD_Signal, s);
      ema = alpha * v + (1.0 - alpha) * ema;
     }
   return ema;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // MA values at the last two closed bars.
   const double sma1 = QM_SMA(_Symbol, PERIOD_CURRENT, Strat_SMA_Fast_Period, 1);
   const double sma2 = QM_SMA(_Symbol, PERIOD_CURRENT, Strat_SMA_Fast_Period, 2);
   const double ema1 = QM_EMA(_Symbol, PERIOD_CURRENT, Strat_EMA_Slow_Period, 1);
   const double ema2 = QM_EMA(_Symbol, PERIOD_CURRENT, Strat_EMA_Slow_Period, 2);
   if(sma1 == 0.0 || sma2 == 0.0 || ema1 == 0.0 || ema2 == 0.0)
      return false;

   const bool cross_up   = (sma1 > ema1) && (sma2 <= ema2); // trigger long
   const bool cross_down = (sma1 < ema1) && (sma2 >= ema2); // trigger short
   if(!cross_up && !cross_down)
      return false;

   // Oscillator STATES at the last closed bar (confirmation, not a 2nd event).
   const double stoch_v   = QM_Stoch_K(_Symbol, PERIOD_CURRENT,
                                       Strat_Stoch_K_Period, Strat_Stoch_D_Period,
                                       Strat_Stoch_Slowing, 1);
   const double stoch_ema = Strat_EMA8OfStoch(1);
   const double macd_v    = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                         Strat_MACD_Fast, Strat_MACD_Slow,
                                         Strat_MACD_Signal, 1);
   const double macd_ema  = Strat_EMA8OfMACD(1);

   QM_OrderType side;
   if(cross_up)
     {
      // Either oscillator above its own EMA-8 confirms the long.
      const bool confirm = (stoch_v > stoch_ema) || (macd_v > macd_ema);
      if(!confirm)
         return false;
      side = QM_BUY;
     }
   else
     {
      const bool confirm = (stoch_v < stoch_ema) || (macd_v < macd_ema);
      if(!confirm)
         return false;
      side = QM_SELL;
     }

   // Market entry at next bar open; fixed-pip SL/TP as prices.
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type    = side;
   req.price   = 0.0; // framework fills market price at send
   req.sl      = QM_StopFixedPips(_Symbol, side, entry, Strat_SL_Pips);
   req.tp      = QM_TakeFixedPips(_Symbol, side, entry, Strat_TP_Pips);
   req.reason  = (side == QM_BUY) ? "carter_sma3ema50_long" : "carter_sma3ema50_short";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing / break-even — exits are fixed SL/TP plus the time stop below.
  }

bool Strategy_ExitSignal()
  {
   // Fallback time exit: close after Strat_Max_Hold_Bars H1 bars of holding.
   if(Strat_Max_Hold_Bars <= 0)
      return false;
   const int magic = QM_FrameworkMagic();
   const long max_hold_seconds = (long)Strat_Max_Hold_Bars
                                 * PeriodSeconds(PERIOD_CURRENT);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if((long)(TimeCurrent() - opened) >= max_hold_seconds)
         return true; // framework closes all magic-matched positions
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to central QM_NewsAllowsTrade(...)
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
