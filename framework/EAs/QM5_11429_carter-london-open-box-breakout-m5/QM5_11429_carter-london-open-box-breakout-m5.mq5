#property strict
#property version   "5.0"
#property description "QM5_11429 Carter — London Open Box Breakout (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_11429 — Carter London Open Box Breakout (M5)
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_11429_carter-london-open-box-breakout-m5.md
//       (g0_status: APPROVED)
// Source: John Carter, "20 Strategies for the 5-Minute Timeframe".
//
// Mechanic (mechanical, deterministic):
//   - The hour BEFORE the London open (07:00-08:00 ET) builds a range "box":
//       box_high = max(High) of the box-window M5 bars,
//       box_low  = min(Low)  of the box-window M5 bars,
//       box_height = box_high - box_low (must be >= box_min_pips).
//   - In the 60-minute signal window AFTER the box closes (08:00-09:00 ET),
//     a breakout fires on the CLOSE of an M5 bar:
//       LONG  when bar close > box_high + entry_buffer_frac * box_height,
//       SHORT when bar close < box_low  - entry_buffer_frac * box_height.
//     The breakout close is the single EVENT (gapless-CFD-correct: we reference
//     the bar CLOSE crossing the level, not an opening gap or intrabar range).
//   - Entry is a MARKET order on that closed breakout bar (one position per
//     symbol/magic; no re-entry after the position closes within the session).
//   - SL = opposite box side +/- sl_buffer_pips, capped at sl_cap_pips.
//   - TP = tp_box_mult * box_height measured from the broken box BOUNDARY
//          (LONG: box_high + tp_box_mult*h ; SHORT: box_low - tp_box_mult*h).
//   - Time stop: any open position is closed at/after time_stop_et_hour (10:00
//     ET) if neither SL nor TP has triggered.
//
// Broker time / session note (.DWX, DXZ NY-Close GMT+2/+3 DST-aware):
//   The box window and signal window are defined on the US (ET) clock by the
//   card (07:00/08:00/09:00 ET, US-DST aware). MT5 bar timestamps are in BROKER
//   time. We convert every evaluated bar's OPEN timestamp:
//       broker_open -> UTC via QM_BrokerToUTC -> ET via (UTC - 5h, or -4h when
//       US DST is active per QM_IsUSDSTUTC).
//   Only US DST exists in the framework (no UK/London helper); the card frames
//   the entire session on the US ET clock, so the US-DST calendar is exactly
//   what the box/signal windows need. No wall-clock TimeCurrent() gating is used
//   for the session frame — everything keys off the bar OPEN timestamp.
//
// .DWX invariants honoured:
//   - Spread guard fails OPEN on zero modeled spread (only blocks a genuinely
//     wide spread when ask>bid).
//   - QM_IsNewBar(M5) consumed exactly ONCE per tick by the framework; the entry
//     hook runs only on a fresh closed M5 bar.
//   - Buffers/SL/cap are expressed in PIPS and converted via
//     QM_StopRulesPipsToPriceDistance (scale-correct on 5-digit FX / 3-digit JPY).
//   - Box OHLC + bar-timestamp reads are bespoke structural data with no
//     framework reader; they run once per fresh M5 bar (perf-allowed), bounded
//     by box_lookback_bars (~12), O(1) per bar — no per-tick loop.
//   - No external macro/CSV feed: box is built purely from M5 OHLC.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11429;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Box window on the ET (US) clock: [box_start_et_hour, box_end_et_hour).
input int    box_start_et_hour          = 7;    // 07:00 ET — one hour before London open
input int    box_end_et_hour            = 8;    // 08:00 ET — London open (box closes)
// Signal (breakout) window on the ET clock: [box_end_et_hour, signal_end_et_hour).
input int    signal_end_et_hour         = 9;    // 09:00 ET — last breakout opportunity
// In-trade time stop: close any open position at/after this ET hour.
input int    time_stop_et_hour          = 10;   // 10:00 ET
// Box-window M5 bar count: 60 min / 5 min = 12 bars. Upper bound for the scan.
input int    box_lookback_bars          = 12;
// Minimum box height to accept (filters degenerate tiny boxes), pips.
input double box_min_pips               = 5.0;
// Breakout buffer beyond the box edge, as a fraction of box height.
input double entry_buffer_frac          = 0.20;
// Take profit = tp_box_mult * box_height, measured from the broken boundary.
input double tp_box_mult                = 4.0;
// Stop loss buffer beyond the opposite box side, pips.
input double sl_buffer_pips             = 1.0;
// Stop loss cap for very wide boxes, pips.
input double sl_cap_pips                = 60.0;
// Maximum spread allowed (pips). Fails OPEN on zero modeled spread (.DWX).
input double max_spread_pips            = 15.0;

