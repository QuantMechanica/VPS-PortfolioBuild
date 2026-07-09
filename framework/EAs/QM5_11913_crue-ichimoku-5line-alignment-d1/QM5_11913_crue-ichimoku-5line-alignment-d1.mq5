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

// The framework owns the Ichimoku handle.  Cache the D1 alignment by the
// framework calendar key so exit checks remain O(1) on the per-tick path.
int g_alignment_day_key = 0;
int g_alignment_state   = 0; // +1 bullish, -1 bearish, 0 unaligned/unavailable

int CurrentAlignment()
  {
   const int day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(day_key <= 0)
      return 0;
   if(day_key == g_alignment_day_key)
      return g_alignment_state;

   g_alignment_day_key = day_key;
   g_alignment_state   = 0;

   const int signal_shift = 1;
   const int cloud_shift  = signal_shift + strategy_shift;
   const double tenkan = QM_Ichimoku_TenkanSen(_Symbol, PERIOD_D1,
                                                strategy_tenkan_period,
                                                strategy_kijun_period,
                                                strategy_senkou_b_period,
                                                signal_shift);
   const double kijun = QM_Ichimoku_KijunSen(_Symbol, PERIOD_D1,
                                              strategy_tenkan_period,
                                              strategy_kijun_period,
                                              strategy_senkou_b_period,
                                              signal_shift);
   const double senkou_a = QM_Ichimoku_SenkouSpanA(_Symbol, PERIOD_D1,
                                                    strategy_tenkan_period,
                                                    strategy_kijun_period,
                                                    strategy_senkou_b_period,
                                                    cloud_shift);
   const double senkou_b = QM_Ichimoku_SenkouSpanB(_Symbol, PERIOD_D1,
                                                    strategy_tenkan_period,
                                                    strategy_kijun_period,
                                                    strategy_senkou_b_period,
                                                    cloud_shift);
   const double chikou_proxy = iClose(_Symbol, PERIOD_D1, cloud_shift); // perf-allowed: one cached D1 close implements the card's fixed Chikou proxy

   if(tenkan <= 0.0 || kijun <= 0.0 || senkou_a <= 0.0 ||
      senkou_b <= 0.0 || chikou_proxy <= 0.0)
      return 0;

   // Preserve the approved card's literal five-value monotonic alignment.
   if(tenkan > kijun && kijun > senkou_a &&
      senkou_a > senkou_b && senkou_b > chikou_proxy)
      g_alignment_state = 1;
   else if(tenkan < kijun && kijun < senkou_a &&
           senkou_a < senkou_b && senkou_b < chikou_proxy)
      g_alignment_state = -1;

   return g_alignment_state;
  }

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0) return false;
   
   const double atr1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr1 <= 0.0) return false;

   const int alignment = CurrentAlignment();
   const bool signal_long  = (alignment > 0);
   const bool signal_short = (alignment < 0);

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
   req.expiration_seconds = 0;

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
      
      // Exit when the cached D1 alignment breaks or reverses.
      const int alignment = CurrentAlignment();
      if(ptype == POSITION_TYPE_BUY && alignment != 1) return true;
      if(ptype == POSITION_TYPE_SELL && alignment != -1) return true;
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

   // News blackout gates entries only; management and exits above stay live.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
