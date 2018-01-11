// stl2fe.c

// Conversion of STL (stereolithography) file format to Surface Evolver
// datafile.

// Usage: 
//    stl2fe [-a] [-b] [-e epsilon] [-s]  input.stl  output.fe

// Options:
//   -a       ASCII STL input format
//   -b       binary STL input format
//            If neither -a nor -b are given, the program will try
//            to detect the format type from the first bytes of the 
//            input file.
//   -e eps   Tolerance for identifying vertices. Default 1e-5.
//   -s       Swap byte order in binary format.

// Programmer: Ken Brakke, brakke@susqu.edu
// Date: September 7, 2005

/****************************************************************************

StL ASCII Format:
The ASCII .stl file must start with the lower case keyword solid and end
with endsolid. Within these keywords are listings of individual triangles 
that define the faces of the solid model. Each individual triangle description 
defines a single normal vector directed away from the solid's surface followed 
by the xyz components for all three of the vertices. These values are all in 
Cartesian coordinates and are floating point values. The triangle values 
should all be positive and contained within the building volume. 
The normal vector is a unit vector of length one based at the origin. If the 
normals are not included then most software will generate them using the 
right hand rule. If the normal information is not included then the three 
values should be set to 0.0. Below is a sample ASCII description of a single 
triangle within an STL file.

 solid
 ...

 facet normal 0.00 0.00 1.00
    outer loop
      vertex  2.00  2.00  0.00
      vertex -1.00  1.00  0.00
      vertex  0.00 -1.00  0.00
    endloop
  endfacet
 ...
 endsolid

STL Binary format:
  80 bytes irrelevant header (text id, etc)
   4 byte integer for number of facets
  50 byte facet structures
       3 floats normal
       9 floats vertex coordinates
       2 attributes size (unused) 
***************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#define DIM 3
#define FVERTS 3

struct vertex {
    double x[DIM];
    double s;  // sort coordinate
    int orig;  // vertex number before sorting
    int ident; // vertex to be identified with
  } *vlist;
int vcount;
int vmax;

struct edge {
    int v[2];  // vertex numbers
    int orig;
    int ident;
    int orient;
  } *elist;
int ecount;
int emax;

struct facet {
    int v[3];  // vertex numbers
    int e[3];  // edge numbers
  } * flist;
int fcount;
int facetmax;

FILE *stl_fd;
FILE *out_fd;

#define LINESIZE 1000
char line[LINESIZE];
int linenum = 0;
double epsilon = 1e-5;
int format_type;
#define ASCII_FORMAT 1
#define BINARY_FORMAT 2

#define NO_SWAP 0
#define DO_SWAP 1 
int endswap = -1;

int vcomp(const void *aa, const void *bb)
{ struct vertex *a = (struct vertex*)aa;
  struct vertex *b = (struct vertex*)bb;
  if ( a->s < b->s ) return -1;
  if ( a->s > b->s ) return  1;
  return 0;
}

int ecomp(const void *aa, const void *bb)
{ struct edge *a = (struct edge*)aa;
  struct edge *b = (struct edge*)bb;
  if ( a->v[0] < b->v[0] ) return -1;
  if ( a->v[0] > b->v[0] ) return  1;
  if ( a->v[1] < b->v[1] ) return -1;
  if ( a->v[1] > b->v[1] ) return  1;
  return 0;
}

void read_ascii()
{ int i;
  char *c;
  
  vmax = 10000;
  vlist = (struct vertex *)calloc(vmax,sizeof(struct vertex));

  emax = 10000;
  elist = (struct edge *)calloc(emax,sizeof(struct edge));

  facetmax = 10000;
  flist = (struct facet *)calloc(facetmax,sizeof(struct facet));

  while ( fgets(line,LINESIZE,stl_fd) )
  { linenum++;
    for ( c = line ; *c ; c++ ) *c = tolower(*c);
    if ( strstr(line,"facet") )
    { fgets(line,LINESIZE,stl_fd); // "outer loop"
      for ( c = line ; *c ; c++ ) *c = tolower(*c);
      linenum++;
      for ( i = 0 ; i < FVERTS  ; i++ )
      { int items;
        fgets(line,LINESIZE,stl_fd);
        for ( c = line ; *c ; c++ ) *c = tolower(*c);
        linenum++;
        items = sscanf(line," vertex %lf %lf %lf",vlist[vcount].x,
           vlist[vcount].x+1,vlist[vcount].x+2);
        if ( items != DIM )
        { fprintf(stderr,"Read only %d coordinates in line %d: %s.\n",
                 items,linenum,line);
        }
        flist[fcount].v[i] = vcount;
        vcount++;
      }
      fcount++;
      if ( fcount >= facetmax )
      { facetmax *= 2;
        flist = (struct facet*)realloc(flist,facetmax*sizeof(struct facet));
        if ( !flist )
        { fprintf(stderr,"Cannot allocate memory for facet list of length %d\n",
               facetmax);
          exit(4);
        }       
      }
      if ( vcount >= vmax-3 )
      { vmax *= 2;
        vlist = (struct vertex*)realloc(vlist,vmax*sizeof(struct vertex));
        if ( !vlist )
        { fprintf(stderr,"Cannot allocate memory for vertex list of length %d\n",
               vmax);
          exit(4);
        }       
      }
      fgets(line,LINESIZE,stl_fd);   // "endloop"
      linenum++;
      fgets(line,LINESIZE,stl_fd);   // "endfacet"
      linenum++;
    }
  }
}

void endian_reverse(void *a)
{ char c;
  c = ((char*)a)[0];
  ((char*)a)[0] = ((char*)a)[3];
  ((char*)a)[3] = c;
  c = ((char*)a)[1];
  ((char*)a)[1] = ((char*)a)[2];
  ((char*)a)[2] = c;
}

void read_binary()
{ unsigned int other;
  unsigned int count;
  int i,j;
  struct bin { float n[3];
               float x[3][3];
               short attr;
  } b;

  fseek(stl_fd,80,SEEK_SET);
  fread(&count,sizeof(int),1,stl_fd);
  if ( endswap == -1 )
  {
    other = count;
    endian_reverse(&other);
    if ( other < count )
    { endswap = DO_SWAP;
      count = other;
    }
    else endswap = NO_SWAP;
  }
  facetmax = count;
  flist = (struct facet*)calloc(facetmax,sizeof(struct facet));
  if ( !flist )
  { fprintf(stderr,"Cannot allocate memory for facet list of length %d\n",
        facetmax);
    exit(4);
  }       
  vmax = 3*facetmax;
  vlist = (struct vertex*)calloc(vmax,sizeof(struct vertex));
  if ( !vlist )
  { fprintf(stderr,"Cannot allocate memory for vertex list of length %d\n",
          vmax);
    exit(4);
  }       
  for ( fcount = 0 ; fcount < facetmax ; fcount++ )
  { fread(&b,12*sizeof(float)+sizeof(short int),1,stl_fd);
    if ( endswap )
    { for ( i = 0 ; i < DIM ; i++ )
      { endian_reverse(b.n+i);
        for ( j = 0 ; j < FVERTS ; j++ )
          endian_reverse(b.x[j]+i);
      }
    }
    for ( j = 0 ; j < FVERTS ; j++ )
    { for ( i = 0 ; i < DIM ; i++ )
        vlist[vcount].x[i] = b.x[j][i];
      flist[fcount].v[j] = vcount;
      vcount++;
    }
  }

}

main(int argc,char**argv)
{ int i,j,k;
  int *inxlist;
  int *e_inxlist;
  double dist;

  // read options
  for ( ; argc > 1 ; argc--, argv++ )
  { if ( argv[1][0] != '-' )
       break;
    switch (argv[1][1])
    { case 'a': format_type = ASCII_FORMAT; break;
      case 'b': format_type = BINARY_FORMAT; break;
      case 'e': epsilon = atof(argv[2]); argv++; argc--; break;
      case 's': endswap = DO_SWAP; break;
      default: 
      fprintf(stderr,"Usage: stl2fe [-a] [-b] [-e eps] [-s] input.stl [output.fe]\n");
      fprintf(stderr,"  -a       STL input file is in ASCII format\n");
      fprintf(stderr,"  -b       STL input file is in binary format\n");
      fprintf(stderr,"  -e eps   Tolerance for identifying vertices; default 1e-5.\n");
      fprintf(stderr,"  -s       binary data is wrong endian; byte order needs swapping\n");
      fprintf(stderr,"If options are not given, stl2fe will try to detect from input.\n");
      fprintf(stderr,"If output file name is not given, output is to stdout.\n");
      exit(0);
    }
  }


  if ( argc < 2 )
  { fprintf(stderr,"FATAL ERROR: Need STL input filename on command line.\n");
    exit(2);
  }
  stl_fd = fopen(argv[1],"rb");
  if ( stl_fd == NULL )
  { perror(argv[1]); 
    exit(1);
  }

  if ( argv[2] )
  { out_fd = fopen(argv[2],"w");
    if ( stl_fd == NULL )
    { perror(argv[1]); 
      exit(1);
    }
  }
  else 
    out_fd = stdout;

  // detect type
  if ( format_type == 0 )
  { char *s;
    size_t num;
    int bads = 0;
    int spot;

    num = fread(line,1,LINESIZE-100,stl_fd);
    for ( spot = 0 ; spot < num ; spot++ )
      if ( line[spot] & 0x80 )
        bads++;
    if ( bads < 3 )
      format_type = ASCII_FORMAT;
    else format_type = BINARY_FORMAT;
    fseek(stl_fd,0,SEEK_SET);
  }
  
  // read in data
  if ( format_type == ASCII_FORMAT )
    read_ascii();
  else read_binary();


  // sort vertices along random direction in space
  for ( i = 0 ; i < vcount ; i++ )
  { vlist[i].orig = i;
    vlist[i].s = 0.4573*vlist[i].x[0] + 0.55413*vlist[i].x[1] 
                  + 0.62546*vlist[i].x[2];
  }
  qsort(vlist,vcount,sizeof(struct vertex),vcomp);

  // Go through list and uniquify.  For each vertex, hunt backwards for
  // match until known to be beyond epsilon.
  for ( i = 1 ; i < vcount ; i++ )
  { vlist[i].ident = i;
    for ( j = i-1 ; j >= 0 ; j-- )
    { if ( vlist[j].s < vlist[i].s - epsilon ) 
        break;
      for ( k = 0, dist = 0.0 ; k < DIM ; k++ )
        dist += (vlist[j].x[k] - vlist[i].x[k])*(vlist[j].x[k] - vlist[i].x[k]);
      if ( sqrt(dist) <= epsilon )
      { vlist[i].ident = vlist[j].ident;
        break;
      }
    }
  }
  
  // construct index list
  inxlist = (int *)calloc(vcount,sizeof(int));
  if ( !inxlist )
  { fprintf(stderr,"Cannot allocate memory for inxlist of length %d\n",vcount);
    exit(4);
  } 
  for ( i = 0 ; i < vcount ; i++ )
   inxlist[vlist[i].orig] = vlist[i].ident;

  // convert data in facet list
  for ( i = 0 ; i < fcount ; i++ )
    for ( k = 0 ; k < FVERTS ; k++ )
      flist[i].v[k] = inxlist[flist[i].v[k]];

  // construct edge list
  emax = 3*fcount;
  elist = (struct edge *)calloc(emax,sizeof(struct edge));
  if ( !elist )
  { fprintf(stderr,"Cannot allocate memory for edge list of length %d\n",emax);
    exit(4);
  } 
  for ( i = 0, ecount = 0 ; i < fcount ; i++ )
  { elist[ecount].v[0] = flist[i].v[0];
    elist[ecount].v[1] = flist[i].v[1];
    flist[i].e[0] = ecount;
    ecount++;
    elist[ecount].v[0] = flist[i].v[1];
    elist[ecount].v[1] = flist[i].v[2];
    flist[i].e[1] = ecount;
    ecount++;
    elist[ecount].v[0] = flist[i].v[2];
    elist[ecount].v[1] = flist[i].v[0];
    flist[i].e[2] = ecount;
    ecount++;
  }
  
  // identify reversed edges
  for ( i = 0 ; i < ecount ; i++ )
  { elist[i].orig = i;
    if ( elist[i].v[0] > elist[i].v[1] )
    { int tmp = elist[i].v[0];
      elist[i].v[0] = elist[i].v[1];
      elist[i].v[1] = tmp;
      elist[i].orient = -1;
    }
    else elist[i].orient = 1;
  }
  qsort(elist,ecount,sizeof(struct edge),ecomp);
  for ( i = 1 ; i < ecount ; i++ )
  { elist[i].ident = i;
    if ( elist[i].v[0] == elist[i-1].v[0] &&
         elist[i].v[1] == elist[i-1].v[1] )
      elist[i].ident = elist[i-1].ident;
  }
  // reverse index list
  e_inxlist = (int *)calloc(ecount,sizeof(int));
  if ( !e_inxlist )
  { fprintf(stderr,"Cannot allocate memory for e_inxlist of length %d\n",ecount);
    exit(4);
  } 
  for ( i = 0 ; i < ecount ; i++ )
     e_inxlist[elist[i].orig] = elist[i].orient > 0 ? elist[i].ident+1 :
          -(elist[i].ident+1);
  // update facets
  for ( i = 0 ; i < fcount ; i++ )
    for ( j = 0 ; j < FVERTS ; j++ )
      flist[i].e[j] = e_inxlist[flist[i].e[j]];

  // write datafile
  if ( argv[2] )
    fprintf(out_fd,"// %s\n",argv[2]);
  fprintf(out_fd,"// Surface Evolver datafile generated from %s by stl2fe\n\n",argv[1]);
  fputs("keep_originals\n\n",out_fd);
  fputs("vertices\n",out_fd);
  for ( i = 0 ; i < vcount ; i++ )
    if ( vlist[i].ident == i )
      fprintf(out_fd,"%d  %18.15f %18.15f %18.15f\n",i+1,vlist[i].x[0],vlist[i].x[1],
             vlist[i].x[2]);
  fputs("\nedges\n",out_fd);
  for ( i = 0 ; i < ecount ; i++ )
    if ( elist[i].ident == i )
      fprintf(out_fd,"%d  %d %d\n",i+1,elist[i].v[0]+1,elist[i].v[1]+1);
  fputs("\nfacets\n",out_fd);
  for ( i = 0 ; i < fcount ; i++ )
    fprintf(out_fd,"%d  %d %d %d\n",i+1,flist[i].e[0],flist[i].e[1],flist[i].e[2]);
}

