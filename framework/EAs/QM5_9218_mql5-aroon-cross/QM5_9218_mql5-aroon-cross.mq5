#property strict
#property version   "5.0"
#property description "QM5_9218 MQL5 Aroon Up/Down Crossover (ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9218 — MQL5 Aroon Up/Down Crossover
// Source: Mohamed Abdelmaaboud, MQL5 Articles 2024-01-19
// Card: cards_approved/QM5_9218_mql5-aroon-cross.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9218;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_aroon_period       = 25;    // Aroon Up/Down lookback period
input int    strategy_atr_period         = 14;    // ATR period for stop sizing
input double strategy_sl_atr_mult        = 1.8;   // SL = ATR * multiplier
input double strategy_tp_rr              = 2.3;   // TP = SL * R:R ratio
input double strategy_min_aroon_spread   = 5.0;   // min Aroon spread at entry (filter churn)
input int    strategy_max_hold_bars      = 60;    // failsafe time-exit in H1 bars

// -----------------------------------------------------------------------------
// Aroon indicator helpers — pool-based, no file-scope handles.
// MT5 iAroon buffer layout: 0 = Aroon Up, 1 = Aroon Down.
// CopyBuffer single-shift is O(1) per call; allowed on every-tick path.
// -----------------------------------------------------------------------------

int Local_IndAroon(const string sym, const ENUM_TIMEFRAMES tf, const int period)
  {
   const string key = StringFormat("AROON|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iAroon(sym, tf, period);
   return QM_IndicatorsRegister(key, h);
  }

double Local_AroonUp(const string sym, const ENUM_TIMEFRAMES tf,
                     const int period, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(Local_IndAroon(sym, tf, period), 0, shift);
  }

double Local_AroonDown(const string sym, const ENUM_TIMEFRAMES tf,
                       const int period, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(Local_IndAroon(sym, tf, period), 1, shift);
  }

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

bool HasOwnPosition(ENUM_POSITION_TYPE &ptype, datetime &entry_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)magic)
         continue;
      ptype      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per magic — check before computing indicators
   ENUM_POSITION_TYPE dummy_type;
   datetime dummy_time;
   if(HasOwnPosition(dummy_type, dummy_time))
      return false;

   // Read last two closed bars (O(1) per call via pooled handle + CopyBuffer shift)
   const double up1 = Local_AroonUp(_Symbol, PERIOD_H1, strategy_aroon_period, 1);
   const double dn1 = Local_AroonDown(_Symbol, PERIOD_H1, strategy_aroon_period, 1);
   const double up2 = Local_AroonUp(_Symbol, PERIOD_H1, strategy_aroon_period, 2);
   const double dn2 = Local_AroonDown(_Symbol, PERIOD_H1, strategy_aroon_period, 2);

   // Guard against warm-up returns (indicator not ready)
   if(up1 < 0.0 || dn1 < 0.0 || up2 < 0.0 || dn2 < 0.0)
      return false;

   const double spread_now  = up1 - dn1;   // positive = Up dominant
   const double spread_prev = up2 - dn2;

   // Long: Up crosses above Down; spread >= min_aroon_spread filter
   const bool long_cross  = (spread_now  >=  strategy_min_aroon_spread) &&
                             (spread_prev <=  0.0);
   // Short: Down crosses above Up; (Down−Up) >= min_aroon_spread filter
   const bool short_cross = (-spread_now >=  strategy_min_aroon_spread) &&
                             (-spread_prev <= 0.0);

   if(!long_cross && !short_cross)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl_dist = strategy_sl_atr_mult * atr;
   const double tp_dist = sl_dist * strategy_tp_rr;

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(long_cross)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = ask - sl_dist;
      req.tp     = ask + tp_dist;
      req.reason = "AROON_LONG_CROSS";
     }
   else
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = bid + sl_dist;
      req.tp     = bid - tp_dist;
      req.reason = "AROON_SHORT_CROSS";
     }

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No active management — SL/TP and time-exit handled per card spec
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime entry_time;
   if(!HasOwnPosition(ptype, entry_time))
      return false;

   // Failsafe time-exit: bars elapsed since entry (H1 bars approximated from seconds)
   const int bars_elapsed = (int)((TimeCurrent() - entry_time) / PeriodSeconds(PERIOD_H1));
   if(bars_elapsed >= strategy_max_hold_bars)
      return true;

   // Aroon reverse-cross exit (O(1) per call, allowed in per-tick path)
   const double up1 = Local_AroonUp(_Symbol, PERIOD_H1, strategy_aroon_period, 1);
   const double dn1 = Local_AroonDown(_Symbol, PERIOD_H1, strategy_aroon_period, 1);
   const double up2 = Local_AroonUp(_Symbol, PERIOD_H1, strategy_aroon_period, 2);
   const double dn2 = Local_AroonDown(_Symbol, PERIOD_H1, strategy_aroon_period, 2);

   if(up1 < 0.0 || dn1 < 0.0 || up2 < 0.0 || dn2 < 0.0)
      return false;

   const double spread_now  = up1 - dn1;
   const double spread_prev = up2 - dn2;

   if(ptype == POSITION_TYPE_BUY)
      return (spread_now <= 0.0) && (spread_prev > 0.0); // Down crosses above Up
   else
      return (spread_now >= 0.0) && (spread_prev < 0.0); // Up crosses above Down
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework QM_NewsAllowsTrade
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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_9218\",\"slug\":\"mql5-aroon-cross\"}");
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
