#property strict
#property version   "5.0"
#property description "QM5_1579 Sperandeo TLB swing pivot H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1579;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_tlb_lines               = 3;
input int    strategy_tlb_window_bars         = 260;
input int    strategy_2b_window_bars          = 3;
input int    strategy_atr_period              = 14;
input double strategy_sl_atr_mult             = 2.2;
input double strategy_struct_stop_atr_mult    = 0.25;
input double strategy_trail_atr_mult          = 1.0;
input bool   strategy_use_adx_filter          = true;
input int    strategy_adx_period              = 14;
input double strategy_adx_min                 = 16.0;
input int    strategy_max_spread_points_fx    = 25;
input int    strategy_max_spread_points_cfd   = 50;
input double strategy_spread_atr_mult         = 0.25;

int    g_tlb_dir = 0;
int    g_tlb_latest_flip = 0;
int    g_confirmed_signal_dir = 0;
int    g_confirmed_flip_shift = -1;
double g_confirmed_ref_level = 0.0;
double g_confirmed_bar_high = 0.0;
double g_confirmed_bar_low = 0.0;
double g_tlb_last_level = 0.0;
double g_atr_h4 = 0.0;
bool   g_tlb_ready = false;

string Strategy_SymbolForSlot(const int slot)
  {
   switch(slot)
     {
      case 0: return "EURUSD.DWX";
      case 1: return "GBPUSD.DWX";
      case 2: return "USDJPY.DWX";
      case 3: return "NDX.DWX";
      case 4: return "WS30.DWX";
      case 5: return "XAUUSD.DWX";
      case 6: return "XTIUSD.DWX";
     }
   return "";
  }

bool Strategy_SlotMatchesSymbol()
  {
   return (Strategy_SymbolForSlot(qm_magic_slot_offset) == _Symbol);
  }

bool Strategy_IsFxSymbol()
  {
   string base = _Symbol;
   StringReplace(base, ".DWX", "");
   if(StringLen(base) != 6)
      return false;
   for(int i = 0; i < 6; ++i)
     {
      const ushort ch = StringGetCharacter(base, i);
      if(ch < 'A' || ch > 'Z')
         return false;
     }
   return true;
  }

double Strategy_Close(const int shift)
  {
   return iClose(_Symbol, PERIOD_H4, shift); // perf-allowed: closed-bar state rebuild only
  }

double Strategy_High(const int shift)
  {
   return iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed: closed-bar state rebuild only
  }

double Strategy_Low(const int shift)
  {
   return iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: closed-bar state rebuild only
  }

int Strategy_MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

double Strategy_MaxDouble(const double a, const double b)
  {
   return (a > b) ? a : b;
  }

double Strategy_MinDouble(const double a, const double b)
  {
   return (a < b) ? a : b;
  }

bool Strategy_SpreadAllowed()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || g_atr_h4 <= 0.0)
      return false;

   const double spread_points = (ask - bid) / point;
   const int hard_cap = Strategy_IsFxSymbol() ? strategy_max_spread_points_fx
                                              : strategy_max_spread_points_cfd;
   if(spread_points > (double)hard_cap)
      return false;
   if((ask - bid) > g_atr_h4 * strategy_spread_atr_mult)
      return false;
   return true;
  }

void Strategy_ResetBarState()
  {
   g_tlb_latest_flip = 0;
   g_confirmed_signal_dir = 0;
   g_confirmed_flip_shift = -1;
   g_confirmed_ref_level = 0.0;
   g_confirmed_bar_high = 0.0;
   g_confirmed_bar_low = 0.0;
   g_tlb_last_level = 0.0;
   g_atr_h4 = 0.0;
   g_tlb_ready = false;
  }

