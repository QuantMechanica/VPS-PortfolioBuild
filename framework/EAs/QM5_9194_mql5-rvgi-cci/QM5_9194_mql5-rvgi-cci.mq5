#property strict
#property version   "5.0"
#property description "QM5_9194 RVGI CCI SMA Reversal Confluence (ba57d97a)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9194 — RVGI CCI SMA Reversal Confluence
// Source: Christian Benjamin, MQL5 Article #20262, 2025-11-19
// Card: QM5_9194_mql5-rvgi-cci
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9194;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_period          = 30;    // SMA period for trend filter
input int    strategy_cci_period          = 14;    // CCI period for momentum signal
input int    strategy_rvgi_period         = 10;    // RVGI main-line SMA length
input int    strategy_atr_period          = 14;    // ATR period for stops and trail
input double strategy_atr_sl_mult         = 1.5;   // SL distance = ATR * mult
input double strategy_min_atr_ratio       = 0.5;   // Skip if ATR(14) < median_ATR(100) * ratio

// -----------------------------------------------------------------------------
// File-scope closed-bar state (updated once per new bar in AdvanceClosedBarState)
// -----------------------------------------------------------------------------
double g_rvgi_main_1 = 0.0;  // RVGI main line, shift=1 (last closed bar)
double g_rvgi_main_2 = 0.0;  // RVGI main line, shift=2 (prev closed bar)
double g_rvgi_sig_1  = 0.0;  // RVGI signal line, shift=1
double g_rvgi_sig_2  = 0.0;  // RVGI signal line, shift=2
double g_min_atr     = 0.0;  // Minimum ATR threshold (median_ATR * ratio)

// Compute RVGI main line at the given shift using symmetrically weighted sums
// of (close-open) and (high-low), then SMA over strategy_rvgi_period bars.
// // perf-allowed: RVGI not in QM_Indicators.mqh; gated by QM_IsNewBar caller
double RVGI_Main(const int shift)
  {
   double sum_num = 0.0, sum_den = 0.0;
   for(int i = 0; i < strategy_rvgi_period; i++)
     {
      int s = shift + i;
      // Symmetric weighted close-open (numerator contribution) // perf-allowed
      double co0 = iClose(_Symbol, _Period, s)   - iOpen(_Symbol, _Period, s);   // perf-allowed
      double co1 = iClose(_Symbol, _Period, s+1) - iOpen(_Symbol, _Period, s+1); // perf-allowed
      double co2 = iClose(_Symbol, _Period, s+2) - iOpen(_Symbol, _Period, s+2); // perf-allowed
      double co3 = iClose(_Symbol, _Period, s+3) - iOpen(_Symbol, _Period, s+3); // perf-allowed
      sum_num += co0 + 2.0*co1 + 2.0*co2 + co3;
      // Symmetric weighted high-low (denominator contribution) // perf-allowed
      double hl0 = iHigh(_Symbol, _Period, s)   - iLow(_Symbol, _Period, s);   // perf-allowed
      double hl1 = iHigh(_Symbol, _Period, s+1) - iLow(_Symbol, _Period, s+1); // perf-allowed
      double hl2 = iHigh(_Symbol, _Period, s+2) - iLow(_Symbol, _Period, s+2); // perf-allowed
      double hl3 = iHigh(_Symbol, _Period, s+3) - iLow(_Symbol, _Period, s+3); // perf-allowed
      sum_den += hl0 + 2.0*hl1 + 2.0*hl2 + hl3;
     }
   if(MathAbs(sum_den) < 1e-10) return 0.0;
   return sum_num / sum_den;
  }

