#property strict
#property version   "5.0"
#property description "QM5_11557 carter-t-m5-ema20-macd-buystop-partial — EMA20 + MACD BuyStop + partial/BE/EMA-trail (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11557 carter-t-m5-ema20-macd-buystop-partial
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         System #18, self-published 2014.
// Card: artifacts/cards_approved/QM5_11557_carter-t-m5-ema20-macd-buystop-partial.md
//       (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1/2):
//   The confirming conditions are STATES; the pending-order FILL is the entry
//   EVENT. This avoids the "two crosses on one bar" zero-trade trap — nothing
//   requires two fresh cross events to coincide on a single bar.
//
//   LONG:
//     EMA20 STATE : EMA20(shift1) > EMA20(shift2)              (EMA20 rising;
//                   price-above-EMA confirmation comes via the BUY STOP above it).
//     MACD STATE  : MACD main(shift1) > 0  AND MACD main crossed UP through zero
//                   within the last macd_recency_bars closed bars.
//     Trigger     : BUY STOP placed entry_offset_pips above EMA20(shift1),
//                   expiring after pending_expiry_bars M5 bars. The break above
//                   EMA20+offset (the fill) is the entry event.
//     Stop        : entry - sl_pips         (card: conservative 20p, P2 cap 25p).
//   SHORT is the mirror image (EMA20 falling, MACD negative + recent down-cross,
//     SELL STOP below EMA20).
//
//   Exit / management (Strategy_ManageOpenPosition, per tick on the open):
//     1. Partial close partial_close_pct of the original volume at +1R
//        (price moved sl_distance in favour). Latched once (volume shrinks).
//     2. On the partial, move the remaining stop to break-even (entry price).
//     3. Trail the remaining stop each NEW closed bar by EMA20 -/+ trail_offset_pips
//        (long: ema20 - offset; short: ema20 + offset), monotonic only.
//
//   One pending OR position per magic/symbol at a time (OCO by construction:
//   we never stack the opposite pending while one already lives, and the
//   framework blocks a duplicate open position on the same magic/symbol).
//   Stale pendings self-expire after pending_expiry_bars via ORDER_TIME_SPECIFIED.
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread passes);
// no swap gate; QM_IsNewBar consumed ONCE (entry path only — management/trail use
// a separate latched-bar timestamp via QM_IsNewBar(sym,tf) overload is avoided;
// trail is gated by the SAME entry new-bar event through g_trail_due); confirmations
// are STATES with the FILL as the event; pip-scaled offsets via
// QM_StopRulesPipsToPriceDistance; no external feed; closed-bar reads only.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11557;
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
input int    strategy_ema_period          = 20;    // trend EMA period (card: EMA20)
input int    strategy_macd_fast           = 12;    // MACD fast EMA
input int    strategy_macd_slow           = 26;    // MACD slow EMA
input int    strategy_macd_signal         = 9;     // MACD signal SMA
input int    strategy_macd_recency_bars   = 5;     // MACD zero-cross recency window (P3: 3/5/8)
input int    strategy_entry_offset_pips   = 10;    // pending STOP offset from EMA20 (P3: 5/10/15)
input int    strategy_sl_pips             = 20;    // stop distance from fill price (card: 20p; P2 cap 25)
input int    strategy_pending_expiry_bars = 1;     // cancel unfilled pending after N M5 bars (card: bar close)
input double strategy_partial_close_pct   = 50.0;  // % of original volume closed at +1R
input int    strategy_trail_offset_pips   = 15;    // EMA20 -/+ this pip offset = trailed stop (P3: 10/15/20)
input bool   strategy_no_friday_entry     = true;  // card: no Friday entries
input double strategy_spread_pct_of_stop  = 25.0;  // skip only if spread > this % of stop distance

// 5-pip spread cap (card) expressed as % of the 20-pip stop = 25%. Kept as a
// %-of-stop cap so it scales with the configured stop distance.

// -----------------------------------------------------------------------------
// File-scope management state (per open trade lifecycle)
// -----------------------------------------------------------------------------
ulong  g_managed_ticket   = 0;     // ticket currently being managed
double g_initial_volume   = 0.0;   // original volume at fill (to detect partial)
double g_sl_distance      = 0.0;   // |entry - sl| captured at fill = 1R reference
bool   g_partial_done     = false; // +1R partial already taken
bool   g_trail_due        = false; // a new closed bar arrived -> trail allowed this tick

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// pip-distance in price terms for the active symbol (5-digit / JPY safe).
double PipsToPrice(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// MACD main crossed UP through zero within [shift1 .. recency] closed bars.
bool MacdCrossedUpRecently(const int recency)
  {
   for(int s = 1; s <= recency; ++s)
     {
      const double m_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s);
      const double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s + 1);
      if(m_prev <= 0.0 && m_now > 0.0)
         return true;
     }
   return false;
  }

bool MacdCrossedDownRecently(const int recency)
  {
   for(int s = 1; s <= recency; ++s)
     {
      const double m_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s);
      const double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s + 1);
      if(m_prev >= 0.0 && m_now < 0.0)
         return true;
     }
   return false;
  }

