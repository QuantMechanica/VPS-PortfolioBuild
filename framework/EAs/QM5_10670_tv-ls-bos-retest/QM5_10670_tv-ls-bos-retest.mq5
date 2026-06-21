#property strict
#property version   "5.0"
#property description "QM5_10670 TradingView Liquidity Sweep BOS Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10670;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pivot_left             = 3;
input int    strategy_pivot_right            = 3;
input int    strategy_pivot_lookback         = 48;
// 96 bars = 24h on M15, allows cross-session sweep→BOS→retest sequences.
input int    strategy_setup_timeout_bars     = 96;
input double strategy_displacement_body_min  = 0.55;
input double strategy_displacement_edge_max  = 0.30;
input double strategy_retest_edge_max        = 0.35;
input int    strategy_atr_period             = 14;
input double strategy_atr_stop_buffer_mult   = 0.10;
input double strategy_max_stop_atr           = 2.50;
input double strategy_rr_target              = 2.00;
// Session gate applies only to retest entry; sweep+BOS detection is all-bar.
input bool   strategy_session_filter_enabled = true;
input int    strategy_session_start_hhmm_broker = 1530;
input int    strategy_session_end_hhmm_broker   = 1700;
input int    strategy_max_spread_points      = 200;

int Hhmm(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 100 + dt.min;
  }

int ClampHhmm(const int value)
  {
   int hhmm = value;
   if(hhmm < 0)
      hhmm = 0;
   if(hhmm > 2359)
      hhmm = 2359;
   int hour = hhmm / 100;
   int minute = hhmm % 100;
   if(hour > 23)
      hour = 23;
   if(minute > 59)
      minute = 59;
   return hour * 100 + minute;
  }

bool IsInBrokerSession(const datetime broker_time)
  {
   if(!strategy_session_filter_enabled)
      return true;

   const int start_hhmm = ClampHhmm(strategy_session_start_hhmm_broker);
   const int end_hhmm   = ClampHhmm(strategy_session_end_hhmm_broker);
   if(start_hhmm == end_hhmm)
      return true;

   const int now_hhmm = Hhmm(broker_time);
   if(start_hhmm < end_hhmm)
      return (now_hhmm >= start_hhmm && now_hhmm < end_hhmm);
   return (now_hhmm >= start_hhmm || now_hhmm < end_hhmm);
  }

bool SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   // DWX tester: ask==bid (zero spread) is normal; only block a genuinely wide spread.
   if(ask > bid && ((ask - bid) / point) > (double)strategy_max_spread_points)
      return false;
   return true;
  }

// perf-allowed: bespoke closed-bar swing/sweep/BOS structure needs raw OHLC.
// Called only from Strategy_EntrySignal (post QM_IsNewBar gate), once per bar.
double BarHigh(const int shift)  { return iHigh(_Symbol, _Period, shift); }  // perf-allowed
double BarLow(const int shift)   { return iLow(_Symbol, _Period, shift);  }  // perf-allowed
double BarOpen(const int shift)  { return iOpen(_Symbol, _Period, shift); }  // perf-allowed
double BarClose(const int shift) { return iClose(_Symbol, _Period, shift);}  // perf-allowed
int    BarCount()                { return Bars(_Symbol, _Period);          }  // perf-allowed

bool FindConfirmedPivotHigh(double &pivot_high)
  {
   pivot_high = 0.0;
   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 || strategy_pivot_lookback < 8)
      return false;

   const int first_shift = 2 + strategy_pivot_right;
   const int last_shift  = strategy_pivot_lookback;
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      const double candidate = BarHigh(shift);
      if(candidate <= 0.0)
         continue;

      bool valid = true;
      for(int j = 1; valid && j <= strategy_pivot_left; ++j)
         if(BarHigh(shift + j) >= candidate)
            valid = false;
      for(int j = 1; valid && j <= strategy_pivot_right; ++j)
         if(BarHigh(shift - j) > candidate)
            valid = false;

      if(valid)
        {
         pivot_high = candidate;
         return true;
        }
     }
   return false;
  }

