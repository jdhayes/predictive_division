

/* Surface Evolver datafile for surface dividing a region bounded
   by a triangular mesh.  

   For:
   Carolyn G Rasmussen <carolyn.rasmussen@ucr.edu>;
   Christopher Hoyt <choyt@g.hmc.edu>;
   Amir Moradifam <amir.moradifam@ucr.edu>;

   Programmer: Ken Brakke, brakke@susqu.edu, http://www.susqu.edu

   The original datafile was generated from Cell.stl by my program stl2fe.
   That produced the basic list of vertices, edges, and facets.  Then
   I have added further code to do interesting things.

   This file uses spherical harmonics to make a smooth approximation to
   the original triangulated shell.  The radius from the origin is
   expressed as a linear combination of spherical harmonics.

   To calculate spherical harmonics:
   Load datafile, and run CalcHarmonics(integer maxl), where maxl is
   the top order of harmonics you want.  The output is a single formula
   for the sum of all the coefficients times the appropriate harmonics.
   Redirect the output to a file, which can be included in a datafile
   wherever the spherical harmonic formula is needed.  For example:

       CalcHarmonics(10) >>> "HoytCell-10.inc"

   This package includes the files for 10 and 20 order expansions,
   HoytCell-10.inc and HoytCell-20.inc.  They are used in constraints
   wall_con and liq_con.  HoytCell-20.inc gives a more accurate approximation,
   but takes much longer in calculation.  I have written the constraints with
   lines for included both, but one line should be commented out.

   To see how well the smooth surface approximates the original, use the
   command "apply2".  This will refine the original surface, apply the
   wall_con constraint to it to make it the smooth surface, and color it
   green.  Then it will load the original file on top of that, so you
   wind up with the green smooth surface and the white original surface
   superposed.  This is just for visual inspection; don't try to evolve.

   To create a dividing surface, run the procedure create_slice(nx,ny,nz),
   where (nx,ny,nz) is the normal vector of the plane for the initial
   inner surface.  This function should be called immediately after 
   loading the datafile.  Besides creating a dividing surface, it also
   creates explicit contact facets to outline the entire body. Explicit
   contact facets are troublesome, which is why constraint integrals
   exist for energy and volume, but when the integrals get too bad, then
   explicit facets can be used, especially in the early stages of 
   development.  The dividing surface is colored magenta and the contact
   surface is white, so I can keep track of which part is which.
   Note that create_slice() creates the inner surface by adding the
   surface defined in the file inner.fe, so inner.fe must be present
   for create_slice() to work.

   A sample evolution: Load this datafile and run "gogo".  It creates
   an inner surface with normal (1,0,0) and evolves some.  The display
   is set up to make the original shell transparent and only show the
   inner surface and the contact surface.

*/

    

keep_originals

// Stuff for finding spherical harmonic coefficients
function real prod(real xx, real yy, real zz) { }

// Current spherical harmonic indexes
parameter lla = 3
parameter mma = 2

// Slice coefficients
parameter slice_a := 1
parameter slice_b := 0
parameter slice_c := 0
parameter slice_d := 0

// prototype, for SphericalHarmonics.cmd will be read in later.
function real LegendreP(integer ll,integer mm,real xx) {};

function real SphericalHarmonic(integer ll, integer mm, real zz, real phi) {};

quantity harm_coeff info_only method facet_vector_integral global
vector_integrand:
q1:  `ss := SphericalHarmonic(lla,mma,z/sqrt(x^2+y^2+z^2),atan2(y,x))/(x^2+y^2+z^2)`, ss*x
q2:  ss*y
q3:  ss*z

// Spherical harmonic constraint, for the wall
#define PHI atan2(y,x)
#define XX (z/sqrt(x^2+y^2+z^2))
constraint wall_con 
formula: sqrt(x^2+y^2+z^2) =
#include "harmonic.inc"

// Another copy of the spherical harmonic constraint, for the liquid surface.
parameter alpha = 1.0  // for gradual morphing of inner surface to shape
constraint liq_con 
formula: sqrt(x^2+y^2+z^2) = (1-alpha)*5 + alpha*
#include "harmonic.inc"

// Guide constraint, to prevent gaps growing on contact line.
define vertex attribute guide_coeffs real[4]
constraint guide_con 
formula: guide_coeffs[1]*x + guide_coeffs[2]*y + guide_coeffs[3]*z = guide_coeffs[4]



// Constraint for inner surface plane, just convenient to hold sliced edges in place
// while grooming the mesh.
constraint slice_con
formula: slice_a*x + slice_b*y + slice_c*z == slice_d


// Quantities for computing moment of inertia matrix, for principal axes.
quantity xx_moment info_only method facet_vector_integral
vector_integrand:
q1: 0
q2: 0
q3: x^2*z
quantity xy_moment info_only method facet_vector_integral
vector_integrand:
q1: 0
q2: 0
q3: x*y*z
quantity xz_moment info_only method facet_vector_integral
vector_integrand:
q1: 0
q2: x*z*y 
q3: 0
quantity yy_moment info_only method facet_vector_integral
vector_integrand:
q1: 0
q2: 0
q3: y^2*z
quantity yz_moment info_only method facet_vector_integral
vector_integrand:
q1: y*z*x
q2: 0
q3: 0
quantity zz_moment info_only method facet_vector_integral
vector_integrand:
q1: z^2*x 
q2: 0
q3: 0


