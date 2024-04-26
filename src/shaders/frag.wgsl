const PI: f32 = 3.14159265358979323846;
const MAX_F32: f32 = 0x1.fffffep+127f;

const SCREEN_WIDTH: f32 = 1376.0;
const SCREEN_HEIGHT: f32 = 768.0;
const ASPECT: f32 = SCREEN_WIDTH / SCREEN_HEIGHT;
const INV_ASPECT: f32 = SCREEN_HEIGHT / SCREEN_WIDTH;
// Used extremely low FOV to reduce edge distortion of moon sdf
// Combined with placing the camera extremely far from the objects
const FOV: f32 = 0.349066; // 20 degrees

const TEX_WIDTH: f32 = 2048.0;
const TEX_HEIGHT: f32 = 2048.0;

const CENTER: vec3<f32> = vec3(0.0);
const PLANET_ROTATION: f32 = 0.1;
const PLANET_RADIUS: f32 = 50.0;

const MOON_RADIUS: f32 = 5.0;
const MOON_ORBIT_SPEED: f32 = 0.2;
const MOON_ORBIT_RADIUS: f32 = 75.0;
const MOON_ORBIT_INCLINATION: f32 = 5.0;

// Measured via distance from planet center
const WATER_LEVEL: f32 = 50.3;
const SAND_LEVEL: f32 = WATER_LEVEL + 0.2 ;
const PLANT_LEVEL: f32 = WATER_LEVEL + 2.3;
const ICE_LEVEL: f32 = WATER_LEVEL + 3.3;

// Steepness thresholds
const SAND_THRESHOLD: f32 = 10.0;
const PLANT_THRESHOLD: f32 = 36.0;
const EARTH_THRESHOLD: f32 = 40.0;

const SAND_CLR1: vec3<f32> = vec3(0.8, 0.8, 0.1);
const SAND_CLR2: vec3<f32> = vec3(0.3975, 0.775, 0.06);
const PLANT_CLR1: vec3<f32> = vec3(0.05, 0.75, 0.02);
const PLANT_CLR2: vec3<f32> = vec3(0.0, 0.25, 0.07);
const EARTH_CLR: vec3<f32> = vec3(0.3, 0.18, 0.1);
const ROCK_CLR: vec3<f32> = vec3(0.2, 0.2, 0.2);
const ICE_CLR: vec3<f32> = vec3(1.0, 1.0, 1.0);

const PLANT_REFLECTIVITY: f32 = 0.25;
const ROCK_REFLECTIVITY: f32 = 0.35;
const SAND_REFLECTIVITY: f32 = 0.5;
const WATER_REFLECTIVITY: f32 = 0.9;
const ICE_REFLECTIVITY: f32 = 1.0;

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
  zoom: f32,
  x_rot: f32,
  y_rot: f32,
  time_modifier: f32,
}

// GROUPS AND BINDINGS
@group(0) @binding(0) var<uniform> tu: TimeUniform;

@group(1) @binding(0) var<storage, read_write> rp: RayParams;
@group(1) @binding(1) var<storage, read_write> vp: ViewParams;
@group(1) @binding(8) var<storage, read_write> debug_arr: array<vec4<f32>>;
@group(1) @binding(9) var<storage, read_write> debug: vec4<f32>;

@group(2) @binding(0) var planet_tex: texture_2d<f32>;
@group(2) @binding(1) var planet_sampler: sampler;
@group(2) @binding(2) var moon_tex: texture_2d<f32>;
@group(2) @binding(3) var moon_sampler: sampler;

// ASPECT RATIO
fn scale_aspect(fc: vec2<f32>) -> vec2<f32> {
  // Scale from screen dimensions to 0.0 --> 1.0
  var uv: vec2<f32> = ((2.0 * fc) / vec2(SCREEN_WIDTH, SCREEN_HEIGHT)) - 1.0;
  uv.y = -uv.y * INV_ASPECT;
  return uv;
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
  let light_size = 100.0;

  for (var i: i32 = 0; i < 8; i++) {
    let hit = map(pos + light_pos * dist, uv).dist;
    res = min(res, hit / (dist * light_size));
    if (hit < rp.epsilon) { break; }
    dist += hit;
    if (dist > 50.0) { break; }
  }

  return clamp(res, 0.0, 1.0);
}

struct MaterialEnum {
  ice: f32,
  water: f32,
  rock: f32,
  plant: f32,
  sand: f32,
}

