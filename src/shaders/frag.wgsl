const PI: f32 = 3.14159265358979323846;
const TAU: f32 = 2.0 * PI;
const MAX_F32: f32 = 0x1.fffffep+127f;

const SCREEN_WIDTH: f32 = 1376.0;
const SCREEN_HEIGHT: f32 = 768.0;
const ASPECT: f32 = SCREEN_WIDTH / SCREEN_HEIGHT;
const INV_ASPECT: f32 = SCREEN_HEIGHT / SCREEN_WIDTH;
// Used extremely low FOV to reduce edge distortion of moon sdf
// Combined with placing the camera extremely far from the objects (800.0 on z-axis)
const FOV: f32 = 0.1708; // 9.78611914 degrees

const TEX_WIDTH: f32 = 2048.0;
const TEX_HEIGHT: f32 = 2048.0;
const TEX_DIM: vec2<f32> = vec2(TEX_WIDTH, TEX_HEIGHT);

const CENTER: vec3<f32> = vec3(0.0);
const PLANET_ROTATION: f32 = 0.1;
const PLANET_RADIUS: f32 = 50.0;

const MOON_RADIUS: f32 = 5.0;
const MOON_ORBIT_SPEED: f32 = 0.7;
const MOON_ORBIT_RADIUS: f32 = 75.0;
const MOON_ORBIT_INCLINATION: f32 = 5.0;

const WATER_LEVEL: f32 = 50.3;
const SAND_LEVEL: f32 = WATER_LEVEL + 0.2 ;
const VEGETATION_LEVEL: f32 = WATER_LEVEL + 2.2;
const ICE_LEVEL: f32 = WATER_LEVEL + 3.8;

const SAND_CLR: vec3<f32> = vec3(0.8, 0.8, 0.1);
const PLANT_CLR1: vec3<f32> = vec3(0.05, 0.8, 0.02);
const PLANT_CLR2: vec3<f32> = vec3(0.0, 0.3, 0.07);
const EARTH_CLR: vec3<f32> = vec3(0.3, 0.18, 0.1);
const ROCK_CLR: vec3<f32> = vec3(0.2, 0.2, 0.2);
const ICE_CLR: vec3<f32> = vec3(1.0, 1.0, 1.0);

const m2: mat2x2<f32> = mat2x2(
  0.80, 0.60,
  -0.60, 0.80,
);

const m2Inv: mat2x2<f32> = mat2x2(
  0.80, -0.60,
  0.60, 0.80,
);

struct TimeUniform {
    time: f32,
};

struct RayParams {
  epsilon: f32,
  max_dist: f32,
  max_steps: f32,
}
struct ViewParams {
  x_shift: f32,
  y_shift: f32,
  x_rot: f32,
  y_rot: f32,
  zoom: f32,
  time_modifier: f32,
}

// GROUPS AND BINDINGS
@group(0) @binding(0) var<uniform> tu: TimeUniform;

@group(1) @binding(0) var<storage, read_write> rp: RayParams;
@group(1) @binding(1) var<storage, read_write> vp: ViewParams;
@group(1) @binding(8) var<storage, read_write> debug_arr: array<vec4<f32>>;
@group(1) @binding(9) var<storage, read_write> debug: vec4<f32>;

@group(2) @binding(0) var terrain: texture_2d<f32>;
@group(2) @binding(1) var terrain_sampler: sampler;
@group(2) @binding(2) var ice: texture_2d<f32>;
@group(2) @binding(3) var ice_sampler: sampler;

// ASPECT RATIO
fn scale_aspect(fc: vec2<f32>) -> vec2<f32> {
  // Scale from screen dimensions to 0.0 --> 1.0
  var uv: vec2<f32> = ((2.0 * fc) / vec2(SCREEN_WIDTH, SCREEN_HEIGHT)) - 1.0;
  uv.y = -uv.y * INV_ASPECT;
  return uv;
}

fn sphereSDF(pos: vec3<f32>, radius: f32) -> f32 {
  return length(pos) - radius;
}

// LIGHTING
fn get_normal(pos: vec3<f32>, uv: vec2<f32>) -> vec3<f32> {
  let e = vec2(rp.epsilon, 0.0);
  let n = vec3(map(pos, uv).dist) - 
  vec3(
    map(pos - e.xyy, uv).dist,
    map(pos - e.yxy, uv).dist,
    map(pos - e.yyx, uv).dist
  );

  return normalize(n);
}

