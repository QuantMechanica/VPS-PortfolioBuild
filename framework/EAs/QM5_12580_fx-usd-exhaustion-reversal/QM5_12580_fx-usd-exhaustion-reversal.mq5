#property strict
#property version   "5.0"
#property description "QM5_12580 FX USD Exhaustion Reversal D1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12580;
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
input int    strategy_basket_return_bars  = 3;
input int    strategy_basket_z_lookback   = 80;
input double strategy_basket_z_threshold  = 1.5;
input int    strategy_sma_period          = 10;
input int    strategy_atr_period          = 14;
input double strategy_extension_atr_mult  = 1.2;
input double strategy_stop_atr_mult       = 1.5;
input int    strategy_hold_bars           = 4;

string g_fx_symbols[7] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "AUDUSD.DWX",
   "NZDUSD.DWX",
   "USDJPY.DWX",
   "USDCHF.DWX",
   "USDCAD.DWX"
  };

int SymbolSlot(const string symbol)
  {
   for(int i = 0; i < ArraySize(g_fx_symbols); ++i)
      if(g_fx_symbols[i] == symbol)
         return i;
   return -1;
  }

bool IsUsdBase(const string symbol)
  {
   return (symbol == "USDJPY.DWX" || symbol == "USDCHF.DWX" || symbol == "USDCAD.DWX");
  }

bool IsUsdQuote(const string symbol)
  {
   return (symbol == "EURUSD.DWX" || symbol == "GBPUSD.DWX" ||
           symbol == "AUDUSD.DWX" || symbol == "NZDUSD.DWX");
  }

bool IsFriday()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
  }

bool CloseAt(const string symbol, const int shift, double &value)
  {
   value = 0.0;
   if(shift < 0)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_D1, shift, 1, closes); // perf-allowed: closed-bar basket read gated by QM_IsNewBar in OnTick.
   if(copied != 1 || closes[0] <= 0.0)
      return false;

   value = closes[0];
   return true;
  }

bool UsdReturn(const string symbol, const int shift, const int bars, double &ret)
  {
   ret = 0.0;
   if(bars <= 0)
      return false;

   double c0 = 0.0;
   double cN = 0.0;
   if(!CloseAt(symbol, shift, c0) || !CloseAt(symbol, shift + bars, cN))
      return false;
   if(c0 <= 0.0 || cN <= 0.0)
      return false;

   ret = (c0 / cN) - 1.0;
   if(IsUsdQuote(symbol))
      ret = -ret;
   return IsUsdBase(symbol) || IsUsdQuote(symbol);
  }

bool BasketReturn(const int shift, const int bars, double &ret)
  {
   ret = 0.0;
   double total = 0.0;
   int samples = 0;

   for(int i = 0; i < ArraySize(g_fx_symbols); ++i)
     {
      double r = 0.0;
      if(!UsdReturn(g_fx_symbols[i], shift, bars, r))
         return false;
      total += r;
      samples++;
     }

   if(samples != ArraySize(g_fx_symbols))
      return false;
   ret = total / samples;
   return true;
  }

bool BasketZScore(double &z)
  {
   z = 0.0;
   if(strategy_basket_return_bars <= 0 || strategy_basket_z_lookback < 20)
      return false;

   double current = 0.0;
   if(!BasketReturn(1, strategy_basket_return_bars, current))
      return false;

   double mean = 0.0;
   double values[];
   ArrayResize(values, strategy_basket_z_lookback);
   for(int i = 0; i < strategy_basket_z_lookback; ++i)
     {
      const int shift = 1 + strategy_basket_return_bars + i;
      double r = 0.0;
      if(!BasketReturn(shift, strategy_basket_return_bars, r))
         return false;
      values[i] = r;
      mean += r;
     }
   mean /= strategy_basket_z_lookback;

   double var = 0.0;
   for(int i = 0; i < strategy_basket_z_lookback; ++i)
     {
      const double d = values[i] - mean;
      var += d * d;
     }
   var /= MathMax(1, strategy_basket_z_lookback - 1);
   const double sd = MathSqrt(var);
   if(sd <= 0.0)
      return false;

   z = (current - mean) / sd;
   return true;
  }

