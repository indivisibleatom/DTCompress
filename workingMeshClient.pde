int g_pos;

class WorkingMeshClient extends Mesh
{
  int[] m_orderT = new int[maxnt]; //The order of the triangle
  int[] m_orderV = new int[maxnv];
  WorkingMesh m_workingMesh;
  int m_baseVerts;
  int m_baseTriangles;
  int m_countSplitBits;


  WorkingMeshClient(Mesh m, WorkingMesh w)
  {
    reserveSpace();
    m.copyTo(this);
    nv = m.nv;
    nt = m.nt;
    nc = m.nc;
    m_workingMesh = w;
    
    m_baseVerts = nv;
    m_baseTriangles = nt;
    m_countSplitBits = 0;
    
    m_userInputHandler = new WorkingMeshClientUserInputHandler(this);

    m_triangleColorMap = new int[10];
    m_triangleColorMap[0] = green;
    m_triangleColorMap[1] = yellow;
    m_triangleColorMap[2] = red;
    
    for (int i = 0; i < m.nt; i++)
    {
      m_orderT[i] = i;
    }
    for (int i = 0; i < m.nv; i++)
    {
      m_orderV[i] = i;
    }
  }
  
  void initWorkingMesh()
  {
    initVBO(1);
    resetMarkers();
    //markExpandableVerts();
    computeBox();
    updateColorsVBO(255);
  }
  
  void reserveSpace()
  {
    nv = maxnv;
    nt = maxnt; 
    nc=3*nt;

    // primary tables
    V = new int [3*nt];               // V table (triangle/vertex indices)
    O = new int [3*nt];               // O table (opposite corner indices)
    G = new pt [nv];                   // geometry table (vertices)
  
    // auxiliary tables for bookkeeping
    cm = new int[3*nt];               // corner markers: 
    vm = new int[nv];               // vertex markers: 0=not marked, 1=interior, 2=border, 3=non manifold
    tm = new int[nt];               // triangle markers: 0=not marked, 
    cm2 = new int[nt];               // triangle markers: 0=not marked, 

    visible = new boolean[nt];    // set if triangle visible
  }
  
  private int findSmallestExpansionCorner( Boolean[] expansionBits, int startPosition, int corner )
  {
    int minTriangle = 332433240;
    int currentCorner = corner;
    int smallestCorner = corner;
    int initCorner = corner;
    int swingCount = 0;
    do
    {
      int triangle = t(currentCorner);
      int orderT = m_orderT[triangle];
      if (orderT < minTriangle && expansionBits[startPosition+swingCount])
      {
        minTriangle = orderT;
        smallestCorner = currentCorner;
      }
      swingCount++;
      currentCorner = s(currentCorner);
    } while (currentCorner != initCorner);
    return smallestCorner;
  }
  
