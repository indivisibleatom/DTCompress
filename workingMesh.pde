float g_roiSize = 2500;

int maxnv = 100000;
int maxnt = 2*maxnv;

class FutureLODAndVOrder
{
  private int m_order;
  private int m_lod;
  
  FutureLODAndVOrder( int lod, int order )
  {
    m_order = order;
    m_lod = lod;
  }
  
  public int orderV() { return m_order; }
  public int lod() { return m_lod; }
}

class WorkingMesh extends Mesh
{
  int[] m_deathLOD = new int[maxnv]; //LOD per vertex at which it dies
  int[] m_deathAge = new int[maxnv]; //The order of the vertex
  int[] m_birthLOD = new int[maxnv];

  int[] m_orderT = new int[maxnt]; //The order of the triangle
  int[] m_ageT = new int[maxnt];
  int[] m_descendedFrom = new int[maxnv];
  
  ArrayList<Boolean> m_expandBits;
  ArrayList<pt> m_expandVertices;

  int m_baseTriangles;
  int m_baseVerts;

  PacketFetcher m_packetFetcher;  

  WorkingMesh( Mesh m, SuccLODMapperManager lodMapperManager, PacketFetcher packetFetcher )
  {
    reserveSpace();
    m.copyTo(this);
    
    m_expandBits = new ArrayList<Boolean>();
    m_expandVertices = new ArrayList<pt>();
    m_packetFetcher = packetFetcher;

    m_baseVerts = nv;
    m_baseTriangles = nt;
    m_userInputHandler = new WorkingMeshUserInputHandler(this);
    m_triangleColorMap = new int[10];
    m_triangleColorMap[0] = formColor(green, 255);
    m_triangleColorMap[1] = formColor(yellow, 255);
    m_triangleColorMap[2] = formColor(red, 255);

    for (int i = 0; i < m.nt; i++)
    {
      m_orderT[i] = i;
      m_ageT[i] = NUMLODS - 1;
    }

    for (int i = 0; i < m.nv; i++)
    {
      FutureLODAndVOrder future = getLODAndVAge( NUMLODS - 1, i );
      m_deathLOD[i] = future.lod();
      m_birthLOD[i] = NUMLODS - 1;
      m_deathAge[i] = future.orderV();
      m_descendedFrom[i] = i;
    }   
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
  
  void initWorkingMesh()
  {
    initVBO(1);
    resetMarkers();
    markExpandableVerts();
    computeBox();
    updateColorsVBO(255);
  }

  private FutureLODAndVOrder getLODAndVAge( int lod, int orderV )
  {
    while ( lod >= 0 )
    {
      pt[] result = m_packetFetcher.fetchGeometry(lod, orderV);
      if ( result[1] != null )
      {
        break;
      }
      lod--;
      orderV*=3;
    }
    return new FutureLODAndVOrder( lod, orderV );
  }

  private int findSmallestExpansionCorner( int lod, int corner )
  {
    if (DEBUG && DEBUG_MODE >= VERBOSE )
    {
      print("Find smallest expansion corner for corner " + corner + "LOD and LOD swing " + lod + " " + m_deathLOD[v(n(s(corner)))] + "\n");
    }
    int minTriangle = 332433240;
    int currentCorner = corner;
    int smallestCorner = corner;
    int initCorner = corner;
    do
    {
      int cornerOffset = currentCorner%3;
      int triangle = t(currentCorner);
      int orderT = m_orderT[triangle];
      if (orderT < minTriangle && m_packetFetcher.fetchConnectivity(lod, 3*orderT + cornerOffset) == true)
      {
        minTriangle = orderT;
        smallestCorner = currentCorner;
      }
      currentCorner = s(currentCorner);
      while ( currentCorner != initCorner )
      {
        if ( m_ageT[t(currentCorner)] >=  lod )
        {
          break;
        }
        if ( DEBUG && DEBUG_MODE >= VERBOSE )
        {
          print("Skipping corner " + currentCorner + "\n");
        }
        currentCorner = s(currentCorner);
      }
    } 
    while (currentCorner != initCorner);
    return smallestCorner;
  }

  //Get the corner numbers of the corners to be split for a given vertex (given a corners of the vertex)
  private int[] getExpansionCornerNumbers(int lod, int corner)
  {
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      print("Get expansion corner numbers for lod " + lod + " " + m_deathLOD[v(corner)] + "\n");
    }
    int []result = new int[3];
    int numResults = 0;
    int currentCorner = findSmallestExpansionCorner(lod, corner);
    int initCorner = currentCorner;
    do
    {
      int triangle = t(currentCorner);
      int orderT = m_orderT[triangle];

      int cornerOffset = currentCorner%3;

      //TODO msati3: Optimize this query
      boolean expand = m_packetFetcher.fetchConnectivity(lod, 3*orderT + cornerOffset);
      if (expand)
      {
        result[numResults++] = currentCorner;
      }
      currentCorner = s(currentCorner);
      //Skip triangles not of same age as vertex
      while ( currentCorner != initCorner )
      {
        if ( m_ageT[t(currentCorner)] >=  lod )
        {
          break;
        }
        currentCorner = s(currentCorner);
      }
    } 
    while (currentCorner != initCorner);
    return result;
  }

