// CORNER TABLE FOR TRIANGLE MESHES by Jarek Rosignac
// Last edited October, 2011
// example meshesshowShrunkOffsetT
String [] fn= {
  "HeartReallyReduced.vts", "horse.vts", "bunny.vts", "torus.vts", "flat.vts", "tet.vts", "fandisk.vts", "squirrel.vts", "venus.vts", "mesh.vts", "hole.vts", "gs_dimples_bumps.vts"
};
int fni=0; 
int fniMax=fn.length; // file names for loading meshes
Boolean [] vis = new Boolean [20]; 
Boolean onTriangles=true, onEdges=true; // projection control

class DrawingState
{
  public boolean m_fShowEdges;
  public boolean m_fShowVertices;
  public boolean m_fShowCorners;
  public boolean m_fShowNormals;
  public boolean m_fShowTriangles;
  public boolean m_fTranslucent;
  public boolean m_fSilhoutte;
  public boolean m_fPickingBack;
  public float m_shrunk;

  public DrawingState()
  {
    m_fShowEdges = true;
    m_fShowVertices = false;
    m_fShowCorners = false;
    m_fShowNormals = false;
    m_fShowTriangles = true;
    m_fTranslucent = false;
    m_fSilhoutte = false;
    m_fPickingBack = false;
    m_shrunk = 0;
  }
};

//========================== class MESH ===============================
class Mesh {
  //  ==================================== Internal variables ====================================
  // max sizes, counts, selected corners
  int nv = 0;                              // current  number of vertices
  int nt = 0;                   // current number of triangles
  int nc = 0;                                // current number of corners (3 per triangle)
  int cc=0, pc=0, sc=0;                      // current, previous, saved corners
  float vol=0, surf=0;                      // vol and surface
  int m_meshNumber;

  // primary tables
  int[] V;
  int[] O;
  pt[] G;
  
  // auxiliary tables for bookkeeping
  int[] cm;
  int[] vm;
  int[] tm;
  int[] cm2;

  boolean[] visible;
  boolean[] m_selectedRegion;

  int r=2;                                // radius of spheres for displaying vertices
  Viewport m_viewport;                       // the viewport the mesh is registered to

  // box
  pt Cbox = new pt(width/2, height/2, 0);                   // mini-max box center
  float rbox=1000;                                        // half-diagonal of enclosing box

  // rendering modes
  Boolean flatShading=true;
  DrawingState m_drawingState = new DrawingState();
  protected MeshUserInputHandler m_userInputHandler;

  //wrapper class providing utilities to meshes
  MeshUtils m_utils = new MeshUtils(this);
  int[] m_tOffsets;
  int[] m_triangleColorMap = null; //Control of triangle coloring possible from here
  int[] m_vertexVBO;
  int[] m_edgeVBO;
  int[] m_colorVBO;

  //  ==================================== INIT, CREATE, COPY ====================================
  Mesh() 
  {
    m_userInputHandler = new MeshUserInputHandler(this);
    m_selectedRegion = null;
  }
  
  void initMesh( int vertexCount, int triangleCount, boolean fSubdivide )
  {
    // primary tables
    V = new int [3*triangleCount];               // V table (triangle/vertex indices)
    O = new int [3*triangleCount];               // O table (opposite corner indices)
    G = new pt [vertexCount];                   // geometry table (vertices)

    // auxiliary tables for bookkeeping
    cm = new int[3*triangleCount];               // corner markers: 
    vm = new int[vertexCount];               // vertex markers: 0=not marked, 1=interior, 2=border, 3=non manifold
    tm = new int[triangleCount];               // triangle markers: 0=not marked, 
    cm2 = new int[triangleCount];               // triangle markers: 0=not marked, 

    visible = new boolean[triangleCount];    // set if triangle visible
  }

  void setMeshNumber( int meshNumber )
  {
    m_meshNumber = meshNumber;
  }

  void copyTo(Mesh M) {
    for (int i=0; i<nv; i++) M.G[i]=G[i];
    M.nv=nv;
    for (int i=0; i<nc; i++) M.V[i]=V[i];
    M.nt=nt;
    for (int i=0; i<nc; i++) M.O[i]=O[i];
    M.nc=nc;
    M.resetMarkers();
  }

  void declareVectors() {
    for (int i=0; i<nv; i++) {
      G[i]=P(); 
    };   // init vertices and normals
  }

  void resetCounters() {
    nv=0; 
    nt=0; 
    nc=0;
  }

  void makeGrid (int w) { // make a 2D grid of w x w vertices
    for (int i=0; i<w; i++) {
      for (int j=0; j<w; j++) { 
        G[w*i+j].set(height*.8*j/(w-1)+height/10, height*.8*i/(w-1)+height/10, 0);
      }
    }    
    for (int i=0; i<w-1; i++) {
      for (int j=0; j<w-1; j++) {                  // define the triangles for the grid
        V[(i*(w-1)+j)*6]=i*w+j;       
        V[(i*(w-1)+j)*6+2]=(i+1)*w+j;       
        V[(i*(w-1)+j)*6+1]=(i+1)*w+j+1;
        V[(i*(w-1)+j)*6+3]=i*w+j;     
        V[(i*(w-1)+j)*6+5]=(i+1)*w+j+1;     
        V[(i*(w-1)+j)*6+4]=i*w+j+1;
      };
    };
    nv = w*w;
    nt = 2*(w-1)*(w-1); 
    nc=3*nt;
  }

  void resetMarkers() { // reset the seed and current corner and the markers for corners, triangles, and vertices
    cc=0; 
    pc=0; 
    sc=0;
    for (int i=0; i<nv; i++) vm[i]=0;
    for (int i=0; i<nc; i++) cm[i]=0;
    for (int i=0; i<nt; i++){ tm[i]=0; cm2[i] = 0;}
    for (int i=0; i<nt; i++) visible[i]=true;
  }

  int addVertex(pt P) { 
    G[nv] = new pt(); 
    G[nv].set(P); 
    nv++; 
    return nv-1;
  };
  int addVertex(float x, float y, float z) { 
    G[nv] = new pt(); 
    G[nv].x=x; 
    G[nv].y=y; 
    G[nv].z=z; 
    nv++; 
    return nv-1;
  };

  void addTriangle(int i, int j, int k) {
    V[nc++]=i; 
    V[nc++]=j; 
    V[nc++]=k; 
    visible[nt++]=true; /*print("Triangle added " + nt + " " + i + " " + j + " " + k + "\n");*/
  } // adds a triangle
  void addTriangle(int i, int j, int k, int m) {
    V[nc++]=i; 
    V[nc++]=j; 
    V[nc++]=k; 
    tm[nt]=m; 
    visible[nt++]=true;
  } // adds a triangle

    void updateON() {
    computeO(); 
    normals();
    //printStats();
  } // recomputes O and normals

