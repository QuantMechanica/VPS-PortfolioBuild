#property strict
#property version   "5.0"
#property description "QM5_11276 iaf-donchian — IAF Donchian 48H Volatility Breakout (long-only, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11276 iaf-donchian
// -----------------------------------------------------------------------------
// Source: coding-kitties/investing-algorithm-framework,
//   examples/strategies_showcase/07_event_driven_signal/strategy.py
//   source_id 72f9fcfa-6c75-5544-80c4-31e15c9817ab.
// Card: artifacts/cards_approved/QM5_11276_iaf-donchian.md (g0_status APPROVED).
//
// Mechanics (LONG-ONLY, all reads on CLOSED bars, shift >= 1):
//   Donchian channel : highest HIGH / lowest LOW over `donchian_period` (=48)
//                      PRIOR CLOSED bars. NEVER references the forming bar.
//   Entry            : flat AND prior closed bar's CLOSE (shift 1) > prior
//                      48-bar Donchian HIGH built from the bars BEFORE it
//                      (shifts 2..period+1). Market buy on the new bar.
//   Exit (manual)    : prior closed bar's CLOSE (shift 1) < prior 48-bar
//                      Donchian LOW built from shifts 2..period+1.
//   Stop             : source has no explicit stop — V5 baseline adds a default
//                      catastrophic 2.0 * ATR(14) stop below entry.
//   Sizing           : framework RISK_FIXED ($1,000 backtest), one position per
//                      magic (no all-in source sizing).
//
// .DWX invariants honoured:
//   - Spread guard fail-OPEN on .DWX zero modeled spread (block only a
//     genuinely wide spread > spread_pct_of_stop of the catastrophic stop).
//   - No swap gate. No external-macro CSV / non-MT5 feed.
//   - Breakout is prior-CLOSE based (gapless CFDs), not range/gap based.
//   - QM_IsNewBar consumed ONCE in framework OnTick; hooks read fixed shifts.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11276;
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
input int    strategy_donchian_period    = 48;    // Donchian channel length (prior CLOSED bars)
input int    strategy_atr_period         = 14;    // ATR period for the catastrophic stop
input double strategy_atr_sl_mult        = 2.0;   // catastrophic stop = mult * ATR(period)
input double strategy_spread_pct_of_stop = 12.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar Donchian over PRIOR CLOSED bars only, shifts >= 1)
// -----------------------------------------------------------------------------

// Highest HIGH over `count` closed bars starting at `start_shift` (>=1).
// perf-allowed: bounded single-pass over closed bars, run on the new-bar gate.
double DonchianHigh(const int start_shift, const int count)
  {
   double hi = 0.0;
   for(int s = start_shift; s < start_shift + count; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: closed-bar read
      if(h <= 0.0)
         continue;
      if(h > hi)
         hi = h;
     }
   return hi;
  }

// Lowest LOW over `count` closed bars starting at `start_shift` (>=1).
double DonchianLow(const int start_shift, const int count)
  {
   double lo = 0.0;
   for(int s = start_shift; s < start_shift + count; ++s)
     {
      const double l = iLow(_Symbol, _Period, s); // perf-allowed: closed-bar read
      if(l <= 0.0)
         continue;
      if(lo <= 0.0 || l < lo)
         lo = l;
     }
   return lo;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_atr_sl_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Donchian breakout entry (LONG only). Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; only enter when flat.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Donchian breakout on the prior CLOSED bar (shift 1) ---
   // Channel built from the bars BEFORE the trigger bar: shifts 2..period+1.
   // Never references the forming bar (shift 0).
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(close1 <= 0.0)
      return false;

   const double don_high = DonchianHigh(2, strategy_donchian_period);
   if(don_high <= 0.0)
      return false;

   // Open long when flat and the prior closed bar's close is above the prior
   // 48-bar Donchian high.
   if(!(close1 > don_high))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   // --- Default catastrophic stop: 2.0 * ATR(14) below entry ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_sl_mult);
   if(sl <= 0.0 || !(sl < entry))
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target; exit is the opposite Donchian breakout
   req.reason = "donchian48_break_long";
   return true;
  }

// No active SL/TP modification — the exit is the opposite Donchian breakout.
void Strategy_ManageOpenPosition()
  {
  }

// Manual exit: prior closed bar's close below the prior 48-bar Donchian low.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(close1 <= 0.0)
      return false;

   const double don_low = DonchianLow(2, strategy_donchian_period);
   if(don_low <= 0.0)
      return false;

   // Close long when the prior closed bar closed below the prior 48-bar low.
   return (close1 < don_low);
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
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
