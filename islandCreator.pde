int LOD = 0; //TODO msati3: DebugHack
int m_valence2Corner = -1;

class PriorityData
{
  int index;
  int priority;
  
  PriorityData(int in, int p)
  {
    index = in;
    priority = p;
  }
}

public class PriorityDataComparator implements Comparator<PriorityData>
{
    public int compare(PriorityData x, PriorityData y)
    {
        // Assume neither string is null. Real code should
        // probably be more robust
        if (x.priority < y.priority)
        {
            return -1;
        }
        if (x.priority > y.priority)
        {
            return 1;
        }
        return 0;
    }
}

class IslandCreator
{
  private IslandMesh m_mesh;
  private int m_seed; //Seed corner
  
  //Fifo of corners to visit
  LinkedList<Integer> m_cornerFifo;
  boolean[] m_trianglesVisited;
 
  IslandCreator(IslandMesh m, int seed)
  {
    m_mesh = m;
    m_seed = seed;
    m_cornerFifo = new LinkedList<Integer>();
    m_trianglesVisited = new boolean[m_mesh.nt];
  }
  
  private int getValence(int corner)
  {
    int currentCorner = corner;
    int valence = 0;
    do 
    {
      valence++;
      currentCorner = m_mesh.s(currentCorner);
    } while ( currentCorner != corner );
    return valence;
  }
  
  private int getIslandValence(int corner)
  {
    int currentCorner = corner;
    int valence = 0;
    do 
    {
      valence += getValence(currentCorner);
      currentCorner = m_mesh.n(currentCorner);
    } while ( currentCorner != corner );
    return valence;
  }
    
  private int getValenceNonChannel(int corner)
  {
    //Skip the first corner, that will become a non-channel
    int currentCorner = m_mesh.s(corner);
    int valence = 0;
    do 
    {
      if ( m_mesh.tm[ m_mesh.t( currentCorner ) ] != CHANNEL )
      {
        valence++;
      }
      currentCorner = m_mesh.s(currentCorner);
    } while ( currentCorner != corner );
    return valence;
  }

  private void printStats()
  {
    int numIsland = 0;
    int numChannel = 0;
    int numOthers = 0;
    
    //Print information about the valence of each vertex
    for (int i = 0; i < m_mesh.nv; i++)
    {
      m_mesh.vm[i] = 0;
    }

    float averageValence = 0;
    int maxValence = 0;
    int totalValence = 0;
    for (int i = 0; i < m_mesh.nc; i++)
    {
      if (m_mesh.vm[m_mesh.v(i)] == 0)
      {
        m_mesh.vm[m_mesh.v(i)] = 1;
        int valence = getValence(i);
        totalValence += valence;
        if ( valence > maxValence )
        {
          maxValence = valence;
        }
      }
    }
    averageValence = (float)totalValence / m_mesh.nv;
    
    for (int i = 0; i < m_mesh.nv; i++)
    {
      m_mesh.vm[i] = 0;
    }
    int[] valenceBin = new int[maxValence+1];
    for (int i = 0; i < maxValence+1; i++)
    {
      valenceBin[i] = 0;
    }
    for (int i = 0; i < m_mesh.nc; i++)
    {
      if (m_mesh.vm[m_mesh.v(i)] == 0)
      {
        m_mesh.vm[m_mesh.v(i)] = 1;
        int valence = getValence(i);
        valenceBin[valence]++;
      }      
    }
    
    for (int i = 0; i < m_mesh.nt; i++)
    {
      switch (m_mesh.tm[i])
      {
        case 9: 
          numIsland++; 
          break;
        case 3: 
          numChannel++; 
          break;
        default: numOthers++; break;
      }      
    }
    if ( DEBUG && DEBUG_MODE >= LOW )
    {
      if ( m_mesh.nt - numIsland - numChannel != numOthers )
      {
        print("IslandCreator::printStats - Error!! Some other type of triangle exists as well!\n");
      }
    }
    print("Stats num vertices " + m_mesh.nv + " num triangles " + m_mesh.nt + " islands " + numIsland + " channels " + numChannel + " others " + numOthers + " average valence " + averageValence + " max valence " + maxValence + "\n");
    for (int i = 0; i < maxValence+1; i++)
    {
      print("Valence" + i + " " + valenceBin[i] + " " + ((float)valenceBin[i]/m_mesh.nv) * 100 + "\n");
    }
    
    
    /*float[] probability = new float[50];
    for (int i = 0; i < maxValence+1; i++)
    {
      for (int j = 0; j < maxValence+1; j++)
      {
        for (int k = 0; k < maxValence+1; k++)
        {
          if ( i+j+k-9 >= 0 )
          {
            probability[i+j+k-9] += (((float)valenceBin[i]/m_mesh.nv) * ((float)valenceBin[j]/m_mesh.nv) * ((float)valenceBin[k]/m_mesh.nv));
          }
        }
      }
    }
    
    for (int i = 0; i < 50; i++)
    {
      print("Probability " + i + " " + probability[i] + "\n");
    }*/
  }
  
