#property strict
#property version   "5.0"
#property description "QM5_10678 TradingView Tokyo Liquidity Sweep Breakout"

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
input int    qm_ea_id                   = 10678;
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
input int    strategy_reference_start_pkt_hhmm   = 500;
input int    strategy_magic_pkt_hhmm             = 554;
input int    strategy_first_checkpoint_pkt_hhmm  = 630;
input int    strategy_final_checkpoint_pkt_hhmm  = 830;
input int    strategy_checkpoint_interval_min    = 15;
input int    strategy_session_flat_pkt_hhmm      = 900;
input int    strategy_atr_period                 = 14;
input double strategy_max_stop_atr_mult          = 1.75;
input double strategy_rr                         = 1.5;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   static int    state_day_key = 0;
   static bool   reference_range_ready = false;
   static bool   reference_range_has_data = false;
   static bool   trade_taken_today = false;
   static double reference_high = 0.0;
   static double reference_low = 0.0;

   if(_Period != PERIOD_M3 && _Period != PERIOD_M5)
      return false;
   if(strategy_atr_period <= 0 || strategy_max_stop_atr_mult <= 0.0 || strategy_rr <= 0.0)
      return false;
   if(strategy_checkpoint_interval_min <= 0)
      return false;

   const int reference_start_minute = (strategy_reference_start_pkt_hhmm / 100) * 60 + (strategy_reference_start_pkt_hhmm % 100);
   const int magic_minute = (strategy_magic_pkt_hhmm / 100) * 60 + (strategy_magic_pkt_hhmm % 100);
   const int first_minute = (strategy_first_checkpoint_pkt_hhmm / 100) * 60 + (strategy_first_checkpoint_pkt_hhmm % 100);
   const int final_minute = (strategy_final_checkpoint_pkt_hhmm / 100) * 60 + (strategy_final_checkpoint_pkt_hhmm % 100);
   if(reference_start_minute < 0 || reference_start_minute > 1439 ||
      magic_minute < 0 || magic_minute > 1439 ||
      first_minute < 0 || first_minute > 1439 ||
      final_minute < 0 || final_minute > 1439)
      return false;
   if(reference_start_minute > magic_minute || first_minute > final_minute)
      return false;

   const int period_seconds = PeriodSeconds(_Period);
   if(period_seconds <= 0)
      return false;

   // perf-allowed: the card's Tokyo candle/range test is bespoke structural OHLC logic;
   // this hook is called only after the framework's QM_IsNewBar() gate.
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1);
   if(bar_open_broker <= 0)
      return false;

   const datetime bar_close_broker = bar_open_broker + period_seconds;
   const datetime bar_open_pkt = QM_BrokerToUTC(bar_open_broker) + (5 * 3600);
   const datetime bar_close_pkt = QM_BrokerToUTC(bar_close_broker) + (5 * 3600);
   MqlDateTime pkt_open;
   MqlDateTime pkt;
   ZeroMemory(pkt_open);
   ZeroMemory(pkt);
   TimeToStruct(bar_open_pkt, pkt_open);
   TimeToStruct(bar_close_pkt, pkt);

   const int day_key = pkt.year * 10000 + pkt.mon * 100 + pkt.day;
   if(day_key != state_day_key)
     {
      state_day_key = day_key;
      reference_range_ready = false;
      reference_range_has_data = false;
      trade_taken_today = false;
      reference_high = 0.0;
      reference_low = 0.0;
     }

   const int open_minute = pkt_open.hour * 60 + pkt_open.min;
   const int close_minute = pkt.hour * 60 + pkt.min;

   if(close_minute > reference_start_minute && open_minute <= magic_minute)
     {
      const double h1 = iHigh(_Symbol, _Period, 1);
      const double l1 = iLow(_Symbol, _Period, 1);
      if(h1 > 0.0 && l1 > 0.0 && h1 > l1)
        {
         if(!reference_range_has_data)
           {
            reference_high = h1;
            reference_low = l1;
            reference_range_has_data = true;
           }
         else
           {
            reference_high = MathMax(reference_high, h1);
            reference_low = MathMin(reference_low, l1);
           }
        }
     }

   if(open_minute <= magic_minute && close_minute > magic_minute)
     {
      reference_range_ready = reference_range_has_data;
      return false;
     }

   if(trade_taken_today || !reference_range_ready)
      return false;
   if(close_minute < first_minute || close_minute > final_minute)
      return false;
   if(((close_minute - first_minute) % strategy_checkpoint_interval_min) != 0)
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   const bool long_clean = (close1 > reference_high && low1 > reference_high);
   const bool short_clean = (close1 < reference_low && high1 < reference_low);
   if(!long_clean && !short_clean)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double entry = long_clean ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = long_clean ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, long_clean ? reference_low : reference_high);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr);
   req.reason = long_clean ? "TV_TOKYO_LSB_LONG" : "TV_TOKYO_LSB_SHORT";

   const double stop_distance = MathAbs(entry - req.sl);
   if(stop_distance <= 0.0 || req.tp <= 0.0)
      return false;
   if(stop_distance > (strategy_max_stop_atr_mult * atr))
      return false;

   trade_taken_today = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, BE, partials, or adds.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   const datetime now_pkt = QM_BrokerToUTC(TimeCurrent()) + (5 * 3600);
   MqlDateTime pkt;
   ZeroMemory(pkt);
   TimeToStruct(now_pkt, pkt);
   const int now_minute = pkt.hour * 60 + pkt.min;
   const int flat_minute = (strategy_session_flat_pkt_hhmm / 100) * 60 + (strategy_session_flat_pkt_hhmm % 100);

   return (now_minute >= flat_minute);
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
