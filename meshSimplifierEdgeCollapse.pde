class MeshSimplifierEdgeCollapse
{
  private Mesh m_mesh;
  private Mesh m_simplifiedMesh;
  private SuccLODMapperManager m_succLODMapperManager;
  int[][] m_vertexMappingBaseToMain;
  int[] m_triangleMappingBaseToMain;
  int[][] m_vertexToTriagleMappingBaseToMain;

  //Caching the two locations of L and R triangles for edge collapses, if they are moved from the end of the list.
  int m_locationLT;
  int m_locationRT;
  int m_collapseRevert; //count the number of island triangles moved up in one collapse, so that we can reconsider them
  
  MeshSimplifierEdgeCollapse( Mesh m, SuccLODMapperManager sLODMapperManager )
  {
    m_mesh = m;
    m_simplifiedMesh = new Mesh();
    m_succLODMapperManager = sLODMapperManager;
    m_vertexMappingBaseToMain = new int[m_mesh.nv][3];
    m_triangleMappingBaseToMain = new int[m_mesh.nt];
    m_vertexToTriagleMappingBaseToMain = new int[m_mesh.nv][4];

    m_succLODMapperManager.addLODLevel();
    m_succLODMapperManager.getActiveLODMapper().setBaseMesh(m_simplifiedMesh);
    m_succLODMapperManager.getActiveLODMapper().setRefinedMesh(m_mesh);
  }
  
  private pt centroid(Mesh m, int triangleIndex)
  {
    pt pt1 = m.G[m.v(m.c(triangleIndex))];
    pt pt2 = m.G[m.v(m.c(triangleIndex) + 1)];
    pt pt3 = m.G[m.v(m.c(triangleIndex) + 2)];

    return P(pt1, pt2, pt3);
  }
  
  private void copyMainToSimplifiedMesh()
  {
    //First create copy of orig mesh 
    for (int i = 0; i < m_mesh.nv; i++) 
    {
      m_vertexMappingBaseToMain[i][0] = i;
      m_vertexMappingBaseToMain[i][1] = -1;
      m_vertexMappingBaseToMain[i][2] = -1;
      
      m_vertexToTriagleMappingBaseToMain[i][0] = -1;
      m_vertexToTriagleMappingBaseToMain[i][1] = -1;
      m_vertexToTriagleMappingBaseToMain[i][2] = -1;
      m_vertexToTriagleMappingBaseToMain[i][3] = -1;     

      m_simplifiedMesh.G[i] = P(m_mesh.G[i]);
    }
    m_simplifiedMesh.nv = m_mesh.nv;

    for (int i = 0; i < m_mesh.nc; i++)
    {
      m_simplifiedMesh.V[i] = m_mesh.V[i];
    }
    m_simplifiedMesh.nt = m_mesh.nt;

    for (int i = 0; i < m_mesh.nc; i++) 
    {
      m_simplifiedMesh.O[i] = m_mesh.O[i];
    }

    m_simplifiedMesh.resetMarkers();

    for (int i = 0; i < m_mesh.nt; i++)
    {
      m_triangleMappingBaseToMain[i] = i;
      m_simplifiedMesh.tm[i] = m_mesh.tm[i];
    }
    m_simplifiedMesh.nc = m_mesh.nc;
  }
  
  private void populateOpposites( int c )
  {
    int l = m_simplifiedMesh.l(c);
    int r = m_simplifiedMesh.r(c);
    m_simplifiedMesh.O[l] = r;
    m_simplifiedMesh.O[r] = l;
  }

  private void shiftGUp( pt[] G, int startIndex )
  {
    for (int i = startIndex+1; i < m_mesh.nv; i++)
    {
      G[i-1] = G[i];
      for (int j = 0; j < 3; j++)
      {
        m_vertexMappingBaseToMain[i-1][j] = m_vertexMappingBaseToMain[i][j];
      }
      for (int j = 0; j < 4; j++)
      {
        m_vertexToTriagleMappingBaseToMain[i-1][j] = m_vertexToTriagleMappingBaseToMain[i][j];        
      }
    }
  }
  
  private void fixupV( int lowV, int highC )
  {
    Mesh m = m_simplifiedMesh;
    int currentCorner = highC;
    do
    {
      m.V[currentCorner] = lowV;
      currentCorner = m.s(currentCorner);
    } while (currentCorner != highC);
  }

  private void moveTriangle( int fromT, int toT )
  {
    Mesh m = m_simplifiedMesh;
    for (int i = 0; i < 3; i++)
    {
      m.V[3*toT + i] = m.V[3*fromT + i];
      m.O[3*toT + i] = m.O[3*fromT + i];
      m.O[m.O[3*toT + i]] = 3*toT + i;
      m.tm[3*toT + i] = m.tm[3*fromT + i];
    }
  }
  
  private void removeTriangles( int t1, int t2 )
  {
    //Copy the last triangles here
    Mesh m = m_simplifiedMesh;
    int move1 = t1 == m.nt - 1 ? 0 : t1 == m.nt - 2 ? 1 : 2;
    int move2 = t2 == m.nt - 1 ? 0 : t2 == m.nt - 2 ? 1 : 2;
    if ( move1+move2 == 1 ) //The two are the last and the second last
    {
      return;
    }
    
    int[] triangleMoved1 = {-1, -1};
    int[] triangleMoved2 = {-1, -1};
    if ( move1 + move2 == 4 )
    {
      moveTriangle( m.nt-1, t1 );
      moveTriangle( m.nt-2, t2 );
      triangleMoved1[0] = m.nt-1;
      triangleMoved2[0] = m.nt-2;
      triangleMoved1[1] = t1;
      triangleMoved2[1] = t2;
    }
    else if ( move1 == 2 )
    {
      if ( move2 != 0 )
      {
        moveTriangle( m.nt-1, t1 );
        triangleMoved1[0] = m.nt - 1;
        triangleMoved1[1] = t1;
      }
      else
      {
        moveTriangle( m.nt-2, t1 );
        triangleMoved1[0] = m.nt - 2;
        triangleMoved1[1] = t1;
      }
    }
    else if ( move2 == 2 )
    {
      if ( move1 != 0 )
      {
        moveTriangle( m.nt-1, t2 );
        triangleMoved1[0] = m.nt - 1;
        triangleMoved1[1] = t2;
      }
      else
      {
        moveTriangle( m.nt-2, t2 );
        triangleMoved1[0] = m.nt - 2;
        triangleMoved1[1] = t2;
      }
    }
   
    if ( triangleMoved1[0] == m_locationLT )
    {
        m_locationLT = triangleMoved1[1];
    }
    else if ( triangleMoved2[0] == m_locationLT )
    {
        m_locationLT = triangleMoved2[0];
    }
    if ( triangleMoved1[0] == m_locationRT )
    {
        m_locationRT = triangleMoved1[1];
    }
    else if ( triangleMoved2[0] == m_locationRT )
    {
        m_locationRT = triangleMoved2[1];
    }
    
    if ( m.tm[triangleMoved1[1]] == ISLAND )
    {
      m_collapseRevert++;
    }
    if ( m.tm[triangleMoved2[1]] == ISLAND )
    {
      m_collapseRevert++;
    }

    m.nc -= 6;
    m.nt -= 2;
  }
  
  //Collapse to a new vertex. Add this new vertex to lower location of G table and modify O, V and G tables
  private int edgeCollapse( int c1, int c2, pt vertex )
  {
    if ( DEBUG && DEBUG_MODE >= VERBOSE)
    {
      print("Edge collapse " + c1 + "  " + c2 + "\n");
    }
    Mesh m = m_simplifiedMesh;
    int v1 = m.v(m.n(c1));
    int v2 = m.v(m.p(c1));
    int lowerV = v1 < v2 ? v1 : v2;
    int higherV = v1 > v2 ? v1 : v2;
    int lowerC = v1 < v2 ? m.n(c1) : m.p(c2);
    int higherC = v1 > v2 ? m.n(c1) : m.p(c2);
    
    fixupV(lowerV, higherC);

    //Populate opposites
    populateOpposites(c1);
    populateOpposites(c2);
    
    //Add vertex, modify G
    m.G[lowerV] = vertex;
    
    //Remove triangles modify V and O
    int t1 = m.t(c1); int t2 = m.t(c2);
    removeTriangles( t1, t2 );
    
    return lowerV;
  }
  
  Mesh simplify()
  {
    copyMainToSimplifiedMesh();
    
    int[] islandTriangleNumbersInMain = new int[m_mesh.nt];
    int numIslandTriangles = 0;
    int numBaseTriangles = 0;
    
    for (int i = 0; i < m_mesh.nt; i++)
    {
      if (m_mesh.tm[i] == ISLAND)
      {
        islandTriangleNumbersInMain[numIslandTriangles++] = i;
      }
      if (m_mesh.tm[i] != ISLAND && m_mesh.tm[i] != CHANNEL)
      {
         m_triangleMappingBaseToMain[numBaseTriangles++] = i;
      }
    }

    numIslandTriangles = 0;
    for (int i = 0; i < m_simplifiedMesh.nt; i++)
    {
      if (m_simplifiedMesh.tm[i] == ISLAND)
      {
        int c = m_simplifiedMesh.c(i);
        int o = m_simplifiedMesh.o(c);
        int l = m_simplifiedMesh.l(c);
        int r = m_simplifiedMesh.r(c);
        
        if (DEBUG && DEBUG_MODE >= LOW)
        {
          print(c + " " + o + " " + l + " " + r + "\n");
        }

        pt newPt = centroid(m_simplifiedMesh, i);
        m_collapseRevert = 0;
        int commonVertexIndex = edgeCollapse( c, o, newPt );
        m_locationRT = r;
        m_locationLT = l;
        commonVertexIndex = edgeCollapse( m_locationLT, m_locationRT, newPt );
       
        m_vertexMappingBaseToMain[commonVertexIndex][0] = m_mesh.v(m_mesh.c(islandTriangleNumbersInMain[numIslandTriangles]));
        m_vertexMappingBaseToMain[commonVertexIndex][1] = m_mesh.v(m_mesh.n(m_mesh.c(islandTriangleNumbersInMain[numIslandTriangles])));
        m_vertexMappingBaseToMain[commonVertexIndex][2] = m_mesh.v(m_mesh.p(m_mesh.c(islandTriangleNumbersInMain[numIslandTriangles])));
        
        m_vertexToTriagleMappingBaseToMain[commonVertexIndex][0] = islandTriangleNumbersInMain[numIslandTriangles];
        m_vertexToTriagleMappingBaseToMain[commonVertexIndex][1] = m_mesh.t(m_mesh.u(m_mesh.c(islandTriangleNumbersInMain[numIslandTriangles])));
        m_vertexToTriagleMappingBaseToMain[commonVertexIndex][2] = m_mesh.t(m_mesh.u(m_mesh.n(m_mesh.c(islandTriangleNumbersInMain[numIslandTriangles]))));
        m_vertexToTriagleMappingBaseToMain[commonVertexIndex][3] = m_mesh.t(m_mesh.u(m_mesh.p(m_mesh.c(islandTriangleNumbersInMain[numIslandTriangles]))));

        
        numIslandTriangles++;

        //At most 3 triangles before may be removed due to collapse. Revert i index to the required number for this case
        i -= m_collapseRevert;
        m_collapseRevert = 0;
      }
    }
    m_succLODMapperManager.getActiveLODMapper().setBaseToRefinedVMap(m_vertexMappingBaseToMain);
    m_succLODMapperManager.getActiveLODMapper().setBaseToRefinedTMap(m_triangleMappingBaseToMain);
    m_succLODMapperManager.getActiveLODMapper().setBaseVToRefinedTMap(m_vertexToTriagleMappingBaseToMain);
    print("Num vertices " + m_simplifiedMesh.nv + " Num triangles " + m_simplifiedMesh.nt + "\n");
    return m_simplifiedMesh;
  }
}
