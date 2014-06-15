int NUMLODS = 7;

class SuccLODMapperManager
{
  private SuccLODMapper []m_sucLODMapper = new SuccLODMapper[NUMLODS];
  int m_currentLODLevel = -1;

  public void addLODLevel()
  {
    m_currentLODLevel++;
    m_sucLODMapper[m_currentLODLevel] = new SuccLODMapper();
  }
  
  public boolean fMaxSimplified()
  {
    return (m_currentLODLevel >= NUMLODS - 1);
  }
  
  public SuccLODMapper getActiveLODMapper()
  {
    if ( m_currentLODLevel != -1 )
    {
      return m_sucLODMapper[m_currentLODLevel];
    }
    return null;
  }
  
  public SuccLODMapper getMapperForLOD(int LOD)
  {
    return m_sucLODMapper[LOD];
  }
  
  public SuccLODMapper getLODMapperForBaseMeshNumber(int number)
  {
    if ( m_currentLODLevel != -1 )
    {
      if ( number > 0 )
      {
        return m_sucLODMapper[number - 1];
      }
      else
      {
        return m_sucLODMapper[number];
      }
    }
    return null;
  }
  
  public void propagateNumberings()
  {
    for (int i = NUMLODS-1; i >= 0; i--)
    {
      m_sucLODMapper[i].pushCornerNumberings( ( (i == NUMLODS-1)?null : m_sucLODMapper[i+1]) );
      m_sucLODMapper[i].createGExpansionPacket( ( (i == NUMLODS-1)?null : m_sucLODMapper[i+1]) );
      m_sucLODMapper[i].createTriangleNumberings( ( (i == NUMLODS-1)?null : m_sucLODMapper[i+1]), m_sucLODMapper[NUMLODS-1].getBaseTriangles() );
      print("LOD " + i + "\n");
      
      if ( DEBUG && DEBUG_MODE >= VERBOSE )
      {
        m_sucLODMapper[i].checkNumberings(); //Enable for debug
      }

      m_sucLODMapper[i].createEdgeExpansionPacket( ( (i == NUMLODS-1)?null : m_sucLODMapper[i+1]), m_sucLODMapper[NUMLODS-1].getBaseTriangles() );
    }
  }
  
  void serializeExpansionPackets()
  {
    for (int i = 0; i < NUMLODS; i++)
    {    
      SuccLODMapper mapper = getMapperForLOD(i);
      mapper.serialize("serializedPacket"+i+".dat");
    }
  }
}

class SuccLODMapper
{
  private Mesh m_base;
  private Mesh m_refined;
  private int [][]m_baseToRefinedVMap;
  private int []m_tBaseToRefinedTMap;
  private int []m_tBaseToRefinedTOffsetsNextLevel; //Stores offsets that need to be propagated for next level
  private int [][]m_vBaseToRefinedTMap;

  private int []m_vertexNumberings;  //Mapping from the vertices ordered correctly (3i,3i+1,..) according to the base mesh to the actual vertex numbers in the main mesh > used to transition from one LOD to another.
  private int []m_triangleNumberings;  //Mapping from the triangles ordered correctly (N+4i,4i+1,...) according to the base mesh to the actual triangles numbers in the main mesh > used to transition from one LOD to another.
  private HashMap<Integer, pt> m_GExpansionPacket;
  private BitSet m_edgeExpansionPacket;

  private int[] m_refinedTriangleToOrderedTriangle;
  private int[] m_refinedTriangleToAssociatedVertexNumber;
  SuccLODMapper m_parent;
  
  SuccLODMapper()
  {
  }
  
  public int getBaseTriangles()
  {
    return m_base.nt;
  }

  public void setBaseMesh( Mesh base )
  {
    m_base = base;
  }
  
  pt getGeometry( int index )
  {
    return m_GExpansionPacket.get(index);
  }
  
  boolean getConnectivity( int index )
  {
    return m_edgeExpansionPacket.get(index);
  }
  
  void serialize( String fileName )
  {
    FileWriter writer;
    print("Serializing");
    try
    {
      writer = new FileWriter( fileName );
      
      for (int i = 0; i < m_vertexNumberings.length; i++)
      {
        pt p = getGeometry(i);
        if ( p != null )
        {
          writer.write( i + " " + p.x + " " + p.y + " " + p.z + "\n");
        }
        else
        {
          writer.write( i + " " + "null" + "\n" );
        }
      }
      for (int i = 0; i < m_edgeExpansionPacket.size(); i++)   
      {
        writer.write( m_edgeExpansionPacket.get(i)? 1 : 0 );
      }
    }
    catch ( Exception ex )
    {
      print("There was an exception!!\n");
      return;
    }
  }
  
