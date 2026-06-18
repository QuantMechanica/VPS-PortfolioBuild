#property strict
#property version   "5.0"
#property description "QM5_11344 ichimoku-stack-d1 — Ichimoku stacked-line D1 trend state (long/short, reversal)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11344 ichimoku-stack-d1
// -----------------------------------------------------------------------------
// Source: Emeric Crue, "Back-Testing: Ichimoku Trading Strategy Using Python",
//         Python in Quantitative Finance, May 2019 (local PDF, source_id
//         e78a9f1f-4e6a-563c-a080-915133d6ed28). g0_status APPROVED.
// Card: artifacts/cards_approved/QM5_11344_ichimoku-stack-d1.md
//
// Mechanics (D1, closed-bar reads only — fully non-repainting):
//   Standard Ichimoku periods: Tenkan 9, Kijun 26, Senkou 52.
//
//   The Ichimoku stack is a STATE (alignment of the five lines), not an event.
//   The single EVENT is the transition into a fully-aligned stack on the close
//   of a D1 bar — read once per new closed bar.
//
//   LONG STATE (all strictly true on the last closed bar, shift 1):
//     1. Chikou Span  > Tenkan Sen   (momentum confirmation, non-repaint shift)
//     2. Tenkan Sen   > Kijun Sen
//     3. Kijun Sen    > Senkou Span A
//     4. Senkou Span A > Senkou Span B
//   SHORT STATE: the four strict inequalities reversed.
//
//   Entry  : if FLAT or holding the OPPOSITE direction and the target stack is
//            true -> open in the stack direction at next D1 open (market send
//            on the new closed bar). A held opposite position is closed first by
//            Strategy_ExitSignal (reverse-on-flip).
//   Exit   : close any open position when NEITHER the long nor the short stack
//            is true on a closed D1 bar (stack invalidation = primary exit), or
//            when the OPPOSITE stack becomes true (reverse).
//   Stop   : protective ATR(14) * 3.0 from entry (framework compatibility;
//            the primary close is stack invalidation, not the stop).
//
// NON-REPAINTING SHIFT SEMANTICS (the deterministic crux):
//   - Tenkan / Kijun (iIchimoku buffers 0/1) are plotted at the calculation bar
//     -> shift 1 == last closed bar. Non-repainting at shift >= 1.
//   - Senkou A / B (buffers 2/3) are stored forward-displaced by kijun_period.
//     Reading at shift 1 yields the cloud value PLOTTED at the last closed bar,
//     which was COMPUTED >= kijun_period bars ago -> non-repainting. This is the
//     cloud the last closed bar actually sits against ("price-vs-cloud").
//   - Chikou (buffer 4) is stored back-displaced by kijun_period: the close of a
//     bar is plotted kijun_period bars in the PAST. To read the last closed
//     bar's close as Chikou (and avoid a future/repainting read), use
//     shift = kijun_period + 1, and compare it to Tenkan at that SAME plotted
//     bar (shift = kijun_period + 1). This is the literal, deterministic reading
//     of "Chikou Span > Tenkan Sen on the last closed bar".
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread never
// blocks), no swap gate, no external feed, D1-native (no MN1). Broker-time
// sessions not used (daily trend state). One position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11344;
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
input int    strategy_tenkan_period     = 9;     // Tenkan-sen (conversion) period
input int    strategy_kijun_period      = 26;    // Kijun-sen (base) period; also the
                                                 // forward/back displacement of the spans
input int    strategy_senkou_period     = 52;    // Senkou Span B period
input int    strategy_atr_period        = 14;    // ATR period for the protective stop
input double strategy_atr_sl_mult       = 3.0;   // protective stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0; // skip only if spread > this % of stop dist

// -----------------------------------------------------------------------------
// Helpers — deterministic stack evaluation on the last closed D1 bar.
// -----------------------------------------------------------------------------

