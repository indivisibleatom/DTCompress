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
  int[] m_orderV = new int[maxnv]; //The order of the vertex

  int[] m_orderT = new int[maxnt]; //The order of the triangle
  int[] m_ageT = new int[maxnt];

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
      FutureLODAndVOrder future = getLODAndVOrder( NUMLODS - 1, i );
      m_LOD[i] = future.lod();
      m_orderV[i] = future.orderV();
    }
  }
  
  void markTriangleAges()
  {
     for (int i = 0; i < nc; i++)
    {
      tm[t(i)] = m_LOD[v(i)] + 1;
    }
  }
  
  private FutureLODAndVOrder getLODAndVOrder( int lod, int orderV )
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
    do 
    {
      int lodCurrent = m_LOD[v(n(currentCorner))];
      if ( lodCurrent > lod )
      {
        expand(n(currentCorner));
      }
      currentCorner = s(currentCorner);
    } while(currentCorner != corner);
  }

  int addVertex(pt p, int lod, int orderV)
  {
    int vertexIndex = addVertex(p);
    FutureLODAndVOrder future = getLODAndVOrder( lod, orderV );
    m_LOD[vertexIndex] = future.lod();
    m_orderV[vertexIndex] = future.orderV();
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
    int orderV = m_orderV[vertex];
    int lod = m_LOD[vertex];
    if ( lod >= 0 )
    {
      pt[] result = m_packetFetcher.fetchGeometry(lod, orderV);
      int cornerOffset = cc%3;
      boolean expand = m_packetFetcher.fetchConnectivity(lod, 3*m_orderT[t(cc)] + cornerOffset);
      print( "Order vertex" + orderV + " " + "lod " + lod + "order triangle " + m_orderT[t(cc)] + "age triangle " + m_ageT[t(cc)] + "\n");
      print( "Expand edge " + expand + " Geometry " + result[0] + " " + result[1] + " " + result[2] + "\n" );
    }
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

      int orderV = m_orderV[vertex];
      int triangle = t(i);
      int cornerOffset = i%3;

      int orderT = m_orderT[triangle];
      int lod = m_LOD[vertex];
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
      int orderV = m_orderV[vertex];
      pt[] result = m_packetFetcher.fetchGeometry(lod, orderV);
      if (result[1] != null && lod >= 0)
      {
        int[] ct = getExpansionCornerNumbers(lod, corner);
        if ( DEBUG && DEBUG_MODE >= VERBOSE )
        {
          print("Stiching using corners " + ct[0] + " " + ct[1] + " " + ct[2] + "\n");
        }
        stitch( result, lod, orderV, ct );
      }
    }
  }

  void stitch( pt[] g, int currentLOD, int currentOrderV, int[] ct )
  {
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
      /*else
      {
        offsetTriangles += 4 * verticesAtLOD;
      }*/
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

