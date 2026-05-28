#property strict
#property version   "5.0"
#property description "QM5_10345 Elite Trader Oil LWMA RSI Impulse Scalp"

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
input int    qm_ea_id                   = 10345;
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
// TODO: declare strategy-specific input params here, e.g.:
//   input int    strategy_atr_period   = 14;
//   input double strategy_atr_sl_mult  = 2.0;
//   input double strategy_atr_tp_mult  = 3.0;
input int    strategy_lwma_fast         = 36;
input int    strategy_lwma_mid          = 75;
input int    strategy_lwma_slow         = 120;
input int    strategy_rsi_period        = 14;
input double strategy_rsi_long_level    = 50.0;
input double strategy_rsi_short_level   = 50.0;
input int    strategy_atr_period        = 14;
input double strategy_impulse_mult      = 1.0;
input double strategy_pullback_atr_mult = 0.25;
input double strategy_sl_atr_mult       = 1.0;
input double strategy_tp_atr_mult       = 1.0;
input double strategy_trail_atr_mult    = 1.0;
input int    strategy_swing_lookback    = 10;
input int    strategy_session_start_h   = 7;
input int    strategy_session_end_h     = 20;
input int    strategy_spread_median_bars = 30;
input double strategy_spread_median_mult = 2.0;

int Strategy_Hour(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

bool Strategy_InSession(const datetime t)
  {
   const int h = Strategy_Hour(t);
   if(strategy_session_start_h == strategy_session_end_h)
      return true;
   if(strategy_session_start_h < strategy_session_end_h)
      return (h >= strategy_session_start_h && h < strategy_session_end_h);
   return (h >= strategy_session_start_h || h < strategy_session_end_h);
  }

double Strategy_MedianRecentSpread()
  {
   const int bars = (strategy_spread_median_bars > 1) ? strategy_spread_median_bars : 1;
   double spreads[];
   ArrayResize(spreads, bars);
   int n = 0;
   for(int shift = 1; shift <= bars; ++shift)
     {
      const long spread = iSpread(_Symbol, _Period, shift);
      if(spread <= 0)
         continue;
      spreads[n] = (double)spread;
      n++;
     }
   if(n <= 0)
      return 0.0;
   ArrayResize(spreads, n);
   ArraySort(spreads);
   if((n % 2) == 1)
      return spreads[n / 2];
   return 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double median_spread = Strategy_MedianRecentSpread();
   if(current_spread <= 0 || median_spread <= 0.0)
      return false;
   return ((double)current_spread <= strategy_spread_median_mult * median_spread);
  }

bool Strategy_HigherSwingHighs()
  {
   const int lookback = (strategy_swing_lookback > 4) ? strategy_swing_lookback : 4;
   int found = 0;
   double newer = 0.0;
   double older = 0.0;
   for(int shift = 2; shift <= lookback - 1; ++shift)
     {
      const double h0 = iHigh(_Symbol, _Period, shift);
      const double hp = iHigh(_Symbol, _Period, shift + 1);
      const double hn = iHigh(_Symbol, _Period, shift - 1);
      if(h0 <= 0.0 || hp <= 0.0 || hn <= 0.0)
         continue;
      if(h0 > hp && h0 > hn)
        {
         if(found == 0)
            newer = h0;
         else if(found == 1)
           {
            older = h0;
            break;
           }
         found++;
        }
     }
   return (newer > 0.0 && older > 0.0 && newer > older);
  }

bool Strategy_LowerSwingLows()
  {
   const int lookback = (strategy_swing_lookback > 4) ? strategy_swing_lookback : 4;
   int found = 0;
   double newer = 0.0;
   double older = 0.0;
   for(int shift = 2; shift <= lookback - 1; ++shift)
     {
      const double l0 = iLow(_Symbol, _Period, shift);
      const double lp = iLow(_Symbol, _Period, shift + 1);
      const double ln = iLow(_Symbol, _Period, shift - 1);
      if(l0 <= 0.0 || lp <= 0.0 || ln <= 0.0)
         continue;
      if(l0 < lp && l0 < ln)
        {
         if(found == 0)
            newer = l0;
         else if(found == 1)
           {
            older = l0;
            break;
           }
         found++;
        }
     }
   return (newer > 0.0 && older > 0.0 && newer < older);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): news is handled by the framework.
   // Session and spread are entry-only gates so required exits still fire.
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

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_InSession(TimeCurrent()))
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_M1;
   const double close1 = iClose(_Symbol, tf, 1);
   const double lwma_fast = QM_LWMA(_Symbol, tf, strategy_lwma_fast, 1);
   const double lwma_mid = QM_LWMA(_Symbol, tf, strategy_lwma_mid, 1);
   const double lwma_slow = QM_LWMA(_Symbol, tf, strategy_lwma_slow, 1);
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double macd_main = QM_MACD_Main(_Symbol, tf, 12, 26, 9, 1);
   const double macd_signal = QM_MACD_Signal(_Symbol, tf, 12, 26, 9, 1);
   if(close1 <= 0.0 || lwma_fast <= 0.0 || lwma_mid <= 0.0 || lwma_slow <= 0.0 ||
      rsi <= 0.0 || atr <= 0.0)
      return false;

   const double impulse = macd_main - macd_signal;
   const double impulse_threshold = strategy_impulse_mult * atr / close1;
   const double pullback_distance = strategy_pullback_atr_mult * atr;
   if(impulse_threshold <= 0.0 || pullback_distance <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const bool long_setup =
      (lwma_fast > lwma_mid && lwma_mid > lwma_slow &&
       close1 > lwma_fast &&
       rsi > strategy_rsi_long_level &&
       impulse > 0.0 && MathAbs(impulse) > impulse_threshold &&
       Strategy_HigherSwingHighs() &&
       MathAbs(close1 - lwma_fast) <= pullback_distance);

   const bool short_setup =
      (lwma_fast < lwma_mid && lwma_mid < lwma_slow &&
       close1 < lwma_fast &&
       rsi < strategy_rsi_short_level &&
       impulse < 0.0 && MathAbs(impulse) > impulse_threshold &&
       Strategy_LowerSwingLows() &&
       MathAbs(close1 - lwma_fast) <= pullback_distance);

   if(!long_setup && !short_setup)
      return false;

   req.type = long_setup ? QM_BUY : QM_SELL;
   req.price = long_setup ? ask : bid;
   const double sl_distance = MathMax(strategy_sl_atr_mult * atr, 2.0 * (ask - bid));
   const double tp_distance = strategy_tp_atr_mult * atr;
   if(sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   req.sl = long_setup ? (req.price - sl_distance) : (req.price + sl_distance);
   req.tp = long_setup ? (req.price + tp_distance) : (req.price - tp_distance);
   req.reason = long_setup ? "LWMA_RSI_IMPULSE_LONG" : "LWMA_RSI_IMPULSE_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: move to break-even after +1R, then trail by ATR.
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || current_sl <= 0.0 || market <= 0.0)
         continue;

      const double initial_risk = MathAbs(open_price - current_sl);
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(initial_risk > 0.0 && moved >= initial_risk)
        {
         const double be_sl = open_price;
         const bool improves_to_be = is_buy ? (current_sl < be_sl - point * 0.5)
                                            : (current_sl > be_sl + point * 0.5);
         if(improves_to_be)
            QM_TM_MoveSL(ticket, be_sl, "break_even_after_1R");
        }

      const bool at_or_beyond_be = is_buy ? (current_sl >= open_price - point * 0.5)
                                          : (current_sl <= open_price + point * 0.5);
      if(!at_or_beyond_be)
         continue;

      const double trail_sl = is_buy ? (market - atr * strategy_trail_atr_mult)
                                     : (market + atr * strategy_trail_atr_mult);
      const bool improves_trail = is_buy ? (trail_sl > current_sl + point * 0.5)
                                         : (trail_sl < current_sl - point * 0.5);
      if(improves_trail)
         QM_TM_MoveSL(ticket, trail_sl, "atr_trail_after_be");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: end-of-session close plus LWMA slope / RSI regime exits.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(!Strategy_InSession(TimeCurrent()))
         return true;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double lwma1 = QM_LWMA(_Symbol, PERIOD_M1, strategy_lwma_fast, 1);
      const double lwma2 = QM_LWMA(_Symbol, PERIOD_M1, strategy_lwma_fast, 2);
      const double lwma3 = QM_LWMA(_Symbol, PERIOD_M1, strategy_lwma_fast, 3);
      const double rsi1 = QM_RSI(_Symbol, PERIOD_M1, strategy_rsi_period, 1);
      const double rsi2 = QM_RSI(_Symbol, PERIOD_M1, strategy_rsi_period, 2);
      if(lwma1 <= 0.0 || lwma2 <= 0.0 || lwma3 <= 0.0 || rsi1 <= 0.0 || rsi2 <= 0.0)
         continue;

      if(position_type == POSITION_TYPE_BUY)
        {
         if(lwma1 < lwma2 && lwma2 < lwma3)
            return true;
         if(rsi2 >= strategy_rsi_long_level && rsi1 < strategy_rsi_long_level)
            return true;
        }
      else if(position_type == POSITION_TYPE_SELL)
        {
         if(lwma1 > lwma2 && lwma2 > lwma3)
            return true;
         if(rsi2 <= strategy_rsi_short_level && rsi1 > strategy_rsi_short_level)
            return true;
        }
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: callable for P8; central framework filter remains authoritative.
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
