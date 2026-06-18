#property strict
#property version   "5.0"
#property description "QM5_1322 Connors RSI(2) FX-Port D1 Pullback Mean-Reversion"
// Build from card QM5_1322_connors-rsi2-fx-port-d1.md (build target ea_id=1322).
// NOTE: card frontmatter ea_id=QM5_12131 (stale); build target/qm_ea_id = 1322 per
// orchestrator instruction. Flagged as frontmatter mismatch in build report.
//
// Mechanic (all D1, closed bar = shift 1):
//   Macro trend gate : close > SMA(200) => BUY-eligible ; close < SMA(200) => SELL-eligible
//   RSI(2) trigger   : RSI(2) < 5  => BUY ; RSI(2) > 95 => SELL  (deep oversold/overbought)
//   Exit (primary)   : BUY close when RSI(2) > 50 ; SELL close when RSI(2) < 50
//   Exit (swing)     : BUY close when close > max(close[t-1..t-5]) ; SELL mirror
//   Exit (time-stop) : 8 D1 bars held without exit => market close
//   Stop loss        : entry -/+ 2.0*ATR(14,D1) hard SL (FX deviation from no-SL original)
//   Take profit      : 3.0*ATR cap, default OFF for P2 baseline
//   Cycle suppression: after a BUY, suppress new BUYs until RSI crosses back >50;
//                      after a SELL, suppress new SELLs until RSI crosses back <50.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1322;
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
input int    strategy_rsi_period         = 2;       // Connors RSI(2)
input double strategy_rsi_buy_thresh     = 5.0;     // RSI < this => BUY (deep oversold)
input double strategy_rsi_sell_thresh    = 95.0;    // RSI > this => SELL (deep overbought)
input double strategy_rsi_exit_mid       = 50.0;    // mean-reversion-complete exit threshold
input int    strategy_sma_period         = 200;     // macro-trend filter
input int    strategy_atr_period         = 14;      // ATR for stop sizing
input double strategy_atr_sl_mult        = 2.0;     // hard SL = N*ATR (P3-sweep 1.5-3.0)
input double strategy_atr_tp_mult        = 0.0;     // TP = N*ATR; 0 = OFF (P2 baseline)
input int    strategy_swing_lookback     = 5;       // swing high/low exit lookback (D1 bars)
input int    strategy_time_stop_days     = 8;       // max D1 bars held before time-stop close

// File-scope state ---------------------------------------------------------
datetime g_entry_day        = 0;     // D1 bar-open time when current position entered
bool     g_suppress_buy     = false; // cycle-suppression: block new BUYs until RSI>50
bool     g_suppress_sell    = false; // cycle-suppression: block new SELLs until RSI<50

int CurrentDir()
  {
   // +1 long, -1 short, 0 flat (for THIS EA's magic on THIS symbol)
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

void ClosePositionAll(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_ClosePosition(t, reason);
     }
  }

// Highest/lowest CLOSE over closes[t-1..t-lookback] (prior CLOSE, not range —
// .DWX gapless invariant #6). Returns false if history insufficient.
bool SwingHighClose(double &out_high)
  {
   double c[];
   ArraySetAsSeries(c, true);
   const int n = strategy_swing_lookback;
   if(n < 1)
      return false;
   if(CopyClose(_Symbol, PERIOD_D1, 1, n, c) != n)
      return false;
   double hi = c[0];
   for(int i = 1; i < n; ++i)
     {
      if(c[i] <= 0.0)
         return false;
      if(c[i] > hi)
         hi = c[i];
     }
   if(hi <= 0.0)
      return false;
   out_high = hi;
   return true;
  }

bool SwingLowClose(double &out_low)
  {
   double c[];
   ArraySetAsSeries(c, true);
   const int n = strategy_swing_lookback;
   if(n < 1)
      return false;
   if(CopyClose(_Symbol, PERIOD_D1, 1, n, c) != n)
      return false;
   double lo = c[0];
   for(int i = 1; i < n; ++i)
     {
      if(c[i] <= 0.0)
         return false;
      if(c[i] < lo)
         lo = c[i];
     }
   if(lo <= 0.0)
      return false;
   out_low = lo;
   return true;
  }

// --- No-Trade Filter (time, spread, news) --------------------------------
// Fail-OPEN spread guard per .DWX invariant #1: only block a genuinely WIDE
// spread; never block on zero spread (DWX quotes ask==bid in the tester).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double spread   = ask - bid;
      const double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      // Wide-spread guard: > 50 points absolute. Zero-spread (tester) passes.
      if(point > 0.0 && (spread / point) > 50.0)
         return true;
     }
   return false;
  }

