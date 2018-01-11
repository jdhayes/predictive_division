/* SphericalHarmonics.cmd

   Spherical harmonics functions.

   Ref: https://en.wikipedia.org/wiki/Spherical_harmonics

*/

/* Associated Legendre polynomials
   Ref: https://en.wikipedia.org/wiki/Associated_Legendre_polynomials#Recurrence_formula
*/

function real LegendreP(integer ll, integer mm, real xx)
{
   local inx,pmm,pmm1,pma,pmb,nn,doubfac,pmn;

   if mm < 0 or mm > ll then 
   { errprintf "\nLegendreP ERROR: Illegal arguments: m %d  l %d. Must have 0 <= m <= l.\n\n",mm,ll;
     abort;
   };
   if xx^2 > 1 then 
   { errprintf "\nLegendreP ERROR: Illegal argument: x = %f. Must have -1 <= x <= 1.\n\n",xx;
     abort;
   };

   // start of recursion, using first recursion formula in ref
   doubfac := 1; 
   for ( inx := 3 ; inx < 2*mm ; inx+=2 ) doubfac *= inx;
   pmm := (mm imod 2 ? -1 : 1)*doubfac*(1 - xx^2)^(mm/2);
   if ll == mm then return pmm;

   // for l = m + 1
   pmm1 := xx*(2*mm+1)*pmm;
   if ll == mm + 1 then return pmm1;

   // Apply recursion
   pma := pmm;
   pmb := pmm1;
   for ( nn := mm+2 ; nn <= ll ; nn++ )
   { pmn := ( (2*nn-1)*xx*pmb - (nn-1+mm)*pma )/(nn - mm);
     pma := pmb;
     pmb := pmn;
   };

   return pmn;
   
}

// Spherical harmonics, scaled to be orthogonal with respect to integration over unit sphere.
// These are the real versions, mm < 0 for sin part, mm >= 0 for cos part.
// Input: ll, mm as usual
//        xx is cos(theta), theta is angle from north pole
//        phi is longitude
function real SphericalHarmonic(integer ll, integer mm, real xx, real phi)
{ local coeff,nn;

if abs(mm) > ll then { errprintf "\n\nFATAL ERROR SphericalHarmonic ll < abs(mm); ll = %d  mm = %d\n\n\n",ll,mm; };

  coeff := (2*ll + 1)/4/Pi;
  for ( nn := ll - abs(mm) + 1 ; nn <= ll+abs(mm) ; nn++ ) coeff /= nn;
  if mm == 0 then return sqrt(coeff)*LegendreP(ll,0,xx);
  if mm <= 0 then return sqrt(2*coeff)*LegendreP(ll,-mm,xx)*sin(-mm*phi);
  return sqrt(2*coeff)*LegendreP(ll,mm,xx)*cos(mm*phi);
}


// Printing out formulas for spherical harmonics, for use in datafiles.

// First, coefficients for associated Legendre polynomials, omitting the
// sqrt(1-x^2) term for odd m.
define LegendreCoeff real[1][1][1];  // returned values; indexes m+1,l+1,k+1, k is power of x.
Legendre_max := -1;  // to record current state of LegendreCoeff
procedure CalcLegendreCoeff(integer maxl)
{ local ll,kk,mm,inx;
  define LegendreCoeff real[maxl+1][maxl+1][maxl+1];
  LegendreCoeff := 0;
  Legendre_max := maxl;

  // First, plain Legendre polynomials (m=0)
  LegendreCoeff[1][1][1] := 1;
  LegendreCoeff[2][1][2] := 1;
  for ( ll := 2 ; ll <= maxl ; ll++ )
    for ( kk := 0 ; kk <= ll ; kk++ )
    { LegendreCoeff[ll+1][1][kk+1] += ( (kk==0? 0 : (2*ll-1)*LegendreCoeff[ll][1][kk]) - (ll-1)*LegendreCoeff[ll-1][1][kk+1])/ll;
    };

  // Now, associated Legendre polynomials by the derivative definition.
  // First the derivatives alone.
  for ( ll := 0 ; ll <= maxl ; ll++ )
    for ( mm := 1 ; mm <= ll ; mm++ )
      for ( kk := 0 ; kk < ll ; kk++ )
        LegendreCoeff[ll+1][mm+1][kk+1] := (kk+1)*LegendreCoeff[ll+1][mm][kk+2];

  // And then the multiplication by (1-x^2)^(m/2)
  for ( ll := 0 ; ll <= maxl ; ll++ )
    for ( mm := 0 ; mm <= ll ; mm++ )
      for ( inx := 2 ; inx <= mm ; inx += 2 )
        for ( kk := ll ; kk >= 2 ; kk-- )
          LegendreCoeff[ll+1][mm+1][kk+1] -= LegendreCoeff[ll+1][mm+1][kk-1];

}

