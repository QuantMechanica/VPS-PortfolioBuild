#ifndef QM_MAGIC_RESOLVER_MQH
#define QM_MAGIC_RESOLVER_MQH

#include "QM_Errors.mqh"

// V5 Framework Step 04:
// - canonical magic computation: magic = ea_id * 10000 + symbol_slot
// - baked registry snapshot (seed row for framework bring-up)
// - runtime collision guard against foreign open positions

#define QM_MAGIC_EA_ID_MIN 1000
#define QM_MAGIC_EA_ID_MAX 9999
#define QM_MAGIC_SLOT_MIN  0
#define QM_MAGIC_SLOT_MAX  9999

// SHA256 of framework/registry/magic_numbers.csv baked into the binary at build time.
#define QM_MAGIC_REGISTRY_SHA256 "4F1B91E02A85FB3EB30691D200AE2DAC209A00898053D4FC41045281C1132FF7"

#define QM_MAGIC_REGISTRY_ROWS 15
static const int    QM_MAGIC_REG_EA_ID[QM_MAGIC_REGISTRY_ROWS]   = {1001, 1044, 1044, 1045, 1046, 1046, 1047, 1047, 1047, 1047, 1050, 1050, 1050, 1050, 1050};
static const int    QM_MAGIC_REG_SLOT[QM_MAGIC_REGISTRY_ROWS]    = {0, 0, 1, 0, 0, 1, 0, 1, 2, 3, 0, 1, 2, 3, 4};
static const string QM_MAGIC_REG_SYMBOL[QM_MAGIC_REGISTRY_ROWS]  = {"EURUSD.DWX", "NDX.DWX", "WS30.DWX", "SPX500.DWX", "NDX.DWX", "WS30.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX", "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX", "USDCAD.DWX"};
static const int    QM_MAGIC_REG_MAGIC[QM_MAGIC_REGISTRY_ROWS]   = {10010000, 10440000, 10440001, 10450000, 10460000, 10460001, 10470000, 10470001, 10470002, 10470003, 10500000, 10500001, 10500002, 10500003, 10500004};

int QM_Magic(const int ea_id, const int symbol_slot)
{
   static int cache_ea_id = -1;
   static int cache_slot  = -1;
   static int cache_magic = -1;

   if(ea_id == cache_ea_id && symbol_slot == cache_slot)
   {
      return cache_magic;
   }

   if(ea_id < QM_MAGIC_EA_ID_MIN || ea_id > QM_MAGIC_EA_ID_MAX)
   {
      PrintFormat("%s: invalid ea_id=%d", EA_MAGIC_NOT_REGISTERED, ea_id);
      return -1;
   }

   if(symbol_slot < QM_MAGIC_SLOT_MIN || symbol_slot > QM_MAGIC_SLOT_MAX)
   {
      PrintFormat("%s: invalid symbol_slot=%d", EA_MAGIC_NOT_REGISTERED, symbol_slot);
      return -1;
   }

   const long magic64 = (long)ea_id * 10000L + (long)symbol_slot;
   if(magic64 <= 0 || magic64 > 2147483647L)
   {
      PrintFormat("%s: magic out of range ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot);
      return -1;
   }

   const int magic = (int)magic64;
   if(magic == 0)
   {
      PrintFormat("%s: computed magic is zero ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot);
      return -1;
   }

   cache_ea_id = ea_id;
   cache_slot  = symbol_slot;
   cache_magic = magic;
   return magic;
}

bool QM_MagicRegistered(const int ea_id, const int symbol_slot)
{
   const int computed_magic = QM_Magic(ea_id, symbol_slot);
   if(computed_magic <= 0)
   {
      return false;
   }

   for(int i = 0; i < QM_MAGIC_REGISTRY_ROWS; ++i)
   {
      if(QM_MAGIC_REG_EA_ID[i] == ea_id && QM_MAGIC_REG_SLOT[i] == symbol_slot)
      {
         return (QM_MAGIC_REG_MAGIC[i] == computed_magic);
      }
   }

   return false;
}

string QM_MagicRegistryHash()
{
   return QM_MAGIC_REGISTRY_SHA256;
}

bool QM_MagicCollisionWithForeignOpenPositions(const int magic, const string expected_symbol = "")
{
   if(magic <= 0)
   {
      return true;
   }

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
      {
         continue;
      }

      const long position_magic = PositionGetInteger(POSITION_MAGIC);
      if((int)position_magic != magic)
      {
         continue;
      }

      const string position_symbol = PositionGetString(POSITION_SYMBOL);
      if(expected_symbol != "" && position_symbol == expected_symbol)
      {
         continue;
      }

      PrintFormat("%s: magic=%d conflicts with ticket=%I64u symbol=%s expected_symbol=%s",
                  EA_MAGIC_COLLISION_DETECTED,
                  magic,
                  ticket,
                  position_symbol,
                  expected_symbol);
      return true;
   }

   return false;
}

int QM_MagicChecked(const int ea_id, const int symbol_slot, const string expected_symbol = "")
{
   const int magic = QM_Magic(ea_id, symbol_slot);
   if(magic <= 0)
   {
      return -1;
   }

   if(!QM_MagicRegistered(ea_id, symbol_slot))
   {
      PrintFormat("%s: ea_id=%d slot=%d magic=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot, magic);
      return -1;
   }

   if(QM_MagicCollisionWithForeignOpenPositions(magic, expected_symbol))
   {
      return -1;
   }

   return magic;
}

#endif // QM_MAGIC_RESOLVER_MQH
