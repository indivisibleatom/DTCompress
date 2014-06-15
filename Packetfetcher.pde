class PacketFetcher
{
  private HashMap<Integer, pt>[] m_GExpansionPacket;
  private BitSet[] m_edgeExpansionPacket; 

  PacketFetcher( String fileName, int numLODs )
  {
    m_edgeExpansionPacket = new BitSet[numLODs];
    m_GExpansionPacket = new HashMap[numLODs];

    FileReader reader;
    try
    {
      for (int i = 0; i < numLODs; i++)
      {
        m_GExpansionPacket[i] = new HashMap<Integer, pt>();
        reader = new FileReader( "C:/Users/Mukul/Desktop/viewer/"+fileName+i+".dat");
        int ch;
        StringBuilder readStringBuilder = new StringBuilder();
        while ( ( ch = reader.read () ) != -1 )
        {
          if ( ch != '\n' )
          {
            readStringBuilder.append( (char)ch );
          }
          else
          {
            String readString = readStringBuilder.toString();
            if ( readString.charAt(0) == 0 || readString.charAt(0) == 1 )
            {
              m_edgeExpansionPacket[i] = new BitSet( readString.length() );
              for (int j = 0; j < readString.length(); j++)
              {
                m_edgeExpansionPacket[i].set( j, readString.charAt(j) == 0? false:true );
              }
            }
            else
            {
              String[] strings = readString.split(" ");
              if ( !strings[1].equals("null") )
              {
                int index = Integer.parseInt( strings[0] );
                pt p = P( Float.parseFloat( strings[1] ), Float.parseFloat( strings[2] ), Float.parseFloat( strings[3] ) );
                m_GExpansionPacket[i].put( index, p );
              }
            }
            readStringBuilder = new StringBuilder();
          }
        }
      }
    }
    catch (Exception ex)
    {
      print("Exception while reading! Packetfetcher " + "C:/Users/Mukul/Desktop/viewer/"+fileName+".dat" + "\n");
    }
  }

  pt getGeometry( int LOD, int index )
  {
    return m_GExpansionPacket[LOD].get(index);
  }
  
  boolean getConnectivity( int LOD, int index )
  {
    return m_edgeExpansionPacket[LOD].get(index);
  }
  
  pt[] fetchGeometry( int lod, int order )
  {
    pt[] result = new pt[3];
    result[0] = getGeometry(lod, 3*order) == null ? null : P(getGeometry(lod, 3*order));
    result[1] = getGeometry(lod, 3*order+1) == null ? null : P(getGeometry(lod, 3*order+1));
    result[2] = getGeometry(lod, 3*order+2) == null ? null : P(getGeometry(lod, 3*order+2));
    return result;
  }

  boolean fetchConnectivity( int lod, int order )
  {
    return getConnectivity(lod, order);
  }
}