  void setRefinedMesh( Mesh refined )
  {
    m_refined = refined;
  }
  
  void setBaseToRefinedVMap(int[][] vMap)
  {
    m_baseToRefinedVMap = vMap;
  }
  
  void setBaseToRefinedTMap(int[] tMap)
  {
    m_tBaseToRefinedTMap = tMap;
  }
  
  void setBaseVToRefinedTMap(int[][] vToTMap)
  {
    m_vBaseToRefinedTMap = vToTMap;
  }

  private void printVertexNumberings( int vertex, boolean useParent )
  {
    if ( useParent )
    {
      for (int i = 0; i < m_parent.m_vertexNumberings.length; i++)
      {
        if (vertex == m_parent.m_vertexNumberings[i])
        {
          print(i + " ");
        }
      }
    }
    else
    {
      for (int i = 0; i < m_vertexNumberings.length; i++)
      {
        if (vertex == m_vertexNumberings[i])
        {
          print(i + " ");
        }
      }
    }
  }
  
  private void printTriangleNumberings( int triangle, boolean useParent )
  {
    if ( useParent )
    {
      for (int i = 0; i < m_parent.m_triangleNumberings.length; i++)
      {
        if (triangle == m_parent.m_triangleNumberings[i])
        {
          print(i + " ");
        }
      }
    }
    else
    {
      for (int i = 0; i < m_triangleNumberings.length; i++)
      {
        if (triangle == m_triangleNumberings[i])
        {
          print(i + " ");
        }
      }
    }
  }
    
  void printVertexMapping(int corner, int meshNumber)
  {
    //Treating corner for the base mesh
    if (meshNumber == 0)
    {
      print("Printing vertex mapping for corner " + corner + "\n");
      int vertex = m_base.v(corner);

      print("VertexNumbering for vertex ");
      vertex = m_base.v(corner);
      printVertexNumberings( vertex, true );
      print("\n");
      
      print("TriangleNumbering for triangle ");
      int triangle = m_base.t(corner);
      printTriangleNumberings( triangle, true );
      print("\n");
    }
    else if ( meshNumber != NUMLODS )
    {
      print("Printing vertex mapping for corner " + corner + "\n");
      int vertex = m_base.v(corner);

      print("BaseToRefinedVMap " + corner + " " + vertex + " " + m_baseToRefinedVMap[vertex][0] + " " + m_baseToRefinedVMap[vertex][1] + " " + m_baseToRefinedVMap[vertex][2] + "\n");
      print("BaseToRefinedTMap " + m_tBaseToRefinedTMap[m_base.t(corner)] + " " + m_vBaseToRefinedTMap[vertex][0] + " " + m_vBaseToRefinedTMap[vertex][1] + " " + m_vBaseToRefinedTMap[vertex][2] + " " +  m_vBaseToRefinedTMap[vertex][3] + "\n");

      print("VertexNumbering for vertex ");
      printVertexNumberings( vertex, true );
      print("\n");

      int triangle = m_base.t(corner);
      print("TriangleNumbering for triangle ");
      printTriangleNumberings( triangle, true );
      print("\n");    
    }
    else
    {
      int vertex = m_base.v(corner);
      print("BaseToRefinedVMap " + corner + " " + vertex + " " + m_baseToRefinedVMap[vertex][0] + " " + m_baseToRefinedVMap[vertex][1] + " " + m_baseToRefinedVMap[vertex][2] + "\n");
      print("BaseToRefinedTMap " + m_tBaseToRefinedTMap[m_base.t(corner)] + " " + m_vBaseToRefinedTMap[vertex][0] + " " + m_vBaseToRefinedTMap[vertex][1] + " " + m_vBaseToRefinedTMap[vertex][2] + " " +  m_vBaseToRefinedTMap[vertex][3] + "\n");
    }    
  }

  private int getEdgeOffset( int corner )
  {
    corner %= 3;
    return corner;
    //return m_refined.p(corner);
  }
  
  //Given a base triangle numbering, returns one ordered triangle corresponding to the base triangle
  //Given a base triangle and parent LOD, find out the ordering of the triangle
  private int getOrderedTriangleNumberInBase( SuccLODMapper parent, int baseTriangle )
  {
    if ( parent != null )
    {
      return parent.m_refinedTriangleToOrderedTriangle[baseTriangle];
    }
    else
    {
      return baseTriangle;
    }
  }

