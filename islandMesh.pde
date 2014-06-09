//TYPES OF TRIANGLES
int SPLIT = 1;
int GATE = 2;
int CHANNEL = 3;
int WATER = 8; //Water before forming islands
int ISOLATEDWATER = 4;
int LAGOON = 5;
int JUNCTION = 6;
int CAP = 7;
int ISLAND = 9;

class IslandMesh extends Mesh
{
 int[] cm2 = new int[3*maxnt];
  
 IslandMesh()
 {
   m_userInputHandler = new IslandMeshUserInputHandler(this);
 }
 
 IslandMesh(Mesh m)
 {
   G = m.G;
   V = m.V;
   O = m.O;
   nv = m.nv;
   nt = m.nt;
   nc = m.nc;
   
   /*m_vertexVBO = m.m_vertexVBO;
   m_colorVBO = m.m_colorVBO;*/
   initVBO();
   
   m_userInputHandler = new IslandMeshUserInputHandler(this);
 }

 //Debug
 void pickc (pt X) {
   int origCC = cc;
    super.pickc(X);
    //if ( origCC != cc && DEBUG && DEBUG_MODE >= LOW ) { print(" Island for corner " + cc + " is " + getIslandForVertexExtended(v(cc)) + " " + island[cc] + " Number of vertex wrt island is" + m_islandVertexNumber.get(v(cc)) + "\n" ); }
 } // picks closest corner to X

 void resetMarkers() 
 {
   super.resetMarkers();
 }
 
 void updateColorsVBO(int opacity)
 {
    ByteBuffer col = ByteBuffer.allocate( 4 * nc );
    color c = 0;
    for (int i = 0; i < nc; i++)
    {
      int t = t(i);
      if (tm[t]==0) c = formColor(red, opacity); 
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
          c = formColor(green, opacity); 
        }
        else if (cm2[t] == 1)
        {
          c = formColor(yellow, opacity); 
        }
        else if (cm2[t] == 2)
        {
          c = formColor(magenta, opacity);
        }
        else
        {
          c = formColor(blue, opacity);
        }
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
  
 void showTriangles(Boolean front, int opacity, float shrunk) {
   drawVBO();  
    /*for (int t=0; t<nt; t++) {
      if (V[3*t] == -1) continue;    //Handle base mesh compacted triangles      
      if (!vis[tm[t]] || frontFacing(t)!=front || !visible[t]) continue;
      if (!frontFacing(t)&&showBack) {
        fill(blue); 
        shade(t); 
        continue;
      }
      if (tm[t]==0) fill(red, opacity); 
      if (tm[t]==1) fill(brown, opacity); 
      if (tm[t]==2) fill(orange, opacity); 
      if (tm[t]==3) fill(cyan, opacity); 
      if (tm[t]==4) fill(magenta, opacity); 
      if (tm[t]==5) fill(green, opacity); 
      if (tm[t]==6) fill(blue, opacity); 
      if (tm[t]==7) fill(#FAAFBA, opacity); 
      if (tm[t]==8) fill(blue, opacity); 
      if (tm[t]==9)
      {
        if (cm2[t] == 0)
        {
          fill(green, opacity); 
        }
        else if (cm2[t] == 1)
        {
          fill(yellow, opacity); 
        }
        else if (cm2[t] == 2)
        {
          fill(magenta, opacity);
        }
        else
        {
          fill(blue, opacity);
        }
      }
        
      if (vis[tm[t]]) {
        if (m_drawingState.m_shrunk != 0) showShrunkT(t, m_drawingState.m_shrunk); 
        else shade(t);
      }
    }*/
  }
}