  private int[] getCornerNumbers( Boolean[] expansionBits, int startPosition, int startCorner )
  {
    int[] cn = new int[3];
    int smallestEpansionCorner = findSmallestExpansionCorner(expansionBits, startPosition, startCorner);
    int initCorner = smallestEpansionCorner;

    //count number of bits
    int numBits = 0;
    int count = 0;
    for (int i = startPosition; i < expansionBits.length; i++)
    {
      numBits++;
      if ( expansionBits[i] )
      {
        count++;
      }
      if (count == 3)
      {
        break;
      }
    }

    int swingCountTotal = numBits;
    int swingCount = 0;
    int cornerAddedCount = 0;
    int smallestCornerPerm = 0;
    int currentCorner = startCorner;
    do
    {
      if ( expansionBits[startPosition+swingCount] )
      {
        print((startPosition + swingCount - g_pos) + " " );
        if ( currentCorner == initCorner )
        {
          smallestCornerPerm = cornerAddedCount;
        }
        cn[cornerAddedCount++] = currentCorner;
      }
      swingCount++;
      currentCorner = s(currentCorner);
    } while( currentCorner != startCorner && cornerAddedCount != 3 );
    if ( smallestCornerPerm == 1 )
    {
      int temp = cn[0];
      cn[0] = cn[1];
      cn[1] = cn[2];
      cn[2] = temp;
    }
    else if ( smallestCornerPerm == 2 )
    {
      int temp = cn[0];
      cn[0] = cn[2];
      cn[2] = cn[1];
      cn[1] = temp;
    }
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      if ( cornerAddedCount != 3 )
      {
        print("Start position is " + startPosition + "\n");
        for (int i = 0; i < swingCount; i++)
        {
          print(expansionBits[startPosition+i] + " ");
        }
        print("WorkingMeshClient::getCornerNumbers returns != 3 as expandable corner count for vertex " + v(startCorner) + " " + cornerAddedCount + "\n");
      }
    }
    m_countSplitBits = numBits;
    return cn;
  }
  
  private void markAllSurrounding( ArrayList<Integer> inRegionCornersNew, ArrayList<Integer> inRegionCornersOld, boolean[] markedVertices )
  {
    for (int corner:inRegionCornersOld)
    {
      int currentCorner = corner;
      do
      {
        if ( !markedVertices[v(n(currentCorner))] )
        {
          inRegionCornersNew.add( n(currentCorner) );
          markedVertices[v(n(currentCorner))] = true;
        }
        currentCorner = s(currentCorner);
      }while (currentCorner != corner);
    }
  }
  
  private ArrayList<Integer> expandInRegion( ArrayList<Integer> inRegionCorners, int numRings, boolean[] markedVertices )
  {
    ArrayList<Integer> newInRegionCorners = null;
    ArrayList<Integer> inRegionCornersCurrent = inRegionCorners;
    ArrayList<Integer> inRegionCornersOld = null;

    for (int i = 0; i < numRings; i++)
    {
      if ( i % 2 == 0 )
      {
        newInRegionCorners = new ArrayList<Integer>();
        inRegionCornersCurrent = newInRegionCorners;
        inRegionCornersOld = inRegionCorners;
      }
      else
      {
        inRegionCorners = new ArrayList<Integer>();
        inRegionCornersCurrent = inRegionCorners;
        inRegionCornersOld = newInRegionCorners;
      }
      for (int j:inRegionCornersOld)
      {
        inRegionCornersCurrent.add(j);
      }
      for (int j:inRegionCornersOld)
      {
        markAllSurrounding(inRegionCornersCurrent, inRegionCornersOld, markedVertices);
      }
    }
    return inRegionCornersCurrent;
  }

  void expandRegion( int corner )
  {
    FunctionProfiler profiler = new FunctionProfiler();
 
    m_workingMesh.expandRegion(corner);
    Boolean[] expansionBits = m_workingMesh.getExpansionBits();
    pt[] vertices = m_workingMesh.getExpansionVertices();
    
    int currentLODStartPositionBits = 0;
    int currentLODStartPositionVert = 0;
    int currentLODWave = NUMLODS-1;
 
    ArrayList<Integer> descendedCorners = new ArrayList<Integer>();
    ArrayList<Integer> expandedCorners;
    descendedCorners.add(corner);
    
    while ( currentLODStartPositionBits != expansionBits.length )
    {
      int numExpandable = 0;
      int numValidExpandable = 0;

      boolean[] expandArray = new boolean[nv];
      boolean[] splitBitsArray = new boolean[nc];
      boolean[] inRegion = new boolean[nv];
      
      //Mark the region to be expanded
      expandedCorners = new ArrayList<Integer>();
      for (int i:descendedCorners)
      {
        checkDebugNotEqual( inRegion[v(i)], true , "WorkingMeshClient::expandRegion => Error!! Original is already expanded!!\n", LOW );
        inRegion[v(i)] = true;
        expandedCorners.add(i);
      }

      if ( currentLODWave > 0 )
      {
        expandedCorners = expandInRegion( expandedCorners, currentLODWave, inRegion );
        print("Size of expanded region " + expandedCorners.size() + " ring size " + currentLODWave + "\n");
      }
      setRegion(inRegion);
 
      if ( DEBUG && DEBUG_MODE >= VERBOSE )
      {
        for (int i = 0; i < expandedCorners.size() - 1;i++)
        {
          for (int j = i+1; j < expandedCorners.size(); j++)
          {
            checkDebugNotEqual( v(expandedCorners.get(i)), v(expandedCorners.get(j)), "WorkingMeshClient::expandRegion => Error!! expandedCorners has two corners with same vertex\n", LOW );
          }
        }
      }
      
      for (int i:expandedCorners)
      {
        int vertex = v(i);
        checkDebugEqual( inRegion[vertex], true, "WorkingMeshClient::expandRegion => Error!! Vertex is not marked inRegion\n", LOW );
       
        numValidExpandable++;
        if ( expansionBits[currentLODStartPositionBits + numValidExpandable] )
        {
          numExpandable++;
        }
      }
      
      print("Num valid to be expanded possibly " + numValidExpandable+ " Num expandable " + numExpandable + "\n");

      int[] corners = new int[3*numExpandable];
      int currentExpandableCount = 0;
      int offsetIntoSplitBits = 0;
      
      int k = 0;
      for (int i:expandedCorners)
      {
        if ( expansionBits[ currentLODStartPositionBits + k ] )
        {
          int[] cn = getCornerNumbers(expansionBits, currentLODStartPositionBits + numValidExpandable + offsetIntoSplitBits, i);
          offsetIntoSplitBits += m_countSplitBits;
          for ( int j = 0; j < 3; j++ )
          {
            corners[currentExpandableCount++] = cn[j];
          }
        }
        k++;
      }

      int countExpanded = 0;
      int numVertices = nv; 
      numValidExpandable = 0;

      for (int i = 0; i < numVertices; i++)
      {
        if ( inRegion[i] )
        {
          numValidExpandable++;
          if ( expansionBits[ currentLODStartPositionBits + numValidExpandable ] )
          {
            pt[] result = {vertices[ currentLODStartPositionVert + 3 * countExpanded ], vertices[ currentLODStartPositionVert + 3 * countExpanded + 1 ], vertices[ currentLODStartPositionVert + 3 * countExpanded + 2 ]};
            int[] ct = {corners[ 3 * countExpanded ], corners[ 3 * countExpanded + 1 ], corners[ 3 * countExpanded + 2 ]};
            countExpanded++;
            stitch( i, result, currentLODWave, m_orderV[i], ct );
          }
        }
        else
        {
          m_orderV[i] *= 3;
        }
      }

      currentLODStartPositionBits += numValidExpandable + offsetIntoSplitBits;
      currentLODStartPositionVert += countExpanded*3;
      currentLODWave--;
      print("Size of descendedCorners " + descendedCorners.size() + "\n");
      print("Expanded one level. New number of vertices " + nv + "\n");
    }
    
    profiler.done();
    onDoneExpand();
  }
  
  void expandMesh()
  {
    m_workingMesh.onExpansionRequest();
    Boolean[] expansionBits = m_workingMesh.getExpansionBits();
    pt[] vertices = m_workingMesh.getExpansionVertices();
    int[] corners; //Stores the number of corners expandable for the current LOD wave
    
    int currentLODStartPositionBits = 0;
    int currentLODStartPositionVert = 0;
    int currentLODWave = NUMLODS-1;
    
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      print("Num vertices in expansion packet total " + vertices.length + "\n");
    }
    while (currentLODStartPositionBits != expansionBits.length)
    {
      g_pos = currentLODStartPositionBits + nv;
      int countExpandable = 0;
      int [] cornerForVertex = new int[nv];
      for (int i = 0; i < nv; i++)
      {
        cornerForVertex[i] = -1;
         if ( expansionBits[currentLODStartPositionBits+i] )
         {
           countExpandable++;
         }
      }
      
      for (int i = 0; i < nc; i++)
      {
        int vertex = v(i);
        if ( cornerForVertex[vertex] == -1 )
        {
          cornerForVertex[vertex] = i;
        }
      }
      
      int currentExpandableCount = 0;
      int offsetIntoSplitBits = 0;
      corners = new int[countExpandable*3];
      for (int i = 0; i < nv; i++)
      {
        if ( expansionBits[currentLODStartPositionBits+i] )
        {
          int[] cn = getCornerNumbers(expansionBits, currentLODStartPositionBits+nv+offsetIntoSplitBits, cornerForVertex[i]);
          offsetIntoSplitBits += m_countSplitBits;
          for ( int j = 0; j < 3; j++ )
          {
            corners[currentExpandableCount++] = cn[j];
          }
        }
      }

      int numVertices = nv;
      int numExpanded = 0;
      for (int i = 0; i < numVertices; i++)
      {
        if ( expansionBits[currentLODStartPositionBits+i] )
        {
          pt[] result = {vertices[currentLODStartPositionVert+3*numExpanded], vertices[currentLODStartPositionVert+3*numExpanded+1], vertices[currentLODStartPositionVert+3*numExpanded+2]};
          int[] ct = {corners[3*numExpanded], corners[3*numExpanded+1], corners[3*numExpanded+2]};
          numExpanded++;
          int orderV = m_orderV[i];
          stitch( i, result, currentLODWave, orderV, ct );
        }
        else
        {
          m_orderV[i] *= 3;
        }
      }
 
      currentLODStartPositionBits += numVertices + offsetIntoSplitBits;
      currentLODStartPositionVert += numExpanded*3;
      currentLODWave--;
      if ( DEBUG && DEBUG_MODE >= LOW )
      {
        print("Debug " + numVertices + " " + offsetIntoSplitBits + " " + countExpandable + "\n");
        print("One level of expansion. New vertex count " + nv + ". New start position " + currentLODStartPositionBits + "\n");
      }
    }
  }
  
  void expand(int corner)
  {
  }
  
  void stitch( int currentV, pt[] g, int currentLOD, int currentOrderV, int[] ct )
  {
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      print("Stiching using corners " + ct[0] + " " + ct[1] + " " + ct[2] + " " + currentOrderV + "\n");
    }
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      int orderT1 = m_orderT[t(ct[0])];
      int orderT2 = m_orderT[t(ct[1])];
      int orderT3 = m_orderT[t(ct[2])];
      if (orderT1 >= orderT2 || orderT1 >= orderT3)
      {
        print("workingMeshClient::stitch - incorrect triangle orderings! " + orderT1 + " " + orderT2 + " " + orderT3 + "\n");
      }
    }

    int offsetCorner = 3*nt;
    int v1 = addVertex(g[0], currentLOD-1, 3*currentOrderV);
    int v2 = addVertex(g[1], currentLOD-1, 3*currentOrderV+1);
    int v3 = addVertex(g[2], currentV, currentLOD-1, 3*currentOrderV+2);

    int offsetTriangles = m_baseTriangles;
    int nuLowerLOD = NUMLODS - currentLOD;
    int verticesAtLOD = m_baseVerts;

    //Rehook the triangles incident on expanded vertices
    int currentCorner = s(ct[0]);
    int vertex = v2;
    do
    {
      V[currentCorner] = vertex;
      if ( currentCorner == ct[1] )
      {
        vertex = v3;
      }
      if ( currentCorner == ct[2] )
      {
        vertex = v1;
      }
      currentCorner = s(currentCorner);
    } 
    while (currentCorner != s (ct[0]));

    for (int i = 0; i < nuLowerLOD; i++)
    {
      if ( i + 1 == nuLowerLOD )
      {
        offsetTriangles += 4 * currentOrderV;
      }
      else
      {
        offsetTriangles += 4 * verticesAtLOD;
      }
      verticesAtLOD *= 3;
    }
    addTriangle( v1, v2, v3, offsetTriangles, currentLOD-1, true );
    addTriangle( v1, v(p(ct[0])), v2, offsetTriangles + 1, currentLOD-1, true );
    addTriangle( v2, v(p(ct[1])), v3, offsetTriangles + 2, currentLOD-1, true );
    addTriangle( v3, v(p(ct[2])), v1, offsetTriangles + 3, currentLOD-1, true );

    O[p(s(ct[0]))] = offsetCorner + 3; 
    O[p(s(ct[1]))] = offsetCorner + 6;
    O[p(s(ct[2]))] = offsetCorner + 9;
    O[offsetCorner + 3] = p(s(ct[0]));
    O[offsetCorner + 6] = p(s(ct[1]));
    O[offsetCorner + 9] = p(s(ct[2]));

    O[n(ct[0])] = offsetCorner + 5;
    O[n(ct[1])] = offsetCorner + 8;
    O[n(ct[2])] = offsetCorner + 11;
    O[offsetCorner + 5] = n(ct[0]);
    O[offsetCorner + 8] = n(ct[1]);
    O[offsetCorner + 11] = n(ct[2]);

    O[offsetCorner] = offsetCorner+7;
    O[offsetCorner+1] = offsetCorner+10;
    O[offsetCorner+2] = offsetCorner+4;
    O[offsetCorner+7] = offsetCorner;
    O[offsetCorner+10] = offsetCorner+1;
    O[offsetCorner+4] = offsetCorner+2;
  }
  
  int addVertex(pt p, int lod, int orderV)
  {
    int vertexIndex = addVertex(p);
    m_orderV[vertexIndex] = orderV;
    return vertexIndex;
  }
  
  int addVertex(pt p, int index, int lod, int orderV)
  {
    int vertexIndex = index;
    G[vertexIndex] = p;
    m_orderV[vertexIndex] = orderV;
    return vertexIndex;
  }

  void addTriangle( int v1, int v2, int v3, int orderT, int ageT, boolean fCallThisClass )
  {
    addTriangle(v1, v2, v3);
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      print("Adding triangle with order " + orderT + "\n");
    }
    m_orderT[nt-1] = orderT;
  }
  
  void onDoneExpand()
  {
    //markExpandableVerts();
    
    initVBO(1);
    updateColorsVBO(255);
  }
}
