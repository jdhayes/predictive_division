
/* trailer.inc

   Include file for end of datafiles.

*/

//showq; // start graphics

basename := datafilename; //  Used for titles and output files; change after loading if you want

constraint_tolerance := 1e-6;  // default 1e-12 gave too many warnings

eigen_flag := 0  // set to 1, 2, or 3 by e_run when doing eigenvector directions for surfaces
                 // so filenames and window titles go by eigenvector number

harmonic_order := 0  // Should be re-defined when loading particular harmonic function.
                     // Used for output labelling

define slice_normal real[3];

read "slicer.cmd"
read "SphericalHarmonics.cmd"
read "stl.cmd"

// Make body
new_b := new_body;
set facet frontbody new_b;

// Center about the origin, so radius is single-valued function
// of spherical direction.
center := {
  xcm := sum(facet ff, ff.x*avg(ff.vertex,x^2/2))/body[new_b].volume; 
  ycm := sum(facet ff, ff.y*avg(ff.vertex,y^2/2))/body[new_b].volume; 
  zcm := sum(facet ff, ff.z*avg(ff.vertex,z^2/2))/body[new_b].volume; 
  set vertex x x-xcm;
  set vertex y y-ycm;
  set vertex z z-zcm;
}

center  // execute
show_trans "R20r4d"

// Calculating spherical harmonics


/********************************************************************************/
// Procedure to calculate spherical harmonics.  Prepares the surface by
// refining long edges, so facets get small enough that numerical integration
// is accurate.
procedure CalcHarmonics(integer max_l) 
{
   // Need to get small facets to resolve higher order spherical harmonics.
   // Refine until get about 10,000 facets.
   fix vertex;
   fix edge;
   groom_length := (max(vertex,x)-min(vertex,x))/20;
   do { reset_counts; 
        refine edge where length > groom_length; u; V; 
      } while refine_count > 0;
   do 
   { refine edge where length > groom_length; u; V;
     groom_length *= 0.8;
   } while facet_count < 10000;

   define HarmonicCoeff real[max_l+1][2*max_l+1];
   for ( lla := 0 ; lla <= max_l ; lla++ )
   { printf "l = %d:\n",lla;
     for ( mma := -lla ; mma <= lla ; mma++ )
     { recalc;
       HarmonicCoeff[lla+1][lla+mma+1] := harm_coeff.value;
       errprintf "   m = %2d: %18.15f\n",mma,harm_coeff.value;
     }
   };
   SphHarmPrintAll(max_l); 
}

/********************************************************************************/
// Alternate way to calculate spherical harmonics.  Evaluates separate integrals
// for each combination of sin/cos and power of x.
procedure AltCalcHarmonics(integer max_l)
{
  local ll,mm;

  // Sanity checks
  if sum(edge, valence != 2 ) > 0 then
  { errprintf "\n\n\nAltCalcHarmonics FATAL ERROR: The surface is not manifold.\n";
    errprintf "There are %d edges that are not valence 2 (colored red in image).\n",
      sum(edge,valence!=2);
    abort;
  };

  // Check orientation
  if body[1] volume < 0 then
  { unset body[1].facet frontbody;
    unset facet quantity harm_coeff;
    reverse_orientation facets;
    set facet orientation 1;
    set facet backbody 1;
    set facet quantity harm_coeff;
    recalc;
  };

  quiet on;
  if Legendre_max < max_l then CalcLegendreCoeff(max_l);

   // need to get small facets to resolve higher order spherical harmonics
   fix vertex;
   fix edge;
   groom_length := (max(vertex,x)-min(vertex,x))/20;
   do { reset_counts; 
        refine edge where length > groom_length; u; V; 
      } while refine_count > 0;
   do 
   { { refine edge where length > groom_length; u; V; } 3;
     groom_length *= 0.8;
   } while facet_count < 10000;

   define HarmonicCoeff real[max_l+1][2*max_l+1];
   for ( lla := 0 ; lla <= max_l ; lla++ )
   { errprintf "l = %d:\n",lla;
     for ( mma := -lla ; mma <= lla ; mma++ )
     { recalc;
       HarmonicCoeff[lla+1][lla+mma+1] := harm_coeff.value;
       errprintf "   m = %2d: %18.15f\n",mma,harm_coeff.value;
     }
   };

   AltSphHarmPrintAll(max_l); 
   quiet off;
} // end AltCalcHarmonics

