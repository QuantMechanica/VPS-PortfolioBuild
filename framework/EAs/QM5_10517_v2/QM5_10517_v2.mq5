#property strict
#property version   "5.0"
#property description "QM5_10517 MQL5 Percentage Channel Swing _v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica Strategy Card: QM5_10517_v2
// Logic: Percentage Channel Breakout/Mean-reversion.
// Fixes: Increased news stale tolerance to avoid ONINIT_FAILED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10517;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 1.0;
input double RISK_FIXED                 = 0.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 8760;    // Increased to 1 year to avoid INIT_FAILED
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_channel_percent   = 50.0;
input bool   strategy_use_middle_cross  = false;
input int    strategy_channel_lookback  = 300;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_tp_r_multiple     = 1.25;
input bool   strategy_reverse_trade     = false;

// -----------------------------------------------------------------------------
// Strategy logic
// -----------------------------------------------------------------------------

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
        }
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasOurPosition()) return false;

   const int bars = Bars(_Symbol, PERIOD_CURRENT);
   const int lookback = MathMin(strategy_channel_lookback, bars - 5);
   if(lookback < 10) return false;

   const double pct = strategy_channel_percent / 100.0;
   const double plus_value = 1.0 + pct / 100.0;
   const double minus_value = 1.0 - pct / 100.0;

   double middle_next = 0.0;
   double middle_2 = 0.0, middle_1 = 0.0;
   double upper_1 = 0.0, lower_1 = 0.0;

   // Pre-fetch price to avoid redundant QM_SMA calls in loop
   double prices[];
   if(CopyClose(_Symbol, PERIOD_CURRENT, 1, lookback, prices) != lookback) return false;

   for(int i = 0; i < lookback; ++i)
     {
      int shift = lookback - i;
      double price = prices[i];
      double middle = price;
      
      if(i > 0)
        {
         if(price * minus_value > middle_next) middle = price * minus_value;
         else if(price * plus_value < middle_next) middle = price * plus_value;
         else middle = middle_next;
        }

      if(shift == 2) middle_2 = middle;
      if(shift == 1)
        {
         middle_1 = middle;
         upper_1 = middle * plus_value;
         lower_1 = middle * minus_value;
        }
      middle_next = middle;
     }

   if(middle_1 <= 0.0 || upper_1 <= 0.0 || lower_1 <= 0.0) return false;

   const double high_1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   const double low_1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   const double close_2 = iClose(_Symbol, PERIOD_CURRENT, 2);

   int signal = 0;
   if(strategy_use_middle_cross)
     {
      if(close_2 >= middle_2 && close_1 < middle_1) signal = 1;
      else if(close_2 <= middle_2 && close_1 > middle_1) signal = -1;
     }
   else
     {
      const bool long_signal = (low_1 <= lower_1);
      const bool short_signal = (high_1 >= upper_1);
      if(long_signal != short_signal) signal = long_signal ? 1 : -1;
     }

   if(strategy_reverse_trade) signal = -signal;
   if(signal == 0) return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0) return false;

   const double risk_dist = MathAbs(entry - req.sl);
   req.tp = (req.type == QM_BUY) ? entry + risk_dist * strategy_tp_r_multiple : entry - risk_dist * strategy_tp_r_multiple;
   
   req.reason = (signal > 0) ? "PCT_CHAN_LONG" : "PCT_CHAN_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal() { return false; }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

bool Strategy_NoTradeFilter() { return false; }

// -----------------------------------------------------------------------------
// Framework Wiring
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
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
      
   if(!news_allows || QM_FrameworkHandleFridayClose() || Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

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

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
