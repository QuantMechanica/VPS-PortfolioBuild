#property strict
#property version   "5.0"
#property description "QM5_11332 TC-M5 System #18 EMA20 MACD Cross Trail"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

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
input int    qm_ea_id                   = 11332;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_ema_period        = 20;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_macd_lookback     = 5;
input double strategy_entry_offset_pips = 10.0;
input double strategy_stop_ema_pips     = 20.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_cap_mult      = 1.5;
input double strategy_trail_ema_pips    = 15.0;
input double strategy_partial_pct       = 50.0;
input double strategy_spread_cap_pips   = 12.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || pip <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_pips = (ask - bid) / pip;
   if(spread_pips > strategy_spread_cap_pips)
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

   if(strategy_ema_period < 2 ||
      strategy_macd_fast < 1 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 ||
      strategy_macd_lookback < 1 ||
      strategy_entry_offset_pips <= 0.0 ||
      strategy_stop_ema_pips <= 0.0 ||
      strategy_atr_period < 1 ||
      strategy_atr_cap_mult <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP ||
         order_type == ORDER_TYPE_SELL_STOP ||
         order_type == ORDER_TYPE_BUY_LIMIT ||
         order_type == ORDER_TYPE_SELL_LIMIT)
         return false;
     }

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_M5;
   const int price_side_1 = QM_Sig_Price_Above_MA(_Symbol, tf, strategy_ema_period, 0.0, 1);
   const int price_side_2 = QM_Sig_Price_Above_MA(_Symbol, tf, strategy_ema_period, 0.0, 2);
   const bool ema_cross_long = (price_side_2 < 0 && price_side_1 > 0);
   const bool ema_cross_short = (price_side_2 > 0 && price_side_1 < 0);
   if(!ema_cross_long && !ema_cross_short)
      return false;

   bool macd_long = false;
   bool macd_short = false;
   for(int shift = 1; shift <= strategy_macd_lookback; ++shift)
     {
      const double macd_now = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
      const double macd_prev = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
      if(macd_prev < 0.0 && macd_now > 0.0)
         macd_long = true;
      if(macd_prev > 0.0 && macd_now < 0.0)
         macd_short = true;
     }

   const double ema = QM_EMA(_Symbol, tf, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ema <= 0.0 || atr <= 0.0 || point <= 0.0 || pip <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double entry_offset = strategy_entry_offset_pips * pip;
   const double ema_stop_offset = strategy_stop_ema_pips * pip;
   const double atr_cap = strategy_atr_cap_mult * atr;
   const int expiry_seconds = PeriodSeconds(tf);

   if(ema_cross_long && macd_long)
     {
      const double entry = NormalizeDouble(ema + entry_offset, _Digits);
      const double raw_sl = ema - ema_stop_offset;
      const double raw_dist = entry - raw_sl;
      if(raw_dist <= 0.0 || atr_cap <= 0.0)
         return false;
      const double sl_dist = MathMin(raw_dist, atr_cap);
      const double sl = NormalizeDouble(entry - sl_dist, _Digits);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = (ask >= entry) ? QM_BUY : QM_BUY_STOP;
      req.price = (req.type == QM_BUY_STOP) ? entry : 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "TC18_EMA20_MACD_LONG";
      req.expiration_seconds = (req.type == QM_BUY_STOP) ? expiry_seconds : 0;
      return true;
     }

   if(ema_cross_short && macd_short)
     {
      const double entry = NormalizeDouble(ema - entry_offset, _Digits);
      const double raw_sl = ema + ema_stop_offset;
      const double raw_dist = raw_sl - entry;
      if(raw_dist <= 0.0 || atr_cap <= 0.0)
         return false;
      const double sl_dist = MathMin(raw_dist, atr_cap);
      const double sl = NormalizeDouble(entry + sl_dist, _Digits);
      if(sl <= 0.0 || sl <= entry)
         return false;

      req.type = (bid <= entry) ? QM_SELL : QM_SELL_STOP;
      req.price = (req.type == QM_SELL_STOP) ? entry : 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "TC18_EMA20_MACD_SHORT";
      req.expiration_seconds = (req.type == QM_SELL_STOP) ? expiry_seconds : 0;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(strategy_trail_ema_pips <= 0.0 || strategy_partial_pct <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
   if(point <= 0.0 || pip <= 0.0)
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
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || current_sl <= 0.0 || volume <= 0.0 || market <= 0.0)
         continue;

      bool partial_done = is_buy ? (current_sl >= open_price) : (current_sl <= open_price);
      const double risk_distance = is_buy ? (open_price - current_sl) : (current_sl - open_price);
      if(!partial_done && risk_distance > 0.0)
        {
         const double trigger = is_buy ? (open_price + risk_distance) : (open_price - risk_distance);
         const bool hit_1r = is_buy ? (market >= trigger) : (market <= trigger);
         if(hit_1r)
           {
            const double partial_lots = volume * MathMin(100.0, strategy_partial_pct) / 100.0;
            if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
              {
               QM_TM_MoveSL(ticket, open_price, "TC18_BE_AFTER_1R_PARTIAL");
               continue;
              }
           }
        }

      if(!partial_done)
         continue;

      const double ema = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1);
      if(ema <= 0.0)
         continue;

      const double raw_trail = is_buy ? (ema - strategy_trail_ema_pips * pip)
                                      : (ema + strategy_trail_ema_pips * pip);
      const double trail_sl = NormalizeDouble(raw_trail, _Digits);
      if(trail_sl <= 0.0)
         continue;

      const bool improves = is_buy ? (trail_sl > current_sl + point * 0.5 && trail_sl < market)
                                   : (trail_sl < current_sl - point * 0.5 && trail_sl > market);
      if(improves)
         QM_TM_MoveSL(ticket, trail_sl, "TC18_EMA20_TRAIL_REMAINDER");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits via 1R partial, breakeven, EMA20 trailing SL, and framework Friday close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
