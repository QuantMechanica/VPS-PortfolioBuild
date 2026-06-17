#property strict
#property version   "5.0"
#property description "QM5_10572 MQL5 ForexLine MA Color Change (mql5-forexline)"
// Strategy Card: QM5_10572_mql5-forexline, G0 APPROVED 2026-05-22.
// Source: Nikolay Kositsin "Exp_ForexLine", MQL5 CodeBase id 14896.

#include <QM/QM_Common.mqh>

// =============================================================================
// ForexLine = a smoothed moving-average whose plotted color flips with the
// direction of its slope. A closed-bar "bullish color change" fires when the
// MA turns up (was flat/falling, now rising); a "bearish color change" fires
// when it turns down. iCustom(ForexLine) is unavailable in the .DWX tester, so
// the line is self-computed with the pooled QM_SMMA reader (SMMA is the closest
// built-in to the source's smoothed averaging) and the color/direction is
// derived from the slope across CLOSED bars (shift 1/2/3). One trigger event
// per bar; opposite color change is the exit.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10572;
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
// ForexLine moving-average period/method (card: ForexLine MA period/method,
// sweepable). MODE per applied price PRICE_CLOSE on the card timeframe.
input int    strategy_fl_period         = 12;     // ForexLine smoothing length.
input bool   strategy_use_adx_filter    = false;  // Optional ADX minimum-trend filter (card filter).
input int    strategy_adx_period        = 14;     // ADX period when filter enabled.
input double strategy_adx_min           = 20.0;   // Minimum ADX to allow entry.
input int    strategy_atr_period        = 14;     // ATR(14) hard-stop basis (card P2 baseline).
input double strategy_atr_sl_mult       = 2.0;    // 2.0 ATR hard stop (card P2 baseline).
input double strategy_tp_rr             = 1.5;    // 1.5R target (card P2 baseline).

// -----------------------------------------------------------------------------
// ForexLine smoothed-MA slope-direction helper.
//   dir = +1 rising, -1 falling, 0 flat, evaluated on closed bars.
// -----------------------------------------------------------------------------
int ForexLineDirection(const int newer_shift)
  {
   // Slope between the MA at newer_shift and newer_shift+1 (both closed bars).
   const double ma_newer = QM_SMMA(_Symbol, _Period, strategy_fl_period, newer_shift);
   const double ma_older = QM_SMMA(_Symbol, _Period, strategy_fl_period, newer_shift + 1);
   if(ma_newer <= 0.0 || ma_older <= 0.0)
      return 0;
   if(ma_newer > ma_older)
      return 1;
   if(ma_newer < ma_older)
      return -1;
   return 0;
  }

// Return TRUE to BLOCK trading this tick. Cheap O(1) checks only.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One active position per symbol/magic (card Position Sizing).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Optional ADX minimum-trend filter (card Zusaetzliche Filter).
   if(strategy_use_adx_filter)
     {
      const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
      if(adx < strategy_adx_min)
         return false;
     }

   // Closed-bar ForexLine color change: prior slope vs latest slope.
   const int dir_now  = ForexLineDirection(1);   // latest closed bar slope.
   const int dir_prev = ForexLineDirection(2);   // bar before that.
   if(dir_now == 0)
      return false;

   const bool bullish_change = (dir_now > 0 && dir_prev <= 0);
   const bool bearish_change = (dir_now < 0 && dir_prev >= 0);
   if(!bullish_change && !bearish_change)
      return false;

   const QM_OrderType side = bullish_change ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // ATR(14) 2.0 hard stop + 1.5R target (card Stop Loss / P2 baseline).
   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);

   req.type   = side;
   req.price  = 0.0;   // market fill at send.
   req.sl     = sl;
   req.tp     = tp;
   req.reason = bullish_change ? "FOREXLINE_BULL_COLORCHANGE" : "FOREXLINE_BEAR_COLORCHANGE";
   return true;
  }

// Per-tick: no trailing/partial/BE — exits via SL/TP, opposite signal, framework.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now (opposite ForexLine color change).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int dir_now  = ForexLineDirection(1);
   const int dir_prev = ForexLineDirection(2);
   if(dir_now == 0)
      return false;

   const bool bullish_change = (dir_now > 0 && dir_prev <= 0);
   const bool bearish_change = (dir_now < 0 && dir_prev >= 0);
   if(!bullish_change && !bearish_change)
      return false;

   // Close a long on bearish change, a short on bullish change (card Exit).
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && bearish_change)
         return true;
      if(ptype == POSITION_TYPE_SELL && bullish_change)
         return true;
     }
   return false;
  }

// Optional news-filter override — defer to central framework filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10572_mql5_forexline\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
