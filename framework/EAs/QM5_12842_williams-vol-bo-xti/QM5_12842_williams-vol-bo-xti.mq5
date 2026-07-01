#property strict
#property version   "5.0"
#property description "QM5_12842 Williams Volatility Breakout WTI (SRC03)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12842 — Williams Prior-Range Volatility Breakout, WTI (XTIUSD.DWX D1)
// Source: SRC03 — Williams, L.R. (1999). Long-Term Secrets to Short-Term Trading.
// Card: QM5_12842_williams-vol-bo-xti_card.md | G0 APPROVED 2026-07-01
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12842;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                  = 336;
input string qm_news_min_impact                       = "high";
input QM_NewsMode qm_news_mode_legacy                 = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_range_mult         = 0.75;   // prior-range mult for buy-stop offset above open
input double strategy_min_range_atr      = 0.35;   // skip if prior_range < X * ATR; 0 = disabled
input int    strategy_atr_period         = 20;     // ATR period for range floor and stop sizing
input double strategy_atr_sl_mult        = 2.5;    // SL = entry - ATR * mult
input double strategy_take_rr            = 2.0;    // TP = entry + take_rr * SL_dist; 0 = none
input int    strategy_order_expiry_hours = 20;     // pending buy-stop expires after N hours
input int    strategy_max_hold_days      = 5;      // close open position after N calendar days
input int    strategy_max_spread_points  = 1000;   // skip entry if bid-ask spread > N points

// ---------------------------------------------------------------------------
// Helpers: check for existing position or pending order for this EA's magic
// ---------------------------------------------------------------------------

bool HasOpenPositionForMagic()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool HasPendingOrderForMagic()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong t = OrderGetTicket(i);
      if(!OrderSelect(t))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

// No additional pre-filter needed; entry guards live in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// On each new D1 bar: place a pending buy-stop if conditions are met.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Guard: no duplicate position or pending order
   if(HasOpenPositionForMagic() || HasPendingOrderForMagic())
      return false;

   // Spread guard (DWX spread = 0 in backtest; guard for live; never block on zero spread)
   const double ask_px = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid_px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask_px > 0 && bid_px > 0 && ask_px > bid_px)
     {
      const double spread_cap = strategy_max_spread_points * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if((ask_px - bid_px) > spread_cap)
         return false;
     }

   // D1 OHLC reads — perf-allowed: single-shift reads, gated by QM_IsNewBar
   const double d1_open    = iOpen(_Symbol, PERIOD_D1, 0);   // perf-allowed
   const double prior_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed
   const double prior_low  = iLow(_Symbol, PERIOD_D1, 1);    // perf-allowed

   if(d1_open <= 0.0 || prior_high <= 0.0 || prior_low <= 0.0)
      return false;

   const double prior_range = prior_high - prior_low;
   if(prior_range <= 0.0)
      return false;

   // ATR at last closed bar for range-floor check and stop sizing
   const double atr_val = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   // Skip small-range (holiday / truncated) bars
   if(strategy_min_range_atr > 0.0 && prior_range < strategy_min_range_atr * atr_val)
      return false;

   // Pending buy-stop trigger price
   const double entry_price = d1_open + strategy_range_mult * prior_range;
   if(entry_price <= 0.0)
      return false;

   // Stop loss: ATR * mult below entry
   const double sl_price = entry_price - strategy_atr_sl_mult * atr_val;
   if(sl_price <= 0.0 || sl_price >= entry_price)
      return false;

   // Take profit: RR multiple of SL distance above entry (0 = disabled)
   const double rr_dist  = entry_price - sl_price;
   const double tp_price = (strategy_take_rr > 0.0) ? entry_price + strategy_take_rr * rr_dist : 0.0;

   req.type               = QM_BUY_STOP;
   req.price              = entry_price;
   req.sl                 = sl_price;
   req.tp                 = tp_price;
   req.reason             = "SRC03_WILLIAMS_VOL_BO";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = strategy_order_expiry_hours * 3600;

   return true;
  }

// Per-tick: enforce max-hold-days time stop on open positions.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_days = (int)((now - open_time) / 86400);
      if(held_days >= strategy_max_hold_days)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

// No additional discretionary exit; SL/TP and max-hold in ManageOpenPosition.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer news filtering entirely to framework axes.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Framework wiring — do not edit below this line.
// ---------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC03_S01_XTI_20260701\",\"ea\":\"QM5_12842_williams-vol-bo-xti\"}");
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
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
