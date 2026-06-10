#property strict
#property version   "5.0"
#property description "QM5_9362 — Ichimoku Chikou Span vs Senkou Span A with ADX confirmation (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_9362_mql5-ichi-chikou-span
// Source: Stephen Njuki, MQL5 Wizard Techniques Part 73, Pattern 4
// Strategy: Buy when Chikou Span[26] > Senkou Span A[current] AND ADX >= 25.
//           Sell on the reverse. Exit on opposite signal or after 96 M30 bars.
//           SL = swing high/low (10-bar) ± 0.5 × ATR(14).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9362;
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
input int    strategy_ichimoku_tenkan   = 9;    // Tenkan-sen period
input int    strategy_ichimoku_kijun    = 26;   // Kijun-sen period
input int    strategy_ichimoku_senkou   = 52;   // Senkou Span B period
input double strategy_adx_threshold    = 25.0; // ADX minimum for entry
input int    strategy_adx_period       = 14;   // ADX period
input int    strategy_swing_lookback   = 10;   // Bars for swing high/low SL
input double strategy_sl_atr_buffer    = 0.5;  // ATR multiple added beyond swing SL
input int    strategy_time_exit_bars   = 96;   // Max hold in chart bars before forced close

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Read Ichimoku Chikou and Senkou A with shifts documented in framework:
// ChikouSpan at buffer-shift=26 = close 26 bars ago (avoids NaN on forming bar).
// SenkouSpanA at buffer-shift=kijun=26 = current cloud level (framework-documented).
void ReadIchimokuSignal(double &chikou_out, double &senkou_a_out)
  {
   chikou_out   = QM_Ichimoku_ChikouSpan( _Symbol, _Period,
                                          strategy_ichimoku_tenkan,
                                          strategy_ichimoku_kijun,
                                          strategy_ichimoku_senkou,
                                          strategy_ichimoku_kijun);   // shift=26
   senkou_a_out = QM_Ichimoku_SenkouSpanA(_Symbol, _Period,
                                           strategy_ichimoku_tenkan,
                                           strategy_ichimoku_kijun,
                                           strategy_ichimoku_senkou,
                                           strategy_ichimoku_kijun);  // shift=26 = current cloud
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
   double chikou, senkou_a;
   ReadIchimokuSignal(chikou, senkou_a);
   if(chikou <= 0.0 || senkou_a <= 0.0)
      return false;

   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx < strategy_adx_threshold)
      return false;

   QM_OrderType order_type;
   if(chikou > senkou_a)
      order_type = QM_BUY;
   else if(chikou < senkou_a)
      order_type = QM_SELL;
   else
      return false;

   const double entry = QM_OrderTypeIsBuy(order_type)
                       ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_adx_period, 1);
   if(atr <= 0.0)
      return false;

   const double swing_sl = QM_StopStructure(_Symbol, order_type, entry,
                                            strategy_swing_lookback);
   if(swing_sl <= 0.0)
      return false;

   double sl;
   if(order_type == QM_BUY)
      sl = swing_sl - strategy_sl_atr_buffer * atr;
   else
      sl = swing_sl + strategy_sl_atr_buffer * atr;

   if(order_type == QM_BUY  && sl >= entry) return false;
   if(order_type == QM_SELL && sl <= entry) return false;

   req.type        = order_type;
   req.price       = 0.0;
   req.sl          = sl;
   req.tp          = 0.0;
   req.reason      = "ichi_chikou_adx";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing or break-even management specified in the card.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();

   // Find open position for this magic
   bool                 found    = false;
   ENUM_POSITION_TYPE   pos_type = POSITION_TYPE_BUY;
   datetime             open_time = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      found = true;
      break; // one position per magic
     }
   if(!found)
      return false;

   // Time exit: strategy_time_exit_bars full bars
   const int hold_limit_secs = strategy_time_exit_bars * PeriodSeconds(_Period);
   if((int)(TimeCurrent() - open_time) >= hold_limit_secs)
      return true;

   // Signal-reversal exit (handle-pooled indicator reads — O(1) per tick)
   double chikou, senkou_a;
   ReadIchimokuSignal(chikou, senkou_a);
   if(chikou <= 0.0 || senkou_a <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY  && chikou < senkou_a) return true;
   if(pos_type == POSITION_TYPE_SELL && chikou > senkou_a) return true;

   return false;
  }

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