void Strategy_AdvanceState_OnNewBar()
  {
   Strategy_ResetBarState();

   g_atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(g_atr_h4 <= 0.0)
      return;

   const int n_lines = Strategy_MaxInt(1, strategy_tlb_lines);
   int window = Strategy_MaxInt(strategy_tlb_window_bars, n_lines + strategy_2b_window_bars + 10);
   const int available = Bars(_Symbol, PERIOD_H4) - 1; // perf-allowed: closed-bar warmup availability check
   if(available <= n_lines + strategy_2b_window_bars + 3)
      return;
   if(window > available)
      window = available;

   double block_close[];
   ArrayResize(block_close, n_lines);
   const double seed_close = Strategy_Close(window);
   if(seed_close <= 0.0)
      return;
   for(int i = 0; i < n_lines; ++i)
      block_close[i] = seed_close;

   int direction = 0;
   int recent_flip_dir = 0;
   int recent_flip_shift = -1;
   double recent_flip_ref = 0.0;

   for(int shift = window - 1; shift >= 1; --shift)
     {
      const double c = Strategy_Close(shift);
      if(c <= 0.0)
         continue;

      double hi = block_close[0];
      double lo = block_close[0];
      for(int j = 1; j < n_lines; ++j)
        {
         if(block_close[j] > hi)
            hi = block_close[j];
         if(block_close[j] < lo)
            lo = block_close[j];
        }

      int next_dir = direction;
      bool append_line = false;
      bool flipped = false;
      double flip_ref = block_close[0];

      if(direction >= 0)
        {
         if(c > block_close[0])
           {
            next_dir = 1;
            append_line = true;
           }
         else if(c < lo)
           {
            next_dir = -1;
            append_line = true;
            flipped = true;
            flip_ref = lo;
           }
        }
      if(!append_line && direction <= 0)
        {
         if(c < block_close[0])
           {
            next_dir = -1;
            append_line = true;
           }
         else if(c > hi)
           {
            next_dir = 1;
            append_line = true;
            flipped = true;
            flip_ref = hi;
           }
        }

      if(!append_line)
         continue;

      for(int j = n_lines - 1; j > 0; --j)
         block_close[j] = block_close[j - 1];
      block_close[0] = c;
      direction = next_dir;

      if(flipped)
        {
         recent_flip_dir = direction;
         recent_flip_shift = shift;
         recent_flip_ref = flip_ref;
         if(shift == 1)
            g_tlb_latest_flip = direction;
        }
     }

   g_tlb_dir = direction;
   g_tlb_last_level = block_close[0];
   g_tlb_ready = (direction != 0 && g_tlb_last_level > 0.0);

   const int bars_after_flip = recent_flip_shift - 1;
   if(recent_flip_dir == 0 || bars_after_flip < 1 || bars_after_flip > strategy_2b_window_bars)
      return;

   const double c1 = Strategy_Close(1);
   const double h1 = Strategy_High(1);
   const double l1 = Strategy_Low(1);
   if(c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || recent_flip_ref <= 0.0)
      return;

   if(recent_flip_dir < 0 && h1 > recent_flip_ref && c1 < recent_flip_ref)
     {
      g_confirmed_signal_dir = -1;
      g_confirmed_flip_shift = recent_flip_shift;
      g_confirmed_ref_level = recent_flip_ref;
      g_confirmed_bar_high = h1;
      g_confirmed_bar_low = l1;
     }
   else if(recent_flip_dir > 0 && l1 < recent_flip_ref && c1 > recent_flip_ref)
     {
      g_confirmed_signal_dir = 1;
      g_confirmed_flip_shift = recent_flip_shift;
      g_confirmed_ref_level = recent_flip_ref;
      g_confirmed_bar_high = h1;
      g_confirmed_bar_low = l1;
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H4)
      return true;
   if(qm_magic_slot_offset < 0 || qm_magic_slot_offset > 6)
      return true;
   if(!Strategy_SlotMatchesSymbol())
      return true;
   if(!g_tlb_ready || g_atr_h4 <= 0.0)
      return true;
   if(!Strategy_SpreadAllowed())
      return true;
   return false;
  }

bool Strategy_AdxAllows()
  {
   if(!strategy_use_adx_filter)
      return true;
   const double adx = QM_ADX(_Symbol, PERIOD_H4, strategy_adx_period, 1);
   return (adx >= strategy_adx_min);
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

   if(g_confirmed_signal_dir == 0)
      return false;
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(!Strategy_AdxAllows())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || g_atr_h4 <= 0.0)
      return false;

   if(g_confirmed_signal_dir > 0)
     {
      req.type = QM_BUY;
      req.price = ask;
      const double atr_stop = ask - g_atr_h4 * strategy_sl_atr_mult;
      const double struct_stop = g_confirmed_bar_low - g_atr_h4 * strategy_struct_stop_atr_mult;
      req.sl = Strategy_MaxDouble(atr_stop, struct_stop);
      req.tp = 0.0;
      req.reason = "QM5_1579_TLB_UP_2B_FAILDOWN";
      return (req.sl > 0.0 && req.sl < req.price);
     }

   req.type = QM_SELL;
   req.price = bid;
   const double atr_stop = bid + g_atr_h4 * strategy_sl_atr_mult;
   const double struct_stop = g_confirmed_bar_high + g_atr_h4 * strategy_struct_stop_atr_mult;
   req.sl = Strategy_MinDouble(atr_stop, struct_stop);
   req.tp = 0.0;
   req.reason = "QM5_1579_TLB_DOWN_2B_FAILUP";
   return (req.sl > req.price);
  }

void Strategy_ManageOpenPosition()
  {
   if(!g_tlb_ready || g_atr_h4 <= 0.0 || strategy_trail_atr_mult <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         continue;

      if(position_type == POSITION_TYPE_BUY && g_tlb_dir > 0)
        {
         const double target = g_tlb_last_level - g_atr_h4 * strategy_trail_atr_mult;
         if(target > 0.0 && (current_sl <= 0.0 || target > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, target, "QM5_1579_TLB_TRAIL_LONG");
        }
      else if(position_type == POSITION_TYPE_SELL && g_tlb_dir < 0)
        {
         const double target = g_tlb_last_level + g_atr_h4 * strategy_trail_atr_mult;
         if(target > 0.0 && (current_sl <= 0.0 || target < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, target, "QM5_1579_TLB_TRAIL_SHORT");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   if(g_confirmed_signal_dir == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && g_confirmed_signal_dir < 0)
         return true;
      if(position_type == POSITION_TYPE_SELL && g_confirmed_signal_dir > 0)
         return true;
     }
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

   const bool new_bar = QM_IsNewBar(_Symbol, PERIOD_H4);
   if(new_bar)
      Strategy_AdvanceState_OnNewBar();

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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!new_bar)
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
