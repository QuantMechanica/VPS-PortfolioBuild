#property strict
#property version   "5.0"
#property description "QM5_9523 — MQL5 Asia Range Liquidity Sweep Fade"

#include <QM/QM_Common.mqh>

//--- Asia range state, reset each broker day
double g_asia_high    = 0.0;
double g_asia_low     = 0.0;
bool   g_asia_ready   = false;
int    g_trades_today = 0;
int    g_last_day     = -1;

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9523;
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
input int    AsiaStartHour   = 0;   // Broker time: Asia range build start hour (inclusive)
input int    AsiaEndHour     = 7;   // Broker time: Asia range build end hour (exclusive)

input group "Strategy — Trade Sessions"
input int    LondonStartHour = 9;   // Broker time: London session open (inclusive)
input int    LondonEndHour   = 17;  // Broker time: London session close (exclusive)
input int    NYStartHour     = 14;  // Broker time: NY session open (inclusive)
input int    NYEndHour       = 22;  // Broker time: NY session close (exclusive)

input group "Strategy — Signal"
input int    MaxTradesPerDay   = 1;    // Maximum entries per calendar day
input double RR                = 1.5;  // Take-profit risk:reward ratio
input double MinRangeATRRatio  = 0.1;  // Min sweep candle range as fraction of ATR(14, M15)
input double SlBufferATRRatio  = 0.05; // SL buffer beyond sweep extreme as fraction of ATR(14, M15)

// =============================================================================
// Asia range state advance — call ONCE per new bar inside QM_IsNewBar gate
// =============================================================================
void AdvanceAsiaRange()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt_now;
   TimeToStruct(broker_now, dt_now);
   const int today_day = dt_now.day_of_year;

   if(today_day != g_last_day)
     {
      g_last_day     = today_day;
      g_asia_high    = 0.0;
      g_asia_low     = 0.0;
      g_asia_ready   = false;
      g_trades_today = 0;
     }
   const datetime prev_time = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: single-shift inside QM_IsNewBar gate
   if(prev_time == 0)
      return;
   MqlDateTime dt_prev;
   TimeToStruct(prev_time, dt_prev);
   const int prev_hour = dt_prev.hour;

   // Incorporate closed bar into Asia range if it falls within build window
   if(prev_hour >= AsiaStartHour && prev_hour < AsiaEndHour)
     {
      const double bar_h = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed
      const double bar_l = iLow(_Symbol,  PERIOD_M15, 1); // perf-allowed
      if(g_asia_high == 0.0 || bar_h > g_asia_high)
         g_asia_high = bar_h;
      if(g_asia_low == 0.0 || bar_l < g_asia_low)
         g_asia_low = bar_l;
     }

   // Mark range ready once current time is past the build window
   if(!g_asia_ready && dt_now.hour >= AsiaEndHour && g_asia_high > 0.0 && g_asia_low > 0.0)
      g_asia_ready = true;
  }

// =============================================================================
// Framework hooks
// =============================================================================

// Return TRUE to BLOCK trading this tick. Cheap per-tick checks only.
bool Strategy_NoTradeFilter()
  {
   // Only trade during London or New York session
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int h = dt.hour;
   const bool in_london = (h >= LondonStartHour && h < LondonEndHour);
   const bool in_ny     = (h >= NYStartHour     && h < NYEndHour);
   if(!in_london && !in_ny)
      return true;

   // Block if daily trade cap already reached
   if(g_trades_today >= MaxTradesPerDay)
      return true;

   // Block if this EA already holds an open position on this symbol
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }

   return false;
  }

// Populate req and return TRUE if a new entry should fire on this closed bar.
// Called only after QM_IsNewBar() and AdvanceAsiaRange().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_asia_ready || g_asia_high <= 0.0 || g_asia_low <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, 14, 1);
   if(atr <= 0.0)
      return false;
   const double prev_h = iHigh(_Symbol,  PERIOD_M15, 1); // perf-allowed: single-shift inside QM_IsNewBar gate
   const double prev_l = iLow(_Symbol,   PERIOD_M15, 1); // perf-allowed: single-shift inside QM_IsNewBar gate
   const double prev_c = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: single-shift inside QM_IsNewBar gate
   if(prev_h <= 0.0 || prev_l <= 0.0 || prev_c <= 0.0)
      return false;

   // Skip candles below minimum range threshold (zero-range guard)
   if((prev_h - prev_l) < MinRangeATRRatio * atr)
      return false;

   const double sl_buf = SlBufferATRRatio * atr;
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   // Short: prev candle swept asiaHigh and closed back below → fade the sweep
   if(prev_h > g_asia_high && prev_c < g_asia_high)
     {
      const double entry  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl     = prev_h + sl_buf;
      const double sl_pts = (sl - entry) / point;
      if(sl_pts <= 0.0)
         return false;
      req.type        = QM_SELL;
      req.price       = entry;
      req.sl          = sl;
      req.tp          = entry - sl_pts * point * RR;
      req.symbol_slot = qm_magic_slot_offset;
      req.reason      = "asia-sweep-short";
      return true;
     }

   // Long: prev candle swept asiaLow and closed back above → fade the sweep
   if(prev_l < g_asia_low && prev_c > g_asia_low)
     {
      const double entry  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl     = prev_l - sl_buf;
      const double sl_pts = (entry - sl) / point;
      if(sl_pts <= 0.0)
         return false;
      req.type        = QM_BUY;
      req.price       = entry;
      req.sl          = sl;
      req.tp          = entry + sl_pts * point * RR;
      req.symbol_slot = qm_magic_slot_offset;
      req.reason      = "asia-sweep-long";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA.
void Strategy_ManageOpenPosition()
  {
   // Static SL/TP per trade; no active management for this strategy.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   // All exits via SL/TP; no time-based or signal-based discretionary exit.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;  // defer to QM_NewsAllowsTrade
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

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

   // Advance Asia range state before entry evaluation
   AdvanceAsiaRange();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
      if(out_ticket > 0)
         g_trades_today++;
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
