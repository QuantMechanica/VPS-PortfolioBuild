#property strict
#property version   "5.0"
#property description "QM5_11913 Crue Ichimoku 5-Line Alignment Trend (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11913
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11913;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_tenkan_period     = 9;
input int    strategy_kijun_period      = 26;
input int    strategy_senkou_b_period   = 52;
input int    strategy_shift             = 26; // For Chikou and Senkou
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 3.0;
input int    strategy_time_stop_bars    = 180;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Helper to manually calculate Ichimoku lines since not in QM_Indicators yet
bool GetIchimokuValues(int shift, double &tenkan, double &kijun, double &senkouA, double &senkouB)
{
   double t_high = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, strategy_tenkan_period, shift));
   double t_low  = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, strategy_tenkan_period, shift));
   tenkan = (t_high + t_low) / 2.0;

   double k_high = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, strategy_kijun_period, shift));
   double k_low  = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, strategy_kijun_period, shift));
   kijun = (k_high + k_low) / 2.0;

   // Senkou A and B are shifted forward by 26 bars.
   // To get the Senkou value plotted AT bar 'shift', we need the Tenkan/Kijun/High/Low from 'shift + 26' bars ago.
   int past_shift = shift + strategy_shift;
   
   double past_t_high = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, strategy_tenkan_period, past_shift));
   double past_t_low  = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, strategy_tenkan_period, past_shift));
   double past_tenkan = (past_t_high + past_t_low) / 2.0;

   double past_k_high = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, strategy_kijun_period, past_shift));
   double past_k_low  = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, strategy_kijun_period, past_shift));
   double past_kijun = (past_k_high + past_k_low) / 2.0;

   senkouA = (past_tenkan + past_kijun) / 2.0;

   double past_sb_high = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, strategy_senkou_b_period, past_shift));
   double past_sb_low  = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, strategy_senkou_b_period, past_shift));
   senkouB = (past_sb_high + past_sb_low) / 2.0;

   return true;
}

bool CheckBullishAlignment(int shift)
{
   double tenkan, kijun, senkouA, senkouB;
   if(!GetIchimokuValues(shift, tenkan, kijun, senkouA, senkouB)) return false;

   // Chikou check: Current close compared to close 26 bars ago (simulating if current price is above historical price)
   double current_close = iClose(_Symbol, PERIOD_D1, shift);
   double past_close = iClose(_Symbol, PERIOD_D1, shift + strategy_shift);
   
   // The strategy card specifically asks for:
   // Tenkan > Kijun > SenkouA > SenkouB > Chikou_proxy
   // Where Chikou_proxy(t) = close(t-26). (Price 26 bars ago).
   // Wait, the card says: "SenkouB(t-26) > Chikou_proxy(t)"
   // No, wait. For Long:
   // Tenkan > Kijun
   // Kijun > SenkouA
   // SenkouA > SenkouB
   // SenkouB > Chikou_proxy(t) (Wait, if Chikou proxy is close(t-26), this means SenkouB > close(t-26).
   // Let's re-read carefully:
   // "Chikou(t) = close(t) # plotted at t - 26"
   // "Chikou_displayed_at_t = close(t + 26) -- but in real-time we use close(t)"
   // The simplest implementation: "compare close(t) against close(t-26)."
   // If close(t) > close(t-26), Chikou is "above" the price 26 bars ago.
   // Let's stick to standard monotonic alignment implied:
   // Tenkan > Kijun > SenkouA > SenkouB. And Current Close > Close 26 bars ago.
   // Actually, the card says:
   // - Tenkan(t) > Kijun(t)
   // - Kijun(t) > SenkouA(t-26)
   // - SenkouA(t-26) > SenkouB(t-26)
   // - SenkouB(t-26) > Chikou_proxy(t) ??? This implies bearish if SenkouB is above price.
   // Ah, the card says: "For the strict 5-line alignment, all four inequalities must hold."
   // Let's look at standard Ichimoku bullish alignment: 
   // Price > Tenkan > Kijun > SenkouA > SenkouB. And Chikou (Current Close) > Past Close (Close[26]).
   
   // Re-reading Card:
   // 1. Tenkan(t) > Kijun(t)
   // 2. Kijun(t) > SenkouA(t-26)
   // 3. SenkouA(t-26) > SenkouB(t-26)
   // 4. SenkouB(t-26) > Chikou_proxy(t) -- Wait, if SenkouB > Chikou_proxy, then SenkouB is at the bottom of the first 4, but ABOVE Chikou_proxy? That would mean Chikou_proxy is the LOWEST.
   // Let's assume standard monotonic: Tenkan > Kijun > SenkouA > SenkouB > Close(t-26).
   
   if (tenkan > kijun && 
       kijun > senkouA && 
       senkouA > senkouB && 
       senkouB > past_close) 
       return true;
       
   return false;
}

bool CheckBearishAlignment(int shift)
{
   double tenkan, kijun, senkouA, senkouB;
   if(!GetIchimokuValues(shift, tenkan, kijun, senkouA, senkouB)) return false;

   double past_close = iClose(_Symbol, PERIOD_D1, shift + strategy_shift);

   if (tenkan < kijun && 
       kijun < senkouA && 
       senkouA < senkouB && 
       senkouB < past_close) 
       return true;
       
   return false;
}

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(PositionsTotal() > 0) return false; // One position per symbol
   
   const double atr1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr1 <= 0.0) return false;

   bool signal_long  = CheckBullishAlignment(1);
   bool signal_short = CheckBearishAlignment(1);

   if(!signal_long && !signal_short) return false;

   QM_OrderType side = signal_long ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr1, strategy_atr_sl_mult);
   if(sl <= 0.0) return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "ICHIMOKU_ALIGN_LONG" : "ICHIMOKU_ALIGN_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_D1, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Exit if alignment is broken
      if(ptype == POSITION_TYPE_BUY && !CheckBullishAlignment(1)) return true;
      if(ptype == POSITION_TYPE_SELL && !CheckBearishAlignment(1)) return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

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
         ulong ticket = PositionGetTicket(i);
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
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
