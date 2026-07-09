#property strict
#property version   "5.0"
#property description "QM5_9723 - ForexFactory Sonic R Scout S/R H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9723 ff-sonicr-scout-h1
// Source: sonicdeejay / traderathome, Sonic R. System Scout Trade,
// ForexFactory thread 114792. H1 support/resistance Scout reversal at whole and
// half-number zones after a significant ATR-scaled run.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9723;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker            = 21;

input group "Stress"
input double qm_stress_reject_probability           = 0.0;

input group "Strategy"
input int    strategy_atr_period                    = 14;
input int    strategy_swing_lookback_bars           = 80;
input int    strategy_run_lookback_bars             = 20;
input int    strategy_swing_reject_count            = 2;
input int    strategy_round_step_pips               = 50;
input double strategy_zone_atr_mult                 = 0.35;
input double strategy_run_atr_mult                  = 2.0;
input double strategy_wick_min_pct                  = 45.0;
input double strategy_sl_atr_buffer                 = 0.20;
input double strategy_max_stop_atr                  = 1.40;
input double strategy_tp_r_mult                     = 3.0;
input double strategy_min_opposing_r                = 2.5;
input int    strategy_time_stop_bars                = 12;

static bool   g_long_valid       = false;
static bool   g_short_valid      = false;
static double g_long_sl          = 0.0;
static double g_long_tp          = 0.0;
static double g_short_sl         = 0.0;
static double g_short_tp         = 0.0;
static double g_close1           = 0.0;
static double g_atr1             = 0.0;

double PipSize()
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double LevelStep()
  {
   const double pip = PipSize();
   if(pip <= 0.0)
      return 0.0;
   return pip * (double)strategy_round_step_pips;
  }

double NormalizeTradePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

double NearestRoundLevel(const double price, const double step)
  {
   if(step <= 0.0)
      return price;
   return MathRound(price / step) * step;
  }

double NextRoundAbove(const double price, const double step)
  {
   if(step <= 0.0)
      return price;
   return (MathFloor(price / step) + 1.0) * step;
  }

double NextRoundBelow(const double price, const double step)
  {
   if(step <= 0.0)
      return price;
   return (MathCeil(price / step) - 1.0) * step;
  }

double WickPctLong(const MqlRates &bar)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   const double body_low = MathMin(bar.open, bar.close);
   return 100.0 * (body_low - bar.low) / range;
  }

double WickPctShort(const MqlRates &bar)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   const double body_high = MathMax(bar.open, bar.close);
   return 100.0 * (bar.high - body_high) / range;
  }

double HighestHigh(const MqlRates &rates[], const int n, const int bars)
  {
   const int limit = MathMin(n, bars);
   double out = rates[0].high;
   for(int i = 1; i < limit; ++i)
      if(rates[i].high > out)
         out = rates[i].high;
   return out;
  }

double LowestLow(const MqlRates &rates[], const int n, const int bars)
  {
   const int limit = MathMin(n, bars);
   double out = rates[0].low;
   for(int i = 1; i < limit; ++i)
      if(rates[i].low < out)
         out = rates[i].low;
   return out;
  }

int SwingLowTouchesNear(const MqlRates &rates[], const int n, const double center, const double tolerance)
  {
   int touches = 0;
   for(int i = 1; i < n - 1; ++i)
     {
      if(rates[i].low <= rates[i - 1].low &&
         rates[i].low <= rates[i + 1].low &&
         MathAbs(rates[i].low - center) <= tolerance)
         touches++;
     }
   return touches;
  }

int SwingHighTouchesNear(const MqlRates &rates[], const int n, const double center, const double tolerance)
  {
   int touches = 0;
   for(int i = 1; i < n - 1; ++i)
     {
      if(rates[i].high >= rates[i - 1].high &&
         rates[i].high >= rates[i + 1].high &&
         MathAbs(rates[i].high - center) <= tolerance)
         touches++;
     }
   return touches;
  }

bool BuildSupportZone(const MqlRates &rates[], const int n, const double atr,
                      double &zone_low, double &zone_high, double &zone_mid)
  {
   const double step = LevelStep();
   const double tolerance = strategy_zone_atr_mult * atr;
   if(step <= 0.0 || tolerance <= 0.0)
      return false;

   const double round_center = NearestRoundLevel(rates[0].low, step);
   const bool round_zone = (rates[0].low <= round_center + tolerance &&
                            rates[0].high >= round_center - tolerance);
   const bool swing_zone = (SwingLowTouchesNear(rates, n, rates[0].low, tolerance) >= strategy_swing_reject_count);

   if(!round_zone && !swing_zone)
      return false;

   zone_mid = round_zone ? round_center : rates[0].low;
   zone_low = zone_mid - tolerance;
   zone_high = zone_mid + tolerance;
   return true;
  }

bool BuildResistanceZone(const MqlRates &rates[], const int n, const double atr,
                         double &zone_low, double &zone_high, double &zone_mid)
  {
   const double step = LevelStep();
   const double tolerance = strategy_zone_atr_mult * atr;
   if(step <= 0.0 || tolerance <= 0.0)
      return false;

   const double round_center = NearestRoundLevel(rates[0].high, step);
   const bool round_zone = (rates[0].low <= round_center + tolerance &&
                            rates[0].high >= round_center - tolerance);
   const bool swing_zone = (SwingHighTouchesNear(rates, n, rates[0].high, tolerance) >= strategy_swing_reject_count);

   if(!round_zone && !swing_zone)
      return false;

   zone_mid = round_zone ? round_center : rates[0].high;
   zone_low = zone_mid - tolerance;
   zone_high = zone_mid + tolerance;
   return true;
  }

