#property strict
#property version   "5.0"
#property description "QM5_9960 | ff-lwma5-openclose-cross | ForexFactory LWMA5 Open-Close Cross H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9960 — ForexFactory LWMA5 Open/Close Cross H4
// Source: SwingMan, ForexFactory "Golden-Cross Trading-Idea" (2023-2025)
// Entry: D1 LWMA(5,close) vs LWMA(5,open) trend filter + H4 close/open LWMA cross.
// Exit:  Opposite H4 cross, 1.5R TP, 10-bar time stop.
// Stop:  1.1 * ATR(14, H4).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9960;
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
input int    strategy_lwma_period       = 5;     // LWMA period for open/close lines
input int    strategy_atr_period        = 14;    // ATR period (H4)
input double strategy_atr_sl_mult       = 1.1;  // SL = mult * ATR(14,H4)
input double strategy_tp_ratio          = 1.5;  // TP = ratio * SL distance
input double strategy_atr_range_filter  = 2.0;  // Skip cross candle if range > mult * ATR
input double strategy_spread_pct_max    = 0.12; // Max spread as fraction of stop distance
input int    strategy_time_stop_bars    = 10;   // Close position after N H4 bars (40h)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // No additional session filter beyond news/Friday-close guards.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // --- D1 trend filter ---
   double d1_lwma_close_1 = QM_LWMA(_Symbol, PERIOD_D1, strategy_lwma_period, 1, PRICE_CLOSE);
   double d1_lwma_open_1  = QM_LWMA(_Symbol, PERIOD_D1, strategy_lwma_period, 1, PRICE_OPEN);

   // --- H4 cross detection (last closed bar = shift 1, bar before = shift 2) ---
   double h4_lwma_close_1 = QM_LWMA(_Symbol, PERIOD_H4, strategy_lwma_period, 1, PRICE_CLOSE);
   double h4_lwma_open_1  = QM_LWMA(_Symbol, PERIOD_H4, strategy_lwma_period, 1, PRICE_OPEN);
   double h4_lwma_close_2 = QM_LWMA(_Symbol, PERIOD_H4, strategy_lwma_period, 2, PRICE_CLOSE);
   double h4_lwma_open_2  = QM_LWMA(_Symbol, PERIOD_H4, strategy_lwma_period, 2, PRICE_OPEN);

   // H4 price confirmation (close must be on the same side as the cross)
   double h4_close_1 = iClose(_Symbol, PERIOD_H4, 1);  // perf-allowed: no QM_Close helper
   double h4_high_1  = iHigh(_Symbol, PERIOD_H4, 1);   // perf-allowed: range filter
   double h4_low_1   = iLow(_Symbol, PERIOD_H4, 1);    // perf-allowed: range filter

   // ATR for stops and range filter
   double h4_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(h4_atr <= 0.0)
      return false;

   // Range filter: skip if cross candle is too large (wide/volatile bar)
   double candle_range = h4_high_1 - h4_low_1;
   if(candle_range > strategy_atr_range_filter * h4_atr)
      return false;

   // Stop distance and spread check
   double sl_distance = strategy_atr_sl_mult * h4_atr;
   double spread_pts  = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(sl_distance > 0.0 && spread_pts / sl_distance > strategy_spread_pct_max)
      return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool bullish_cross = (h4_lwma_close_1 > h4_lwma_open_1) && (h4_lwma_close_2 <= h4_lwma_open_2);
   bool bearish_cross = (h4_lwma_close_1 < h4_lwma_open_1) && (h4_lwma_close_2 >= h4_lwma_open_2);

   // --- Long entry ---
   if(bullish_cross &&
      d1_lwma_close_1 > d1_lwma_open_1 &&
      h4_close_1 > h4_lwma_close_1 &&
      h4_close_1 > h4_lwma_open_1)
     {
      req.type              = QM_BUY;
      req.price             = ask;
      req.sl                = ask - sl_distance;
      req.tp                = ask + strategy_tp_ratio * sl_distance;
      req.reason            = "QM5_9960_LONG";
      req.symbol_slot       = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // --- Short entry ---
   if(bearish_cross &&
      d1_lwma_close_1 < d1_lwma_open_1 &&
      h4_close_1 < h4_lwma_close_1 &&
      h4_close_1 < h4_lwma_open_1)
     {
      req.type              = QM_SELL;
      req.price             = bid;
      req.sl                = bid + sl_distance;
      req.tp                = bid - strategy_tp_ratio * sl_distance;
      req.reason            = "QM5_9960_SHORT";
      req.symbol_slot       = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Baseline: no break-even or trail; SL/TP set at entry. Time stop in ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const long h4_period_seconds = PeriodSeconds(PERIOD_H4);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time stop: close after N H4 bars elapsed
      datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      if((long)(TimeCurrent() - entry_time) >= strategy_time_stop_bars * h4_period_seconds)
         return true;

      // Opposite LWMA cross exit — check on every tick; indicators change only
      // on new bar so this fires once on the first tick after the cross forms.
      double h4_lwma_close_1 = QM_LWMA(_Symbol, PERIOD_H4, strategy_lwma_period, 1, PRICE_CLOSE);
      double h4_lwma_open_1  = QM_LWMA(_Symbol, PERIOD_H4, strategy_lwma_period, 1, PRICE_OPEN);
      double h4_lwma_close_2 = QM_LWMA(_Symbol, PERIOD_H4, strategy_lwma_period, 2, PRICE_CLOSE);
      double h4_lwma_open_2  = QM_LWMA(_Symbol, PERIOD_H4, strategy_lwma_period, 2, PRICE_OPEN);

      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(pos_type == POSITION_TYPE_BUY)
        {
         // Bearish cross: close < open after being above
         if(h4_lwma_close_1 < h4_lwma_open_1 && h4_lwma_close_2 >= h4_lwma_open_2)
            return true;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         // Bullish cross: close > open after being below
         if(h4_lwma_close_1 > h4_lwma_open_1 && h4_lwma_close_2 <= h4_lwma_open_2)
            return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade
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
