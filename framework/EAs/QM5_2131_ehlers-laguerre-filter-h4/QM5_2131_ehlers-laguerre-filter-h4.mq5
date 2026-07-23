#property strict
#property version   "5.0"
#property description "QM5_2131 Ehlers Laguerre Filter H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2131;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_gamma              = 0.80;
input bool   strategy_use_typical_price  = false;
input int    strategy_atr_period         = 20;
input double strategy_cross_atr_mult     = 0.30;
input int    strategy_d1_ema_period      = 50;
input int    strategy_warmup_h4_bars     = 200;
input double strategy_initial_stop_atr   = 0.50;
input double strategy_trail_trigger_atr  = 1.50;
input double strategy_trail_atr_mult     = 2.50;
input int    strategy_time_stop_h4_bars  = 80;
input int    strategy_cross_throttle_bars = 3;
input double strategy_spread_atr_mult    = 0.30;

// Card §"Mechanik": LF[0..-3] + Close[0..-1] cache, refreshed exactly once per
// closed H4 bar (from AdvanceState_OnNewBar, gated by the single OnTick
// QM_IsNewBar() call). RECENT_BARS=12 gives headroom for the 3-bar throttle
// scan plus the LF[-3] filter-reversal lookback.
#define QM2131_RECENT_BARS 12

double   g_laguerre_lf[QM2131_RECENT_BARS];
double   g_laguerre_close[QM2131_RECENT_BARS];
double   g_laguerre_high[QM2131_RECENT_BARS];
double   g_laguerre_low[QM2131_RECENT_BARS];
bool     g_laguerre_ready = false;

// Cached once per closed bar in AdvanceState_OnNewBar; all per-tick paths
// (NoTradeFilter / ManageOpenPosition / EntrySignal) read these only.
double   g_atr20    = 0.0;
double   g_d1_ema50 = 0.0;

// Card §"Exit": "LF[0]<LF[-3] AND LF[-1]<LF[-2] for 2 consecutive H4 bars".
// Latched once per bar so the exit check can require the streak, not just
// the single-bar condition.
int      g_reversal_down_streak = 0;
int      g_reversal_up_streak   = 0;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

bool FindOurPosition(ulong &ticket,
                     ENUM_POSITION_TYPE &position_type,
                     double &open_price,
                     datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

// Card §"Mechanik" Step 2-3: 4-stage Laguerre IIR cascade + 1:2:2:1 weighted
// output, reconstructed over a bounded lookback so the filter is fully
// settled (Ehlers 2014 p.65 fig.4.3 ~60-bar settling) at every read. Called
// exactly once per closed H4 bar — the caller (OnTick) gates this behind its
// own single QM_IsNewBar() check; this function performs NO bar-timestamp
// gating of its own (framework corset: QM_IsNewBar is the only sanctioned
// new-bar detector, never a hand-rolled iTime/g_last_bar comparison).
void AdvanceState_OnNewBar()
  {
   const int gamma_warmup = MathMax(60, strategy_warmup_h4_bars);
   const int count = MathMax(gamma_warmup, strategy_atr_period + 60) + QM2131_RECENT_BARS + 4;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H4, 1, count, rates) != count) // perf-allowed: bounded Laguerre reconstruction, cached once per closed H4 bar via the OnTick QM_IsNewBar() gate.
     {
      g_laguerre_ready = false;
      return;
     }

   const double gamma = MathMax(0.0, MathMin(0.99, strategy_gamma));
   double l0 = 0.0, l1 = 0.0, l2 = 0.0, l3 = 0.0;

   for(int i = count - 1; i >= 0; --i)
     {
      const double price = strategy_use_typical_price
                           ? ((rates[i].high + rates[i].low + rates[i].close) / 3.0)
                           : rates[i].close;
      if(price <= 0.0)
        {
         g_laguerre_ready = false;
         return;
        }

      if(i == count - 1)
        {
         l0 = price;
         l1 = price;
         l2 = price;
         l3 = price;
        }
      else
        {
         const double old_l0 = l0;
         const double old_l1 = l1;
         const double old_l2 = l2;
         const double old_l3 = l3;
         l0 = (1.0 - gamma) * price + gamma * old_l0;
         l1 = -gamma * l0 + old_l0 + gamma * old_l1;
         l2 = -gamma * l1 + old_l1 + gamma * old_l2;
         l3 = -gamma * l2 + old_l2 + gamma * old_l3;
        }

      if(i < QM2131_RECENT_BARS)
        {
         g_laguerre_lf[i] = (l0 + 2.0 * l1 + 2.0 * l2 + l3) / 6.0;
         g_laguerre_close[i] = rates[i].close;
         g_laguerre_high[i] = rates[i].high;
         g_laguerre_low[i] = rates[i].low;
        }
     }

   g_laguerre_ready = true;

   g_atr20    = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   g_d1_ema50 = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1, PRICE_CLOSE);

   // Card §"Exit" filter-direction-reversal streak (2 consecutive H4 bars).
   if(g_laguerre_lf[0] < g_laguerre_lf[3] && g_laguerre_lf[1] < g_laguerre_lf[2])
      g_reversal_down_streak = MathMin(g_reversal_down_streak + 1, 2);
   else
      g_reversal_down_streak = 0;

   if(g_laguerre_lf[0] > g_laguerre_lf[3] && g_laguerre_lf[1] > g_laguerre_lf[2])
      g_reversal_up_streak = MathMin(g_reversal_up_streak + 1, 2);
   else
      g_reversal_up_streak = 0;
  }