double NextResistanceAbove(const MqlRates &rates[], const int n, const double price)
  {
   const double step = LevelStep();
   double next = NextRoundAbove(price, step);
   for(int i = 1; i < n - 1; ++i)
     {
      if(rates[i].high <= price)
         continue;
      if(rates[i].high >= rates[i - 1].high && rates[i].high >= rates[i + 1].high)
         if(next <= price || rates[i].high < next)
            next = rates[i].high;
     }
   return next;
  }

double NextSupportBelow(const MqlRates &rates[], const int n, const double price)
  {
   const double step = LevelStep();
   double next = NextRoundBelow(price, step);
   for(int i = 1; i < n - 1; ++i)
     {
      if(rates[i].low >= price)
         continue;
      if(rates[i].low <= rates[i - 1].low && rates[i].low <= rates[i + 1].low)
         if(next >= price || rates[i].low > next)
            next = rates[i].low;
     }
   return next;
  }

bool OpenPositionExists()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

void UpdateBarState()
  {
   g_long_valid = false;
   g_short_valid = false;
   g_long_sl = 0.0;
   g_long_tp = 0.0;
   g_short_sl = 0.0;
   g_short_tp = 0.0;
   g_close1 = 0.0;
   g_atr1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(g_atr1 <= 0.0)
      return;

   MqlRates rates[];
   const int request_bars = MathMax(strategy_swing_lookback_bars, strategy_run_lookback_bars) + 4;
   const int n = CopyRates(_Symbol, PERIOD_H1, 1, request_bars, rates); // perf-allowed - structural S/R scan, called once per new H1 bar
   if(n < MathMax(strategy_run_lookback_bars, 8))
      return;

   const MqlRates bar = rates[0];
   g_close1 = bar.close;

   double zone_low = 0.0, zone_high = 0.0, zone_mid = 0.0;
   if(BuildSupportZone(rates, n, g_atr1, zone_low, zone_high, zone_mid))
     {
      const double high20 = HighestHigh(rates, n, strategy_run_lookback_bars);
      const bool down_run = (high20 - bar.close >= strategy_run_atr_mult * g_atr1);
      const bool wick_ok = (WickPctLong(bar) >= strategy_wick_min_pct);
      const bool close_back = (bar.close > zone_mid);
      const bool touched_zone = (bar.low <= zone_high && bar.high >= zone_low);
      const double sl = zone_low - strategy_sl_atr_buffer * g_atr1;
      const double r = bar.close - sl;
      const double opposing = NextResistanceAbove(rates, n, bar.close);
      const bool stop_ok = (r > 0.0 && r <= strategy_max_stop_atr * g_atr1);
      const bool room_ok = (opposing > bar.close && opposing - bar.close >= strategy_min_opposing_r * r);
      if(down_run && wick_ok && close_back && touched_zone && stop_ok && room_ok)
        {
         g_long_valid = true;
         g_long_sl = NormalizeTradePrice(sl);
         g_long_tp = NormalizeTradePrice(MathMin(bar.close + strategy_tp_r_mult * r, opposing));
        }
     }

   if(BuildResistanceZone(rates, n, g_atr1, zone_low, zone_high, zone_mid))
     {
      const double low20 = LowestLow(rates, n, strategy_run_lookback_bars);
      const bool up_run = (bar.close - low20 >= strategy_run_atr_mult * g_atr1);
      const bool wick_ok = (WickPctShort(bar) >= strategy_wick_min_pct);
      const bool close_back = (bar.close < zone_mid);
      const bool touched_zone = (bar.low <= zone_high && bar.high >= zone_low);
      const double sl = zone_high + strategy_sl_atr_buffer * g_atr1;
      const double r = sl - bar.close;
      const double opposing = NextSupportBelow(rates, n, bar.close);
      const bool stop_ok = (r > 0.0 && r <= strategy_max_stop_atr * g_atr1);
      const bool room_ok = (opposing < bar.close && bar.close - opposing >= strategy_min_opposing_r * r);
      if(up_run && wick_ok && close_back && touched_zone && stop_ok && room_ok)
        {
         g_short_valid = true;
         g_short_sl = NormalizeTradePrice(sl);
         g_short_tp = NormalizeTradePrice(MathMax(bar.close - strategy_tp_r_mult * r, opposing));
        }
     }
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(OpenPositionExists())
      return false;

   if(g_long_valid)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0 || ask <= g_long_sl || g_long_tp <= ask)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = g_long_sl;
      req.tp = g_long_tp;
      req.reason = "SONICR_SCOUT_SUPPORT_REJECT";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   if(g_short_valid)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || bid >= g_short_sl || g_short_tp >= bid)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = g_short_sl;
      req.tp = g_short_tp;
      req.reason = "SONICR_SCOUT_RESIST_REJECT";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Scout uses fixed initial SL/TP. Early close and time stop live in ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if((long)(TimeCurrent() - open_time) >= (long)(strategy_time_stop_bars * 3600))
         return true;

      if(g_atr1 <= 0.0 || g_close1 <= 0.0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double sl = PositionGetDouble(POSITION_SL);
      if(ptype == POSITION_TYPE_BUY && sl > 0.0)
        {
         const double zone_edge = sl + strategy_sl_atr_buffer * g_atr1;
         if(g_close1 < zone_edge)
            return true;
        }
      if(ptype == POSITION_TYPE_SELL && sl > 0.0)
        {
         const double zone_edge = sl - strategy_sl_atr_buffer * g_atr1;
         if(g_close1 > zone_edge)
            return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - keep management/exit above the news entry gate.
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      UpdateBarState();

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

   if(!is_new_bar)
      return;

   QM_EquityStreamOnNewBar();

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
