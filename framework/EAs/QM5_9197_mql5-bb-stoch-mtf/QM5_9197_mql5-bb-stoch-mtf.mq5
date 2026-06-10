#property strict
#property version   "5.0"
#property description "QM5_9197 — BB+Stochastic Multi-Timeframe Mean-Reversion (M15)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QM5_9197  mql5-bb-stoch-mtf
// Source: Christian Benjamin, Price Action Analysis Toolkit Development (Part 7):
//         Signal Pulse EA, MQL5 Articles, 2025-01-16
// Strategy: Mean-reversion using Bollinger Bands + Stochastic across M15/M30/H1.
//   Long when price ≤ lower BB AND Stoch %K ≤ 20 on all three timeframes.
//   Short when price ≥ upper BB AND Stoch %K ≥ 80 on all three timeframes.
//   TP = min(BB middle distance, 1.5R). SL = signal-bar low/high ± ATR(14)*0.5.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9197;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                  = 336;
input string qm_news_min_impact                       = "high";
input QM_NewsMode qm_news_mode_legacy                 = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period         = 20;     // Bollinger Bands period
input double strategy_bb_devs           = 2.0;    // Bollinger Bands deviation
input int    strategy_stoch_k           = 14;     // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slow        = 3;      // Stochastic slowing
input double strategy_stoch_os          = 20.0;   // Oversold threshold (%K <=)
input double strategy_stoch_ob          = 80.0;   // Overbought threshold (%K >=)
input int    strategy_atr_period        = 14;     // ATR period for SL offset
input double strategy_sl_atr_mult       = 0.5;    // SL = bar extreme +/- ATR * mult
input double strategy_tp_rr             = 1.5;    // TP cap: max reward/risk ratio
input int    strategy_min_bar_gap       = 10;     // Min M15 bars between same-dir signals

// Bar-time trackers for minimum-gap filter (per direction)
datetime g_last_long_bar  = 0;
datetime g_last_short_bar = 0;

