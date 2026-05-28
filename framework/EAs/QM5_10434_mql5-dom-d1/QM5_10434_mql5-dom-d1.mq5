#property strict
#property version   "5.0"
#property description "QM5_10434 - mql5-dom-d1 - Daily Dominance Bias"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_10434 - mql5-dom-d1
// -----------------------------------------------------------------------------
// Strategy: MQL5 Daily Dominance Bias
// Source: Chukwubuikem Okeke, Dominance EA
// Period: D1
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10434;
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
input int    strategy_ma_period         = 50;
input int    strategy_atr_period        = 14;
input double strategy_atr_multiplier    = 1.0;
input double strategy_tp_multiplier     = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // No whole-tick block here: Monday exclusion is entry-only so time-stop exits can still run.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Source/card rule: skip Monday entries to avoid weekend volatility.
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 1) return false;

   // Determine previous day's boundaries
   datetime d1_start = iTime(_Symbol, PERIOD_D1, 0);
   datetime d1_prev_start = iTime(_Symbol, PERIOD_D1, 1);
   if(d1_start <= 0 || d1_prev_start <= 0) return false;

   // Count intraday (H1) bars for previous day
   int bull_count = 0;
   int bear_count = 0;
   
   // Last H1 bar of the previous day is just before today's start
   int h1_start_idx = iBarShift(_Symbol, PERIOD_H1, d1_start - 1);
   // First H1 bar of the previous day starts exactly at d1_prev_start
   int h1_end_idx = iBarShift(_Symbol, PERIOD_H1, d1_prev_start);
   
   if(h1_start_idx < 0 || h1_end_idx < 0 || h1_start_idx > h1_end_idx) return false;
   
   for(int i = h1_start_idx; i <= h1_end_idx; i++)
     {
      double o = iOpen(_Symbol, PERIOD_H1, i);
      double c = iClose(_Symbol, PERIOD_H1, i);
      if(c > o) bull_count++;
      else if(c < o) bear_count++;
     }
   
   // MA confirmation: SMA(50) on H1 closes
   // Previous day's final candle close compared to H1 SMA
   double last_h1_close = iClose(_Symbol, PERIOD_H1, h1_start_idx);
   double ma = QM_SMA(_Symbol, PERIOD_H1, strategy_ma_period, h1_start_idx);
   if(ma <= 0) return false;
   
   bool long_signal = (bull_count > bear_count) && (last_h1_close > ma);
   bool short_signal = (bear_count > bull_count) && (last_h1_close < ma);
   
   if(!long_signal && !short_signal) return false;
   
   // SL and TP calculation
   double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0) return false;
   
   double prev_low = iLow(_Symbol, PERIOD_D1, 1);
   double prev_high = iHigh(_Symbol, PERIOD_D1, 1);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double sl = 0;
   double tp = 0;
   double dist_points = 0;
   
   if(long_signal)
     {
      req.type = QM_BUY;
      sl = prev_low - strategy_atr_multiplier * atr;
      dist_points = (ask - sl) / point;
      tp = ask + strategy_tp_multiplier * (ask - sl);
     }
   else
     {
      req.type = QM_SELL;
      sl = prev_high + strategy_atr_multiplier * atr;
      dist_points = (sl - bid) / point;
      tp = bid - strategy_tp_multiplier * (sl - bid);
     }
   
   if(dist_points <= 0) return false;

   // Skip if stop distance exceeds 3.5 x ATR(14,D1)
   if(dist_points * point > 3.5 * atr) return false;

   req.symbol_slot = qm_magic_slot_offset;
   req.sl = sl;
   req.tp = tp;
   req.reason = "mql5-dom-d1";

   return true;
   }
void Strategy_ManageOpenPosition()
  {
   // No specific management mentioned in the card beyond SL/TP and daily exit.
  }

bool Strategy_ExitSignal()
  {
   // Time stop: close at the next daily decision.
   // Check if the current open position belongs to a previous trading day.
   const int magic = QM_FrameworkMagic();
   datetime day_start = iTime(_Symbol, PERIOD_D1, 0);
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      
      datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(pos_time < day_start) return true; // Close old trades at start of new day
     }
     
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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
                        30, 30,
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
   if(!QM_KillSwitchCheck()) return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar()) return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }

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