  //Given a refined triangle, returns one ordered vertex corresponding to the base vertex that expands to the refined triangle
  private int getOrderedVertexNumberInBase( int refinedTriangle )
  {
    return m_refinedTriangleToAssociatedVertexNumber[ refinedTriangle ];
  }
  
  private int findOrderedTriangle( int triangleRefined )
  {
    for (int i = 0; i < m_triangleNumberings.length; i++)
    {
      if ( m_triangleNumberings[i] == triangleRefined )
      {
        if (m_refinedTriangleToOrderedTriangle[triangleRefined] != i)
        {
          print("SuccLODMapper::findOrderedTriangle - bug in the population of m_refinedTriangleToOrderedTriangle!\n");
        }
        return i;
      }
    }
    return -1;
  }
  
  private void populateRefinedToOrderedTriangles()
  {
    m_refinedTriangleToOrderedTriangle = new int[m_refined.nt];
    for (int i = 0; i < m_refined.nt; i++)
    {
      m_refinedTriangleToOrderedTriangle[i] = -1;
    }

    for (int i = 0; i < m_triangleNumberings.length; i++)
    {
      if ( m_triangleNumberings[i] != -1 && m_refinedTriangleToOrderedTriangle[m_triangleNumberings[i]] == -1 )
      {
        m_refinedTriangleToOrderedTriangle[m_triangleNumberings[i]] = i;
      }
    }
  }

  void createTriangleNumberings(SuccLODMapper parent, int numBaseTriangles)
  {
    m_refinedTriangleToAssociatedVertexNumber = new int[m_refined.nt];
    for (int i = 0; i < m_refinedTriangleToAssociatedVertexNumber.length; i++)
    {
      m_refinedTriangleToAssociatedVertexNumber[i] = -1;
    }

    if ( parent == null )
    {
      int maxTriangleNumber = numBaseTriangles + 4*m_base.nv;
      m_edgeExpansionPacket = new BitSet(3*maxTriangleNumber);
      m_edgeExpansionPacket.clear();
      m_triangleNumberings = new int[maxTriangleNumber];

      for (int i = 0; i < numBaseTriangles; i++)
      {
        m_triangleNumberings[i] = m_tBaseToRefinedTMap[i];
      }
      int offset = numBaseTriangles;
      for (int i = 0; i < m_base.nv; i++)
      {
        for (int j = 0; j < 4; j++)
        {
          if ( m_vBaseToRefinedTMap[i][j] == -1 )
          {
            m_triangleNumberings[offset + 4*i + j] = -1;
          }
          else
          {
            m_triangleNumberings[offset + 4*i + j] = m_vBaseToRefinedTMap[i][j];
            if ( m_refinedTriangleToAssociatedVertexNumber[m_vBaseToRefinedTMap[i][j]] == -1 )
            {
              m_refinedTriangleToAssociatedVertexNumber[m_vBaseToRefinedTMap[i][j]] = offset + 4*i + j;
            }
          }
        }
      }
    }
    else
    {
      int maxTriangleNumber = parent.m_triangleNumberings.length + 4*parent.m_vertexNumberings.length;
      m_edgeExpansionPacket = new BitSet(3*maxTriangleNumber);
      m_edgeExpansionPacket.clear();
      m_triangleNumberings = new int[maxTriangleNumber];

      for (int i = 0; i < parent.m_triangleNumberings.length; i++)
      {
        if ( parent.m_triangleNumberings[i] == -1 )
        {
          m_triangleNumberings[i] = -1;
        }
        else
        {
          m_triangleNumberings[i] = m_tBaseToRefinedTMap[parent.m_triangleNumberings[i]];
        }
      }
      int offset = parent.m_triangleNumberings.length;
      for (int i = 0; i < parent.m_vertexNumberings.length; i++)
      {
        for (int j = 0; j < 4; j++)
        {
          if ( m_vBaseToRefinedTMap[parent.m_vertexNumberings[i]][j] == -1 )
          {
            m_triangleNumberings[offset + 4*i + j] = -1;
          }
          else
          {
            if ( m_refinedTriangleToAssociatedVertexNumber[m_vBaseToRefinedTMap[parent.m_vertexNumberings[i]][j]] == -1 )
            {
              m_refinedTriangleToAssociatedVertexNumber[m_vBaseToRefinedTMap[parent.m_vertexNumberings[i]][j]] = offset + 4*i + j;
            }
            m_triangleNumberings[offset + 4*i + j] = m_vBaseToRefinedTMap[parent.m_vertexNumberings[i]][j];
          }
        }
      }
    }

    populateRefinedToOrderedTriangles();
  }
  
