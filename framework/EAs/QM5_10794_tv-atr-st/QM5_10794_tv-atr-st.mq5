#property strict
#property version   "5.0"
#property description "QM5_10794 TradingView Dual ATR SuperTrend (tv-atr-st)"
// Strategy Card: QM5_10794_tv-atr-st, G0 APPROVED 2026-05-22.
// Source: TradingView script rkC2DHrJ "ATR SuperTrend Strategy", author unodeitanti0
//         (source_id d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7). See SPEC.md for full citation.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — Dual ATR SuperTrend trend-following EA
// -----------------------------------------------------------------------------
// Mechanik (card §Mechanik):
//   LONG  : ST1 (base TF) flips bullish on the just-closed bar
//           AND ST2 (higher TF) is already bullish
//           AND ADX >= min (if enabled), RSI not overbought,
//               price within max ATR-distance of ST1 line (if enabled),
//               optional EMA filter permits long, no open position.
//   SHORT : mirror image.
//   EXIT  : ATR stop / R-multiple target (set at entry), optional breakeven at
//           +1R, opposite ST1 flip. Friday-close handled by the framework.
//
// SuperTrend is bespoke structural logic with no QM_* reader, so its band
// recursion is advanced ONCE per closed bar into file-scope cached state
// (INTRADAY DISCIPLINE). The per-tick path only reads cached state + ATR/ADX/RSI
// pooled readers — no CopyRates, no history loops.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10794;
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
input int    st1_atr_period             = 10;     // ST1 (trigger) ATR period — card 10/2.0, 10/3.0, 14/2.5
input double st1_atr_mult               = 2.0;    // ST1 ATR multiplier
input ENUM_TIMEFRAMES st2_timeframe     = PERIOD_H4;  // ST2 confirmation timeframe — card H1/H4
input int    st2_atr_period             = 10;     // ST2 (confirmation) ATR period
input double st2_atr_mult               = 3.0;    // ST2 ATR multiplier

input group "Strategy - Stop / Target"
input int    sl_atr_period              = 14;     // initial-stop ATR period — card ATR(14)*2.0
input double sl_atr_mult                = 2.0;    // initial-stop ATR multiplier
input double tp_r_mult                  = 2.0;    // take-profit as R multiple of stop — card 1.5R/2.0R/2.5R
input bool   be_enabled                 = false;  // move SL to breakeven after +be_r_mult R
input double be_r_mult                  = 1.0;    // breakeven trigger in R

input group "Strategy - Filters"
input double adx_min                    = 0.0;    // ADX minimum (0 = off) — card off/22/25/30
input int    adx_period                 = 14;
input int    rsi_period                 = 14;
input double rsi_overbought             = 70.0;   // block LONG if RSI >= this (>=100 disables)
input double rsi_oversold               = 30.0;   // block SHORT if RSI <= this (<=0 disables)
input double max_dist_atr               = 0.0;    // max distance from ST1 line in ATR units (0 = off) — card 1.5/2.0/2.5
input bool   use_ema_filter             = false;  // require price above/below EMA for long/short
input int    ema_filter_period          = 200;

// -----------------------------------------------------------------------------
// File-scope cached SuperTrend state (advanced once per closed bar).
// -----------------------------------------------------------------------------
bool   g_st1_init      = false;
double g_st1_upper     = 0.0;
double g_st1_lower     = 0.0;
int    g_st1_dir       = 0;      // +1 bullish, -1 bearish
double g_st1_prevclose = 0.0;
double g_st1_line      = 0.0;
bool   g_st1_flip_bull = false;  // ST1 turned bullish on the just-closed bar
bool   g_st1_flip_bear = false;

bool   g_st2_init      = false;
double g_st2_upper     = 0.0;
double g_st2_lower     = 0.0;
int    g_st2_dir       = 0;
double g_st2_prevclose = 0.0;
double g_st2_line      = 0.0;

// -----------------------------------------------------------------------------
// SuperTrend band recursion — advances cached state by ONE closed bar.
// hl2 / close come from the last closed bar (shift 1). iHigh/iLow/iClose are
// single-shift O(1) reads of bespoke structural data with no QM_* equivalent.
// -----------------------------------------------------------------------------
void QM_ST_Advance(const ENUM_TIMEFRAMES tf, const int period, const double mult,
                   bool &init, double &fUpper, double &fLower, int &dir,
                   double &prevClose, double &line)
  {
   const double atr = QM_ATR(_Symbol, tf, period, 1);
   const double hi  = iHigh(_Symbol, tf, 1);   // perf-allowed: bespoke SuperTrend structural read
   const double lo  = iLow(_Symbol, tf, 1);    // perf-allowed: bespoke SuperTrend structural read
   const double cl  = iClose(_Symbol, tf, 1);  // perf-allowed: bespoke SuperTrend structural read
   if(atr <= 0.0 || hi <= 0.0 || lo <= 0.0 || cl <= 0.0)
      return;  // warmup — leave cached state untouched

   const double hl2        = (hi + lo) * 0.5;
   const double basicUpper = hl2 + mult * atr;
   const double basicLower = hl2 - mult * atr;

   if(!init)
     {
      fUpper    = basicUpper;
      fLower    = basicLower;
      dir       = (cl >= hl2) ? 1 : -1;
      prevClose = cl;
      line      = (dir == 1) ? fLower : fUpper;
      init      = true;
      return;
     }

   // Everget SuperTrend band continuation using the previous bar's close+bands.
   const double newUpper = (basicUpper < fUpper || prevClose > fUpper) ? basicUpper : fUpper;
   const double newLower = (basicLower > fLower || prevClose < fLower) ? basicLower : fLower;
   int newDir;
   if(dir == -1)
      newDir = (cl > fUpper) ? 1 : -1;
   else
      newDir = (cl < fLower) ? -1 : 1;

   fUpper    = newUpper;
   fLower    = newLower;
   dir       = newDir;
   prevClose = cl;
   line      = (newDir == 1) ? newLower : newUpper;
  }

