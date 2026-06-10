#property strict
#property version   "5.0"
#property description "QM5_9414 PAQ Doji Exhaustion Reversal — H1 candlestick pattern"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_9414 mql5-paq-doji
// Card:   D:\QM\strategy_farm\artifacts\cards_approved\QM5_9414_mql5-paq-doji.md
// Source: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
//
// Signal: Doji at bar[2] after 3 consecutive trend bars, confirmed when bar[1]
//         closes above Doji high (buy) or below Doji low (sell).
// Exits:  1.5R TP (SL/TP at framework level) | opposite confirmed Doji |
//         price crosses Doji midpoint intrabar | 18-H1-bar time stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9414;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input double strategy_doji_body_ratio    = 0.10;   // max body/totalRange for Doji (card default 0.10)
input int    strategy_atr_period         = 14;     // ATR period for range filter and stop sizing
input double strategy_atr_range_min_mult = 0.50;   // skip Doji when totalRange < mult*ATR
input double strategy_atr_sl_mult        = 0.25;   // SL = Doji extreme +/- mult*ATR
input double strategy_tp_r_mult          = 1.50;   // TP distance in multiples of initial risk
input int    strategy_max_hold_bars      = 18;     // time exit after N H1 bars (server-time approx)

// ----------------------------------------------------------------------------
// Per-position cached state — reset when no matching position is open
// ----------------------------------------------------------------------------
double   g_doji_mid       = 0.0;   // midpoint of the entry Doji bar
int      g_pos_type       = -1;    // -1=none  0=POSITION_TYPE_BUY  1=POSITION_TYPE_SELL
datetime g_entry_time     = 0;     // server time at entry (for 18-bar time stop)
bool     g_exit_requested = false; // deferred opposite-Doji exit signal

// ----------------------------------------------------------------------------
// Detect whether the bar at [shift] qualifies as a Doji.
// Called only from Strategy_EntrySignal, which is gated by QM_IsNewBar().
// ----------------------------------------------------------------------------
bool DetectDoji(const int shift,
                double &out_high, double &out_low, double &out_mid)
  {
   // perf-allowed: OHLC reads for bespoke candlestick structural logic (once per new bar)
   const double op  = iOpen (_Symbol, PERIOD_CURRENT, shift); // perf-allowed
   const double hi  = iHigh (_Symbol, PERIOD_CURRENT, shift); // perf-allowed
   const double lo  = iLow  (_Symbol, PERIOD_CURRENT, shift); // perf-allowed
   const double cl  = iClose(_Symbol, PERIOD_CURRENT, shift); // perf-allowed

   if(hi <= lo || op <= 0.0 || cl <= 0.0)
      return false;

   const double body        = MathAbs(cl - op);
   const double upper_wick  = hi - MathMax(cl, op);
   const double lower_wick  = MathMin(cl, op) - lo;
   const double total_range = hi - lo;

   // ATR at shift=1 (just-closed bar) from pooled handle
   const double atr14 = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr14 <= 0.0)
      return false;

   // micro-Doji filter: totalRange must be at least atr_range_min_mult * ATR
   if(total_range < strategy_atr_range_min_mult * atr14)
      return false;
   // body-ratio gate: body must be <= doji_body_ratio * totalRange
   if(body > total_range * strategy_doji_body_ratio)
      return false;
   // both wicks must strictly exceed the body
   if(upper_wick <= body || lower_wick <= body)
      return false;

   out_high = hi;
   out_low  = lo;
   out_mid  = (hi + lo) * 0.5;
   return true;
  }

// ----------------------------------------------------------------------------
// Strategy hooks
// ----------------------------------------------------------------------------

