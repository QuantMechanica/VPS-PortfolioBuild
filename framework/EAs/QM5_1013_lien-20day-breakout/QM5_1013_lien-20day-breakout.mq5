#property strict
#property version   "5.0"
#property description "QM5_1013 lien-20day-breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1013 lien-20day-breakout
// Card: strategy-seeds/cards/lien-20day-breakout_card.md
// Source: Kathy Lien, 20-day breakout failed-pullback continuation setup.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1013;
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
input int    breakout_lookback                 = 20;
input int    pullback_lookback                 = 2;
input int    pullback_timing                   = 1;
input int    rebreak_window                    = 3;
input int    breakout_offset_pips              = 5;
input int    stop_anchor_offset_pips           = 7;
input double tp1_rr                            = 1.0;
input string trail_method                      = "two_bar_extreme";
input string multi_window_extreme_confluence   = "off";
input string signal_tf                         = "D1";

string QM_ConfigStrategyName() { return "lien-20day-breakout"; }
int    QM_ConfigEaId() { return 1013; }

enum Lien20State
  {
   LIEN20_SCAN = 0,
   LIEN20_PULLBACK = 1,
   LIEN20_REBREAK = 2
  };

Lien20State g_setup_state = LIEN20_SCAN;
int         g_setup_direction = 0;
double      g_breakout_level = 0.0;
double      g_pullback_extreme = 0.0;
int         g_pullback_wait = 0;
int         g_rebreak_wait = 0;
bool        g_tp1_done = false;

ENUM_TIMEFRAMES ParseTf(const string value, const ENUM_TIMEFRAMES fallback_tf)
  {
   string v = value;
   StringTrimLeft(v);
   StringTrimRight(v);
   StringToUpper(v);
   if(v == "M30") return PERIOD_M30;
   if(v == "H1")  return PERIOD_H1;
   if(v == "H4")  return PERIOD_H4;
   if(v == "D1")  return PERIOD_D1;
   if(v == "W1")  return PERIOD_W1;
   return fallback_tf;
  }

ENUM_TIMEFRAMES StrategyTf()
  {
   return ParseTf(signal_tf, PERIOD_D1);
  }

double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

double NormalizeStrategyPrice(const double price)
  {
   return QM_TM_NormalizePrice(_Symbol, price);
  }

bool TextContains(const string haystack, const string needle)
  {
   string h = haystack;
   string n = needle;
   StringToUpper(h);
   StringToUpper(n);
   return (StringFind(h, n) >= 0);
  }

bool HasManagedPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool HasManagedOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

void CancelManagedOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void ResetSetup()
  {
   g_setup_state = LIEN20_SCAN;
   g_setup_direction = 0;
   g_breakout_level = 0.0;
   g_pullback_extreme = 0.0;
   g_pullback_wait = 0;
   g_rebreak_wait = 0;
  }

bool LoadClosedBars(const int requested, MqlRates &bars[])
  {
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, StrategyTf(), 1, requested, bars); // perf-allowed: bounded D1 structural scan, called only from the closed-bar entry path.
   return (copied >= requested);
  }

int ConfluenceLookback()
  {
   if(TextContains(multi_window_extreme_confluence, "60"))
      return 60;
   if(TextContains(multi_window_extreme_confluence, "40"))
      return 40;
   return 0;
  }

bool FreshHigh(const MqlRates &bars[], const int lookback, const int confluence)
  {
   const double high = bars[0].high;
   if(high <= 0.0)
      return false;

   for(int i = 1; i <= lookback; ++i)
      if(bars[i].high >= high)
         return false;

   if(confluence > lookback)
     {
      for(int i = lookback + 1; i <= confluence; ++i)
         if(bars[i].high >= high)
            return false;
     }

   return true;
  }

bool FreshLow(const MqlRates &bars[], const int lookback, const int confluence)
  {
   const double low = bars[0].low;
   if(low <= 0.0)
      return false;

   for(int i = 1; i <= lookback; ++i)
      if(bars[i].low <= low)
         return false;

   if(confluence > lookback)
     {
      for(int i = lookback + 1; i <= confluence; ++i)
         if(bars[i].low <= low)
            return false;
     }

   return true;
  }

bool TwoBarLow(const MqlRates &bars[], const int lookback)
  {
   const double low = bars[0].low;
   if(low <= 0.0)
      return false;
   for(int i = 1; i <= lookback; ++i)
      if(bars[i].low <= low)
         return false;
   return true;
  }