  private int getVertexNumbering(int vertex)
  {
    for (int i = 0; i < m_vertexNumberings.length; i++)
    {
      if ( m_vertexNumberings[i] == vertex )
      {
        return i;
      }
    }
    print("No vertex numbering found for vertex " + vertex + "\n");
    return -1;
  }
  
  //Given a refined triangle number, get the ordering of that triangel
  private int getTriangleNumbering(int triangle)
  {
    for (int i = 0; i < m_triangleNumberings.length; i++)
    {
      if ( m_triangleNumberings[i] == triangle )
      {
        return i;
      }
    }
    print("No triangle numbering found for triangle " + triangle + "\n");
    return -1;
  }
  
  private void checkNumberings()
  {
    for (int i = 0; i < m_refined.nv; i++)
    {
      getVertexNumbering( i );
    }
    for (int i = 0; i < m_refined.nt; i++)
    {
      getTriangleNumbering( i );
    }
  }  

  public void pushCornerNumberings( SuccLODMapper parent )
  {
    if ( parent != null )
    {
      for (int i = 0; i < parent.m_refined.nc; i++)
      {
        m_base.V[i] = parent.m_refined.V[i];
        m_base.O[i] = parent.m_refined.O[i];
      }
      for (int i = 0; i < m_base.nt; i++)
      {
        int refinedTriangle = m_tBaseToRefinedTMap[i];
        int offset = parent.m_refined.m_tOffsets[i];
        int lowestCorner = m_refined.c(refinedTriangle);
        m_base.m_tOffsets[i] = offset;
        m_refined.m_tOffsets[refinedTriangle] = offset;
        fixupTriangleCorners( lowestCorner + offset );
      }
    }
  }
  
  //Offsets the corners in a mesh
  private void changeCorners(int corner, int offset)
  {
    int[] newVMap= new int[3];
    int[] newOMap = new int[3];
    for (int j = 0; j < 3; j++)
    {
      newVMap[j] = m_refined.V[corner+(j+offset)%3];
      newOMap[j] = m_refined.O[corner+(j+offset)%3];
    }
    for (int j = 0; j < 3; j++)
    {
      m_refined.V[corner+j] = newVMap[j];
      m_refined.O[corner+j] = newOMap[j];
      m_refined.O[m_refined.O[corner+j]] = corner+j;
    }
  }
  
  private void fixupTriangleCorners( int offsetCorner )
  {
    int desiredLowestCorner = offsetCorner;
    int currestLowestCorner = m_refined.c(m_refined.t(offsetCorner));
    int offset = offsetCorner % 3;
    if ( offset != 0 )
    {
      changeCorners( currestLowestCorner, offset );
    }
  }  
  
  private void createEdgeExpansionPacket(SuccLODMapper parent, int numBaseTriangles)
  {
    for (int i = 0; i < m_refined.nt; i++)
    {
      if ( m_refined.tm[i] == ISLAND )
      {
        int corner1 = m_refined.c(i);
        int swingCorner1 = m_refined.u(corner1);
        int refTriangle1 = m_refined.t(m_refined.u(swingCorner1));
        int offset1 = getEdgeOffset(m_refined.u(swingCorner1));

        int corner2 = m_refined.n(corner1);
        int swingCorner2 = m_refined.u(corner2);
        int refTriangle2 = m_refined.t(m_refined.u(swingCorner2));
        int offset2 = getEdgeOffset(m_refined.u(swingCorner2));

        int corner3 = m_refined.p(corner1);
        int swingCorner3 = m_refined.u(corner3);
        int refTriangle3 = m_refined.t(m_refined.u(swingCorner3));
        int offset3 = getEdgeOffset(m_refined.u(swingCorner3));
        
        int t1 = getTriangleNumbering(refTriangle1);
        int t2 = getTriangleNumbering(refTriangle2);
        int t3 = getTriangleNumbering(refTriangle3);
        
        m_edgeExpansionPacket.set(3*t1 + offset1, true);
        m_edgeExpansionPacket.set(3*t2 + offset2, true);
        m_edgeExpansionPacket.set(3*t3 + offset3, true);
      }
    }
  }
  
