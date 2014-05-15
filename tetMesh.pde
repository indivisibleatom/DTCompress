// CORNER TABLE FOR Tetrahedral Meshes

//Fast bit operators
int d4(int num){ return num>>2; }
int x4(int num){ return num<<2; }
int m4(int num){ return num & 0x3; }
boolean even(int num) { return ((num & 0x1) == 0); }

class TetMesh {
  pt[] m_G;
  int[] m_V;
  int[] m_O;
  int m_nv;
  int m_nt;
  int m_nc;
  
  TetMesh(int maxV, int maxT)
  {
    m_G = new pt[maxV];
    m_V = new int[4*maxT];
    m_O = new int[4*maxT];
    m_nv = 0;
    m_nt = 0;
    m_nc = 0;
  }
  
  //Operators
  int fc(int corner) { return x4(m4(corner)); } //first corner
  int t(int corner) { return d4(corner); }
  int n(int corner) { return fc(corner) + m4(corner+1); }
  int p(int corner) { return fc(corner) + m4(corner+3); }
  int v(int corner) { return m_V[corner]; }
  int o(int corner) { return m_O[corner]; }
  
  void loadMeshVts(String fileName)
  {
    println("loading: " + fileName); 
    String [] ss = loadStrings(fileName);
    String subpts;
    int s=0;   
    int comma1, comma2, comma3;   
    float x, y, z;   
    int a, b, c, d;
    
    m_nv = int(ss[s++]);
    print("nv="+m_nv);
    for (int k=0; k<m_nv; k++) {
      int i=k+s; 
      comma1=ss[i].indexOf(',');   
      x=float(ss[i].substring(0, comma1));
      String rest = ss[i].substring(comma1+1, ss[i].length());
      comma2=rest.indexOf(',');    
      y=float(rest.substring(0, comma2)); 
      z=float(rest.substring(comma2+1, rest.length()));
      m_G[k] = new pt();
      m_G[k].set(x, y, z);
    };
    
    s=m_nv+1;
    int numFaces = int(ss[s]); 
    int nc=3*numFaces;
    println(", nf="+numFaces);
    s++;
    int[] triV = new int[3*numFaces];
    for (int k=0; k<numFaces; k++) {
      int i=k+s;
      comma1=ss[i].indexOf(',');   
      a=int(ss[i].substring(0, comma1));  
      String rest = ss[i].substring(comma1+1, ss[i].length()); 
      comma2=rest.indexOf(',');  
      b=int(rest.substring(0, comma2)); 
      c=int(rest.substring(comma2+1, rest.length()));
      triV[3*k]=a - 1;  
      triV[3*k+1]=b - 1;  
      triV[3*k+2]=c - 1;
    }

    s=m_nv + numFaces + 2;
    m_nt = int(ss[s]); 
    m_nc = 4*m_nt;
    println(", nt="+m_nt);
    s++;
    for (int k=0; k<m_nt; k++) {
      int i=k+s;
      comma1=ss[i].indexOf(',');   
      a=int(ss[i].substring(0, comma1));  
      String rest = ss[i].substring(comma1+1, ss[i].length()); 
      comma2=rest.indexOf(',');  
      b=int(rest.substring(0, comma2)); 
      comma3=rest.indexOf(',');   
      c=int(rest.substring(0, comma3));
      d=int(rest.substring(comma3+1, rest.length()));
      triV[4*k]=findCommon(triV, a, b, c);  
      triV[4*k+1]=findCommon(triV, b, c, d);
      triV[4*k+2]=findCommon(triV, c, d, a);
      triV[4*k+3]=findCommon(triV, d, a, b);
    }
  }
  
  private int findCommon(int []triV, int a, int b, int c)
  {
    int[] vertices1 = {triV[3*a], triV[3*a+1], triV[3*a+2]};
    int[] vertices2 = {triV[3*b], triV[3*b+1], triV[3*b+2]};
    int[] vertices3 = {triV[3*c], triV[3*c+1], triV[3*c+2]};
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++)
        for (int k = 0; k < 3; k++)
        {
          if (vertices1[i] == vertices2[j] && vertices1[i] == vertices3[k])
            return vertices1[i];
        }
    return -1;
  }
  
  void showTriangle(int t, int a, int b, int c)
  {
    int v1 = m_V[4*t+a];
    int v2 = m_V[4*t+b];
    int v3 = m_V[4*t+c];
    
    beginShape(TRIANGLES);
    vertex(m_G[v1].x, m_G[v1].y, m_G[v1].z);
    vertex(m_G[v2].x, m_G[v2].y, m_G[v2].z);
    vertex(m_G[v3].x, m_G[v3].y, m_G[v3].z);
    endShape();
  }
  
  void draw()
  {
    for (int i = 0; i < m_nt; i++)
    {
      showTriangle(i,0,1,2);
      showTriangle(i,1,2,3);
      showTriangle(i,2,3,0);
      showTriangle(i,3,0,1);
    }
  }
  
  //Wedge
  class Wedge
  {
    int m_a;
    int m_b;
    
    Wedge(int a, int b)
    {
      m_a = a;
      m_b = b;
    }
    
    //Operators
    Wedge m(Wedge w) { return new Wedge( m_b, m_a ); }
    Wedge n(Wedge w) 
    {
      int nc = m4(w.m_b + (even(w.m_a)? 3:1));
      if ( nc == m4(w.m_a) )
      {
        nc = m4(w.m_b + 2);
      }
      return new Wedge( w.m_a, fc(w.m_a) + nc );
    }
    Wedge o(Wedge w)
    {
      int na;
      TetMesh mesh = TetMesh.this;
      int oc = mesh.o( w.m_b );
      if ( oc == w.m_b ) { return null; }
      if ( mesh.v(mesh.n(oc)) == mesh.v( w.m_a ) ) { na = mesh.n(oc); }
      else if ( mesh.v(mesh.p(oc)) == mesh.v( w.m_a ) ) { na = mesh.p(oc); }
      else { na = mesh.n(mesh.n(oc) ); }
      return new Wedge( na, oc );
    }
    
    Wedge p(Wedge w) {return n(n(w)); }
    Wedge l(Wedge w) {return o(n(w)); }
    Wedge r(Wedge w) {return o(p(w)); }
    Wedge k(Wedge w) {return n(m(p(w))); }
    Wedge f(Wedge w) { return o(m(w)); }
    Wedge sl(Wedge w) { return n(l(w)); }
    Wedge sr(Wedge w) { return p(r(w)); }
  }
}

