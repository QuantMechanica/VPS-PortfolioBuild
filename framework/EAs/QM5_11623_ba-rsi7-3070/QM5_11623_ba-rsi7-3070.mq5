#property strict
#property version   "5.0"
#property description "QM5_11623 ba-rsi7-3070 — Basana RSI(7) 30/70 mean-reversion (D1, long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11623 ba-rsi7-3070
// -----------------------------------------------------------------------------
// Source: Gabriel Martin Becedillas Ruiz / gbeced, Basana RSI sample strategy
//   https://github.com/gbeced/basana/blob/develop/samples/strategies/rsi.py
// Card: artifacts/cards_approved/QM5_11623_ba-rsi7-3070.md (g0_status APPROVED).
//
// Mechanics (symmetric long+short, closed-bar reads at shift 1; D1):
//   RSI(7) threshold reversion.
//   Entry LONG  (oversold cross-into) : RSI[2] >= os_level AND RSI[1] <  os_level.
//   Entry SHORT (overbought cross-into): RSI[2] <= ob_level AND RSI[1] >  ob_level.
//     -> exactly the literal mechanical rule from the card body. The level-cross
//        is the SINGLE trigger EVENT (prev-vs-now), so it can never fire on the
//        same bar as the opposite cross (no two-cross-same-bar zero-trade trap).
//   Exit LONG  : RSI crosses back ABOVE the exit midline (RSI[2] < mid, RSI[1] >= mid)
//                OR an opposite (short) entry signal fires.
//   Exit SHORT : RSI crosses back BELOW the exit midline (RSI[2] > mid, RSI[1] <= mid)
//                OR an opposite (long) entry signal fires.
//   Emergency stop: entry +/- sl_atr_mult * ATR(atr_period) from entry. No TP
//                   (the RSI midline / opposite-signal exit closes the trade).
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-open on .DWX zero modeled spread).
//
// One open position per symbol/magic. Only the 5 Strategy_* hooks + Strategy
// inputs are EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11623;
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
input int    strategy_rsi_period        = 7;      // RSI lookback (Basana sample = 7)
input double strategy_rsi_oversold      = 30.0;   // oversold level (long trigger)
input double strategy_rsi_overbought    = 70.0;   // overbought level (short trigger)
input double strategy_rsi_exit_mid      = 50.0;   // midline exit level
input int    strategy_atr_period        = 20;     // ATR period for emergency stop
input double strategy_sl_atr_mult       = 3.0;    // emergency stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Returns +1 for a fresh LONG (oversold cross-into) signal, -1 for a fresh SHORT
// (overbought cross-into) signal, 0 otherwise. Evaluated on closed bars only:
// rsi_prev at shift 2, rsi_now at shift 1. A single prev->now level cross = one
// trigger EVENT per bar (no two-cross-same-bar trap).
int RsiEntryDirection()
  {
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return 0;

   // Long: RSI crosses DOWN into oversold (prev >= os, now < os) — literal card rule.
   if(rsi_prev >= strategy_rsi_oversold && rsi_now < strategy_rsi_oversold)
      return 1;

   // Short: RSI crosses UP into overbought (prev <= ob, now > ob) — literal card rule.
   if(rsi_prev <= strategy_rsi_overbought && rsi_now > strategy_rsi_overbought)
      return -1;

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — RSI work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
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

// Symmetric long/short entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int dir = RsiEntryDirection();
   if(dir == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(dir > 0)
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
      req.tp     = 0.0;   // no TP — RSI midline / opposite-signal exit
      req.reason = "ba_rsi7_long_os_cross";
      return true;
     }

   // dir < 0 — short
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
   req.reason = "ba_rsi7_short_ob_cross";
   return true;
  }

// No active trade management beyond the fixed ATR emergency stop. Discretionary
// exit (RSI midline / opposite signal) lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: RSI crosses back through the midline against the open
// position, OR an opposite entry signal fires. One event per closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine current open-position direction for this magic.
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
   if(!have_long && !have_short)
      return false;

   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   const int dir = RsiEntryDirection(); // opposite-signal check

   if(have_long)
     {
      // Exit long when RSI crosses back ABOVE the midline, or a short signal fires.
      const bool midline_up = (rsi_prev < strategy_rsi_exit_mid && rsi_now >= strategy_rsi_exit_mid);
      if(midline_up || dir < 0)
         return true;
     }

   if(have_short)
     {
      // Exit short when RSI crosses back BELOW the midline, or a long signal fires.
      const bool midline_down = (rsi_prev > strategy_rsi_exit_mid && rsi_now <= strategy_rsi_exit_mid);
      if(midline_down || dir > 0)
         return true;
     }

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
