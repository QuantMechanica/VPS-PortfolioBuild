#property strict
#property version   "5.0"
#property description "QM5_11317 Carter M5 #9 EMA50/100 trend + MACD zero-cross confirmation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_11317 — Thomas Carter "20 Forex Trading Strategies (5 Minute Time Frame)"
//             5 Min Trading System #9. EMA(50)/EMA(100) trend regime gate +
//             MACD(12,26,9) zero-cross confirmation, M5.
//
// Anti-zero-trade design (see codex_build_ea.md .DWX INVARIANT #4):
//   The MACD main-line zero-cross is the single ENTRY EVENT (it must have
//   occurred within the last N closed bars). The EMA50/100 stack and the
//   10-pip distance are STATES evaluated on the trigger bar — NOT a second
//   fresh cross event. Two fresh crosses on one bar almost never coincide, so
//   only one is the event.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11317;
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
input int    strategy_ema_fast_period      = 50;    // EMA(50) trend gate / exit anchor
input int    strategy_ema_slow_period      = 100;   // EMA(100) trend gate
input int    strategy_macd_fast            = 12;    // MACD fast EMA
input int    strategy_macd_slow            = 26;    // MACD slow EMA
input int    strategy_macd_signal          = 9;     // MACD signal EMA
input int    strategy_macd_cross_lookback  = 5;     // MACD zero-cross must be <= N closed bars old (EVENT)
input int    strategy_distance_pips        = 10;    // close must be >= this far beyond EMA(50)
input int    strategy_structure_bars       = 5;     // initial SL = 5-bar low (long) / high (short)
input double strategy_tp1_r_multiple       = 2.0;   // take partial profit at this R-multiple
input double strategy_partial_close_ratio  = 0.50;  // fraction closed at TP1, remainder rides to BE
input int    strategy_be_buffer_pips       = 0;     // breakeven offset after partial
input int    strategy_exit_break_pips      = 10;    // final exit: close breaks EMA(50) by this many pips
input int    strategy_spread_cap_pips      = 20;    // M5 spread cap (card baseline 20 points)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// Fail-OPEN spread guard. .DWX quotes ask==bid (0 modeled spread) in the
// tester; never block on zero spread — only block a genuinely wide spread.
bool SpreadTooWide()
  {
   const double cap = PipDistance(strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false; // misconfigured cap -> do not block

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > cap)
      return true;
   return false;
  }

// EVENT: did the MACD main line cross zero in the bullish/bearish direction
// within the last `strategy_macd_cross_lookback` closed bars, and is it still
// on the right side of zero now (shift 1)? MACD can be negative — we test the
// sign-flip, not a positivity floor.
bool MacdCrossedZeroRecently(const bool bullish)
  {
   if(strategy_macd_cross_lookback < 1)
      return false;

   const double macd_now = QM_MACD_Main(_Symbol, PERIOD_M5,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, 1);
   if(bullish && macd_now <= 0.0)
      return false;
   if(!bullish && macd_now >= 0.0)
      return false;

   for(int shift = 1; shift <= strategy_macd_cross_lookback; ++shift)
     {
      const double newer = QM_MACD_Main(_Symbol, PERIOD_M5,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, shift);
      const double older = QM_MACD_Main(_Symbol, PERIOD_M5,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, shift + 1);
      if(bullish && newer > 0.0 && older <= 0.0)
         return true;
      if(!bullish && newer < 0.0 && older >= 0.0)
         return true;
     }

   return false;
  }

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &type, double &open_price,
                       double &sl, double &tp, double &volume)
  {
   ticket = 0;
   type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   tp = 0.0;
   volume = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      volume = PositionGetDouble(POSITION_VOLUME);
      return true;
     }

   return false;
  }

