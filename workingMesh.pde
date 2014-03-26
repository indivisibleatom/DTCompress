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
  int[] m_LOD = new int[maxnv]; //LOD per vertex
  int[] m_deathAge = new int[maxnv]; //The order of the vertex

  int[] m_orderT = new int[maxnt]; //The order of the triangle
  int[] m_ageT = new int[maxnt];
  
  ArrayList<Boolean> m_expandBits;
  ArrayList<pt> m_expandVertices;

  int m_baseTriangles;
  int m_baseVerts;

  PacketFetcher m_packetFetcher;

  WorkingMesh( Mesh m, SuccLODMapperManager lodMapperManager )
  {
    G = m.G;
    V = m.V;
    O = m.O;
    nv = m.nv;
    nt = m.nt;
    nc = m.nc;
    
    m_expandBits = new ArrayList<Boolean>();
    m_expandVertices = new ArrayList<pt>();

    m_baseVerts = nv;
    m_baseTriangles = nt;
    m_userInputHandler = new WorkingMeshUserInputHandler(this);
    m_packetFetcher = new PacketFetcher(lodMapperManager);
    m_triangleColorMap = new int[10];
    m_triangleColorMap[0] = green;
    m_triangleColorMap[1] = yellow;
    m_triangleColorMap[2] = red;

    for (int i = 0; i < m.nt; i++)
    {
      m_orderT[i] = i;
      m_ageT[i] = NUMLODS - 1;
    }

    for (int i = 0; i < m.nv; i++)
    {
      FutureLODAndVOrder future = getLODAndVAge( NUMLODS - 1, i );
      m_LOD[i] = future.lod();
      m_deathAge[i] = future.orderV();
    }
  }
  
  void markTriangleAges()
  {
     /*for (int i = 0; i < nc; i++)
    {
      tm[t(i)] = m_LOD[v(i)] + 1;
    }*/
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
      print("Find smallest expansion corner for corner " + corner + "LOD and LOD swing " + lod + " " + m_LOD[v(n(s(corner)))] + "\n");
    }
    int minTriangle = maxnt;
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

  private int[] getExpansionCornerNumbers(int lod, int corner)
  {
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      print("Get expansion corner numbers for lod " + lod + " " + m_LOD[v(corner)] + "\n");
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
    int lod = m_LOD[v(corner)];
    boolean fRequiredExpansion = true;
    do
    {
      fRequiredExpansion = false;
      do 
      {
        int lodCurrent = m_LOD[v(n(currentCorner))];
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
    m_LOD[vertexIndex] = future.lod();
    m_deathAge[vertexIndex] = future.orderV();
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
    int lod = m_LOD[vertex];
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
    int lod = m_LOD[vertex];
    
    int currentCorner = corner;
    do
    {
      if ( m_LOD[ v(currentCorner) ] != lod )
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
      int lod = m_LOD[vertex];
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
      }
      else
      {
        splitArray[sizeSplitBitsArray+count] = false;
      }
      currentCorner = s(currentCorner);
      count++;
    } 
    while (currentCorner != corner);
    if (DEBUG && DEBUG_MODE >= LOW)
    {
      if ( numSplitEdges != 3 )
      {
        print("workingMesh::populateSplitBitsArray - number of splitBits is not 3!\n");
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
    print("Expanding mesh " + nv + "\n");
    int currentLODWave = NUMLODS - 1;
    boolean[] expandArray;
    int[] cornerForVertex;
    boolean[] splitBitsArray;
    pt[] expandVertices;
    int numExpandable;
    int totalBits = 0;
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
        int lod = m_LOD[vertex];
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
        if ( expandArray[i] )
        {
          sizeSplitBitsArray += populateSplitBitsArray(splitBitsArray, currentLODWave, cornerForVertex[i], corners, sizeCornersArray, sizeSplitBitsArray);
          totalBits += getValence(cornerForVertex[i]);
          sizeCornersArray += 3;
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
          stitch( result, currentLODWave, orderV, ct );
        }
      }
      
      currentLODWave--;
      print("Debug " + numVertices + " " + sizeSplitBitsArray + "\n");
      print("Expanded one level. New number of vertices " + nv + "\n");
    }
    print("Total bits per vertex " + totalBits + " " + (float)totalBits/g_totalVertices + "\n");
  }
  
  void expandRegion(int corner)
  {
    float r2 = 1000;
    pt centerSphere = P(G[v(corner)]);

    int currentLODWave = NUMLODS - 1;
    boolean[] expandArray;
    int[] cornerForVertex;
    boolean[] splitBitsArray;
    pt[] expandVertices;
    int numExpandable;
    int totalBits = 0;
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
 
      int numValidExpandable = 0;
      for (int i = 0; i < nc; i++)
      {
        int vertex = v(i);
        if ( d2( centerSphere, G[vertex] ) <= r2 )
        {
          if ( cornerForVertex[vertex] == -1 )
          {
            cornerForVertex[vertex] = i;
          }
          int lod = m_LOD[vertex];
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
      print("\n" + numValidExpandable+ " " + numExpandable + " ");

      int[] corners = new int[3*numExpandable];
      int sizeSplitBitsArray = 0;
      int sizeCornersArray = 0;
      for (int i = 0; i < nv; i++)
      {
        if ( d2( centerSphere, G[i] ) <= r2 )
        {
          m_expandBits.add(expandArray[i]);
          totalBits++;
          if ( expandArray[i] )
          {
            sizeSplitBitsArray += populateSplitBitsArray(splitBitsArray, currentLODWave, cornerForVertex[i], corners, sizeCornersArray, sizeSplitBitsArray);
            totalBits += getValence(cornerForVertex[i]);
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
      for (int i = 0; i < numVertices; i++)
      {
        if ( expandArray[i] && d2( centerSphere, G[i] ) <= r2 )
        {
          int orderV = m_deathAge[i];
          pt[] result = m_packetFetcher.fetchGeometry(currentLODWave, orderV);
          m_expandVertices.add(P(result[0])); m_expandVertices.add(P(result[1])); m_expandVertices.add(P(result[2]));
          int[] ct = {corners[countExpanded], corners[countExpanded+1], corners[countExpanded+2]};
          countExpanded+=3;
          stitch( result, currentLODWave, orderV, ct );
        }
      }
      
      currentLODWave--;
      print("Debug " + numVertices + " " + sizeSplitBitsArray + "\n");
      print("Expanded one level. New number of vertices " + nv + "\n");
    }
    print("Total bits per vertex " + totalBits + " " + (float)totalBits/g_totalVertices + "\n");
  }

  void expand(int corner)
  {
    int vertex = v(corner);
    int lod = m_LOD[vertex];
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
        stitch( result, lod, orderV, ct );
      }
    }
  }

  void stitch( pt[] g, int currentLOD, int currentOrderV, int[] ct )
  {
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      print("Stiching using corners " + ct[0] + " " + ct[1] + " " + ct[2] + "\n");
    }
    if ( DEBUG && DEBUG_MODE >= LOW )
    {
      int orderT1 = m_orderT[t(ct[0])];
      int orderT2 = m_orderT[t(ct[1])];
      int orderT3 = m_orderT[t(ct[2])];
      if (orderT1 >= orderT2 || orderT1 >= orderT3)
      {
        print("workingMeshServer::stitch incorrect orderings !!!!\n");
      }
    }

    int offsetCorner = 3*nt;
    int v1 = addVertex(g[0], currentLOD-1, 3*currentOrderV);
    int v2 = addVertex(g[1], currentLOD-1, 3*currentOrderV+1);
    int v3 = addVertex(g[2], currentLOD-1, 3*currentOrderV+2);

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
    markExpandableVerts();
    
    //Recolor expanded vertex
    //colorCorrect( offsetCorner );
  }
  
  void colorCorrect( int corner )
  {
    int currentCorner = corner;
    do
    {
      int swingCorner = currentCorner;
      do
      {
        swingCorner = s(swingCorner);
      } while (swingCorner != currentCorner);
      currentCorner = n(currentCorner);
    } while (currentCorner != corner);
  }
}