// -----------------------------------------------------------------------------
// No Trade Filter — runs every tick before entry/exit.
// No custom session or regime filter required by the card.
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Entry Signal — called once per closed M15 bar (QM_IsNewBar gate in OnTick).
// Long: price ≤ lower BB + Stoch %K ≤ oversold on M15, M30, H1.
// Short: price ≥ upper BB + Stoch %K ≥ overbought on M15, M30, H1.
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // MTF BB mean-reversion signals (+1 below lower, -1 above upper, 0 inside)
   const int bb_m15 = QM_Sig_BB_MeanRev(_Symbol, PERIOD_M15, strategy_bb_period, strategy_bb_devs, 1);
   const int bb_m30 = QM_Sig_BB_MeanRev(_Symbol, PERIOD_M30, strategy_bb_period, strategy_bb_devs, 1);
   const int bb_h1  = QM_Sig_BB_MeanRev(_Symbol, PERIOD_H1,  strategy_bb_period, strategy_bb_devs, 1);

   // MTF Stochastic %K (last closed bar on each TF)
   const double stk_m15 = QM_Stoch_K(_Symbol, PERIOD_M15, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double stk_m30 = QM_Stoch_K(_Symbol, PERIOD_M30, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double stk_h1  = QM_Stoch_K(_Symbol, PERIOD_H1,  strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

   // Bar timestamp for gap filter (perf-allowed: single iTime read at closed-bar gate)
   const datetime bar1_time = iTime(_Symbol, PERIOD_M15, 1);

   // ATR for SL offset
   const double atr14 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr14 <= 0.0)
      return false;

   // === LONG ENTRY ===
   if(bb_m15 == 1 && bb_m30 == 1 && bb_h1 == 1 &&
      stk_m15 <= strategy_stoch_os && stk_m30 <= strategy_stoch_os && stk_h1 <= strategy_stoch_os)
     {
      if(bar1_time - g_last_long_bar < (datetime)(strategy_min_bar_gap * PeriodSeconds(PERIOD_M15)))
         return false;

      const double entry   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sig_low = iLow(_Symbol, PERIOD_M15, 1);   // perf-allowed: SL at signal-bar low
      if(sig_low <= 0.0 || entry <= 0.0)
         return false;

      const double sl = NormalizeDouble(sig_low - atr14 * strategy_sl_atr_mult, _Digits);
      if(sl >= entry)
         return false;

      const double sl_dist  = entry - sl;
      const double rr_dist  = sl_dist * strategy_tp_rr;
      const double bb_mid   = QM_BB_Middle(_Symbol, PERIOD_M15, strategy_bb_period, strategy_bb_devs, 1);
      const double bb_dist  = (bb_mid > entry) ? (bb_mid - entry) : 0.0;
      const double tp_dist  = (bb_dist > 0.0) ? MathMin(bb_dist, rr_dist) : rr_dist;
      const double tp       = NormalizeDouble(entry + tp_dist, _Digits);

      req.type             = QM_BUY;
      req.price            = entry;
      req.sl               = sl;
      req.tp               = tp;
      req.reason           = "BB_STOCH_MTF_LONG";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;

      g_last_long_bar = bar1_time;
      return true;
     }

   // === SHORT ENTRY ===
   if(bb_m15 == -1 && bb_m30 == -1 && bb_h1 == -1 &&
      stk_m15 >= strategy_stoch_ob && stk_m30 >= strategy_stoch_ob && stk_h1 >= strategy_stoch_ob)
     {
      if(bar1_time - g_last_short_bar < (datetime)(strategy_min_bar_gap * PeriodSeconds(PERIOD_M15)))
         return false;

      const double entry    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sig_high = iHigh(_Symbol, PERIOD_M15, 1);  // perf-allowed: SL at signal-bar high
      if(sig_high <= 0.0 || entry <= 0.0)
         return false;

      const double sl = NormalizeDouble(sig_high + atr14 * strategy_sl_atr_mult, _Digits);
      if(sl <= entry)
         return false;

      const double sl_dist  = sl - entry;
      const double rr_dist  = sl_dist * strategy_tp_rr;
      const double bb_mid   = QM_BB_Middle(_Symbol, PERIOD_M15, strategy_bb_period, strategy_bb_devs, 1);
      const double bb_dist  = (bb_mid < entry) ? (entry - bb_mid) : 0.0;
      const double tp_dist  = (bb_dist > 0.0) ? MathMin(bb_dist, rr_dist) : rr_dist;
      const double tp       = NormalizeDouble(entry - tp_dist, _Digits);

      req.type             = QM_SELL;
      req.price            = entry;
      req.sl               = sl;
      req.tp               = tp;
      req.reason           = "BB_STOCH_MTF_SHORT";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;

      g_last_short_bar = bar1_time;
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management — no trailing or breakeven required by the card.
// SL/TP set at entry are the only exit mechanisms beyond the signal exit below.
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// -----------------------------------------------------------------------------
// Exit Signal — close on opposite three-timeframe BB+Stoch signal.
// Indicator reads at shift=1 are stable per bar; no per-bar gate needed.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   if(PositionsTotal() == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      const int bb_m15 = QM_Sig_BB_MeanRev(_Symbol, PERIOD_M15, strategy_bb_period, strategy_bb_devs, 1);
      const int bb_m30 = QM_Sig_BB_MeanRev(_Symbol, PERIOD_M30, strategy_bb_period, strategy_bb_devs, 1);
      const int bb_h1  = QM_Sig_BB_MeanRev(_Symbol, PERIOD_H1,  strategy_bb_period, strategy_bb_devs, 1);
      const double stk_m15 = QM_Stoch_K(_Symbol, PERIOD_M15, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
      const double stk_m30 = QM_Stoch_K(_Symbol, PERIOD_M30, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
      const double stk_h1  = QM_Stoch_K(_Symbol, PERIOD_H1,  strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

      if(ptype == POSITION_TYPE_BUY &&
         bb_m15 == -1 && bb_m30 == -1 && bb_h1 == -1 &&
         stk_m15 >= strategy_stoch_ob && stk_m30 >= strategy_stoch_ob && stk_h1 >= strategy_stoch_ob)
         return true;

      if(ptype == POSITION_TYPE_SELL &&
         bb_m15 == 1 && bb_m30 == 1 && bb_h1 == 1 &&
         stk_m15 <= strategy_stoch_os && stk_m30 <= strategy_stoch_os && stk_h1 <= strategy_stoch_os)
         return true;

      return false;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook — defer to framework two-axis filter.
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9197\",\"slug\":\"mql5-bb-stoch-mtf\"}");
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