// Advance ST1 (base TF) every closed base bar; ST2 only on its own new bar.
void QM_ST_AdvanceAll()
  {
   const int st1_old = g_st1_dir;
   QM_ST_Advance((ENUM_TIMEFRAMES)_Period, st1_atr_period, st1_atr_mult,
                 g_st1_init, g_st1_upper, g_st1_lower, g_st1_dir,
                 g_st1_prevclose, g_st1_line);
   g_st1_flip_bull = (g_st1_init && st1_old == -1 && g_st1_dir == 1);
   g_st1_flip_bear = (g_st1_init && st1_old ==  1 && g_st1_dir == -1);

   // ST2 advances on its own cadence. Guard the edge case where st2_timeframe
   // equals the base period (framework already consumed that QM_IsNewBar key).
   const bool st2_new = (st2_timeframe == (ENUM_TIMEFRAMES)_Period)
                        ? true
                        : QM_IsNewBar(_Symbol, st2_timeframe);
   if(st2_new || !g_st2_init)
      QM_ST_Advance(st2_timeframe, st2_atr_period, st2_atr_mult,
                    g_st2_init, g_st2_upper, g_st2_lower, g_st2_dir,
                    g_st2_prevclose, g_st2_line);
  }

// Returns our open position type for this magic+symbol (or -1 if none).
int QM_OurPositionType()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return -1;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return (int)PositionGetInteger(POSITION_TYPE);  // POSITION_TYPE_BUY=0 / SELL=1
     }
   return -1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No session restriction in the minimal baseline.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Evaluated once per closed base bar (framework gates on QM_IsNewBar()).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;            // market — framework resolves Ask/Bid at send
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // FIRST: advance cached SuperTrend state for this new closed bar.
   QM_ST_AdvanceAll();

   if(!g_st1_init || !g_st2_init)
      return false;
   if(QM_OurPositionType() != -1)   // one position per symbol/magic
      return false;

   const double atr1 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, st1_atr_period, 1);
   if(atr1 <= 0.0)
      return false;
   const double close1 = g_st1_prevclose;   // last closed-bar close (cached)
   const double adx = (adx_min > 0.0) ? QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, adx_period, 1) : 0.0;
   const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, rsi_period, 1);
   const double ema = use_ema_filter ? QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, ema_filter_period, 1) : 0.0;

   // Shared filters
   const bool adx_ok  = (adx_min <= 0.0) || (adx >= adx_min);
   const bool dist_ok = (max_dist_atr <= 0.0) ||
                        (MathAbs(close1 - g_st1_line) <= max_dist_atr * atr1);

   // LONG
   if(g_st1_flip_bull && g_st2_dir == 1 && adx_ok && dist_ok)
     {
      const bool rsi_ok = (rsi < rsi_overbought);
      const bool ema_ok = (!use_ema_filter) || (close1 > ema);
      if(rsi_ok && ema_ok)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double sl    = QM_StopATR(_Symbol, QM_BUY, entry, sl_atr_period, sl_atr_mult);
         if(entry > 0.0 && sl > 0.0 && sl < entry)
           {
            const double risk = entry - sl;
            req.type   = QM_BUY;
            req.sl     = sl;
            req.tp     = entry + risk * tp_r_mult;
            req.reason = "tv-atr-st LONG ST1bull ST2bull";
            return true;
           }
        }
     }

   // SHORT
   if(g_st1_flip_bear && g_st2_dir == -1 && adx_ok && dist_ok)
     {
      const bool rsi_ok = (rsi > rsi_oversold);
      const bool ema_ok = (!use_ema_filter) || (close1 < ema);
      if(rsi_ok && ema_ok)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double sl    = QM_StopATR(_Symbol, QM_SELL, entry, sl_atr_period, sl_atr_mult);
         if(entry > 0.0 && sl > entry)
           {
            const double risk = sl - entry;
            req.type   = QM_SELL;
            req.sl     = sl;
            req.tp     = entry - risk * tp_r_mult;
            req.reason = "tv-atr-st SHORT ST1bear ST2bear";
            return true;
           }
        }
     }

   return false;
  }

// Per-tick: optional breakeven move at +be_r_mult R.
void Strategy_ManageOpenPosition()
  {
   if(!be_enabled)
      return;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;
   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const double open = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl   = PositionGetDouble(POSITION_SL);
      if(open <= 0.0 || sl <= 0.0)
         continue;
      const double sl_dist = MathAbs(open - sl);
      const int trigger_pips = (int)MathRound((sl_dist * be_r_mult) / pip);
      if(trigger_pips <= 0)
         continue;
      QM_TM_MoveToBreakEven(ticket, trigger_pips, 1);
     }
  }

// Per-tick: discretionary exit on opposite ST1 trend (closed-bar cached dir).
bool Strategy_ExitSignal()
  {
   const int ptype = QM_OurPositionType();
   if(ptype == POSITION_TYPE_BUY  && g_st1_dir == -1)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_st1_dir ==  1)
      return true;
   return false;
  }

// News-filter hook — defer to the central two-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10794_tv-atr-st\"}");
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