    // ============================================= CORNER OPERATORS =======================================
  // operations on a corner
  int t (int c) {
    return int(c/3);
  };              // triangle of corner    
  int n (int c) {
    return 3*t(c)+(c+1)%3;
  };        // next corner in the same t(c)    
  int p (int c) {
    return n(n(c));
  };               // previous corner in the same t(c)  
  int v (int c) {
    return V[c] ;
  };                 // id of the vertex of c             
  int o (int c) {
    return O[c];
  };                  // opposite (or self if it has no opposite)
  int l (int c) {
    return o(n(c));
  };               // left neighbor (or next if n(c) has no opposite)                      
  int r (int c) {
    return o(p(c));
  };               // right neighbor (or previous if p(c) has no opposite)                    
  int s (int c) {
    return n(l(c));
  };               // swings around v(c) or around a border loop
  int u (int c) {
    return p(r(c));
  };               // unswings around v(c) or around a border loop
  int c (int t) {
    return t*3;
  }                    // first corner of triangle t
  boolean b (int c) {
    return O[c]==c;
  };           // if faces a border (has no opposite)
  boolean vis(int c) {
    return visible[t(c)];
  };   // true if tiangle of c is visible
  boolean hasValidR(int c) { 
    return r(c) != p(c);
  } //true for meshes with border if not returning previous (has actual R)
  boolean hasValidL(int c) { 
    return l(c) != n(c);
  } //true for meshes with borher if not returning next (has actual L)

  /*int cForV(int v) { 
    if (CForV[v] == -1) 
    {
      if ( DEBUG && DEBUG_MODE >= LOW )
      {
        print("Fatal error! The corner for the vertex is -1");
      }
    } 
    return CForV[v];
  }*/

  // operations on the selected corner cc
  int t() {
    return t(cc);
  }
  int n() {
    return n(cc);
  }        
  Mesh next() {
    pc=cc; 
    cc=n(cc); 
    return this;
  };
  int p() {
    return p(cc);
  }        
  Mesh previous() {
    pc=cc; 
    cc=p(cc); 
    return this;
  };
  int v() {
    return v(cc);
  }
  int o() {
    return o(cc);
  }        
  Mesh back() {
    if (!b(cc)) {
      pc=cc; 
      cc=o(cc);
    }; 
    return this;
  };
  boolean b() {
    return b(cc);
  }             
  int l() {
    return l(cc);
  }         
  Mesh left() {
    next(); 
    back(); 
    return this;
  }; 
  int r() {
    return r(cc);
  }         
  Mesh right() {
    previous(); 
    back(); 
    return this;
  };
  int s() {
    return s(cc);
  }         
  Mesh swing() {
    left(); 
    next();  
    return this;
  };
  int u() {
    return u(cc);
  }         
  Mesh unswing() {
    right(); 
    previous();  
    return this;
  };

  // geometry for corner c
  pt g (int c) {
    return G[v(c)];
  };                // shortcut to get the point of the vertex v(c) of corner c
  pt cg(int c) {
    pt cPt = P(g(c), .3, triCenter(t(c)));  
    return(cPt);
  };   // computes point at corner
  pt corner(int c) {
    return P(g(c), triCenter(t(c)));
  };   // returns corner point

  // geometry for corner cc
  pt g() {
    return g(cc);
  }            // shortcut to get the point of the vertex v(c) of corner c
  pt gp() {
    return g(p(cc));
  }            // shortcut to get the point of the vertex v(c) of corner c
  pt gn() {
    return g(n(cc));
  }            // shortcut to get the point of the vertex v(c) of corner c
  void setG(pt P) {
    G[v(cc)].set(P);
  } // moves vertex of c to P

    // debugging prints
  void writeCorner (int c) {
    println("cc="+cc+", n="+n(cc)+", p="+p(cc)+", o="+o(cc)+", v="+v(cc)+", t="+t(cc)+"."+", nt="+nt+", nv="+nv );
  }; 
  void writeCorner () {
    writeCorner (cc);
  }
  void writeCorners () {
    for (int c=0; c<nc; c++) {
      println("T["+c+"]="+t(c)+", visible="+visible[t(c)]+", v="+v(c)+",  o="+o(c));
    };
  }

  // ============================================= MESH MANIPULATION =======================================
  // pick corner closest to point X
  void pickcOfClosestVertex (pt X) {
    for (int b=0; b<nc; b++) if (vis[tm[t(b)]]) if (d(X, g(b))<d(X, g(cc))) {
      cc=b; 
      pc=b;
    }
  } // picks corner of closest vertex to X
  void pickc (pt X) {
    int origCC = cc;
    for (int b=0; b<nc; b++) if (V[b] != -1 && vis[tm[t(b)]] && visible[t(b)]) if (d(X, cg(b))<d(X, cg(cc)) ) {
      cc=b; 
      pc=b;
    }
    if ( origCC != cc && DEBUG && DEBUG_MODE >= LOW ) { 
      print("Corner picked :" + cc + " vertex :" + v(cc) + "\n");
    }
  } // picks closest corner to X
  void picksOfClosestVertex (pt X) {
    for (int b=0; b<nc; b++) if (vis[tm[t(b)]]) if (d(X, g(b))<d(X, g(sc))) {
      sc=b;
    }
  } // picks corner of closest vertex to X
  void picks (pt X) {
    for (int b=0; b<nc; b++)  if (vis[tm[t(b)]]) if (d(X, cg(b))<d(X, cg(sc))) {
      sc=b;
    }
  } // picks closest corner to X

  // move the vertex of a corner
  void setG(int c, pt P) {
    G[v(c)].set(P);
  }       // moves vertex of c to P
  Mesh add(int c, vec V) {
    G[v(c)].add(V); 
    return this;
  }             // moves vertex of c to P
  Mesh add(int c, float s, vec V) {
    G[v(c)].add(s, V); 
    return this;
  }   // moves vertex of c to P
  Mesh add(vec V) {
    G[v(cc)].add(V); 
    return this;
  } // moves vertex of c to P
  Mesh add(float s, vec V) {
    G[v(cc)].add(s, V); 
    return this;
  } // moves vertex of c to P
  
  void hide() {
    visible[t(cc)]=false; 
    if (!b(cc) && visible[t(o(cc))]) cc=o(cc); 
    else {
      cc=n(cc); 
      if (!b(cc) && visible[t(o(cc))]) cc=o(cc); 
      else {
        cc=n(cc); 
        if (!b(cc) && visible[t(o(cc))]) cc=o(cc);
      };
    };
  }
    // ============================================= GEOMETRY =======================================