fn get_ambient_occlusion(pos: vec3<f32>, normal: vec3<f32>, uv: vec2<f32>) -> f32 {
  var occ = 0.0;
  var weight = 0.4;

  for (var i: i32 = 0; i < 8; i++) {
    let len = 0.01 + 0.02 * f32(i * i);
    let dist = map(pos + normal * len, uv).dist;
    occ += (len - dist) * weight;
    weight *= 0.85;
  }

  return 1.0 - clamp(0.6 * occ, 0.0, 1.0);
}

fn get_soft_shadow(pos: vec3<f32>, light_pos: vec3<f32>, uv: vec2<f32>) -> f32 {
  var res = 1.0;
  var dist = 0.01;
  let light_size = 0.1;

  for (var i: i32 = 0; i < 8; i++) {
    let hit = map(pos + light_pos * dist, uv).dist;
    res = min(res, hit / (dist * light_size));
    if (hit < rp.epsilon) { break; }
    dist += hit;
    if (dist > 40.0) { break; }
  }

  return clamp(res, 0.0, 1.0);
}

fn get_light(pos: vec3<f32>, rd: vec3<f32>, uv: vec2<f32>) -> vec3<f32> {
  var light_pos: vec3<f32> = vec3(100.0, 100.0, 100.0);
  let color: vec3<f32> = vec3(1.0);

  let l: vec3<f32> = normalize(light_pos - pos);
  let normal: vec3<f32> = get_normal(pos, uv);

  let v: vec3<f32> = -rd;
  let r: vec3<f32> = reflect(-l, normal);

  let diff: f32 = 0.70 * max(dot(l, normal), 0.0);
  let specular: f32 = 0.1 * pow(clamp(dot(r, v), 0.0, 1.0), 10.0);
  let ambient: f32 = 0.10; 

  let shadow: f32 = get_soft_shadow(pos, light_pos, uv);
  let occ: f32 = get_ambient_occlusion(pos, normal, uv);

  return (ambient * occ + (specular * occ + diff) * shadow) * color;
}

// CAMERA

fn get_cam(ro: vec3<f32>, look_at: vec3<f32>) -> mat4x4<f32> {
  let camf = normalize(vec3(look_at - ro));
  let camr = normalize(cross(vec3(0.0, 1.0, 0.0), camf));
  let camu = cross(camf, camr);
  let camd = vec4(-ro.x, -ro.y, -ro.z, 1.0);

  return mat4x4(
    vec4(camr, 0.0), 
    vec4(camu, 0.0), 
    vec4(camf, 0.0), 
    camd
  );
}

fn rotate3d(v: vec3<f32>, angleX: f32, angleY: f32) -> vec3<f32> {
 let saX = sin(angleX);
 let caX = cos(angleX);
 let saY = sin(angleY);
 let caY = cos(angleY);

 // Rotation matrix for X-axis rotation
 let mtxX = mat3x3<f32>(
    1.0, 0.0, 0.0,
    0.0, caX, -saX,
    0.0, saX, caX
 );

 // Rotation matrix for Y-axis rotation
 let mtxY = mat3x3<f32>(
    caY, 0.0, saY,
    0.0, 1.0, 0.0,
    -saY, 0.0, caY
 );

 let rotatedX = v * mtxX;
 let rotatedY = rotatedX * mtxY;

 return rotatedY;
}

fn sRGB_to_linear(sRGB: vec3<f32>) -> vec3<f32> {
  var linear: vec3<f32> = vec3(0.0);
  let cr = sRGB.r;
  let cg = sRGB.g;
  let cb = sRGB.b;
  let cr_check = step(cr, 0.04045);
  let cg_check = step(cg, 0.04045);
  let cb_check = step(cb, 0.04045);
  
  linear.r = cr_check*(cr / 12.92) + (1.0 - cr_check)*pow((cr + 0.055) / 1.055, 2.4);
  linear.g = cg_check*(cg / 12.92) + (1.0 - cg_check)*pow((cg + 0.055) / 1.055, 2.4);
  linear.b = cb_check*(cb / 12.92) + (1.0 - cb_check)*pow((cb + 0.055) / 1.055, 2.4);

  return linear;
}


