#property strict
#property version   "5.0"
#property description "QM5_10980 ftmo-dhilo-brk — Prior-D1 High/Low Breakout (H1, long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10980 ftmo-dhilo-brk
// -----------------------------------------------------------------------------
// Source: FTMO blog "Why do we need a structured trading plan?" (2025-06-13).
// Card: artifacts/cards_approved/QM5_10980_ftmo-dhilo-brk.md (g0_status APPROVED).
//
// Mechanics (H1, closed-bar reads at shift 1; long + short):
//   Levels       : previous completed D1 candle HIGH and LOW (shift 1 on D1).
//   Long EVENT   : H1 close > prevD1High + buf_atr_mult * ATR(14,H1).
//   Short EVENT  : H1 close < prevD1Low  - buf_atr_mult * ATR(14,H1).
//   Stop (long)  : low(H1 breakout bar)  - sl_atr_mult * ATR(14,H1).
//   Stop (short) : high(H1 breakout bar) + sl_atr_mult * ATR(14,H1).
//   Take profit  : 3.0R from entry vs that stop (QM_TakeRR).
//   Management   : move SL to break-even once price reaches be_trigger_rr * R.
//   Exits        : end of broker day, OR time-stop after max_hold_bars H1 bars.
//   Filters      : one position per magic; one trade per broker day per symbol;
//                  skip Mon first N H1 bars + Fri last N H1 bars; skip if prior
//                  D1 range is outside [range_lo_mult, range_hi_mult]*ATR(14,D1).
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs + their small file-scope state
// are EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10980;
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
input int    strategy_atr_period         = 14;    // ATR period (H1 buffer/stop + D1 range filter)
input double strategy_buf_atr_mult       = 0.10;  // breakout buffer = mult * ATR(14,H1)
input double strategy_sl_atr_mult        = 0.10;  // SL beyond breakout-bar extreme = mult * ATR(14,H1)
input double strategy_tp_rr              = 3.0;    // take-profit = this * initial risk (R)
input double strategy_be_trigger_rr      = 1.5;   // move SL to break-even once price reaches this * R
input int    strategy_max_hold_bars      = 18;    // time exit after this many H1 bars
input double strategy_range_lo_mult      = 0.75;  // skip if prior D1 range < this * ATR(14,D1)
input double strategy_range_hi_mult      = 2.50;  // skip if prior D1 range > this * ATR(14,D1)
input int    strategy_skip_mon_open_bars = 2;     // skip first N H1 bars of Monday (broker time)
input int    strategy_skip_fri_close_bars = 4;    // skip last N H1 bars of Friday (broker time)
input double strategy_spread_atr_cap     = 1.00;  // skip if spread > this * ATR(14,H1) (fail-open on 0)

// -----------------------------------------------------------------------------
// File-scope strategy state.
//   g_traded_day        : broker-day index (days since epoch) on which an entry
//                         was last opened — enforces one trade per broker day.
//   g_bars_held         : H1 closed bars elapsed since the current entry (time stop).
//   g_have_position     : whether we currently track an open position.
// State is advanced ONLY on the framework new-bar gate (no per-EA timestamp
// reimplementation) and reset when the position closes.
// -----------------------------------------------------------------------------
long   g_traded_day    = -1;
int    g_bars_held     = 0;
bool   g_have_position = false;

// Broker-day index (whole days since epoch) for a broker timestamp.
long BrokerDayIndex(const datetime broker_time)
  {
   return (long)(broker_time / 86400);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/session work runs on the
// closed-bar entry path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false; // no ATR yet — defer, do not block here

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > strategy_spread_atr_cap * atr_h1)
      return true;

   return false;
  }