  // enclosing box
  void computeBox() { // computes center Cbox and half-diagonal Rbox of minimax box
    pt Lbox =  P(G[0]);  
    pt Hbox =  P(G[0]);
    for (int i=1; i<nv; i++) { 
      Lbox.x=min(Lbox.x, G[i].x); 
      Lbox.y=min(Lbox.y, G[i].y); 
      Lbox.z=min(Lbox.z, G[i].z);
      Hbox.x=max(Hbox.x, G[i].x); 
      Hbox.y=max(Hbox.y, G[i].y); 
      Hbox.z=max(Hbox.z, G[i].z);
    };
    Cbox.set(P(Lbox, Hbox));  
    rbox=d(Cbox, Hbox);
  };

  // ============================================= O TABLE CONSTRUCTION =========================================
  void computeOnaive() {                        // sets the O table from the V table, assumes consistent orientation of triangles
    resetCounters();
    for (int i=0; i<3*nt; i++) {
      O[i]=i;
    };  // init O table to -1: has no opposite (i.e. is a border corner)
    for (int i=0; i<nc; i++) {  
      for (int j=i+1; j<nc; j++) {       // for each corner i, for each other corner j
        if ( (v(n(i))==v(p(j))) && (v(p(i))==v(n(j))) ) {
          O[i]=j; 
          O[j]=i;
        };
      };
    };
  }// make i and j opposite if they match         

  void computeO() {
    int val[] = new int [nv]; 
    for (int v=0; v<nv; v++) val[v]=0;  
    for (int c=0; c<nc; c++)
    {
      val[v(c)]++;   //  valences
    }
    int fic[] = new int [nv]; 
    int rfic=0; 
    for (int v=0; v<nv; v++) {
      fic[v]=rfic; 
      rfic+=val[v];
    };  // head of list of incident corners
    for (int v=0; v<nv; v++) val[v]=0;   // valences wil be reused to track how many incident corners were encountered for each vertex
    int [] C = new int [nc]; 
    for (int c=0; c<nc; c++) C[fic[v(c)]+val[v(c)]++]=c;  // vor each vertex: the list of val[v] incident corners starts at C[fic[v]]
    for (int c=0; c<nc; c++) O[c]=c;    // init O table to -1 meaning that a corner has no opposite (i.e. faces a border)
    for (int v=0; v<nv; v++)             // for each vertex...
      for (int a=fic[v]; a<fic[v]+val[v]-1; a++) for (int b=a+1; b<fic[v]+val[v]; b++) { // for each pair (C[a],C[b[]) of its incident corners
        if (v(n(C[a]))==v(p(C[b]))) {
          O[p(C[a])]=n(C[b]); 
          O[n(C[b])]=p(C[a]);
        }; // if C[a] follows C[b] around v, then p(C[a]) and n(C[b]) are opposite
        if (v(n(C[b]))==v(p(C[a]))) {
          O[p(C[b])]=n(C[a]); 
          O[n(C[a])]=p(C[b]);
        };
      };
  }
  void computeOvis() { // computees O for the visible triangles
    //   resetMarkers(); 
    int val[] = new int [nv]; 
    for (int v=0; v<nv; v++) val[v]=0;  
    for (int c=0; c<nc; c++) if (visible[t(c)]) val[v(c)]++;   //  valences
    int fic[] = new int [nv]; 
    int rfic=0; 
    for (int v=0; v<nv; v++) {
      fic[v]=rfic; 
      rfic+=val[v];
    };  // head of list of incident corners
    for (int v=0; v<nv; v++) val[v]=0;   // valences wil be reused to track how many incident corners were en`ered for each vertex
    int [] C = new int [nc]; 
    for (int c=0; c<nc; c++) if (visible[t(c)]) C[fic[v(c)]+val[v(c)]++]=c;  // for each vertex: the list of val[v] incident corners starts at C[fic[v]]
    for (int c=0; c<nc; c++) O[c]=c;    // init O table to -1 meaning that a corner has no opposite (i.e. faces a border)
    for (int v=0; v<nv; v++)             // for each vertex...
      for (int a=fic[v]; a<fic[v]+val[v]-1; a++) for (int b=a+1; b<fic[v]+val[v]; b++) { // for each pair (C[a],C[b[]) of its incident corners
        if (v(n(C[a]))==v(p(C[b]))) {
          O[p(C[a])]=n(C[b]); 
          O[n(C[b])]=p(C[a]);
        }; // if C[a] follows C[b] around v, then p(C[a]) and n(C[b]) are opposite
        if (v(n(C[b]))==v(p(C[a]))) {
          O[p(C[b])]=n(C[a]); 
          O[n(C[a])]=p(C[b]);
        };
      };
  }
  
  public int getValence(int corner)
  {
    int currentCorner = corner;
    int valence = 0;
    do 
    {
      valence++;
      currentCorner = s(currentCorner);
    } while ( currentCorner != corner );
    return valence;
  }

  public int getValenceBounded(int corner)
  {
    int currentCorner = corner;
    int valence = 0;
    do 
    {
      valence++;
      currentCorner = s(currentCorner);
    } while ( currentCorner != corner && valence < 100 );
    return valence;
  }

  void updateColorsVBO(int opacity)
  {
    ByteBuffer col = ByteBuffer.allocate( 4 * nc );
    color c = 0;
    for (int i = 0; i < nc; i++)
    {
      int t = t(i);
      if (m_triangleColorMap != null)
      {
        c = m_triangleColorMap[tm[t]];
      }
      else
      {
        if (tm[t]==0) c = formColor(cyan, opacity); 
        if (tm[t]==1) c = formColor(brown, opacity); 
        if (tm[t]==2) c = formColor(orange, opacity); 
        if (tm[t]==3) c = formColor(cyan, opacity); 
        if (tm[t]==4) c = formColor(magenta, opacity); 
        if (tm[t]==5) c = formColor(green, opacity); 
        if (tm[t]==6) c = formColor(blue, opacity); 
        if (tm[t]==7) c = formColor(#FAAFBA, opacity); 
        if (tm[t]==8) c = formColor(blue, opacity); 
        if (tm[t]==9)
        {
          if (cm2[t] == 0)
          {
            c = formColor(yellow, opacity); 
          }
          else if (cm2[t] == 1)
          {
            c = formColor(blue, opacity); 
          }
          else if (cm2[t] == 2)
          {
            c = formColor(magenta, opacity);
          }
          else
          {
            c = formColor(brown, opacity);
          }
        }
        
        
        if (tm[t]==10) c = formColor(cyan, opacity); 
        if (tm[t]==11) c = formColor(brown, opacity); 
        if (tm[t]==12) c = formColor(orange, opacity); 
        if (tm[t]==13) c = formColor(cyan, opacity); 
        if (tm[t]==14) c = formColor(magenta, opacity); 
        if (tm[t]==15) c = formColor(green, opacity); 
        if (tm[t]==16) c = formColor(blue, opacity); 
        if (tm[t]==17) c = formColor(#FAAFBA, opacity); 
        if (tm[t]==18) c = formColor(blue, opacity); 
        if (tm[t]==19) c = formColor(yellow, opacity); 
      }
      col.put((byte)(c >> 16 & 0xFF));
      col.put((byte)(c >> 8 & 0xFF));
      col.put((byte)(c & 0xFF));
      col.put((byte)alpha(c));
    }
    col.rewind();

    pgl.beginGL();
    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, m_colorVBO[0] );
    gl.glBufferData( GL.GL_ARRAY_BUFFER, 4 * 4 * nc, col, GL.GL_DYNAMIC_DRAW );
  
    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, 0 );
  
    pgl.endGL();
  } 