/********************************************************************************/
// Calculating principal axes.  Computes three unit eigenvectors of the
// moment of inertia matrix.  The eigenvectors are found by repeated multiplication
// of a triplet of vectors by the moment matrix, with orthogonalization of the
// vectors after each multiplication.
// Eigenvectors are returned in the rows of the global array eigvecs.

define eigvecs real[3][3];  // eigenvectors in rows

calc_principal_axes := {
  local moments,next_eigvecs,old_eigvecs;
  define moments real[3][3];
  define next_eigvecs real[3][3];  
  define old_eigvecs real[3][3];  

  set facet quantity xx_moment;
  set facet quantity xy_moment;
  set facet quantity xz_moment;
  set facet quantity yy_moment;
  set facet quantity yz_moment;
  set facet quantity zz_moment;

  recalc;
  moments := { {xx_moment.value, xy_moment.value, xz_moment.value},
               {xy_moment.value, yy_moment.value, yz_moment.value},
               {xz_moment.value, yz_moment.value, zz_moment.value}};
  if moments[1][1] < 0 then moments *= -1;  // correct for wrong surface orientation

  eigvecs := { {1,0,0},{0,1,0},{0,0,1}};
  for ( inx := 1 ; inx <= 10 ; inx++ )
  { old_eigvecs := eigvecs;
    next_eigvecs := eigvecs*moments;  // left multiply since eigenvectors in rows
    eigvecs[1] := next_eigvecs[1]/sqrt(next_eigvecs[1]*next_eigvecs[1]);
    eigvecs[2] := next_eigvecs[2] - (next_eigvecs[2]*eigvecs[1])*eigvecs[1];
    eigvecs[2] /= sqrt(eigvecs[2]*eigvecs[2]); 
    eigvecs[3] := next_eigvecs[3] - (next_eigvecs[3]*eigvecs[1])*eigvecs[1]
                                  - (next_eigvecs[3]*eigvecs[2])*eigvecs[2];
    eigvecs[3] /= sqrt(eigvecs[3]*eigvecs[3]); 

    // calculate change
    diff := (old_eigvecs[1]-eigvecs[1])*(old_eigvecs[1]-eigvecs[1])
          + (old_eigvecs[2]-eigvecs[2])*(old_eigvecs[2]-eigvecs[2])
          + (old_eigvecs[3]-eigvecs[3])*(old_eigvecs[3]-eigvecs[3]);
    printf "Diff %15.12f\n",sqrt(diff);
  };

  // clean up
  unset facet quantity xx_moment;
  unset facet quantity xy_moment;
  unset facet quantity xz_moment;
  unset facet quantity yy_moment;
  unset facet quantity yz_moment;
  unset facet quantity zz_moment;

}

/********************************************************************************/

// Apply spherical harmonic constraint
apply := {
  set vertex constraint wall_con;
  set edge constraint wall_con;
  set facet constraint wall_con;
}

/********************************************************************************/

// Refine a lot to make smoother surface and show comparison.
apply2 := {
   { refine edge where length > 1; u; V; } 8;
   set facet color green; // so we can tell the two surfaces apart
   apply;    // set the constraint
   {u; V }10; // groom the mesh
   addload datafilename;
   set vertex x x-xcm where not on_constraint wall_con;
   set vertex y y-ycm where not on_constraint wall_con;
   set vertex z z-zcm where not on_constraint wall_con;
}

/********************************************************************************/
// Set guide constraint coefficients on contact line.
set_guide_flag := 0;  // whether guide constraint has been set
set_guide := { 
  local cnormal;
  define cnormal real[3];
  foreach vertex vv where sum(vv.facet,color==magenta) and sum(vv.facet,color==white) do
  { // normal of constraint plane is average of adjacent contact edge vectors
    cnormal := 0;
    foreach vv.edge ee where sum(ee.facet,color==magenta) and sum(ee.facet,color==white) do
      cnormal += edge[ee.id].edge_vector;
    vv.guide_coeffs := { cnormal[1], cnormal[2], cnormal[3], cnormal*vv.__x };
    set vv constraint guide_con;
  };
  set_guide_flag := 1;
}
/********************************************************************************/
// Set window titles.
set_titles := {
   if eigen_flag then
     title_string := sprintf"%s eigen %d (%4.2f,%4.2f,%4.2f)",basename,
      eigen_flag,slice_normal[1],slice_normal[2],slice_normal[3]
   else
     title_string := sprintf"%s  (%4.2f,%4.2f,%4.2f)",basename,
       slice_normal[1],slice_normal[2],slice_normal[3];
   console_title := title_string;
   graphics_title := title_string;
}