bool TwoBarHigh(const MqlRates &bars[], const int lookback)
  {
   const double high = bars[0].high;
   if(high <= 0.0)
      return false;
   for(int i = 1; i <= lookback; ++i)
      if(bars[i].high >= high)
         return false;
   return true;
  }

void ArmBreakout(const int direction, const double breakout_level)
  {
   g_setup_state = LIEN20_PULLBACK;
   g_setup_direction = direction;
   g_breakout_level = breakout_level;
   g_pullback_extreme = 0.0;
   g_pullback_wait = 0;
   g_rebreak_wait = 0;
  }

void ArmRebreak(const double pullback_extreme)
  {
   g_setup_state = LIEN20_REBREAK;
   g_pullback_extreme = pullback_extreme;
   g_pullback_wait = 0;
   g_rebreak_wait = 0;
  }

bool BuildRebreakRequest(QM_EntryRequest &req)
  {
   const double entry_offset = PipDistance(breakout_offset_pips);
   const double stop_offset = PipDistance(stop_anchor_offset_pips);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_offset <= 0.0 || stop_offset <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 86400;
   req.tp = 0.0;

   if(g_setup_direction > 0)
     {
      const double entry = NormalizeStrategyPrice(g_breakout_level + entry_offset);
      const double sl = NormalizeStrategyPrice(g_pullback_extreme - stop_offset);
      if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
         return false;

      req.type = (entry > ask) ? QM_BUY_STOP : QM_BUY;
      req.price = (req.type == QM_BUY_STOP) ? entry : 0.0;
      req.sl = sl;
      req.reason = "LIEN20_REBREAK_LONG";
      return true;
     }

   if(g_setup_direction < 0)
     {
      const double entry = NormalizeStrategyPrice(g_breakout_level - entry_offset);
      const double sl = NormalizeStrategyPrice(g_pullback_extreme + stop_offset);
      if(entry <= 0.0 || sl <= 0.0 || sl <= entry)
         return false;

      req.type = (entry < bid) ? QM_SELL_STOP : QM_SELL;
      req.price = (req.type == QM_SELL_STOP) ? entry : 0.0;
      req.sl = sl;
      req.reason = "LIEN20_REBREAK_SHORT";
      return true;
     }

   return false;
  }

void ScanForFreshBreakout(const MqlRates &bars[], const int breakout_lb, const int pullback_lb, const int confluence)
  {
   if(FreshHigh(bars, breakout_lb, confluence))
     {
      ArmBreakout(1, bars[0].high);
      if(TwoBarLow(bars, pullback_lb))
         ArmRebreak(bars[0].low);
      return;
     }

   if(FreshLow(bars, breakout_lb, confluence))
     {
      ArmBreakout(-1, bars[0].low);
      if(TwoBarHigh(bars, pullback_lb))
         ArmRebreak(bars[0].high);
     }
  }

double ExtremeLow(const ENUM_TIMEFRAMES bars_tf, const int bars_count)
  {
   double out = 0.0;
   for(int shift = 1; shift <= bars_count; ++shift)
     {
      const double value = iLow(_Symbol, bars_tf, shift); // perf-allowed: small closed-bar structural trailing stop.
      if(value <= 0.0)
         continue;
      if(out <= 0.0 || value < out)
         out = value;
     }
   return out;
  }

double ExtremeHigh(const ENUM_TIMEFRAMES bars_tf, const int bars_count)
  {
   double out = 0.0;
   for(int shift = 1; shift <= bars_count; ++shift)
     {
      const double value = iHigh(_Symbol, bars_tf, shift); // perf-allowed: small closed-bar structural trailing stop.
      if(value <= 0.0)
         continue;
      if(out <= 0.0 || value > out)
         out = value;
     }
   return out;
  }

bool BreakevenOrBetter(const ENUM_POSITION_TYPE pos_type,
                       const double open_price,
                       const double current_sl)
  {
   if(open_price <= 0.0 || current_sl <= 0.0)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tolerance = (point > 0.0) ? point * 0.5 : 0.0;
   if(pos_type == POSITION_TYPE_BUY)
      return current_sl >= open_price - tolerance;
   return current_sl <= open_price + tolerance;
  }

int TrailLookback()
  {
   if(TextContains(trail_method, "DONCHIAN10"))
      return 10;
   if(TextContains(trail_method, "DONCHIAN5"))
      return 5;
   if(TextContains(trail_method, "THREE") || TextContains(trail_method, "3_BAR"))
      return 3;
   return 2;
  }