bool FindConfirmedPivotLow(double &pivot_low)
  {
   pivot_low = 0.0;
   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 || strategy_pivot_lookback < 8)
      return false;

   const int first_shift = 2 + strategy_pivot_right;
   const int last_shift  = strategy_pivot_lookback;
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      const double candidate = BarLow(shift);
      if(candidate <= 0.0)
         continue;

      bool valid = true;
      for(int j = 1; valid && j <= strategy_pivot_left; ++j)
         if(BarLow(shift + j) <= candidate)
            valid = false;
      for(int j = 1; valid && j <= strategy_pivot_right; ++j)
         if(BarLow(shift - j) < candidate)
            valid = false;

      if(valid)
        {
         pivot_low = candidate;
         return true;
        }
     }
   return false;
  }

bool BullishDisplacement(const double level)
  {
   const double open1  = BarOpen(1);
   const double high1  = BarHigh(1);
   const double low1   = BarLow(1);
   const double close1 = BarClose(1);
   const double range  = high1 - low1;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range <= 0.0)
      return false;

   const double body_ratio  = MathAbs(close1 - open1) / range;
   const double upper_edge  = (high1 - close1) / range;
   return (close1 > open1 &&
           close1 > level &&
           body_ratio >= strategy_displacement_body_min &&
           upper_edge <= strategy_displacement_edge_max);
  }

bool BearishDisplacement(const double level)
  {
   const double open1  = BarOpen(1);
   const double high1  = BarHigh(1);
   const double low1   = BarLow(1);
   const double close1 = BarClose(1);
   const double range  = high1 - low1;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range <= 0.0)
      return false;

   const double body_ratio = MathAbs(close1 - open1) / range;
   const double lower_edge = (close1 - low1) / range;
   return (close1 < open1 &&
           close1 < level &&
           body_ratio >= strategy_displacement_body_min &&
           lower_edge <= strategy_displacement_edge_max);
  }

bool BullishRetest(const double bos_level)
  {
   const double open1  = BarOpen(1);
   const double high1  = BarHigh(1);
   const double low1   = BarLow(1);
   const double close1 = BarClose(1);
   const double range  = high1 - low1;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range <= 0.0)
      return false;

   const double upper_edge = (high1 - close1) / range;
   return (low1 <= bos_level &&
           close1 > bos_level &&
           close1 > open1 &&
           upper_edge <= strategy_retest_edge_max);
  }

bool BearishRetest(const double bos_level)
  {
   const double open1  = BarOpen(1);
   const double high1  = BarHigh(1);
   const double low1   = BarLow(1);
   const double close1 = BarClose(1);
   const double range  = high1 - low1;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range <= 0.0)
      return false;

   const double lower_edge = (close1 - low1) / range;
   return (high1 >= bos_level &&
           close1 < bos_level &&
           close1 < open1 &&
           lower_edge <= strategy_retest_edge_max);
  }

void ResetSetup(int &setup_state, int &setup_age, double &setup_swept, double &setup_bos)
  {
   setup_state = 0;
   setup_age   = 0;
   setup_swept = 0.0;
   setup_bos   = 0.0;
  }

