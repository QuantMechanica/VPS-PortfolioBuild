#property strict
#property version   "5.0"
#property description "QM5_9361 Ichimoku Kumo Bounce with ADX/DI (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9361 — Ichimoku Kumo Bounce (M30)
// Source: Stephen Njuki, MQL5 Wizard Techniques Part 73 (Pattern 3)
// Three-bar cloud-bounce with ADX/DI trend confirmation
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9361;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_ichi_tenkan    = 9;     // Ichimoku Tenkan-sen period
input int    strategy_ichi_kijun     = 26;    // Ichimoku Kijun-sen / Senkou offset
input int    strategy_ichi_senkou_b  = 52;    // Ichimoku Senkou Span B lookback
input int    strategy_adx_period     = 14;    // ADX / DI period
input double strategy_adx_threshold  = 25.0;  // Minimum ADX to trade
input double strategy_sl_atr_mult    = 0.5;   // ATR multiplier beyond Senkou B for SL
input int    strategy_time_exit_bars = 64;    // Time-exit after N closed M30 bars

// =============================================================================
// Ichimoku helpers — bespoke structural logic; no QM_ wrapper exists for Ichi.
// All bar reads are perf-allowed: called only inside the QM_IsNewBar() gate.
// =============================================================================

double IchiTenkan(const int k)
  {
   // perf-allowed: Ichimoku structural logic, once per closed bar
   double hi = iHigh(_Symbol, _Period, k);
   double lo = iLow(_Symbol, _Period, k);
   for(int j = 1; j < strategy_ichi_tenkan; j++)
     {
      const double h = iHigh(_Symbol, _Period, k + j);
      const double l = iLow(_Symbol, _Period, k + j);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
     }
   return (hi + lo) * 0.5;
  }

double IchiKijun(const int k)
  {
   // perf-allowed: Ichimoku structural logic, once per closed bar
   double hi = iHigh(_Symbol, _Period, k);
   double lo = iLow(_Symbol, _Period, k);
   for(int j = 1; j < strategy_ichi_kijun; j++)
     {
      const double h = iHigh(_Symbol, _Period, k + j);
      const double l = iLow(_Symbol, _Period, k + j);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
     }
   return (hi + lo) * 0.5;
  }

// Senkou Span A applicable at framework shift s
// (Tenkan + Kijun computed kijun_period bars before s, projected forward 26)
double IchiSenkouA(const int s)
  {
   return (IchiTenkan(s + strategy_ichi_kijun) + IchiKijun(s + strategy_ichi_kijun)) * 0.5;
  }

// Senkou Span B applicable at framework shift s
double IchiSenkouB(const int s)
  {
   // perf-allowed: Ichimoku structural logic, once per closed bar
   const int k = s + strategy_ichi_kijun;
   double hi = iHigh(_Symbol, _Period, k);
   double lo = iLow(_Symbol, _Period, k);
   for(int j = 1; j < strategy_ichi_senkou_b; j++)
     {
      const double h = iHigh(_Symbol, _Period, k + j);
      const double l = iLow(_Symbol, _Period, k + j);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
     }
   return (hi + lo) * 0.5;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Called only after QM_IsNewBar() — handles both bar-close exit checks and
// entry evaluation for the three-bar Kumo bounce pattern.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // --- Read Ichimoku & price data (perf-allowed: once per closed bar) ---
   // Framework shift 1 = last completed bar = article notation [0]
   // Framework shift 2 = article [1];  shift 3 = article [2]
   const double c0  = iClose(_Symbol, _Period, 1); // article Close[0]
   const double c1  = iClose(_Symbol, _Period, 2); // article Close[1]
   const double c2  = iClose(_Symbol, _Period, 3); // article Close[2]

   const double ssa0 = IchiSenkouA(1); // Senkou A at article [0]
   const double ssa1 = IchiSenkouA(2); // Senkou A at article [1]
   const double ssa2 = IchiSenkouA(3); // Senkou A at article [2]
   const double ssb0 = IchiSenkouB(1); // Senkou B at article [0]

   if(c0 <= 0.0 || ssa0 <= 0.0 || ssb0 <= 0.0)
      return false;

   const double adx_val     = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double diplus_val  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double diminus_val = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);

   const int magic = QM_FrameworkMagic();

   // --- Bar-close exit check for open position ---
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))                   continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)       continue;

      const bool is_long   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const datetime o_time = (datetime)PositionGetInteger(POSITION_TIME);

      // perf-allowed: bar-count for time exit, once per closed bar
      const int bars_elapsed = iBarShift(_Symbol, _Period, o_time, false);

      bool should_exit = false;

      if(bars_elapsed >= strategy_time_exit_bars)
         should_exit = true;

      // Close back through Senkou A against trade
      if(is_long  && c0 < ssa0) should_exit = true;
      if(!is_long && c0 > ssa0) should_exit = true;

      // Opposite Pattern 3 signal exit
      if(is_long)
        {
         // Exit long when sell pattern fires
         if(c2 < c1 && c1 > c0 &&
            c2 < ssa2 && c0 < ssa0 && c1 >= ssa1 &&
            diplus_val < diminus_val && adx_val >= strategy_adx_threshold)
            should_exit = true;
        }
      else
        {
         // Exit short when buy pattern fires
         if(c2 > c1 && c1 < c0 &&
            c2 > ssa2 && c0 > ssa0 && c1 <= ssa1 &&
            diplus_val > diminus_val && adx_val >= strategy_adx_threshold)
            should_exit = true;
        }

      if(should_exit)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }

   // --- One-position guard ---
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))                   continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   // --- Three-bar cloud-bounce entry evaluation ---
   // Buy: V-pattern (c2 high, c1 dips into cloud, c0 recovers above cloud) + DI+ > DI-
   const bool buy_signal = (c2 > c1  && c1 < c0 &&
                             c2 > ssa2 && c0 > ssa0 && c1 <= ssa1 &&
                             diplus_val > diminus_val && adx_val >= strategy_adx_threshold);

   // Sell: inverted-V (c2 low, c1 spikes into cloud, c0 drops below cloud) + DI- > DI+
   const bool sell_signal = (c2 < c1  && c1 > c0 &&
                              c2 < ssa2 && c0 < ssa0 && c1 >= ssa1 &&
                              diplus_val < diminus_val && adx_val >= strategy_adx_threshold);

   if(!buy_signal && !sell_signal)
      return false;

   // --- Stop loss: Senkou B ± 0.5 × ATR(14) ---
   const double atr = QM_ATR(_Symbol, _Period, strategy_adx_period, 1);

   double sl_price;
   if(buy_signal)
     {
      sl_price = ssb0 - strategy_sl_atr_mult * atr;
      if(sl_price >= c0) return false; // degenerate: Senkou B above entry
     }
   else
     {
      sl_price = ssb0 + strategy_sl_atr_mult * atr;
      if(sl_price <= c0) return false; // degenerate: Senkou B below entry
     }

   req.type             = buy_signal ? QM_BUY : QM_SELL;
   req.price            = 0.0;
   req.sl               = sl_price;
   req.tp               = 0.0;
   req.reason           = buy_signal ? "ichi_kumo_bounce_long" : "ichi_kumo_bounce_short";
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card: no trailing / BE specified. SL-only position management.
  }

bool Strategy_ExitSignal()
  {
   // All exits are bar-close based and handled inside Strategy_EntrySignal.
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade
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
