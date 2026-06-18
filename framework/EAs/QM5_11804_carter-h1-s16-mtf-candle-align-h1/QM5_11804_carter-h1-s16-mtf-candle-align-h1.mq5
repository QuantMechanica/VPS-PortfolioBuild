#property strict
#property version   "5.0"
#property description "QM5_11804 carter-h1-s16-mtf-candle-align-h1 — MTF 4-Candle Direction Alignment (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11804 carter-h1-s16-mtf-candle-align-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//   Strategy S16 (Scribd, ~2014). PDF 376863900-20-Forex-Trading-Strategies-
//   Collection.pdf. R1-R4 PASS per
//   artifacts/cards_approved/QM5_11804_carter-h1-s16-mtf-candle-align-h1.md
//   (g0_status APPROVED).
//
// Mechanics (all reads on CLOSED bars, shift 1, per timeframe):
//   Confluence STATE : the last completed candle on ALL FOUR timeframes
//                      (M5, M15, M30, H1) closes the SAME color — all bullish
//                      (close > open) or all bearish (close < open). Pure raw
//                      OHLC candle direction; no indicators. This four-timeframe
//                      agreement is a multi-timeframe momentum FILTER (a STATE).
//   Trigger  EVENT   : the H1 closed-bar gate (QM_IsNewBar on _Period == H1)
//                      fires exactly ONE event per H1 bar. On that single event
//                      we evaluate the confluence STATE and, if all four TFs
//                      agree, enter at market in the aligned direction. The card
//                      rule is literally "enter on H1 candle close" — the H1
//                      new-bar gate is that single event. One-position-per-magic
//                      prevents re-entry while the alignment persists across
//                      subsequent H1 bars, so the position is opened once and
//                      not stacked.
//   Direction        : all four bullish -> BUY ; all four bearish -> SELL.
//   Stop / Take      : factory translation per card Mechanik — SL = 2 x ATR(14),
//                      TP = 4 x ATR(14) on the SAME ATR value, via
//                      QM_StopATRFromValue / QM_TakeATRFromValue (scale-correct
//                      on 5-digit / JPY symbols). Source fixed-pip values
//                      (SL 20 / TP 30-40) are the discretionary origin; the
//                      factory uses the ATR translation the card specifies.
//   Exit             : positions close on the fixed ATR SL/TP. The card's
//                      "signal expires if H1 direction changes" is honoured by
//                      a defensive exit: when the H1 candle color flips against
//                      the open position, close manually.
//   Filters          : spread cap (fail-OPEN on .DWX zero modeled spread).
//   One open position per symbol/magic.
//
// Two-cross trap avoided: the four-TF alignment is a pure STATE, not an event;
// the single EVENT is the H1 new-bar gate. We never require two fresh crossover
// events on the same bar. The alignment is read once per closed H1 bar.
//
// HTF candle reads use bounded, closed-bar iClose/iOpen with an EXPLICIT TF —
// perf-allowed bespoke structural reads (no QM indicator helper exposes raw
// candle color), each a single shift-1 access, evaluated once per H1 closed bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11804;
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
// Four alignment timeframes (the 4-candle confluence STATE). strategy_tf_d is the
// H1 entry/trigger TF; it must match _Period when the EA runs on H1.
input ENUM_TIMEFRAMES strategy_tf_a       = PERIOD_M5;   // alignment TF 1
input ENUM_TIMEFRAMES strategy_tf_b       = PERIOD_M15;  // alignment TF 2
input ENUM_TIMEFRAMES strategy_tf_c       = PERIOD_M30;  // alignment TF 3
input ENUM_TIMEFRAMES strategy_tf_d       = PERIOD_H1;   // alignment + entry TF (H1)
input int    strategy_atr_period          = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult         = 2.0;    // stop distance = mult * ATR (card: 2xATR)
input double strategy_tp_atr_mult         = 4.0;    // target distance = mult * ATR (card: 4xATR)
input double strategy_spread_cap_pips     = 15.0;   // skip if genuine spread wider than this (pips)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Candle color of the last completed bar on a given TF.
//   +1 bullish (close > open), -1 bearish (close < open), 0 doji/no-data.
// perf-allowed: single closed-bar (shift 1) raw OHLC read per TF — no QM helper
// exposes raw candle color, and this is bounded structural logic gated to the
// H1 new-bar path (evaluated once per closed H1 bar).
int CandleColor(const ENUM_TIMEFRAMES tf)
  {
   const double o = iOpen(_Symbol, tf, 1);   // perf-allowed: closed-bar candle color
   const double c = iClose(_Symbol, tf, 1);  // perf-allowed: closed-bar candle color
   if(o <= 0.0 || c <= 0.0)
      return 0;
   if(c > o)
      return 1;
   if(c < o)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-OPEN on .DWX zero spread).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Convert the pip cap to a price distance (scale-correct on 5-digit / JPY).
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(cap_distance > 0.0 && spread > 0.0 && spread > cap_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true on H1 (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Confluence STATE: all FOUR alignment TFs same color (closed bars) ---
   const int col_a = CandleColor(strategy_tf_a);
   const int col_b = CandleColor(strategy_tf_b);
   const int col_c = CandleColor(strategy_tf_c);
   const int col_d = CandleColor(strategy_tf_d);
   if(col_a == 0 || col_b == 0 || col_c == 0 || col_d == 0)
      return false;
   if(!(col_a == col_b && col_b == col_c && col_c == col_d))
      return false;
   const int align_dir = col_a; // +1 all four bullish, -1 all four bearish

   // --- ATR for the fixed stop/target (same ATR value for SL and TP) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const QM_OrderType order_type = (align_dir > 0 ? QM_BUY : QM_SELL);
   const double entry = (align_dir > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, order_type, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, order_type, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = order_type;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (align_dir > 0 ? "mtf4_align_long" : "mtf4_align_short");
   return true;
  }

// Fixed ATR SL/TP only; no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: card "signal expires if H1 candle direction changes". Close
// the open position when the just-completed H1 candle flips against it.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int h1_color = CandleColor(strategy_tf_d); // H1 closed-bar direction
   if(h1_color == 0)
      return false;

   // Determine the side of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY  && h1_color < 0)
         return true; // long held, H1 turned bearish -> exit
      if(pos_type == POSITION_TYPE_SELL && h1_color > 0)
         return true; // short held, H1 turned bullish -> exit
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
