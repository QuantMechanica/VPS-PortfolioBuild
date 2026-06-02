#property strict
#property version   "5.0"
#property description "QM5_10374_v2 Elite Trader MA stack 30-bar breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10374;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int             strategy_fast_sma_period     = 60;
input int             strategy_mid_sma_period      = 90;
input int             strategy_slow_sma_period     = 150;
input int             strategy_breakout_lookback   = 30;
input int             strategy_atr_period          = 20;
input double          strategy_max_stop_atr        = 2.5;
input double          strategy_min_stop_spreads    = 4.0;
input ENUM_TIMEFRAMES strategy_timeframe           = PERIOD_H1;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

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

   static int    setup_dir = 0;
   static double setup_high = 0.0;
   static double setup_low = 0.0;
   static bool   setup_consumed = false;

   const int min_bars = MathMax(strategy_slow_sma_period, strategy_breakout_lookback) + 5;
   if(strategy_fast_sma_period < 1 ||
      strategy_mid_sma_period <= strategy_fast_sma_period ||
      strategy_slow_sma_period <= strategy_mid_sma_period ||
      strategy_breakout_lookback < 1 ||
      strategy_atr_period < 1 ||
      iBars(_Symbol, strategy_timeframe) < MathMax(150, min_bars))
      return false;

   const double sma_fast = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1);
   const double sma_mid = QM_SMA(_Symbol, strategy_timeframe, strategy_mid_sma_period, 1);
   const double sma_slow = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 1);
   if(sma_fast <= 0.0 || sma_mid <= 0.0 || sma_slow <= 0.0)
      return false;

   int current_dir = 0;
   if(sma_fast > sma_mid && sma_mid > sma_slow)
      current_dir = 1;
   else if(sma_fast < sma_mid && sma_mid < sma_slow)
      current_dir = -1;

   if(current_dir == 0)
     {
      setup_dir = 0;
      setup_high = 0.0;
      setup_low = 0.0;
      setup_consumed = false;
      return false;
     }

   if(setup_dir != current_dir)
     {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      const int copied = CopyRates(_Symbol, strategy_timeframe, 2, strategy_breakout_lookback, rates); // perf-allowed: gated by QM_IsNewBar; called once per closed bar for 30-bar range
      if(copied != strategy_breakout_lookback)
         return false;

      double high_ref = -DBL_MAX;
      double low_ref = DBL_MAX;
      for(int i = 0; i < copied; ++i)
        {
         high_ref = MathMax(high_ref, rates[i].high);
         low_ref = MathMin(low_ref, rates[i].low);
        }
      if(high_ref <= 0.0 || low_ref <= 0.0 || high_ref <= low_ref)
         return false;

      setup_dir = current_dir;
      setup_high = high_ref;
      setup_low = low_ref;
      setup_consumed = false;
     }

   if(setup_consumed || setup_high <= 0.0 || setup_low <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlRates signal[];
   ArraySetAsSeries(signal, true);
   if(CopyRates(_Symbol, strategy_timeframe, 1, 1, signal) != 1) // perf-allowed: gated by QM_IsNewBar; single OHLCV bar read
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(point <= 0.0 || spread_points <= 0 || atr <= 0.0)
      return false;

   if(setup_dir > 0 && signal[0].high > setup_high)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double stop_distance = ask - setup_low;
      if(ask <= 0.0 || stop_distance <= 0.0)
         return false;
      if(stop_distance < strategy_min_stop_spreads * (double)spread_points * point)
         return false;
      if(strategy_max_stop_atr > 0.0 && stop_distance > strategy_max_stop_atr * atr)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(setup_low, _Digits);
      req.tp = 0.0;
      req.reason = "QM5_10374_MA_STACK30_LONG";
      setup_consumed = true;
      return true;
     }

   if(setup_dir < 0 && signal[0].low < setup_low)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double stop_distance = setup_high - bid;
      if(bid <= 0.0 || stop_distance <= 0.0)
         return false;
      if(stop_distance < strategy_min_stop_spreads * (double)spread_points * point)
         return false;
      if(strategy_max_stop_atr > 0.0 && stop_distance > strategy_max_stop_atr * atr)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(setup_high, _Digits);
      req.tp = 0.0;
      req.reason = "QM5_10374_MA_STACK30_SHORT";
      setup_consumed = true;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double closed_close = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: single bar read for SMA cross exit check
   const double sma_mid = QM_SMA(_Symbol, strategy_timeframe, strategy_mid_sma_period, 1);
   if(closed_close <= 0.0 || sma_mid <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double stored_level = PositionGetDouble(POSITION_SL);
      if(type == POSITION_TYPE_BUY && (closed_close < sma_mid || (stored_level > 0.0 && closed_close < stored_level)))
         return true;
      if(type == POSITION_TYPE_SELL && (closed_close > sma_mid || (stored_level > 0.0 && closed_close > stored_level)))
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
