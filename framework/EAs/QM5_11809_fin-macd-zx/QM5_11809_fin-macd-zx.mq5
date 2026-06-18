#property strict
#property version   "5.0"
#property description "QM5_11809 fin-macd-zx — MACD histogram zero-cross (symmetric long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11809 fin-macd-zx
// -----------------------------------------------------------------------------
// Source: shashankvemuri/Finance, stock_analysis/backest_all_indicators.py,
//         strategy_MACD (n_slow=26, n_fast=12, n_sign=9).
// Card: artifacts/cards_approved/QM5_11809_fin-macd-zx.md (g0_status APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads at shift 1, D1):
//   MACD histogram (a.k.a. MACD_DIFF) = QM_MACD_Main - QM_MACD_Signal.
//   Trigger EVENT (entry):
//     Long  when hist crosses UP   through 0 : hist[2] <= 0 and hist[1] > 0.
//     Short when hist crosses DOWN through 0 : hist[2] >= 0 and hist[1] < 0.
//   Exit EVENT (opposite zero-cross):
//     Close long  on a fresh DOWN-cross ; close short on a fresh UP-cross.
//   Reversal is from a FLAT state only — the opposite cross closes the current
//     position (Strategy_ExitSignal); a NEW position then opens on the next
//     eligible cross while flat. Entry and exit are distinct events, each
//     evaluated once per closed bar, so the two-cross-same-bar trap is avoided.
//   Stop : 3.0 * ATR(14) hard stop (MACD is a trend-state strategy).
//   Vol/spread guard : skip only a genuinely wide spread (fail-open on .DWX
//     zero modeled spread).
//   Spread-skip extra : card asks to skip when D1 spread > 2x median; with .DWX
//     zero modeled spread this never fires in the tester — handled fail-open.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11809;
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
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 9;      // MACD signal EMA period
input int    strategy_atr_period        = 14;     // ATR period (hard stop)
input double strategy_sl_atr_mult       = 3.0;    // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helper: MACD histogram (MACD_DIFF) on a given closed-bar shift.
// hist = MACD main line - MACD signal line. Returns the difference; callers
// must guard against the warmup case by checking the raw lines if needed.
// -----------------------------------------------------------------------------
double MacdHist(const int shift)
  {
   const double main_v   = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                        strategy_macd_slow, strategy_macd_signal, shift);
   const double signal_v = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                          strategy_macd_slow, strategy_macd_signal, shift);
   return (main_v - signal_v);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is in
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

// Symmetric entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; new entries only from flat.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- MACD histogram on the two most recently closed bars (shift 2 -> 1) ---
   const double hist_prev = MacdHist(2);
   const double hist_now  = MacdHist(1);

   // --- ATR hard-stop distance ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Trigger EVENT: histogram zero-cross (single event per side) ---
   const bool cross_up   = (hist_prev <= 0.0 && hist_now > 0.0);
   const bool cross_down = (hist_prev >= 0.0 && hist_now < 0.0);

   if(cross_up)
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
      req.tp     = 0.0;   // exit on opposite zero-cross, no fixed target
      req.reason = "macd_zx_long";
      return true;
     }

   if(cross_down)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "macd_zx_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop. Exit is the opposite
// MACD zero-cross, handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit EVENT: opposite histogram zero-cross relative to the open position.
// Long exits on a fresh DOWN-cross; short exits on a fresh UP-cross. One event
// per closed bar; distinct from the entry trigger so no two-cross trap.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double hist_prev = MacdHist(2);
   const double hist_now  = MacdHist(1);
   const bool cross_up   = (hist_prev <= 0.0 && hist_now > 0.0);
   const bool cross_down = (hist_prev >= 0.0 && hist_now < 0.0);
   if(!cross_up && !cross_down)
      return false;

   // Determine current net direction for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && cross_down)
      return true;
   if(have_short && cross_up)
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