// No Trade Filter: no session or regime gate for this card.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: closed-bar Doji + trend + confirmation pattern.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type              = QM_BUY;
   req.price             = 0.0;
   req.sl                = 0.0;
   req.tp                = 0.0;
   req.reason            = "";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         has_pos = true;
         break;
        }
     }

   // Detect Doji at bar[2]: the potential reversal bar
   double doji_h, doji_l, doji_m;
   if(!DetectDoji(2, doji_h, doji_l, doji_m))
      return false;

   // perf-allowed: raw close reads for 3-bar trend context + confirmation (once per new bar)
   const double conf_close = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double c3         = iClose(_Symbol, PERIOD_CURRENT, 3); // perf-allowed
   const double c4         = iClose(_Symbol, PERIOD_CURRENT, 4); // perf-allowed
   const double c5         = iClose(_Symbol, PERIOD_CURRENT, 5); // perf-allowed

   if(conf_close <= 0.0 || c3 <= 0.0 || c4 <= 0.0 || c5 <= 0.0)
      return false;

   // 3 consecutive lower closes preceding Doji: c5 > c4 > c3 (downtrend)
   const bool trend_down = (c4 < c5) && (c3 < c4);
   // 3 consecutive higher closes preceding Doji: c5 < c4 < c3 (uptrend)
   const bool trend_up   = (c4 > c5) && (c3 > c4);

   // Confirmation: bar[1] breaks out of the Doji range in trend-reversal direction
   const bool buy_signal  = trend_down && (conf_close > doji_h);
   const bool sell_signal = trend_up   && (conf_close < doji_l);

   // Opposite-Doji exit: if holding a position and opposite signal fires, defer close
   if(has_pos && g_pos_type >= 0)
     {
      if((g_pos_type == 0 && sell_signal) || (g_pos_type == 1 && buy_signal))
        {
         g_exit_requested = true;
         return false;
        }
     }

   if(has_pos)
      return false;   // one open position per magic

   const double atr14 = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr14 <= 0.0 || point <= 0.0)
      return false;

   if(buy_signal)
     {
      const double entry    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0) return false;
      const double sl       = doji_l - strategy_atr_sl_mult * atr14;
      if(entry <= sl)  return false;   // price already below stop (malformed)
      const double tp       = entry + strategy_tp_r_mult * (entry - sl);

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "PAQ_DOJI_BUY";

      g_doji_mid   = doji_m;
      g_pos_type   = 0;
      g_entry_time = TimeCurrent();
      return true;
     }

   if(sell_signal)
     {
      const double entry    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return false;
      const double sl       = doji_h + strategy_atr_sl_mult * atr14;
      if(entry >= sl)  return false;   // price already above stop (malformed)
      const double tp       = entry - strategy_tp_r_mult * (sl - entry);

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "PAQ_DOJI_SELL";

      g_doji_mid   = doji_m;
      g_pos_type   = 1;
      g_entry_time = TimeCurrent();
      return true;
     }

   return false;
  }

// Trade Management: 1.5R TP is handled via req.tp at entry; no additional trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: time stop, midpoint cross, and deferred opposite-Doji signal.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         has_pos = true;
         break;
        }
     }

   if(!has_pos)
     {
      // Reset cached state whenever no position is held under our magic
      g_pos_type       = -1;
      g_doji_mid       = 0.0;
      g_entry_time     = 0;
      g_exit_requested = false;
      return false;
     }

   // a) Deferred opposite-Doji exit (set by EntrySignal on the new-bar tick)
   if(g_exit_requested)
     {
      g_exit_requested = false;
      return true;
     }

   // b) Time stop: exit after approx strategy_max_hold_bars H1 bars (server-time)
   if(g_entry_time > 0 &&
      TimeCurrent() >= g_entry_time + (datetime)(strategy_max_hold_bars * 3600))
      return true;

   // c) Doji midpoint cross: exit if price trades back through midpoint against trade
   if(g_doji_mid > 0.0)
     {
      if(g_pos_type == 0)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && bid < g_doji_mid)
            return true;
        }
      else if(g_pos_type == 1)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && ask > g_doji_mid)
            return true;
        }
     }

   return false;
  }

// News Filter Hook: defer to framework QM_NewsAllowsTrade2 via FW1 axis params.
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