// Evaluate the four bullish stack inequalities on the last closed bar.
// Returns true only if every line read is valid (> 0) and strictly stacked.
bool Ichimoku_LongStack()
  {
   const int t  = strategy_tenkan_period;
   const int k  = strategy_kijun_period;
   const int s  = strategy_senkou_period;
   // Chikou is back-displaced by kijun_period; read the last closed bar's close
   // (and the Tenkan at the same plotted bar) at shift kijun_period + 1.
   const int chikou_shift = k + 1;

   const double tenkan  = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, 1);
   const double kijun   = QM_Ichimoku_KijunSen (_Symbol, _Period, t, k, s, 1);
   const double senkA   = QM_Ichimoku_SenkouSpanA(_Symbol, _Period, t, k, s, 1);
   const double senkB   = QM_Ichimoku_SenkouSpanB(_Symbol, _Period, t, k, s, 1);
   const double chikou  = QM_Ichimoku_ChikouSpan(_Symbol, _Period, t, k, s, chikou_shift);
   const double tenkanC = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, chikou_shift);

   if(tenkan <= 0.0 || kijun <= 0.0 || senkA <= 0.0 || senkB <= 0.0 ||
      chikou <= 0.0 || tenkanC <= 0.0)
      return false;

   return (chikou  > tenkanC &&
           tenkan  > kijun   &&
           kijun   > senkA   &&
           senkA   > senkB);
  }

// Evaluate the four bearish stack inequalities on the last closed bar.
bool Ichimoku_ShortStack()
  {
   const int t  = strategy_tenkan_period;
   const int k  = strategy_kijun_period;
   const int s  = strategy_senkou_period;
   const int chikou_shift = k + 1;

   const double tenkan  = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, 1);
   const double kijun   = QM_Ichimoku_KijunSen (_Symbol, _Period, t, k, s, 1);
   const double senkA   = QM_Ichimoku_SenkouSpanA(_Symbol, _Period, t, k, s, 1);
   const double senkB   = QM_Ichimoku_SenkouSpanB(_Symbol, _Period, t, k, s, 1);
   const double chikou  = QM_Ichimoku_ChikouSpan(_Symbol, _Period, t, k, s, chikou_shift);
   const double tenkanC = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, chikou_shift);

   if(tenkan <= 0.0 || kijun <= 0.0 || senkA <= 0.0 || senkB <= 0.0 ||
      chikou <= 0.0 || tenkanC <= 0.0)
      return false;

   return (chikou  < tenkanC &&
           tenkan  < kijun   &&
           kijun   < senkA   &&
           senkA   < senkB);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_atr_sl_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on the close of a D1 bar. Caller guarantees QM_IsNewBar() == true.
// Open in the stack direction only when FLAT (a held opposite position is
// closed first by Strategy_ExitSignal on the same tick -> next-bar reversal).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic. If a position is still open here it is
   // same-direction (opposite is closed by the exit hook) -> hold, no re-entry.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const bool long_stack  = Ichimoku_LongStack();
   const bool short_stack = Ichimoku_ShortStack();

   // Stacks are mutually exclusive by construction; guard anyway.
   if(long_stack == short_stack)
      return false; // both false (flat/no signal) or impossible both-true

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(long_stack)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_sl_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send (next D1 open)
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP; exit is stack invalidation / reversal
      req.reason = "ichimoku_stack_long";
      return true;
     }

   // short_stack
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = 0.0;
   req.reason = "ichimoku_stack_short";
   return true;
  }

// No active management beyond the protective ATR stop. Exit logic lives in
// Strategy_ExitSignal (stack invalidation / reversal).
void Strategy_ManageOpenPosition()
  {
  }

// Primary exit: close when NEITHER stack holds (invalidation), OR when the
// OPPOSITE stack to the open position becomes true (reverse on the next bar).
// Evaluated on the closed-bar path inside OnTick's exit branch.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const bool long_stack  = Ichimoku_LongStack();
   const bool short_stack = Ichimoku_ShortStack();

   // Determine the direction of the open position for this EA's magic.
   const int magic = QM_FrameworkMagic();
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
      if(ptype == POSITION_TYPE_BUY)  have_long  = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }

   // Invalidation: neither stack true -> flatten.
   if(!long_stack && !short_stack)
      return true;

   // Reversal: opposite stack true relative to the held direction -> close now;
   // entry re-opens in the new direction on this same closed bar.
   if(have_long && short_stack)
      return true;
   if(have_short && long_stack)
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