// TERRAIN/TEXTURE MAPPING
fn ice_uniplanar_mapping(pos: vec3<f32>, uv: vec2<f32>, radius: f32) -> vec3<f32> {
  let l = length(pos);
  
  // Calculate tex coordinates for Y plane
  var tex_XZ = vec2(pos.x / l, pos.z / l) * 0.5 + 0.5;
  
  // Calc normal, exp to sharpen borders between planes
  var n = abs(get_normal_rm(pos, radius));
  n *= n*n*n*n*n;
  n /= n.x + n.y + n.z;

  var XZ: vec3<f32> = textureSample(terrain, terrain_sampler, tex_XZ).rgb * n.y;
  XZ = sRGB_to_linear(XZ);
  return XZ;
}

fn tex_triplanar_mapping(pos: vec3<f32>, uv: vec2<f32>, radius: f32) -> vec2<f32> {
  let amp = 10.0;
  let l = length(pos);
  
  // Calculate tex coordinates for each of the 3 planes
  // Shift slightly to avoid symmetries
  var tex_XY = vec2(pos.x / l, pos.y / l) * 0.5 + 0.49;
  var tex_XZ = vec2(pos.x / l, pos.z / l) * 0.5 + 0.51;
  var tex_YZ = vec2(pos.y / l, pos.z / l) * 0.5 + 0.53;
  
  // Calc normal, exp to sharpen borders between planes
  var n = abs(get_normal_rm(pos, radius));
  n *= n*n*n*n*n;
  n /= n.x + n.y + n.z;

  let XY: vec2<f32> = textureSample(terrain, terrain_sampler, tex_XY).xy * amp * n.z;
  let XZ: vec2<f32> = textureSample(terrain, terrain_sampler, tex_XZ).xy * amp * n.y;
  let YZ: vec2<f32> = textureSample(terrain, terrain_sampler, tex_YZ).xy * amp * n.x;

  return XY + XZ + YZ;
}


fn calculate_slope(pos: vec3<f32>, uv: vec2<f32>) -> f32 {
    let r_vec = normalize(pos);
    let n_vec = get_normal(pos, uv);
    let dp = dot(r_vec, n_vec);
    let angle = acos(dp);
    let slope_in_degrees = degrees(angle);

    return slope_in_degrees;
}

fn map_sphere(pos: vec3<f32>, radius: f32) -> f32 {
  return sphereSDF(pos, radius);
}

fn get_moon_position() -> vec3<f32> {
  let angle = tu.time*MOON_ORBIT_SPEED;
  let x = MOON_ORBIT_RADIUS*cos(angle);
  let z = MOON_ORBIT_RADIUS*sin(angle);
  let y = MOON_ORBIT_INCLINATION*sin(angle)*3.0;

  return vec3(x, y - MOON_ORBIT_INCLINATION - x*0.01, z);
}

struct Terrain {
  dist: f32,
  water_depth: f32,
}

fn get_terrain(pos: vec3<f32>, uv: vec2<f32>) -> Terrain {
  let rPos = rotate3d(pos, 0.0, PLANET_ROTATION*tu.time);
  var d1 = sphereSDF(rPos, PLANET_RADIUS);
  let moon_offset = get_moon_position();
  var moon = sphereSDF(pos + moon_offset, MOON_RADIUS);
  var d0 = d1;
  
  let ptx = tex_triplanar_mapping(rPos, uv, PLANET_RADIUS);
  d1 += ptx.x;
  
  let water_depth = max(0.0, d1 - d0);
  d1 = min(d0, d1);
  d1 = min(moon, d1);
  
  return Terrain(d1, water_depth);
}

fn map(pos: vec3<f32>, uv: vec2<f32>) -> Terrain {
  var d = 0.0;
  
  let t = get_terrain(pos, uv);
  d += t.dist;

  return Terrain(d, t.water_depth);
}

// RAY MARCHING
fn get_normal_rm(pos: vec3<f32>, radius: f32) -> vec3<f32> {
  let e = vec2(rp.epsilon, 0.0);
  let n = vec3(map_sphere(pos, radius)) - 
    vec3(
      map_sphere(pos - e.xyy, radius), 
      map_sphere(pos - e.yxy, radius), 
      map_sphere(pos - e.yyx, radius)
    );

  return normalize(n);
}

struct TerrainPos {
  dist: f32,
  water_depth: f32,
  pos: vec3<f32>,
}