// Cross direction of Close vs LF at cached offset `offset` (0=current closed
// bar, 1=one bar back, ...). Reads the AdvanceState_OnNewBar cache only.
int CrossDirectionAtOffset(const int offset)
  {
   if(!g_laguerre_ready)
      return 0;
   if(offset < 0 || offset + 1 >= QM2131_RECENT_BARS)
      return 0;

   const double close_now = g_laguerre_close[offset];
   const double close_prev = g_laguerre_close[offset + 1];
   const double lf_now = g_laguerre_lf[offset];
   const double lf_prev = g_laguerre_lf[offset + 1];
   if(close_prev <= lf_prev && close_now > lf_now)
      return 1;
   if(close_prev >= lf_prev && close_now < lf_now)
      return -1;
   return 0;
  }

// Card §"Zusätzliche Filter" cross-frequency throttle: skip entry if ANY
// cross (either direction) fired in the strategy_cross_throttle_bars bars
// before this one (offset 0 is this bar's own triggering cross and is
// deliberately excluded from the scan).
bool RecentCrossThrottleBlocks()
  {
   const int bars = MathMin(MathMax(0, strategy_cross_throttle_bars), QM2131_RECENT_BARS - 2);
   for(int offset = 1; offset <= bars; ++offset)
      if(CrossDirectionAtOffset(offset) != 0)
         return true;
   return false;
  }

double ExtremeSinceEntry(const ENUM_POSITION_TYPE position_type, const datetime open_time)
  {
   double extreme = 0.0;
   const int max_scan = MathMax(2, strategy_time_stop_h4_bars + 4);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded trailing-stop scan over H4 bars since entry.
      if(bar_time <= 0)
         break;
      if(open_time > 0 && bar_time < open_time)
         break;

      if(position_type == POSITION_TYPE_BUY)
        {
         const double high = iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded trailing-stop highest-high since entry.
         if(high > 0.0 && (extreme <= 0.0 || high > extreme))
            extreme = high;
        }
      else
        {
         const double low = iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded trailing-stop lowest-low since entry.
         if(low > 0.0 && (extreme <= 0.0 || low < extreme))
            extreme = low;
        }
     }

   return extreme;
  }

