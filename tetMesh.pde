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
  
  TetMesh(int maxV, int maxT)
  {
    m_G = new pt[maxV];
    m_V = new int[4*maxT];
    m_O = new int[4*maxT];
  }
  
  //Operators
  int fc(int corner) { return x4(m4(corner)); } //first corner
  int t(int corner) { return d4(corner); }
  int n(int corner) { return fc(corner) + m4(corner+1); }
  int p(int corner) { return fc(corner) + m4(corner+3); }
  int v(int corner) { return m_V[corner]; }
  int o(int corner) { return m_O[corner]; }
  
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

