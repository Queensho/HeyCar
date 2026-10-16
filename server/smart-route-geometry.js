// Geometry-only filtering: incident coordinates close to the actual route polyline.
const EARTH=6371000;
function rad(n){return n*Math.PI/180;}
function distanceMeters(a,b){
 const dLat=rad(b.lat-a.lat),dLon=rad(b.lon-a.lon);
 const h=Math.sin(dLat/2)**2+Math.cos(rad(a.lat))*Math.cos(rad(b.lat))*Math.sin(dLon/2)**2;
 return 2*EARTH*Math.asin(Math.min(1,Math.sqrt(h)));
}
function pointToSegmentMeters(p,a,b){
 const lat0=rad(p.lat),kx=111320*Math.cos(lat0),ky=111320;
 const ax=(a.lon-p.lon)*kx,ay=(a.lat-p.lat)*ky,bx=(b.lon-p.lon)*kx,by=(b.lat-p.lat)*ky;
 const dx=bx-ax,dy=by-ay,len=dx*dx+dy*dy;
 const t=len===0?0:Math.max(0,Math.min(1,-(ax*dx+ay*dy)/len));
 return Math.hypot(ax+t*dx,ay+t*dy);
}
function geometryPoints(geometry){
 if(!geometry||typeof geometry!=='object')return [];
 const coordinates=geometry.coordinates;
 if(!Array.isArray(coordinates))return [];
 const flat=[];
 function visit(v,depth){
  if(flat.length>=500||depth>5||!Array.isArray(v))return;
  if(v.length>=2&&typeof v[0]==='number'&&typeof v[1]==='number'){
   const p={lat:v[1],lon:v[0]};
   if(Number.isFinite(p.lat)&&Number.isFinite(p.lon)&&Math.abs(p.lat)<=90&&Math.abs(p.lon)<=180)flat.push(p);
   return;
  }
  for(const child of v)visit(child,depth+1);
 }
 visit(coordinates,0);
 return flat;
}
function matchIncidents(incidents,routeGeometry,thresholdMeters=250){
 if(!Array.isArray(routeGeometry)||routeGeometry.length<2)return {available:false,reason:'NO_ROUTE_GEOMETRY',incidents:[]};
 const path=routeGeometry.filter(p=>p&&Number.isFinite(p.lat)&&Number.isFinite(p.lon));
 if(path.length<2)return {available:false,reason:'NO_ROUTE_GEOMETRY',incidents:[]};
 const matches=[];
 for(const incident of incidents){
  const coords=geometryPoints(incident.geometry);
  if(!coords.length)continue;
  let min=Infinity;
  for(const p of coords){
   for(let i=1;i<path.length;i++){
    min=Math.min(min,pointToSegmentMeters(p,path[i-1],path[i]));
    if(min<=thresholdMeters)break;
   }
   if(min<=thresholdMeters)break;
  }
  if(min<=thresholdMeters)matches.push({...incident,distanceToRouteMeters:Math.round(min)});
 }
 return {available:true,matchMethod:'geometric_proximity_not_road_direction',thresholdMeters,incidents:matches};
}
module.exports={matchIncidents,distanceMeters};
