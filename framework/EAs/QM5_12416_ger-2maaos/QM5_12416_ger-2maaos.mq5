#property strict
#property version   "5.0"
#property description "QM5_12416 Geraked 2MA Andean Trend Cross"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12416;
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
// FW1 2026-05-23 - Two-axis news filter per Vault Q09.
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
// FW2 2026-05-23 - only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf           = PERIOD_H4;
input int             strategy_aos_period          = 50;
input int             strategy_aos_signal_period   = 9;
input int             strategy_fast_ma_period      = 50;
input int             strategy_slow_ma_period      = 200;
input int             strategy_min_pos_interval    = 6;
input int             strategy_sl_lookback         = 10;
input int             strategy_sl_dev_points       = 100;
input double          strategy_tp_coef             = 1.0;
input int             strategy_spread_limit_points = -1;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_signal_tf)
      return true;

   if(strategy_spread_limit_points >= 0 &&
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_spread_limit_points)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_aos_period <= 0 ||
      strategy_aos_signal_period <= 0 ||
      strategy_fast_ma_period <= 0 ||
      strategy_slow_ma_period <= 0 ||
      strategy_sl_lookback <= 0 ||
      strategy_tp_coef <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int pos_i = PositionsTotal() - 1; pos_i >= 0; --pos_i)
     {
      const ulong ticket = PositionGetTicket(pos_i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int period_seconds = PeriodSeconds(strategy_signal_tf);
   if(strategy_min_pos_interval > 0 && period_seconds > 0)
     {
      const datetime now = TimeCurrent();
      const datetime cutoff = now - (datetime)(strategy_min_pos_interval * period_seconds);
      if(HistorySelect(cutoff, now))
        {
         for(int deal_i = HistoryDealsTotal() - 1; deal_i >= 0; --deal_i)
           {
            const ulong deal = HistoryDealGetTicket(deal_i);
            if(deal == 0)
               continue;
            if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
               continue;
            if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
               continue;
            if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
               return false;
           }
        }
     }

   const int min_needed = MathMax(strategy_slow_ma_period,
                                  strategy_aos_period + strategy_aos_signal_period + strategy_sl_lookback + 5);
   const int warmup = MathMax(strategy_slow_ma_period + 20,
                              strategy_aos_period * 5 + strategy_aos_signal_period + 5);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, warmup, rates); // perf-allowed: custom Andean Oscillator and swing-stop reconstruction, called only from the framework QM_IsNewBar-gated entry hook.
   if(copied < min_needed)
      return false;

   const double alpha = 2.0 / ((double)strategy_aos_period + 1.0);
   const double alpha_signal = 2.0 / ((double)strategy_aos_signal_period + 1.0);
   double up1 = 0.0;
   double up2 = 0.0;
   double dn1 = 0.0;
   double dn2 = 0.0;
   double signal = 0.0;
   double bull_1 = 0.0;
   double bull_2 = 0.0;
   double bear_1 = 0.0;
   double bear_2 = 0.0;
   double signal_1 = 0.0;
   double signal_2 = 0.0;

   for(int idx = copied - 1; idx >= 0; --idx)
     {
      const double open = rates[idx].open;
      const double close = rates[idx].close;
      if(open <= 0.0 || close <= 0.0)
         return false;

      double t = MathMax(close, open);
      up1 = MathMax(t, up1 - (up1 - close) * alpha);
      if(up1 == 0.0)
         up1 = close;

      t = MathMax(close * close, open * open);
      up2 = MathMax(t, up2 - (up2 - close * close) * alpha);
      if(up2 == 0.0)
         up2 = close * close;

      t = MathMin(close, open);
      dn1 = MathMin(t, dn1 + (close - dn1) * alpha);
      if(dn1 == 0.0)
         dn1 = close;

      t = MathMin(close * close, open * open);
      dn2 = MathMin(t, dn2 + (close * close - dn2) * alpha);
      if(dn2 == 0.0)
         dn2 = close * close;

      const double bull = MathSqrt(MathMax(0.0, dn2 - dn1 * dn1));
      const double bear = MathSqrt(MathMax(0.0, up2 - up1 * up1));
      signal = MathMax(bull, bear) * alpha_signal + signal * (1.0 - alpha_signal);

      if(idx == 1)
        {
         bull_2 = bull;
         bear_2 = bear;
         signal_2 = signal;
        }
      else if(idx == 0)
        {
         bull_1 = bull;
         bear_1 = bear;
         signal_1 = signal;
        }
     }

   if(signal_1 <= 0.0 && signal_2 <= 0.0)
      return false;

   const double fast_ma = QM_SMA(_Symbol, strategy_signal_tf, strategy_fast_ma_period, 1, PRICE_CLOSE);
   const double slow_ma = QM_SMA(_Symbol, strategy_signal_tf, strategy_slow_ma_period, 1, PRICE_CLOSE);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(fast_ma <= 0.0 || slow_ma <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double ma_diff = MathAbs(fast_ma - slow_ma);
   const bool long_signal =
      bull_2 <= signal_2 &&
      bull_1 > signal_1 &&
      bull_1 > bear_1 &&
      fast_ma > slow_ma &&
      ask > fast_ma - 0.5 * ma_diff;

   const bool short_signal =
      bear_2 <= signal_2 &&
      bear_1 > signal_1 &&
      bull_1 < bear_1 &&
      fast_ma < slow_ma &&
      bid < fast_ma + 0.5 * ma_diff;

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? ask : bid;
   double sl = 0.0;
   if(QM_OrderTypeIsBuy(side))
     {
      double lowest = DBL_MAX;
      for(int i = 0; i < strategy_sl_lookback; ++i)
        {
         if(rates[i].low <= 0.0)
            return false;
         lowest = MathMin(lowest, rates[i].low);
        }
      if(lowest <= 0.0 || lowest == DBL_MAX)
         return false;
      sl = NormalizeDouble(lowest - strategy_sl_dev_points * point, _Digits);
      if(sl <= 0.0 || sl >= entry)
         return false;
     }
   else
     {
      double highest = -DBL_MAX;
      for(int i = 0; i < strategy_sl_lookback; ++i)
        {
         if(rates[i].high <= 0.0)
            return false;
         highest = MathMax(highest, rates[i].high);
        }
      if(highest <= 0.0 || highest == -DBL_MAX)
         return false;
      sl = NormalizeDouble(highest + strategy_sl_dev_points * point, _Digits);
      if(sl <= entry)
         return false;
     }

   const long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop_dist = (stops_level > 0) ? (double)stops_level * point : point;
   if(long_signal && entry - sl < min_stop_dist)
      return false;
   if(short_signal && sl - entry < min_stop_dist)
      return false;

   const double tp = NormalizeDouble(long_signal
                                     ? entry + strategy_tp_coef * MathAbs(entry - sl)
                                     : entry - strategy_tp_coef * MathAbs(entry - sl),
                                     _Digits);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "GER_2MAAOS_LONG" : "GER_2MAAOS_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // V5 baseline disables the source trailing and grid overlays; exits are SL/TP.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // No signal-close rule in the approved card.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
   // FW1 - 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
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
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 - emit end-of-day equity snapshot if the day rolled
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

