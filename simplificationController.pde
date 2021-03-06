int c_numMeshes = 3;

class SimplificationController
{
 private ViewportManager m_viewportManager;
 private IslandMesh m_islandMesh;
 private Mesh m_baseMesh;
 private WorkingMesh m_workingMesh;
 private SuccLODMapperManager m_lodMapperManager;
 private ArrayList<Mesh> m_displayMeshes;
 int m_minMesh;
 int m_maxMesh;
 
 SimplificationController()
 {
  m_viewportManager = new ViewportManager();
  m_viewportManager.addViewport( new Viewport( 0, 0, width/3, height ) );
  m_viewportManager.addViewport( new Viewport( width/3, 0, width/3, height ) );
  m_viewportManager.addViewport( new Viewport( 2*width/3, 0, width/3, height ) );

  m_displayMeshes = new ArrayList<Mesh>();
  m_islandMesh = new IslandMesh(); 
  m_lodMapperManager = new SuccLODMapperManager();
  m_baseMesh = null;
  m_islandMesh.declareVectors();  
  m_islandMesh.loadMeshVTS("data/new.vts");
  m_islandMesh.updateON(); // computes O table and normals
  m_islandMesh.resetMarkers(); // resets vertex and tirangle markers
  m_islandMesh.computeBox();
  print("Box " + m_islandMesh.Cbox.x + " " + m_islandMesh.Cbox.y + " " + m_islandMesh.Cbox.z + "\n");
  m_minMesh = 0;
  m_maxMesh = -1;
  onMeshAdded(m_islandMesh);
  //m_displayMeshes.add(m_islandMesh);
  //m_viewportManager.registerMeshToViewport( m_islandMesh, 0 );
  for(int i=0; i<20; i++) vis[i]=true; // to show all types of triangles
 }
 
 ViewportManager viewportManager()
 {
   return m_viewportManager;
 }
 
 void onKeyPressed()
 {
   /*if (key=='p')  //Create base mesh and register it to other viewport archival
   {
     if (m_baseMesh != null)
     {
       m_viewportManager.unregisterMeshFromViewport( m_baseMesh, 1 );
     }
     m_baseMesh = m_islandMesh.populateBaseG(); 
     m_islandMesh.numberVerticesOfIslandsAndCreateStream();
     m_islandMesh.connectMesh(); 
     m_baseMesh.computeCForV();
     m_baseMesh.computeBox(); 
     m_viewportManager.registerMeshToViewport( m_baseMesh, 1 );
   }*/
   /*if (key=='p')  //Create base mesh and register it to other viewport archival
   {
     if (m_baseMesh != null)
     {
       m_viewportManager.unregisterMeshFromViewport( m_baseMesh, 1 );
     }
     MeshSimplifier simplifier = new MeshSimplifier( m_islandMesh );
     m_baseMesh = simplifier.simplify(); 
     m_baseMesh.computeCForV();
     m_baseMesh.computeBox(); 
     m_viewportManager.registerMeshToViewport( m_baseMesh, 1 );
   }*/
   //Debugging baseVToVMap
   if (keyPressed&&key=='h')
   {
     print("Size " + m_displayMeshes.size() + "\n");
     int corner = m_displayMeshes.get(m_minMesh + m_viewportManager.getSelectedViewport()).cc;
     print("Selected corner " + corner + "\n");
     m_lodMapperManager.getLODMapperForBaseMeshNumber(m_minMesh + m_viewportManager.getSelectedViewport()).printVertexMapping(corner, m_minMesh + m_viewportManager.getSelectedViewport());
     if ( m_workingMesh != null )
     {
       m_workingMesh.printVerticesSelected();
     }
   }
   else if (key=='p')  //Create base mesh and register it to other viewport archival
   {
     MeshSimplifierEdgeCollapse simplifier = new MeshSimplifierEdgeCollapse( m_islandMesh, m_lodMapperManager );
     m_baseMesh = simplifier.simplify(); 
     
     m_baseMesh.computeBox(); 
     onMeshAdded(m_baseMesh);
     
     if ( m_lodMapperManager.fMaxSimplified() )
     {
       m_lodMapperManager.propagateNumberings();
       m_workingMesh = new WorkingMesh( m_baseMesh, m_lodMapperManager );
       m_workingMesh.resetMarkers();
       m_workingMesh.markTriangleAges();
       m_workingMesh.markExpandableVerts();
       m_workingMesh.computeBox();
       setWorkingMesh();
     }

   }
   else if(key=='l') {IslandMesh m = new IslandMesh();
                 m.declareVectors();
                 m.loadMeshOBJ(); // M.loadMesh(); 
                 m.updateON();   m.resetMarkers();
                 m.computeBox();
                 for(int i=0; i<10; i++) vis[i]=true;
                 changeIslandMesh(m);
                }
   else if(key=='*') {
                 IslandMesh m = new IslandMesh(m_baseMesh);
                 m.resetMarkers();
                 m.computeBox();
                 for(int i=0; i<20; i++) vis[i]=true;
                 changeIslandMesh(m);
                 m_baseMesh = null;
                }
   else if(key=='M') {IslandMesh m = new IslandMesh();
                 m.declareVectors();  
                 m.loadMeshVTS(); 
                 m.updateON();   m.resetMarkers();
                 m.computeBox();
                 for(int i=0; i<10; i++) vis[i]=true;
                 changeIslandMesh(m);
                 }
   //Debugging utilities
   else if (key=='`') 
   {
     CuboidConstructor c = new CuboidConstructor(8, 8, 20, 30);
     c.constructMesh();
     changeIslandMesh(c.getMesh());
   }
   else if (key=='i')
   {
     if (m_baseMesh != null)
     {
       m_viewportManager.unregisterMeshFromViewport( m_baseMesh, 1 );
     }
     m_islandMesh.onBeforeAdvanceOnIslandEdge();
     m_baseMesh = m_islandMesh.populateBaseG(); 
     m_islandMesh.numberVerticesOfIslandsAndCreateStream();
     m_baseMesh.Cbox = m_islandMesh.Cbox;
     m_baseMesh.rbox = m_islandMesh.rbox;
     m_viewportManager.registerMeshToViewport( m_baseMesh, 1 ); 
   }
   else if (key=='I') //Connect base mesh step by step
   {
     if (m_baseMesh != null)
     {
       m_islandMesh.connectMeshStepByStep();
     }
   }
   else
   {
      viewportManager().onKeyPressed(); 
   }
 }
 