  void homogenize( int corner )
  {
    int currentCorner = corner;
    int lod = m_deathLOD[v(corner)];
    boolean fRequiredExpansion = true;
    do
    {
      fRequiredExpansion = false;
      do 
      {
        int lodCurrent = m_deathLOD[v(n(currentCorner))];
        if ( lodCurrent > lod )
        {
          expand(n(currentCorner));
          fRequiredExpansion = true;
        }
        currentCorner = s(currentCorner);
      } while(currentCorner != corner);
    } while(fRequiredExpansion);
  }

  int addVertex(pt p, int lod, int orderV)
  {
    int vertexIndex = addVertex(p);
    FutureLODAndVOrder future = getLODAndVAge( lod, orderV );
    m_deathLOD[vertexIndex] = future.lod();
    m_deathAge[vertexIndex] = future.orderV();
    m_birthLOD[vertexIndex] = lod;
    return vertexIndex;
  }

  int addVertex(pt p, int index, int lod, int orderV)
  {
    int vertexIndex = index;
    G[index] = p;
    FutureLODAndVOrder future = getLODAndVAge( lod, orderV );
    m_deathLOD[vertexIndex] = future.lod();
    m_deathAge[vertexIndex] = future.orderV();
    m_birthLOD[vertexIndex] = lod;
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
    m_ageT[nt - 1] = ageT;     
  }

  void printVerticesSelected()
  {
    int vertex = v(cc);
    int orderV = m_deathAge[vertex];
    int lod = m_deathLOD[vertex];
    if ( lod >= 0 )
    {
      pt[] result = m_packetFetcher.fetchGeometry(lod, orderV);
      int cornerOffset = cc%3;
      boolean expand = m_packetFetcher.fetchConnectivity(lod, 3*m_orderT[t(cc)] + cornerOffset);
      if ( DEBUG && DEBUG_MODE >= VERBOSE )
      {
        print( "Order vertex " + orderV + " lod " + lod + " order triangle " + m_orderT[t(cc)] + " age triangle " + m_ageT[t(cc)] + "\n");
        print( "Expand edge " + expand + " Geometry " + result[0] + " " + result[1] + " " + result[2] + "\n" );
      }
    }
  }

  //True if the same LOD vertices surround the current corner
  private boolean sameLODSurrounding( int corner )
  {
    int vertex = v( corner );
    int lod = m_deathLOD[vertex];
    
    int currentCorner = corner;
    do
    {
      if ( m_deathLOD[ v(currentCorner) ] != lod )
        return false;
      currentCorner = s(currentCorner);
    }while (currentCorner != corner);
    return true;
  }