/********************************************************************************/

groom_shell := {

   // Sanity check for simply connected surface.
   euler_number := vertex_count - edge_count + facet_count;
   if euler_number != 2 then
   { errprintf "\n\n\n\n  FATAL ERROR: The surface is not simply connected!\n";
     if euler_number == 0 then
       errprintf "  There is 1 hole in it.\n"
     else errprintf "  There are %d holes in it.\n",(2-euler_number)/2;
     errprintf "\n\n\n\n";
     abort;
   };

   set vertex constraint liq_con;
   set edge constraint liq_con;
   set facet constraint liq_con;

   // Mesh grooming of whole surface.  Do before slicing, since original
   // surface can be very bad.
   // Start by just u,V, since edge deletions can lead to bad topology
   // changes.
   for ( inx := 1 ; inx <= 20; inx++ ) 
   { reset_counts;
     u; rawv;
     if equi_count == 0 then break;
   };

   // Now edge length grooming  
   groom_length := minimum( (max(vertex,x)-min(vertex,x)), 
         minimum((max(vertex,y)-min(vertex,y)), (max(vertex,z)-min(vertex,z))))/10;

   for(inx:=1; inx<=100; inx++)
   { refine edge where length > groom_length; 
     delete edge where length < groom_length/4;
     u; rawv;
     C;
     if check_count then
     { errprintf "\n\n\nERROR in create_slice: surface fails checks.\n\n\n";
       abort;
     };
     if inx > 5 and max(edge,dihedral) < 2 then break;
   };

   dumpname :=  sprintf"%s-%d.fe",basename,harmonic_order;
   dump dumpname;
   printf "showq; \n" >> dumpname;

} // end groom_shell

/********************************************************************************/


// Create slice surface and body.  Slice plane normal is // (nx,ny,nz), not
// necessarily a unit vector.  Do immediately after loading the datafile.
create_slice_flag := 0 // so you don't try to do this twice.
procedure create_slice(real nx, real ny, real nz)
{
   local nv,target_volume,inx;

   slice_normal := {nx,ny,nz};
   set_titles;
   // Using plane through center of mass as approximation for halving the volume.
   slice_a := nx;
   slice_b := ny;
   slice_c := nz;
   slice_d := sum(facet ff, (ff.facet_normal*slice_normal)*((ff.vertex[1].__x*slice_normal)^2
      + (ff.vertex[2].__x*slice_normal)^2 + (ff.vertex[3].__x*slice_normal)^2
      + (ff.vertex[1].__x*slice_normal)*(ff.vertex[2].__x*slice_normal)
      + (ff.vertex[1].__x*slice_normal)*(ff.vertex[3].__x*slice_normal)
      + (ff.vertex[2].__x*slice_normal)*(ff.vertex[3].__x*slice_normal)));
   slice_d /= 12*(nx^2 + ny^2 + nz^2)*body[1].volume;

   target_volume := abs(body[1].volume)/2;
   dissolve body[1];  // don't want it to interfere with the new body

   slicer;

   set vertex constraint liq_con;
   set edge constraint liq_con;

   // Check orientation
   if sum(facet ff, ff.facet_normal*ff.vertex[1].__x) < 0 then
   { reverse_orientation facets;
     set facet orientation 1;
   };

   foreach edge ee where valence==1 do 
   { set ee constraint slice_con;
     set ee.vertex constraint slice_con;
   };

   // fill in the inner surface
   foreach edge ee where valence == 1 do
   { start_e := ee.id;
     start_v := ee.vertex[1].id;
     center_v := new_vertex(0,0,0);
     start_radial := new_edge(center_v,ee.vertex[1].id);
     this_e := start_e;
     prev_radial := start_radial;
     for(;;) 
     { if edge[this_e].vertex[2].id == start_v then
         this_radial := start_radial
       else
         this_radial := new_edge(center_v,edge[this_e].vertex[2].id);
       this_f := new_facet(prev_radial,this_e,-this_radial); 
       facet[this_f].color := magenta;
       if edge[this_e].vertex[2].id == start_v then
         break;
       foreach edge[this_e].vertex[2].edge eee where eee.valence==1 and eee.id != abs(this_e) and eee.id != this_radial do
       { this_e := eee.oid;
         break;
       };
       prev_radial := this_radial;
     };
   };

   // Check orientation of inner surface
   if sum(facet ff where color==magenta,  ff.facet_normal * slice_normal) > 0 then
     foreach facet ff where color==magenta do
     { reverse_orientation ff;
       set ff orientation 1;
     };
   // Refine mesh, so get about 1000 facets on the slice.
   groom_length := sqrt(sum(facet where color==magenta,area)/200);
   do { reset_counts; 
        refine edge where not fixed and length > groom_length; u; V; u; V;
        delete edge where not fixed and length < groom_length/3;
      } while refine_count > 0;
   do 
   { refine edge where not fixed and length > groom_length; u; V; 
     groom_length *= 0.9;
   } while sum(facet, color==magenta) < 1000;

   // Fix vertices on contact surface that are not on the contact line and
   // remove constraint liq_con from them, to save calculation time.

   fix vertex vv where not fixed and sum(vv.facet, color==magenta) == 0; 
   unset vertex vv constraint liq_con where sum(vv.facet, color==magenta) == 0;
   unset vertex constraint slice_con;
   unset edge constraint slice_con;

   // Set contact facet tension to 0, for 90 degree contact angle.
   set facet tension 0 where color==white;

   slice_body := new_body;
   set facet frontbody slice_body where not fixed;  
   body[slice_body].target := target_volume;


   
   create_slice_flag := 1;

} // end create_slice()


