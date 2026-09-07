#ifndef QM_CHARTPANEL_MQH
#define QM_CHARTPANEL_MQH

#include <QM/QM_ChartScheme.mqh>

// QuantMechanica Signature Chart Panel v3.
// Presentation only: creates chart objects and reads terminal/account history.
// It never sends, changes, or closes orders. Render from OnTimer, never OnTick.

#define QM_PANEL_FONT      "Segoe UI"
#define QM_PANEL_FONT_MONO "Consolas"
#define QM_PANEL_ROWS      34
#define QM_PANEL_REFRESH_SECONDS 30

struct QMChartPanelSnapshot
  {
   string trading_state;
   string trading_reason;
   string news_state;
   string news_detail;
   string friday_state;
   string friday_countdown;
   string governor_state;
   string governor_reason;
   string kill_switch_state;
   string spread_state;
   string session_state;
   string risk_mode;
   string risk_per_trade;
   string effective_risk;
   string daily_room;
   string total_room;
   string last_signal;
   string calendar_health;
   string heartbeat_state;
   string build_version;
   string support_line;
  };

struct QMPanelTrade
  {
   ulong position_id;
   double pnl;
   datetime close_time;
   ENUM_DEAL_REASON close_reason;
   bool has_exit;
  };

struct QMPanelPerformance
  {
   bool valid;
   string error;
   int closed_today;
   int closed_since_attach;
   int closed_total;
   int wins;
   int losses;
   double gross_profit;
   double gross_loss;
   double net_profit;
   double average_win;
   double average_loss;
   double profit_factor;
   bool profit_factor_infinite;
   double expectancy;
   double max_drawdown_money;
   double max_drawdown_percent;
   int current_win_streak;
   int current_loss_streak;
   int longest_win_streak;
   int longest_loss_streak;
   double best_trade;
   double worst_trade;
   double last_trade;
   datetime last_trade_time;
   ENUM_DEAL_REASON last_trade_reason;
   double account_today_pnl;
  };

string QM_PanelAscii(const string value)
  {
   string out = "";
   for(int i = 0; i < StringLen(value); ++i)
     {
      const ushort ch = StringGetCharacter(value, i);
      out += ShortToString((ushort)((ch >= 32 && ch <= 126) ? ch : 32));
     }
   return out;
  }

string QM_PanelTimeframeName(const ENUM_TIMEFRAMES value)
  {
   string name = EnumToString(value);
   if(StringFind(name, "PERIOD_") == 0)
      return StringSubstr(name, 7);
   return name;
  }

string QM_PanelFormatNumber(const double value, const int requested_decimals,
                            const bool show_plus = false)
  {
   const int decimals = (int)MathMax(0, MathMin(4, requested_decimals));
   long scale = 1;
   for(int i = 0; i < decimals; ++i)
      scale *= 10;
   const long scaled = (long)MathRound(MathAbs(value) * (double)scale);
   const long whole = scaled / scale;
   const long fraction = scaled % scale;
   string grouped = StringFormat("%I64d", whole);
   for(int at = StringLen(grouped) - 3; at > 0; at -= 3)
      grouped = StringSubstr(grouped, 0, at) + "." + StringSubstr(grouped, at);
   if(decimals > 0)
     {
      string fraction_text = StringFormat("%I64d", fraction);
      while(StringLen(fraction_text) < decimals)
         fraction_text = "0" + fraction_text;
      grouped += "," + fraction_text;
     }
   if(value < 0.0)
      return "-" + grouped;
   if(show_plus && value > 0.0)
      return "+" + grouped;
   return grouped;
  }

string QM_PanelMoney(const double value, const bool show_plus = false)
  {
   return AccountInfoString(ACCOUNT_CURRENCY) + " " +
          QM_PanelFormatNumber(value, 2, show_plus);
  }

string QM_PanelPercent(const double value, const bool show_plus = false)
  {
   return QM_PanelFormatNumber(value, 2, show_plus) + " %";
  }

string QM_PanelPips(const double value)
  {
   return QM_PanelFormatNumber(value, 1, false) + " pip";
  }

string QM_PanelDuration(const long raw_seconds)
  {
   const long seconds = (long)MathMax(0, raw_seconds);
   const long hours = seconds / 3600;
   const long minutes = (seconds % 3600) / 60;
   return StringFormat("%02d:%02d", hours, minutes);
  }