void ClearRequest(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildTrade(QM_EntryRequest &req,
                const QM_OrderType side,
                const double swept_price,
                const double entry_price,
                const string reason)
  {
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_stop_buffer_mult < 0.0 ||
      strategy_max_stop_atr <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   double sl = 0.0;
   if(side == QM_BUY)
      sl = QM_StopRulesNormalizePrice(_Symbol, swept_price - atr * strategy_atr_stop_buffer_mult);
   else
      sl = QM_StopRulesNormalizePrice(_Symbol, swept_price + atr * strategy_atr_stop_buffer_mult);

   if(entry_price <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY  && sl >= entry_price)
      return false;
   if(side == QM_SELL && sl <= entry_price)
      return false;

   if(MathAbs(entry_price - sl) > atr * strategy_max_stop_atr)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry_price, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;
   if(side == QM_BUY  && tp <= entry_price)
      return false;
   if(side == QM_SELL && tp >= entry_price)
      return false;

   req.type   = side;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// Spread-only filter. Session filter is NOT here — it applies only to the
// retest entry inside Strategy_EntrySignal, so the sweep+BOS state machine
// can advance on all closed bars regardless of session.
bool Strategy_NoTradeFilter()
  {
   return !SpreadAllowed();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ClearRequest(req);

   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 ||
      strategy_pivot_lookback < 8 || strategy_setup_timeout_bars < 1)
      return false;
   if(strategy_displacement_body_min < 0.0 || strategy_displacement_body_min > 1.0 ||
      strategy_displacement_edge_max < 0.0 || strategy_displacement_edge_max > 1.0 ||
      strategy_retest_edge_max < 0.0 || strategy_retest_edge_max > 1.0)
      return false;

   const int min_bars = strategy_pivot_lookback + strategy_pivot_left + strategy_pivot_right + 10;
   if(BarCount() < min_bars)
      return false;

   // State machine (runs every closed bar regardless of session):
   //   0  = looking for new sweep setup
   //   1  = sweep detected, waiting for bullish BOS displacement
   //   2  = BOS confirmed, waiting for bullish retest entry (session-gated)
   //  -1  = sweep detected, waiting for bearish BOS displacement
   //  -2  = BOS confirmed, waiting for bearish retest entry (session-gated)
   static int    setup_state      = 0;
   static int    setup_age        = 0;
   static double setup_swept      = 0.0;
   static double setup_bos        = 0.0;
   static double used_long_sweep  = 0.0;
   static double used_short_sweep = 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   // Advance age on every bar; expire stale setups.
   if(setup_state != 0)
     {
      setup_age++;
      if(setup_age > strategy_setup_timeout_bars)
         ResetSetup(setup_state, setup_age, setup_swept, setup_bos);
     }

   // Stage BOS-wait: look for bullish displacement on all bars.
   if(setup_state == 1)
     {
      if(BullishDisplacement(setup_bos))
        {
         setup_state = 2;
         setup_age   = 0;
        }
      return false;
     }

   // Stage BOS-wait: look for bearish displacement on all bars.
   if(setup_state == -1)
     {
      if(BearishDisplacement(setup_bos))
        {
         setup_state = -2;
         setup_age   = 0;
        }
      return false;
     }

   // Stage retest-entry (long): session-gated final trigger.
   if(setup_state == 2)
     {
      if(IsInBrokerSession(TimeCurrent()) && BullishRetest(setup_bos))
        {
         if(BuildTrade(req, QM_BUY, setup_swept, ask, "LS_BOS_RETEST_LONG"))
           {
            used_long_sweep = setup_swept;
            ResetSetup(setup_state, setup_age, setup_swept, setup_bos);
            return true;
           }
         ResetSetup(setup_state, setup_age, setup_swept, setup_bos);
        }
      return false;
     }

   // Stage retest-entry (short): session-gated final trigger.
   if(setup_state == -2)
     {
      if(IsInBrokerSession(TimeCurrent()) && BearishRetest(setup_bos))
        {
         if(BuildTrade(req, QM_SELL, setup_swept, bid, "LS_BOS_RETEST_SHORT"))
           {
            used_short_sweep = setup_swept;
            ResetSetup(setup_state, setup_age, setup_swept, setup_bos);
            return true;
           }
         ResetSetup(setup_state, setup_age, setup_swept, setup_bos);
        }
      return false;
     }

   // State 0: look for a new sweep.
   double pivot_high = 0.0;
   double pivot_low  = 0.0;
   if(!FindConfirmedPivotHigh(pivot_high) || !FindConfirmedPivotLow(pivot_low))
      return false;

   const double high1  = BarHigh(1);
   const double low1   = BarLow(1);
   const double close1 = BarClose(1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   // Long sweep: low dips below pivot_low, closes back above it.
   if(low1 < pivot_low && close1 > pivot_low &&
      (used_long_sweep <= 0.0 || MathAbs(low1 - used_long_sweep) > point * 2.0))
     {
      setup_state = 1;
      setup_age   = 0;
      setup_swept = low1;
      setup_bos   = pivot_high;
      return false;
     }

   // Short sweep: high pokes above pivot_high, closes back below it.
   if(high1 > pivot_high && close1 < pivot_high &&
      (used_short_sweep <= 0.0 || MathAbs(high1 - used_short_sweep) > point * 2.0))
     {
      setup_state = -1;
      setup_age   = 0;
      setup_swept = high1;
      setup_bos   = pivot_low;
      return false;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Fixed stop + 2R TP; no trailing or partial close per card.
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