  //Given a base vertex and triangle, return a corner in the refined mesh in the corresponding triangle so that it is incident upon v's expansion and its incident half edge is shared with a channel
  private int findCornerInRefined( int baseV, int baseT )
  {
    int[] vertexInRefined  = m_baseToRefinedVMap[baseV];
    if (vertexInRefined[1] == -1)
      return -1;
    int triangleInRefined = m_tBaseToRefinedTMap[baseT];
    
    int corner = m_refined.c(triangleInRefined);
    for (int i = 0; i < 3; i++)
    {
      int currentCorner = corner;
      do
      {
        if (m_refined.v(currentCorner) == vertexInRefined[i] && m_refined.tm[m_refined.t(m_refined.s(currentCorner))] == CHANNEL && m_refined.tm[m_refined.t(m_refined.s(m_refined.s(currentCorner)))] == ISLAND)
        {
          return currentCorner;
        }
        currentCorner = m_refined.n(currentCorner);
      }while (currentCorner != corner);
    }
    
    if ( DEBUG && DEBUG_MODE >= HIGH )
    {
      print("SuccLODMapper::findCornerInRefined returing -1!!");
    }
    return -1;
  }
   
  void createGExpansionPacket(SuccLODMapper parent)
  {
    m_parent = parent; //TODO msati: Debug hack...remove

    int []vertexNumberings;
    if ( parent == null )
    {
      vertexNumberings = new int[m_base.nv];
      for (int i = 0; i < m_base.nv; i++)
      {
        vertexNumberings[i] = i;
      }
      m_vertexNumberings = new int[3*m_base.nv];
    }
    else
    {
      vertexNumberings = parent.m_vertexNumberings;
      m_vertexNumberings = new int[3*vertexNumberings.length];
    }
    m_GExpansionPacket = new HashMap<Integer, pt>();
    
    //Order the G entries correctly
    int[] minTPerVBase = new int[m_base.nv]; //Stores the min T incident on the base vertices
    int[] cornerRefinedPerVBase = new int[m_base.nv]; //Caches corner in refined for min t
    for (int i = 0; i < m_base.nv; i++)
    {
      minTPerVBase[i] = MAX_INT;
      cornerRefinedPerVBase[i] = -1;
    }
    for (int i = 0; i < m_base.nc; i++)
    {
      int vertexBase = m_base.v(i);
      int tBase = m_base.t(i);
      int orderT = getOrderedTriangleNumberInBase( parent, tBase );
      int corner = findCornerInRefined( vertexBase, tBase );
      if ( corner != -1 ) //If expandable
      {
        if ( orderT < minTPerVBase[vertexBase] )
        {
          minTPerVBase[vertexBase] = orderT;
          cornerRefinedPerVBase[vertexBase] = corner;
        }
      }
    }
        
    for (int i = 0; i < m_base.nv; i++)
    {
      int corner = cornerRefinedPerVBase[i];
      if ( corner != -1 )
      {
        int cornerIsland = m_refined.s(m_refined.s(corner));
        if (DEBUG && DEBUG_MODE >= LOW)
        {
          if (m_refined.tm[m_refined.t(cornerIsland)] != ISLAND)
          {
            print("Something wrong! Not an island on double swing");
          }
        }
        if ( (cornerIsland%3) != 0)
        {
          fixupTriangleCorners( cornerIsland );
          int offset = (cornerIsland%3);
          m_refined.m_tOffsets[m_refined.t(cornerIsland)] = offset;
          int []newVMap = new int[3];
          int []newTMap = new int[3];
          for (int j = 0; j < 3; j++)
          {
            newVMap[j] = m_baseToRefinedVMap[i][(j+offset)%3];
            newTMap[j] = m_vBaseToRefinedTMap[i][1+(j+offset)%3];
          }
          for (int j = 0; j < 3; j++)
          {
            m_baseToRefinedVMap[i][j] = newVMap[j];
            m_vBaseToRefinedTMap[i][j+1] = newTMap[j];
          }
        }
      }
    }
    
    for (int i = 0; i < vertexNumberings.length; i++)
    {
      for (int j = 0; j < 3; j++)
      {
        if (m_baseToRefinedVMap[vertexNumberings[i]][j] == -1)
        {
          m_vertexNumberings[3*i+j] = m_baseToRefinedVMap[vertexNumberings[i]][0];
        }
        else
        {
          m_GExpansionPacket.put(3*i+j, P(m_refined.G[m_baseToRefinedVMap[vertexNumberings[i]][j]]) );
          m_vertexNumberings[3*i+j] = m_baseToRefinedVMap[vertexNumberings[i]][j];
        }
      }
    }
  }
}
