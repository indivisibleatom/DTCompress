class MeshUtils
{
 private Mesh m;
 
 MeshUtils(Mesh _m) { m = _m; }
 
 public float computeArea(int triangle)
 {
   pt A = m.G[m.v(m.c(triangle))];
   pt B = m.G[m.v(m.n(m.c(triangle)))];
   pt C = m.G[m.v(m.p(m.c(triangle)))];
     
   vec AB = V(A, B);
   vec AC = V(A, C);
   vec cross = N(AB, AC);
   float area = 0.5 * cross.norm();
   return abs(area);
 }
 
    
 public pt baryCenter(int triangle)
 {
   int corner = m.c(triangle);
   pt baryCenter = new pt();
   baryCenter.set(m.G[m.v(m.c(triangle))]);
   baryCenter.add(m.G[m.v(m.n(m.c(triangle)))]);
   baryCenter.add(m.G[m.v(m.p(m.c(triangle)))]);
   baryCenter.div(3);
   if (DEBUG && DEBUG_MODE >= VERBOSE)
   {
     print(baryCenter.x + " " + baryCenter.y + " " + baryCenter.z);
   }
   return baryCenter;
 }
}

class TetMeshUserInputHandler
{
  private TetMesh m_mesh;
  protected boolean m_fKeyEntryMode;
  protected String m_command;

  
  TetMeshUserInputHandler(TetMesh m)
  {
    m_mesh = m;
  }
  
  public void onMousePressed()
  {
  }
  
  public void onMouseDragged()
  {
  }
  
  public void onMouseMoved()
  {
  }
  
  public void onKeyPress()
  {   
    if (key==':')
    {
      m_fKeyEntryMode = true;
      m_command = "";
    }
    else if (m_fKeyEntryMode)
    {
      if (key == ENTER || key == RETURN)
      {
        interpretCommand( m_command );
        m_fKeyEntryMode = false;
      }
      else
      {
        m_command += key;
      }
    }
  }
  
  public void interpretCommand( String command )
  {
    switch( command.charAt(0) )
    {
    }
  }
}

class MeshUserInputHandler
{
  private Mesh m_mesh;
  protected boolean m_fKeyEntryMode;
  protected String m_command;

  
  MeshUserInputHandler(Mesh m)
  {
    m_mesh = m;
  }
  
  public void onMousePressed()
  {
     pressed=true;
     if (keyPressed&&key=='h') {m_mesh.hide(); }  // hide triangle
  }
  
  public void onMouseDragged()
  {
  }
  
  public void onMouseMoved()
  {
  }
  
  public void onKeyPress()
  {
    // corner ops for demos
    // CORNER OPERATORS FOR TEACHING AND DEBUGGING
    if(key=='N') m_mesh.next();      
    if(key=='P') m_mesh.previous();
    if(key=='O') m_mesh.back();
    if(key=='L') m_mesh.left();
    if(key=='R') m_mesh.right();   
    if(key=='S') {m_mesh.cc = m_mesh.s(m_mesh.cc); print("Current corner " + m_mesh.cc);}
    if(key=='U') m_mesh.unswing();
    
    // mesh edits, smoothing, refinement
    //if(key=='v') m_mesh.flip(); // clip edge opposite to M.cc
    if(key=='F') {m_mesh.smoothen(); m_mesh.normals();}
    if(key=='Y') {m_mesh.refine(); m_mesh.makeAllVisible(); g_totalVertices = m_mesh.nv;}
    if(key=='d') {m_mesh.clean();}
    if(key=='o') m_mesh.offset();

    if(key=='u') {m_mesh.resetMarkers(); m_mesh.makeAllVisible(); } // undo deletions
    if(key=='B') showBack=!showBack;
    if(key=='#') m_mesh.volume(); 
    if(key=='_') m_mesh.surface(); 

    //Drawing options
    if (key == 'Q') { m_mesh.getDrawingState().m_fShowVertices = !m_mesh.getDrawingState().m_fShowVertices; }
    if (key == 'q') { m_mesh.getDrawingState().m_fShowCorners = !m_mesh.getDrawingState().m_fShowCorners; }
    if (key == 'A') { m_mesh.getDrawingState().m_fShowNormals = !m_mesh.getDrawingState().m_fShowNormals; }
    if (key == 'a') { m_mesh.getDrawingState().m_fShowTriangles = !m_mesh.getDrawingState().m_fShowTriangles; }
    if (key == 'E') { m_mesh.getDrawingState().m_fTranslucent = !m_mesh.getDrawingState().m_fTranslucent; }
    if (key == 'e') { m_mesh.getDrawingState().m_fSilhoutte = !m_mesh.getDrawingState().m_fSilhoutte; }
    if (key == 'b') { m_mesh.getDrawingState().m_fPickingBack=true; m_mesh.getDrawingState().m_fTranslucent = true; println("picking on the back");}
    if (key == 'f') { m_mesh.getDrawingState().m_fPickingBack=false; m_mesh.getDrawingState().m_fTranslucent = false; println("picking on the front");}
    if (key == 'g') { m_mesh.flatShading=!m_mesh.flatShading; }
    if (key == '-') { m_mesh.getDrawingState().m_fShowEdges=!m_mesh.getDrawingState().m_fShowEdges; if (m_mesh.getDrawingState().m_fShowEdges) m_mesh.getDrawingState().m_shrunk=1; else m_mesh.getDrawingState().m_shrunk=0; }
    
    if (key==':')
    {
      m_fKeyEntryMode = true;
      m_command = "";
    }
    else if (m_fKeyEntryMode)
    {
      if (key == ENTER || key == RETURN)
      {
        interpretCommand( m_command );
        m_fKeyEntryMode = false;
      }
      else
      {
        m_command += key;
      }
    }
  }
 