string QM_PanelDateTime(const datetime value)
  {
   if(value <= 0)
      return "N/A";
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return StringFormat("%04d-%02d-%02d %02d:%02d",
                       parts.year, parts.mon, parts.day, parts.hour, parts.min);
  }

bool QM_PanelFormatterSelfTest()
  {
   return QM_PanelFormatNumber(100000.0, 2) == "100.000,00" &&
          QM_PanelFormatNumber(-1234.5, 2) == "-1.234,50" &&
          QM_PanelFormatNumber(0.31, 2) + " %" == "0,31 %" &&
          QM_PanelDuration(3720) == "01:02";
  }

string QM_PanelMaskedLogin()
  {
   const string login = StringFormat("%I64d", AccountInfoInteger(ACCOUNT_LOGIN));
   if(StringLen(login) <= 4)
      return "****";
   return "****" + StringSubstr(login, StringLen(login) - 4);
  }

string QM_PanelEnvironment()
  {
   const long mode = AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode == ACCOUNT_TRADE_MODE_REAL)
      return "LIVE";
   if(mode == ACCOUNT_TRADE_MODE_DEMO)
      return "DEMO";
   if(mode == ACCOUNT_TRADE_MODE_CONTEST)
      return "CONTEST";
   return "UNKNOWN";
  }

string QM_PanelNextBar()
  {
   const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const datetime bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   if(seconds <= 0 || bar <= 0)
      return "N/A (bar clock unavailable)";
   const datetime next = bar + seconds;
   return QM_PanelDateTime(next) + " BT | " +
          QM_PanelDuration((long)(next - TimeCurrent()));
  }

int QM_PanelFindTrade(QMPanelTrade &trades[], const ulong position_id)
  {
   for(int i = 0; i < ArraySize(trades); ++i)
      if(trades[i].position_id == position_id)
         return i;
   const int index = ArraySize(trades);
   ArrayResize(trades, index + 1);
   trades[index].position_id = position_id;
   trades[index].pnl = 0.0;
   trades[index].close_time = 0;
   trades[index].close_reason = DEAL_REASON_CLIENT;
   trades[index].has_exit = false;
   return index;
  }

bool QM_PanelPositionIdentifierOpen(const ulong position_id)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionSelectByTicket(ticket) &&
         (ulong)PositionGetInteger(POSITION_IDENTIFIER) == position_id)
         return true;
     }
   return false;
  }

double QM_PanelFloatingForMagic(const long magic)
  {
   double floating = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      floating += PositionGetDouble(POSITION_PROFIT) +
                  PositionGetDouble(POSITION_SWAP);
     }
   return floating;
  }

void QM_PanelResetPerformance(QMPanelPerformance &stats)
  {
   stats.valid = false;
   stats.error = "N/A (history unavailable)";
   stats.closed_today = 0;
   stats.closed_since_attach = 0;
   stats.closed_total = 0;
   stats.wins = 0;
   stats.losses = 0;
   stats.gross_profit = 0.0;
   stats.gross_loss = 0.0;
   stats.net_profit = 0.0;
   stats.average_win = 0.0;
   stats.average_loss = 0.0;
   stats.profit_factor = 0.0;
   stats.profit_factor_infinite = false;
   stats.expectancy = 0.0;
   stats.max_drawdown_money = 0.0;
   stats.max_drawdown_percent = 0.0;
   stats.current_win_streak = 0;
   stats.current_loss_streak = 0;
   stats.longest_win_streak = 0;
   stats.longest_loss_streak = 0;
   stats.best_trade = 0.0;
   stats.worst_trade = 0.0;
   stats.last_trade = 0.0;
   stats.last_trade_time = 0;
   stats.last_trade_reason = DEAL_REASON_CLIENT;
   stats.account_today_pnl = 0.0;
  }

