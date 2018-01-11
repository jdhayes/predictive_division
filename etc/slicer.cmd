// slicer.cmd

// plane eq: a*x + b*y + c*z = d

// Commands included: 
//   drawslice - make new edges across facets along plane.
//   slicer - make slice and dissolve all facets, edges, and vertices
//            on negative side of the plane. Calls drawslice.
//   slice_list - print coordinates of vertices along a slice.
//   clip_slice - physically clips along all current clip planes.

/* 
   help: slicer
   keywords: slice, slicing
   slicer - Remove surface on one side of a plane.
   Set slice_a,slice_b,slice_c,slice_d coefficients so
      slice_a*x + slice_b*y + slice_c*z >= slice_d
   is the side you want, and do "slicer".
   Result: truncated surface on positive side of plane
   Try not to slice exactly through vertices!!
   Default plane is slice_a := 0, slice_b := 0, slice_c := 1, slice_d := .1
   endhelp

   help: drawslice
   keywords: slice, slicing
   drawslice - Creates edges where a given plane intersects the surface.
   Set slice_a,slice_b,slice_c,slice_d coefficients so
      slice_a*x + slice_b*y + slice_c*z >= slice_d
   is the slice plane want, and do "draw_slice".
   Try not to slice exactly through vertices!!
   Default plane is slice_a := 0, slice_b := 0, slice_c := 1, slice_d := .1
   endhelp


*/

// "slicer" usage: 
// Set slice_a,slice_b,slice_c,slice_d coefficients so
// slice_a*x + slice_b*y + slice_c*z >= slice_d
// is the side you want, and do "slicer".
// output: truncated surface on positive side of plane
// Try not to slice exactly through vertices!!
// Default plane is slice_a := 0, slice_b := 0, slice_c := 1, slice_d := .1

// To mark the vertices and edges created by the current slicing,
// there are a vertex attribute v_timestamp and an edge attribute 
// e_timestamp that are set to slice_timestamp, which is incremented
// each time slicer is called.

// Works in torus by rewrapping wrapped edges that would be cut
// so unwrapped part is on positive side of cut plane.

// Slice_list:
// Listing of vertices along the slice, beginning at user-designated vertex.
// If the slice has multiple components, you will have to run separately
// for each component.   "slicer" or "drawslice" must be called first.
// Usage: set startv to the first vertex on the slice and call slice_list
// Output is to stdout, so will usually be redirected, e.g.
//    slice_list >>> "slice.dat"

//Set these coefficients for the slicing plane
slice_a := 0; 
slice_b := 0; 
slice_c := 1; 
slice_d := .1; 

// Attributes for marking vertices and edges on slice with timestamp
slice_timestamp := 2   // so won't conflict with 0 for new edges or 1 for
                       // original edges
define vertex attribute v_timestamp integer
define edge attribute e_timestamp integer

// Mark existing edges and vertices (if not already marked)
set edge e_timestamp 1 where e_timestamp==0
set vertex v_timestamp 1 where v_timestamp==0


// This script can handle boundary edges, but in case model does
// not use boundaries, we define an attribute here so the script parses.
if not is_defined("e_boundary") then define edge attribute e_boundary integer

// First put in new edges along slicing plane
drawslice := { 
        local lambda;
        local denom;
        local xx1;
        local yy1;
        local zz1;
        local xx2;
        local yy2;
        local zz2;
        local xb,yb,zb;
        local otherv;

        slice_timestamp += 1;  // marker for this slice
        foreach edge ee do 
        {
          xx1 := ee.vertex[1].x; 
          yy1 := ee.vertex[1].y; 
          zz1 := ee.vertex[1].z; 
          xx2 := xx1 + ee.x;  // using edge vector in case of torus wrap
          yy2 := yy1 + ee.y; 
          zz2 := zz1 + ee.z;
          denom := slice_a*(xx1-xx2)+slice_b*(yy1-yy2)+slice_c*(zz1-zz2);
          if ( denom != 0.0 ) then 
          { 
            lambda := (slice_d-slice_a*xx2-slice_b*yy2-slice_c*zz2)/denom; 
            if ( (lambda >= 0) and (lambda <= 1) ) then 
            { 
              if torus then 
                if ee.wrap then
                { if denom > 0 then // tail on positive side
                    wrap_vertex(ee.vertex[2].id,ee.wrap)
                  else  // head on positive side
                    wrap_vertex(ee.vertex[1].id,wrap_inverse(ee.wrap));
                }; 
         
              otherv := ee.vertex[2].id;
              refine ee;
              if ee.e_boundary then
              { ee.vertex[2].p := lambda*ee.vertex[1].p 
                                    + (1-lambda)*vertex[otherv].p;
              }
              else
              {
              xb := lambda*xx1+(1-lambda)*xx2; 
              yb := lambda*yy1+(1-lambda)*yy2;
              zb := lambda*zz1+(1-lambda)*zz2; 
              ee.vertex[2].x := xb;
              ee.vertex[2].y := yb;
              ee.vertex[2].z := zb;
              };
              ee.vertex[2].v_timestamp := slice_timestamp;
              set ee.vertex[2].edge eee e_timestamp slice_timestamp where 
                  eee.vertex[2].v_timestamp == slice_timestamp;

            } 
            else if torus and ee.wrap then
            { // try wrapping from head
              xx2 := ee.vertex[2].x; 
              yy2 := ee.vertex[2].y; 
              zz2 := ee.vertex[2].z; 
              xx1 := xx2 - ee.x;  // using edge vector in case of torus wrap
              yy1 := yy2 - ee.y; 
              zz1 := zz2 - ee.z;
              denom := slice_a*(xx1-xx2)+slice_b*(yy1-yy2)+slice_c*(zz1-zz2);
              if ( denom != 0.0 ) then 
              { 
                lambda := (slice_d-slice_a*xx2-slice_b*yy2-slice_c*zz2)/denom; 
                if ( (lambda >= 0) and (lambda <= 1) ) then 
                { 
                  if torus then 
                    if ee.wrap then
                    { if denom > 0 then // tail on positive side
                        wrap_vertex(ee.vertex[2].id,ee.wrap)
                      else  // head on positive side
                        wrap_vertex(ee.vertex[1].id,wrap_inverse(ee.wrap));
                    };
             
                  xb := lambda*xx1+(1-lambda)*xx2; 
                  yb := lambda*yy1+(1-lambda)*yy2;
                  zb := lambda*zz1+(1-lambda)*zz2; 
                  refine ee;
                  ee.vertex[2].v_timestamp := slice_timestamp;
                  ee.vertex[2].x := xb;
                  ee.vertex[2].y := yb;
                  ee.vertex[2].z := zb;
                  set ee.vertex[2].edge eee e_timestamp slice_timestamp where 
                    eee.vertex[2].e_timestamp == slice_timestamp;
                }
              } 
          }
        } ; 
      } ; 

   }

