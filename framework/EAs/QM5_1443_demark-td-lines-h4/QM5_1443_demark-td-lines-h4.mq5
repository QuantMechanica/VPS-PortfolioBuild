#property strict
#property version   "5.0"
#property description "QM5_1443 DeMark TD Lines Trendline-Break H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1443;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H4;
input int    strategy_atr_period         = 20;
input int    strategy_d1_sma_period      = 50;
input int    strategy_td_scan_bars       = 160;
input int    strategy_min_line_span      = 4;
input int    strategy_max_line_span      = 60;
input int    strategy_reuse_cooldown     = 15;
input double strategy_spread_atr_mult    = 0.20;
input double strategy_entry_buffer_atr   = 0.15;
input double strategy_sl_atr_mult        = 1.50;
input double strategy_tp2_atr_mult       = 1.00;
input int    strategy_time_stop_bars     = 25;
input double strategy_partial_pct        = 0.50;

struct TDLine
  {
   bool   valid;
   int    newer_shift;
   int    older_shift;
   double slope;
   double intercept;
   double range;
   string id;
  };

string   g_consumed_supply_id = "";
string   g_consumed_demand_id = "";
datetime g_consumed_supply_bar = 0;
datetime g_consumed_demand_bar = 0;
datetime g_last_management_bar = 0;
double   g_active_tp1 = 0.0;

double NormalizePrice(const double price)
  {
   return NormalizeDouble(price, _Digits);
  }

double LineValue(const TDLine &line, const int shift)
  {
   return line.slope * (double)shift + line.intercept;
  }

double TrueRangeAt(const int shift)
  {
   const double high = iHigh(_Symbol, strategy_tf, shift);
   const double low = iLow(_Symbol, strategy_tf, shift);
   const double prev_close = iClose(_Symbol, strategy_tf, shift + 1);
   if(high <= 0.0 || low <= 0.0 || prev_close <= 0.0)
      return 0.0;
   return MathMax(high - low, MathMax(MathAbs(high - prev_close), MathAbs(low - prev_close)));
  }

bool IsDemandPoint(const int shift)
  {
   const double low = iLow(_Symbol, strategy_tf, shift);
   return (low > 0.0 &&
           low < iLow(_Symbol, strategy_tf, shift - 1) &&
           low < iLow(_Symbol, strategy_tf, shift + 1));
  }

bool IsSupplyPoint(const int shift)
  {
   const double high = iHigh(_Symbol, strategy_tf, shift);
   return (high > 0.0 &&
           high > iHigh(_Symbol, strategy_tf, shift - 1) &&
           high > iHigh(_Symbol, strategy_tf, shift + 1));
  }

double RangeBetweenAnchors(const int newer_shift, const int older_shift)
  {
   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = newer_shift; i <= older_shift; ++i)
     {
      const double high = iHigh(_Symbol, strategy_tf, i);
      const double low = iLow(_Symbol, strategy_tf, i);
      if(high <= 0.0 || low <= 0.0)
         return 0.0;
      highest = MathMax(highest, high);
      lowest = MathMin(lowest, low);
     }
   return (highest > lowest) ? (highest - lowest) : 0.0;
  }

