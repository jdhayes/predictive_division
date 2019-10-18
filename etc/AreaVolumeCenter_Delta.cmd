procedure area_volume_center_delta() {
    area_center_x := sum(facet ff,ff.area*avg(ff.vertex,x))/total_area;
    area_center_y := sum(facet ff,ff.area*avg(ff.vertex,y))/total_area;
    area_center_z := sum(facet ff,ff.area*avg(ff.vertex,z))/total_area;
    vol_center_x := sum(facet ff, ff.x*avg(ff.vertex,x^2/2))/body[1].volume;
    vol_center_y := sum(facet ff, ff.y*avg(ff.vertex,y^2/2))/body[1].volume;
    vol_center_z := sum(facet ff, ff.z*avg(ff.vertex,z^2/2))/body[1].volume;
    dist := sqrt((area_center_x-vol_center_x)^2
               + (area_center_y-vol_center_y)^2
               + (area_center_z-vol_center_z)^2);
    printf "Distance between area center and volume center: %18.10f\n", dist;
}
area_volume_center_delta()
