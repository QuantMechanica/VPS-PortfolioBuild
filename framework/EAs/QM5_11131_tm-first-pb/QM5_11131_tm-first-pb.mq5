#property strict
#property version   "5.0"
#property description "QM5_11131 TradingMarkets First Pullback Index Limit (tm-first-pb)"
// Strategy Card: QM5_11131 (tm-first-pb), G0 APPROVED 2026-05-22.
// Source: Matt Radtke, "Learning From The First Pullback Strategy", TradingMarkets 2013.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — TradingMarkets First Pullback (long-only, D1)
// -----------------------------------------------------------------------------
// Mechanik (card §Mechanik):
//   Setup (evaluated on the D1 close): a strong multi-horizon uptrend showing
//   its first short-term pullback —
//     close[1] > SMA200 & > SMA100 & > SMA50 & > SMA20   (trend stack)
//     close[1] < SMA5                                     (first pullback)
//   Entry: place a BUY LIMIT X% below the setup close (ATR proxy for non-US
//   index CFDs); cancel the pending order after Y D1 bars if unfilled.
//   Exit: close above SMA5, or a 2.5*ATR(14) protective stop, or a time exit
//   after N D1 bars.
//
// Framework corset: only the five Strategy_* hooks + inputs are author code.
// All indicator reads go through QM_* pooled readers; closed-bar "close" is
// read as QM_SMA(.,1,1) to avoid a raw iClose call. iBarShift is used only for
// bar-age (time-exit / pending-expiry) and is not a forbidden series reader.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11131;
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
// Trend stack (card: close > SMA200/100/50/20).
input int    trend_sma_anchor           = 200;   // long-horizon trend filter
input int    trend_sma_slow             = 100;
input int    trend_sma_mid              = 50;
input int    trend_sma_fast             = 20;
// First-pullback / exit MA (card: close < SMA5 to set up; close > SMA5 to exit).
input int    pullback_sma               = 5;
// Limit-entry depth below the setup close.
input bool   entry_limit_use_atr        = false;  // false: % below (US indices); true: ATR proxy (non-US)
input double entry_limit_pct            = 4.0;     // card baseline X=4% for SP500/NDX/WS30
input double entry_limit_atr_mult       = 1.0;     // card baseline X=1.0*ATR(14) for non-US CFDs (e.g. GDAXI)
input int    entry_atr_period           = 14;      // ATR period for limit proxy + protective stop
input int    entry_limit_valid_bars     = 3;       // Y: cancel unfilled limit after N D1 bars
// Protective stop + time exit.
input double stop_atr_mult              = 2.5;     // card: 2.5*ATR(14) protective stop
input int    max_hold_bars              = 7;       // card: time exit after N D1 bars

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): the limit is placed below market on the
// D1 close, so intraday spread at placement is not binding for this strategy.
// News + Friday-close are handled by the framework wiring in OnTick. O(1).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// True when this EA already has an open position OR a working pending limit on
// the current symbol/magic — enforces "one active position per symbol/magic"
// and prevents stacking duplicate limit orders while one is still working.
bool TmHasOpenOrPending()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;   // fail-closed: no valid magic -> do not place orders

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         return true;
     }

   return false;
  }

// Trade Entry: build the BUY LIMIT request when the trend-stack + first-pullback
// setup prints on the just-closed D1 bar. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY_LIMIT;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "tm_first_pb_long_limit";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;   // GTC; aged-out manually in Strategy_ManageOpenPosition

   if(TmHasOpenOrPending())
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_D1;

   // Closed-bar close read as SMA(1) to stay inside the framework readers.
   const double close1 = QM_SMA(_Symbol, tf, 1, 1);
   const double sma_a  = QM_SMA(_Symbol, tf, trend_sma_anchor, 1);
   const double sma_s  = QM_SMA(_Symbol, tf, trend_sma_slow, 1);
   const double sma_m  = QM_SMA(_Symbol, tf, trend_sma_mid, 1);
   const double sma_f  = QM_SMA(_Symbol, tf, trend_sma_fast, 1);
   const double sma_p  = QM_SMA(_Symbol, tf, pullback_sma, 1);

   // Skip if any MA history is unavailable (card filter).
   if(close1 <= 0.0 || sma_a <= 0.0 || sma_s <= 0.0 || sma_m <= 0.0 ||
      sma_f <= 0.0 || sma_p <= 0.0)
      return false;

   // Trend stack: strong multi-horizon uptrend.
   if(!(close1 > sma_a && close1 > sma_s && close1 > sma_m && close1 > sma_f))
      return false;

   // First short-term pullback: close back below the fast MA.
   if(!(close1 < sma_p))
      return false;

   // Limit depth below the setup close.
   double limit_price = 0.0;
   if(entry_limit_use_atr)
     {
      const double atr = QM_ATR(_Symbol, tf, entry_atr_period, 1);
      if(atr <= 0.0)
         return false;
      limit_price = close1 - entry_limit_atr_mult * atr;
     }
   else
     {
      if(entry_limit_pct <= 0.0)
         return false;
      limit_price = close1 * (1.0 - entry_limit_pct / 100.0);
     }
   if(limit_price <= 0.0)
      return false;

   // Protective stop: 2.5*ATR(14) below the limit price.
   const double atr_sl = QM_ATR(_Symbol, tf, entry_atr_period, 1);
   if(atr_sl <= 0.0)
      return false;
   const double sl = limit_price - stop_atr_mult * atr_sl;
   if(sl <= 0.0 || sl >= limit_price)
      return false;

   req.price = limit_price;
   req.sl    = sl;
   req.tp    = 0.0;   // card: exit by close>SMA5 / time-exit / protective stop
   return true;
  }

// Trade Management: age out an unfilled BUY LIMIT after Y D1 bars (card: cancel
// the limit when Y bars expire). No trailing / break-even / partials in the
// baseline. Cheap: early-returns when no pending order is working.
void Strategy_ManageOpenPosition()
  {
   if(OrdersTotal() <= 0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_LIMIT)
         continue;

      const datetime setup_t = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      const int age_bars = iBarShift(_Symbol, PERIOD_D1, setup_t, false);
      if(age_bars >= entry_limit_valid_bars)
         QM_TM_RemovePendingOrder(t, "tm_first_pb_limit_expired");
     }
  }

// Trade Close: discretionary exit — close above SMA5, or time exit after N D1
// bars. The protective 2.5*ATR stop on the order handles adverse moves.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   datetime open_time = 0;
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_position = true;
      break;
     }
   if(!have_position)
      return false;

   // Exit: close back above the fast MA (card baseline exit).
   const double close1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1);
   const double sma_p  = QM_SMA(_Symbol, PERIOD_D1, pullback_sma, 1);
   if(close1 > 0.0 && sma_p > 0.0 && close1 > sma_p)
      return true;

   // Time exit after N D1 bars in the trade.
   const int held_bars = iBarShift(_Symbol, PERIOD_D1, open_time, false);
   if(held_bars >= max_hold_bars)
      return true;

   return false;
  }

// News Filter Hook (callable for Q09 News Impact phase): defer to the central
// two-axis framework filter. Return TRUE here only for bespoke overrides.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11131_tm-first-pb\"}");
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

   // Per-tick: trade management (pending-order aging for this strategy).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (close>SMA5 / time-exit). Separate from SL.
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

   // Per-closed-bar: entry-signal evaluation.
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
