#property strict
#property version   "5.0"
#property description "QM5_11104 Total Power Indicator power cross"

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
input int    qm_ea_id                   = 11104;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H4;
input int             strategy_lookback_period = 45;
input int             strategy_power_period    = 10;
input int             strategy_atr_period      = 14;
input double          strategy_atr_sl_mult     = 2.0;
input int             strategy_time_stop_bars  = 20;

bool LoadPowerRates(MqlRates &rates[])
  {
   if(strategy_lookback_period <= 0 || strategy_power_period <= 0)
      return false;

   const int bars_needed = strategy_lookback_period + 1;
   ArrayResize(rates, bars_needed);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, bars_needed, rates); // perf-allowed: closed-bar Total Power high/low window; Strategy_EntrySignal is framework-new-bar gated.
   return (copied == bars_needed);
  }

double PowerPercent(const MqlRates &rates[], const bool bulls, const int signal_shift)
  {
   if(signal_shift < 1 || strategy_lookback_period <= 0)
      return -1.0;

   const int bars_available = ArraySize(rates);
   int hits = 0;
   for(int i = 0; i < strategy_lookback_period; ++i)
     {
      const int bar_shift = signal_shift + i;
      const int idx = bar_shift - 1;
      if(idx < 0 || idx >= bars_available)
         return -1.0;

      const double ema = QM_EMA(_Symbol, strategy_signal_tf, strategy_power_period, bar_shift);
      if(ema <= 0.0 || rates[idx].high <= 0.0 || rates[idx].low <= 0.0)
         return -1.0;

      if(bulls)
        {
         if((rates[idx].high - ema) > 0.0)
            hits++;
        }
      else
        {
         if((rates[idx].low - ema) < 0.0)
            hits++;
        }
     }

   return 100.0 * (double)hits / (double)strategy_lookback_period;
  }

int TotalPowerCrossSignal()
  {
   MqlRates rates[];
   if(!LoadPowerRates(rates))
      return 0;

   const double bulls1 = PowerPercent(rates, true, 1);
   const double bears1 = PowerPercent(rates, false, 1);
   const double bulls2 = PowerPercent(rates, true, 2);
   const double bears2 = PowerPercent(rates, false, 2);
   if(bulls1 < 0.0 || bears1 < 0.0 || bulls2 < 0.0 || bears2 < 0.0)
      return 0;

   if(bulls1 > bears1 && bulls2 <= bears2)
      return 1;
   if(bulls1 < bears1 && bulls2 >= bears2)
      return -1;
   return 0;
  }

int OurPositionDir(ulong &out_ticket, datetime &out_open_time)
  {
   out_ticket = 0;
   out_open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      out_ticket = ticket;
      out_open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }

   return 0;
  }

bool BuildEntry(const QM_OrderType side, const string reason, QM_EntryRequest &req)
  {
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type               = side;
   req.price              = 0.0;
   req.sl                 = sl;
   req.tp                 = 0.0;
   req.reason             = reason;
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): no card-specific session or spread
// gate; the framework handles news, spread, kill-switch, and Friday close.
bool Strategy_NoTradeFilter()
  {
   return (_Period != (int)strategy_signal_tf);
  }

// Trade Entry: completed-bar Bulls/Bears Power percentage cross from the card.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int signal = TotalPowerCrossSignal();
   if(signal == 0)
      return false;

   ulong ticket = 0;
   datetime open_time = 0;
   const int dir = OurPositionDir(ticket, open_time);

   if(signal > 0)
     {
      if(dir > 0)
         return false;
      if(dir < 0)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      return BuildEntry(QM_BUY, "total_power_bull_cross", req);
     }

   if(dir < 0)
      return false;
   if(dir > 0)
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
   return BuildEntry(QM_SELL, "total_power_bear_cross", req);
  }

// Trade Management: the card specifies only the initial 2.0 ATR hard stop.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: opposite crosses are handled as stop-and-reverse in Trade Entry;
// this hook enforces the 20 H4-bar safety time stop.
bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0)
      return false;

   ulong ticket = 0;
   datetime open_time = 0;
   if(OurPositionDir(ticket, open_time) == 0 || open_time <= 0)
      return false;

   const int tf_seconds = PeriodSeconds(strategy_signal_tf);
   if(tf_seconds <= 0)
      return false;

   return ((TimeCurrent() - open_time) >= (strategy_time_stop_bars * tf_seconds));
  }

// News Filter Hook: news blackout is deferred to P8 / central framework mode.
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
