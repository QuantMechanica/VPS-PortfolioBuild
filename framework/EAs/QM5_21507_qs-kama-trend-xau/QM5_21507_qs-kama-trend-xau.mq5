#property strict
#property version   "5.0"
#property description "QM5_21507 XAUUSD Kaufman Adaptive Moving Average (KAMA) Trend Strategy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_21507 - XAUUSD KAMA Trend Strategy
// -----------------------------------------------------------------------------
// Source: QuantifiedStrategies.com "Adaptive Moving Average Trading Strategy"
// Implementation:
//   - Native XAUUSD.DWX D1 bars only; no external feed, no ML.
//   - Kaufman Adaptive Moving Average (KAMA) computed on completed D1 closes.
//   - Long entry: Close[1] > KAMA[1] and KAMA[1] > KAMA[2] (up-slope confirmation).
//   - Short entry: Close[1] < KAMA[1] and KAMA[1] < KAMA[2] (down-slope confirmation).
//   - Flat slope (KAMA[1] == KAMA[2]) blocks new entries.
//   - Trend-failure exit: Close[1] recrosses KAMA[1] against position.
//   - Fixed hard SL: strategy_atr_sl_mult * ATR(strategy_atr_period, D1).
//   - Max-hold exit: strategy_max_hold_bars (default 60 D1 bars).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 21507;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

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
input int    strategy_er_period          = 10;
input int    strategy_fast_ema           = 2;
input int    strategy_slow_ema           = 30;
input int    strategy_warmup_buffer      = 10;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_max_hold_bars      = 60;
input int    strategy_max_spread_points  = 300;

// Cached strategy state (updated once per closed D1 bar)
bool   g_kama_valid  = false;
double g_kama_1      = 0.0;
double g_kama_2      = 0.0;
double g_close_1     = 0.0;
double g_cached_atr  = 0.0;

// -----------------------------------------------------------------------------
// Helper: calculate KAMA and cache bar state
// -----------------------------------------------------------------------------

bool Strategy_CalculateKAMA(double &out_kama_1, double &out_kama_2, double &out_close_1)
  {
   out_kama_1 = 0.0;
   out_kama_2 = 0.0;
   out_close_1 = 0.0;

   const int er_period = MathMax(2, strategy_er_period);
   const int fast_p    = MathMax(1, strategy_fast_ema);
   const int slow_p    = MathMax(fast_p + 1, strategy_slow_ema);
   const int warmup    = MathMax(5, strategy_warmup_buffer);

   const int bars_total_needed = MathMax(er_period + slow_p + warmup, slow_p * 3 + er_period);

   double closes[];
   ArrayResize(closes, bars_total_needed + 1);
   ArraySetAsSeries(closes, true);

   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, bars_total_needed + 1, closes); // perf-allowed: bounded D1 vector behind QM_IsNewBar
   if(copied < bars_total_needed + 1)
      return false;

   out_close_1 = closes[0];

   const double fast_sc = 2.0 / (double)(fast_p + 1);
   const double slow_sc = 2.0 / (double)(slow_p + 1);

   const int start_k = copied - 1 - er_period;
   if(start_k < 2)
      return false;

   double current_kama = closes[start_k + 1];

   for(int k = start_k; k >= 0; --k)
     {
      const double change = MathAbs(closes[k] - closes[k + er_period]);
      double volatility = 0.0;
      for(int i = 0; i < er_period; ++i)
         volatility += MathAbs(closes[k + i] - closes[k + i + 1]);

      double er = 0.0;
      if(volatility > 0.0)
        {
         er = change / volatility;
         if(er > 1.0) er = 1.0;
         if(er < 0.0) er = 0.0;
        }

      const double sc = MathPow(er * (fast_sc - slow_sc) + slow_sc, 2.0);
      current_kama = current_kama + sc * (closes[k] - current_kama);

      if(k == 1)
         out_kama_2 = current_kama;
      else if(k == 0)
         out_kama_1 = current_kama;
     }

   return (out_kama_1 > 0.0 && out_kama_2 > 0.0 &&
           MathIsValidNumber(out_kama_1) && MathIsValidNumber(out_kama_2));
  }

void AdvanceState_OnNewBar()
  {
   g_kama_valid = Strategy_CalculateKAMA(g_kama_1, g_kama_2, g_close_1);
   if(g_kama_valid)
      g_cached_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   else
      g_cached_atr = 0.0;
  }

bool Strategy_HasOwnedPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XAUUSD.DWX" || _Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 21507 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_er_period < 2 || strategy_fast_ema < 1 || strategy_slow_ema <= strategy_fast_ema)
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_bars <= 0 || strategy_max_spread_points <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_21507_KAMA_TREND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_kama_valid)
      return false;
   if(g_cached_atr <= 0.0 || !MathIsValidNumber(g_cached_atr))
      return false;

   // Check spread cap
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 || spread_points > strategy_max_spread_points)
      return false;

   // Direction logic:
   // Long: Close[1] > KAMA[1] && KAMA[1] > KAMA[2]
   // Short: Close[1] < KAMA[1] && KAMA[1] < KAMA[2]
   // Flat slope blocks entry.
   int direction = 0;
   if(g_close_1 > g_kama_1 && g_kama_1 > g_kama_2)
      direction = 1;
   else if(g_close_1 < g_kama_1 && g_kama_1 < g_kama_2)
      direction = -1;
   else
      return false;

   // Fresh-state management must close an opposite position before entry;
   // same-direction means hold. Any owned position that remains blocks entry.
   if(Strategy_HasOwnedPosition())
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                g_cached_atr,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.tp = 0.0;
   req.reason = (direction > 0) ? "KAMA_TREND_LONG" : "KAMA_TREND_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const string position_symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int completed_bars = (opened > 0) ? iBarShift(_Symbol, PERIOD_D1, opened, false) : -1;

      bool should_close = false;
      if(position_symbol != "XAUUSD.DWX")
         should_close = true;
      if(position_type != POSITION_TYPE_BUY && position_type != POSITION_TYPE_SELL)
         should_close = true;
      if(opened <= 0 || completed_bars < 0)
         should_close = true;

      // Max-hold exit
      if(completed_bars >= strategy_max_hold_bars)
         should_close = true;

      // Trend-failure exit: price recrosses KAMA line against held position
      if(g_kama_valid)
        {
         if(position_type == POSITION_TYPE_BUY && g_close_1 < g_kama_1)
            should_close = true;
         else if(position_type == POSITION_TYPE_SELL && g_close_1 > g_kama_1)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   g_kama_valid = false;
   g_kama_1     = 0.0;
   g_kama_2     = 0.0;
   g_close_1    = 0.0;
   g_cached_atr = 0.0;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_21507\",\"ea\":\"qs-kama-trend-xau\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   AdvanceState_OnNewBar();

   // Re-run management against the freshly prepared D1 state. A failed or
   // unsettled opposite close remains fail-closed at Strategy_EntrySignal.
   Strategy_ManageOpenPosition();

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
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
