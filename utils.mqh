//+------------------------------------------------------------------+
//| utils.mqh                                                        |
//| Helper functions for Al Brooks EA                                |
//+------------------------------------------------------------------+
#pragma once

// ATR helper
inline double GetATR(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iATR(symbol, tf, period);
   if (handle == INVALID_HANDLE)
      return 0;
   double buffer[1];
   if (CopyBuffer(handle, 0, shift, 1, buffer) == 1)
   {
      IndicatorRelease(handle);
      return buffer[0];
   }
   IndicatorRelease(handle);
   return 0;
}

// EMA helper
inline double GetEMA(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if (handle == INVALID_HANDLE)
      return 0;
   double buffer[1];
   if (CopyBuffer(handle, 0, shift, 1, buffer) == 1)
   {
      IndicatorRelease(handle);
      return buffer[0];
   }
   IndicatorRelease(handle);
   return 0;
}

// Recent swing high
inline double GetRecentSwingHigh(const string symbol, ENUM_TIMEFRAMES tf, int lookback)
{
   double swing = iHigh(symbol, tf, 1);
   for(int i=2;i<=lookback;i++)
   {
      double h = iHigh(symbol, tf, i);
      if(h > swing)
         swing = h;
   }
   return swing;
}

// Recent swing low
inline double GetRecentSwingLow(const string symbol, ENUM_TIMEFRAMES tf, int lookback)
{
   double swing = iLow(symbol, tf, 1);
   for(int i=2;i<=lookback;i++)
   {
      double l = iLow(symbol, tf, i);
      if(l < swing)
         swing = l;
   }
   return swing;
}