  // ============================================= DISPLAY CORNERS and LABELS =============================
  void showCorners()
  {
    noStroke();
    for (int i = 0; i < 3*nt; i++)
    {
      if (cm[i] == 1)
      {
        fill(yellow);
        showCorner(i, 5);
      }
      else if (cm[i] == 2)
      {
        fill(red);
        showCorner(i, 5);
      }
      else
      {
        //fill(orange);
        //showCorner(i, 3);
      }
    }
  }

  void showCorner(int c, float r) {
    if (m_drawingState.m_fShowCorners) {
      show(cg(c), r);
    }
  };   // renders corner c as small ball

  void showcc() {
    noStroke(); 
    fill(blue); 
    showCorner(sc, 3); /* fill(green); showCorner(pc,5); */
    fill(dred); 
    showCorner(cc, 3);
  } // displays corner markers

  // ============================================= DISPLAY VERTICES =======================================
  void showVertices() {
    noStroke(); 
    noSmooth(); 
    for (int v=0; v<nv; v++) 
    {
      if ( m_selectedRegion != null )
      {
        if ( m_selectedRegion[v] )
        {
          fill(red, 150);
          show(G[v], 5);
        }
        else
        {
          fill(blue, 150);
          show(G[v], 5);
        }
      }
      else
      {
        //if (vm[v]==0) fill(brown,150);
        if (vm[v]==0) fill(green, 150);
        if (vm[v]==1) fill(red, 150);
        show(G[v], 5);  
        if (vm[v]==2)
        {
          fill(green, 150);
          show(G[v], 5);
        }
        if (vm[v]==3)
        {
          fill(blue, 150);
          show(G[v], 5);
        }
        if (vm[v]==5)
        {
          fill(red, 150);
          show(G[v], 5);
        }
      }
    }
    noFill();
  }

  void showVertices(int col, int radius) 
  {
    noStroke(); 
    noSmooth(); 
    for (int v=0; v<nv; v++)
    {
      fill(col);
      show(G[v], radius);
    }
    noFill();
  }

  // ============================================= DISPLAY EDGES =======================================
  void showBorder() {
    for (int c=0; c<nc; c++) {
      if (b(c) && visible[t(c)]) {
        drawEdge(c);
      };
    };
  }; // draws all border edges

  void showEdges () {
    drawVBOEdge();
  };
  
  void drawEdge(int c) {
    //show(g(p(c)), g(n(c)));
  };  // draws edge of t(c) opposite to corner c
  
  void drawSilhouettes() {
    for (int c=0; c<nc; c++) if (c<o(c) && frontFacing(t(c))!=frontFacing(t(o(c)))) drawEdge(c);
  }  

  // ============================================= DISPLAY TRIANGLES =======================================
  // displays triangle if marked as visible using flat or smooth shading (depending on flatShading variable
  void shade(int t) { // displays triangle t if visible
    if (visible[t])  
      if (flatShading) {
        beginShape(); 
        vertex(g(3*t)); 
        vertex(g(3*t+1)); 
        vertex(g(3*t+2));  
        endShape(CLOSE);
      }      
  }
  
  // display shrunken and offset triangles
  void showShrunkT(int t, float e) {
    if (visible[t]) showShrunk(g(3*t), g(3*t+1), g(3*t+2), e);
  }
  void showSOT(int t) {
    if (visible[t]) showShrunkOffsetT(t, 1, 1);
  }
  void showSOT() {
    if (visible[t(cc)]) showShrunkOffsetT(t(cc), 1, 1);
  }
  void showShrunkOffsetT(int t, float e, float h) {
    if (visible[t]) showShrunkOffset(g(3*t), g(3*t+1), g(3*t+2), e, h);
  }
  void showShrunkT() {
    int t=t(cc); 
    if (visible[t]) showShrunk(g(3*t), g(3*t+1), g(3*t+2), 2);
  }
  void showShrunkOffsetT(float h) {
    int t=t(cc); 
    if (visible[t]) showShrunkOffset(g(3*t), g(3*t+1), g(3*t+2), 2, h);
  }

  // display front and back triangles shrunken if showEdges  
  Boolean frontFacing(int t) {
    return !cw(m_viewport.getE(), g(3*t), g(3*t+1), g(3*t+2));
  } 
  void showFrontTrianglesSimple() {
    for (int t=0; t<nt; t++) if (frontFacing(t)) {
      if (m_drawingState.m_fShowEdges) showShrunkT(t, 1); 
      else shade(t);
    }
  };  

  void showFrontTriangles() {
    for (int t=0; t<nt; t++) if (frontFacing(t)) {
      if (!visible[t]) continue;
      //      if(tm[t]==1) continue;
      if (tm[t]==0) fill(cyan, 155); 
      if (tm[t]==1) fill(green, 150); 
      if (tm[t]==2) fill(red, 150); 
      if (tm[t]==3) fill(blue, 150); 
      if (m_drawingState.m_fShowEdges) showShrunkT(t, 1); 
      else shade(t);
    }
  } 

  private void showTestTriangle()
  {
   pgl.beginGL();
   gl.glBegin(GL.GL_TRIANGLES);
     gl.glVertex3f( 0, 0, 1 );
     gl.glVertex3f( 100, 0, 1 );
     gl.glVertex3f( 50, 50, 1 );
   gl.glEnd();
   pgl.endGL();
  }
 
   void drawVBOEdge()
  { 
    pgl.beginGL();
    gl.glColor3f(0,0,0);

    gl.glEnableClientState( GL.GL_VERTEX_ARRAY );

    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, m_edgeVBO[0] );
    gl.glVertexPointer(3, GL.GL_FLOAT, 0, 0);

