#property strict
#property version   "5.0"
#property description "QM5_11160 dwx-brk-risk — Price-channel breakout w/ ATR risk control (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11160 dwx-brk-risk
// -----------------------------------------------------------------------------
// Source: Darwinex Blog "The Journey of an Automated Trading Expert" (2024-10-03)
//   — Wim's hallmark: simple breakout systems, few indicators, a hard stop on
//   every trade. Card: artifacts/cards_approved/QM5_11160_dwx-brk-risk.md
//   (g0_status APPROVED).
//
// Mechanics (long/short, closed-bar reads at shift 1; breakout uses PRIOR
// CLOSED bars only):
//   Channel      : rolling high/low over bars [2 .. lookback+1] (excludes the
//                  breakout bar at shift 1 so the signal is on a fresh break).
//   Long EVENT   : close[1] > channel_high AND breakout-bar range >=
//                  brk_range_atr_mult * ATR(14) at shift 1.
//   Short EVENT  : close[1] < channel_low  AND same range filter.
//   Entry        : market BUY/SELL on the new bar open.
//   Stop         : entry -/+ atr_stop_mult * ATR(14), capped at the opposite
//                  side of the breakout bar (low[1] for longs, high[1] for
//                  shorts) if that is CLOSER (tighter) than the ATR stop.
//   Take profit  : tp_rr * R from entry (R = |entry - sl|).
//   Break-even   : at +1R favourable, SL moved to entry.
//   Time stop    : close after max_holding_bars closed H1 bars in trade.
//   Opposite exit: a fresh opposite breakout closes the position.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of
//                  the planned stop distance (fail-open on .DWX zero spread).
//   Weekly open  : skip the first skip_minutes_after_open minutes of the trading
//                  week (broker time) to avoid the Sunday/Monday open noise.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11160;
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
input int    strategy_breakout_lookback  = 48;    // channel lookback (bars [2..lookback+1])
input int    strategy_atr_period         = 14;    // ATR period (range filter + stop)
input double strategy_brk_range_atr_mult = 0.75;  // min breakout-bar range as x ATR
input double strategy_atr_stop_mult      = 1.5;   // initial stop distance = mult * ATR
input double strategy_tp_rr              = 1.5;   // take profit at this R multiple
input int    strategy_max_holding_bars   = 18;    // time stop after N closed bars
input double strategy_be_trigger_rr      = 1.0;   // move SL to break-even at this R
input double strategy_spread_pct_of_stop = 10.0;  // skip if spread > this % of stop distance
input int    strategy_skip_minutes_after_open = 15; // skip first N min of the trading week

// -----------------------------------------------------------------------------
// Helpers (closed-bar reads only; perf-allowed single-shift bar accessors)
// -----------------------------------------------------------------------------

// Rolling channel high over bars [2 .. lookback+1] (excludes the breakout bar
// at shift 1). perf-allowed: bounded single pass per closed-bar entry gate.
double ChannelHigh()
  {
   double hi = 0.0;
   const int first = 2;
   const int last  = strategy_breakout_lookback + 1;
   for(int s = first; s <= last; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: closed-bar read
      if(h <= 0.0)
         continue;
      if(hi == 0.0 || h > hi)
         hi = h;
     }
   return hi;
  }

double ChannelLow()
  {
   double lo = 0.0;
   const int first = 2;
   const int last  = strategy_breakout_lookback + 1;
   for(int s = first; s <= last; ++s)
     {
      const double l = iLow(_Symbol, _Period, s); // perf-allowed: closed-bar read
      if(l <= 0.0)
         continue;
      if(lo == 0.0 || l < lo)
         lo = l;
     }
   return lo;
  }

// +1 fresh long breakout / -1 fresh short breakout / 0 none, evaluated on the
// last closed bar (shift 1) against the prior channel. Range filter applied.
int BreakoutSignal()
  {
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return 0;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double low1   = iLow(_Symbol, _Period, 1);
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return 0;

   const double bar_range = high1 - low1;
   if(bar_range < strategy_brk_range_atr_mult * atr)
      return 0;

   const double ch_hi = ChannelHigh();
   const double ch_lo = ChannelLow();
   if(ch_hi <= 0.0 || ch_lo <= 0.0)
      return 0;

   if(close1 > ch_hi)
      return +1;
   if(close1 < ch_lo)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: weekly-open skip + spread guard. Fail-open on the
// .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   // --- Skip the first N minutes of the trading week (broker time) ---
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   // DXZ broker week opens Monday; the Sunday-evening session belongs to Monday.
   if(dt.day_of_week == 1 && (dt.hour * 60 + dt.min) < strategy_skip_minutes_after_open)
      return true;

   // --- Spread guard (fail-open on zero modeled spread) ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false; // no ATR yet — defer, do not block

   const double stop_distance = strategy_atr_stop_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long/short breakout entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int sig = BreakoutSignal();
   if(sig == 0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   const double low1  = iLow(_Symbol, _Period, 1);
   if(high1 <= 0.0 || low1 <= 0.0)
      return false;

   if(sig > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // ATR stop, then tighten to the breakout-bar low if that is closer.
      double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_stop_mult);
      if(sl <= 0.0)
         return false;
      if(low1 < entry && low1 > sl) // breakout-bar low is closer (higher) than ATR stop
         sl = QM_StopRulesNormalizePrice(_Symbol, low1);
      if(sl >= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0; // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "dwx_breakout_long";
      return true;
     }
   else // sig < 0
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr, strategy_atr_stop_mult);
      if(sl <= 0.0)
         return false;
      if(high1 > entry && high1 < sl) // breakout-bar high is closer (lower) than ATR stop
         sl = QM_StopRulesNormalizePrice(_Symbol, high1);
      if(sl <= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "dwx_breakout_short";
      return true;
     }
  }

// Break-even at +1R. Reads the open position for this magic and moves the SL to
// entry once price has travelled be_trigger_rr * R in favour.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl    = PositionGetDouble(POSITION_SL);
      const long   ptype = PositionGetInteger(POSITION_TYPE);
      if(entry <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double risk = entry - sl;
         if(risk <= 0.0)
            continue;
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid >= entry + strategy_be_trigger_rr * risk && sl < entry)
            QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, entry), "break_even");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double risk = sl - entry;
         if(risk <= 0.0)
            continue;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= entry - strategy_be_trigger_rr * risk && sl > entry)
            QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, entry), "break_even");
        }
     }
  }

// Discretionary exit: time stop (max_holding_bars) OR opposite fresh breakout.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this EA's position on this symbol to read its open time / direction.
   long   ptype     = -1;
   datetime open_tm = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ptype   = PositionGetInteger(POSITION_TYPE);
      open_tm = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(ptype < 0)
      return false;

   // --- Time stop: closed bars elapsed since entry >= max_holding_bars ---
   const int secs_per_bar = PeriodSeconds(_Period);
   if(secs_per_bar > 0 && open_tm > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: current bar open time
      if(cur_bar > 0)
        {
         const int bars_held = (int)((cur_bar - open_tm) / secs_per_bar);
         if(bars_held >= strategy_max_holding_bars)
            return true;
        }
     }

   // --- Opposite fresh breakout closes the position ---
   const int sig = BreakoutSignal();
   if(ptype == POSITION_TYPE_BUY && sig < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && sig > 0)
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