bool QM_PanelBuildPerformance(const long magic, const datetime attached_at,
                              const double start_equity,
                              QMPanelPerformance &stats)
  {
   QM_PanelResetPerformance(stats);
   const datetime now = TimeCurrent();
   if(!HistorySelect(0, now))
      return false;

   MqlDateTime day;
   TimeToStruct(now, day);
   day.hour = 0;
   day.min = 0;
   day.sec = 0;
   const datetime today_start = StructToTime(day);
   QMPanelTrade trades[];
   const int deals_total = HistoryDealsTotal();
   for(int i = 0; i < deals_total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const long type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      const datetime when = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const double value = HistoryDealGetDouble(deal, DEAL_PROFIT) +
                           HistoryDealGetDouble(deal, DEAL_SWAP) +
                           HistoryDealGetDouble(deal, DEAL_COMMISSION) +
                           HistoryDealGetDouble(deal, DEAL_FEE);
      if(when >= today_start)
         stats.account_today_pnl += value;
      if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      const ulong position_id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      const int index = QM_PanelFindTrade(trades, position_id);
      trades[index].pnl += value;
      const long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT)
        {
         trades[index].has_exit = true;
         if(when >= trades[index].close_time)
           {
            trades[index].close_time = when;
            trades[index].close_reason =
               (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON);
           }
        }
     }

   QMPanelTrade closed[];
   for(int i = 0; i < ArraySize(trades); ++i)
     {
      if(!trades[i].has_exit || QM_PanelPositionIdentifierOpen(trades[i].position_id))
         continue;
      const int index = ArraySize(closed);
      ArrayResize(closed, index + 1);
      closed[index] = trades[i];
     }
   for(int i = 0; i < ArraySize(closed) - 1; ++i)
      for(int j = i + 1; j < ArraySize(closed); ++j)
         if(closed[j].close_time < closed[i].close_time)
           {
            QMPanelTrade swap = closed[i];
            closed[i] = closed[j];
            closed[j] = swap;
           }

   double curve = 0.0;
   double peak = 0.0;
   int run_wins = 0;
   int run_losses = 0;
   for(int i = 0; i < ArraySize(closed); ++i)
     {
      const double pnl = closed[i].pnl;
      ++stats.closed_total;
      if(closed[i].close_time >= today_start)
         ++stats.closed_today;
      if(closed[i].close_time >= attached_at)
         ++stats.closed_since_attach;
      stats.net_profit += pnl;
      if(stats.closed_total == 1 || pnl > stats.best_trade)
         stats.best_trade = pnl;
      if(stats.closed_total == 1 || pnl < stats.worst_trade)
         stats.worst_trade = pnl;
      if(pnl > 0.0)
        {
         ++stats.wins;
         stats.gross_profit += pnl;
         ++run_wins;
         run_losses = 0;
         stats.longest_win_streak = (int)MathMax(stats.longest_win_streak, run_wins);
        }
      else if(pnl < 0.0)
        {
         ++stats.losses;
         stats.gross_loss += pnl;
         ++run_losses;
         run_wins = 0;
         stats.longest_loss_streak = (int)MathMax(stats.longest_loss_streak, run_losses);
        }
      else
        {
         run_wins = 0;
         run_losses = 0;
        }
      curve += pnl;
      peak = MathMax(peak, curve);
      stats.max_drawdown_money = MathMax(stats.max_drawdown_money, peak - curve);
     }
   const double final_curve = curve + QM_PanelFloatingForMagic(magic);
   stats.max_drawdown_money = MathMax(stats.max_drawdown_money, peak - final_curve);
   stats.max_drawdown_percent = start_equity > 0.0
      ? stats.max_drawdown_money / start_equity * 100.0 : 0.0;
   stats.current_win_streak = run_wins;
   stats.current_loss_streak = run_losses;
   stats.average_win = stats.wins > 0 ? stats.gross_profit / stats.wins : 0.0;
   stats.average_loss = stats.losses > 0 ? stats.gross_loss / stats.losses : 0.0;
   stats.profit_factor_infinite = stats.gross_profit > 0.0 && stats.gross_loss == 0.0;
   stats.profit_factor = stats.gross_loss < 0.0
      ? stats.gross_profit / MathAbs(stats.gross_loss) : 0.0;
   stats.expectancy = stats.closed_total > 0 ? stats.net_profit / stats.closed_total : 0.0;
   if(stats.closed_total > 0)
     {
      const int last = stats.closed_total - 1;
      stats.last_trade = closed[last].pnl;
      stats.last_trade_time = closed[last].close_time;
      stats.last_trade_reason = closed[last].close_reason;
     }
   stats.valid = true;
   stats.error = "";
   return true;
  }