    gl.glDrawArrays( GL.GL_LINES, 0, 6 * nc );

    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, 0);
    gl.glDisableClientState(GL.GL_VERTEX_ARRAY);
    pgl.endGL();
  }
  
  void drawVBO()
  { 
    pgl.beginGL();

    gl.glEnableClientState( GL.GL_VERTEX_ARRAY );
    gl.glEnableClientState(GL.GL_COLOR_ARRAY);

    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, m_vertexVBO[0] );
    gl.glVertexPointer(3, GL.GL_FLOAT, 0, 0);

    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, m_colorVBO[0] );
    gl.glColorPointer( 4, GL.GL_UNSIGNED_BYTE, 0, 0);

    gl.glDrawArrays( GL.GL_TRIANGLES, 0, 3 * nc );

    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, 0);
    gl.glDisableClientState(GL.GL_VERTEX_ARRAY);
    gl.glDisableClientState(GL.GL_COLOR_ARRAY);
    pgl.endGL();
  }
  
  void showTriangles(Boolean front, int opacity, float shrunk)
  {
    drawVBO();
  }

  void showBackTriangles() {
    /*for (int t=0; t<nt; t++) if (!frontFacing(t)) shade(t);*/
  };  
  
  void showMarkedTriangles() {
    for (int t=0; t<nt; t++) 
    {
      if (visible[t]) 
      {
        showShrunkOffsetT(t, 1, 1);
      }
    }
  };

  // ********************************************************* DRAW *****************************************************
  void draw()
  {
    if ( m_valence2Corner != -1 )
    {
      showCorner(m_valence2Corner, 10);
    }
    
    {
      noStroke();
      if (m_drawingState.m_fPickingBack)
      {
        noStroke(); 
        if (m_drawingState.m_fTranslucent)  
        {
          showTriangles(false, 100, m_drawingState.m_shrunk);
        }
        else 
        {
          showBackTriangles();
        }
      }
      else if (m_drawingState.m_fTranslucent)
      {
        if (m_drawingState.m_fShowTriangles)
        {
          fill(grey, 80); 
          noStroke(); 
          showBackTriangles();  
          showTriangles(true, 150, m_drawingState.m_shrunk);
        }
      }
      else if (m_drawingState.m_fShowTriangles)
      {
        showTriangles(true, 255, m_drawingState.m_shrunk);
      }
      if (m_drawingState.m_fShowVertices)
      {
        showVertices();
      }
      if (m_drawingState.m_fShowCorners)
      {
        showCorners();
      }
      if (m_drawingState.m_fShowNormals)
      {
        //showNormals();
      }
      if (m_drawingState.m_fShowEdges)
      {
        stroke(black); 
        showEdges();
      }
    }
  }

  void drawPostPicking()
  {       
    // -------------------------------------------------------- display picked points and triangles ----------------------------------   
    fill(163, 73, 164); 
    {
      showSOT(); // shoes triangle t(cc) shrunken
      showcc();  // display corner markers: seed sc (green),  current cc (red)

    // -------------------------------------------------------- display FRONT if we were picking on the back ---------------------------------- 
      if (getDrawingState().m_fPickingBack) 
      {
        if (getDrawingState().m_fTranslucent) {
          fill(cyan, 150); 
          if (getDrawingState().m_fShowEdges) stroke(orange); 
          else noStroke(); 
          showTriangles(true, 100, m_drawingState.m_shrunk);
        } 
        else {
          fill(cyan); 
          if (getDrawingState().m_fShowEdges) stroke(orange); 
          else noStroke(); 
          showTriangles(true, 255, m_drawingState.m_shrunk);
        }
      }
  
      // -------------------------------------------------------- Disable z-buffer to display occluded silhouettes and other things ---------------------------------- 
      hint(DISABLE_DEPTH_TEST);  // show on top
      if (getDrawingState().m_fSilhoutte) {
        stroke(dbrown); 
        drawSilhouettes();
      }  // display silhouettes
    }
  }

  DrawingState getDrawingState()
  {
    return m_drawingState;
  }

  //  ==========================================================  PROCESS EDGES ===========================================
  // FLIP 
  void flip(int c) {      // flip edge opposite to corner c, FIX border cases
    if (b(c)) return;
    V[n(o(c))]=v(c); 
    V[n(c)]=v(o(c));
    int co=o(c); 

    O[co]=r(c); 
    if (!b(p(c))) O[r(c)]=co; 
    if (!b(p(co))) O[c]=r(co); 
    if (!b(p(co))) O[r(co)]=c; 
    O[p(c)]=p(co); 
    O[p(co)]=p(c);
  }
  void flip() {
    flip(cc); 
    pc=cc; 
    cc=p(cc);
  }

  void flipWhenLonger() {
    for (int c=0; c<nc; c++) if (d(g(n(c)), g(p(c)))>d(g(c), g(o(c)))) flip(c);
  } 

  int cornerOfShortestEdge() {  // assumes manifold
    float md=d(g(p(0)), g(n(0))); 
    int ma=0;
    for (int a=1; a<nc; a++) if (vis(a)&&(d(g(p(a)), g(n(a)))<md)) {
      ma=a; 
      md=d(g(p(a)), g(n(a)));
    }; 
    return ma;
  } 
  void findShortestEdge() {
    cc=cornerOfShortestEdge();
  } 

  //  ========================================================== PROCESS  TRIANGLES ===========================================
  pt triCenter(int i) {
    return P( G[V[3*i]], G[V[3*i+1]], G[V[3*i+2]] );
  };  
  pt triCenter() {
    return triCenter(t());
  }  // computes center of triangle t(i) 
  void writeTri (int i) {
    println("T"+i+": V = ("+V[3*i]+":"+v(o(3*i))+","+V[3*i+1]+":"+v(o(3*i+1))+","+V[3*i+2]+":"+v(o(3*i+2))+")");
  };



  //  ==========================================================  NORMALS ===========================================
  void normals() {
  }

  //  ==========================================================  VOLUME ===========================================
  float volume() {
    float v=0; 
    for (int i=0; i<nt; i++) v+=triVol(i); 
    vol=v/6; 
    return vol;
  }
  float volume(int m) {
    float v=0; 
    for (int i=0; i<nt; i++) if (tm[i]==m) v+=triVol(i); 
    return v/6;
  }
  float triVol(int t) { 
    return m(P(), g(3*t), g(3*t+1), g(3*t+2));
  };  

  float surface() {
    float s=0; 
    for (int i=0; i<nt; i++) s+=triSurf(i); 
    surf=s; 
    return surf;
  }
  float surface(int m) {
    float s=0; 
    for (int i=0; i<nt; i++) if (tm[i]==m) s+=triSurf(i); 
    return s;
  }
  float triSurf(int t) { 
    if (visible[t]) return area(g(3*t), g(3*t+1), g(3*t+2)); 
    else return 0;
  };  

  //  ========================================================== FILL HOLES ===========================================
  void fanHoles() {
    for (int cc=0; cc<nc; cc++) if (visible[t(cc)]&&b(cc)) fanThisHole(cc); 
    normals();
  }
  void fanThisHole() {
    fanThisHole(cc);
  }
  void fanThisHole(int cc) {   // fill hole with triangle fan (around average of parallelogram predictors). Must then call computeO to restore O table
    if (!b(cc)) return ; // stop if cc is not facing a border
    G[nv].set(0, 0, 0);   // tip vertex of fan
    int o=0;              // tip corner of new fan triangle
    int n=0;              // triangle count in fan
    int a=n(cc);          // corner running along the border
    while (n (a)!=cc) {    // walk around the border loop 
      if (b(p(a))) {       // when a is at the left-end of a border edge
        G[nv].add( P(P(g(a), g(n(a))), P(g(a), V(g(p(a)), g(n(a))))) ); // add parallelogram prediction and mid-edge point
        o=3*nt; 
        V[o]=nv; 
        V[n(o)]=v(n(a)); 
        V[p(o)]=v(a); 
        visible[nt]=true; 
        nt++; // add triangle to V table, make it visible
        O[o]=p(a); 
        O[p(a)]=o;        // link opposites for tip corner
        O[n(o)]=-1; 
        O[p(o)]=-1;
        n++;
      }; // increase triangle-count in fan
      a=s(a);
    } // next corner along border
    G[nv].mul(1./n); // divide fan tip to make it the average of all predictions
    a=o(cc);       // reset a to walk around the fan again and set up O
    int l=n(a);   // keep track of previous
    int i=0; 
    while (i<n) {
      a=s(a); 
      if (v(a)==nv) { 
        i++; 
        O[p(a)]=l; 
        O[l]=p(a); 
        l=n(a);
      };
    };  // set O around the fan
    nv++;  
    nc=3*nt;  // update vertex count and corner count
  };

  //  ==========================================================  GARBAGE COLLECTION ===========================================
  void clean() {
    excludeInvisibleTriangles();  
    println("excluded");
    compactVO(); 
    println("compactedVO");
    compactV(); 
    println("compactedV");
    normals(); 
    println("normals");
    computeO();
    resetMarkers();
  }  // removes deleted triangles and unused vertices

    void excludeInvisibleTriangles () {
    for (int b=0; b<nc; b++) {
      if (!visible[t(o(b))]) {
        O[b]=b;
      };
    };
  }
  void compactVO() {  
    int[] U = new int [nc];
    int lc=-1; 
    for (int c=0; c<nc; c++) {
      if (visible[t(c)]) {
        U[c]=++lc;
      };
    };
    for (int c=0; c<nc; c++) {
      if (!b(c)) {
        O[c]=U[o(c)];
      } 
      else {
        O[c]=c;
      };
    };
    int lt=0;
    for (int t=0; t<nt; t++) {
      if (visible[t]) {
        V[3*lt]=V[3*t]; 
        V[3*lt+1]=V[3*t+1]; 
        V[3*lt+2]=V[3*t+2]; 
        O[3*lt]=O[3*t]; 
        O[3*lt+1]=O[3*t+1]; 
        O[3*lt+2]=O[3*t+2]; 
        visible[lt]=true; 
        lt++;
      };
    };
    nt=lt; 
    nc=3*nt;    
    println("      ...  NOW: nv="+nv +", nt="+nt +", nc="+nc );
  }

  void compactV() {  
    println("COMPACT VERTICES: nv="+nv +", nt="+nt +", nc="+nc );
    int[] U = new int [nv];
    boolean[] deleted = new boolean [nv];
    for (int v=0; v<nv; v++) {
      deleted[v]=true;
    };
    for (int c=0; c<nc; c++) {
      deleted[v(c)]=false;
    };
    int lv=-1; 
    for (int v=0; v<nv; v++) {
      if (!deleted[v]) {
        U[v]=++lv;
      };
    };
    for (int c=0; c<nc; c++) {
      V[c]=U[v(c)];
    };
    lv=0;
    for (int v=0; v<nv; v++) {
      if (!deleted[v]) {
        G[lv].set(G[v]);  
        deleted[lv]=false; 
        lv++;
      };
    };
    nv=lv;
    println("      ...  NOW: nv="+nv +", nt="+nt +", nc="+nc );
  }

  // ============================================================= ARCHIVAL ============================================================
  boolean flipOrientation=false;            // if set, save will flip all triangles

  void saveMeshVTS() {
    String savePath = selectOutput("Select or specify .vts file where the mesh will be saved");  // Opens file chooser
    if (savePath == null) {
      println("No output file was selected..."); 
      return;
    }
    else println("writing to "+savePath);
    saveMeshVTS(savePath);
  }

  void saveMeshVTS(String fn) {
    String [] inppts = new String [nv+1+nt+1];
    int s=0;
    inppts[s++]=str(nv);
    for (int i=0; i<nv; i++) {
      inppts[s++]=str(G[i].x)+","+str(G[i].y)+","+str(G[i].z);
    };
    inppts[s++]=str(nt);
    if (flipOrientation) {
      for (int i=0; i<nt; i++) {
        inppts[s++]=str(V[3*i])+","+str(V[3*i+2])+","+str(V[3*i+1]);
      };
    }
    else {
      for (int i=0; i<nt; i++) {
        inppts[s++]=str(V[3*i])+","+str(V[3*i+1])+","+str(V[3*i+2]);
      };
    };
    saveStrings(fn, inppts);
  };

  void loadMeshVTS(int scale) {
    String loadPath = selectInput("Select .vts mesh file to load");  // Opens file chooser
    if (loadPath == null) {
      println("No input file was selected..."); 
      return;
    }
    else println("reading from "+loadPath); 
    loadMeshVTS(loadPath, scale);
  }

  void loadMeshVTS() {
    String loadPath = selectInput("Select .vts mesh file to load");  // Opens file chooser
    if (loadPath == null) {
      println("No input file was selected..."); 
      return;
    }
    else println("reading from "+loadPath); 
    loadMeshVTS(loadPath, 1);
  }

  private void printStats()
  {
    int numIsland = 0;
    int numChannel = 0;
    int numOthers = 0;
    
    //Print information about the valence of each vertex
    for (int i = 0; i < nv; i++)
    {
      vm[i] = 0;
    }

    float averageValence = 0;
    int maxValence = 0;
    int totalValence = 0;
    for (int i = 0; i < nc; i++)
    {
      //print(v(i) + " i " + i + " ");
      if (vm[v(i)] == 0)
      {
        vm[v(i)] = 1;
        int valence = getValence(i);
        totalValence += valence;
        if ( valence > maxValence )
        {
          maxValence = valence;
        }
      }
    }
    averageValence = (float)totalValence / nv;
    print("Max valence " + maxValence + "\n");  
  }
  
  void initTables(String[] vtsFile)
  {
    nv = int(vtsFile[0]);
    nt = int(vtsFile[nv+1]); 
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
    
    m_tOffsets = new int[nt]; //Storing the T offsets for propagating down LOD's. TODO msati3: better approach?
    declareVectors();
  }

  void loadMeshVTS(String fn, int scale) {
    println("loading: "+fn); 
    String [] ss = loadStrings(fn);
    initTables(ss);
    String subpts;
    int s=0;   
    int comma1, comma2;   
    float x, y, z;   
    int a, b, c;
    nv = int(ss[s++]);
    print("nv="+nv);
    for (int k=0; k<nv; k++) {
      int i=k+s; 
      comma1=ss[i].indexOf(',');   
      x=float(ss[i].substring(0, comma1));
      String rest = ss[i].substring(comma1+1, ss[i].length());
      comma2=rest.indexOf(',');    
      y=float(rest.substring(0, comma2)); 
      z=float(rest.substring(comma2+1, rest.length()));
      G[k].set(x * scale, y * scale, z * scale);
    };
    s=nv+1;
    nt = int(ss[s]); 
    nc=3*nt;
    println(", nt="+nt);
    s++;
    for (int k=0; k<nt; k++) {
      int i=k+s;
      comma1=ss[i].indexOf(',');   
      a=int(ss[i].substring(0, comma1));  
      String rest = ss[i].substring(comma1+1, ss[i].length()); 
      comma2=rest.indexOf(',');  
      b=int(rest.substring(0, comma2)); 
      c=int(rest.substring(comma2+1, rest.length()));
      V[3*k]=a;  
      V[3*k+1]=b;  
      V[3*k+2]=c;
    }
    initVBO();
  };


  void loadMeshOBJ() {
    String loadPath = selectInput("Select .obj mesh file to load");  // Opens file chooser
    if (loadPath == null) {
      println("No input file was selected..."); 
      return;
    }
    else println("reading from "+loadPath); 
    loadMeshOBJ(loadPath);
  }

  void loadMeshOBJ(String fn) {
    println("loading: "+fn); 
    String [] ss = loadStrings(fn);
    String subpts;
    String S;
    int comma1, comma2;   
    float x, y, z;   
    int a, b, c;
    int s=2;   
    println(ss[s]);
    int nn=ss[s].indexOf(':')+2; 
    println("nn="+nn);
    nv = int(ss[s++].substring(nn));  
    println("nv="+nv);
    int k0=s;
    for (int k=0; k<nv; k++) {
      int i=k+k0; 
      S=ss[i].substring(2); 
      if (k==0 || k==nv-1) println(S);
      comma1=S.indexOf(' ');   
      x=-float(S.substring(0, comma1));           // swaped sign to fit picture
      String rest = S.substring(comma1+1);
      comma2=rest.indexOf(' ');    
      y=float(rest.substring(0, comma2)); 
      z=float(rest.substring(comma2+1));
      G[k].set(x, y, z); 
      if (k<3 || k>nv-4) {
        print("k="+k+" : ");
      }
      s++;
    };
    s=s+2; 
    println("Triangles");
    println(ss[s]);
    nn=ss[s].indexOf(':')+2;
    nt = int(ss[s].substring(nn)); 
    nc=3*nt;
    println(", nt="+nt);
    s++;
    k0=s;
    for (int k=0; k<nt; k++) {
      int i=k+k0;
      S=ss[i].substring(2);                        
      if (k==0 || k==nt-1) println(S);
      comma1=S.indexOf(' ');   
      a=int(S.substring(0, comma1));  
      String rest = S.substring(comma1+1); 
      comma2=rest.indexOf(' ');  
      b=int(rest.substring(0, comma2)); 
      c=int(rest.substring(comma2+1));
      //      V[3*k]=a-1;  V[3*k+1]=b-1;  V[3*k+2]=c-1;                           // original
      V[3*k]=a-1;  
      V[3*k+1]=c-1;  
      V[3*k+2]=b-1;                           // swaped order
    }
    for (int i=0; i<nv; i++) G[i].mul(4);
  }; 

  void initVBO(int typeMesh) //0 static, 1 dynamic
  {
     m_vertexVBO = new int[1];
    m_colorVBO = new int[1];
    m_edgeVBO = new int[1];

    FloatBuffer geometry = FloatBuffer.allocate( 3 * nc );
    for (int i = 0; i < nc; i++)
    {
      geometry.put(G[V[i]].x);
      geometry.put(G[V[i]].y);
      geometry.put(G[V[i]].z);
    }
    geometry.rewind();
    
    FloatBuffer edgeGeometry = FloatBuffer.allocate( 2 * 3 * nc );
    for (int i = 0; i < nc; i++)
    {
      edgeGeometry.put(G[V[i]].x);
      edgeGeometry.put(G[V[i]].y);
      edgeGeometry.put(G[V[i]].z);

      int j = 1;
      if ( (i+1) % 3 == 0 )
      {
        j = -2;
      }
      edgeGeometry.put(G[V[i+j]].x);
      edgeGeometry.put(G[V[i+j]].y);
      edgeGeometry.put(G[V[i+j]].z);
    }
    edgeGeometry.rewind();
  
    ByteBuffer col = ByteBuffer.allocate( 4 * nc );
    for (int i = 0; i < nc; i++)
    {
      byte zero = 0;
      byte maxi = (byte)(255 & 0xff);
      col.put(maxi);
      col.put(zero);
      col.put(zero);
      col.put(maxi);
    }
    col.rewind();

    pgl.beginGL();
    gl.glGenBuffers( 1, m_vertexVBO, 0 );
    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, m_vertexVBO[0] );
    gl.glBufferData( GL.GL_ARRAY_BUFFER, 3 * 4 * nc, geometry, typeMesh == 0 ? GL.GL_STATIC_DRAW : GL.GL_DYNAMIC_DRAW );

    pgl.beginGL();
    gl.glGenBuffers( 1, m_edgeVBO, 0 );
    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, m_edgeVBO[0] );
    gl.glBufferData( GL.GL_ARRAY_BUFFER, 2 * 3 * 4 * nc, edgeGeometry, typeMesh == 0 ? GL.GL_STATIC_DRAW : GL.GL_DYNAMIC_DRAW );

    gl.glGenBuffers( 1, m_colorVBO, 0 );
    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, m_colorVBO[0] );
    gl.glBufferData( GL.GL_ARRAY_BUFFER, 4 * 4 * nc, col, GL.GL_DYNAMIC_DRAW );

    gl.glBindBuffer( GL.GL_ARRAY_BUFFER, 0 );

    pgl.endGL();

    geometry.clear();
    edgeGeometry.clear();
    col.clear();
  }

  void initVBO()
  {
    initVBO(0); //static mesh
  }

  void makeInvisible(int m) { 
    for (int i=0; i<nt; i++) if (tm[i]==m) visible[i]=false;
  }
  void rename(int m, int k) { 
    for (int i=0; i<nt; i++) if (tm[i]==m)  tm[i]=k;
  }
  void makeAllVisible() { 
    for (int i=0; i<nt; i++) visible[i]=true;
  }

  // cplit the mesh near loop
  int closestVertexID(pt M) {
    int v=0; 
    for (int i=1; i<nv; i++) if (d(M, G[i])<d(M, G[v])) v=i; 
    return v;
  }
  int closestCorner(pt M) {
    int c=0; 
    for (int i=1; i<nc; i++) if (d(M, cg(i))<d(M, cg(c))) c=i; 
    return c;
  }


  void drawLineToClosestProjection(pt P) {
    float md=d(P, g(0));
    int cc=0; // corner of closest cell
    int type = 0; // type of closest projection: - = vertex, 1 = edge, 2 = triangle
    pt Q = P(); // closest point
    for (int c=0; c<nc; c++) if (d(P, g(c))<md) {
      Q.set(g(c)); 
      cc=c; 
      type=0; 
      md=d(P, g(c));
    } 
    for (int c=0; c<nc; c++) if (c<=o(c)) {
      float d = distPE(P, g(n(c)), g(p(c))); 
      if (d<md && projPonE(P, g(n(c)), g(p(c)))) {
        md=d; 
        cc=c; 
        type=1; 
        Q=CPonE(P, g(n(c)), g(p(c)));
      }
    } 
    if (onTriangles) 
      for (int t=0; t<nt; t++) {
        int c=3*t; 
        float d = distPtPlane(P, g(c), g(n(c)), g(p(c))); 
        if (d<md && projPonT(P, g(c), g(n(c)), g(p(c)))) {
          md=d; 
          cc=c; 
          type=2; 
          Q=CPonT(P, g(c), g(n(c)), g(p(c)));
        }
      } 
    if (type==2) stroke(dred);   
    if (type==1) stroke(dgreen);  
    if (type==0) stroke(dblue);  
    show(P, Q);
  }

  pt closestProjection(pt P) {  // ************ closest projection of P on this mesh
    float md=d(P, G[0]);
    pt Q = P();
    int v=0; 
    for (int i=1; i<nv; i++) if (d(P, G[i])<md) {
      Q=G[i]; 
      md=d(P, G[i]);
    } 
    for (int c=0; c<nc; c++) if (c<=o(c)) {
      float d = abs(distPE(P, g(n(c)), g(p(c)))); 
      if (d<md && projPonE(P, g(n(c)), g(p(c)))) {
        md=d; 
        Q=CPonE(P, g(n(c)), g(p(c)));
      }
    } 
    for (int t=0; t<nt; t++) {
      int c=3*t; 
      float d = distPtPlane(P, g(c), g(n(c)), g(p(c))); 
      if (d<md && projPonT(P, g(c), g(n(c)), g(p(c)))) {
        md=d; 
        Q=CPonT(P, g(c), g(n(c)), g(p(c)));
      }
    } 
    return Q;
  }

  pt closestProjection(pt P, int k) { //closest projection on triangles marked as tm[t]==k
    float md=d(P, G[0]);
    pt Q = P();
    for (int c=0; c<nc; c++) if (tm[t(c)]==k) if (d(P, g(c))<md) {
      Q=g(c); 
      md=d(P, g(c));
    } 
    for (int c=0; c<nc; c++)  if (tm[t(c)]==k) if (c<=o(c)) {
      float d = distPE(P, g(n(c)), g(p(c))); 
      if (d<md && projPonE(P, g(n(c)), g(p(c)))) {
        md=d; 
        Q=CPonE(P, g(n(c)), g(p(c)));
      }
    } 
    for (int t=0; t<nt; t++)  if (tm[t]==k) {
      int c=3*t; 
      float d = distPtPlane(P, g(c), g(n(c)), g(p(c))); 
      if (d<md && projPonT(P, g(c), g(n(c)), g(p(c)))) {
        md=d; 
        Q=CPonT(P, g(c), g(n(c)), g(p(c)));
      }
    } 
    return Q;
  }


  int closestVertexNextCorner(pt P, int k) { //closest projection on triangles marked as tm[t]==k
    int bc=0; // best corner index
    float md=d(P, g(p(bc)));
    for (int c=0; c<nc; c++) if (tm[t(c)]==k && tm[t(o(c))]!=k) if (d(P, g(p(c)))<md) {
      bc=c; 
      md=d(P, g(p(c)));
    } 
    return bc;
  }

  int closestVertex(pt P, int k) { //closest projection on triangles marked as tm[t]==k
    int v=0;
    float md=d(P, G[v]);
    for (int c=0; c<nc; c++) if (tm[t(c)]==k) if (d(P, g(c))<md) {
      v=v(c); 
      md=d(P, g(c));
    } 
    return v;
  }

  int nextAlongSplit(int c, int mk) {
    c=p(c);
    if (tm[t(o(c))]==mk) return c;
    c=p(o(c));
    while (tm[t (o (c))]!=mk) c=p(o(c));
    return c;
  }  

  int prevAlongSplit(int c, int mk) {
    c=n(c);
    if (tm[t(o(c))]==mk) return c;
    c=n(o(c));
    while (tm[t (o (c))]!=mk) c=n(o(n(c)));
    return c;
  }  

  //Interaction of mesh class with outside objects. TODO msati3: Better ways of handling this?
  void setViewport(Viewport viewport) {
    if ( DEBUG && DEBUG_MODE >= LOW )
    {
      print("Setting viewport for " + m_meshNumber + " to " + viewport + "\n" );
    }
    m_viewport = viewport;
  }
  
  void setRegion(boolean[] inRegion)
  {
    m_selectedRegion = inRegion;
  }

  void onKeyPressed() {
    m_userInputHandler.onKeyPress();
  }

  void onMousePressed() {
    m_userInputHandler.onMousePressed();
  }
  
  void onMouseDragged() {
    m_userInputHandler.onMouseDragged();
  }
  
  void onMouseMoved() {
    m_userInputHandler.onMouseMoved();
  }

  void interactSelectedMesh() {
    m_userInputHandler.interactSelectedMesh();
  }
} // ==== END OF MESH CLASS

