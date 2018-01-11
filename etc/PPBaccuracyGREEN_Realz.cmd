procedure PPBaccuracy(string PPB_filelocation)
{
  set face color grey where color==white;
  
  ADDLOAD "PPBFILE";
set face color green where color==white;
  foreach vertex vv where vv.facet[1] color==green do
  {
    vv.x := vv.x-xcm;
    vv.y := vv.y-ycm;
    vv.z := vv.z-zcm;
  };

  define ppbmean real[3];
  ppbmean := {sum(facet ff where color==green, ff.x*avg(ff.vertex,x^2/2))/body[new_b].volume,
        sum(facet ff where color==green, ff.y*avg(ff.vertex,y^2/2))/body[new_b].volume,
        sum(facet ff where color==green, ff.z*avg(ff.vertex,z^2/2))/body[new_b].volume};

  local moments,next_eigvecs,old_eigvecs;
  define moments real[3][3];
  define next_eigvecs real[3][3];  
  define old_eigvecs real[3][3];  

  set facet quantity xx_moment where color==green;
  set facet quantity xy_moment where color==green;
  set facet quantity xz_moment where color==green;
  set facet quantity yy_moment where color==green;
  set facet quantity yz_moment where color==green;
  set facet quantity zz_moment where color==green;

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
  };

  // clean up
  unset facet quantity xx_moment where color==green;
  unset facet quantity xy_moment where color==green;
  unset facet quantity xz_moment where color==green;
  unset facet quantity yy_moment where color==green;
  unset facet quantity yz_moment where color==green;
  unset facet quantity zz_moment where color==green;;


  define norm real[3];
  norm := eigvecs[3];

  tanPhi := (norm[3]*norm[3])/(norm[1]*norm[1] + norm[2]*norm[2]);

  if tanPhi>1 then {print "Warning: normal vector is mainly vertical";};

  totalDistanceSq := 0;
  totalLength   := 0;

  foreach edge ee where ee.facet[1] color!=ee.facet[2] color do
  {
    define e1 real[3];
    e1 := ee.vertex[1].__x;

    define e2 real[3];
    e2 := ee.vertex[2].__x;
    
    Dist := ((0.5*e1+0.5*e2-ppbmean)*norm) / (norm*norm);
    
    ProjLen := ( (e2-e1)*(e2-e1) - ((norm*(e2-e1))^2/(norm*norm)) )^0.5;
   

    totalDistanceSq := totalDistanceSq + (Dist^2*ProjLen);
    totalLength := totalLength + (ProjLen);
  };

  print totalDistanceSq/totalLength;

}    
set background white;

PPBaccuracy("PPBFILE");
