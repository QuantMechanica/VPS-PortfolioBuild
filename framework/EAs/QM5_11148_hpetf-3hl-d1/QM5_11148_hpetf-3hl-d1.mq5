#property strict
#property version   "5.0"
#property description "QM5_11148 hpetf-3hl-d1 — Connors HPETF 3-Day High/Low Pullback (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11148 hpetf-3hl-d1
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "High Probability ETF Trading" (2009).
// Card: artifacts/cards_approved/QM5_11148_hpetf-3hl-d1.md (g0_status APPROVED).
//
// Trend-aligned ETF mean reversion on D1 index CFDs. All reads are closed bars
// (shift 1 = last closed bar). The "three-day high/low pullback" primitive uses
// the consecutive lower-high/lower-low (long) or higher-high/higher-low (short)
// sequence over the last three closed bars — NOT a gap rule, so it is valid on
// gapless .DWX CFDs.
//
// Mechanics (long; short is the mirror):
//   Trend STATE   : Close[1] > SMA(200)[1].
//   Setup  STATE  : Close[1] < SMA(5)[1] (short-term exhaustion below the 5-MA).
//   3HL    STATE  : For the last three closed bars each bar's high AND low is
//                   below the prior bar's high AND low:
//                     high[1]<high[2] && low[1]<low[2]
//                     high[2]<high[3] && low[2]<low[3]
//                     high[3]<high[4] && low[3]<low[4]
//   Entry         : market BUY at next D1 open (req.price=0 → fill at send).
//   Stop          : entry - sl_atr_mult * ATR(atr_period) (card: 3.0 * ATR(14)).
//   Exit (signal) : Close[1] > SMA(5)[1]  (long) — mean-reversion target hit.
//   Time-stop     : exit after time_stop_bars closed D1 bars in the position.
//   Spread guard  : skip only a genuinely wide spread > spread_pct_of_atr of
//                   ATR (fail-open on .DWX zero modeled spread).
//
// Short mirror: Close[1]<SMA(200), Close[1]>SMA(5), higher-high/higher-low 3-seq,
// stop = entry + mult*ATR, exit when Close[1] < SMA(5)[1].
//
// One position per magic. Source aggressive add-unit is omitted (baseline).
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11148;
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
input int    strategy_sma_trend_period  = 200;   // long-term trend gate SMA
input int    strategy_sma_exit_period   = 5;     // short-term mean-reversion SMA (entry+exit)
input int    strategy_atr_period        = 14;    // ATR period for the hard stop
input double strategy_sl_atr_mult       = 3.0;   // stop distance = mult * ATR (card: 3.0)
input int    strategy_time_stop_bars    = 10;    // exit after N closed D1 bars in trade
input double strategy_spread_pct_of_atr = 25.0;  // skip if spread > this % of ATR (card: 0.25*ATR)
input bool   strategy_allow_long        = true;  // enable long (above-200 mean reversion)
input bool   strategy_allow_short       = true;  // enable short mirror (below-200)

// File-scope: closed-bar count at which the currently-open position was entered.
// Used by the time-stop. Advanced/seeded on the closed-bar gate only.
int    g_entry_bar_count = -1;
int    g_bar_count       = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — all signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_atr / 100.0) * atr_value)
      return true;

   return false;
  }

// Trend-aligned 3-day high/low pullback entry. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate). One position per magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double sma_trend = QM_SMA(_Symbol, _Period, strategy_sma_trend_period, 1);
   const double sma_exit  = QM_SMA(_Symbol, _Period, strategy_sma_exit_period, 1);
   if(sma_trend <= 0.0 || sma_exit <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Four closed-bar highs/lows for the three consecutive comparisons.
   // perf-allowed: bounded single closed-bar OHLC reads (structural sequence).
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double h2 = iHigh(_Symbol, _Period, 2);
   const double h3 = iHigh(_Symbol, _Period, 3);
   const double h4 = iHigh(_Symbol, _Period, 4);
   const double l1 = iLow(_Symbol, _Period, 1);
   const double l2 = iLow(_Symbol, _Period, 2);
   const double l3 = iLow(_Symbol, _Period, 3);
   const double l4 = iLow(_Symbol, _Period, 4);
   if(h1 <= 0.0 || h2 <= 0.0 || h3 <= 0.0 || h4 <= 0.0 ||
      l1 <= 0.0 || l2 <= 0.0 || l3 <= 0.0 || l4 <= 0.0)
      return false;

   // --- LONG: above-200 mean reversion ---
   if(strategy_allow_long &&
      close1 > sma_trend &&            // trend STATE
      close1 < sma_exit)               // short-term exhaustion below SMA(5)
     {
      const bool three_lower =
         (h1 < h2 && l1 < l2) &&
         (h2 < h3 && l2 < l3) &&
         (h3 < h4 && l3 < l4);
      if(three_lower)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
         if(sl <= 0.0)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = 0.0;   // exit is SMA(5)-cross / time-stop, not a fixed TP
         req.reason = "hpetf_3hl_long";
         return true;
        }
     }

   // --- SHORT: below-200 mirror ---
   if(strategy_allow_short &&
      close1 < sma_trend &&
      close1 > sma_exit)
     {
      const bool three_higher =
         (h1 > h2 && l1 > l2) &&
         (h2 > h3 && l2 > l3) &&
         (h3 > h4 && l3 > l4);
      if(three_higher)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
         if(sl <= 0.0)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = 0.0;
         req.reason = "hpetf_3hl_short";
         return true;
        }
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop. The SMA(5) target and
// the time-stop live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: SMA(5) mean-reversion target reached, or time-stop exceeded.
// Evaluated on the closed-bar path (OnTick gates exit before the new-bar gate,
// but these reads are all closed-bar shift-1 values so they are stable per bar).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_entry_bar_count = -1; // no position — reset the entry marker
      return false;
     }

   // Determine the open position's direction for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   // First time we see this position, seed the entry bar marker.
   if(g_entry_bar_count < 0)
      g_entry_bar_count = g_bar_count;

   // Time-stop: closed bars held since entry.
   if(strategy_time_stop_bars > 0 &&
      (g_bar_count - g_entry_bar_count) >= strategy_time_stop_bars)
      return true;

   // SMA(5) mean-reversion target.
   const double close1  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double sma_exit = QM_SMA(_Symbol, _Period, strategy_sma_exit_period, 1);
   if(close1 <= 0.0 || sma_exit <= 0.0)
      return false;

   if(is_long  && close1 > sma_exit)
      return true;
   if(is_short && close1 < sma_exit)
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

   g_entry_bar_count = -1;
   g_bar_count       = 0;
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
      g_entry_bar_count = -1; // position closed — reset marker
     }

   if(!QM_IsNewBar())
      return;

   // Advance the closed-bar counter ONCE per new closed bar (time-stop clock).
   g_bar_count++;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         g_entry_bar_count = g_bar_count; // mark entry bar for the time-stop
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