vec labelD=new vec(-4, +4, 12);           // offset vector for drawing labels  

float distPE (pt P, pt A, pt B) {
  return n(N(V(A, B), V(A, P)))/d(A, B);
} // distance from P to edge(A,B)
float distPtPlane (pt P, pt A, pt B, pt C) {
  vec N = U(N(V(A, B), V(A, C))); 
  return abs(d(V(A, P), N));
} // distance from P to plane(A,B,C)
Boolean projPonE (pt P, pt A, pt B) {
  return d(V(A, B), V(A, P))>0 && d(V(B, A), V(B, P))>0;
} // P projects onto the interior of edge(A,B)
Boolean projPonT (pt P, pt A, pt B, pt C) {
  vec N = U(N(V(A, B), V(A, C))); 
  return m(N, V(A, B), V(A, P))>0 && m(N, V(B, C), V(B, P))>0 && m(N, V(C, A), V(C, P))>0 ;
} // P projects onto the interior of edge(A,B)
pt CPonE (pt P, pt A, pt B) {
  return P(A, d(V(A, B), V(A, P))/d(V(A, B), V(A, B)), V(A, B));
}
pt CPonT (pt P, pt A, pt B, pt C) {
  vec N = U(N(V(A, B), V(A, C))); 
  return P(P, -d(V(A, P), N), N);
}

