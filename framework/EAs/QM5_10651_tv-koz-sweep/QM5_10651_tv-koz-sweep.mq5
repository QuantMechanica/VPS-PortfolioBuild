#property strict
#property version   "5.0"
#property description "QM5_10651 TradingView KOZ SMC ICT Sweep"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10651;
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
input int    strategy_broker_to_ny_offset_hours = 7;
input int    strategy_ny_start_1_hhmm           = 930;
input int    strategy_ny_end_1_hhmm             = 1100;
input int    strategy_ny_start_2_hhmm           = 1400;
input int    strategy_ny_end_2_hhmm             = 1530;
input int    strategy_m15_swing_wing_bars       = 2;
input int    strategy_m15_scan_bars             = 120;
input int    strategy_m5_scan_bars              = 32;
input int    strategy_fvg_lookback_bars         = 10;
input int    strategy_ob_lookback_bars          = 12;
input int    strategy_confluence_tolerance_pts  = 20;
input double strategy_pin_max_body_ratio        = 0.35;
input double strategy_pin_wick_body_mult        = 2.0;
input int    strategy_min_stop_points           = 20;

int HhmmFromBrokerAsNy(const datetime broker_time)
  {
   const datetime ny_time = broker_time - (strategy_broker_to_ny_offset_hours * 3600);
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return dt.hour * 100 + dt.min;
  }

bool HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

bool LoadRates(const ENUM_TIMEFRAMES tf, const int start_pos, const int count, MqlRates &rates[])
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, start_pos, count, rates); // perf-allowed: Strategy_EntrySignal is called only after QM_IsNewBar().
   return (copied == count);
  }

bool IsSwingHigh(MqlRates &rates[], const int idx, const int wing)
  {
   const double value = rates[idx].high;
   for(int k = 1; k <= wing; ++k)
     {
      if(rates[idx - k].high >= value || rates[idx + k].high >= value)
         return false;
     }
   return true;
  }

bool IsSwingLow(MqlRates &rates[], const int idx, const int wing)
  {
   const double value = rates[idx].low;
   for(int k = 1; k <= wing; ++k)
     {
      if(rates[idx - k].low <= value || rates[idx + k].low <= value)
         return false;
     }
   return true;
  }

bool FindM15Structure(MqlRates &rates[],
                      const int wing,
                      double &recent_high,
                      double &prior_high,
                      double &recent_low,
                      double &prior_low)
  {
   recent_high = 0.0;
   prior_high = 0.0;
   recent_low = 0.0;
   prior_low = 0.0;

   const int n = ArraySize(rates);
   if(wing < 1 || n < (wing * 2 + 10))
      return false;

   int highs_found = 0;
   int lows_found = 0;
   for(int i = wing; i < n - wing && (highs_found < 2 || lows_found < 2); ++i)
     {
      if(highs_found < 2 && IsSwingHigh(rates, i, wing))
        {
         if(highs_found == 0)
            recent_high = rates[i].high;
         else
            prior_high = rates[i].high;
         highs_found++;
        }

      if(lows_found < 2 && IsSwingLow(rates, i, wing))
        {
         if(lows_found == 0)
            recent_low = rates[i].low;
         else
            prior_low = rates[i].low;
         lows_found++;
        }
     }

   return (highs_found >= 2 && lows_found >= 2);
  }

bool LevelInRange(const double level, const double a, const double b, const double tolerance)
  {
   const double lo = MathMin(a, b) - tolerance;
   const double hi = MathMax(a, b) + tolerance;
   return (level >= lo && level <= hi);
  }

bool HasBullishConfluence(MqlRates &rates[], const double level, const double tolerance)
  {
   const int n = ArraySize(rates);
   const int ob_max = MathMin(strategy_ob_lookback_bars, n - 1);
   for(int i = 0; i < ob_max; ++i)
     {
      if(rates[i].close < rates[i].open && LevelInRange(level, rates[i].low, rates[i].high, tolerance))
         return true;
     }

   const int fvg_max = MathMin(strategy_fvg_lookback_bars, n - 3);
   for(int i = 0; i <= fvg_max; ++i)
     {
      const double older_high = rates[i + 2].high;
      const double newer_low = rates[i].low;
      if(older_high < newer_low && LevelInRange(level, older_high, newer_low, tolerance))
         return true;
     }
   return false;
  }

bool HasBearishConfluence(MqlRates &rates[], const double level, const double tolerance)
  {
   const int n = ArraySize(rates);
   const int ob_max = MathMin(strategy_ob_lookback_bars, n - 1);
   for(int i = 0; i < ob_max; ++i)
     {
      if(rates[i].close > rates[i].open && LevelInRange(level, rates[i].low, rates[i].high, tolerance))
         return true;
     }

   const int fvg_max = MathMin(strategy_fvg_lookback_bars, n - 3);
   for(int i = 0; i <= fvg_max; ++i)
     {
      const double older_low = rates[i + 2].low;
      const double newer_high = rates[i].high;
      if(older_low > newer_high && LevelInRange(level, older_low, newer_high, tolerance))
         return true;
     }
   return false;
  }

