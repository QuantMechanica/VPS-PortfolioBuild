#property strict
#property version   "5.0"
#property description "QM5_10411 Elite Trader TD Setup Exhaustion"

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
input int    qm_ea_id                   = 10411;
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
input int    strategy_setup_count       = 9;
input int    strategy_atr_period        = 20;
input double strategy_stop_buffer_atr   = 0.25;
input double strategy_target_rr         = 1.5;
input int    strategy_time_stop_bars    = 20;
input bool   strategy_session_filter_enabled = false;
input int    strategy_session_start_hour = 0;
input int    strategy_session_end_hour   = 24;

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

int Strategy_HourOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

bool Strategy_InSession(const datetime broker_time)
  {
   if(!strategy_session_filter_enabled)
      return true;

   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(24, strategy_session_end_hour));
   const int hour = Strategy_HourOf(broker_time);

   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (hour >= start_h && hour < end_h);
   return (hour >= start_h || hour < end_h);
  }

bool Strategy_HasOurPosition()
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

int Strategy_TDCountLong()
  {
   int count = 0;
   const int max_scan = MathMax(strategy_setup_count + 8, 40);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const double close_now = iClose(_Symbol, _Period, shift);
      const double close_4 = iClose(_Symbol, _Period, shift + 4);
      if(close_now <= 0.0 || close_4 <= 0.0)
         break;
      if(close_now >= close_4)
         break;
      count++;
     }
   return count;
  }

int Strategy_TDCountShort()
  {
   int count = 0;
   const int max_scan = MathMax(strategy_setup_count + 8, 40);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const double close_now = iClose(_Symbol, _Period, shift);
      const double close_4 = iClose(_Symbol, _Period, shift + 4);
      if(close_now <= 0.0 || close_4 <= 0.0)
         break;
      if(close_now <= close_4)
         break;
      count++;
     }
   return count;
  }

bool Strategy_LongSwingConfirmed()
  {
   const double low_1 = iLow(_Symbol, _Period, 1);
   const double low_2 = iLow(_Symbol, _Period, 2);
   const double low_3 = iLow(_Symbol, _Period, 3);
   const double low_4 = iLow(_Symbol, _Period, 4);
   const double low_5 = iLow(_Symbol, _Period, 5);
   if(low_1 <= 0.0 || low_2 <= 0.0 || low_3 <= 0.0 || low_4 <= 0.0 || low_5 <= 0.0)
      return false;

   return ((low_1 < low_3 && low_1 < low_4) ||
           (low_2 < low_4 && low_2 < low_5));
  }

bool Strategy_ShortSwingConfirmed()
  {
   const double high_1 = iHigh(_Symbol, _Period, 1);
   const double high_2 = iHigh(_Symbol, _Period, 2);
   const double high_3 = iHigh(_Symbol, _Period, 3);
   const double high_4 = iHigh(_Symbol, _Period, 4);
   const double high_5 = iHigh(_Symbol, _Period, 5);
   if(high_1 <= 0.0 || high_2 <= 0.0 || high_3 <= 0.0 || high_4 <= 0.0 || high_5 <= 0.0)
      return false;

   return ((high_1 > high_3 && high_1 > high_4) ||
           (high_2 > high_4 && high_2 > high_5));
  }

bool Strategy_BuildRequest(const QM_OrderType type, QM_EntryRequest &req)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double low_1 = iLow(_Symbol, _Period, 1);
   const double low_2 = iLow(_Symbol, _Period, 2);
   const double high_1 = iHigh(_Symbol, _Period, 1);
   const double high_2 = iHigh(_Symbol, _Period, 2);
   if(low_1 <= 0.0 || low_2 <= 0.0 || high_1 <= 0.0 || high_2 <= 0.0)
      return false;

   req.type = type;
   req.price = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(type == QM_BUY)
     {
      const double entry = ask;
      const double setup_low = MathMin(low_1, low_2);
      req.sl = Strategy_NormalizePrice(setup_low - strategy_stop_buffer_atr * atr);
      if(req.sl <= 0.0 || req.sl >= entry)
         return false;
      req.tp = Strategy_NormalizePrice(entry + (entry - req.sl) * strategy_target_rr);
      req.reason = "TD_SETUP_LONG";
      return true;
     }

   const double entry = bid;
   const double setup_high = MathMax(high_1, high_2);
   req.sl = Strategy_NormalizePrice(setup_high + strategy_stop_buffer_atr * atr);
   if(req.sl <= 0.0 || req.sl <= entry)
      return false;
   req.tp = Strategy_NormalizePrice(entry - (req.sl - entry) * strategy_target_rr);
   req.reason = "TD_SETUP_SHORT";
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_InSession(TimeCurrent()))
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

   if(strategy_setup_count < 1 ||
      strategy_atr_period < 1 ||
      strategy_stop_buffer_atr < 0.0 ||
      strategy_target_rr <= 0.0 ||
      strategy_time_stop_bars < 1)
      return false;

   if(Strategy_HasOurPosition())
      return false;

   if(Strategy_TDCountLong() >= strategy_setup_count && Strategy_LongSwingConfirmed())
     {
      if(!Strategy_BuildRequest(QM_BUY, req))
         return false;
      return true;
     }

   if(Strategy_TDCountShort() >= strategy_setup_count && Strategy_ShortSwingConfirmed())
     {
      if(!Strategy_BuildRequest(QM_SELL, req))
         return false;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial, or add-on management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime position_time = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   if(position_time > 0)
     {
      const int bars_since_entry = iBarShift(_Symbol, _Period, position_time, false);
      if(bars_since_entry >= strategy_time_stop_bars)
         return true;
     }

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double close_2 = iClose(_Symbol, _Period, 2);
   const double close_5 = iClose(_Symbol, _Period, 5);
   const double close_6 = iClose(_Symbol, _Period, 6);
   if(close_1 <= 0.0 || close_2 <= 0.0 || close_5 <= 0.0 || close_6 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
      return (close_1 > close_5 && close_2 > close_6);
   if(position_type == POSITION_TYPE_SELL)
      return (close_1 < close_5 && close_2 < close_6);

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
