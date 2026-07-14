//+------------------------------------------------------------------+
//| Export_FTMO_Joint_Tester_Bars.mq5                               |
//| Tester-only, no-trade tick-to-M15 exporter for custom symbols.  |
//+------------------------------------------------------------------+
#property strict

input string output_path = "QM\\ftmo_joint_bars\\NDX_DWX_2020_M15.csv";

int g_handle = INVALID_HANDLE;
datetime g_bucket = 0;
double g_open = 0.0;
double g_high = 0.0;
double g_low = 0.0;
double g_close = 0.0;
long g_tick_volume = 0;

void WriteBucket()
  {
   if(g_handle == INVALID_HANDLE || g_bucket <= 0 || g_tick_volume <= 0)
      return;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   FileWrite(g_handle,
             (long)g_bucket,
             DoubleToString(g_open, digits),
             DoubleToString(g_high, digits),
             DoubleToString(g_low, digits),
             DoubleToString(g_close, digits),
             g_tick_volume);
  }

void StartBucket(const datetime bucket, const double price)
  {
   g_bucket = bucket;
   g_open = price;
   g_high = price;
   g_low = price;
   g_close = price;
   g_tick_volume = 1;
  }

int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER) == 0)
     {
      Print("FTMO_JOINT_TESTER_EXPORT_REJECTED_NOT_TESTER");
      return INIT_FAILED;
     }
   g_handle = FileOpen(output_path,
                       FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON,
                       ',');
   if(g_handle == INVALID_HANDLE)
     {
      PrintFormat("FTMO_JOINT_TESTER_EXPORT_OPEN_FAIL path=%s error=%d",
                  output_path, GetLastError());
      return INIT_FAILED;
     }
   FileWrite(g_handle, "time", "open", "high", "low", "close", "tickvol");
   PrintFormat("FTMO_JOINT_TESTER_EXPORT_INIT symbol=%s path=%s", _Symbol, output_path);
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   const double price = tick.bid > 0.0 ? tick.bid : tick.last;
   if(price <= 0.0 || tick.time <= 0)
      return;
   const datetime bucket = (datetime)(((long)tick.time / 900) * 900);
   if(g_bucket == 0)
     {
      StartBucket(bucket, price);
      return;
     }
   if(bucket != g_bucket)
     {
      WriteBucket();
      StartBucket(bucket, price);
      return;
     }
   g_high = MathMax(g_high, price);
   g_low = MathMin(g_low, price);
   g_close = price;
   ++g_tick_volume;
  }

void OnDeinit(const int reason)
  {
   WriteBucket();
   if(g_handle != INVALID_HANDLE)
     {
      FileFlush(g_handle);
      FileClose(g_handle);
      g_handle = INVALID_HANDLE;
     }
   PrintFormat("FTMO_JOINT_TESTER_EXPORT_DONE symbol=%s reason=%d", _Symbol, reason);
  }

double OnTester()
  {
   return 0.0;
  }
