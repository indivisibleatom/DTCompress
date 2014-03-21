class WorkingMeshClient extends Mesh
{
  int[] m_orderV = new int[maxnv]; //The order of the vertex
  int[] m_orderT = new int[maxnt]; //The order of the triangle
  WorkingMesh m_workingMesh;
  int m_baseVerts;
  int m_baseTriangles;


  WorkingMeshClient(Mesh m, WorkingMesh w)
  {
    m.copyTo(this);
    V = m.V;
    O = m.O;
    nv = m.nv;
    nt = m.nt;
    nc = m.nc;
    m_workingMesh = w;
    
    m_baseVerts = nv;
    m_baseTriangles = nt;
    
    m_triangleColorMap = new int[10];
    m_triangleColorMap[0] = green;
    m_triangleColorMap[1] = yellow;
    m_triangleColorMap[2] = red;
  }
  
  private int[] getCornerNumbers( Boolean[] expansionBits, int startPosition, int startCorner )
  {
    int[] cn = new int[3];
    int swingCount = 0;
    int cornerAddedCount = 0;
    int currentCorner = startCorner;
    do
    {
      if ( expansionBits[startPosition+swingCount] )
      {
        cn[cornerAddedCount++] = currentCorner;
      }
      swingCount++;
      currentCorner = s(currentCorner);
    } while( currentCorner != startCorner );
    if ( DEBUG && DEBUG_MODE >= LOW )
    {
      if ( cornerAddedCount != 3 )
      {
        print("WorkingMeshClient::getCornerNumbers returns != 3 as expandable corner count for vertex " + v(startCorner) + "\n");
      }
    }
    return cn;
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
    
    print("Num vertices " + vertices.length);
    while (currentLODStartPositionBits != expansionBits.length)
    {
      int countExpandable = 0;
      int [] cornerForVertex = new int[nv];
      for (int i = 0; i < nv; i++)
      {
         if ( expansionBits[currentLODStartPositionBits+i] )
         {
           countExpandable++;
         }
      }
      
      for (int i = 0; i < nc; i++)
      {
        print("Vertex for corner " + i + " = " + v(i) + "\n");
        cornerForVertex[v(i)] = i;
      }
      
      int currentExpandableCount = 0;
      int offsetIntoSplitBits = 0;
      corners = new int[countExpandable*3];
      for (int i = 0; i < nv; i++)
      {
        if ( expansionBits[currentLODStartPositionBits+i] )
        {
          int[] cn = getCornerNumbers(expansionBits, currentLODStartPositionBits+countExpandable+offsetIntoSplitBits, cornerForVertex[i]);         
          offsetIntoSplitBits += getValence(cornerForVertex[i]);
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
          stitch( result, currentLODWave, orderV, ct );
        }
        else
        {
          m_orderV[i] *= 3;
        }
      }
 
      currentLODStartPositionBits += numVertices + numExpanded*3;
      currentLODStartPositionVert += numExpanded*3;
      currentLODWave--;
    }
  }
  
  void expand(int corner)
  {
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

  void addTriangle( int v1, int v2, int v3, int orderT, int ageT, boolean fCallThisClass )
  {
    addTriangle(v1, v2, v3);
    if ( DEBUG && DEBUG_MODE >= VERBOSE )
    {
      print("Adding triangle with order " + orderT + "\n");
    }
    m_orderT[nt-1] = orderT;
  }
}