 private void onMeshAdded( Mesh mesh )
 {
   m_displayMeshes.add(mesh);
   m_maxMesh++;
   for ( int i = 0; i < m_displayMeshes.size(); i++ )
   {
     m_displayMeshes.get(i).setMeshNumber( i );
   }

   if ( m_maxMesh - m_minMesh >= c_numMeshes )
   {
     for (int i = m_minMesh; i < m_maxMesh; i++)
     {
       print("Move mesh at index " + (i+1) + " to viewport " + (i - m_minMesh) + "\n");
       m_viewportManager.unregisterMeshFromViewport( m_displayMeshes.get(i), i - m_minMesh );
     }
     for (int i = m_minMesh; i < m_maxMesh - 1; i++)
     {
       m_viewportManager.registerMeshToViewport( m_displayMeshes.get(i+1), i - m_minMesh );
     }
     print("Adding mesh at index " + (m_maxMesh) + " at viewport index " + (m_maxMesh - 1 - m_minMesh) + "\n");
     m_viewportManager.registerMeshToViewport( m_displayMeshes.get(m_maxMesh), m_maxMesh - 1 - m_minMesh );
     m_minMesh++;
     m_viewportManager.selectViewport( 1 );
   }
   else
   {
     m_viewportManager.registerMeshToViewport( m_displayMeshes.get(m_maxMesh), m_maxMesh );
     print("Added mesh at viewport index " + (m_maxMesh) + " Min mesh index at start of viewport " + (m_minMesh) + " Mesh list size " + m_displayMeshes.size() + "\n");
   }
 }
 
 private void setWorkingMesh()
 {
   m_viewportManager.unregisterMeshFromViewport( m_displayMeshes.get(m_maxMesh), m_maxMesh - m_minMesh );
   m_displayMeshes.set( m_maxMesh, m_workingMesh );
   m_viewportManager.registerMeshToViewport( m_workingMesh, m_maxMesh - m_minMesh );
 }
 
 private void changeIslandMesh(IslandMesh m)
 {
   print("Changing island mesh\n");
   m_viewportManager.unregisterMeshFromViewport( m_displayMeshes.get(m_maxMesh), m_maxMesh - m_minMesh );
   m_displayMeshes.set( m_maxMesh, m );
   m_islandMesh = m;
   m_viewportManager.registerMeshToViewport( m_displayMeshes.get(m_maxMesh), m_maxMesh - m_minMesh );
 }
}
