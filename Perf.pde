class FunctionProfiler
{
  int m_startTime;

  FunctionProfiler()
  {
    m_startTime = millis();
  }
  
  void done()
  {
    StackTraceElement[] stackTraceElements = Thread.currentThread().getStackTrace();
    print("Time for function " + stackTraceElements[ 2 ].getFileName() + "::" + stackTraceElements[ 2 ].getClassName() + "::" + stackTraceElements[ 2 ].getMethodName() + " is " + (millis() - m_startTime) + "\n");
  }
}