  void markExpandableVerts()
  {
    for (int i = 0; i < nc; i++)
    {
      cm[i] = 0;
      vm[v(i)] = 0;
    }
    for (int i = 0; i < nc; i++)
    {
      int vertex = v(i);

      int orderV = m_deathAge[vertex];
      int triangle = t(i);
      int cornerOffset = i%3;

      int orderT = m_orderT[triangle];
      int lod = m_deathLOD[vertex];
      if (sameLODSurrounding( i ))
      {
        if (lod >= 0)
        {
          pt[] result = m_packetFetcher.fetchGeometry(lod, orderV);
          if (result[1] != null)
          {
            vm[vertex] = 1;
          }
          else
          {
            vm[vertex] = 0;
          }
          if ( m_ageT[t(i)] >=  lod )
          {
            boolean expand = m_packetFetcher.fetchConnectivity(lod, 3*orderT + cornerOffset);
            if (expand)
            {
              int minTriangle = maxnt;
              minTriangle = t(i);
              int currentCorner = s(i);
              boolean smallest = true;
              while (currentCorner != i)
              {
                //Skip triangles not of same age as vertex
                while ( currentCorner != i )
                {
                  if ( m_ageT[t(currentCorner)] >=  lod )
                  {
                    break;
                  }
                  currentCorner = s(currentCorner);
                }
                if (currentCorner == i)
                {
                  break;
                }
  
                cornerOffset = currentCorner%3;
                triangle = t(currentCorner);
                orderT = m_orderT[triangle];
                if (triangle < minTriangle && m_packetFetcher.fetchConnectivity(lod, 3*orderT + cornerOffset) == true)
                {
                  smallest = false;
                }
                currentCorner = s(currentCorner);
              }
              if ( smallest )
              {
                cm[i] = 1;
              }
              else
              {
                cm[i] = 2;
              }
            }
          }
        }
      }
    }
  }
  
  private int populateSplitBitsArray( boolean[] splitArray, int currentLODWave, int corner, int[] corners, int sizeCornersArray, int sizeSplitBitsArray )
  {
    int[] ct = getExpansionCornerNumbers(currentLODWave, corner);
    for (int i = 0; i < 3; i++)
    {
      corners[sizeCornersArray+i] = ct[i];
    }
    
    int currentCorner = corner;
    int numSplitEdges = 0;
    int count=0;
    do
    {
      if (currentCorner == ct[0] || currentCorner == ct[1] || currentCorner == ct[2])
      {
        numSplitEdges++;
        splitArray[sizeSplitBitsArray+count] = true;
        //print((sizeSplitBitsArray + count) + " ");
      }
      else
      {
        splitArray[sizeSplitBitsArray+count] = false;
      }
      count++;
      currentCorner = s(currentCorner);
    }
    while (currentCorner != corner && numSplitEdges != 3);
    if (DEBUG && DEBUG_MODE >= LOW)
    {
      if ( numSplitEdges != 3 )
      {
        print("workingMesh::populateSplitBitsArray - number of splitBits is not 3! " + currentLODWave + " " + v(corner) + "\n");
      }
    }
    return count;
  }
  
  public void onExpansionRequest()
  {
    expandMesh();
  }
  
  public Boolean[] getExpansionBits()
  {
    return m_expandBits.toArray(new Boolean[m_expandBits.size()]);
  }
  
  public pt[] getExpansionVertices()
  {
    return m_expandVertices.toArray(new pt[m_expandVertices.size()]);
  }
  
