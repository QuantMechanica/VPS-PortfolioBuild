#property strict
#property version   "5.0"
#property description "QM5_11139 bt-pink-20high — 20-bar high breakout (Donchian), 2-bar hold (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11139 bt-pink-20high
// -----------------------------------------------------------------------------
// Source: Daniel Rodriguez / backtrader "pinkfish challenge" sample
//   (samples/pinkfish-challenge/pinkfish-challenge.py).
// Card: artifacts/cards_approved/QM5_11139_bt-pink-20high.md (g0_status APPROVED).
//
// Mechanics (long-only, D1, closed-bar reads only):
//   Entry EVENT : the JUST-CLOSED bar (shift 1) prints a fresh N-bar high, i.e.
//                 high[1] > max(high[2..N+1]).  We use the prior CLOSED bars for
//                 the lookback high (shifts 2..N+1) and the closed signal bar
//                 (shift 1) as the trigger — never the forming bar — so the
//                 signal cannot repaint on a gapless .DWX CFD. Entry is filled
//                 at the next bar open (market-on-new-closed-bar), per the card's
//                 P2 next-open baseline.
//   Exit        : time stop — close after `hold_bars` closed D1 bars in market.
//   Stop loss   : emergency stop, the WIDER (lower) of
//                   (a) entry - sl_atr_mult * ATR(atr_period)   and
//                   (b) the signal-bar low.
//                 No profit target in the source baseline.
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//                 modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11139;
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
input int    strategy_high_lookback     = 20;     // N-bar highest-high lookback (prior closed bars)
input int    strategy_hold_bars         = 2;      // close after this many closed bars in market
input int    strategy_atr_period        = 14;     // ATR period for the emergency stop
input double strategy_sl_atr_mult       = 2.5;    // emergency stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — breakout work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only breakout entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int lookback = (strategy_high_lookback > 1) ? strategy_high_lookback : 20;

   // Highest high over the N CLOSED bars that PRECEDE the just-closed signal bar
   // (shifts 2 .. N+1). Using only closed bars means the trigger cannot repaint.
   double prior_high = 0.0;
   for(int s = 2; s <= lookback + 1; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: closed-bar breakout lookback
      if(h <= 0.0)
         return false;                              // insufficient history yet
      if(h > prior_high)
         prior_high = h;
     }
   if(prior_high <= 0.0)
      return false;

   // Trigger EVENT: the just-closed bar (shift 1) printed a fresh N-bar high.
   const double signal_high = iHigh(_Symbol, _Period, 1); // perf-allowed: closed signal bar
   const double signal_low  = iLow(_Symbol,  _Period, 1); // perf-allowed: closed signal bar
   if(signal_high <= 0.0)
      return false;
   if(!(signal_high > prior_high))
      return false;

   // --- Emergency stop: the WIDER (lower) of ATR-stop and the signal-bar low ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_stop = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(atr_stop <= 0.0)
      return false;

   // "whichever is wider after symbol normalization" → for a long, the lower stop.
   double sl = atr_stop;
   if(signal_low > 0.0 && signal_low < sl)
      sl = QM_TM_NormalizePrice(_Symbol, signal_low);
   if(sl <= 0.0 || sl >= entry)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send (next-bar open)
   req.sl     = sl;
   req.tp     = 0.0;   // no profit target in the source baseline
   req.reason = "pink_20high_breakout";
   return true;
  }

// No active stop/target adjustment — fixed emergency stop + time-stop exit only.
void Strategy_ManageOpenPosition()
  {
  }

// Time-stop exit: close after `strategy_hold_bars` closed D1 bars in market.
// Counts how many closed bars have elapsed since the entry bar by comparing
// the current bar-open time against the position open time. POSITION_TIME is a
// trade-management read (not a strategy new-bar gate), so this is not a per-EA
// new-bar reimplementation.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int hold = (strategy_hold_bars > 0) ? strategy_hold_bars : 2;

   // Open time of the current bar (shift 0) — advanced once per closed bar.
   const datetime bar_open_now = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open clock
   if(bar_open_now <= 0)
      return false;

   const int secs_per_bar = PeriodSeconds(_Period);
   if(secs_per_bar <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime pos_open = (datetime)PositionGetInteger(POSITION_TIME);
      if(pos_open <= 0)
         continue;

      // Bars elapsed = number of D1 boundaries crossed since the entry bar.
      const int bars_elapsed = (int)((bar_open_now - pos_open) / secs_per_bar);
      if(bars_elapsed >= hold)
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