bool Strategy_NoTradeFilter()
  {
   // Blocks until the first AdvanceState_OnNewBar() has populated the cache
   // (start-of-run cold state) and whenever the reconstruction fails.
   if(!g_laguerre_ready || g_atr20 <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   // Card §"Zusätzliche Filter": skip if spread > 0.30 x ATR(20,H4). .DWX
   // quotes ask==bid (0 spread) in the tester, so this never fails-closed on
   // a genuinely zero spread — only a real wide spread blocks.
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * g_atr20)
      return true;

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

   if(_Period != PERIOD_H4)
      return false;
   if(!g_laguerre_ready || g_atr20 <= 0.0 || g_d1_ema50 <= 0.0)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(RecentCrossThrottleBlocks())
      return false;

   const double close_0 = g_laguerre_close[0];
   const double close_1 = g_laguerre_close[1];
   const double lf_0 = g_laguerre_lf[0];
   const double lf_1 = g_laguerre_lf[1];
   const double lf_2 = g_laguerre_lf[2];

   // Card §"Entry" rule 1: fresh Close/LF cross.
   const bool cross_up = (close_1 <= lf_1 && close_0 > lf_0);
   const bool cross_down = (close_1 >= lf_1 && close_0 < lf_0);

   // Card §"Entry" Long: cross magnitude >= 0.3xATR, filter trending up
   // (LF[0]>LF[-2]), D1 regime aligned long.
   if(cross_up &&
      close_0 - lf_0 >= strategy_cross_atr_mult * g_atr20 &&
      lf_0 > lf_2 &&
      close_0 > g_d1_ema50)
     {
      req.type = QM_BUY;
      req.sl = NormalizeStrategyPrice(g_laguerre_low[0] - strategy_initial_stop_atr * g_atr20);
      req.reason = "LAGUERRE_PRICE_UP_CROSS";
      return (req.sl > 0.0);
     }

   // Card §"Entry" Short: mirror.
   if(cross_down &&
      lf_0 - close_0 >= strategy_cross_atr_mult * g_atr20 &&
      lf_0 < lf_2 &&
      close_0 < g_d1_ema50)
     {
      req.type = QM_SELL;
      req.sl = NormalizeStrategyPrice(g_laguerre_high[0] + strategy_initial_stop_atr * g_atr20);
      req.reason = "LAGUERRE_PRICE_DOWN_CROSS";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(g_atr20 <= 0.0 || point <= 0.0 || open_price <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   // Card §"Exit" ATR trailing-stop: only switches on after a 1.5xATR
   // favorable move; trails at 2.5xATR from the highest-high (longs) /
   // lowest-low (shorts) since entry.
   const double favorable_move = is_buy ? (market - open_price) : (open_price - market);
   if(favorable_move < strategy_trail_trigger_atr * g_atr20)
      return;

   const double extreme = ExtremeSinceEntry(position_type, open_time);
   if(extreme <= 0.0)
      return;

   const double target_sl = NormalizeStrategyPrice(is_buy ? (extreme - strategy_trail_atr_mult * g_atr20)
                                                          : (extreme + strategy_trail_atr_mult * g_atr20));
   if(target_sl <= 0.0)
      return;

   const double current_sl = PositionGetDouble(POSITION_SL);
   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (target_sl > current_sl + point * 0.5)
                                 : (target_sl < current_sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, target_sl, "laguerre_high_low_atr_trail");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, open_price, open_time))
      return false;

   // Card §"Exit" time-stop: 80 H4 bars (~2 weeks). Restart-safe held-period
   // count via the framework helper (walks the real bar series off
   // POSITION_TIME) instead of a hand-rolled bar counter; -1 ("unknown")
   // never satisfies >= strategy_time_stop_h4_bars, so it is never "due".
   const int held = QM_TM_HeldPeriodsForMagic(QM_FrameworkMagic(), _Symbol, PERIOD_H4);
   if(held >= strategy_time_stop_h4_bars)
      return true;

   if(!g_laguerre_ready)
      return false;

   const double close_0 = g_laguerre_close[0];
   const double close_1 = g_laguerre_close[1];
   const double lf_0 = g_laguerre_lf[0];
   const double lf_1 = g_laguerre_lf[1];

   // Card §"Exit" opposite-cross (primary reversal signal).
   const bool cross_up = (close_1 <= lf_1 && close_0 > lf_0);
   const bool cross_down = (close_1 >= lf_1 && close_0 < lf_0);
   if(position_type == POSITION_TYPE_BUY && cross_down)
      return true;
   if(position_type == POSITION_TYPE_SELL && cross_up)
      return true;

   // Card §"Exit" filter-direction-reversal: LF[0]<LF[-3] AND LF[-1]<LF[-2]
   // (mirror for shorts) held for 2 CONSECUTIVE H4 bars — the streak is
   // latched once per bar in AdvanceState_OnNewBar.
   if(position_type == POSITION_TYPE_BUY && g_reversal_down_streak >= 2)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_reversal_up_streak >= 2)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the central QM_NewsAllowsTrade[2] check below
  }

int OnInit()
  {
   if(_Period != PERIOD_H4 && MQLInfoInteger(MQL_TESTER) == 0)
      Print("QM5_2131 expects H4 chart period.");

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

   g_laguerre_ready = false;
   g_atr20 = 0.0;
   g_d1_ema50 = 0.0;
   g_reversal_down_streak = 0;
   g_reversal_up_streak = 0;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_2131\",\"strategy\":\"ehlers_laguerre_filter_h4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard
   // can return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the 2-axis news gate below blocks NEW
   // entries only (2026-07-02 audit rule; canonical order per EA_Skeleton.mq5).
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FIRST: advance the closed-bar Laguerre/ATR/EMA cache for the bar that
   // just closed — the only new-bar detector call in this EA (single-consume
   // per DWX invariant #3).
   AdvanceState_OnNewBar();

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
