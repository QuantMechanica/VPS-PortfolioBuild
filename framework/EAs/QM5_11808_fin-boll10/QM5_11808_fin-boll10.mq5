#property strict
#property version   "5.0"
#property description "QM5_11808 fin-boll10 — Bollinger(10,2) band reversion, opposite-band exit (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11808 fin-boll10
// -----------------------------------------------------------------------------
// Source: shashankvemuri/Finance, stock_analysis/backest_all_indicators.py,
//         strategy_BollingerBands(df, n=10, n_rng=2).
// Card: artifacts/cards_approved/QM5_11808_fin-boll10.md (g0_status APPROVED).
//
// Mechanics (long+short mean reversion, closed-bar reads at shift 1, D1):
//   Bollinger STATE : QM_BB_Lower / QM_BB_Upper / QM_BB_Middle on close,
//                     period = bb_period (10), deviation = bb_dev (2.0).
//   Long  EVENT  : close crosses DOWN through the lower band on the trigger bar
//                  (close[1] < lower[1] AND close[2] >= lower[2]) — a fresh
//                  oversold band breach. Source: lower-band indicator == 1.
//   Short EVENT  : close crosses UP through the upper band on the trigger bar
//                  (close[1] > upper[1] AND close[2] <= upper[2]) — a fresh
//                  overbought band breach. Source: upper-band indicator == 1.
//   Exit long    : close >= upper band (opposite-band touch STATE).
//   Exit short   : close <= lower band (opposite-band touch STATE).
//   Stop         : entry -/+ sl_atr_mult * ATR(atr_period)  (P3 ATR variant).
//   One position per symbol/magic; opposite signal closes first, reversal only
//   on the next eligible EVENT (the per-magic single-position guard enforces it).
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread). Warmup floor: bb_warmup_bars closed bars.
//
// Two-cross trap avoided: ONE band-breach crossing is the trigger EVENT; the
// opposite-band touch is a STATE used only for exit, never required on the
// same bar as entry.
//
// Symbol port: card targets GER40.DWX, which is NOT in dwx_symbol_matrix.csv.
// Ported to GDAXI.DWX (DAX 40, present in the matrix). Flagged in build result.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11808;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period          = 10;    // Bollinger period (card n = 10)
input double strategy_bb_dev             = 2.0;   // Bollinger std-dev mult (card n_rng = 2)
input int    strategy_bb_warmup_bars     = 40;    // min closed bars before trading
input int    strategy_atr_period         = 14;    // ATR period for the hard stop
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR (P3 variant)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — band/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long+short band-reversion entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Warmup: require enough closed history for a stable band.
   if(Bars(_Symbol, _Period) < strategy_bb_warmup_bars + 3)
      return false;

   // --- Bollinger STATE at the two most recent closed bars (shifts 1 and 2) ---
   const double upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 1);
   const double lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 1);
   const double upper2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 2);
   const double lower2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 2);
   if(upper1 <= 0.0 || lower1 <= 0.0 || upper2 <= 0.0 || lower2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // ATR value for the hard stop.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Long EVENT: fresh DOWN-cross through the lower band (oversold breach) ---
   const bool long_event  = (close2 >= lower2 && close1 < lower1);
   // --- Short EVENT: fresh UP-cross through the upper band (overbought breach) ---
   const bool short_event = (close2 <= upper2 && close1 > upper1);

   // Two events cannot coincide (lower-breach vs upper-breach are mutually
   // exclusive on one bar); if neither fires, no entry.
   if(long_event == short_event)
      return false;

   if(long_event)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // exit on opposite-band touch (Strategy_ExitSignal)
      req.reason = "boll10_lower_breach_long";
      return true;
     }

   // short_event
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr_value, strategy_sl_atr_mult);
   if(sl_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = 0.0;
   req.reason = "boll10_upper_breach_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exit is the
// opposite-band touch handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Opposite-band exit STATE: close long when close touches/exceeds the upper
// band; close short when close touches/falls below the lower band.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 1);
   const double lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 1);
   if(upper1 <= 0.0 || lower1 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Determine current position direction for this magic.
   bool has_long  = false;
   bool has_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         has_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         has_short = true;
     }

   // Long exits on opposite (upper) band; short exits on opposite (lower) band.
   if(has_long && close1 >= upper1)
      return true;
   if(has_short && close1 <= lower1)
      return true;

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
