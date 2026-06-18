#property strict
#property version   "5.0"
#property description "QM5_11776 tc-tf-s12-sma-cci5-m15 — Carter S12 SMA(7/21/84/336)+CCI(5) trend (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11776 tc-tf-s12-sma-cci5-m15
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Strategy #12", in 20 Trend Following Systems, 2014
//         (514732392-Forex-Trend-Following-Strategy.pdf, pp. 30-32).
// Card: artifacts/cards_approved/QM5_11776_tc-tf-s12-sma-cci5-m15.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1, M15):
//   Trigger EVENT (single) : SMA(7) crosses SMA(21). Long = SMA7 crosses ABOVE
//                            SMA21 between shift 2 and shift 1. Short = below.
//                            This is the ONLY cross EVENT — avoids the
//                            two-cross-same-bar zero-trade trap.
//   CCI confirm STATE      : CCI(5) on the correct side of zero. Long needs
//                            CCI(5) > 0 at shift 1; short needs CCI(5) < 0.
//                            The card asks for the CCI zero-cross "within ±1
//                            candle" of the SMA cross — implemented as a STATE
//                            (CCI already on the trigger side), not a second
//                            simultaneous cross event.
//   Trend filter STATE     : Long  -> close1 > SMA(84) AND close1 > SMA(336).
//                            Short -> close1 < SMA(84) AND close1 < SMA(336).
//   Stop loss              : factory default 2 x ATR(14) on M15.
//   Partial exit           : at +partial_pips profit close 50% of the position
//                            once, then move SL to break-even (entry price).
//   Trail remainder        : long  -> close below SMA(7) closes the rest;
//                            short -> close above SMA(7) closes the rest.
//   Spread guard           : block only a genuinely wide spread (fail-open on
//                            .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11776;
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
input int    strategy_sma_fast_period    = 7;     // fast SMA (cross trigger, also trail line)
input int    strategy_sma_slow_period    = 21;    // slow SMA (cross trigger)
input int    strategy_sma_mid_period     = 84;    // long-term trend filter (7x12)
input int    strategy_sma_long_period    = 336;   // long-term trend filter (7x48)
input int    strategy_cci_period         = 5;     // CCI(5) confirm oscillator
input int    strategy_atr_period         = 14;    // ATR period for the stop
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_partial_pips       = 25.0;  // partial-exit profit threshold (pips)
input double strategy_partial_fraction   = 0.5;   // fraction of the position closed at partial
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// File-scope latch so the 50% partial close + break-even shift happen once.
ulong  g_partial_done_ticket = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- SMAs at the two most recent closed bars (shift 2 -> shift 1) ---
   const double sma_fast_1 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double sma_fast_2 = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double sma_slow_1 = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double sma_slow_2 = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(sma_fast_1 <= 0.0 || sma_fast_2 <= 0.0 || sma_slow_1 <= 0.0 || sma_slow_2 <= 0.0)
      return false;

   // --- Single trigger EVENT: SMA(7) crosses SMA(21) on the last closed bar ---
   const bool cross_up   = (sma_fast_2 <= sma_slow_2 && sma_fast_1 > sma_slow_1);
   const bool cross_down = (sma_fast_2 >= sma_slow_2 && sma_fast_1 < sma_slow_1);
   if(!cross_up && !cross_down)
      return false;

   // --- Long-term trend filter STATE: close vs SMA(84) and SMA(336) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   const double sma_mid_1  = QM_SMA(_Symbol, _Period, strategy_sma_mid_period, 1);
   const double sma_long_1 = QM_SMA(_Symbol, _Period, strategy_sma_long_period, 1);
   if(sma_mid_1 <= 0.0 || sma_long_1 <= 0.0)
      return false;

   // --- CCI(5) confirm STATE: on the correct side of the zero line ---
   const double cci_1 = QM_CCI(_Symbol, _Period, strategy_cci_period, 1, PRICE_TYPICAL);

   const bool long_ok  = cross_up   &&
                         cci_1 > 0.0 &&
                         close1 > sma_mid_1 &&
                         close1 > sma_long_1;
   const bool short_ok = cross_down  &&
                         cci_1 < 0.0 &&
                         close1 < sma_mid_1 &&
                         close1 < sma_long_1;
   if(!long_ok && !short_ok)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const QM_OrderType otype = long_ok ? QM_BUY : QM_SELL;
   const double entry = (otype == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, otype, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP; exit by partial + SMA(7) trail
   req.reason = long_ok ? "carter_s12_long" : "carter_s12_short";

   // New entry pending — clear the partial latch so the new ticket can scale once.
   g_partial_done_ticket = 0;
   return true;
  }

// Per-tick management: close 50% at +partial_pips, then move SL to break-even.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(ticket == g_partial_done_ticket) // already scaled this position
         continue;

      const long   ptype = PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double vol   = PositionGetDouble(POSITION_VOLUME);
      if(entry <= 0.0 || vol <= 0.0)
         continue;

      const double partial_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_partial_pips);
      if(partial_dist <= 0.0)
         continue;

      bool target_hit = false;
      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         target_hit = (bid > 0.0 && bid >= entry + partial_dist);
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         target_hit = (ask > 0.0 && ask <= entry - partial_dist);
        }
      if(!target_hit)
         continue;

      const double close_vol = QM_TM_NormalizeVolume(_Symbol, vol * strategy_partial_fraction);
      if(close_vol > 0.0 && close_vol < vol)
         QM_TM_PartialClose(ticket, close_vol, QM_EXIT_STRATEGY);

      // Move the remainder's stop to break-even (entry price).
      QM_TM_MoveSL(ticket, entry, "carter_s12_breakeven");
      g_partial_done_ticket = ticket;
     }
  }

// Trail exit: long closes when the last closed bar closed below SMA(7);
// short closes when it closed above SMA(7). One closed-bar evaluation.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double sma_fast = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   if(close1 <= 0.0 || sma_fast <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 < sma_fast)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 > sma_fast)
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