// Advance file-scope RVGI state and min-ATR threshold for the new closed bar.
// Must be called only when QM_IsNewBar() just returned true (once per bar).
void AdvanceClosedBarState()
  {
   double m1 = RVGI_Main(1);
   double m2 = RVGI_Main(2);
   double m3 = RVGI_Main(3);
   double m4 = RVGI_Main(4);
   double m5 = RVGI_Main(5);
   g_rvgi_main_1 = m1;
   g_rvgi_main_2 = m2;
   // RVGI signal = SWMA(4) of main line
   g_rvgi_sig_1 = (m1 + 2.0*m2 + 2.0*m3 + m4) / 6.0;
   g_rvgi_sig_2 = (m2 + 2.0*m3 + 2.0*m4 + m5) / 6.0;
   // Median ATR(100) for minimum volatility filter
   double avals[100];
   for(int j = 0; j < 100; j++)
      avals[j] = QM_ATR(_Symbol, _Period, strategy_atr_period, j + 1);
   ArraySort(avals);
   g_min_atr = ((avals[49] + avals[50]) / 2.0) * strategy_min_atr_ratio;
  }

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < PositionsTotal(); i++)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
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
   AdvanceClosedBarState();

   // Warmup: skip until RVGI has valid state for two closed bars
   if(g_rvgi_main_1 == 0.0 || g_rvgi_main_2 == 0.0)
      return false;

   // One position at a time
   if(HasOurPosition())
      return false;

   const double close1   = iClose(_Symbol, _Period, 1);   // perf-allowed: bespoke closed-bar ref
   if(close1 <= 0.0) return false;

   const double sma30    = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double cci_curr = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);
   const double atr14    = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   // Minimum volatility filter
   if(g_min_atr > 0.0 && atr14 < g_min_atr)
      return false;

   const bool rvgi_bull_cross = g_rvgi_main_2 < g_rvgi_sig_2 && g_rvgi_main_1 > g_rvgi_sig_1;
   const bool rvgi_bear_cross = g_rvgi_main_2 > g_rvgi_sig_2 && g_rvgi_main_1 < g_rvgi_sig_1;
   const bool cci_up_cross    = cci_prev <= -100.0 && cci_curr > -100.0;
   const bool cci_dn_cross    = cci_prev >= 100.0  && cci_curr < 100.0;

   const double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double sl_dist = atr14 * strategy_atr_sl_mult;
   if(sl_dist < point) return false;

   // Long: price below SMA(30), CCI crosses up from oversold, RVGI bullish cross
   if(close1 < sma30 && cci_up_cross && rvgi_bull_cross)
     {
      req.type        = QM_BUY;
      req.price       = 0.0;
      req.sl          = close1 - sl_dist;
      req.tp          = close1 + 2.0 * sl_dist;
      req.reason      = "RVGI_CCI_SMA_LONG";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   // Short: price above SMA(30), CCI crosses down from overbought, RVGI bearish cross
   if(close1 > sma30 && cci_dn_cross && rvgi_bear_cross)
     {
      req.type        = QM_SELL;
      req.price       = 0.0;
      req.sl          = close1 + sl_dist;
      req.tp          = close1 - 2.0 * sl_dist;
      req.reason      = "RVGI_CCI_SMA_SHORT";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      // Trail by ATR(14) after profit develops
      QM_TM_TrailATR(ticket, strategy_atr_period, 1.0);
     }
  }

bool Strategy_ExitSignal()
  {
   if(g_rvgi_main_1 == 0.0 || g_rvgi_main_2 == 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      const ENUM_POSITION_TYPE ptype =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      const double cci_curr = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
      const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);
      const bool rvgi_bear  = g_rvgi_main_2 > g_rvgi_sig_2 && g_rvgi_main_1 < g_rvgi_sig_1;
      const bool rvgi_bull  = g_rvgi_main_2 < g_rvgi_sig_2 && g_rvgi_main_1 > g_rvgi_sig_1;
      const bool cci_dn     = cci_prev >= 100.0  && cci_curr < 100.0;
      const bool cci_up     = cci_prev <= -100.0 && cci_curr > -100.0;

      if(ptype == POSITION_TYPE_BUY  && rvgi_bear && cci_dn) return true;
      if(ptype == POSITION_TYPE_SELL && rvgi_bull && cci_up)  return true;
     }
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9194\",\"slug\":\"mql5-rvgi-cci\"}");
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