// Spherical harmonic term coefficients, SphHarm_a[ll+1][ll+mm+1]
define SphHarmTermCoeff real[1][1];
procedure CalcSphHarmTermCoeff(integer max_l)
{ local mm,ll,aa,nn;
  define SphHarmTermCoeff real[max_l+1][2*max_l+1];
  for ( ll := 0 ; ll <= max_l ; ll++ )
    for ( mm := -ll ; mm <= ll ; mm++ )
    {
      aa := (2*ll + 1)/4/Pi;
      for ( nn := ll - abs(mm) + 1 ; nn <= ll+abs(mm) ; nn++ ) aa /= nn;
      aa := sqrt(aa);
      if mm != 0 then aa *= sqrt(2.0);
      if mm mod 2 then aa := -aa;
      SphHarmTermCoeff[ll+1][ll+mm+1] := aa;
    };
}

// Printing spherical harmonics.
procedure SphHarmPrint(integer ll, integer mm)
{
  local coeff,nn,first,kk;

  if Legendre_max < ll then CalcLegendreCoeff(ll);

  coeff := (2*ll + 1)/4/Pi;
  for ( nn := ll - abs(mm) + 1 ; nn <= ll+abs(mm) ; nn++ ) coeff /= nn;
  coeff := sqrt(coeff);
  if mm != 0 then coeff *= sqrt(2.0);
  if mm mod 2 then coeff := -coeff;
  if mm < 0 then
    printf "%17.15g*sin(%d*PHI)*",coeff,-mm
  else if mm == 0 then
    printf "%17.15g*",coeff
  else
    printf "%17.15f*cos(%d*PHI)*",coeff,mm;
  if mm imod 2 then
    printf "sqrt(1-XX^2)*";
  first := 1;
  printf "(";
  for ( kk := 0 ; kk <= ll ; kk++ )
    if LegendreCoeff[ll+1][abs(mm)+1][kk+1] != 0.0 then
    { if !first and LegendreCoeff[ll+1][abs(mm)+1][kk+1] > 0 then printf "+";
      if kk == 0 then
        printf "%1.15g",LegendreCoeff[ll+1][abs(mm)+1][kk+1]
      else if kk == 1 then
        printf "%1.15g*XX",LegendreCoeff[ll+1][abs(mm)+1][kk+1]
      else
        printf "%1.15g*XX^%d",LegendreCoeff[ll+1][abs(mm)+1][kk+1],kk;
      first := 0;
    };
  printf ")";
}

// Print full expansion, using experimentally derived coefficents.
define HarmonicCoeff real[1][1]
procedure SphHarmPrintAll(integer maxl)
{ local ll,mm,first;
  if Legendre_max < maxl then CalcLegendreCoeff(maxl);
  first := 1;
  for ( ll := 0 ; ll <= maxl ; ll++ )
  { for ( mm := -ll ; mm <= ll ; mm++ )
    { if not first then printf "+ ";
      printf "%1.15g*",HarmonicCoeff[ll+1][ll+1+mm];
      SphHarmPrint(ll,mm);
      if mm < maxl then printf "\\\n" else printf "\n";
      first := 0;
    }
  }
}


// Alternate way to print full expansion, using gathered common powers
 
procedure AltSphHarmPrintAll(integer max_l)
{ local mm,kk,ll,coeff_sum,first,leadterm;

  CalcSphHarmTermCoeff(max_l);

  printf "( ";
  first := 1;
  for ( mm := -max_l ; mm <= max_l ; mm++ )
  { 
    if not first then
    { printf " + ";
    }
    else first := 0;
    if mm imod 2 then
      printf "sqrt(1-XX^2)*";
    if mm < 0 then
      printf "sin(%d*PHI)*(",-mm
    else if mm > 0 then
      printf "cos(%d*PHI)*(",mm
    else printf "(";

    leadterm := 1;
    for ( kk := 0 ; kk <= max_l ; kk++ )
    { 
      coeff_sum := 0.0;
      for ( ll := abs(mm) ; ll <= max_l ; ll++ )
        coeff_sum += HarmonicCoeff[ll+1][ll+mm+1]*SphHarmTermCoeff[ll+1][ll+mm+1]*LegendreCoeff[ll+1][abs(mm)+1][kk+1];
      if coeff_sum != 0.0 then 
      { 
        if not leadterm and coeff_sum > 0 then printf " +";
        if kk == 0 then printf " %16.15f",coeff_sum
        else if kk == 1 then printf " %16.15f*XX",coeff_sum
        else printf " %16.15f*XX^%d",coeff_sum,kk;
        leadterm := 0;
      }
    };
    printf ") \n"; 
  };
  printf ")\n\n";  
    
}