bool BullishEngulfing(MqlRates &rates[])
  {
   if(ArraySize(rates) < 2)
      return false;
   return (rates[0].close > rates[0].open &&
           rates[1].close < rates[1].open &&
           rates[0].close >= rates[1].open &&
           rates[0].open <= rates[1].close);
  }

bool BearishEngulfing(MqlRates &rates[])
  {
   if(ArraySize(rates) < 2)
      return false;
   return (rates[0].close < rates[0].open &&
           rates[1].close > rates[1].open &&
           rates[0].open >= rates[1].close &&
           rates[0].close <= rates[1].open);
  }

bool BullishPinBar(const MqlRates &bar)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0 || bar.close <= bar.open)
      return false;
   const double body = MathAbs(bar.close - bar.open);
   const double lower_wick = MathMin(bar.open, bar.close) - bar.low;
   const double upper_wick = bar.high - MathMax(bar.open, bar.close);
   return (body / range <= strategy_pin_max_body_ratio &&
           lower_wick >= strategy_pin_wick_body_mult * MathMax(body, _Point) &&
           lower_wick > upper_wick);
  }

bool BearishPinBar(const MqlRates &bar)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0 || bar.close >= bar.open)
      return false;
   const double body = MathAbs(bar.close - bar.open);
   const double upper_wick = bar.high - MathMax(bar.open, bar.close);
   const double lower_wick = MathMin(bar.open, bar.close) - bar.low;
   return (body / range <= strategy_pin_max_body_ratio &&
           upper_wick >= strategy_pin_wick_body_mult * MathMax(body, _Point) &&
           upper_wick > lower_wick);
  }

void ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildLongRequest(QM_EntryRequest &req, MqlRates &trigger_bar, const double target)
  {
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0 || target <= entry)
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol, trigger_bar.low);
   const double stop_points = MathAbs(entry - sl) / point;
   if(sl <= 0.0 || sl >= entry || stop_points < strategy_min_stop_points)
      return false;

   req.type = QM_BUY;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, target);
   req.reason = "KOZ_SWEEP_LONG_TP1";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool BuildShortRequest(QM_EntryRequest &req, MqlRates &trigger_bar, const double target)
  {
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0 || target >= entry)
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol, trigger_bar.high);
   const double stop_points = MathAbs(entry - sl) / point;
   if(sl <= 0.0 || sl <= entry || stop_points < strategy_min_stop_points)
      return false;

   req.type = QM_SELL;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, target);
   req.reason = "KOZ_SWEEP_SHORT_TP1";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   const int ny_hhmm = HhmmFromBrokerAsNy(TimeCurrent());
   return !(HhmmInWindow(ny_hhmm, strategy_ny_start_1_hhmm, strategy_ny_end_1_hhmm) ||
            HhmmInWindow(ny_hhmm, strategy_ny_start_2_hhmm, strategy_ny_end_2_hhmm));
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetRequest(req);

   if(_Period != PERIOD_M5)
      return false;

   MqlRates m5[];
   const int m5_count = MathMax(strategy_m5_scan_bars, MathMax(strategy_ob_lookback_bars, strategy_fvg_lookback_bars) + 4);
   if(!LoadRates(PERIOD_M5, 1, m5_count, m5))
      return false;

   MqlRates m15[];
   if(!LoadRates(PERIOD_M15, 1, strategy_m15_scan_bars, m15))
      return false;

   MqlRates d1[];
   if(!LoadRates(PERIOD_D1, 1, 1, d1))
      return false;

   double recent_high = 0.0;
   double prior_high = 0.0;
   double recent_low = 0.0;
   double prior_low = 0.0;
   if(!FindM15Structure(m15, strategy_m15_swing_wing_bars, recent_high, prior_high, recent_low, prior_low))
      return false;

   const bool bullish_bias = (recent_high > prior_high && recent_low > prior_low);
   const bool bearish_bias = (recent_high < prior_high && recent_low < prior_low);
   if(!bullish_bias && !bearish_bias)
      return false;

   const double pdl = d1[0].low;
   const double pdh = d1[0].high;
   const double tolerance = MathMax(strategy_confluence_tolerance_pts, 0) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(bullish_bias && (BullishEngulfing(m5) || BullishPinBar(m5[0])))
     {
      double swept_level = 0.0;
      if(m5[0].low < pdl && m5[0].close > pdl)
         swept_level = pdl;
      if(m5[0].low < recent_low && m5[0].close > recent_low)
         swept_level = (swept_level == 0.0 || recent_low > swept_level) ? recent_low : swept_level;

      if(swept_level > 0.0 && HasBullishConfluence(m5, swept_level, tolerance))
         return BuildLongRequest(req, m5[0], recent_high);
     }

   if(bearish_bias && (BearishEngulfing(m5) || BearishPinBar(m5[0])))
     {
      double swept_level = 0.0;
      if(m5[0].high > pdh && m5[0].close < pdh)
         swept_level = pdh;
      if(m5[0].high > recent_high && m5[0].close < recent_high)
         swept_level = (swept_level == 0.0 || recent_high < swept_level) ? recent_high : swept_level;

      if(swept_level > 0.0 && HasBearishConfluence(m5, swept_level, tolerance))
         return BuildShortRequest(req, m5[0], recent_low);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Baseline uses a single full-position TP1 exit for one-position-per-magic compliance.
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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