slicer := {
    local former_autodisplay;

    drawslice;
    former_autodisplay := (autodisplay);
    autodisplay off; // prevent display while dissolving
    foreach facet ff where   // again, careful of torus wraps
      slice_a*(ff.vertex[1].x+ff.edge[1].x/3-ff.edge[3].x/3) +
      slice_b*(ff.vertex[1].y+ff.edge[1].y/3-ff.edge[3].y/3) +
      slice_c*(ff.vertex[1].z+ff.edge[1].z/3-ff.edge[3].z/3)  < slice_d do
    { unset ff frontbody;
      unset ff backbody;
      dissolve ff;
    };
    dissolve bodies bbb where sum(bbb.facets,1) == 0;
    dissolve edges ee where avg(ee.vertex vv, 
      slice_a*vv.x + slice_b*vv.y + slice_c*vv.z) < slice_d;  
      // just does bare edges
    dissolve vertices vv where
      slice_a*vv.x + slice_b*vv.y + slice_c*vv.z < slice_d;  
      // just does bare vertices

    // mark edges and vertices created by slicing
    set edge ee e_timestamp slice_timestamp where 
          (ee.valence==1) and (ee.e_timestamp == 0); 
    set edge ee e_timestamp 1 where ee.e_timestamp == 0; 
    foreach edge ee where e_timestamp==slice_timestamp do
      set ee.vertex v_timestamp slice_timestamp;

    if former_autodisplay then autodisplay on;
}

color_slice := {
    foreach facet ff where   // again, careful of torus wraps
      slice_a*(ff.vertex[1].x+ff.edge[1].x/3-ff.edge[3].x/3) +
      slice_b*(ff.vertex[1].y+ff.edge[1].y/3-ff.edge[3].y/3) +
      slice_c*(ff.vertex[1].z+ff.edge[1].z/3-ff.edge[3].z/3)  < slice_d do
       set ff color magenta;      

}

// Listing of vertices along the slice, beginning at user-designated vertex.
// If the slice has multiple components, you will have to run separately
// for each component.
// Usage: set startv to the first vertex on the slice and call slice_list
// Output is to stdout, so will usually be redirected, e.g.
//    slice_list >>> "slice.dat"

startv := 1
slice_list := {
   local thisv,thisedge,next_edge;

   if vertex[startv].v_timestamp != slice_timestamp then
   { errprintf "slice_list: starting vertex startv is %d, not on latest slice.\n",
        startv;
     return;
   };
   thisv := startv;
   thisedge := 0;
   do
   { // print current vertex coordinates
     printf "%20.15f %20.15f %20.15f\n",vertex[thisv].x,vertex[thisv].y,
       vertex[thisv].z;
     next_edge := 0;
     foreach vertex[thisv].edge ee where ee.e_timestamp == slice_timestamp
     do { if ee.oid != -thisedge then { next_edge := ee.oid; break; }};
     if next_edge == 0 then break; /* done */ 
     thisv := edge[next_edge].vertex[2].id;
     thisedge := next_edge;
   } while thisv != startv; // done
}

clip_slice := {
  local inx;

  for ( inx := 1 ; inx <= 10 ; inx++ )
  { if clip_coeff[inx][1] == 0 and clip_coeff[inx][2] == 0 and clip_coeff[inx][3] == 0
       then continue;
    slice_a := -clip_coeff[inx][1];
    slice_b := -clip_coeff[inx][2];
    slice_c := -clip_coeff[inx][3];
    slice_d := -clip_coeff[inx][4];
    slicer;
  }
}

// "slicer" usage: 
// Set slice_a,slice_b,slice_c,slice_d coefficients so
// slice_a*x + slice_b*y + slice_c*z >= slice_d
// is the side you want, and do "slicer".
// Default plane is slice_a := 0, slice_b := 0, slice_c := 1, slice_d := .1