// True if a pending order for this EA's magic/symbol already lives.
bool HasLivePending(const int magic)
  {
   for(int oi = OrdersTotal() - 1; oi >= 0; --oi)
     {
      const ulong oticket = OrderGetTicket(oi);
      if(oticket == 0 || !OrderSelect(oticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = PipsToPrice(strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && ask > bid && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on the closed-bar path (QM_IsNewBar() == true guaranteed by caller).
// EMA20 rising + MACD positive & recently crossed zero = confirming STATES;
// the BUY/SELL STOP fill is the entry EVENT. One pending/open per magic/symbol.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   // One position per magic; do not stack a pending on top of an open position
   // or another pending (OCO by construction).
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(HasLivePending(magic))
      return false;

   // No Friday entries (card filter). Broker-time day-of-week.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema1 <= 0.0 || ema2 <= 0.0)
      return false;

   const double macd1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 1);

   const double offset  = PipsToPrice(strategy_entry_offset_pips);
   const double sl_dist = PipsToPrice(strategy_sl_pips);
   if(offset < 0.0 || sl_dist <= 0.0)
      return false;
   const int expiry_seconds = strategy_pending_expiry_bars * PeriodSeconds(_Period);

   // ---- LONG: EMA20 rising + MACD positive + recent up-cross of zero ----
   const bool ema_rising = (ema1 > ema2);
   if(ema_rising && macd1 > 0.0 && MacdCrossedUpRecently(strategy_macd_recency_bars))
     {
      const double entry_price = QM_TM_NormalizePrice(_Symbol, ema1 + offset);
      const double sl_price    = QM_TM_NormalizePrice(_Symbol, entry_price - sl_dist);
      if(entry_price <= 0.0 || sl_price <= 0.0 || sl_price >= entry_price)
         return false;

      req.type               = QM_BUY_STOP;
      req.price              = entry_price;
      req.sl                 = sl_price;
      req.tp                 = 0.0; // managed exit: partial @ +1R, BE, EMA trail
      req.reason             = "ema20_up_macd_buystop";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   // ---- SHORT: EMA20 falling + MACD negative + recent down-cross of zero ----
   const bool ema_falling = (ema1 < ema2);
   if(ema_falling && macd1 < 0.0 && MacdCrossedDownRecently(strategy_macd_recency_bars))
     {
      const double entry_price = QM_TM_NormalizePrice(_Symbol, ema1 - offset);
      const double sl_price    = QM_TM_NormalizePrice(_Symbol, entry_price + sl_dist);
      if(entry_price <= 0.0 || sl_price <= 0.0 || sl_price <= entry_price)
         return false;

      req.type               = QM_SELL_STOP;
      req.price              = entry_price;
      req.sl                 = sl_price;
      req.tp                 = 0.0;
      req.reason             = "ema20_down_macd_sellstop";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   return false;
  }

// Active management: +1R partial -> breakeven -> EMA-trail of the remainder.
// Runs every tick when an open position exists for this magic. The EMA-trail
// step is gated to one update per closed bar via g_trail_due (set in OnTick).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      // Lifecycle reset — nothing open for this magic.
      g_managed_ticket = 0;
      g_initial_volume = 0.0;
      g_sl_distance    = 0.0;
      g_partial_done   = false;
      return;
     }

   // Locate this magic's position on the active symbol.
   ulong  ticket     = 0;
   double open_price = 0.0;
   double volume     = 0.0;
   double cur_sl     = 0.0;
   bool   is_buy     = true;
   bool   found      = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket     = t;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume     = PositionGetDouble(POSITION_VOLUME);
      cur_sl     = PositionGetDouble(POSITION_SL);
      is_buy     = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found      = true;
      break;
     }
   if(!found || open_price <= 0.0)
      return;

   // New trade lifecycle detected — capture the 1R reference from the SL.
   if(ticket != g_managed_ticket)
     {
      g_managed_ticket = ticket;
      g_initial_volume = volume;
      g_sl_distance    = (cur_sl > 0.0) ? MathAbs(open_price - cur_sl)
                                        : PipsToPrice(strategy_sl_pips);
      g_partial_done   = false;
     }
   if(g_sl_distance <= 0.0)
      g_sl_distance = PipsToPrice(strategy_sl_pips);

   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double moved = is_buy ? (market - open_price) : (open_price - market);

   // ---- Step 1: partial close at +1R, then move stop to break-even ----
   if(!g_partial_done && moved >= g_sl_distance)
     {
      const double close_lots = QM_TM_NormalizeVolume(_Symbol,
                                   g_initial_volume * (strategy_partial_close_pct / 100.0));
      if(close_lots > 0.0 && close_lots < volume)
        {
         if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_STRATEGY))
           {
            g_partial_done = true;
            // Break-even on the remainder.
            const double be = QM_TM_NormalizePrice(_Symbol, open_price);
            QM_TM_MoveSL(ticket, be, "partial_1R_breakeven");
            return; // next tick re-reads the shrunk position
           }
        }
      else
        {
         // Volume too small to split — treat as managed without partial.
         g_partial_done = true;
        }
     }

   // ---- Step 2: EMA-trail the remaining stop, once per closed bar ----
   if(!g_trail_due)
      return;

   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema1 <= 0.0)
      return;
   const double trail_off = PipsToPrice(strategy_trail_offset_pips);

   if(is_buy)
     {
      const double new_sl = QM_TM_NormalizePrice(_Symbol, ema1 - trail_off);
      // Monotonic: only tighten upward, and never above the market.
      if(new_sl > 0.0 && new_sl < market && (cur_sl <= 0.0 || new_sl > cur_sl))
         QM_TM_MoveSL(ticket, new_sl, "ema20_trail_long");
     }
   else
     {
      const double new_sl = QM_TM_NormalizePrice(_Symbol, ema1 + trail_off);
      if(new_sl > 0.0 && new_sl > market && (cur_sl <= 0.0 || new_sl < cur_sl))
         QM_TM_MoveSL(ticket, new_sl, "ema20_trail_short");
     }
  }

// No discretionary close beyond the managed stop (partial / BE / EMA-trail).
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

   // Single new-bar consume for this tick. Used both to gate entry (below) and
   // to permit one EMA-trail step per closed bar (g_trail_due, read in manage).
   const bool new_bar = QM_IsNewBar();
   g_trail_due = new_bar;

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

   if(!new_bar)
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
