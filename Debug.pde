boolean DEBUG = true;
int VERBOSE = 4;
int HIGH = 2;
int LOW = 1;
int DEBUG_MODE = LOW;

void checkDebugEqual( Object o1, Object o2, String errorString, int level)
{
  if ( DEBUG && DEBUG_MODE >= level )
  {
    if ( o1 != o2 )
    {
      print(errorString);
    }
  }
}

void checkDebugNotEqual( Object o1, Object o2, String errorString, int level)
{
  if ( DEBUG && DEBUG_MODE >= level )
  {
    if ( o1 == o2 )
    {
      print(errorString);
    }
  }
}


void checkDebugGreaterThanEqual( Comparable o1, Comparable o2, String errorString, int level)
{
  if ( DEBUG && DEBUG_MODE >= level )
  {
    if ( o1.compareTo( o2 ) < 0 )
    {
      print(errorString);
    }
  }
}