// -----------------------------------------------------------------------------
// File-scope session state (advanced once per fresh M5 bar).
// -----------------------------------------------------------------------------
// Identifies the ET calendar day for which the cached box belongs.
datetime g_box_session_day   = 0;     // ET-midnight datetime of the cached box's day
bool     g_box_valid         = false; // box built & passed min-height for the session
double   g_box_high          = 0.0;
double   g_box_low           = 0.0;
double   g_box_height        = 0.0;
bool     g_traded_session    = false; // already opened a trade this session (no re-entry)

// -----------------------------------------------------------------------------
// Broker-bar timestamp -> ET conversion helpers.
// -----------------------------------------------------------------------------

// Convert a BROKER-time bar timestamp to Eastern Time (US), DST-aware.
datetime BrokerBarToET(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int et_offset = QM_IsUSDSTUTC(utc) ? 4 : 5;   // EDT=UTC-4, EST=UTC-5
   return utc - (et_offset * 3600);
  }

// ET-midnight (00:00 ET) of the day containing this ET timestamp.
datetime ETMidnight(const datetime et_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(et_time, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

int ETHour(const datetime et_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(et_time, dt);
   return dt.hour;
  }

// Build the box for the ET session day of the just-closed bar, scanning back
// over the M5 bars whose ET OPEN time falls in [box_start_et_hour, box_end_et_hour)
// on that same ET calendar day. perf-allowed bespoke structural read, bounded by
// box_lookback_bars + small margin, run once per fresh M5 bar.
void BuildBoxForSession(const datetime session_day_et)
  {
   double hi = 0.0;
   double lo = 0.0;
   bool   have = false;

   // Scan a margin beyond box_lookback_bars to absorb gaps/weekend bars. The box
   // window only contains <=12 M5 bars; cap the scan defensively.
   const int max_scan = (box_lookback_bars > 0 ? box_lookback_bars : 12) + 8;
   for(int shift = 1; shift <= max_scan; shift++)
     {
      const datetime bar_broker = iTime(_Symbol, PERIOD_M5, shift);  // perf-allowed
      if(bar_broker <= 0)
         break;

      const datetime bar_et = BrokerBarToET(bar_broker);
      // Stop once we walk past the start of the box day's window (older bars).
      if(ETMidnight(bar_et) != session_day_et)
        {
         // A bar from a different ET day ends the relevant scan window.
         if(bar_et < session_day_et)
            break;
         continue;
        }

      const int h = ETHour(bar_et);
      if(h < box_start_et_hour)
         break;                       // walked before the box window — done
      if(h >= box_end_et_hour)
         continue;                    // bar at/after box close — not in box

      const double bar_hi = iHigh(_Symbol, PERIOD_M5, shift);  // perf-allowed
      const double bar_lo = iLow(_Symbol, PERIOD_M5, shift);   // perf-allowed
      if(bar_hi <= 0.0 || bar_lo <= 0.0)
         continue;

      if(!have)
        {
         hi = bar_hi;
         lo = bar_lo;
         have = true;
        }
      else
        {
         if(bar_hi > hi) hi = bar_hi;
         if(bar_lo < lo) lo = bar_lo;
        }
     }

   g_box_high   = hi;
   g_box_low    = lo;
   g_box_height = (have ? (hi - lo) : 0.0);

   const double min_h = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(box_min_pips));
   g_box_valid = (have && g_box_height > 0.0 && (min_h <= 0.0 || g_box_height >= min_h));
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading only on a genuinely wide spread. .DWX quotes ask==bid (spread 0)
// in the tester, so this MUST fail open on zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(max_spread_pips));
      if(cap > 0.0 && (ask - bid) > cap)
         return true;   // genuinely wide spread → block
     }
   return false;
  }