  private int retrySeed()
  {
    return (int)random(m_mesh.nt*3);
  }
  
  private boolean sameVertexIncidentNonChannel( int corner )
  {
    int v2 = m_mesh.v(m_mesh.n(corner));
    int v3 = m_mesh.v(m_mesh.p(corner));

    int currentCorner = corner;
    do
    {
      int v2Cur = m_mesh.v(m_mesh.n(currentCorner));
      int v3Cur = m_mesh.v(m_mesh.p(currentCorner));
      if ((v2 == v2Cur || v2 == v3Cur) || (v3 == v2Cur || v3 == v3Cur))
      {
        if ( currentCorner == corner || currentCorner == m_mesh.s(corner) || currentCorner == m_mesh.u(corner) )
        {
        }
        else
        {
          return true;
        }
      }
      currentCorner = m_mesh.s(currentCorner);
    } while (currentCorner != corner);
    return false;
  }
  
  private boolean validTriangle(int corner)
  {
    int currentCorner = corner;
    int netValence = 0;
    do
    {
      //Should never happen
      if ( sameVertexIncidentNonChannel( corner ) )
      {
        return false;
      }
      
      //No ear collapse of channel to edge
      int opposite = m_mesh.o(currentCorner);
      if ( m_mesh.t(m_mesh.s(opposite)) == m_mesh.t(m_mesh.u(opposite)))
      {
        return false;
      }

      //Valence 3 vertex
      if ( ( m_mesh.v(m_mesh.o(m_mesh.n(currentCorner))) == m_mesh.v(m_mesh.o(m_mesh.p(currentCorner))) ) ||
           ( m_mesh.v(m_mesh.o(currentCorner)) == m_mesh.v(m_mesh.o(m_mesh.p(currentCorner))) ) ||
           ( m_mesh.v(m_mesh.o(currentCorner)) == m_mesh.v(m_mesh.o(m_mesh.n(currentCorner))) ) )
      {
        return false;
      }

      //Valence 3 vertex
      if ( ( m_mesh.t(m_mesh.o(m_mesh.n(currentCorner))) == m_mesh.t(m_mesh.o(m_mesh.p(currentCorner))) ) ||
           ( m_mesh.t(m_mesh.o(currentCorner)) == m_mesh.t(m_mesh.o(m_mesh.p(currentCorner))) ) ||
           ( m_mesh.t(m_mesh.o(currentCorner)) == m_mesh.t(m_mesh.o(m_mesh.n(currentCorner))) ) )
      {
        print("validTriangle : This is occurring valence3Vertex by triangle!!\n");
        return false;
      }

      //Single triangle channels
      if ( ( m_mesh.tm[m_mesh.t(m_mesh.s(m_mesh.s(currentCorner)))] == CHANNEL ) ||
           ( m_mesh.tm[m_mesh.t(m_mesh.u(m_mesh.u(currentCorner)))] == CHANNEL ) )
      {
        return false;
      }

      //Already visited vertex (non-disjoint)
      if ( m_mesh.vm[m_mesh.v(currentCorner)] == 1 )
      {
        return false;
      }
      
      //If cycle exists
      int nonChannel = getValenceNonChannel( m_mesh.n(m_mesh.u(currentCorner)) );
      if ( nonChannel == 2 || nonChannel == 3 )
      {
        return false;
      }

      netValence += nonChannel;
      currentCorner = m_mesh.n(currentCorner);
    } while(currentCorner != corner);
    if ( netValence >= 25 )
    {
      return false;
    }
    return true;
  }
  