// After the partial close we shove SL to (about) breakeven. Detect that state
// so we don't repeatedly partial-close.
bool PartialAlreadyDone(const ENUM_POSITION_TYPE type, const double open_price, const double sl)
  {
   if(open_price <= 0.0 || sl <= 0.0)
      return false;

   const double be_buffer = PipDistance(strategy_be_buffer_pips);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(type == POSITION_TYPE_BUY)
      return (sl >= open_price + be_buffer - point);
   return (sl <= open_price - be_buffer + point);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No-Trade / spread / news filter. O(1) per tick.
bool Strategy_NoTradeFilter()
  {
   return SpreadTooWide();
  }

// Entry: EMA50/100 trend STATE + 10-pip distance STATE + MACD zero-cross EVENT.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_fast_period <= 0 || strategy_ema_slow_period <= 0 ||
      strategy_structure_bars <= 0 || strategy_distance_pips <= 0 ||
      strategy_tp1_r_multiple <= 0.0)
      return false;

   if(SpreadTooWide())
      return false;

   // Closed-bar reads (shift 1). single closed-bar close; no QM close reader exists.
   const double close1   = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: single closed-bar close
   const double ema_fast = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_slow_period, 1);
   const double distance = PipDistance(strategy_distance_pips);
   if(close1 <= 0.0 || ema_fast <= 0.0 || ema_slow <= 0.0 || distance <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // LONG: close above both EMAs, >= distance above EMA50, not between the EMAs
   // (price above the higher of the two), MACD zero-cross EVENT within lookback.
   const bool long_state = (close1 > ema_fast && close1 > ema_slow &&
                            close1 >= ema_fast + distance &&
                            close1 > MathMax(ema_fast, ema_slow));
   if(long_state && MacdCrossedZeroRecently(true))
     {
      const double sl = QM_StopStructure(_Symbol, QM_BUY, ask, strategy_structure_bars);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type   = QM_BUY;
      req.sl     = sl;
      req.tp     = 0.0; // managed: partial at 2R then EMA50-break exit
      req.reason = "TC_M5_S9_EMA50_100_MACD_LONG";
      return true;
     }

   // SHORT: mirror image.
   const bool short_state = (close1 < ema_fast && close1 < ema_slow &&
                             close1 <= ema_fast - distance &&
                             close1 < MathMin(ema_fast, ema_slow));
   if(short_state && MacdCrossedZeroRecently(false))
     {
      const double sl = QM_StopStructure(_Symbol, QM_SELL, bid, strategy_structure_bars);
      if(sl <= 0.0 || sl <= bid)
         return false;

      req.type   = QM_SELL;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "TC_M5_S9_EMA50_100_MACD_SHORT";
      return true;
     }

   return false;
  }

// Take partial profit at 2R, then move the remainder's stop to breakeven.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double open_price;
   double sl;
   double tp;
   double volume;
   if(!SelectOurPosition(ticket, type, open_price, sl, tp, volume))
      return;
   if(PartialAlreadyDone(type, open_price, sl))
      return;
   if(open_price <= 0.0 || sl <= 0.0 || volume <= 0.0)
      return;

   const bool is_buy = (type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double risk_distance = MathAbs(open_price - sl);
   if(risk_distance <= 0.0)
      return;

   const double trigger = is_buy ? (open_price + strategy_tp1_r_multiple * risk_distance)
                                 : (open_price - strategy_tp1_r_multiple * risk_distance);
   if((is_buy && market < trigger) || (!is_buy && market > trigger))
      return;

   double lots_to_close = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_close_ratio);
   if(lots_to_close <= 0.0 || lots_to_close >= volume)
      return;

   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
      QM_TM_MoveSL(ticket,
                   is_buy ? open_price + PipDistance(strategy_be_buffer_pips)
                          : open_price - PipDistance(strategy_be_buffer_pips),
                   "tp1_partial_move_to_breakeven");
  }

// Final exit: close breaks below (long) / above (short) EMA(50) by exit_break_pips.
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double open_price;
   double sl;
   double tp;
   double volume;
   if(!SelectOurPosition(ticket, type, open_price, sl, tp, volume))
      return false;

   const double ema_fast = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_fast_period, 1);
   const double brk      = PipDistance(strategy_exit_break_pips);
   if(ema_fast <= 0.0 || brk <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: single closed-bar close
   if(close1 <= 0.0)
      return false;

   if(type == POSITION_TYPE_BUY)
      return (close1 < ema_fast - brk);
   return (close1 > ema_fast + brk);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11317\",\"ea\":\"tc_m5_9_ema50_100_macd\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, PERIOD_M5))
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
