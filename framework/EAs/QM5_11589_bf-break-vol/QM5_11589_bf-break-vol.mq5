#property strict
#property version   "5.0"
#property description "QM5_11589 bf-break-vol — Rolling breakout, volume + ATR-volatility confirmed (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11589 bf-break-vol
// -----------------------------------------------------------------------------
// Source: conor19w/Binance-Futures-Trading-Bot, TradingStrats.py breakout()
//         https://github.com/conor19w/Binance-Futures-Trading-Bot
// Card: artifacts/cards_approved/QM5_11589_bf-break-vol.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M15 per card):
//   Breakout TRIGGER (EVENT, one per bar):
//     LONG  : the last closed bar's close[1] >= the rolling max close over the N
//             bars that PRECEDE it (shifts 2..N+1), AND the bar before it
//             (close[2]) was still BELOW that same prior-window max. That makes
//             the break a fresh edge-cross, not a "still elevated" state — so we
//             do not re-fire every bar while price hangs above the band (which a
//             pure level >= would do and the two-cross trap warns against).
//     SHORT : symmetric on the rolling MIN close.
//   Volume STATE (confirmation, from the card):
//     current closed-bar tick volume vol[1] >= the rolling max tick volume over
//     the preceding N bars (shifts 2..N+1) — i.e. the break came on a volume
//     expansion. Tick volume is the DWX proxy for the source's exchange volume.
//   Volatility STATE (expansion filter, required by the build contract):
//     ATR(period)/close > atr_floor_pct  — the breakout must occur while the
//     volatility regime is expanded, not in a dead flat tape. ATR is a STATE,
//     never a trigger; it gates the EVENT.
//   Exit (from the card, percentage-of-price):
//     TP = entry * (1 +/- tp_pct/100);  SL = entry * (1 -/+ sl_pct/100).
//     Defensive exit: an opposite fresh breakout closes the position before
//     TP/SL is reached (Strategy_ExitSignal).
//   Spread guard: block only a genuinely WIDE spread (fail-open on .DWX zero
//     modeled spread).
//
// One position per magic. Framework sizes lots (no lots field on the request).
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11589;
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
input int    strategy_breakout_lookback = 10;     // rolling window (bars) for high/low/volume extremes
input int    strategy_atr_period        = 14;     // ATR period (volatility-expansion filter)
input double strategy_atr_floor_pct     = 0.10;   // min ATR/close, in percent (volatility expansion gate)
input double strategy_tp_pct            = 1.0;    // take profit, percent of entry price (card default)
input double strategy_sl_pct            = 1.5;    // stop loss, percent of entry price (card default)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Rolling max close over the N bars preceding the trigger bar (shifts 2..N+1).
// perf-allowed: bespoke breakout band, single bounded closed-bar loop, runs
// only on the new-bar entry path.
double PriorMaxClose(const int lookback)
  {
   double hi = -1.0;
   for(int s = 2; s <= lookback + 1; ++s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed closed-bar read
      if(c <= 0.0)
         continue;
      if(hi < 0.0 || c > hi)
         hi = c;
     }
   return hi;
  }

// Rolling min close over the N bars preceding the trigger bar (shifts 2..N+1).
double PriorMinClose(const int lookback)
  {
   double lo = -1.0;
   for(int s = 2; s <= lookback + 1; ++s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed closed-bar read
      if(c <= 0.0)
         continue;
      if(lo < 0.0 || c < lo)
         lo = c;
     }
   return lo;
  }

// Rolling max tick volume over the N bars preceding the trigger bar.
double PriorMaxVolume(const int lookback)
  {
   double mx = 0.0;
   for(int s = 2; s <= lookback + 1; ++s)
     {
      const double v = (double)iVolume(_Symbol, _Period, s); // perf-allowed closed-bar read
      if(v > mx)
         mx = v;
     }
   return mx;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference = sl_pct of the current ask, so the cap scales.
   const double stop_distance = (strategy_sl_pct / 100.0) * ask;
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

   const int lb = strategy_breakout_lookback;
   if(lb < 2)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: trigger bar close
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: prior bar close
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Volatility STATE: ATR/close above the expansion floor (closed bar) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   if((atr_value / close1) * 100.0 <= strategy_atr_floor_pct)
      return false;

   // --- Volume STATE: the break bar's tick volume tops the prior window ---
   const double vol1   = (double)iVolume(_Symbol, _Period, 1); // perf-allowed
   const double vol_mx = PriorMaxVolume(lb);
   if(vol_mx <= 0.0)
      return false;
   if(!(vol1 >= vol_mx))
      return false;

   // --- Breakout TRIGGER (EVENT): fresh cross of the rolling extreme ---
   const double prior_max = PriorMaxClose(lb);
   const double prior_min = PriorMinClose(lb);
   if(prior_max <= 0.0 || prior_min <= 0.0)
      return false;

   // LONG: close[1] breaks at/above the prior-window max, close[2] was below it.
   const bool long_break  = (close1 >= prior_max && close2 < prior_max);
   // SHORT: close[1] breaks at/below the prior-window min, close[2] was above it.
   const bool short_break = (close1 <= prior_min && close2 > prior_min);

   // Exactly one direction may fire (fresh long and fresh short cannot coexist
   // on a single bar against the same window, but guard anyway).
   if(long_break == short_break)
      return false;

   QM_OrderType side = long_break ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Percentage-of-price SL / TP (card default: SL 1.5%, TP 1.0%) ---
   double sl, tp;
   if(side == QM_BUY)
     {
      sl = entry * (1.0 - strategy_sl_pct / 100.0);
      tp = entry * (1.0 + strategy_tp_pct / 100.0);
     }
   else
     {
      sl = entry * (1.0 + strategy_sl_pct / 100.0);
      tp = entry * (1.0 - strategy_tp_pct / 100.0);
     }
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   tp = QM_TM_NormalizePrice(_Symbol, tp);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_break ? "break_vol_long" : "break_vol_short";
   return true;
  }

// No active management beyond the fixed percentage SL/TP. Opposite-signal exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: an opposite fresh breakout closes the open position before
// TP/SL is hit. Evaluated once per closed bar via the framework new-bar gate.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int lb = strategy_breakout_lookback;
   if(lb < 2)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double prior_max = PriorMaxClose(lb);
   const double prior_min = PriorMinClose(lb);
   if(prior_max <= 0.0 || prior_min <= 0.0)
      return false;

   const bool long_break  = (close1 >= prior_max && close2 < prior_max);
   const bool short_break = (close1 <= prior_min && close2 > prior_min);
   if(long_break == short_break)
      return false; // no clean opposite signal this bar

   // Determine the open side; close it only on the genuinely opposite break.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && short_break)
         return true;
      if(ptype == POSITION_TYPE_SELL && long_break)
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