/**************************************************************************************/

// Check for "ears", which are places where the contact line overruns the fixed white
// surface, despite regular grooming.
ear_check := {
 
  // Identify ears by finding folded-back edges with big dihedral angle.
  foreach vertex vv where sum(vv.edge, dihedral > 2.5) >= 2 do
  { // Find a third edge to delete.
    foreach vv.edge ee where dihedral < 0.5 do 
    { unfix vv;
      delete ee;
      break;
    }
  };
}
/**************************************************************************************/

// Mesh grooming, including around the contact line.
// Note: "groom" broken into separate stages for debugging purposes.
groom_length := 2;
groom_a := { reset_counts; refine edge where not no_refine and length > groom_length;
             if set_guide_flag and refine_count > 0 then set_guide; }
groom_b := {
   foreach edge ee where length < groom_length/4 and sum(ee.vertex,fixed) == 1 do
   { // Want to have vertex on contact line remain fixed
     foreach ee vertex vv do { if vv.fixed then unfix vv else fix vv; };
     delete ee;
   };
}
groom_c := {
   foreach facet ff where area < groom_length^2/32 do
   { // Again, want to keep vertices on contact line fixed while deleting.
     foreach ff.vertex vv do { if vv.fixed then unfix vv else fix vv; };
     delete ff;
   };
}
groom_d := {
   // clean up contact line
   unfix vertex vv where fixed and sum(vv.facet, color==magenta) > 0;
   set vertex vv constraint liq_con where not fixed and sum(vv.facet,color==magenta) > 0
      and sum(vv.facet,color==white) > 0;
   foreach vertex vv where not fixed and sum(vv.facet,color==magenta)==0 do
   { set vv constraint liq_con;
     fix vv;
     unset vv constraint liq_con;
   };
}
groom_e := { vertex_average vertex where not fixed and not on_constraint liq_con; }
groom_f := {
   local newx,ecount,ab,av;
   define newx real[3];
   define ab real[3];
   define av real[3];
   if not set_guide_flag then // average vertices along contact line, sideways
   {                          // averaging only, so as not to have contact line
                              // curvature move the contact line.
     foreach vertex vv where on_constraint liq_con do
     { newx := 0;
       ecount := 0;
       ab := 0;
       foreach vv.edge ee where sum(ee.facet,color==white)==1 do
       { ecount++;
         ab += (ecount==1 ? -1 : 1)*ee.edge_vector;
         if ecount == 1 then av := -ee.edge_vector;
       };
       if ecount == 2 then
          vv.__x += (0.5 - (ab*av)/(ab*ab))*ab;
     };
   };
}