  void expandMesh()
  {
    FunctionProfiler profiler = new FunctionProfiler();
    int currentLODWave = NUMLODS - 1;
    boolean[] expandArray;
    int[] cornerForVertex;
    boolean[] splitBitsArray;
    pt[] expandVertices;
    int numExpandable;
    int totalBits = 0;
    int totalBitsChoose = 0;
    int totalBitsNothing = 0;
    int countFalse = 0;
    int countTrue = 0;
    while (currentLODWave >= 0)
    {
      numExpandable = 0;
      expandArray = new boolean[nv];
      cornerForVertex = new int[nv];
      splitBitsArray = new boolean[nc];
      
      for (int i = 0; i < nv; i++)
      {
        cornerForVertex[i] = -1;
      }
 
      for (int i = 0; i < nc; i++)
      {
        int vertex = v(i);
        if ( cornerForVertex[vertex] == -1 )
        {
          cornerForVertex[vertex] = i;
        }
        int lod = m_deathLOD[vertex];
        if ( lod == currentLODWave )
        {
          if ( !expandArray[vertex] )
          {
            int orderV = m_deathAge[vertex];
            //TODO msati3: Could use connectivity here as well
            pt[] result = m_packetFetcher.fetchGeometry(currentLODWave, orderV);
            if ( result[1] != null )
            {
              expandArray[vertex] = true;
              numExpandable++;
            }
          }
        }
      }

      int[] corners = new int[3*numExpandable];
      int sizeSplitBitsArray = 0;
      int sizeCornersArray = 0;
      for (int i = 0; i < nv; i++)
      {
        m_expandBits.add(expandArray[i]);
        totalBits++;
        totalBitsChoose++;
        totalBitsNothing++;
        if ( expandArray[i] )
        {
          int count = populateSplitBitsArray(splitBitsArray, currentLODWave, cornerForVertex[i], corners, sizeCornersArray, sizeSplitBitsArray);
          sizeSplitBitsArray += count;
          totalBits += count;
          sizeCornersArray += 3;
          int valence = getValence(i);
          totalBitsChoose += ceil((log((valence * (valence - 1) * (valence - 2))/6)/log(2)));
          totalBitsNothing += valence;
          countTrue++;
          countTrue +=3;
          countFalse += count-3;
        }
        else
        {
          countFalse++;
        }
      }

      for (int i = 0; i < sizeSplitBitsArray; i++)
      {
        m_expandBits.add( splitBitsArray[i] );
      }

      int countExpanded = 0;
      int numVertices = nv;
      for (int i = 0; i < numVertices; i++)
      {
        if (expandArray[i])
        {
          int orderV = m_deathAge[i];
          pt[] result = m_packetFetcher.fetchGeometry(currentLODWave, orderV);
          m_expandVertices.add(P(result[0])); m_expandVertices.add(P(result[1])); m_expandVertices.add(P(result[2]));
          int[] ct = {corners[countExpanded], corners[countExpanded+1], corners[countExpanded+2]};
          countExpanded+=3;
          stitch( i, result, currentLODWave, orderV, ct );
        }
      }
      
      currentLODWave--;
      print("Debug " + numVertices + " " + sizeSplitBitsArray + "\n");
      print("Expanded one level. New number of vertices " + nv + "\n");
    }
    
    profiler.done();
    onDoneExpand();
    print("Total bits per vertex " + totalBitsNothing + " " + (float)totalBitsNothing/g_totalVertices + "\n");
    print("Total bits per vertex " + totalBits + " " + (float)totalBits/g_totalVertices + "\n");
    print("Total bits per choose " + totalBitsChoose + " " + (float)totalBitsChoose/g_totalVertices + "\n");
    print("Num 0's " + countFalse + " Num 1's " + countTrue + "\n");
  } 
  
  private boolean[] getRegionArray( ArrayList<Integer> regionCorners )
  {
    boolean[] regionArray = new boolean[nv];
    for (int i:regionCorners)
    {
      regionArray[v(i)] = true;
    }
    return regionArray;
  }
   
