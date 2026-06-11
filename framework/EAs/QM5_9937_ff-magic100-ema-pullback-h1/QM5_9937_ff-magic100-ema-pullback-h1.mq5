#property strict
#property version   "5.0"
#property description "QM5_9937 ForexFactory Magic 100 EMA Pullback H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9937 ff-magic100-ema-pullback-h1
// Source: Minotawr, Magic 100, ForexFactory 2020 (see SPEC.md § 6 for URL)
// Card:   artifacts/cards_approved/QM5_9937_ff-magic100-ema-pullback-h1.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9937;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period        = 100;    // EMA period
input int    strategy_atr_period        = 14;     // ATR period for sizing + filters
input int    strategy_slope_bars        = 10;     // Bars for EMA slope measurement
input double strategy_slope_min_atr    = 0.15;   // Min EMA slope in ATR units
input double strategy_entry_buffer_atr = 0.05;   // Offset beyond candle edge for stop entry
input double strategy_sl_buffer_atr    = 0.05;   // Offset beyond candle edge for initial SL
input double strategy_max_risk_atr     = 1.8;    // Skip trade if risk > this * ATR
input double strategy_tp_r             = 2.5;    // Take-profit in R multiples
input int    strategy_expiry_bars      = 8;      // Cancel pending after this many H1 bars

// File-scope: pending stop order state (reset when filled or cancelled)
ulong  g_pending_ticket  = 0;
bool   g_pending_is_long = false;
int    g_pending_bars    = 0;
double g_pending_entry   = 0.0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