double StructuralTrailCandidate(const ENUM_POSITION_TYPE pos_type)
  {
   const int bars_count = TrailLookback();
   if(pos_type == POSITION_TYPE_BUY)
      return NormalizeStrategyPrice(ExtremeLow(StrategyTf(), bars_count));
   return NormalizeStrategyPrice(ExtremeHigh(StrategyTf(), bars_count));
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasManagedPosition())
     {
      CancelManagedOrders("lien20_position_active");
      ResetSetup();
      return false;
     }

   int breakout_lb = breakout_lookback;
   if(breakout_lb < 2)
      breakout_lb = 2;
   int pullback_lb = pullback_lookback;
   if(pullback_lb < 1)
      pullback_lb = 1;
   int timing_bars = pullback_timing;
   if(timing_bars < 0)
      timing_bars = 0;
   int window_bars = rebreak_window;
   if(window_bars < 1)
      window_bars = 1;

   const int confluence = ConfluenceLookback();
   int requested = breakout_lb + 1;
   if(confluence > breakout_lb)
      requested = confluence + 1;
   if(pullback_lb + 1 > requested)
      requested = pullback_lb + 1;

   MqlRates bars[];
   if(!LoadClosedBars(requested, bars))
      return false;

   if(g_setup_state == LIEN20_SCAN)
     {
      ScanForFreshBreakout(bars, breakout_lb, pullback_lb, confluence);
     }
   else if(g_setup_state == LIEN20_PULLBACK)
     {
      g_pullback_wait++;
      if(g_pullback_wait > timing_bars)
        {
         ResetSetup();
         ScanForFreshBreakout(bars, breakout_lb, pullback_lb, confluence);
        }
      else if(g_setup_direction > 0 && TwoBarLow(bars, pullback_lb))
         ArmRebreak(bars[0].low);
      else if(g_setup_direction < 0 && TwoBarHigh(bars, pullback_lb))
         ArmRebreak(bars[0].high);
      else if(g_pullback_wait >= timing_bars)
        {
         ResetSetup();
         ScanForFreshBreakout(bars, breakout_lb, pullback_lb, confluence);
        }
     }

   if(g_setup_state != LIEN20_REBREAK)
      return false;

   g_rebreak_wait++;
   if(g_rebreak_wait > window_bars)
     {
      CancelManagedOrders("lien20_rebreak_expired");
      ResetSetup();
      ScanForFreshBreakout(bars, breakout_lb, pullback_lb, confluence);
      return false;
     }

   if(HasManagedOrder())
      return false;

   if(BuildRebreakRequest(req))
      return true;

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   bool saw_position = false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      saw_position = true;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market_price <= 0.0)
         continue;

      if(BreakevenOrBetter(pos_type, open_price, current_sl))
         g_tp1_done = true;

      const double tp1_mult = (tp1_rr > 0.0) ? tp1_rr : 1.0;
      const double risk_distance = MathAbs(open_price - current_sl);
      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(!g_tp1_done && current_sl > 0.0 && risk_distance > 0.0 && moved >= risk_distance * tp1_mult)
        {
         const double half = QM_TM_NormalizeVolume(_Symbol, volume * 0.5);
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(half > 0.0 && volume - half >= min_lot - 1e-12)
            QM_TM_PartialClose(ticket, half, QM_EXIT_STRATEGY);

         if(QM_TM_MoveSL(ticket, NormalizeStrategyPrice(open_price), "lien20_tp1_breakeven"))
            g_tp1_done = true;
         continue;
        }

      if(!g_tp1_done)
         continue;

      if(TextContains(trail_method, "ATR14X2"))
        {
         QM_TM_TrailATR(ticket, 14, 2.0);
         continue;
        }
      if(TextContains(trail_method, "ATR14X3"))
        {
         QM_TM_TrailATR(ticket, 14, 3.0);
         continue;
        }

      const double candidate = StructuralTrailCandidate(pos_type);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(candidate <= 0.0 || point <= 0.0)
         continue;

      const bool valid_side = is_buy ? (candidate < market_price) : (candidate > market_price);
      const bool improves = is_buy ? (candidate > current_sl + point * 0.5)
                                   : (candidate < current_sl - point * 0.5);
      if(valid_side && improves)
         QM_TM_MoveSL(ticket, candidate, "lien20_extreme_trail");
     }

   if(!saw_position)
      g_tp1_done = false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1013\",\"strategy\":\"lien-20day-breakout\"}");
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

   if(!QM_IsNewBar(_Symbol, StrategyTf()))
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