fn ray_march(ro: vec3<f32>, rd: vec3<f32>, uv: vec2<f32>) -> TerrainPos {
  let steps = i32(rp.max_steps);

  var dist = 0.0;
  var water_depth = 0.0;
  var p = vec3(0.0);

  for (var i: i32 = 0; i < steps; i++) {
    let pos = ro + dist * rd;
    let t = map(pos, uv);
    let hit = t.dist;
    water_depth = t.water_depth; 
    p = pos;

    if (abs(hit) < rp.epsilon) {
      break;
    }
    dist += hit;

    if (dist > rp.max_dist) {
      break;
    }
  }

  return TerrainPos(dist, water_depth, p);
}

// RENDERING
fn render(uv: vec2<f32>) -> vec3<f32> {
  var ro: vec3<f32> = vec3(0.0, 0.0, 800.0);
  ro = rotate3d(ro, vp.y_rot, vp.x_rot);

  let look_at: vec3<f32> = vec3(0.0, 0.0, 0.0);
  
  var rd: vec3<f32> = (get_cam(ro, look_at) * normalize(vec4(uv * FOV, 1.0, 0.0))).xyz;
  let terrain = ray_march(ro, rd, uv);
  let dist: f32 = terrain.dist;
  let wd = terrain.water_depth;
  let steepness = calculate_slope(terrain.pos, uv);

  let beach_threshold = 10.0;
  let growth_threshold = 36.0;
  let earth_threshold = 40.0;

  let cam_pos = ro + dist * rd;
  var col: vec3<f32> = vec3(0.0);

  if (dist < rp.max_dist) {
    // Calculate the distance from the camera's position to the point
    let dist_origin: f32 = length(cam_pos);
    let light = get_light(cam_pos, rd, uv);
    let latitude = abs(cam_pos.y / WATER_LEVEL);

    // ICE
    if dist_origin > ICE_LEVEL - latitude*1.8 || latitude > 0.95 {
      col += ice_uniplanar_mapping(terrain.pos, uv, PLANET_RADIUS);
    // UNDERWATER
    } else if dist_origin < WATER_LEVEL {
      let rg = max(0.0, (1.0 - wd)*0.1);
      let b = 1.0 - 0.15*wd;
      col += light*vec3(rg, rg, b);
    // BEACHES
    } else if (
      dist_origin < SAND_LEVEL
      && latitude < 0.75
    ) {
      col += light*SAND_CLR;
    // PLANTS
    } else if (
      dist_origin < VEGETATION_LEVEL - latitude*1.4 
      && latitude < 0.85 
      && steepness < growth_threshold 
    ) {
      let height_mixer = (dist_origin - SAND_LEVEL)*0.4;
      let steep_mixer = (steepness - beach_threshold)*0.04;
      let hp_mix = mix(PLANT_CLR1, PLANT_CLR2, height_mixer);
      let sp_mix = mix(PLANT_CLR1, PLANT_CLR2, steep_mixer);
      let hp_mix2 = mix(hp_mix, EARTH_CLR, height_mixer*0.7);
      let sp_mix2 = mix(sp_mix, EARTH_CLR, steep_mixer*0.7);
      
      col += light*(sp_mix2 + hp_mix2)*0.4;
    // EARTH/ROCK
    } else {
      let low_steep = step(dist_origin, VEGETATION_LEVEL)*(steepness - growth_threshold)*0.04;
      let high_altitude = step(VEGETATION_LEVEL, dist_origin)*(dist_origin+1.0 - VEGETATION_LEVEL);
    
      let er_mixer = low_steep + high_altitude;
      col += light*mix(EARTH_CLR, ROCK_CLR, er_mixer);
    }
  }
  
  return col;
}

@fragment
fn main(@builtin(position) FragCoord: vec4<f32>) -> @location(0) vec4<f32> {
  let t: f32 = tu.time * vp.time_modifier;
  var uv: vec2<f32> = scale_aspect(FragCoord.xy); // Scale to -1.0 -> 1.0 + fix aspect ratio

  let uv0 = uv;
  uv.x += vp.x_shift * vp.zoom;
  uv.y += vp.y_shift * vp.zoom;
  uv /= vp.zoom;

  var color = vec3(0.0);
// -----------------------------------------------------------------------------------------------

  color = render(uv);

// -----------------------------------------------------------------------------------------------
  
  return vec4<f32>(color, 1.0);
}