int UsdDirectionFromPosition(const string symbol, const ENUM_POSITION_TYPE ptype)
  {
   if(IsUsdBase(symbol))
      return (ptype == POSITION_TYPE_BUY) ? 1 : -1;
   if(IsUsdQuote(symbol))
      return (ptype == POSITION_TYPE_BUY) ? -1 : 1;
   return 0;
  }

bool HasOpenUsdDirection(const int usd_direction)
  {
   if(usd_direction == 0)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const int slot = SymbolSlot(symbol);
      if(slot < 0)
         continue;

      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      const int expected_magic = QM_Magic(qm_ea_id, slot);
      if(expected_magic <= 0 || magic != expected_magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(UsdDirectionFromPosition(symbol, ptype) == usd_direction)
         return true;
     }
   return false;
  }

bool TradeSideForUsdDirection(const string symbol, const int usd_direction, QM_OrderType &side)
  {
   if(usd_direction == 1)
     {
      side = IsUsdBase(symbol) ? QM_BUY : QM_SELL;
      return IsUsdBase(symbol) || IsUsdQuote(symbol);
     }
   if(usd_direction == -1)
     {
      side = IsUsdBase(symbol) ? QM_SELL : QM_BUY;
      return IsUsdBase(symbol) || IsUsdQuote(symbol);
     }
   return false;
  }

bool ExtensionConfirms(const string symbol, const int usd_direction, const double extension)
  {
   if(usd_direction == -1)
      return IsUsdBase(symbol) ? (extension >= strategy_extension_atr_mult)
                               : (extension <= -strategy_extension_atr_mult);
   if(usd_direction == 1)
      return IsUsdBase(symbol) ? (extension <= -strategy_extension_atr_mult)
                               : (extension >= strategy_extension_atr_mult);
   return false;
  }

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

   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return false;
   if(SymbolSlot(_Symbol) != qm_magic_slot_offset)
      return false;
   if(IsFriday())
      return false;
   if(strategy_basket_z_threshold <= 0.0 ||
      strategy_sma_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_extension_atr_mult <= 0.0 ||
      strategy_stop_atr_mult <= 0.0)
      return false;

   double z = 0.0;
   if(!BasketZScore(z))
      return false;

   int usd_direction = 0;
   if(z > strategy_basket_z_threshold)
      usd_direction = -1;
   else if(z < -strategy_basket_z_threshold)
      usd_direction = 1;
   else
      return false;

   if(HasOpenUsdDirection(usd_direction))
      return false;

   double close1 = 0.0;
   if(!CloseAt(_Symbol, 1, close1))
      return false;
   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma <= 0.0 || atr <= 0.0)
      return false;

   const double extension = (close1 - sma) / atr;
   if(!ExtensionConfirms(_Symbol, usd_direction, extension))
      return false;

   QM_OrderType side = QM_BUY;
   if(!TradeSideForUsdDirection(_Symbol, usd_direction, side))
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (usd_direction == 1) ? "USD_EXHAUSTION_LONG_USD"
                                     : "USD_EXHAUSTION_SHORT_USD";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   double close1 = 0.0;
   if(!CloseAt(_Symbol, 1, close1))
      return false;
   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   if(sma <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 >= sma)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 <= sma)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_open = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      if(strategy_hold_bars > 0 && bars_open >= strategy_hold_bars)
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

   if(SymbolSlot(_Symbol) < 0 || SymbolSlot(_Symbol) != qm_magic_slot_offset)
     {
      QM_LogEvent(QM_ERROR, "SETUP_SYMBOL_SLOT_MISMATCH",
                  StringFormat("{\"symbol\":\"%s\",\"slot\":%d}", _Symbol, qm_magic_slot_offset));
      return INIT_FAILED;
     }

   QM_SymbolGuardInit(g_fx_symbols);
   const int warmup = strategy_basket_z_lookback + (strategy_basket_return_bars * 2) +
                      strategy_sma_period + strategy_atr_period + 32;
   QM_BasketWarmupHistory(g_fx_symbols, PERIOD_D1, warmup);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"universe\":7}",
                            _Symbol, qm_magic_slot_offset));
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
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