// New entry on a freshly-closed M5 bar. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One active position per symbol/magic — no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Locate the just-closed M5 bar in ET. ---
   const datetime bar_broker = iTime(_Symbol, PERIOD_M5, 1);   // perf-allowed
   if(bar_broker <= 0)
      return false;
   const datetime bar_et   = BrokerBarToET(bar_broker);
   const datetime day_et   = ETMidnight(bar_et);
   const int      hour_et  = ETHour(bar_et);

   // --- Session roll: new ET day resets box + per-session trade latch. ---
   if(day_et != g_box_session_day)
     {
      g_box_session_day = day_et;
      g_box_valid       = false;
      g_traded_session  = false;
     }

   // --- Only act inside the breakout signal window [box_end, signal_end) ET. ---
   if(hour_et < box_end_et_hour || hour_et >= signal_end_et_hour)
      return false;

   // No re-entry after a trade has been taken this session.
   if(g_traded_session)
      return false;

   // --- Build the box once per session (on first signal-window bar). ---
   if(!g_box_valid)
      BuildBoxForSession(day_et);
   if(!g_box_valid)
      return false;

   // --- Breakout trigger off the just-closed bar CLOSE. ---
   const double bar_close = iClose(_Symbol, PERIOD_M5, 1);   // perf-allowed
   if(bar_close <= 0.0)
      return false;

   const double buf = entry_buffer_frac * g_box_height;
   const double up_level = g_box_high + buf;
   const double dn_level = g_box_low  - buf;

   QM_OrderType side;
   if(bar_close > up_level)
      side = QM_BUY;
   else if(bar_close < dn_level)
      side = QM_SELL;
   else
      return false;

   // --- Stop loss: opposite box side +/- sl_buffer_pips, capped at sl_cap_pips.
   const double sl_buf  = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(sl_buffer_pips));
   const double sl_cap  = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(sl_cap_pips));
   const double boundary = (side == QM_BUY) ? g_box_high : g_box_low;  // broken edge

   double sl_price;
   if(side == QM_BUY)
      sl_price = g_box_low - sl_buf;     // opposite (lower) box side
   else
      sl_price = g_box_high + sl_buf;    // opposite (upper) box side

   // Apply the cap on the SL DISTANCE from the broken boundary.
   if(sl_cap > 0.0)
     {
      const double sl_dist = MathAbs(boundary - sl_price);
      if(sl_dist > sl_cap)
         sl_price = (side == QM_BUY) ? (boundary - sl_cap) : (boundary + sl_cap);
     }
   sl_price = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   if(sl_price <= 0.0)
      return false;

   // --- Take profit: tp_box_mult * box_height from the broken boundary. ---
   const double tp_dist = tp_box_mult * g_box_height;
   const double tp_price = QM_StopRulesTakeFromDistance(_Symbol, side, boundary, tp_dist);

   req.type   = side;
   req.price  = 0.0;        // market entry on the breakout-bar close
   req.sl     = sl_price;
   req.tp     = tp_price;   // 0.0 if tp_dist invalid → no TP
   req.reason = "QM5_11429 london_box_breakout";

   g_traded_session = true; // latch: no re-entry this session even if closed early
   return true;
  }

// No active SL/TP management beyond the fixed exits (card P2 baseline). The card
// mentions an optional trailing stop as a P3 sweep dimension — OFF in baseline.
void Strategy_ManageOpenPosition()
  {
  }

// In-trade time stop: close any open position once the ET clock of the latest
// closed M5 bar reaches time_stop_et_hour (10:00 ET). Cheap O(1) read.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime bar_broker = iTime(_Symbol, PERIOD_M5, 0);  // current bar open, perf-allowed
   if(bar_broker <= 0)
      return false;
   const int hour_et = ETHour(BrokerBarToET(bar_broker));
   // From the time-stop hour (10:00 ET) onward, exit the position. A trade can
   // only have been opened in the [08:00,09:00) ET window, so this fires the same
   // session day before any next box window; the open-position gate above keeps
   // it a no-op once flat.
   return (hour_et >= time_stop_et_hour);
  }

// Defer to the central two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
