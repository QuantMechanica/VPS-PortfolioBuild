#property strict
#property version   "5.0"
#property description "QM5_11004 the5ers-ema-rsi-pullback — EMA9/20 trend + RSI pullback (two-sided, M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11004 the5ers-ema-rsi-pullback
// -----------------------------------------------------------------------------
// Source: The5ers blog "Your Forex Playbook: Short-Term Trading Strategies".
// Card: artifacts/cards_approved/QM5_11004_the5ers-ema-rsi-pullback.md
//       (g0_status APPROVED, source_id 1d445184-7c47-57da-9856-a123682a932d).
//
// Mechanics (two-sided, closed-bar reads at shift 1/2):
//   Long entry on a closed M15 bar when:
//     EMA(fast)[1] > EMA(slow)[1]   (bullish stack STATE)
//     close[1]     > EMA(slow)[1]   (price above slow EMA STATE)
//     RSI[2] < rsi_lo  AND  RSI[1] >= rsi_lo  (oversold-recovery EVENT)
//     no open position under this magic
//   Short entry is the symmetric port:
//     EMA(fast)[1] < EMA(slow)[1]
//     close[1]     < EMA(slow)[1]
//     RSI[2] > rsi_hi  AND  RSI[1] <= rsi_hi  (overbought-recovery EVENT)
//     no open position under this magic
//
//   Stop loss  : fixed sl_pips (scale-correct pips→price via QM_StopFixedPips).
//   Take profit: fixed tp_pips (QM_TakeFixedPips); default 40 = 2R on 20-pip SL.
//   Early exit : EMA(fast) crosses against EMA(slow) (one event at shift 1).
//   Time stop  : close after time_stop_bars closed M15 bars in the position.
//   Session    : only trade entries inside [session_start_h, session_end_h)
//                broker time (TimeCurrent() is broker time in the tester).
//   Spread     : skip a genuinely wide spread > spread_pct_of_stop of the SL
//                distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11004;
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
input int    strategy_ema_fast_period    = 9;      // fast EMA (trend filter)
input int    strategy_ema_slow_period    = 20;     // slow EMA (trend filter)
input int    strategy_rsi_period         = 14;     // RSI lookback period
input double strategy_rsi_lo             = 30.0;   // long trigger: RSI recovers up through this
input double strategy_rsi_hi             = 70.0;   // short trigger: RSI recovers down through this
input int    strategy_sl_pips            = 20;     // stop-loss distance in pips
input int    strategy_tp_pips            = 40;     // take-profit distance in pips
input int    strategy_time_stop_bars     = 32;     // close after this many closed M15 bars
input int    strategy_session_start_h    = 6;      // earliest entry hour, broker time (inclusive)
input int    strategy_session_end_h      = 20;     // latest entry hour, broker time (exclusive)
input double strategy_spread_pct_of_stop = 10.0;   // skip if spread > this % of SL distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
// Session and signal logic live on the closed-bar entry path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // SL distance reference for the spread cap (fixed pips → price distance).
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Two-sided entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // --- Session filter: only enter inside [start, end) broker-time hours. ---
   // EntrySignal is called only after the framework new-bar gate, so this is
   // deterministic per bar without maintaining a local timestamp gate.
   const datetime bar_open = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   if(dt.hour < strategy_session_start_h || dt.hour >= strategy_session_end_h)
      return false;

   // --- EMA stack STATE (closed bar, shift 1). ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const int price_vs_slow = QM_Sig_Price_Above_MA(_Symbol, _Period, strategy_ema_slow_period, 0.0, 1);

   // --- RSI recovery EVENT (shift 2 outside the band, shift 1 back inside). ---
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   bool is_long  = false;
   bool is_short = false;

   // Long: bullish stack + price above slow EMA + RSI recovers up through lo.
   if(ema_fast > ema_slow && price_vs_slow > 0 &&
      rsi_prev < strategy_rsi_lo && rsi_now >= strategy_rsi_lo)
      is_long = true;

   // Short: bearish stack + price below slow EMA + RSI recovers down through hi.
   if(ema_fast < ema_slow && price_vs_slow < 0 &&
      rsi_prev > strategy_rsi_hi && rsi_now <= strategy_rsi_hi)
      is_short = true;

   if(!is_long && !is_short)
      return false;

   const QM_OrderType side = is_long ? QM_BUY : QM_SELL;

   const double entry = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;   // framework fills market price at send
   req.sl = sl;
   req.tp = tp;
   req.reason = is_long ? "ema_rsi_pb_long" : "ema_rsi_pb_short";
   return true;
  }

// No active SL/TP trade management beyond the fixed stop/target. The time-stop
// and EMA-cross exit live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: (a) time stop after time_stop_bars closed M15 bars, or
// (b) EMA(fast) crosses against EMA(slow) relative to the open side.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Locate this EA's open position to read its side + open time.
   bool   have_pos    = false;
   bool   pos_is_long = false;
   datetime pos_open  = 0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      pos_open    = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos    = true;
      break;
     }
   if(!have_pos)
      return false;

   // --- Time stop: elapsed closed M15 bars >= time_stop_bars. ---
   const int period_seconds = PeriodSeconds(_Period);
   if(period_seconds > 0 && pos_open > 0)
     {
      const int bars_elapsed = (int)((TimeCurrent() - pos_open) / period_seconds);
      if(bars_elapsed >= strategy_time_stop_bars)
         return true;
     }

   // --- Defensive exit: EMA(fast) crosses against EMA(slow), shift 1 event. ---
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   if(pos_is_long)
     {
      // Long closes when fast crosses below slow.
      if(fast_prev >= slow_prev && fast_now < slow_now)
         return true;
     }
   else
     {
      // Short closes when fast crosses above slow.
      if(fast_prev <= slow_prev && fast_now > slow_now)
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
