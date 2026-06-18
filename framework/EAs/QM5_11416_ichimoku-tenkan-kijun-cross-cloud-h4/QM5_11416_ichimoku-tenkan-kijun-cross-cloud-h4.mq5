#property strict
#property version   "5.0"
#property description "QM5_11416 ichimoku-tenkan-kijun-cross-cloud-h4 — TK cross EVENT + cloud/Chikou STATE filters (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11416 ichimoku-tenkan-kijun-cross-cloud-h4
// -----------------------------------------------------------------------------
// Source: Anonymous, "Ichimoku Cloud Forex Trading Strategy" (local PDF,
//         source_id d45db07a-2928-5ff6-9251-d54170212549). g0_status APPROVED.
// Card: artifacts/cards_approved/QM5_11416_ichimoku-tenkan-kijun-cross-cloud-h4.md
// Reference sibling: QM5_11344_ichimoku-stack-d1.
//
// Mechanics (H4, closed-bar reads only — fully non-repainting):
//   Standard Ichimoku periods: Tenkan 9, Kijun 26, Senkou 52.
//
//   The Tenkan/Kijun (TK) cross is the single EVENT (entry trigger). The cloud
//   (Kumo) position and the Chikou-clear-space condition are STATES (filters),
//   per the .DWX invariant "don't require two cross EVENTS on the same bar".
//
//   LONG entry — all true on the last closed bar (shift 1):
//     EVENT  : Tenkan crossed above Kijun     -> Tenkan[2] < Kijun[2]  AND
//                                                Tenkan[1] > Kijun[1]
//     STATE 1: price above the cloud          -> Close[1] > max(SpanA[1], SpanB[1])
//     STATE 2: Chikou clear of historical px  -> Chikou (last closed bar's close,
//              plotted kijun_period bars back) is ABOVE the historical bar it
//              overlaps: chikou_close > High[kijun_period + 1].
//   SHORT entry: the symmetric reversed conditions.
//
//   Entry  : on the new closed H4 bar, if FLAT (one position per magic) and the
//            directional conditions hold -> open at next bar open (market send).
//   Exit   : (a) Chikou re-enters the historical bar range (chikou_close back
//            inside [Low, High] of the bar kijun_period+1 back) -> stack/space
//            lost; OR (b) an OPPOSITE TK cross fires. Reverse-on-flip is handled
//            by closing first (exit), then re-entering on the same closed bar.
//   Stop   : protective stop below Kijun-sen (long) / above Kijun-sen (short),
//            CAPPED at 60 pips (card P2 cap). RISK_FIXED sizing.
//
// NON-REPAINTING SHIFT SEMANTICS (the deterministic crux):
//   - Tenkan / Kijun (buffers 0/1) plot at the calc bar -> shift 1 == last closed
//     bar; cross read across shifts {1,2} is closed-bar, non-repainting.
//   - Senkou A / B (buffers 2/3) are stored forward-displaced by kijun_period.
//     Reading at shift 1 yields the cloud value PLOTTED at the last closed bar
//     (computed >= kijun_period bars ago) -> non-repainting; this is the cloud
//     the last closed bar's price actually sits against ("price-vs-cloud").
//   - Chikou (buffer 4) is stored back-displaced by kijun_period: the close of a
//     bar is plotted kijun_period bars in the PAST. To read the last closed bar's
//     close as Chikou and compare it to the historical bar it overlaps without a
//     future/repainting read, use shift = kijun_period + 1 for BOTH the Chikou
//     buffer and the High/Low it is compared against.
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread never
// blocks), no swap gate, no external feed, H4-native (no MN1), gapless-CFD safe
// (no prior-RANGE gap rule). Broker-time sessions not used (multi-day trend).
// One position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11416;
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
input double strategy_sl_cap_pips       = 60.0;  // P2 stop cap (pips) — Kijun stop is
                                                 // clamped to this maximum distance
input double strategy_spread_cap_pips   = 20.0;  // skip only if spread > this (card spread cap)

// -----------------------------------------------------------------------------
// Helpers — deterministic Ichimoku reads on the last closed H4 bar.
// All reads use closed-bar shifts; nothing repaints.
// -----------------------------------------------------------------------------

// Pip size for the symbol (5-digit / JPY aware) so the 60-pip cap and the 20-pip
// spread cap are scale-correct. 1 pip = 10 points on 3/5-digit quotes.
double Strat_PipSize()
  {
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

// TK cross on the last closed bar. dir = +1 long (Tenkan crossed above Kijun),
// -1 short (Tenkan crossed below Kijun). Reads shifts {1,2} -> non-repainting.
int Strat_TKCross()
  {
   const int t = strategy_tenkan_period;
   const int k = strategy_kijun_period;
   const int s = strategy_senkou_period;

   const double tk1 = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, 1);
   const double kj1 = QM_Ichimoku_KijunSen (_Symbol, _Period, t, k, s, 1);
   const double tk2 = QM_Ichimoku_TenkanSen(_Symbol, _Period, t, k, s, 2);
   const double kj2 = QM_Ichimoku_KijunSen (_Symbol, _Period, t, k, s, 2);

   if(tk1 <= 0.0 || kj1 <= 0.0 || tk2 <= 0.0 || kj2 <= 0.0)
      return 0;

   if(tk2 < kj2 && tk1 > kj1) return +1;   // bullish cross on last closed bar
   if(tk2 > kj2 && tk1 < kj1) return -1;    // bearish cross on last closed bar
   return 0;
  }

