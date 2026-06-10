#property strict
#property version   "5.0"
#property description "QM5_9195 Multi-Timeframe Signal Pulse (BB + Stochastic)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QM5_9195 mql5-signal-pulse
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9195_mql5-signal-pulse.md
// Source: Allan Munene Mutiiria, MQL5 Articles 2025-01-21 (ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb)
// Strategy: M15 BB mean-reversion with Stochastic cross + H1 pulse confirmation.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9195;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                 = 336;
input string qm_news_min_impact                      = "high";
input QM_NewsMode qm_news_mode_legacy                = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled                 = true;
input int    qm_friday_close_hour_broker             = 21;

input group "Stress"
input double qm_stress_reject_probability            = 0.0;

input group "Strategy"
input int             strategy_bb_period             = 20;
input double          strategy_bb_deviation          = 2.0;
input int             strategy_stoch_k               = 5;
input int             strategy_stoch_d               = 3;
input int             strategy_stoch_slow            = 3;
input double          strategy_stoch_ob              = 80.0;   // overbought threshold
input double          strategy_stoch_os              = 20.0;   // oversold threshold
input int             strategy_atr_period            = 14;
input double          strategy_atr_sl_mult           = 0.5;    // SL = candle_extreme ± ATR * mult
input double          strategy_tp_rr                 = 2.0;    // TP = entry + rr * sl_distance (2R)
input int             strategy_bbw_lookback          = 100;    // BB-width filter lookback
input double          strategy_bbw_min_ratio         = 0.5;    // skip if BBW < median * ratio
input ENUM_TIMEFRAMES strategy_htf                   = PERIOD_H1; // higher TF pulse confirmation

// -----------------------------------------------------------------------------
// No Trade Filter
// BB-width filter lives in EntrySignal (needs closed-bar indicator data); this
// hook is reserved for O(1) tick-level guards that could be added later.
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// Closed-bar logic (called only after QM_IsNewBar() from OnTick scaffold).
// Long:  M15 close <= lower BB  + Stoch K oversold & crosses above D  + H1 K < 50
// Short: M15 close >= upper BB  + Stoch K overbought & crosses below D + H1 K > 50
// Filter: skip if current BB width < strategy_bbw_lookback-bar median * strategy_bbw_min_ratio
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type              = QM_BUY;
   req.price             = 0.0;
   req.sl                = 0.0;
   req.tp                = 0.0;
   req.reason            = "";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One position per magic
   if(QM_EntryHasOpenPosition(QM_FrameworkMagic(), _Symbol))
      return false;

   // --- BB width filter ---
   // Compute lookback BB widths, sort, take median; skip if current width is too narrow.
   double bbw_arr[];
   ArrayResize(bbw_arr, strategy_bbw_lookback);
   for(int i = 0; i < strategy_bbw_lookback; i++)
     {
      bbw_arr[i] = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, i + 1)
                 - QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, i + 1);
     }
   ArraySort(bbw_arr);
   const double bbw_median = bbw_arr[strategy_bbw_lookback / 2];
   const double bbw_cur    = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1)
                           - QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   if(bbw_median > 0.0 && bbw_cur < bbw_median * strategy_bbw_min_ratio)
      return false;

   // --- BB signal (shift=1 = last closed bar) ---
   // +1 → close < lower band (mean-rev long), -1 → close > upper band (mean-rev short)
   const int bb_sig = QM_Sig_BB_MeanRev(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_sig == 0)
      return false;

   // --- Stochastic on M15 (two shifts for cross detection) ---
   const double k1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);

   // --- H1 pulse: stochastic K position vs midline ---
   const double htf_k1 = QM_Stoch_K(_Symbol, strategy_htf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

   // --- ATR for stop distance ---
   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // Signal candle high/low for SL anchor — perf-allowed: structural stop anchor, one read per bar
   const double low1  = iLow(_Symbol,  PERIOD_CURRENT, 1);  // perf-allowed: signal candle SL anchor
   const double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed: signal candle SL anchor

   // === LONG ===
   if(bb_sig > 0)
     {
      // Stochastic oversold AND K just crossed above D
      const bool stoch_long = (k1 < strategy_stoch_os) && (k1 > d1) && (k2 <= d2);
      // H1 pulse: stoch K below 50 (confirms mean-reversion long bias)
      const bool htf_long   = (htf_k1 < 50.0);
      if(!stoch_long || !htf_long)
         return false;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl  = NormalizeDouble(low1 - atr * strategy_atr_sl_mult, _Digits);
      if(sl <= 0.0 || ask <= sl)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = NormalizeDouble(ask + strategy_tp_rr * (ask - sl), _Digits);
      req.reason = "SIGNAL_PULSE_LONG";
      return true;
     }

   // === SHORT ===
   if(bb_sig < 0)
     {
      // Stochastic overbought AND K just crossed below D
      const bool stoch_short = (k1 > strategy_stoch_ob) && (k1 < d1) && (k2 >= d2);
      // H1 pulse: stoch K above 50 (confirms mean-reversion short bias)
      const bool htf_short   = (htf_k1 > 50.0);
      if(!stoch_short || !htf_short)
         return false;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl  = NormalizeDouble(high1 + atr * strategy_atr_sl_mult, _Digits);
      if(bid <= 0.0 || sl <= bid)
         return false;
      const double tp = NormalizeDouble(bid - strategy_tp_rr * (sl - bid), _Digits);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "SIGNAL_PULSE_SHORT";
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// SL/TP handle primary exits; no active trailing for this strategy.
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// -----------------------------------------------------------------------------
// Trade Close
// Closes on opposite confirmed pulse: opposite BB band touch + stochastic reversal.
// Fires per-tick; the indicator values at shift=1 are closed-bar stable.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   if(!QM_EntryHasOpenPosition(QM_FrameworkMagic(), _Symbol))
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
      // bb_sig: +1 = close at/below lower band, -1 = close at/above upper band
      const int    bb_sig  = QM_Sig_BB_MeanRev(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_deviation, 1);
      const double stoch_k = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

      if(ptype == POSITION_TYPE_BUY && bb_sig < 0 && stoch_k > strategy_stoch_ob)
         return true;   // bearish pulse → close long
      if(ptype == POSITION_TYPE_SELL && bb_sig > 0 && stoch_k < strategy_stoch_os)
         return true;   // bullish pulse → close short
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// Defer to the framework's QM_NewsAllowsTrade2 (called from OnTick scaffold).
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