  public int getNumberFromCommand( String command, int indexBegin )
  {
    String desiredPart = command.substring( indexBegin );
    return Integer.parseInt( desiredPart );
  }
  
  public void interpretCommand( String command )
  {
    switch( command.charAt(0) )
    {
      case 'c': m_mesh.cc = getNumberFromCommand(command, 1);
        break;
      case 'v': int vertex = getNumberFromCommand(command, 1);
                for (int i = 0; i < m_mesh.nc; i++)
                {
                  if ( m_mesh.v(i) ==  vertex )
                  {
                    m_mesh.cc = i;
                    break;
                  }
                }
        break;
    }
  }
  
  public void interactSelectedMesh()
  {
    // -------------------------------------------------------- graphic picking on surface ----------------------------------   
    if (keyPressed&&key=='h') { m_mesh.pickc(Pick()); }// sets c to closest corner in M 
    if(pressed) {
       if (keyPressed&&key=='s') m_mesh.picks(Pick()); // sets M.sc to the closest corner in M from the pick point
       if (keyPressed&&key=='c') m_mesh.pickc(Pick()); // sets M.cc to the closest corner in M from the pick point
       if (keyPressed&&(key=='x'||key=='X')) m_mesh.pickcOfClosestVertex(Pick()); 
    }
    pressed=false;
  }
}

class WorkingMeshUserInputHandler extends MeshUserInputHandler
{
  WorkingMesh m_mesh;
  
  WorkingMeshUserInputHandler( WorkingMesh m )
  {
    super(m);
    m_mesh = m;
  }

  public void interactSelectedMesh()
  {
    if (keyPressed&&key==' ')
    {
      m_mesh.pickc(Pick()); 
      m_mesh.expand(m_mesh.cc); 
    }// sets c to closest corner in M 
    super.interactSelectedMesh();
  }
  
  public void onKeyPress()
  {
    super.onKeyPress();
    if ( !m_fKeyEntryMode )
    {
      if (keyPressed && key=='2')
      {
         m_mesh.expandMesh();
      }
      if(keyPressed&&key == 'G') 
      {
        m_mesh.expandRegion(m_mesh.cc);
      }
      if (keyPressed&&key == '~')
      {
        m_mesh.selectRegion(m_mesh.cc);
      }
    }
  }
}

class WorkingMeshClientUserInputHandler extends MeshUserInputHandler
{
  WorkingMeshClient m_mesh;
  
  WorkingMeshClientUserInputHandler( WorkingMeshClient m )
  {
    super(m);
    m_mesh = m;
  }

  public void interactSelectedMesh()
  {
    super.interactSelectedMesh();
    if (keyPressed&&key==' ')
    {
      m_mesh.pickc(Pick()); 
      m_mesh.expand(m_mesh.cc); 
    }// sets c to closest corner in M 
    if(keyPressed&&key == 'G') 
    {
      m_mesh.expandRegion(m_mesh.cc);
    }
  }
  
  public void onKeyPress()
  {
    super.onKeyPress();

    if ( !m_fKeyEntryMode )
    {
      if (keyPressed && key=='2')
      {
        m_mesh.expandMesh();
      }
      if(keyPressed&&key == 'G') 
      {
        m_mesh.expand(m_mesh.cc);
      }
    }
  }
}


class IslandMeshUserInputHandler extends MeshUserInputHandler
{
  private IslandMesh m_mesh;
  
  IslandMeshUserInputHandler( IslandMesh m )
  {
    super( m );
    m_mesh = m;
    m_fKeyEntryMode = false;
  }
  
  public void interpretCommand( String command )
  {
    super.interpretCommand(command);
  }
  
  public void onKeyPress()
  {
    super.onKeyPress();
    if (!m_fKeyEntryMode)
    {
      if (key=='1') 
      {
        m_mesh.getDrawingState().m_fShowEdges = true; 
        IslandCreator islandCreator = new IslandCreator(m_mesh, (int) random(m_mesh.nt * 3));
        islandCreator.createIslands("heuristic");
      }
    }
  }
}
