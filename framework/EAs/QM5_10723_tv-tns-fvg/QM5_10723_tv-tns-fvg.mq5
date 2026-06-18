#property strict
#property version   "5.0"
#property description "QM5_10723 TradingView Tap'n'Slap FVG"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
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
input int    qm_ea_id                   = 10723;
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
input int    strategy_fvg_max_age            = 30;
input int    strategy_min_tap_age            = 3;
input int    strategy_pivot_length           = 8;
input int    strategy_atr_period             = 14;
input double strategy_stop_atr_mult          = 0.75;
input double strategy_stop_atr_cap_mult      = 2.5;
input double strategy_min_rr                 = 1.5;
input double strategy_be_trigger_r           = 0.8;
input int    strategy_be_lock_points         = 5;
input bool   strategy_filter_weak_sl         = true;
input int    strategy_edge_offset_points     = 0;
input int    strategy_max_trades_per_day     = 3;
input bool   strategy_use_symbol_session     = true;
input int    strategy_session_start_hhmm     = 1630;
input int    strategy_entry_cutoff_hhmm      = 2230;
input int    strategy_session_end_hhmm       = 2300;
input int    strategy_max_spread_points      = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): central news and Friday gates run in
// the framework; this hook only adds the optional card-safe spread ceiling.
// Return TRUE to BLOCK trading this tick. Cheap O(1) checks only.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      if(ask > bid && ((ask - bid) / point) > strategy_max_spread_points)
         return true;
     }
   return false;
  }