bool BuildTDLine(const bool supply_line, TDLine &line)
  {
   line.valid = false;
   line.newer_shift = 0;
   line.older_shift = 0;
   line.slope = 0.0;
   line.intercept = 0.0;
   line.range = 0.0;
   line.id = "";

   int newer = -1;
   int older = -1;
   const int max_scan = MathMax(strategy_max_line_span + 4,
                                MathMin(strategy_td_scan_bars, Bars(_Symbol, strategy_tf) - 3));
   for(int shift = 2; shift <= max_scan; ++shift)
     {
      const bool point_ok = supply_line ? IsSupplyPoint(shift) : IsDemandPoint(shift);
      if(!point_ok)
         continue;
      if(newer < 0)
        {
         newer = shift;
         continue;
        }
      older = shift;
      break;
     }

   if(newer < 0 || older < 0)
      return false;

   const int span = older - newer;
   if(span < strategy_min_line_span || span > strategy_max_line_span)
      return false;

   const double newer_price = supply_line ? iHigh(_Symbol, strategy_tf, newer) : iLow(_Symbol, strategy_tf, newer);
   const double older_price = supply_line ? iHigh(_Symbol, strategy_tf, older) : iLow(_Symbol, strategy_tf, older);
   if(newer_price <= 0.0 || older_price <= 0.0)
      return false;

   if(supply_line && newer_price >= older_price)
      return false;
   if(!supply_line && newer_price <= older_price)
      return false;

   line.newer_shift = newer;
   line.older_shift = older;
   line.slope = (newer_price - older_price) / (double)(newer - older);
   line.intercept = older_price - line.slope * (double)older;
   line.range = RangeBetweenAnchors(newer, older);
   line.id = StringFormat("%s:%I64d:%I64d",
                          supply_line ? "S" : "D",
                          (long)iTime(_Symbol, strategy_tf, newer),
                          (long)iTime(_Symbol, strategy_tf, older));
   line.valid = (line.range > 0.0);
   return line.valid;
  }

bool CooldownAllows(const bool supply_line, const string line_id)
  {
   const datetime consumed_bar = supply_line ? g_consumed_supply_bar : g_consumed_demand_bar;
   const string consumed_id = supply_line ? g_consumed_supply_id : g_consumed_demand_id;
   if(consumed_id == line_id)
      return false;
   if(consumed_bar <= 0)
      return true;
   const int bars_since = iBarShift(_Symbol, strategy_tf, consumed_bar, false);
   return (bars_since < 0 || bars_since >= strategy_reuse_cooldown);
  }

void ConsumeLine(const bool supply_line, const string line_id)
  {
   if(supply_line)
     {
      g_consumed_supply_id = line_id;
      g_consumed_supply_bar = iTime(_Symbol, strategy_tf, 1);
     }
   else
     {
      g_consumed_demand_id = line_id;
      g_consumed_demand_bar = iTime(_Symbol, strategy_tf, 1);
     }
  }

bool PerlVolatilityQualifier()
  {
   double sum4 = 0.0;
   for(int i = 1; i <= 4; ++i)
      sum4 += TrueRangeAt(i);
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   return (atr > 0.0 && sum4 >= atr);
  }

bool MacroBiasAllows(const bool bullish)
  {
   const double sma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 2);
   if(sma1 <= 0.0 || sma2 <= 0.0)
      return false;
   return bullish ? (sma1 >= sma2) : (sma1 <= sma2);
  }

bool BullishBreak(const TDLine &supply)
  {
   if(!supply.valid || !CooldownAllows(true, supply.id))
      return false;
   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double close2 = iClose(_Symbol, strategy_tf, 2);
   const double close3 = iClose(_Symbol, strategy_tf, 3);
   const double close4 = iClose(_Symbol, strategy_tf, 4);
   const double open1 = iOpen(_Symbol, strategy_tf, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || close3 <= 0.0 || close4 <= 0.0 || open1 <= 0.0)
      return false;
   if(!(close1 > LineValue(supply, 1) && close2 <= LineValue(supply, 2)))
      return false;
   if(!(close2 < close3))
      return false;
   if(!(open1 > close2 || close1 > 2.0 * close2 - MathMax(close3, close4)))
      return false;
   return (PerlVolatilityQualifier() && MacroBiasAllows(true));
  }

bool BearishBreak(const TDLine &demand)
  {
   if(!demand.valid || !CooldownAllows(false, demand.id))
      return false;
   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double close2 = iClose(_Symbol, strategy_tf, 2);
   const double close3 = iClose(_Symbol, strategy_tf, 3);
   const double close4 = iClose(_Symbol, strategy_tf, 4);
   const double open1 = iOpen(_Symbol, strategy_tf, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || close3 <= 0.0 || close4 <= 0.0 || open1 <= 0.0)
      return false;
   if(!(close1 < LineValue(demand, 1) && close2 >= LineValue(demand, 2)))
      return false;
   if(!(close2 > close3))
      return false;
   if(!(open1 < close2 || close1 < 2.0 * close2 - MathMin(close3, close4)))
      return false;
   return (PerlVolatilityQualifier() && MacroBiasAllows(false));
  }

bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price, double &volume)
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
      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   return ((ask - bid) > strategy_spread_atr_mult * atr);
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

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   if(GetOurPosition(ticket, ptype, open_price, volume))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   TDLine supply;
   TDLine demand;
   BuildTDLine(true, supply);
   BuildTDLine(false, demand);

   if(BullishBreak(supply))
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double max_entry = iClose(_Symbol, strategy_tf, 1) + strategy_entry_buffer_atr * atr;
      if(ask > max_entry)
         return false;
      const double entry = ask;
      const double sl = entry - strategy_sl_atr_mult * atr;
      const double tp1 = LineValue(supply, 1) + supply.range;
      if(entry <= 0.0 || sl <= 0.0 || tp1 <= entry)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizePrice(sl);
      req.tp = NormalizePrice(tp1 + strategy_tp2_atr_mult * atr);
      req.reason = StringFormat("TD_LINES_BUY:%s:TP1=%.8f", supply.id, tp1);
      g_active_tp1 = tp1;
      ConsumeLine(true, supply.id);
      return true;
     }

   if(BearishBreak(demand))
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double min_entry = iClose(_Symbol, strategy_tf, 1) - strategy_entry_buffer_atr * atr;
      if(bid < min_entry)
         return false;
      const double entry = bid;
      const double sl = entry + strategy_sl_atr_mult * atr;
      const double tp1 = LineValue(demand, 1) - demand.range;
      if(entry <= 0.0 || sl <= 0.0 || tp1 >= entry)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizePrice(sl);
      req.tp = NormalizePrice(tp1 - strategy_tp2_atr_mult * atr);
      req.reason = StringFormat("TD_LINES_SELL:%s:TP1=%.8f", demand.id, tp1);
      g_active_tp1 = tp1;
      ConsumeLine(false, demand.id);
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   if(!GetOurPosition(ticket, ptype, open_price, volume))
      return;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double current = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double tp1 = g_active_tp1;
   if(tp1 <= 0.0)
      return;
   const double tp2 = is_buy ? (tp1 + strategy_tp2_atr_mult * atr) : (tp1 - strategy_tp2_atr_mult * atr);
   const double pos_tp = PositionGetDouble(POSITION_TP);

   if(pos_tp != 0.0 && MathAbs(pos_tp - tp2) > SymbolInfoDouble(_Symbol, SYMBOL_POINT))
      QM_TM_MoveTP(ticket, NormalizePrice(tp2), "TD_LINES_TP2_REFRESH");

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double pos_sl = PositionGetDouble(POSITION_SL);
   const bool moved_to_be = (point > 0.0 && MathAbs(pos_sl - open_price) <= point);
   if(!moved_to_be && ((is_buy && current >= tp1) || (!is_buy && current <= tp1)))
     {
      const double partial_lots = volume * MathMax(0.0, MathMin(1.0, strategy_partial_pct));
      if(partial_lots > 0.0)
         QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL);
      QM_TM_MoveSL(ticket, NormalizePrice(open_price), "TD_LINES_TP1_BE");
     }

   const datetime closed_bar = iTime(_Symbol, strategy_tf, 1);
   if(closed_bar > 0 && closed_bar != g_last_management_bar)
     {
      g_last_management_bar = closed_bar;
      TDLine supply;
      TDLine demand;
      BuildTDLine(true, supply);
      BuildTDLine(false, demand);
      if(is_buy && BearishBreak(demand))
        {
         ConsumeLine(false, demand.id);
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
      if(!is_buy && BullishBreak(supply))
        {
         ConsumeLine(true, supply.id);
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   if(!GetOurPosition(ticket, ptype, open_price, volume))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since = iBarShift(_Symbol, strategy_tf, open_time, false);
   return (bars_since >= strategy_time_stop_bars);
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1443\",\"strategy\":\"demark-td-lines-h4\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

   if(!QM_IsNewBar(_Symbol, strategy_tf))
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