fn get_light(
  pos: vec3<f32>,
  rd: vec3<f32>,
  uv: vec2<f32>,
  material: MaterialEnum,
) -> vec3<f32> {
  var light_pos: vec3<f32> = vec3(40.0, 50.0, -500.0);
  let color: vec3<f32> = vec3(1.0);

  let l: vec3<f32> = normalize(light_pos - pos);
  let normal: vec3<f32> = get_normal(pos, uv);

  let v: vec3<f32> = -rd;
  let r: vec3<f32> = reflect(-l, normal);

  let diff: f32 = 0.70 * max(dot(l, normal), 0.0);
  let specular: f32 = 0.30 * pow(clamp(dot(r, v), 0.0, 1.0), 10.0);
  let ambient: f32 = 0.05; 

  var reflect: f32 = 0.0;
  reflect += material.ice*ICE_REFLECTIVITY;
  reflect += material.water*WATER_REFLECTIVITY;
  reflect += material.rock*ROCK_REFLECTIVITY;
  reflect += material.plant*PLANT_REFLECTIVITY;
  reflect += material.sand*SAND_REFLECTIVITY;
  let spec_ref = specular*reflect;
  let diff_ref = diff*reflect;

  let shadow: f32 = get_soft_shadow(pos, light_pos, uv);
  let occ: f32 = get_ambient_occlusion(pos, normal, uv);

  return (ambient * occ + (spec_ref * occ + diff_ref) * shadow) * color;
}

// CAMERA

