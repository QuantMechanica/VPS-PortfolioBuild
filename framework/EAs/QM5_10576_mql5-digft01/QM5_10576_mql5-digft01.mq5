#property strict
#property version   "5.0"
#property description "QM5_10576 DigitalF-T01 oscillator cloud cross"

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
input int    qm_ea_id                   = 10576;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H3;
input int             strategy_signal_bar         = 1;
input int             strategy_halfchannel_points = 25;
input ENUM_APPLIED_PRICE strategy_applied_price   = PRICE_CLOSE;
input int             strategy_atr_period         = 14;
input double          strategy_atr_sl_mult        = 2.0;
input double          strategy_take_profit_rr     = 1.5;
input int             strategy_max_spread_points  = 0;

int g_digitalf_last_signal = 0;

double DigitalF_Price(const MqlRates &rates[], const int shift)
  {
   switch(strategy_applied_price)
     {
      case PRICE_OPEN:     return rates[shift].open;
      case PRICE_HIGH:     return rates[shift].high;
      case PRICE_LOW:      return rates[shift].low;
      case PRICE_MEDIAN:   return (rates[shift].high + rates[shift].low) / 2.0;
      case PRICE_TYPICAL:  return (rates[shift].high + rates[shift].low + rates[shift].close) / 3.0;
      case PRICE_WEIGHTED: return (rates[shift].high + rates[shift].low + 2.0 * rates[shift].close) / 4.0;
      default:             return rates[shift].close;
     }
  }

double DigitalF_Oscillator(const MqlRates &rates[], const int shift)
  {
   return 0.24470985659780 * DigitalF_Price(rates, shift) +
          0.23139774006970 * DigitalF_Price(rates, shift + 1) +
          0.20613796947320 * DigitalF_Price(rates, shift + 2) +
          0.17166230340640 * DigitalF_Price(rates, shift + 3) +
          0.13146907903600 * DigitalF_Price(rates, shift + 4) +
          0.08950387549560 * DigitalF_Price(rates, shift + 5) +
          0.04960091651250 * DigitalF_Price(rates, shift + 6) +
          0.01502270569607 * DigitalF_Price(rates, shift + 7) -
          0.01188033734430 * DigitalF_Price(rates, shift + 8) -
          0.02989873856137 * DigitalF_Price(rates, shift + 9) -
          0.03898967104900 * DigitalF_Price(rates, shift + 10) -
          0.04014113626390 * DigitalF_Price(rates, shift + 11) -
          0.03511968085800 * DigitalF_Price(rates, shift + 12) -
          0.02611613850342 * DigitalF_Price(rates, shift + 13) -
          0.01539056955666 * DigitalF_Price(rates, shift + 14) -
          0.00495353651394 * DigitalF_Price(rates, shift + 15) +
          0.00368588764825 * DigitalF_Price(rates, shift + 16) +
          0.00963614049782 * DigitalF_Price(rates, shift + 17) +
          0.01265138888314 * DigitalF_Price(rates, shift + 18) +
          0.01307496106868 * DigitalF_Price(rates, shift + 19) +
          0.01169702291063 * DigitalF_Price(rates, shift + 20) +
          0.00974841844086 * DigitalF_Price(rates, shift + 21) +
          0.00898900012545 * DigitalF_Price(rates, shift + 22) -
          0.00649745721156 * DigitalF_Price(rates, shift + 23);
  }

double DigitalF_Trigger(const MqlRates &rates[], const int shift, const double oscillator)
  {
   MqlDateTime tm;
   TimeToStruct(rates[shift].time, tm);
   const int period_seconds = PeriodSeconds(strategy_signal_tf);
   if(period_seconds <= 0)
      return 0.0;

   const int bars_from_day_start = (int)MathRound(60.0 * (tm.hour * 60 + tm.min) / period_seconds) + 1;
   const int anchor_shift = shift + bars_from_day_start;
   if(anchor_shift >= ArraySize(rates))
      return 0.0;

   const double channel = strategy_halfchannel_points * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(channel <= 0.0)
      return 0.0;

   return (oscillator >= rates[anchor_shift].close)
          ? rates[anchor_shift].close + channel
          : rates[anchor_shift].close - channel;
  }

int DigitalF_ClosedBarSignal()
  {
   const int signal_shift = MathMax(1, strategy_signal_bar);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 0, 80, rates); // perf-allowed: Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied < signal_shift + 32)
      return 0;

   const double osc_now = DigitalF_Oscillator(rates, signal_shift);
   const double trg_now = DigitalF_Trigger(rates, signal_shift, osc_now);
   const double osc_prev = DigitalF_Oscillator(rates, signal_shift + 1);
   const double trg_prev = DigitalF_Trigger(rates, signal_shift + 1, osc_prev);
   if(trg_now <= 0.0 || trg_prev <= 0.0)
      return 0;

   if(osc_now > trg_now && osc_prev <= trg_prev)
      return 1;
   if(osc_now < trg_now && osc_prev >= trg_prev)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_signal_tf != (ENUM_TIMEFRAMES)_Period)
      return true;
   if(strategy_signal_bar < 1 ||
      strategy_halfchannel_points <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0 ||
      strategy_max_spread_points < 0)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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

   g_digitalf_last_signal = DigitalF_ClosedBarSignal();
   if(g_digitalf_last_signal == 0)
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

   req.type = (g_digitalf_last_signal > 0) ? QM_BUY : QM_SELL;
   req.price = QM_EntryMarketPrice(req.type);
   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_rr);
   req.reason = (g_digitalf_last_signal > 0) ? "DIGITALF_T01_BULL_CROSS" : "DIGITALF_T01_BEAR_CROSS";
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   return (QM_LotsForRisk(_Symbol, MathAbs(req.price - req.sl) / point) > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // P2 baseline has no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_digitalf_last_signal == 0)
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_digitalf_last_signal < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_digitalf_last_signal > 0)
         return true;
     }

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
