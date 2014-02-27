class MeshSimplifierEdgeCollapse
{
  private Mesh m_mesh;
  private Mesh m_simplifiedMesh;
  private SuccLODMapperManager m_succLODMapperManager;
  int[][] m_vertexMappingBaseToMain;
  int[][] m_vertexToTriagleMappingBaseToMain;

  //Mapping from main mesh to mesh being incrementally simplified
  int[] m_tMappingMeshTToSimplifiedT;
  int[] m_tMappingSimplifiedTToMeshT;
  int[] m_vMappingMeshToSimplifiedV;
  
  MeshSimplifierEdgeCollapse( Mesh m, SuccLODMapperManager sLODMapperManager )
  {
    m_mesh = m;
    m_simplifiedMesh = new Mesh();
    m_succLODMapperManager = sLODMapperManager;
    m_vertexMappingBaseToMain = new int[m_mesh.nv][3];
    m_vertexToTriagleMappingBaseToMain = new int[m_mesh.nv][4];

    m_tMappingMeshTToSimplifiedT = new int[m_mesh.nt];
    m_tMappingSimplifiedTToMeshT = new int[m_mesh.nt];
    m_vMappingMeshToSimplifiedV = new int[m_mesh.nv];
 
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

  private void moveTriangle( int fromT, int toT )
  {
    if (DEBUG && DEBUG_MODE >= VERBOSE)
    {
      print("Move triangles " + fromT + " " + toT + "\n");
    }
    m_tMappingSimplifiedTToMeshT[toT] = m_tMappingSimplifiedTToMeshT[fromT];
    m_tMappingMeshTToSimplifiedT[m_tMappingSimplifiedTToMeshT[fromT]] = toT;
    Mesh m = m_simplifiedMesh;
    m.tm[toT] = m.tm[fromT];
    for (int i = 0; i < 3; i++)
    {
      m.V[3*toT + i] = m.V[3*fromT + i];
      m.O[3*toT + i] = m.O[3*fromT + i];
      m.O[m.O[3*toT + i]] = 3*toT + i;
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
      m.nc -= 6;
      m.nt -= 2;
      return;
    }
    
    if ( move1 + move2 == 4 )
    {
      moveTriangle( m.nt-1, t1 );
      moveTriangle( m.nt-2, t2 );
    }
    else if ( move1 == 2 )
    {
      if ( move2 != 0 )
      {
        moveTriangle( m.nt-1, t1 );
      }
      else
      {
        moveTriangle( m.nt-2, t1 );
      }
    }
    else if ( move2 == 2 )
    {
      if ( move1 != 0 )
      {
        moveTriangle( m.nt-1, t2 );
      }
      else
      {
        moveTriangle( m.nt-2, t2 );
      }
    }
    else
    {
      if ( DEBUG && DEBUG_MODE >= LOW )
      {
        print("MeshSimplifierEdgeCollapse::removeTriangles No condition met!!\n");
      }
    }
    m.nc -= 6;
    m.nt -= 2;
  }

  //Collapse to a new vertex. Add this new vertex to lower location of G table and modify O, V and G tables
  int numTimes = 0;
  
  private int edgeCollapse( int c1, int c2, pt vertex )
  {
    numTimes++;
    if ( DEBUG && DEBUG_MODE >= VERBOSE)
    {
      print("Edge collapse " + c1 + "  " + c2 + "\n");
    }
    Mesh m = m_simplifiedMesh;
    int v1 = m.v(m.n(c1));
    int v2 = m.v(m.p(c1));
    int lowerV = v1 < v2 ? v1 : v2;
    int higherV = v1 > v2 ? v1 : v2;
    int lowerC = v1 < v2 ? m.n(c1) : m.p(c1);
    int higherC = v1 > v2 ? m.n(c1) : m.p(c1);
    
    m.G[higherV] = null;

    //Set all v's to point to lowerV
    int currentCorner = higherC;
    do
    {
      m.V[currentCorner] = lowerV;
      currentCorner = m.s(currentCorner);
    }while (currentCorner != higherC);

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
  
    int numBaseTriangles = 0;   
    for (int i = 0; i < m_mesh.nt; i++)
    {
      m_tMappingMeshTToSimplifiedT[i] = i;
      m_tMappingSimplifiedTToMeshT[i] = i;
    }

    int islandNumber = 0;
    for (int i = 0; i < m_mesh.nt; i++)
    {
        int simplifiedT = m_tMappingMeshTToSimplifiedT[i];
        if (m_mesh.tm[i] == ISLAND)
        {
          int c = m_simplifiedMesh.c(simplifiedT);
          int o = m_simplifiedMesh.o(c);
          int lMain = m_mesh.l(m_mesh.c(i));
          int rMain = m_mesh.r(m_mesh.c(i));
          
          if (m_simplifiedMesh.tm[simplifiedT] != ISLAND)
          {
            if ( DEBUG && DEBUG_MODE >= LOW )
            {
              print("MeshSimplifier:simplify - simplifiedMesh.tm[simplifiedT] is not an island, while the main mesh is!\n");
            }
          }
          
          pt newPt = centroid(m_mesh, i);
          int commonVertexIndex = edgeCollapse( c, o, newPt );        
          int l = m_simplifiedMesh.c(m_tMappingMeshTToSimplifiedT[m_mesh.t(lMain)]) + lMain%3;
          int r = m_simplifiedMesh.c(m_tMappingMeshTToSimplifiedT[m_mesh.t(rMain)]) + rMain%3;
          commonVertexIndex = edgeCollapse( l, r, newPt );
          if (DEBUG && DEBUG_MODE >= VERBOSE)
          {
            print(c + " " + o + " " + l + " " + r + "\n");
          }
          
          m_vertexMappingBaseToMain[commonVertexIndex][0] = m_mesh.v(m_mesh.c(i));
          m_vertexMappingBaseToMain[commonVertexIndex][1] = m_mesh.v(m_mesh.n(m_mesh.c(i)));
          m_vertexMappingBaseToMain[commonVertexIndex][2] = m_mesh.v(m_mesh.p(m_mesh.c(i)));

          m_vertexToTriagleMappingBaseToMain[commonVertexIndex][0] = i;
          m_vertexToTriagleMappingBaseToMain[commonVertexIndex][1] = m_mesh.t(m_mesh.u(m_mesh.c(i)));
          m_vertexToTriagleMappingBaseToMain[commonVertexIndex][2] = m_mesh.t(m_mesh.u(m_mesh.n(i)));
          m_vertexToTriagleMappingBaseToMain[commonVertexIndex][3] = m_mesh.t(m_mesh.u(m_mesh.p(i)));
       }
    }

    int countV = 0;
    for (int i = 0; i < m_mesh.nv; i++)
    {
      m_vMappingMeshToSimplifiedV[i] = -1;
      if ( m_simplifiedMesh.G[i] != null )
      {
        m_vertexMappingBaseToMain[countV] = m_vertexMappingBaseToMain[i];
        m_vertexToTriagleMappingBaseToMain[countV++] = m_vertexToTriagleMappingBaseToMain[i];
      }
    }

    int indexNotNull = 0;
    for (int i = 0; i < m_mesh.nv; i++, indexNotNull++)
    {
      if ( m_simplifiedMesh.G[i] == null )
      {
        m_simplifiedMesh.nv--;
      }
      while ( indexNotNull < m_mesh.nv && m_simplifiedMesh.G[indexNotNull] == null )
      {
        indexNotNull++;
      }
      if (indexNotNull < m_mesh.nv)
      {
        m_vMappingMeshToSimplifiedV[indexNotNull] = i;
        m_simplifiedMesh.G[i] = m_simplifiedMesh.G[indexNotNull];
      }
    }
    
    for (int i = 0; i < m_mesh.nc; i++)
    {
      m_simplifiedMesh.V[i] = m_vMappingMeshToSimplifiedV[m_simplifiedMesh.V[i]];
    }

    if ( DEBUG && DEBUG_MODE >= LOW )
    {
      if ( indexNotNull != m_mesh.nv )
      {
        for (int i = indexNotNull; i < m_mesh.nv; i++)
        {
          if ( m_simplifiedMesh.G[i] != null )
          {
            print("Mesh::simplify - simplified mesh has a G with a non-numm entry remaining in the end \n");
          }
        }
      }
    
      for (int i = 0; i < m_simplifiedMesh.nv; i++)
      {
       if ( m_simplifiedMesh.G[i] == null )
       {
         print("Mesh::simplify - simplified mesh has a G with a null entry");
       }
      }
    }

    m_succLODMapperManager.getActiveLODMapper().setBaseToRefinedVMap(m_vertexMappingBaseToMain);
    m_succLODMapperManager.getActiveLODMapper().setBaseToRefinedTMap(m_tMappingSimplifiedTToMeshT);
    m_succLODMapperManager.getActiveLODMapper().setBaseVToRefinedTMap(m_vertexToTriagleMappingBaseToMain);
    print("Num vertices " + m_simplifiedMesh.nv + " Num triangles " + m_simplifiedMesh.nt + "\n");
    return m_simplifiedMesh;
  }
}
