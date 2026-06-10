#property strict
#property version   "5.0"
#property description "QM5_9464 GitHub Ichimoku Tenkan/Kijun Cross H1 (gh-ichi-tk-cross)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9464 — GitHub Ichimoku Tenkan/Kijun Cross
// Source: pipbolt.io, Ichimoku-Kinko-Hyo-EA.mq5, GitHub
// Card:   D:\QM\strategy_farm\artifacts\cards_approved\QM5_9464_gh-ichi-tk-cross.md
// Entry:  Tenkan-sen crosses above/below Kijun-sen on H1 closed bar.
// Exit:   Reverse state (Tenkan <= Kijun for longs, Tenkan >= Kijun for shorts).
// Stop:   ATR(14) * 2.0 from entry price.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9464;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                 = 336;
input string qm_news_min_impact                      = "high";
input QM_NewsMode qm_news_mode_legacy                = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled                 = true;
input int    qm_friday_close_hour_broker             = 21;

input group "Stress"
input double qm_stress_reject_probability            = 0.0;

input group "Strategy"
input int    strategy_tenkan_period                  = 9;    // Tenkan-sen lookback (source default)
input int    strategy_kijun_period                   = 26;   // Kijun-sen lookback (source default)
input int    strategy_atr_period                     = 14;   // ATR period for stop sizing
input double strategy_atr_sl_mult                    = 2.0;  // ATR multiplier for stop distance

// -----------------------------------------------------------------------------
// Closed-bar Ichimoku line cache
// Updated once per new bar inside Strategy_EntrySignal (QM_IsNewBar()-gated).
// Strategy_ExitSignal reads these cached values (one-tick latency is negligible
// on H1 where hundreds of ticks follow bar close before the next bar opens).
// -----------------------------------------------------------------------------
double g_tenkan1 = 0.0;  // Tenkan-sen value at shift=1 (last closed bar)
double g_kijun1  = 0.0;  // Kijun-sen  value at shift=1
double g_tenkan2 = 0.0;  // Tenkan-sen value at shift=2 (bar before last)
double g_kijun2  = 0.0;  // Kijun-sen  value at shift=2

// Compute Ichimoku mid-price line: (HHV(period, shift) + LLV(period, shift)) / 2.
// perf-allowed: Ichimoku has no QM_* helper; called only from QM_IsNewBar()-gated context.
double IchimokuLine(const int period, const int shift)
  {
   if(period <= 0 || shift < 1)
      return 0.0;
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   if(CopyHigh(_Symbol, _Period, shift, period, highs) < period) return 0.0;
   if(CopyLow (_Symbol, _Period, shift, period, lows)  < period) return 0.0;
   double hh = highs[ArrayMaximum(highs, 0, period)];
   double ll = lows [ArrayMinimum(lows,  0, period)];
   return (hh + ll) * 0.5;
  }

// Advance Ichimoku cache — call exactly ONCE per new closed bar.
void AdvanceIchimokuCache()
  {
   g_tenkan1 = IchimokuLine(strategy_tenkan_period, 1);
   g_kijun1  = IchimokuLine(strategy_kijun_period,  1);
   g_tenkan2 = IchimokuLine(strategy_tenkan_period, 2);
   g_kijun2  = IchimokuLine(strategy_kijun_period,  2);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // No additional filter: card disables MA filter for P2 baseline.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance Ichimoku cache on each new bar (this function is called only when
   // QM_IsNewBar() == true in OnTick, so CopyHigh/CopyLow fire once per bar).
   AdvanceIchimokuCache();

   if(g_tenkan1 <= 0.0 || g_kijun1 <= 0.0 || g_tenkan2 <= 0.0 || g_kijun2 <= 0.0)
      return false;

   // Long: Tenkan crossed above Kijun (T[1] > K[1] and T[2] <= K[2]).
   if(g_tenkan1 > g_kijun1 && g_tenkan2 <= g_kijun2)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl    = QM_StopATR(_Symbol, QM_BUY, entry,
                                      strategy_atr_period, strategy_atr_sl_mult);
      if(sl <= 0.0) return false;
      req.type             = QM_BUY;
      req.price            = entry;
      req.sl               = sl;
      req.tp               = 0.0;
      req.reason           = "ichi-tk-cross-long";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // Short: Tenkan crossed below Kijun (T[1] < K[1] and T[2] >= K[2]).
   if(g_tenkan1 < g_kijun1 && g_tenkan2 >= g_kijun2)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl    = QM_StopATR(_Symbol, QM_SELL, entry,
                                      strategy_atr_period, strategy_atr_sl_mult);
      if(sl <= 0.0) return false;
      req.type             = QM_SELL;
      req.price            = entry;
      req.sl               = sl;
      req.tp               = 0.0;
      req.reason           = "ichi-tk-cross-short";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no active trade management (no BE, trail, or partial).
  }

bool Strategy_ExitSignal()
  {
   // Close long when Tenkan-sen <= Kijun-sen; close short when Tenkan-sen >= Kijun-sen.
   // Uses closed-bar cache (g_tenkan1/g_kijun1), which is refreshed once per bar
   // by Strategy_EntrySignal. One-tick latency on first tick of new bar is negligible on H1.
   if(g_tenkan1 <= 0.0 || g_kijun1 <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY  && g_tenkan1 <= g_kijun1) return true;
      if(pt == POSITION_TYPE_SELL && g_tenkan1 >= g_kijun1) return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // Defer entirely to framework 2-axis news filter.
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9464\",\"slug\":\"gh-ichi-tk-cross\"}");
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