  private void visitTriangle(int corner)
  {
    m_mesh.tm[m_mesh.t(corner)] = ISLAND;
    m_mesh.tm[m_mesh.t(m_mesh.o(corner))] = CHANNEL;
    m_mesh.tm[m_mesh.t(m_mesh.o(m_mesh.n(corner)))] = CHANNEL;
    m_mesh.tm[m_mesh.t(m_mesh.o(m_mesh.p(corner)))] = CHANNEL;
    
    m_mesh.vm[m_mesh.v(corner)] = 1;
    m_mesh.vm[m_mesh.v(m_mesh.n(corner))] = 1;
    m_mesh.vm[m_mesh.v(m_mesh.p(corner))] = 1;
  }
  
  private int findNewPossibles(int corner, int []possibles)
  {
    int numPossibles = 0;
    int currentCorner = corner;
    do
    {
      int possibleCornerO = m_mesh.s(m_mesh.s(m_mesh.s(currentCorner)));
      do
      {
        int possibleCorner = m_mesh.o(possibleCornerO);
        if (validTriangle(possibleCorner))
        {
          possibles[numPossibles++] = possibleCorner;
          break;
        }
        possibleCornerO = m_mesh.s(possibleCornerO);
      } while (possibleCornerO != m_mesh.u(currentCorner) );
      currentCorner = m_mesh.n(currentCorner);
    } while(numPossibles == 0 && currentCorner != corner);
    return numPossibles;
  }
   
  private void addPossiblesToFifo(int[] possibles, int numPossibles)
  {
    for (int i = 0; i < numPossibles; i++)
    {
      m_cornerFifo.add(possibles[i]);
    }
  }
  
  private int internalCreateIslandsPass0()
  {
    PriorityQueue<PriorityData> possibleAlternatives = new PriorityQueue<PriorityData>(10, new PriorityDataComparator());
    int numExpandable = 0;
    for (int i = 0; i < m_mesh.nt; i++)
    {
      int valence = getIslandValence(3*i);
      if ( validTriangle(3*i))
      {
        int valence1 = getValence(3*i);
        int valence2 = getValence(3*i+1);
        int valence3 = getValence(3*i+2);
        
        int cost = valence1 <= 4 ? -20 : valence1;
        cost+= valence2 <= 4 ? -20 : valence2;
        cost+= valence3 <= 4 ? -20 : valence3;
        if ( cost < 15 )
        {
          possibleAlternatives.add(new PriorityData(i, cost));
        }
        m_cornerFifo.add(i);
      }
    }
    while (!possibleAlternatives.isEmpty())
    {
      PriorityData data = possibleAlternatives.remove();
      if ( validTriangle(3*data.index) )
      {
        m_trianglesVisited[data.index] = true;
        visitTriangle(3*data.index);
        numExpandable++;
      }
    }

    return numExpandable;
  }
  