// Long+short breakout entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Bar-open time of the just-closed H1 bar (shift 1) in broker time.
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(bar_time <= 0)
      return false;

   // One trade per broker day per symbol.
   const long day_idx = BrokerDayIndex(bar_time);
   if(day_idx == g_traded_day)
      return false;

   // --- Session filter: skip Monday open bars and Friday close bars ---
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   if(dt.day_of_week == 1) // Monday
     {
      if(dt.hour < strategy_skip_mon_open_bars) // first N H1 bars (00:00..)
         return false;
     }
   if(dt.day_of_week == 5) // Friday
     {
      // Last N H1 bars before the 24:00 boundary.
      if(dt.hour >= (24 - strategy_skip_fri_close_bars))
         return false;
     }

   // --- Prior D1 levels (shift 1 on D1 = last completed daily candle) ---
   const double prevD1High = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: single closed-bar read
   const double prevD1Low  = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: single closed-bar read
   if(prevD1High <= 0.0 || prevD1Low <= 0.0 || prevD1High <= prevD1Low)
      return false;

   // --- Prior D1 range filter vs ATR(14,D1) ---
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_d1 <= 0.0)
      return false;
   const double prevD1Range = prevD1High - prevD1Low;
   if(prevD1Range < strategy_range_lo_mult * atr_d1 ||
      prevD1Range > strategy_range_hi_mult * atr_d1)
      return false;

   // --- Breakout buffer + stop reference from ATR(14,H1) ---
   const double atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false;
   const double buffer = strategy_buf_atr_mult * atr_h1;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   bool         go_long  = false;
   bool         go_short = false;
   if(close1 > prevD1High + buffer)
      go_long = true;
   else if(close1 < prevD1Low - buffer)
      go_short = true;

   if(!go_long && !go_short)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   if(go_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, low1 - strategy_sl_atr_mult * atr_h1);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "dhilo_brk_long";
     }
   else // go_short
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, high1 + strategy_sl_atr_mult * atr_h1);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "dhilo_brk_short";
     }

   // Mark this broker day as traded and reset the hold counter for the new entry.
   g_traded_day = day_idx;
   g_bars_held  = 0;
   return true;
  }

// Break-even shift once price reaches be_trigger_rr * R (R = open-to-SL distance).
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl     = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || cur_sl <= 0.0)
         continue;

      const bool   is_buy = (ptype == POSITION_TYPE_BUY);
      const double risk   = is_buy ? (open_price - cur_sl) : (cur_sl - open_price);
      if(risk <= 0.0)
         continue; // SL already at/through break-even

      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < strategy_be_trigger_rr * risk)
         continue;

      const double be = QM_TM_NormalizePrice(_Symbol, open_price);
      if(be <= 0.0)
         continue;
      QM_TM_MoveSL(ticket, be, "breakeven_at_1.5R");
     }
  }

// Discretionary exits: end of broker day, or time-stop after max_hold_bars.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_have_position = false;
      return false;
     }

   // Time-stop: g_bars_held is advanced once per closed H1 bar in OnTick wiring
   // via the framework new-bar gate (see AdvanceHoldCounter()).
   if(g_bars_held >= strategy_max_hold_bars)
      return true;

   // End-of-broker-day exit: close if the current bar's broker day differs from
   // the entry broker day (a new day has started while the position is open).
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(bar_time > 0 && BrokerDayIndex(bar_time) != g_traded_day)
      return true;

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// Advance the hold-bar counter once per closed H1 bar while a position is open.
// Called from OnTick under the framework new-bar gate — NOT a per-EA new-bar
// reimplementation; it consumes no timestamp of its own.
void AdvanceHoldCounter()
  {
   const bool open_now = (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
   if(open_now)
     {
      if(g_have_position)
         g_bars_held++;     // a closed bar elapsed while holding
      else
        {
         g_have_position = true; // first closed bar after the entry
         g_bars_held     = 0;
        }
     }
   else
     {
      g_have_position = false;
      g_bars_held     = 0;
     }
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

   // Per-closed-bar: advance the time-stop counter, then emit equity snapshot.
   AdvanceHoldCounter();
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