fn get_cam(ro: vec3<f32>, look_at: vec3<f32>) -> mat4x4<f32> {
  let camf = normalize(vec3(look_at - ro));
  let camr = normalize(cross(vec3(0.0, 1.0, 0.0), camf));
  let camu = cross(camf, camr);
  let camp = vec4(-ro.x, -ro.y, -ro.z, 1.0);

  return mat4x4(
    vec4(camr, 0.0), 
    vec4(camu, 0.0), 
    vec4(camf, 0.0), 
    camp
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

// TERRAIN/TEXTURE MAPPING
fn tex_triplanar_mapping(
  pos: vec3<f32>,
  uv: vec2<f32>,
  radius: f32,
  amp: f32,
  tex: texture_2d<f32>,
  tex_sampler: sampler,
) -> vec4<f32> {
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

  let XY: vec4<f32> = textureSample(tex, tex_sampler, tex_XY) * amp * n.z;
  let XZ: vec4<f32> = textureSample(tex, tex_sampler, tex_XZ) * amp * n.y;
  let YZ: vec4<f32> = textureSample(tex, tex_sampler, tex_YZ) * amp * n.x;

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

// SIGNED DISTANCE FUNCTIONS
// Found at the brilliant Inigo Quilezles' site here:
// https://iquilezles.org/articles/smin/
fn unionSDF(d1: f32, d2: f32) -> f32 {
  return min(d1, d2);
}

fn subtractSDF(d1: f32, d2: f32) -> f32 {
  return max(-d1, d2);
}

fn smooth_unionSDF(d1: f32,  d2: f32, k: f32) -> f32 {
    let h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

fn smooth_subtractSDF(d1: f32, d2: f32, k: f32 ) -> f32 {
    let h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h);
}

fn sphereSDF(pos: vec3<f32>, radius: f32) -> f32 {
  return length(pos) - radius;
}

fn ellipsoidSDF(pos: vec3<f32>, radius: f32) -> f32 {
  let k0 = length(pos / radius);
  let k1 = length(pos / (radius*radius));
  return k0*(k0 - 1.0) / k1;
}

// PCG AND SEED
var<private> seed: u32 = 1234;

fn pcg_u32() -> u32 {
    let old_seed = seed + 747796405u + 2891336453u;
    let word = ((old_seed >> ((old_seed >> 28u) + 4u)) ^ old_seed) * 277803737u;
    seed = (word >> 22u) ^ word;
    return word;
}

fn pcg_f32() -> f32 {
    let state = pcg_u32();
    return f32(state) / f32(0xffffffffu);
}

// MOON
fn get_moon_position() -> vec3<f32> {
  let angle = 1.0; // tu.time*MOON_ORBIT_SPEED;
  let x = MOON_ORBIT_RADIUS*cos(angle);
  let z = MOON_ORBIT_RADIUS*sin(angle);
  let y = MOON_ORBIT_INCLINATION*sin(angle)*3.0;

  //return vec3(x, y - MOON_ORBIT_INCLINATION - x*0.1, z);

  return vec3(0.0, 0.0, 100.0);
}

fn get_moon(pos: vec3<f32>, uv: vec2<f32>) -> f32 {
  let moon_offset = get_moon_position();
  let moon_pos = pos + moon_offset;
  var moon = sphereSDF(moon_pos, MOON_RADIUS);
  let mt_amp = 0.2;

  let mtx = tex_triplanar_mapping(
    moon_pos, uv, 
    MOON_RADIUS, mt_amp,
    moon_tex, moon_sampler,
  );
  
  //moon += mtx.x;
  //moon += mtx.y;
  //moon += mtx.z;
  moon += mtx.w*20.0;

  return moon;
}

struct Terrain {
  dist: f32,
  water_depth: f32,
}

fn get_terrain(pos: vec3<f32>, uv: vec2<f32>) -> Terrain {
  let rPos = rotate3d(pos, 0.0, PLANET_ROTATION*tu.time);
  var d1 = sphereSDF(rPos, PLANET_RADIUS);
  var d0 = d1;
  
  let pt_amp = 10.0;
  let tx = tex_triplanar_mapping(
    rPos, uv, 
    PLANET_RADIUS, pt_amp,
    planet_tex, planet_sampler
  );

  d1 += tx.x;
  d1 += tx.y;
  
  let high_alt = step(PLANT_LEVEL, length(rPos - CENTER));
  d1 += tx.z;

  // Calc water depth for use in render
  let water_depth = max(0.0, d1 - d0);
  // Cover lower elevations in water
  d1 = min(d0, d1);
  // If above 0.95 latitude add ice texture on water
  let latitude = abs(pos.y / PLANET_RADIUS); 
  let ice_switch = step(0.95, latitude);
  // Dont add extra texture to polar mountains
  let polar_flats_switch = step(length(rPos - CENTER), WATER_LEVEL);
  d1 += ice_switch*tx.w*1.8;
  
  var moon = get_moon(pos, uv);

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
  let n = vec3(sphereSDF(pos, radius)) - 
    vec3(
      sphereSDF(pos - e.xyy, radius), 
      sphereSDF(pos - e.yxy, radius), 
      sphereSDF(pos - e.yyx, radius)
    );

  return normalize(n);
}

struct TerrainPos {
  dist: f32,
  water_depth: f32,
  pos: vec3<f32>,
}

fn ray_march(ro: vec3<f32>, rd: vec3<f32>, uv: vec2<f32>, look_at: vec3<f32>) -> TerrainPos {
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
  var ro: vec3<f32> = vec3(0.0, 0.0, -300.0);
  ro = rotate3d(ro, vp.y_rot, vp.x_rot);

  let look_at: vec3<f32> = vec3(0.0, 0.0, -100.0);

  var rd: vec3<f32> = (get_cam(ro, look_at) * normalize(vec4(uv * FOV, 1.0, 0.0))).xyz;
  let terrain = ray_march(ro, rd, uv, look_at);
  let dist: f32 = terrain.dist;
  let wd = terrain.water_depth;
  let steepness = calculate_slope(terrain.pos, uv);

  let cam_pos = ro + dist * rd;
  var col: vec3<f32> = vec3(0.0);
  var material = MaterialEnum(0.0, 0.0, 0.0, 0.0, 0.0);

  if (dist < rp.max_dist) {
    let dist_origin: f32 = length(cam_pos);
    let latitude = abs(cam_pos.y / WATER_LEVEL);
    let adjusted_ice_level = ICE_LEVEL - latitude*1.8;

    // ICE
    if dist_origin > adjusted_ice_level {
      let ef = smoothstep(adjusted_ice_level, adjusted_ice_level + 1.0, dist_origin);
      let ice_clr = mix(ROCK_CLR, ICE_CLR, ef);
      material.ice = 1.0*ef;
      material.rock = 1.0 - 1.0*ef;
      col += get_light(cam_pos, rd, uv, material)*ice_clr;
    } else if latitude > 0.95 {
      let ef = smoothstep(0.95, 0.96, latitude);
      let ice_clr = mix(ROCK_CLR, ICE_CLR, ef);
      material.ice = 1.0*ef;
      col += get_light(cam_pos, rd, uv, material)*ice_clr;
    // UNDERWATER
    } else if dist_origin < WATER_LEVEL {
      let rg = max(0.0, (1.0 - wd)*0.05);
      let b = 1.0 - 0.15*wd;
      let water_clr = vec3(rg, rg, b);
      material.water = 1.0;
      col += get_light(cam_pos, rd, uv, material)*water_clr;
    // BEACHES
    } else if (
      dist_origin < SAND_LEVEL
      && latitude < 0.75
    ) {
      let ef = smoothstep(SAND_LEVEL - 0.1, SAND_LEVEL, dist_origin);
      let beach_clr = mix(SAND_CLR1, SAND_CLR2, ef);
      material.sand = 1.0;
      col += get_light(cam_pos, rd, uv, material)*beach_clr;
    // PLANTS
    } else if (
      dist_origin < PLANT_LEVEL - latitude*1.4 
      && latitude < 0.85 
      && steepness < PLANT_THRESHOLD 
    ) {
      let height_mixer = smoothstep(SAND_LEVEL, PLANT_LEVEL, dist_origin);
      let steep_mixer = smoothstep(SAND_THRESHOLD, PLANT_THRESHOLD, steepness);
      let hp_mix = mix(PLANT_CLR1, PLANT_CLR2, height_mixer);
      let sp_mix = mix(PLANT_CLR1, PLANT_CLR2, steep_mixer);
      let hp_mix2 = mix(hp_mix, EARTH_CLR, height_mixer*0.7);
      let sp_mix2 = mix(sp_mix, EARTH_CLR, steep_mixer*0.4);
      
      material.plant = 1.0;
      col += get_light(cam_pos, rd, uv, material)*(sp_mix2 + hp_mix2)*0.5;
    // EARTH/ROCK
    } else {
      let low_steep = step(dist_origin, PLANT_LEVEL)*(steepness - PLANT_THRESHOLD)*0.04;
      let high_altitude = step(PLANT_LEVEL, dist_origin)*(dist_origin+1.0 - PLANT_LEVEL);
      let er_mixer = low_steep + high_altitude;
      let mountain_clr = mix(EARTH_CLR, ROCK_CLR, er_mixer);
      material.rock = 1.0;
      col += get_light(cam_pos, rd, uv, material)*mountain_clr;
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