// Price-vs-cloud STATE on the last closed bar. +1 above cloud / -1 below / 0 in.
int Strat_CloudState()
  {
   const int t = strategy_tenkan_period;
   const int k = strategy_kijun_period;
   const int s = strategy_senkou_period;

   const double close1 = iClose(_Symbol, _Period, 1);            // perf-allowed: single closed-bar read
   const double spanA  = QM_Ichimoku_SenkouSpanA(_Symbol, _Period, t, k, s, 1);
   const double spanB  = QM_Ichimoku_SenkouSpanB(_Symbol, _Period, t, k, s, 1);

   if(close1 <= 0.0 || spanA <= 0.0 || spanB <= 0.0)
      return 0;

   const double cloud_top = MathMax(spanA, spanB);
   const double cloud_bot = MathMin(spanA, spanB);
   if(close1 > cloud_top) return +1;
   if(close1 < cloud_bot) return -1;
   return 0;
  }

// Chikou clear-space STATE. Reads the last closed bar's close via the Chikou
// buffer at shift (kijun_period + 1) and compares to the High/Low of the bar it
// is plotted onto (same shift). +1 = Chikou above that bar's High (clear upside),
// -1 = Chikou below that bar's Low (clear downside), 0 = inside the bar range.
int Strat_ChikouState()
  {
   const int t = strategy_tenkan_period;
   const int k = strategy_kijun_period;
   const int s = strategy_senkou_period;
   const int cshift = k + 1;

   const double chikou = QM_Ichimoku_ChikouSpan(_Symbol, _Period, t, k, s, cshift);
   const double hi     = iHigh(_Symbol, _Period, cshift);        // perf-allowed: single closed-bar read
   const double lo     = iLow (_Symbol, _Period, cshift);        // perf-allowed: single closed-bar read

   if(chikou <= 0.0 || hi <= 0.0 || lo <= 0.0)
      return 0;

   if(chikou > hi) return +1;
   if(chikou < lo) return -1;
   return 0;   // inside the historical bar range -> no clear space
  }

// Protective stop price: Kijun-sen (last closed bar) on the protective side,
// clamped so the stop distance never exceeds strategy_sl_cap_pips. type decides
// which side. Returns a normalized stop price, or 0.0 if unavailable.
double Strat_KijunStop(const QM_OrderType type, const double entry_price)
  {
   const int t = strategy_tenkan_period;
   const int k = strategy_kijun_period;
   const int s = strategy_senkou_period;

   const double kijun = QM_Ichimoku_KijunSen(_Symbol, _Period, t, k, s, 1);
   if(kijun <= 0.0 || entry_price <= 0.0)
      return 0.0;

   const double cap_dist = strategy_sl_cap_pips * Strat_PipSize();
   if(cap_dist <= 0.0)
      return 0.0;

   double sl = 0.0;
   if(type == QM_BUY)
     {
      sl = kijun;                                   // stop below entry (Kijun)
      if(sl >= entry_price)                         // Kijun not below price -> use cap
         sl = entry_price - cap_dist;
      if((entry_price - sl) > cap_dist)             // clamp to 60-pip cap
         sl = entry_price - cap_dist;
     }
   else // QM_SELL
     {
      sl = kijun;                                   // stop above entry (Kijun)
      if(sl <= entry_price)
         sl = entry_price + cap_dist;
      if((sl - entry_price) > cap_dist)
         sl = entry_price + cap_dist;
     }
   return QM_TM_NormalizePrice(_Symbol, sl);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;   // no valid quote yet — never block on it

   const double spread   = ask - bid;
   const double cap_dist = strategy_spread_cap_pips * Strat_PipSize();
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap_dist > 0.0 && spread > cap_dist)
      return true;

   return false;
  }

// Entry on the close of an H4 bar. Caller guarantees QM_IsNewBar() == true.
// One position per magic; only open when FLAT (opposite held positions are
// closed first by Strategy_ExitSignal on the same tick -> next-bar reversal).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int cross  = Strat_TKCross();
   if(cross == 0)
      return false;                               // the EVENT must fire

   const int cloud  = Strat_CloudState();
   const int chikou = Strat_ChikouState();

   if(cross > 0 && cloud > 0 && chikou > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = Strat_KijunStop(QM_BUY, entry);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send (next H4 open)
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP; exit is Chikou re-entry / opposite cross
      req.reason = "ichimoku_tk_cross_long";
      return true;
     }

   if(cross < 0 && cloud < 0 && chikou < 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = Strat_KijunStop(QM_SELL, entry);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "ichimoku_tk_cross_short";
      return true;
     }

   return false;
  }

// No active management beyond the protective Kijun-capped stop. Exit logic lives
// in Strategy_ExitSignal (Chikou re-entry / opposite cross).
void Strategy_ManageOpenPosition()
  {
  }

// Primary exit: Chikou re-enters the historical bar range (clear space lost), OR
// an OPPOSITE TK cross fires relative to the held direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Direction of the open position for this EA's magic.
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

   const int chikou = Strat_ChikouState();   // 0 == inside historical range
   const int cross  = Strat_TKCross();

   if(have_long)
     {
      if(chikou <= 0)       return true;     // Chikou no longer clear above
      if(cross  < 0)        return true;     // opposite (bearish) cross
     }
   if(have_short)
     {
      if(chikou >= 0)       return true;     // Chikou no longer clear below
      if(cross  > 0)        return true;     // opposite (bullish) cross
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