groom := {

   ear_check;

   groom_a;
   groom_b;
   groom_c;
   u;
   groom_d;
   groom_e;
   groom_f;
} // end groom


/**************************************************************************************/

// Demonstration of evolution
gogo := {
  if not create_slice_flag then
    create_slice(1,1,0);
  show_trans "R20r4d"; // center the graphics image and rotate so can see inner surface
  show facet where not fixed;
  show edge ee where ee.facet[1] color!=green;
  fix vertex vv where sum(vv.facet,color==white)>0;
  m 0;
  g ;
  optimize; 
  g 10;
  groom;
  {g ; groom } 40;

} // end gogo

/**********************************************************************************/
// Final stage evolution.  Separated out so you can break the evolution with
// CTRL-C and resume.

go_final := {
  breakcount := 0;
  do 
  { old_energy := total_energy;
    g 5; groom;
    if old_energy - total_energy < 0.001 then breakcount++
    else breakcount := 0;
  } while breakcount < 5;

} // end go_final

/**********************************************************************************/
// Production run
procedure run(real nx, real ny, real nz)
{
  scale_limit := 0.1;  // to keep things from moving too fast

  slice_normal := {nx,ny,nz};

  set_titles;

  if not create_slice_flag then
    create_slice(nx,ny,nz);
  show_trans "R20r4d"; // center the graphics image and rotate so can see inner surface
  show facet where not fixed;
  show edge ee where ee.facet[1] color!=green;
  fix vertex vv where sum(vv.facet,color==white)>0;
  m 0;
  g ;
  optimize; 
  g 10;

  groom;

  // Coarse evolution; large steps with frequent grooming
  old_energy := total_energy;
  do
  {
    gcount := 0;
    do { g; gcount++ } while total_energy > old_energy - 0.1 and gcount < 5;
    old_energy := total_energy;   // note: groom can increase energy by more than .1,
                                  // so record old_energy here to prevent infinite cycling.
    groom; ear_check;
    if gcount == 5 then breakcount++
    else breakcount := 0;
  } while breakcount < 5;

  // Final stage
  set_guide; // so don't have to use vertex averaging on contact line
             // to prevent gaps from forming.
  conj_grad on;
  go_final;

  // Output products

  // Dump file
  if eigen_flag then
    dump sprintf "%s-eigen%d-%1.5f.dmp",basename,eigen_flag,total_energy
  else
    dump sprintf "%s-%g-%g-%g-%1.5f.dmp",basename,nx,ny,nz,total_energy;

  // STL file
  if eigen_flag then
    stlname := sprintf "%s-eigen%d-%1.5f.stl",basename,eigen_flag,total_energy
  else
    stlname := sprintf "%s-%g-%g-%g-%1.5f.stl",basename,nx,ny,nz,total_energy;
  stl >>> stlname;

  // Postscript file
  if eigen_flag then
    psfilename := sprintf "%s-eigen%d-%1.5f",basename,eigen_flag,total_energy
  else
    psfilename := sprintf "%s-%g-%g-%g-%1.5f",basename,nx,ny,nz,total_energy;
  postscript psfilename;

  // Results text file
  if eigen_flag then
    printf "Filename: %30s Normal: %4.2f %4.2f %4.2f  Energy: %15.10f eigendirection %d\n",
        basename, nx,ny,nz,total_energy,eigen_flag  >> "results.txt"
  else
    printf "Filename: %30s Normal: %4.2f %4.2f %4.2f  Energy: %15.10f\n",
        basename, nx,ny,nz,total_energy  >> "results.txt"

}  // end run

/*********************************************************************************************/

// Run with eigenvector plane.  Argument is which eigenvector plane:
// 1 for smallest section, 2 for middle, 3 for largest
procedure e_run(integer which_ev)
{
  if which_ev < 1 or which_ev > 3 then
  { errprintf "\n\n\nFATAL ERROR: e_run argument must be 1, 2, or 3. Was %d\n\n\n",which_ev;
    abort;
  };
  eigen_flag := which_ev;
  calc_principal_axes;
  run(eigvecs[which_ev][1],eigvecs[which_ev][2],eigvecs[which_ev][3]);
}


