#property strict
#property version   "5.0"
#property description "QM5_11494 Carter MTF triple EMA and Bollinger alignment"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 11494;
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
input int    strategy_ema_fast_period    = 14;
input int    strategy_ema_mid_period     = 21;
input int    strategy_ema_slow_period    = 50;
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 20.0;
input bool   strategy_use_h1_filter      = true;
input bool   strategy_use_bb_filter      = true;
input bool   strategy_touch_ema21_too    = true;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 1.5;
input double strategy_tp_atr_mult        = 2.0;
input int    strategy_sl_cap_pips        = 20;
input int    strategy_tp_cap_pips        = 20;
input int    strategy_spread_cap_pips    = 15;
input bool   strategy_no_friday_entry    = true;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_ema_fast_period <= 0 || strategy_ema_mid_period <= 0 ||
      strategy_ema_slow_period <= 0 || strategy_bb_period <= 0 ||
      strategy_bb_deviation <= 0.0 || strategy_atr_period <= 0 ||
      strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0 ||
      strategy_sl_cap_pips <= 0 || strategy_tp_cap_pips <= 0)
      return false;

   if(strategy_no_friday_entry)
     {
      MqlDateTime broker_dt;
      TimeToStruct(TimeCurrent(), broker_dt);
      if(broker_dt.day_of_week == 5)
         return false;
     }

   MqlRates m5_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_M5, 1, m5_bar))
      return false;
   if(m5_bar.open <= 0.0 || m5_bar.high <= 0.0 || m5_bar.low <= 0.0 || m5_bar.close <= 0.0)
      return false;

   const double ema14_m5 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_fast_period, 1);
   const double ema21_m5 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_mid_period, 1);
   const double ema50_m5 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_slow_period, 1);
   if(ema14_m5 <= 0.0 || ema21_m5 <= 0.0 || ema50_m5 <= 0.0)
      return false;

   bool long_m5 = (ema14_m5 > ema21_m5 && ema21_m5 > ema50_m5);
   bool short_m5 = (ema14_m5 < ema21_m5 && ema21_m5 < ema50_m5);

   if(strategy_use_bb_filter)
     {
      const double bb_upper_m5 = QM_BB_Upper(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1);
      const double bb_lower_m5 = QM_BB_Lower(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1);
      if(bb_upper_m5 <= 0.0 || bb_lower_m5 <= 0.0)
         return false;
      const bool ema50_inside_m5 = (ema50_m5 >= bb_lower_m5 && ema50_m5 <= bb_upper_m5);
      long_m5 = long_m5 && ema50_inside_m5;
      short_m5 = short_m5 && ema50_inside_m5;
     }

   bool long_h1 = true;
   bool short_h1 = true;
   if(strategy_use_h1_filter)
     {
      const double ema14_h1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, 1);
      const double ema21_h1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_mid_period, 1);
      const double ema50_h1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow_period, 1);
      if(ema14_h1 <= 0.0 || ema21_h1 <= 0.0 || ema50_h1 <= 0.0)
         return false;

      long_h1 = (ema14_h1 > ema21_h1 && ema21_h1 > ema50_h1);
      short_h1 = (ema14_h1 < ema21_h1 && ema21_h1 < ema50_h1);

      if(strategy_use_bb_filter)
        {
         const double bb_upper_h1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
         const double bb_lower_h1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
         if(bb_upper_h1 <= 0.0 || bb_lower_h1 <= 0.0)
            return false;
         const bool ema50_inside_h1 = (ema50_h1 >= bb_lower_h1 && ema50_h1 <= bb_upper_h1);
         long_h1 = long_h1 && ema50_inside_h1;
         short_h1 = short_h1 && ema50_inside_h1;
        }
     }

   const bool long_touch = (m5_bar.low <= ema14_m5 ||
                            (strategy_touch_ema21_too && m5_bar.low <= ema21_m5));
   const bool short_touch = (m5_bar.high >= ema14_m5 ||
                             (strategy_touch_ema21_too && m5_bar.high >= ema21_m5));
   const bool long_signal = (long_m5 && long_h1 && long_touch && m5_bar.close > m5_bar.open);
   const bool short_signal = (short_m5 && short_h1 && short_touch && m5_bar.close < m5_bar.open);
   if(!long_signal && !short_signal)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const QM_OrderType order_type = long_signal ? QM_BUY : QM_SELL;
   const double entry_price = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   double sl_price = QM_StopATRFromValue(_Symbol, order_type, entry_price, atr_value, strategy_sl_atr_mult);
   double tp_price = QM_TakeATRFromValue(_Symbol, order_type, entry_price, atr_value, strategy_tp_atr_mult);
   if(sl_price <= 0.0 || tp_price <= 0.0)
      return false;

   const double sl_cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double tp_cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_cap_pips);
   if(sl_cap_distance > 0.0 && MathAbs(entry_price - sl_price) > sl_cap_distance)
      sl_price = QM_StopRulesNormalizePrice(_Symbol, long_signal ? entry_price - sl_cap_distance
                                                                 : entry_price + sl_cap_distance);
   if(tp_cap_distance > 0.0 && MathAbs(tp_price - entry_price) > tp_cap_distance)
      tp_price = QM_StopRulesNormalizePrice(_Symbol, long_signal ? entry_price + tp_cap_distance
                                                                 : entry_price - tp_cap_distance);

   req.type = order_type;
   req.price = 0.0;
   req.sl = sl_price;
   req.tp = tp_price;
   req.reason = long_signal ? "mtf_triple_ema_bb_long" : "mtf_triple_ema_bb_short";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // The card specifies fixed server-side ATR SL/TP only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // The card specifies no discretionary exit beyond SL, TP, and Friday close.
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