  void selectRegion(int corner)
  {
    boolean[] markedVertices = new boolean[nv];

    ArrayList<Integer> inRegion = new ArrayList<Integer>();

    inRegion.add( corner );
    markedVertices[v(corner)] = true;

    ArrayList<Integer> expandedRegion = expandInRegion( inRegion, 1, markedVertices );
    setRegion(markedVertices);
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

  void expandRegion(int corner)
  {
    FunctionProfiler profiler = new FunctionProfiler();
    int vertexToExpand = v(corner);

    int currentLODWave = NUMLODS - 1;
    boolean[] expandArray;
    int[] cornerForVertex;
    boolean[] splitBitsArray;
    pt[] expandVertices;
    int numExpandable;
    int totalBits = 0;
    int totalBitsChoose = 0;
    boolean[] inRegion;
    m_expandVertices.clear();
    m_expandBits.clear();
    
    ArrayList<Integer> descendedCorners = new ArrayList<Integer>();
    ArrayList<Integer> expandedCorners;
    descendedCorners.add(corner);

    while (currentLODWave >= 0)
    {
      numExpandable = 0;
      expandArray = new boolean[nv];
      cornerForVertex = new int[nv];
      splitBitsArray = new boolean[nc];
      inRegion = new boolean[nv];
      
      //Mark the region to be expanded
      expandedCorners = new ArrayList<Integer>();
      for (int i:descendedCorners)
      {
        checkDebugNotEqual( inRegion[v(i)], true , "WorkingMesh::expandRegion => Error!! Original is already expanded!!\n", LOW );
        inRegion[v(i)] = true;
        expandedCorners.add(i);
      }

      if ( currentLODWave > 0 )
      {
        expandedCorners = expandInRegion( expandedCorners, currentLODWave, inRegion );
        print("Size of expanded region " + expandedCorners.size() + " ring size " + currentLODWave + "\n");
      }
      setRegion(inRegion);
 
      int numValidExpandable = 0;
      
      if ( DEBUG && DEBUG_MODE >= VERBOSE )
      {
        for (int i = 0; i < expandedCorners.size() - 1;i++)
        {
          for (int j = i+1; j < expandedCorners.size(); j++)
          {
            checkDebugNotEqual( v(expandedCorners.get(i)), v(expandedCorners.get(j)), "WorkingMesh::expandRegion => Error!! expandedCorners has two corners with same vertex\n", LOW );
          }
        }
      }
      
      for (int i:expandedCorners)
      {
        int vertex = v(i);
        checkDebugEqual( inRegion[vertex], true, "WorkingMesh::expandRegion => Error!! Vertex is not marked inRegion\n", LOW );
       
        if ( m_birthLOD[vertex] >= currentLODWave ) //This might happen if a region has been expanded, and another one is being expanded
        {
          int lod = m_deathLOD[vertex];
          if ( lod == currentLODWave )
          {
            if ( !expandArray[vertex] )
            {
              int orderV = m_deathAge[vertex];

              //TODO msati3: Could use connectivity here as well
              pt[] result = m_packetFetcher.fetchGeometry(currentLODWave, orderV);
              if ( result[1] != null )
              {
                expandArray[vertex] = true;
                numExpandable++;
              }
            }
          }
          numValidExpandable++;
        }
      }
      
      print("Num valid to be expanded possibly " + numValidExpandable + " Num expandable " + numExpandable + "\n");

      int[] corners = new int[3*numExpandable];
      int sizeSplitBitsArray = 0;
      int sizeCornersArray = 0;
      for (int i:expandedCorners)
      {
        int vertex = v(i);
        if ( m_birthLOD[vertex] >= currentLODWave ) //This might happen if a region has been expanded, and another one is being expanded
        {
          m_expandBits.add(expandArray[vertex]);
          totalBits++;
          totalBitsChoose++;
          if ( expandArray[vertex] )
          {
            sizeSplitBitsArray += populateSplitBitsArray(splitBitsArray, currentLODWave, i, corners, sizeCornersArray, sizeSplitBitsArray);
            int valence = getValence(i); 
            totalBits += valence;
            totalBitsChoose += ceil((log((valence * (valence - 1) * (valence - 2))/6)/log(2)));
            sizeCornersArray += 3;
          }
        }
      }

      for (int i = 0; i < sizeSplitBitsArray; i++)
      {
        m_expandBits.add( splitBitsArray[i] );
      }

      int countExpanded = 0;
      int numVertices = nv; 
      for (int i:expandedCorners)
      {
        int vertex = v(i);
        int cornerInit = nc;
        if ( expandArray[vertex] && m_birthLOD[vertex] >= currentLODWave )
        {
          addIfDescendedFromOriginalVertex( i, descendedCorners );
          int orderV = m_deathAge[vertex];
          pt[] result = m_packetFetcher.fetchGeometry(currentLODWave, orderV);
          m_expandVertices.add(P(result[0])); m_expandVertices.add(P(result[1])); m_expandVertices.add(P(result[2]));
          int[] ct = {corners[countExpanded], corners[countExpanded+1], corners[countExpanded+2]};
          countExpanded+=3;
          stitch( vertex, result, currentLODWave, orderV, ct );
        }
      }
      
      currentLODWave--;
      print("Size of descendedCorners " + descendedCorners.size() + "\n");
      print("Expanded one level. New number of vertices " + nv + "\n");
    }
    
    profiler.done();
    onDoneExpand();
    int countVerticesComplete = 0;
    for (int i = 0; i < nv; i++)
    {
      if ( m_descendedFrom[i] == vertexToExpand )
      {
        countVerticesComplete++;
      }
    }
    print("Total number of fully vertices added " + m_expandVertices.size() + "\n");
    print("Total bits per fully expanded vertices " + totalBits + " " + countVerticesComplete + " " + (float)totalBits/countVerticesComplete + "\n");
    print("Total bits per fully expanded vertices choose " + totalBitsChoose + " " + countVerticesComplete + " " + (float)totalBitsChoose/countVerticesComplete + "\n");
  }
  
  void addIfDescendedFromOriginalVertex( int corner, ArrayList<Integer> descendedCorners )
  {
    int indexToRemoveFrom = -1;
    for (int j = 0; j < descendedCorners.size(); j++)
    {
      if ( corner == descendedCorners.get(j) )
      {
        indexToRemoveFrom =  j;
        break;
      }
    }
    //Add first two corners that would be added post stitch (as there are the corners corresponding to newly added vertices v1 and v2
    if ( indexToRemoveFrom != -1 )
    {
      descendedCorners.add( nc );
      descendedCorners.add( nc+1 );
      descendedCorners.set( indexToRemoveFrom, nc+2 );
    }
  }

  void expand(int corner)
  {
    int vertex = v(corner);
    int lod = m_deathLOD[vertex];
    if (lod >= 0)
    {
      homogenize(corner);
      if ( DEBUG && DEBUG_MODE >= VERBOSE )
      {
        print("Homogenized");
      }
      int orderV = m_deathAge[vertex];
      pt[] result = m_packetFetcher.fetchGeometry(lod, orderV);
      if (result[1] != null && lod >= 0)
      {
        int[] ct = getExpansionCornerNumbers(lod, corner);
        stitch( v(corner), result, lod, orderV, ct );
      }
    }
    onDoneExpand();
  }
  
  void onDoneExpand()
  {
    //markExpandableVerts();
    
    initVBO(1);
    updateColorsVBO(255);
  }

  void stitch( int currentV, pt[] g, int currentLOD, int currentOrderV, int[] ct )
  {
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      print("Stiching using corners " + ct[0] + " " + ct[1] + " " + ct[2] + " vertex " + currentV + "\n");
    }
    if ( DEBUG && DEBUG_MODE >= LOW )
    {
      int orderT1 = m_orderT[t(ct[0])];
      int orderT2 = m_orderT[t(ct[1])];
      int orderT3 = m_orderT[t(ct[2])];
      if (orderT1 >= orderT2 || orderT1 >= orderT3)
      {
        print("workingMeshServer::stitch incorrect orderings !!!!\n" + currentOrderV + " " + currentV + " " + orderT1 + " " + orderT2 + " " + orderT3 + "\n");
      }
    }

    int offsetCorner = 3*nt;
    int v1 = addVertex(g[0], currentLOD-1, 3*currentOrderV);
    int v2 = addVertex(g[1], currentLOD-1, 3*currentOrderV+1);
    int v3 = addVertex(g[2], currentV, currentLOD-1, 3*currentOrderV+2);
    m_descendedFrom[v1] = m_descendedFrom[currentV];
    m_descendedFrom[v2] = m_descendedFrom[currentV];

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
}