  private void resetMarkers()
  {
    for (int i = 0; i < m_mesh.nt; i++)
    {
      if ( !m_trianglesVisited[i] )
      {
        m_mesh.tm[i] = 0;
        m_mesh.cm2[i] = 0;
        m_mesh.vm[m_mesh.v(3*i)] = 0;
        m_mesh.vm[m_mesh.v(3*i+1)] = 0;
        m_mesh.vm[m_mesh.v(3*i+2)] = 0;
      }
    }
  }
 
  private int internalCreateIslandsPass1()
  {
    int[] newPossibles = new int[3];
    int numPossibles;
    Integer corner;
    int numberExpandable = 0;
    while ((corner = m_cornerFifo.poll()) != null)
    {
      if (validTriangle(corner)) //Check for validity at time of processing, as in between time of addition to fifo and processing, this might be changed
      {
        numberExpandable++;
        visitTriangle(corner);
        numPossibles = findNewPossibles(corner, newPossibles);
        addPossiblesToFifo(newPossibles, numPossibles);
      }
    }
    return numberExpandable;
  }
  
  private int internalCreateIslandsPass2()
  {
    int numExpandable = 0;
    for (int i = 0; i < m_mesh.nt; i++)
    {
      if (validTriangle(i*3))
      {
        m_seed = i*3;
        visitTriangle(m_mesh.c(i));
        numExpandable++;
      }
      m_cornerFifo.add(m_seed);
      numExpandable += internalCreateIslandsPass1();
    }
    return numExpandable;
  }
  
  //Offsets the corners in a mesh
  private void changeCorners(int corner, int offset)
  {
    int[] newVMap= new int[3];
    int[] newOMap = new int[3];
    for (int j = 0; j < 3; j++)
    {
      newVMap[j] = m_mesh.V[corner+(j+offset)%3];
      newOMap[j] = m_mesh.O[corner+(j+offset)%3];
    }
    for (int j = 0; j < 3; j++)
    {
      m_mesh.V[corner+j] = newVMap[j];
      m_mesh.O[corner+j] = newOMap[j];
      m_mesh.O[m_mesh.O[corner+j]] = corner+j;
    }
  }
  
  private void fixupChannelCorners( int triangleIsland )
  {
    int currentCorner = m_mesh.c(triangleIsland);
    do
    {
      int channelCorner = m_mesh.u(currentCorner);
      int channelOffset = channelCorner % 3;
      if ( channelOffset != 0 )
      {
        changeCorners( m_mesh.c(m_mesh.t(channelCorner)), channelOffset );
        m_mesh.m_tOffsets[m_mesh.t(channelCorner)] = channelOffset;
      }
      currentCorner = m_mesh.n(currentCorner);
    } while ( currentCorner != m_mesh.c(triangleIsland) );
  }
  
  private boolean hasChannel( int corner )
  {
    int currentCorner = m_mesh.s(m_mesh.s((corner)));
    //count all except the current corner
    while ( currentCorner != m_mesh.u(corner) )
    {
      if ( m_mesh.tm[m_mesh.t(currentCorner)] == CHANNEL )
      {
        return true;
      }
      currentCorner = m_mesh.s(currentCorner);
    }
    return false;
  }
  
  private int countValenceOnCompact( int triangle )
  {
    int countExtraValence = 0;
    int currentCorner = m_mesh.c(triangle);
    do
    {
      if ( !hasChannel( currentCorner ) )
      {
        countExtraValence++;
      }
      currentCorner = m_mesh.n(currentCorner);
    } while (currentCorner != m_mesh.c(triangle));
    m_mesh.cm2[triangle] = countExtraValence;
    return countExtraValence;
  } 
  
  private int computeIslandCosts()
  {
    int count = 0;
    for (int i = 0; i < m_mesh.nt; i++)
    {
      int valence = 0;
      if ( m_mesh.tm[i] == ISLAND )
      {
        count += countValenceOnCompact(i);
      }
    }
    return count;
  }
  
  void createIslands( String strategy )
  {
    if ( strategy == "regionGrow" )
    {
      createIslandsRegionGrow();
    }
    else
    {
      createIslandsHeuristic();
    }
  }
   
