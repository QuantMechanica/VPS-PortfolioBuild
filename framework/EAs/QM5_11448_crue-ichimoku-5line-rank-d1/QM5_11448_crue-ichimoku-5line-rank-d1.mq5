#property strict
#property version   "5.0"
#property description "QM5_11448 crue-ichimoku-5line-rank-d1 — Ichimoku 5-line rank/stack D1 (always-in, -22 Chikou)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11448 crue-ichimoku-5line-rank-d1
// -----------------------------------------------------------------------------
// Source: Emeric Crue, "Backtesting Ichimoku Trading Strategy", Python in
//         Quantitative Finance, May 2019 (local PDF
//         409877311-BackTesting-Ichimoku-Trading-Strategy.pdf; source_id
//         26f4bdb0-0e74-5f92-9da1-dbdd8702cab2). g0_status APPROVED.
// Card: artifacts/cards_approved/QM5_11448_crue-ichimoku-5line-rank-d1.md
//
// Mechanics (D1, closed-bar reads only — fully non-repainting):
//   Ichimoku periods: Tenkan 9, Kijun 26, Senkou 52. Chikou displacement is the
//   NON-STANDARD -22 found optimal in Crue's in-/out-of-sample tests (vs the
//   standard -26 used by sibling QM5_11344).
//
//   The five Ichimoku lines are ranked in strict order. The rank/alignment is a
//   STATE; the single EVENT is the transition into a fully-stacked rank on the
//   close of a D1 bar — read once per new closed bar.
//
//   LONG STATE (all strictly true on the last closed bar):
//     1. Chikou        > Tenkan Sen   (close back-displaced -22, non-repaint)
//     2. Tenkan Sen    > Kijun Sen
//     3. Kijun Sen     > Senkou Span A
//     4. Senkou Span A > Senkou Span B   (bullish cloud)
//   SHORT STATE: the four strict inequalities reversed.
//
//   Entry  : always-in — if FLAT or holding the OPPOSITE direction and the
//            target rank is true -> open in the rank direction at next D1 open
//            (market send on the new closed bar). A held opposite position is
//            closed first by Strategy_ExitSignal (reverse-on-flip).
//   Exit   : close any open position when NEITHER the long nor the short rank
//            holds on a closed D1 bar (rank invalidation = primary exit), or
//            when the OPPOSITE rank becomes true (reverse).
//   Stop   : protective ATR(14) * 2.0 from entry (card P2 SL; the primary close
//            is rank invalidation, not the stop). Crue uses no hard stop; the
//            ATR stop is added for V5 risk control.
//
// NON-REPAINTING SHIFT SEMANTICS (the deterministic crux):
//   - Tenkan / Kijun (iIchimoku buffers 0/1) are plotted at the calculation bar
//     -> shift 1 == last closed bar. Non-repainting at shift >= 1.
//   - Senkou A / B (buffers 2/3) are stored forward-displaced by kijun_period.
//     Reading at shift 1 yields the cloud value PLOTTED at the last closed bar,
//     which was COMPUTED >= kijun_period bars ago -> non-repainting. This is the
//     cloud the last closed bar actually sits against ("price-vs-cloud").
//   - Chikou (buffer 4) is stored back-displaced by kijun_period: the close of a
//     bar is plotted kijun_period bars in the PAST. The card's -22 displacement
//     means we want the close from 22 bars back read as the Chikou "today", and
//     compared to the Tenkan at that SAME plotted bar (no future read). With the
//     MT5 buffer back-displaced by kijun_period(26), the close that is plotted at
//     "now minus chikou_displacement(22)" sits at buffer shift
//     (kijun_period - chikou_displacement) + 1 from the buffer's stored index.
//     We read Chikou at shift = (chikou_displacement + 1) and the Tenkan at the
//     same plotted bar (shift = chikou_displacement + 1). This is the literal,
//     deterministic, non-repainting reading of "Chikou(-22) vs Tenkan".
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread never
// blocks), no swap gate, no external feed, D1-native (no MN1). Broker-time
// sessions not used (daily trend state). One position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11448;
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
input int    strategy_tenkan_period        = 9;     // Tenkan-sen (conversion) period
input int    strategy_kijun_period         = 26;    // Kijun-sen (base) period; also the
                                                    // forward/back displacement of the MT5 spans
