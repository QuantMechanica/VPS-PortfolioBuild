#property strict
#property version   "5.0"
#property description "QM5_11555 Carter-T M5 WMA5/SMA11 PSAR ADX14"

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
input int    qm_ea_id                   = 11555;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M5;
input int             strategy_wma_period         = 5;
input int             strategy_sma_period         = 11;
input double          strategy_psar_step          = 0.01;
input double          strategy_psar_max           = 0.10;
input int             strategy_adx_period         = 14;
input int             strategy_sl_lookback_bars   = 5;
input int             strategy_sl_cap_pips        = 25;
input int             strategy_spread_cap_pips    = 5;
input bool            strategy_no_friday_entry    = true;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_spread_cap_pips > 0)
     {
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > (long)(strategy_spread_cap_pips * pip_factor))
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

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   if(strategy_wma_period <= 0 || strategy_sma_period <= 0 ||
      strategy_adx_period <= 0 || strategy_sl_lookback_bars <= 0 ||
      strategy_psar_step <= 0.0 || strategy_psar_max <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = strategy_signal_tf;
   const double wma = QM_WMA(_Symbol, tf, strategy_wma_period, 1, PRICE_CLOSE);
   const double sma = QM_SMA(_Symbol, tf, strategy_sma_period, 1, PRICE_CLOSE);
   const double plus_di = QM_ADX_PlusDI(_Symbol, tf, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, tf, strategy_adx_period, 1);
   const double low_1 = QM_SMA(_Symbol, tf, 1, 1, PRICE_LOW);
   const double high_1 = QM_SMA(_Symbol, tf, 1, 1, PRICE_HIGH);
   if(wma <= 0.0 || sma <= 0.0 || plus_di <= 0.0 || minus_di <= 0.0 ||
      low_1 <= 0.0 || high_1 <= 0.0)
      return false;

   const string psar_key = StringFormat("SAR|%s|%d|%.8f|%.8f",
                                        _Symbol,
                                        (int)tf,
                                        strategy_psar_step,
                                        strategy_psar_max);
   int psar_handle = QM_IndicatorsLookup(psar_key);
   if(psar_handle == INVALID_HANDLE)
      psar_handle = QM_IndicatorsRegister(psar_key, iSAR(_Symbol, tf, strategy_psar_step, strategy_psar_max));
   const double psar_1 = QM_IndicatorReadBuffer(psar_handle, 0, 1);
   if(psar_1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(wma > sma && psar_1 < low_1 && plus_di > minus_di)
     {
      const double structure_sl = QM_StopStructure(_Symbol, QM_BUY, ask, strategy_sl_lookback_bars);
      const double capped_sl = QM_StopFixedPips(_Symbol, QM_BUY, ask, strategy_sl_cap_pips);
      if(structure_sl <= 0.0 || capped_sl <= 0.0)
         return false;

      req.type = QM_BUY;
      req.sl = (ask - structure_sl > ask - capped_sl) ? capped_sl : structure_sl;
      req.reason = "CARTER_T_WMA5_SMA11_PSAR_ADX_LONG";
      return (req.sl > 0.0 && req.sl < bid);
     }

   if(wma < sma && psar_1 > high_1 && minus_di > plus_di)
     {
      const double structure_sl = QM_StopStructure(_Symbol, QM_SELL, bid, strategy_sl_lookback_bars);
      const double capped_sl = QM_StopFixedPips(_Symbol, QM_SELL, bid, strategy_sl_cap_pips);
      if(structure_sl <= 0.0 || capped_sl <= 0.0)
         return false;

      req.type = QM_SELL;
      req.sl = (structure_sl - bid > capped_sl - bid) ? capped_sl : structure_sl;
      req.reason = "CARTER_T_WMA5_SMA11_PSAR_ADX_SHORT";
      return (req.sl > ask);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = strategy_signal_tf;
   const string psar_key = StringFormat("SAR|%s|%d|%.8f|%.8f",
                                        _Symbol,
                                        (int)tf,
                                        strategy_psar_step,
                                        strategy_psar_max);
   int psar_handle = QM_IndicatorsLookup(psar_key);
   if(psar_handle == INVALID_HANDLE)
      psar_handle = QM_IndicatorsRegister(psar_key, iSAR(_Symbol, tf, strategy_psar_step, strategy_psar_max));

   const double psar_1 = QM_IndicatorReadBuffer(psar_handle, 0, 1);
   const double psar_2 = QM_IndicatorReadBuffer(psar_handle, 0, 2);
   const double low_1 = QM_SMA(_Symbol, tf, 1, 1, PRICE_LOW);
   const double low_2 = QM_SMA(_Symbol, tf, 1, 2, PRICE_LOW);
   const double high_1 = QM_SMA(_Symbol, tf, 1, 1, PRICE_HIGH);
   const double high_2 = QM_SMA(_Symbol, tf, 1, 2, PRICE_HIGH);
   if(psar_1 <= 0.0 || psar_2 <= 0.0 || low_1 <= 0.0 || low_2 <= 0.0 ||
      high_1 <= 0.0 || high_2 <= 0.0)
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && psar_2 < low_2 && psar_1 > high_1)
         return true;
      if(position_type == POSITION_TYPE_SELL && psar_2 > high_2 && psar_1 < low_1)
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