bool HasOurPendingOrder()
  {
   if(g_pending_ticket == 0)
      return false;
   if(!OrderSelect(g_pending_ticket))
     {
      g_pending_ticket = 0;  // Order was filled or cancelled externally
      return false;
     }
   return true;
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

bool PlacePendingStop(const bool   is_long,
                      const double entry_price,
                      const double sl_price,
                      const double tp_price,
                      const string reason)
  {
   QM_EntryRequest req;
   req.type               = is_long ? QM_BUY_STOP : QM_SELL_STOP;
   req.price              = entry_price;
   req.sl                 = sl_price;
   req.tp                 = tp_price;
   req.reason             = reason;
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   const bool ok = QM_TM_OpenPosition(req, ticket);
   if(ok && ticket > 0)
     {
      g_pending_ticket  = ticket;
      g_pending_is_long = is_long;
      g_pending_bars    = 0;
      g_pending_entry   = entry_price;
     }
   return ok;
  }

// Read single closed-bar OHLC and check trend conditions, then place pending stop.
// Perf-allowed: single-bar iOpen/iClose/iHigh/iLow reads for candle-type detection.
void TryNewEntry()
  {
   const double atr     = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double ema_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   const double ema_old = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period,
                                 1 + strategy_slope_bars);
   if(atr <= 0.0 || ema_now <= 0.0 || ema_old <= 0.0)
      return;

   const double slope     = ema_now - ema_old;
   const double min_slope = strategy_slope_min_atr * atr;
   const double entry_buf = strategy_entry_buffer_atr * atr;
   const double sl_buf    = strategy_sl_buffer_atr * atr;
   const double max_risk  = strategy_max_risk_atr * atr;

   const double open1  = iOpen(_Symbol,  PERIOD_H1, 1);  // perf-allowed: single closed-bar candle type check
   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed
   const double high1  = iHigh(_Symbol,  PERIOD_H1, 1); // perf-allowed
   const double low1   = iLow(_Symbol,   PERIOD_H1, 1); // perf-allowed
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return;

   // Long: uptrend gate, last candle bearish and fully above EMA100
   if(slope >= min_slope && close1 > ema_now && close1 < open1 && low1 > ema_now)
     {
      const double entry = high1 + entry_buf;
      const double sl    = low1  - sl_buf;
      const double risk  = entry - sl;
      if(risk > 0.0 && risk <= max_risk)
         PlacePendingStop(true, entry, sl, entry + strategy_tp_r * risk, "magic100_long");
      return;
     }

   // Short: downtrend gate, last candle bullish and fully below EMA100
   if(slope <= -min_slope && close1 < ema_now && close1 > open1 && high1 < ema_now)
     {
      const double entry = low1  - entry_buf;
      const double sl    = high1 + sl_buf;
      const double risk  = sl    - entry;
      if(risk > 0.0 && risk <= max_risk)
         PlacePendingStop(false, entry, sl, entry - strategy_tp_r * risk, "magic100_short");
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — framework handles news/Friday/kill-switch
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Called per new closed bar (OnTick already gated by QM_IsNewBar).
// We always return false and handle pending order placement ourselves
// so that QM_TM_OpenPosition tickets can be captured in g_pending_ticket.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type        = QM_BUY_STOP;
   req.price       = 0.0;
   req.sl          = 0.0;
   req.tp          = 0.0;
   req.reason      = "";
   req.symbol_slot = qm_magic_slot_offset;

   // 1. Manage existing pending stop order
   if(HasOurPendingOrder())
     {
      g_pending_bars++;

      const double atr     = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      const double ema_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
      const double ema_old = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period,
                                    1 + strategy_slope_bars);
      if(atr <= 0.0 || ema_now <= 0.0)
         return false;

      const double open1  = iOpen(_Symbol,  PERIOD_H1, 1);  // perf-allowed: single closed-bar candle type check
      const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed
      const double high1  = iHigh(_Symbol,  PERIOD_H1, 1); // perf-allowed
      const double low1   = iLow(_Symbol,   PERIOD_H1, 1); // perf-allowed

      // Cancellation: expiry or EMA cross
      bool cancel = (g_pending_bars >= strategy_expiry_bars);
      if(g_pending_is_long  && close1 < ema_now) cancel = true;
      if(!g_pending_is_long && close1 > ema_now) cancel = true;

      if(cancel)
        {
         QM_TM_RemovePendingOrder(g_pending_ticket, "cancel_expiry_or_ema_cross");
         g_pending_ticket = 0;
         return false;
        }

      // Update to a newer retracement candle if pullback has deepened
      const double slope     = ema_now - ema_old;
      const double min_slope = strategy_slope_min_atr * atr;
      const double entry_buf = strategy_entry_buffer_atr * atr;
      const double sl_buf    = strategy_sl_buffer_atr * atr;
      const double max_risk  = strategy_max_risk_atr * atr;

      if(close1 > 0.0 && open1 > 0.0 && high1 > 0.0 && low1 > 0.0)
        {
         if(g_pending_is_long && close1 < open1 && low1 > ema_now && slope >= min_slope)
           {
            const double new_entry = high1 + entry_buf;
            const double new_sl    = low1  - sl_buf;
            const double new_risk  = new_entry - new_sl;
            // Update only if deeper pullback (lower buy-stop price)
            if(new_entry < g_pending_entry && new_risk > 0.0 && new_risk <= max_risk)
              {
               QM_TM_RemovePendingOrder(g_pending_ticket, "update_pullback_long");
               g_pending_ticket = 0;
               PlacePendingStop(true, new_entry, new_sl,
                                new_entry + strategy_tp_r * new_risk,
                                "magic100_long_update");
              }
           }
         else if(!g_pending_is_long && close1 > open1 && high1 < ema_now && slope <= -min_slope)
           {
            const double new_entry = low1  - entry_buf;
            const double new_sl    = high1 + sl_buf;
            const double new_risk  = new_sl - new_entry;
            // Update only if deeper pullback (higher sell-stop price)
            if(new_entry > g_pending_entry && new_risk > 0.0 && new_risk <= max_risk)
              {
               QM_TM_RemovePendingOrder(g_pending_ticket, "update_pullback_short");
               g_pending_ticket = 0;
               PlacePendingStop(false, new_entry, new_sl,
                                new_entry - strategy_tp_r * new_risk,
                                "magic100_short_update");
              }
           }
        }
      return false;
     }

   // 2. Skip new entries when a position is already open
   if(HasOpenPosition())
      return false;

   // 3. Scan for a fresh entry setup
   TryNewEntry();
   return false;
  }

// Called every tick — move SL to breakeven when price reaches +1R
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double curr_sl    = PositionGetDouble(POSITION_SL);
      const ENUM_POSITION_TYPE ptype =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0) return;

      // Skip if SL already at or beyond breakeven
      if(ptype == POSITION_TYPE_BUY  && curr_sl >= open_price - point) return;
      if(ptype == POSITION_TYPE_SELL && curr_sl <= open_price + point) return;

      const double one_r = MathAbs(open_price - curr_sl);
      if(one_r < point) return;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(ptype == POSITION_TYPE_BUY && bid >= open_price + one_r)
         QM_TM_MoveSL(ticket, open_price, "be_1r");
      else if(ptype == POSITION_TYPE_SELL && ask <= open_price - one_r)
         QM_TM_MoveSL(ticket, open_price, "be_1r");

      return;  // One position per magic/symbol
     }
  }

// No discretionary exit — positions close via SL/TP/Friday-close
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to framework two-axis news filter
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line
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