// --- Trade Entry ----------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(CurrentDir() != 0)
      return false; // one position per magic

   const double rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double close_last = iClose(_Symbol, PERIOD_D1, 1);
   if(rsi <= 0.0 || sma <= 0.0 || close_last <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // BUY: established uptrend + deep oversold, cycle not suppressed.
   if(close_last > sma && rsi < strategy_rsi_buy_thresh && !g_suppress_buy)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = entry - strategy_atr_sl_mult * atr;
      if(sl <= 0.0 || sl >= entry)
         return false;
      double tp = 0.0;
      if(strategy_atr_tp_mult > 0.0)
         tp = entry + strategy_atr_tp_mult * atr;

      req.type               = QM_BUY;
      req.price              = 0.0;     // market
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "RSI2_BUY";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_entry_day    = iTime(_Symbol, PERIOD_D1, 0);
      g_suppress_buy = true;            // suppress until RSI crosses back >50
      return true;
     }

   // SELL: established downtrend + deep overbought, cycle not suppressed.
   if(close_last < sma && rsi > strategy_rsi_sell_thresh && !g_suppress_sell)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = entry + strategy_atr_sl_mult * atr;
      if(sl <= entry)
         return false;
      double tp = 0.0;
      if(strategy_atr_tp_mult > 0.0)
         tp = entry - strategy_atr_tp_mult * atr;
      if(strategy_atr_tp_mult > 0.0 && tp <= 0.0)
         tp = 0.0;

      req.type               = QM_SELL;
      req.price              = 0.0;     // market
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "RSI2_SELL";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_entry_day     = iTime(_Symbol, PERIOD_D1, 0);
      g_suppress_sell = true;           // suppress until RSI crosses back <50
      return true;
     }

   return false;
  }

// --- Trade Management -----------------------------------------------------
// Hard SL (and optional ATR TP) ride on the position from entry; no trailing
// per card. Nothing to adjust per-tick.
void Strategy_ManageOpenPosition()
  {
  }

// --- Trade Close ----------------------------------------------------------
// Primary RSI mean-reversion exit, swing high/low exit, and time-stop. Also
// releases cycle suppression once RSI crosses back through the mid (50).
bool Strategy_ExitSignal()
  {
   const double rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);

   // Cycle-suppression release (independent of any open position): once RSI
   // recovers past the mid, the oversold/overbought cycle is considered over
   // and a fresh entry in that direction may fire again.
   if(rsi > 0.0)
     {
      if(g_suppress_buy  && rsi > strategy_rsi_exit_mid)
         g_suppress_buy = false;
      if(g_suppress_sell && rsi < strategy_rsi_exit_mid)
         g_suppress_sell = false;
     }

   const int dir = CurrentDir();
   if(dir == 0)
      return false;

   if(rsi <= 0.0)
      return false;

   // Primary: RSI mean-reversion complete.
   if(dir > 0 && rsi > strategy_rsi_exit_mid)
     {
      ClosePositionAll(QM_EXIT_STRATEGY);
      return false;
     }
   if(dir < 0 && rsi < strategy_rsi_exit_mid)
     {
      ClosePositionAll(QM_EXIT_STRATEGY);
      return false;
     }

   // Swing high/low alternative exit (prior-CLOSE based, gapless-safe).
   const double close_last = iClose(_Symbol, PERIOD_D1, 1);
   if(close_last > 0.0)
     {
      if(dir > 0)
        {
         double swing_hi = 0.0;
         if(SwingHighClose(swing_hi) && close_last > swing_hi)
           {
            ClosePositionAll(QM_EXIT_STRATEGY);
            return false;
           }
        }
      else
        {
         double swing_lo = 0.0;
         if(SwingLowClose(swing_lo) && close_last < swing_lo)
           {
            ClosePositionAll(QM_EXIT_STRATEGY);
            return false;
           }
        }
     }

   // Time-stop: held >= N D1 bars without completion.
   if(g_entry_day > 0)
     {
      const int held = (int)((iTime(_Symbol, PERIOD_D1, 0) - g_entry_day) / 86400);
      if(held >= strategy_time_stop_days)
        {
         ClosePositionAll(QM_EXIT_TIME_STOP);
         return false;
        }
     }

   return false;
  }

// --- News Filter Hook (callable for Q09 News Impact phase) ----------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to central QM_NewsAllowsTrade
  }

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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1322\",\"strategy\":\"connors-rsi2-fx-port-d1\"}");
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
   Strategy_ExitSignal();

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