  void createIslandsHeuristic()
  {
    print("Here\n");
    LOD++;
    m_mesh.resetMarkers();
  
    int numTries = 0;
    int maxIslandSeed = 0;
    int bestCost = -2147438648;
    int numCreatedInit = internalCreateIslandsPass0();
    int startFifoSize = m_cornerFifo.size();
    int numCreated = numCreatedInit;
    for (int i = 0; i < LOD*100 ; i++)
    {
      int currentFifoSize =  m_cornerFifo.size();
      for (int j = startFifoSize; j < currentFifoSize; j++)
      {
        m_cornerFifo.removeLast();
      }

      numCreated = numCreatedInit;
      resetMarkers();
      m_seed = (int)random(m_mesh.nc);
      m_cornerFifo.add(m_seed);
      numCreated += internalCreateIslandsPass1();
      numCreated += internalCreateIslandsPass2();
      int cost = computeIslandCosts();
      int totalCost = numCreated - 5*cost;
      
      if ( totalCost > bestCost )
      {
        print("Cost " + totalCost + "\n");
        maxIslandSeed = m_seed;
        bestCost = totalCost;
      }
    }
    
    m_mesh.resetMarkers();
    m_cornerFifo.clear();
    numCreated = 0;
    numCreated = internalCreateIslandsPass0();
    m_seed = maxIslandSeed;
    numCreated += internalCreateIslandsPass1();
    m_cornerFifo.add(m_seed);
    numCreated += internalCreateIslandsPass2();
    print("Seed " + maxIslandSeed + " Num created " + numCreated + "\n" );
    
    computeIslandCosts();
    
    if ( DEBUG && DEBUG_MODE >= LOW )
    {
      printStats();
    }

    for (int i = 0; i < m_mesh.nt; i++)
    {
      if ( m_mesh.tm[i] == ISLAND )
      {
        fixupChannelCorners( i );
      }
   }
    
   //Clear all vertex markers
   for (int i = 0; i < m_mesh.nv; i++)
   {
     m_mesh.vm[i] = 0;
   }
   print("Done creating islands \n");
  }
 
  void createIslandsRegionGrow()
  {
    LOD++;
    m_mesh.resetMarkers();
  
    int numTries = 0;
    int maxIslandSeed = 0;
    int bestCost = -2147438648;
    int numCreated = 0;
    for (int i = 0; i < LOD*100 ; i++)
    {
      m_cornerFifo.clear();
      resetMarkers();
      numCreated = 0;
      m_seed = (int)random(m_mesh.nc);
      m_cornerFifo.add(m_seed);
      numCreated += internalCreateIslandsPass1();
      numCreated += internalCreateIslandsPass2();

      int cost = computeIslandCosts();
      int totalCost = numCreated - 5*cost;

      if ( totalCost > bestCost )
      {
        print("Cost " + totalCost + "\n");
        maxIslandSeed = m_seed;
        bestCost = totalCost;
      }
    }
    
    m_mesh.resetMarkers();
    m_cornerFifo.clear();
    numCreated = 0;
    m_seed = maxIslandSeed;
    m_cornerFifo.add(m_seed);
    numCreated += internalCreateIslandsPass1();
    numCreated += internalCreateIslandsPass2();
    print("Seed " + maxIslandSeed + " Num created " + numCreated + "\n" );

    computeIslandCosts();
    
    if ( DEBUG && DEBUG_MODE >= LOW )
    {
      printStats();
    }

    for (int i = 0; i < m_mesh.nt; i++)
    {
      if ( m_mesh.tm[i] == ISLAND )
      {
        fixupChannelCorners( i );
      }
   }
    
   //Clear all vertex markers
   for (int i = 0; i < m_mesh.nv; i++)
   {
     m_mesh.vm[i] = 0;
   }
   print("Done creating islands \n");
 }
}