input int    strategy_senkou_period        = 52;    // Senkou Span B period
input int    strategy_chikou_displacement  = 22;    // NON-STANDARD -22 Chikou displacement (Crue)
input int    strategy_atr_period           = 14;    // ATR period for the protective stop
input double strategy_atr_sl_mult          = 2.0;   // protective stop = mult * ATR (card P2)
input double strategy_spread_pct_of_stop   = 15.0;  // skip only if spread > this % of stop dist

// -----------------------------------------------------------------------------
// Helpers — deterministic 5-line rank evaluation on the last closed D1 bar.
// -----------------------------------------------------------------------------

// Shift at which the Chikou (and the Tenkan it is compared to) is read so that
// the close back-displaced by strategy_chikou_displacement is non-repainting.
int Chikou_ReadShift()
  {
   return strategy_chikou_displacement + 1;
  }

// Evaluate the four bullish rank inequalities on the last closed bar.
// Returns true only if every line read is valid (> 0) and strictly ranked.
bool Ichimoku_LongRank()
  {
   const int t  = strategy_tenkan_period;
   const int k  = strategy_kijun_period;
   const int s  = strategy_senkou_period;
   const int cshift = Chikou_ReadShift();

   const double tenkan  = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, 1);
   const double kijun   = QM_Ichimoku_KijunSen (_Symbol, _Period, t, k, s, 1);
   const double senkA   = QM_Ichimoku_SenkouSpanA(_Symbol, _Period, t, k, s, 1);
   const double senkB   = QM_Ichimoku_SenkouSpanB(_Symbol, _Period, t, k, s, 1);
   const double chikou  = QM_Ichimoku_ChikouSpan(_Symbol, _Period, t, k, s, cshift);
   const double tenkanC = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, cshift);

   if(tenkan <= 0.0 || kijun <= 0.0 || senkA <= 0.0 || senkB <= 0.0 ||
      chikou <= 0.0 || tenkanC <= 0.0)
      return false;

   return (chikou  > tenkanC &&
           tenkan  > kijun   &&
           kijun   > senkA   &&
           senkA   > senkB);
  }

// Evaluate the four bearish rank inequalities on the last closed bar.
bool Ichimoku_ShortRank()
  {
   const int t  = strategy_tenkan_period;
   const int k  = strategy_kijun_period;
   const int s  = strategy_senkou_period;
   const int cshift = Chikou_ReadShift();

   const double tenkan  = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, 1);
   const double kijun   = QM_Ichimoku_KijunSen (_Symbol, _Period, t, k, s, 1);
   const double senkA   = QM_Ichimoku_SenkouSpanA(_Symbol, _Period, t, k, s, 1);
   const double senkB   = QM_Ichimoku_SenkouSpanB(_Symbol, _Period, t, k, s, 1);
   const double chikou  = QM_Ichimoku_ChikouSpan(_Symbol, _Period, t, k, s, cshift);
   const double tenkanC = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, cshift);

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
// Open in the rank direction only when FLAT (a held opposite position is closed
// first by Strategy_ExitSignal on the same tick -> next-bar reversal).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic. If a position is still open here it is
   // same-direction (opposite is closed by the exit hook) -> hold, no re-entry.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const bool long_rank  = Ichimoku_LongRank();
   const bool short_rank = Ichimoku_ShortRank();

   // Ranks are mutually exclusive by construction; guard anyway.
   if(long_rank == short_rank)
      return false; // both false (flat/no signal) or impossible both-true

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(long_rank)
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
      req.tp     = 0.0;   // no fixed TP; exit is rank invalidation / reversal
      req.reason = "ichimoku_5line_rank_long";
      return true;
     }

   // short_rank
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
   req.reason = "ichimoku_5line_rank_short";
   return true;
  }

// No active management beyond the protective ATR stop. Exit logic lives in
// Strategy_ExitSignal (rank invalidation / reversal).
void Strategy_ManageOpenPosition()
  {
  }

// Primary exit: close when NEITHER rank holds (invalidation), OR when the
// OPPOSITE rank to the open position becomes true (reverse on the next bar).
// Evaluated on the closed-bar path inside OnTick's exit branch.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const bool long_rank  = Ichimoku_LongRank();
   const bool short_rank = Ichimoku_ShortRank();

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

   // Invalidation: neither rank true -> flatten.
   if(!long_rank && !short_rank)
      return true;

   // Reversal: opposite rank true relative to the held direction -> close now;
   // entry re-opens in the new direction on this same closed bar.
   if(have_long && short_rank)
      return true;
   if(have_short && long_rank)
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