void QM_PanelPositionLines(const long magic, string &lines[],
                           double &risk_money, int &without_stop,
                           int &position_count)
  {
   ArrayResize(lines, 3);
   for(int i = 0; i < 3; ++i)
      lines[i] = "NONE";
   risk_money = 0.0;
   without_stop = 0;
   position_count = 0;
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      const double lots = PositionGetDouble(POSITION_VOLUME);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);
      const double pnl = PositionGetDouble(POSITION_PROFIT) +
                         PositionGetDouble(POSITION_SWAP);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const long type = PositionGetInteger(POSITION_TYPE);
      if(sl <= 0.0)
         ++without_stop;
      else
        {
         double projected = 0.0;
         const ENUM_ORDER_TYPE order_type =
            (type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(OrderCalcProfit(order_type, symbol, lots, entry, sl, projected))
            risk_money += MathAbs(MathMin(0.0, projected));
         else
            ++without_stop;
        }
      if(position_count < 3)
         lines[position_count] = StringFormat("%s %s %s @ %.*f | SL %.*f TP %.*f | %s (%s) | %s",
            symbol, type == POSITION_TYPE_BUY ? "BUY" : "SELL",
            QM_PanelFormatNumber(lots, 2), digits, entry, digits, sl, digits, tp,
            QM_PanelMoney(pnl, true),
            QM_PanelPercent(balance > 0.0 ? pnl / balance * 100.0 : 0.0, true),
            QM_PanelDuration((long)(TimeCurrent() - opened)));
      ++position_count;
     }
   if(position_count > 3)
      lines[2] += StringFormat(" | +%d MORE", position_count - 3);
  }

void QM_PanelOrderLines(const long magic, string &lines[], int &order_count)
  {
   ArrayResize(lines, 3);
   for(int i = 0; i < 3; ++i)
      lines[i] = "NONE";
   order_count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         (long)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(order_count < 3)
        {
         const string symbol = OrderGetString(ORDER_SYMBOL);
         const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         const datetime expiry = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         lines[order_count] = StringFormat("%s %s %s @ %.*f | SL %.*f TP %.*f | EXP %s",
            symbol, EnumToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)),
            QM_PanelFormatNumber(OrderGetDouble(ORDER_VOLUME_CURRENT), 2),
            digits, OrderGetDouble(ORDER_PRICE_OPEN),
            digits, OrderGetDouble(ORDER_SL), digits, OrderGetDouble(ORDER_TP),
            expiry > 0 ? QM_PanelDateTime(expiry) + " BT" : "GTC");
        }
      ++order_count;
     }
   if(order_count > 3)
      lines[2] += StringFormat(" | +%d MORE", order_count - 3);
  }

