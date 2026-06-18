#property strict
#property version   "5.0"
#property description "QM5_11281 4H MACD(5,13,1) extreme-level fade + zero-cross continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA  —  QM5_11281 4H MACD(5,13,1) Pattern (H4)
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_11281_macd-5-13-1-pattern-h4.md
//
// MACD(5,13,1): signal=1 makes the main line a fast EMA(5)-EMA(13) price-unit
// difference (no smoothing). The MACD line CAN be negative — there is NO <=0
// guard; the pattern/cross is the single EVENT per signal type.
//
// Two mechanizable signal families, each ONE closed-bar event:
//   A/D — Fade from extreme: MACD reaches +/-thr then closes back inside it.
//         SELL when it crosses back DOWN through +thr; BUY when it crosses
//         back UP through -thr. Exit at ATR TP / ATR SL.
//   B/C — Zero-line continuation with SMA(200) trend filter:
//         price > SMA200 and MACD crosses UP through 0   -> BUY
//         price < SMA200 and MACD crosses DOWN through 0  -> SELL
//         Exit by ATR trail + opposite zero-cross.
//
// Threshold portability: the card's +/-0.0045 is calibrated for EURUSD (5-digit,
// point 0.00001). We express it in POINTS (0.0045 / 0.00001 = 450) and convert
// to a price-unit threshold at runtime via SYMBOL_POINT. This auto-scales for
// JPY (3-digit) and every FX major with NO external feed (SYMBOL_POINT is local
// MT5 data). One position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11281;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// MACD(5,13,1) — signal=1 => fast unsmoothed oscillator on the H4 close.
input int    strategy_macd_fast          = 5;
input int    strategy_macd_slow          = 13;
input int    strategy_macd_signal        = 1;
// Extreme level for A/D fade, expressed in POINTS vs the EURUSD 5-digit point.
// 0.0045 price on EURUSD = 450 points. P3 sweep: {300, 450, 600}.
input double strategy_extreme_points     = 450.0;
// Trend filter MA for B/C zero-cross continuation.
input int    strategy_trend_sma          = 200;
// ATR-based stops / takes.
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.5;   // initial SL distance
input double strategy_atr_tp_mult        = 2.0;   // A/D fixed TP (R~1.33)
// B/C management: ATR trail + break-even at +1R.
input double strategy_bc_trail_atr_mult  = 1.0;   // B/C trailing stop ATR mult
input int    strategy_be_trigger_pips    = 0;     // 0 => derive BE trigger from initial R
input bool   strategy_enable_fade        = true;  // Type A/D
input bool   strategy_enable_zerocross   = true;  // Type B/C

// -----------------------------------------------------------------------------
// State tags so management/exit know which family opened the position.
// Encoded into the entry reason string; read back from POSITION_COMMENT is not
// reliable in the tester, so we re-derive family at manage/exit time from the
// live MACD/price geometry instead (stateless, deterministic per closed bar).
// -----------------------------------------------------------------------------

double ExtremeThresholdPrice()
  {
   // POINTS -> price distance using the symbol's own point. Self-contained,
   // no external feed: SYMBOL_POINT is local MT5 instrument data.
   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0)
      return 0.0;
   return strategy_extreme_points * pt;
  }

bool HasOpenForThisMagic()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
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
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_macd_fast < 1 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 || strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   // One position per magic.
   if(HasOpenForThisMagic())
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   // Closed-bar MACD main values (shift 1 = last closed, shift 2 = prior).
   const double macd_1 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast,
                                      strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_2 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast,
                                      strategy_macd_slow, strategy_macd_signal, 2);
   if(macd_1 == 0.0 && macd_2 == 0.0)
      return false;

   const double thr = ExtremeThresholdPrice();

   bool go_long  = false;
   bool go_short = false;
   string tag = "";

   // ---- Type A/D : fade from extreme (single cross-back EVENT) ----
   if(strategy_enable_fade && thr > 0.0)
     {
      // Type A (sell): was at/above +thr, closes back below +thr.
      if(macd_2 >= thr && macd_1 < thr)
        { go_short = true; tag = "A_FADE_SHORT"; }
      // Type D (buy): was at/below -thr, closes back above -thr.
      else if(macd_2 <= -thr && macd_1 > -thr)
        { go_long = true; tag = "D_FADE_LONG"; }
     }

   // ---- Type B/C : zero-line continuation with SMA(200) trend filter ----
   // Only if a fade did not already trigger (one event per bar).
   if(strategy_enable_zerocross && !go_long && !go_short)
     {
      const double sma200 = QM_SMA(_Symbol, tf, strategy_trend_sma, 1, PRICE_CLOSE);
      // close of last closed bar (shift 1) for the trend comparison.
      const double close_1 = iClose(_Symbol, tf, 1); // perf-allowed: single closed-bar read
      if(sma200 > 0.0 && close_1 > 0.0)
        {
         const bool cross_up   = (macd_2 <= 0.0 && macd_1 > 0.0);
         const bool cross_down = (macd_2 >= 0.0 && macd_1 < 0.0);
         if(cross_up && close_1 > sma200)
           { go_long = true; tag = "B_ZC_LONG"; }
         else if(cross_down && close_1 < sma200)
           { go_short = true; tag = "C_ZC_SHORT"; }
        }
     }

   if(!go_long && !go_short)
      return false;

   req.type = go_long ? QM_BUY : QM_SELL;
   req.price = QM_EntryMarketPrice(req.type);
   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   // A/D get a fixed ATR take-profit. B/C ride via ATR trail + opposite
   // zero-cross exit, so no hard TP (tp=0 => none).
   const bool is_fade = (StringFind(tag, "FADE") >= 0);
   if(is_fade)
      req.tp = QM_TakeATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_tp_mult);
   else
      req.tp = 0.0;

   req.reason = tag;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(strategy_atr_sl_mult <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Break-even at +1R. Derive trigger distance from the initial risk so the
      // BE move is family-agnostic and scale-correct (points-based helper).
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl         = PositionGetDouble(POSITION_SL);
      const double pt         = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price > 0.0 && sl > 0.0 && pt > 0.0)
        {
         int trigger_pips = strategy_be_trigger_pips;
         if(trigger_pips <= 0)
           {
            const double risk_dist = MathAbs(open_price - sl);
            // pips = price-distance / (10*point) for 5/3-digit FX.
            trigger_pips = (int)MathRound(risk_dist / (10.0 * pt));
           }
         if(trigger_pips > 0)
            QM_TM_MoveToBreakEven(ticket, trigger_pips, 2);
        }

      // ATR trailing stop for the zero-cross continuation legs. The fade legs
      // carry a fixed ATR TP and rely on SL/TP; trailing them is harmless but
      // we keep it to the configured mult only when trailing is enabled.
      if(strategy_bc_trail_atr_mult > 0.0)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_bc_trail_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   if(!strategy_enable_zerocross)
      return false;

   const int magic = QM_FrameworkMagic();
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   const double macd_1 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast,
                                      strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_2 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast,
                                      strategy_macd_slow, strategy_macd_signal, 2);
   const bool cross_up   = (macd_2 <= 0.0 && macd_1 > 0.0);
   const bool cross_down = (macd_2 >= 0.0 && macd_1 < 0.0);
   if(!cross_up && !cross_down)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      // Opposite zero-cross closes a continuation position.
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross_up)
         return true;
     }

   return false;
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
