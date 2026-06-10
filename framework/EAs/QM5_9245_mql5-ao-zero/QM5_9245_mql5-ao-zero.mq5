#property strict
#property version   "5.0"
#property description "QM5_9245 Awesome Oscillator Zero Cross (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9245 — mql5-ao-zero
// Entry: AO crosses above/below zero on a closed H4 bar (noise-filtered).
// Exit:  Opposite AO zero-line cross, or 30-bar failsafe time stop.
// Stop:  ATR(14) * 1.8; TP: 2.2R.
// Source: Stephen Njuki, "MQL5 Wizard Techniques (Part 50): Awesome Oscillator"
// =============================================================================

// ---- AO pool wrapper (iAO not in QM_Indicators forbidden list) --------------

int QM_IndAOLocal(const string sym, const ENUM_TIMEFRAMES tf)
  {
   const string key = StringFormat("AO|%s|%d", sym, (int)tf);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   return QM_IndicatorsRegister(key, iAO(sym, tf));
  }

double QM_AOLocal(const string sym, const ENUM_TIMEFRAMES tf, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndAOLocal(sym, tf), 0, shift);
  }

// =============================================================================
// Inputs

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9245;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;    // ATR period for SL/TP sizing
input double strategy_atr_sl_mult         = 1.8;   // SL = ATR * mult
input double strategy_tp_rr               = 2.2;   // TP = SL_dist * rr
input int    strategy_ao_noise_lookback   = 50;    // Median |AO| lookback
input double strategy_ao_noise_mult       = 0.2;   // Noise threshold: |AO| > mult * median
input int    strategy_time_stop_bars      = 30;    // Failsafe exit after N H4 bars

// =============================================================================
// Per-bar state — updated inside Strategy_EntrySignal (new-bar gated)
int g_bars_held = 0;

// =============================================================================
// Strategy hooks

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Called once per new H4 bar (gated by QM_IsNewBar in OnTick wiring).
// Also maintains g_bars_held for the time-stop in Strategy_ExitSignal.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double ao1 = QM_AOLocal(_Symbol, PERIOD_H4, 1);  // last closed bar
   const double ao2 = QM_AOLocal(_Symbol, PERIOD_H4, 2);  // bar before last
   if(ao1 == 0.0 || ao2 == 0.0)
      return false;

   // Median |AO| noise filter — O(N) reads at new-bar cadence only
   double ao_median = 0.0;
   if(strategy_ao_noise_lookback > 1)
     {
      int h  = QM_IndAOLocal(_Symbol, PERIOD_H4);
      int lb = strategy_ao_noise_lookback;
      double vals[];
      ArrayResize(vals, lb);
      for(int i = 0; i < lb; i++)
         vals[i] = MathAbs(QM_IndicatorReadBuffer(h, 0, i + 1));
      ArraySort(vals);
      ao_median = (lb % 2 == 0)
                  ? (vals[lb / 2 - 1] + vals[lb / 2]) * 0.5
                  : vals[lb / 2];
     }

   // Update bars-held counter (per-bar, uses new-bar gate from OnTick wiring)
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(!PositionSelectByTicket(PositionGetTicket(i)))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_position = true;
      g_bars_held++;
      break;
     }
   if(!has_position)
      g_bars_held = 0;

   if(has_position)
      return false;

   // AO zero-line cross signal
   const bool long_signal  = (ao2 < 0.0 && ao1 > 0.0);
   const bool short_signal = (ao2 > 0.0 && ao1 < 0.0);
   if(!long_signal && !short_signal)
      return false;

   // Noise filter: signal bar must have meaningful AO magnitude
   if(ao_median > 0.0 && MathAbs(ao1) <= strategy_ao_noise_mult * ao_median)
      return false;

   const QM_OrderType side  = long_signal ? QM_BUY : QM_SELL;
   const double entry_price = (side == QM_BUY)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl_dist = atr * strategy_atr_sl_mult;
   const double sl = (side == QM_BUY) ? entry_price - sl_dist
                                       : entry_price + sl_dist;
   const double tp = (side == QM_BUY) ? entry_price + sl_dist * strategy_tp_rr
                                       : entry_price - sl_dist * strategy_tp_rr;

   req.type        = side;
   req.price       = 0.0;
   req.sl          = sl;
   req.tp          = tp;
   req.reason      = long_signal ? "AO_ZERO_CROSS_LONG" : "AO_ZERO_CROSS_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No active trade management beyond the SL/TP set at entry.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      if(!PositionSelectByTicket(PositionGetTicket(i)))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Failsafe time stop
      if(g_bars_held >= strategy_time_stop_bars)
         return true;

      // AO zero-line re-cross exit (closed-bar values, stable within bar)
      const double ao1 = QM_AOLocal(_Symbol, PERIOD_H4, 1);
      const double ao2 = QM_AOLocal(_Symbol, PERIOD_H4, 2);
      if(ao1 == 0.0 || ao2 == 0.0)
         continue;

      const ENUM_POSITION_TYPE pt =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY  && ao2 > 0.0 && ao1 < 0.0)
         return true;
      if(pt == POSITION_TYPE_SELL && ao2 < 0.0 && ao1 > 0.0)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line

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
                        const MqlTradeRequest       &request,
                        const MqlTradeResult        &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