// Trade Entry: detect active FVGs, confirm a qualifying tap candle, and enter
// at market on the next closed-bar evaluation with ATR stop and pivot target.
// Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   static int trade_day_key = 0;
   static int trades_today = 0;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int day_key = now_dt.year * 10000 + now_dt.mon * 100 + now_dt.day;
   if(day_key != trade_day_key)
     {
      trade_day_key = day_key;
      trades_today = 0;
     }

   if(strategy_max_trades_per_day > 0 && trades_today >= strategy_max_trades_per_day)
      return false;

   int session_start = strategy_session_start_hhmm;
   int entry_cutoff = strategy_entry_cutoff_hhmm;
   if(strategy_use_symbol_session && StringFind(_Symbol, "GDAXI") >= 0)
     {
      session_start = 1000;
      entry_cutoff = 1830;
     }

   const int hhmm = now_dt.hour * 100 + now_dt.min;
   if(hhmm < session_start || hhmm >= entry_cutoff)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
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

   const int fvg_age = MathMax(3, strategy_fvg_max_age);
   const int pivot_window = MathMax(1, strategy_pivot_length);
   const int bars_needed = MathMax(fvg_age + 4, pivot_window * 2 + fvg_age + 8);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, bars_needed, rates); // perf-allowed: bounded FVG and pivot scan inside framework closed-bar entry gate.
   if(copied < bars_needed)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double min_stop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const double cap = atr * strategy_stop_atr_cap_mult;
   double stop_dist = MathMax(atr * strategy_stop_atr_mult, min_stop);
   if(cap > 0.0 && min_stop <= cap)
      stop_dist = MathMin(stop_dist, cap);
   if(stop_dist <= 0.0)
      return false;

   const double edge = MathMax(0, strategy_edge_offset_points) * point;
   const MqlRates tap = rates[1];
   const int min_shift = MathMax(1, strategy_min_tap_age) + 1;
   const int max_shift = MathMin(strategy_fvg_max_age + 1, copied - 3);

   for(int shift = min_shift; shift <= max_shift; ++shift)
     {
      if(rates[shift].low > rates[shift + 2].high)
        {
         const double zone_low = rates[shift + 2].high;
         const double zone_high = rates[shift].low;
         const bool bearish_tap = (tap.close < tap.open);
         const bool high_inside = (tap.high >= zone_low + edge && tap.high <= zone_high - edge);
         const bool tapped_zone = (tap.low <= zone_high);
         if(bearish_tap && high_inside && tapped_zone)
           {
            const double entry = ask;
            const double sl = NormalizeDouble(entry - stop_dist, _Digits);
            if(strategy_filter_weak_sl && sl >= zone_low && sl <= zone_high)
               continue;

            double tp = 0.0;
            for(int p = pivot_window + 1; p < copied - pivot_window; ++p)
              {
               bool pivot = true;
               const double h = rates[p].high;
               for(int k = p - pivot_window; k <= p + pivot_window; ++k)
                 {
                  if(k == p)
                     continue;
                  if(rates[k].high >= h)
                    {
                     pivot = false;
                     break;
                    }
                 }
               if(!pivot || h <= entry)
                  continue;
               if(tp <= 0.0 || h < tp)
                  tp = h;
              }

            const double risk = MathAbs(entry - sl);
            const double reward = MathAbs(tp - entry);
            if(tp <= 0.0 || risk <= 0.0 || reward / risk < strategy_min_rr)
               continue;

            req.type = QM_BUY;
            req.price = 0.0;
            req.sl = sl;
            req.tp = NormalizeDouble(tp, _Digits);
            req.reason = "TNS_FVG_LONG_TAP";
            trades_today++;
            return true;
           }
        }

      if(rates[shift].high < rates[shift + 2].low)
        {
         const double zone_low = rates[shift].high;
         const double zone_high = rates[shift + 2].low;
         const bool bullish_tap = (tap.close > tap.open);
         const bool low_inside = (tap.low >= zone_low + edge && tap.low <= zone_high - edge);
         const bool tapped_zone = (tap.high >= zone_low);
         if(bullish_tap && low_inside && tapped_zone)
           {
            const double entry = bid;
            const double sl = NormalizeDouble(entry + stop_dist, _Digits);
            if(strategy_filter_weak_sl && sl >= zone_low && sl <= zone_high)
               continue;

            double tp = 0.0;
            for(int p = pivot_window + 1; p < copied - pivot_window; ++p)
              {
               bool pivot = true;
               const double l = rates[p].low;
               for(int k = p - pivot_window; k <= p + pivot_window; ++k)
                 {
                  if(k == p)
                     continue;
                  if(rates[k].low <= l)
                    {
                     pivot = false;
                     break;
                    }
                 }
               if(!pivot || l >= entry)
                  continue;
               if(tp <= 0.0 || l > tp)
                  tp = l;
              }

            const double risk = MathAbs(entry - sl);
            const double reward = MathAbs(tp - entry);
            if(tp <= 0.0 || risk <= 0.0 || reward / risk < strategy_min_rr)
               continue;

            req.type = QM_SELL;
            req.price = 0.0;
            req.sl = sl;
            req.tp = NormalizeDouble(tp, _Digits);
            req.reason = "TNS_FVG_SHORT_TAP";
            trades_today++;
            return true;
           }
        }
     }

   return false;
  }

// Trade Management: move stop to breakeven plus lock offset after +0.8R.
// No trailing is used in the baseline.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(magic <= 0 || point <= 0.0 || strategy_be_trigger_r <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double initial_r = MathAbs(open_price - current_sl);
      if(market <= 0.0 || initial_r <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < initial_r * strategy_be_trigger_r)
         continue;

      const double lock = MathMax(0, strategy_be_lock_points) * point;
      const double target_sl = is_buy ? open_price + lock : open_price - lock;
      const bool improves = is_buy ? (target_sl > current_sl + point * 0.5)
                                   : (target_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, NormalizeDouble(target_sl, _Digits), "tns_fvg_be_lock");
     }
  }

// Trade Close: force-flat at the regular-session end. SL/TP remain broker-side.
bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int session_end = strategy_session_end_hhmm;
   if(strategy_use_symbol_session && StringFind(_Symbol, "GDAXI") >= 0)
      session_end = 1900;
   return (dt.hour * 100 + dt.min >= session_end);
  }

// News Filter Hook: no strategy-specific override; central P8-compatible
// framework news filter remains callable.
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
