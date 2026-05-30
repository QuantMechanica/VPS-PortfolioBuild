#property strict
#property version   "5.0"
#property description "QM5_10005 ForexFactory Profigenics MTF Channel Pullback"

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
input int    qm_ea_id                   = 10005;
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
input ENUM_TIMEFRAMES strategy_htf      = PERIOD_H1;
input int    strategy_channel_period    = 3;
input int    strategy_bias_period       = 34;
input int    strategy_director_fast     = 5;
input int    strategy_director_slow     = 21;
input int    strategy_atr_period        = 14;
input double strategy_min_sl_pips       = 8.0;
input double strategy_max_atr_mult      = 3.0;
input double strategy_rr                = 1.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: card defines no additional time or spread rule.
   // News is delegated to the framework and Strategy_NewsFilterHook.
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

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const ENUM_TIMEFRAMES ltf = (ENUM_TIMEFRAMES)_Period;
   const double htf_channel_high = QM_SMA(_Symbol, strategy_htf, strategy_channel_period, 1, PRICE_HIGH);
   const double htf_channel_low  = QM_SMA(_Symbol, strategy_htf, strategy_channel_period, 1, PRICE_LOW);
   const double htf_bias         = QM_EMA(_Symbol, strategy_htf, strategy_bias_period, 1, PRICE_OPEN);
   const double ltf_channel_high = QM_SMA(_Symbol, ltf, strategy_channel_period, 1, PRICE_HIGH);
   const double ltf_channel_low  = QM_SMA(_Symbol, ltf, strategy_channel_period, 1, PRICE_LOW);
   const double ltf_bias         = QM_EMA(_Symbol, ltf, strategy_bias_period, 1, PRICE_OPEN);
   const double ltf_fast         = QM_SMA(_Symbol, ltf, strategy_director_fast, 1, PRICE_CLOSE);
   const double ltf_slow         = QM_EMA(_Symbol, ltf, strategy_director_slow, 1, PRICE_CLOSE);
   const double htf_close        = iClose(_Symbol, strategy_htf, 1);
   const double ltf_close        = iClose(_Symbol, ltf, 1);
   const double ltf_high_bar     = iHigh(_Symbol, ltf, 1);
   const double ltf_low_bar      = iLow(_Symbol, ltf, 1);
   const double atr              = QM_ATR(_Symbol, ltf, strategy_atr_period, 1);
   const double point            = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits              = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip              = (digits == 3 || digits == 5) ? point * 10.0 : point;

   if(htf_channel_high <= 0.0 || htf_channel_low <= 0.0 || htf_bias <= 0.0 ||
      ltf_channel_high <= 0.0 || ltf_channel_low <= 0.0 || ltf_bias <= 0.0 ||
      ltf_fast <= 0.0 || ltf_slow <= 0.0 || htf_close <= 0.0 || ltf_close <= 0.0 ||
      ltf_high_bar <= 0.0 || ltf_low_bar <= 0.0 || atr <= 0.0 || pip <= 0.0 ||
      ltf_channel_high <= ltf_channel_low)
      return false;

   const double width = ltf_channel_high - ltf_channel_low;
   const double min_stop = strategy_min_sl_pips * pip;
   const double max_stop = strategy_max_atr_mult * atr;
   if(width <= 0.0 || min_stop <= 0.0 || max_stop <= 0.0)
      return false;

   const bool htf_long = (htf_channel_low > htf_bias && htf_close > htf_channel_low);
   const bool ltf_long = (ltf_channel_low > ltf_bias &&
                          ltf_close > ltf_channel_low &&
                          ltf_fast > ltf_slow &&
                          ltf_low_bar <= ltf_channel_low);
   if(htf_long && ltf_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = ltf_channel_low - width;
      const double stop_distance = MathAbs(entry - sl);
      if(entry <= 0.0 || stop_distance < min_stop || stop_distance > max_stop)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = entry + stop_distance * strategy_rr;
      req.reason = "PROFIGENICS_LONG_CHANNEL_TOUCH";
      return true;
     }

   const bool htf_short = (htf_channel_high < htf_bias && htf_close < htf_channel_high);
   const bool ltf_short = (ltf_channel_high < ltf_bias &&
                           ltf_close < ltf_channel_high &&
                           ltf_fast < ltf_slow &&
                           ltf_high_bar >= ltf_channel_high);
   if(htf_short && ltf_short)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = ltf_channel_high + width;
      const double stop_distance = MathAbs(sl - entry);
      if(entry <= 0.0 || stop_distance < min_stop || stop_distance > max_stop)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = entry - stop_distance * strategy_rr;
      req.reason = "PROFIGENICS_SHORT_CHANNEL_TOUCH";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const ENUM_TIMEFRAMES ltf = (ENUM_TIMEFRAMES)_Period;
   const double channel_high = QM_SMA(_Symbol, ltf, strategy_channel_period, 1, PRICE_HIGH);
   const double channel_low  = QM_SMA(_Symbol, ltf, strategy_channel_period, 1, PRICE_LOW);
   const double close_last   = iClose(_Symbol, ltf, 1);
   if(channel_high <= 0.0 || channel_low <= 0.0 || close_last <= 0.0)
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
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(ptype == POSITION_TYPE_BUY && bid > open_price && close_last > channel_high)
        {
         if(current_sl <= 0.0 || channel_low > current_sl)
            QM_TM_MoveSL(ticket, channel_low, "profigenics_channel_trail_long");
        }
      if(ptype == POSITION_TYPE_SELL && ask < open_price && close_last < channel_low)
        {
         if(current_sl <= 0.0 || channel_high < current_sl)
            QM_TM_MoveSL(ticket, channel_high, "profigenics_channel_trail_short");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const ENUM_TIMEFRAMES ltf = (ENUM_TIMEFRAMES)_Period;
   const double director_fast = QM_SMA(_Symbol, ltf, strategy_director_fast, 1, PRICE_CLOSE);
   const double director_slow = QM_EMA(_Symbol, ltf, strategy_director_slow, 1, PRICE_CLOSE);
   if(director_fast <= 0.0 || director_slow <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && director_fast < director_slow)
         return true;
      if(ptype == POSITION_TYPE_SELL && director_fast > director_slow)
         return true;
     }

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