class CQMChartPanel
  {
private:
   long m_chart;
   string m_prefix;
   string m_ea_id;
   string m_slug;
   long m_magic;
   string m_build_hash;
   bool m_ready;
   bool m_wide;
   int m_corner;
   int m_x;
   int m_y;
   datetime m_attached_at;
   double m_start_equity;
   datetime m_performance_refreshed_at;
   bool m_performance_dirty;
   QMPanelPerformance m_performance;

   string Name(const string suffix) const { return m_prefix + suffix; }
   int RightX() const { return m_wide ? 554 : 12; }
   int RightY() const { return m_wide ? 0 : 440; }

   bool MakeRect(const string suffix, const int x, const int y,
                 const int width, const int height,
                 const color background, const color border)
     {
      const string name = Name(suffix);
      if(ObjectFind(m_chart, name) < 0 &&
         !ObjectCreate(m_chart, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(m_chart, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chart, name, OBJPROP_XDISTANCE, m_x + x);
      ObjectSetInteger(m_chart, name, OBJPROP_YDISTANCE, m_y + y);
      ObjectSetInteger(m_chart, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(m_chart, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(m_chart, name, OBJPROP_BGCOLOR, background);
      ObjectSetInteger(m_chart, name, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(m_chart, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart, name, OBJPROP_ZORDER, 900);
      return true;
     }

   bool MakeLabel(const string suffix, const int x, const int y,
                  const string value, const color foreground,
                  const int font_size, const string font = QM_PANEL_FONT_MONO,
                  const ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
     {
      const string name = Name(suffix);
      if(ObjectFind(m_chart, name) < 0 &&
         !ObjectCreate(m_chart, name, OBJ_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(m_chart, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chart, name, OBJPROP_XDISTANCE, m_x + x);
      ObjectSetInteger(m_chart, name, OBJPROP_YDISTANCE, m_y + y);
      ObjectSetInteger(m_chart, name, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, foreground);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, font_size);
      ObjectSetInteger(m_chart, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart, name, OBJPROP_ZORDER, 910);
      ObjectSetString(m_chart, name, OBJPROP_FONT, font);
      ObjectSetString(m_chart, name, OBJPROP_TEXT, QM_PanelAscii(value));
      return true;
     }

   bool MakeSection(const string suffix, const int x, const int y,
                    const string title)
     {
      return MakeRect(suffix + "_bg", x, y, 524, 20,
                      QM_SCHEME_SECTION, QM_SCHEME_BORDER) &&
             MakeLabel(suffix + "_title", x + 9, y + 3, title,
                       QM_SCHEME_STEEL, 8, QM_PANEL_FONT);
     }

   bool MakeRow(const int row, const int x, const int y, const string label)
     {
      const string key = StringFormat("r%02d", row);
      return MakeLabel(key + "_label", x + 10, y, label,
                       QM_SCHEME_MUTED, 8, QM_PANEL_FONT) &&
             MakeLabel(key + "_value", x + 514, y, "-",
                       QM_SCHEME_TEXT, 7, QM_PANEL_FONT_MONO,
                       ANCHOR_RIGHT_UPPER);
     }

   void SetRow(const int row, const string value, const color foreground)
     {
      const string name = Name(StringFormat("r%02d_value", row));
      ObjectSetString(m_chart, name, OBJPROP_TEXT, QM_PanelAscii(value));
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, foreground);
     }

   color StateColor(const string value) const
     {
      string state = value;
      StringToUpper(state);
      if(StringFind(state, "NO") == 0 || StringFind(state, "BLOCK") >= 0 ||
         StringFind(state, "HALT") >= 0 || StringFind(state, "FAIL") >= 0 ||
         StringFind(state, "STALE") >= 0 || StringFind(state, "DOWN") >= 0 ||
         StringFind(state, "CLOSE") >= 0)
         return QM_SCHEME_RED;
      if(StringFind(state, "N/A") >= 0 || StringFind(state, "UNBOUND") >= 0 ||
         StringFind(state, "UNAVAILABLE") >= 0 || StringFind(state, "NEAR") >= 0)
         return QM_SCHEME_AMBER;
      return QM_SCHEME_EMERALD;
     }

   color ProfitColor(const double value) const
     {
      if(value > 0.0)
         return QM_SCHEME_EMERALD;
      if(value < 0.0)
         return QM_SCHEME_RED;
      return QM_SCHEME_TEXT;
     }

public:
   CQMChartPanel(void)
     {
      m_chart = 0;
      m_prefix = "";
      m_ea_id = "";
      m_slug = "";
      m_magic = 0;
      m_build_hash = "";
      m_ready = false;
      m_wide = true;
      m_corner = CORNER_LEFT_UPPER;
      m_x = 16;
      m_y = 24;
      m_attached_at = 0;
      m_start_equity = 0.0;
      m_performance_refreshed_at = 0;
      m_performance_dirty = true;
      QM_PanelResetPerformance(m_performance);
     }

   bool Initialize(const long chart_id, const int ea_id, const string slug,
                   const long magic, const string build_hash,
                   const bool enabled = true,
                   const int corner = CORNER_LEFT_UPPER,
                   const int x = 16, const int y = 24)
     {
      m_ready = false;
      if(!enabled || MQLInfoInteger(MQL_TESTER) != 0)
         return false;
      m_chart = chart_id;
      m_ea_id = IntegerToString(ea_id);
      m_slug = QM_PanelAscii(slug);
      m_magic = magic;
      m_build_hash = QM_PanelAscii(build_hash);
      m_corner = corner;
      m_x = x;
      m_y = y;
      m_attached_at = TimeCurrent();
      m_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_performance_refreshed_at = 0;
      m_performance_dirty = true;
      m_prefix = "QM_SIG_" + m_ea_id + "_" + StringFormat("%I64d", magic) + "_";
      const long chart_width = ChartGetInteger(chart_id, CHART_WIDTH_IN_PIXELS, 0);
      m_wide = (chart_width <= 0 || chart_width >= 1200);
      const int width = m_wide ? 1090 : 548;
      const int height = m_wide ? 550 : 970;

      if(!MakeRect("bg", 0, 0, width, height, QM_SCHEME_SURFACE, QM_SCHEME_BORDER)) return false;
      if(!MakeRect("rail", 0, 0, 5, height, QM_SCHEME_STEEL, QM_SCHEME_STEEL)) return false;
      if(!MakeLabel("brand", 18, 10, "QM | QUANTMECHANICA", QM_SCHEME_STEEL, 11, QM_PANEL_FONT)) return false;
      if(!MakeLabel("summary", 18, 34, "Trading -- | Net P/L --", QM_SCHEME_TEXT, 10, QM_PANEL_FONT_MONO)) return false;

      if(!MakeSection("state", 12, 62, "STATE | MAY I TRADE?")) return false;
      if(!MakeRow(0, 12, 87, "Trading")) return false;
      if(!MakeRow(1, 12, 107, "News")) return false;
      if(!MakeRow(2, 12, 127, "Governor")) return false;
      if(!MakeRow(3, 12, 147, "Kill switch")) return false;
      if(!MakeRow(4, 12, 167, "Filters")) return false;

      if(!MakeSection("performance", 12, 194, "PERFORMANCE | THIS MAGIC")) return false;
      if(!MakeRow(5, 12, 219, "Trades T/A/All")) return false;
      if(!MakeRow(6, 12, 239, "Wins / losses")) return false;
      if(!MakeRow(7, 12, 259, "Net P/L")) return false;
      if(!MakeRow(8, 12, 279, "Gross + / -")) return false;
      if(!MakeRow(9, 12, 299, "PF / expectancy")) return false;
      if(!MakeRow(10, 12, 319, "Avg win / loss")) return false;
      if(!MakeRow(11, 12, 339, "Max drawdown")) return false;
      if(!MakeRow(12, 12, 359, "Streaks now / max")) return false;
      if(!MakeRow(13, 12, 379, "Best / worst")) return false;
      if(!MakeRow(14, 12, 399, "Last trade")) return false;
      if(!MakeRow(15, 12, 419, "Account")) return false;

      if(!MakeSection("risk", 12, 446, "RISK / ROOM")) return false;
      if(!MakeRow(16, 12, 471, "Next-trade risk")) return false;
      if(!MakeRow(17, 12, 491, "Daily / total room")) return false;
      if(!MakeRow(18, 12, 511, "Open risk to SL")) return false;

      const int rx = RightX();
      const int ry = RightY();
      if(!MakeSection("positions", rx, ry + 62, "POSITION / ORDERS | THIS MAGIC")) return false;
      if(!MakeRow(19, rx, ry + 87, "Position 1")) return false;
      if(!MakeRow(20, rx, ry + 107, "Position 2")) return false;
      if(!MakeRow(21, rx, ry + 127, "Position 3")) return false;
      if(!MakeRow(22, rx, ry + 153, "Order 1")) return false;
      if(!MakeRow(23, rx, ry + 173, "Order 2")) return false;
      if(!MakeRow(24, rx, ry + 193, "Order 3")) return false;

      if(!MakeSection("next", rx, ry + 220, "NEXT")) return false;
      if(!MakeRow(25, rx, ry + 245, "Next decision")) return false;
      if(!MakeRow(26, rx, ry + 265, "Last signal")) return false;

      if(!MakeSection("health", rx, ry + 292, "HEALTH")) return false;
      if(!MakeRow(27, rx, ry + 317, "Heartbeat")) return false;
      if(!MakeRow(28, rx, ry + 337, "Calendar")) return false;

      if(!MakeSection("identity", rx, ry + 364, "IDENTITY")) return false;
      if(!MakeRow(29, rx, ry + 389, "EA")) return false;
      if(!MakeRow(30, rx, ry + 409, "Chart")) return false;
      if(!MakeRow(31, rx, ry + 429, "Environment")) return false;
      if(!MakeRow(32, rx, ry + 449, "Build / license")) return false;
      if(!MakeRow(33, rx, ry + 469, "Support")) return false;
      if(!MakeLabel("footer", 18, height - 20,
                    "Read-only telemetry | broker time | 30 s history cache",
                    QM_SCHEME_MUTED, 7, QM_PANEL_FONT)) return false;
      m_ready = true;
      return true;
     }

   bool Ready(void) const { return m_ready; }

   void InvalidatePerformance(void)
     {
      m_performance_dirty = true;
     }

   void Refresh(const QMChartPanelSnapshot &snapshot)
     {
      if(!m_ready)
         return;
      const datetime now = TimeCurrent();
      if(m_performance_dirty || m_performance_refreshed_at <= 0 ||
         now - m_performance_refreshed_at >= QM_PANEL_REFRESH_SECONDS)
        {
         QM_PanelBuildPerformance(m_magic, m_attached_at, m_start_equity,
                                  m_performance);
         m_performance_refreshed_at = now;
         m_performance_dirty = false;
        }

      const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      string positions[];
      string orders[];
      double risk_money = 0.0;
      int without_stop = 0;
      int position_count = 0;
      int order_count = 0;
      QM_PanelPositionLines(m_magic, positions, risk_money, without_stop, position_count);
      QM_PanelOrderLines(m_magic, orders, order_count);
      MqlTick tick;
      const bool tick_ok = SymbolInfoTick(_Symbol, tick);
      const long tick_age = tick_ok ? (long)(TimeCurrent() - tick.time) : -1;
      const string connection = TerminalInfoInteger(TERMINAL_CONNECTED) ? "UP" : "DOWN";
      const double net_pct = m_start_equity > 0.0
         ? m_performance.net_profit / m_start_equity * 100.0 : 0.0;
      const double win_rate = m_performance.closed_total > 0
         ? (double)m_performance.wins / m_performance.closed_total * 100.0 : 0.0;
      const string risk_text = without_stop > 0
         ? StringFormat("UNPRICED / %d position(s) without SL", without_stop)
         : QM_PanelMoney(risk_money) + " | " +
           QM_PanelPercent(balance > 0.0 ? risk_money / balance * 100.0 : 0.0);

      ObjectSetString(m_chart, Name("summary"), OBJPROP_TEXT,
         QM_PanelAscii("Trading " + snapshot.trading_state + " | Net P/L " +
                       (m_performance.valid ? QM_PanelMoney(m_performance.net_profit, true)
                                            : "N/A")));
      ObjectSetInteger(m_chart, Name("summary"), OBJPROP_COLOR,
         snapshot.trading_state == "YES" ? ProfitColor(m_performance.net_profit)
                                          : StateColor(snapshot.trading_state));

      SetRow(0, snapshot.trading_state + " | " + snapshot.trading_reason,
             StateColor(snapshot.trading_state));
      SetRow(1, snapshot.news_state + " | " + snapshot.news_detail,
             StateColor(snapshot.news_state));
      SetRow(2, snapshot.governor_state + " | " + snapshot.governor_reason,
             StateColor(snapshot.governor_state));
      SetRow(3, snapshot.kill_switch_state, StateColor(snapshot.kill_switch_state));
      SetRow(4, "FRI " + snapshot.friday_state + " " + snapshot.friday_countdown +
                " | SPREAD " + snapshot.spread_state + " | SESSION " + snapshot.session_state,
             StateColor(snapshot.friday_state + " " + snapshot.spread_state));

      if(m_performance.valid)
        {
         SetRow(5, StringFormat("%d / %d / %d", m_performance.closed_today,
                               m_performance.closed_since_attach,
                               m_performance.closed_total), QM_SCHEME_TEXT);
         SetRow(6, StringFormat("%d / %d | %s", m_performance.wins,
                               m_performance.losses,
                               QM_PanelPercent(win_rate)), QM_SCHEME_TEXT);
         SetRow(7, QM_PanelMoney(m_performance.net_profit, true) + " | " +
                   QM_PanelPercent(net_pct, true) + " attach EQ",
                ProfitColor(m_performance.net_profit));
         SetRow(8, QM_PanelMoney(m_performance.gross_profit, true) + " / " +
                   QM_PanelMoney(m_performance.gross_loss), QM_SCHEME_TEXT);
         const string pf = m_performance.profit_factor_infinite ? "INF" :
                           QM_PanelFormatNumber(m_performance.profit_factor, 2);
         SetRow(9, pf + " / " + QM_PanelMoney(m_performance.expectancy, true) +
                   " per trade", ProfitColor(m_performance.expectancy));
         SetRow(10, QM_PanelMoney(m_performance.average_win, true) + " / " +
                    QM_PanelMoney(m_performance.average_loss), QM_SCHEME_TEXT);
         SetRow(11, QM_PanelMoney(m_performance.max_drawdown_money) + " | " +
                    QM_PanelPercent(m_performance.max_drawdown_percent), QM_SCHEME_RED);
         SetRow(12, StringFormat("NOW W%d / L%d | MAX W%d / L%d",
                    m_performance.current_win_streak,
                    m_performance.current_loss_streak,
                    m_performance.longest_win_streak,
                    m_performance.longest_loss_streak), QM_SCHEME_TEXT);
         SetRow(13, QM_PanelMoney(m_performance.best_trade, true) + " / " +
                    QM_PanelMoney(m_performance.worst_trade), QM_SCHEME_TEXT);
         SetRow(14, m_performance.closed_total > 0
                    ? QM_PanelMoney(m_performance.last_trade, true) + " | " +
                      QM_PanelDateTime(m_performance.last_trade_time) + " BT | " +
                      EnumToString(m_performance.last_trade_reason)
                    : "NONE", ProfitColor(m_performance.last_trade));
         SetRow(15, "BAL " + QM_PanelMoney(balance) + " | EQ " + QM_PanelMoney(equity) +
                    " | TODAY " + QM_PanelMoney(m_performance.account_today_pnl, true),
                ProfitColor(m_performance.account_today_pnl));
        }
      else
        {
         for(int row = 5; row <= 15; ++row)
            SetRow(row, m_performance.error, QM_SCHEME_AMBER);
        }

      SetRow(16, snapshot.risk_mode + " " + snapshot.risk_per_trade +
                 " | EFFECTIVE " + snapshot.effective_risk, QM_SCHEME_TEXT);
      SetRow(17, snapshot.daily_room + " / " + snapshot.total_room,
             StateColor(snapshot.daily_room + " " + snapshot.total_room));
      SetRow(18, risk_text, without_stop > 0 ? QM_SCHEME_RED : QM_SCHEME_TEXT);

      for(int i = 0; i < 3; ++i)
        {
         SetRow(19 + i, positions[i], QM_SCHEME_TEXT);
         SetRow(22 + i, orders[i], QM_SCHEME_TEXT);
        }
      SetRow(25, QM_PanelNextBar(), QM_SCHEME_TEXT);
      SetRow(26, snapshot.last_signal, QM_SCHEME_MUTED);
      SetRow(27, snapshot.heartbeat_state + " | TICK " +
                 (tick_age >= 0 ? QM_PanelDuration(tick_age) : "N/A") +
                 " | CONNECTION " + connection,
             StateColor(snapshot.heartbeat_state + " " + connection));
      SetRow(28, snapshot.calendar_health, StateColor(snapshot.calendar_health));
      SetRow(29, "QM5_" + m_ea_id + " | " + m_slug + " | v" +
                 snapshot.build_version, QM_SCHEME_TEXT);
      SetRow(30, _Symbol + " / " + QM_PanelTimeframeName((ENUM_TIMEFRAMES)_Period) +
                 " | MAGIC " + StringFormat("%I64d", m_magic), QM_SCHEME_TEXT);
      SetRow(31, QM_PanelEnvironment() + " | LOGIN " + QM_PanelMaskedLogin() +
                 " | " + AccountInfoString(ACCOUNT_SERVER), QM_SCHEME_MUTED);
      SetRow(32, StringSubstr(m_build_hash, 0, 8) + " | " +
                 EnumToString((ENUM_LICENSE_TYPE)MQLInfoInteger(MQL_LICENSE_TYPE)),
             QM_SCHEME_MUTED);
      SetRow(33, snapshot.support_line, QM_SCHEME_MUTED);
      ChartRedraw(m_chart);
     }

   void Shutdown(void)
     {
      if(m_prefix == "")
         return;
      ObjectsDeleteAll(m_chart, m_prefix);
      ChartRedraw(m_chart);
      m_ready = false;
     }
  };

#endif // QM_CHARTPANEL_MQH
