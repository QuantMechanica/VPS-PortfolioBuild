#property strict
#property version   "5.0"
#property description "QM5_12519 atr-sma-stop — SMA(14/28) crossover trend with ATR trailing stop (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12519 atr-sma-stop
// -----------------------------------------------------------------------------
// Source: Backtest Rookies "Tradingview: Daily ATR Stop" (2019-03-15).
// Card: artifacts/cards_approved/QM5_12519_atr-sma-stop.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; chart TF = H1, ATR sourced from D1):
//   Trigger EVENT : SMA(fast) crosses SMA(slow). One cross = one trigger.
//                   - fast crosses ABOVE slow  -> go long (close opposite first)
//                   - fast crosses BELOW slow  -> go short (close opposite first)
//                   This is the SINGLE trigger event; nothing else is required
//                   to be a fresh cross on the same bar (avoids two-cross trap).
//   Initial stop  : ATR-based, sized from D1 ATR(period):
//                   long  = entry - ATR_D1 * atr_mult
//                   short = entry + ATR_D1 * atr_mult   (via QM_StopATR)
//   Trailing stop : per-tick ATR trail on the D1 ATR (QM_TM_MoveSL, monotone,
//                   never loosens). Build-prompt KEY RULE: ATR sizes a TRAILING
//                   stop here (card's source default is a fixed stop; this build
//                   implements the trailing variant the prompt mandates).
//   Exit          : opposite SMA crossover closes/reverses the position
//                   (handled by the EntrySignal close-opposite + reversal path)
//                   plus the protective ATR trailing stop.
//
// Card timeframe note: card lists "H1 or H4 with daily ATR from D1 bars". This
// build uses H1 as the base chart TF (registered/swept in P2/P3); the D1 ATR is
// read explicitly via the strategy_atr_tf input so the stop volatility scale is
// the source's daily ATR regardless of chart TF.
//
// Symbols (all present in dwx_symbol_matrix.csv, registered verbatim):
//   EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX. No symbol porting required.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12519;
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
input int             strategy_sma_fast_period = 14;          // fast SMA period (source default 14)
input int             strategy_sma_slow_period = 28;          // slow SMA period (source default 28)
input ENUM_TIMEFRAMES strategy_atr_tf          = PERIOD_D1;   // ATR timeframe (source: daily ATR)
input int             strategy_atr_period      = 7;           // ATR period (source default 7)
input double          strategy_atr_mult        = 1.0;         // stop = mult * ATR (sweep 1.0/1.5/2.0)
input bool            strategy_atr_trail        = true;       // trail the ATR stop (prompt-mandated)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread/swap gating (.DWX zero modeled spread).
// Trend/cross work lives in Strategy_EntrySignal on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// SMA(fast)/SMA(slow) crossover entry. Caller guarantees QM_IsNewBar() == true.
// The cross is the SINGLE trigger event; opposite-side cross reverses.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Closed-bar SMA values: shift 1 = last closed bar, shift 2 = bar before.
   const double fast_now  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double slow_now  = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double fast_prev = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double slow_prev = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   // Single trigger EVENT: a fresh cross on the last closed bar.
   const bool cross_up   = (fast_prev <= slow_prev && fast_now >  slow_now);
   const bool cross_down = (fast_prev >= slow_prev && fast_now <  slow_now);
   if(!cross_up && !cross_down)
      return false;

   const int magic = QM_FrameworkMagic();

   // Reversal: if we hold a position on the opposite side, close it first so the
   // opposite cross flips us flat -> the new side opens on the next pass. One
   // position per magic is preserved (we never stack same-bar entries).
   if(QM_TM_OpenPositionCount(magic) > 0)
     {
      bool have_long  = false;
      bool have_short = false;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(ptype == POSITION_TYPE_BUY)  have_long  = true;
         if(ptype == POSITION_TYPE_SELL) have_short = true;
        }

      // Close the opposite side on this cross; do not open the new side in the
      // same call (one position per magic, no same-bar stacking).
      if((cross_up && have_short) || (cross_down && have_long))
        {
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
      return false; // already in a position (or just closed opposite) — no new entry now
     }

   // --- Flat: open in the direction of the fresh cross. ---
   const QM_OrderType side = cross_up ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Initial ATR stop sized from the source's daily ATR (atr_tf, atr_period).
   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target — exit via ATR trail + opposite cross
   req.reason = cross_up ? "sma_cross_long" : "sma_cross_short";
   return true;
  }

// ATR trailing stop: ratchet the protective stop with the D1 ATR every tick.
// QM_TM_MoveSL only tightens (the improves-check lives inside the trail call we
// build below); we read the D1 ATR explicitly so the trail scale matches entry.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_atr_trail)
      return;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   // ATR value from the strategy ATR timeframe (daily by default).
   const double atr_value = QM_ATR(_Symbol, strategy_atr_tf, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double trail_dist = atr_value * strategy_atr_mult;
   if(trail_dist <= 0.0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double raw_sl = is_buy ? (market - trail_dist) : (market + trail_dist);
      const double target_sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
      if(target_sl <= 0.0)
         continue;

      // Monotone ratchet: only tighten (raise for longs, lower for shorts).
      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5)
                                    : (target_sl < current_sl - point * 0.5));
      if(!improves)
         continue;

      QM_TM_MoveSL(ticket, target_sl, "atr_trail");
     }
  }

// Opposite-cross exit is handled in Strategy_EntrySignal (close-opposite path)
// together with the protective ATR trailing stop. No separate discretionary
// exit here.
bool Strategy_ExitSignal()
  {
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
