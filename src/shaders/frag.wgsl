// CONSTANTS
const PI: f32 = 3.14159265358979323846;
const SCREEN_WIDTH: f32 = 1376.0;
const SCREEN_HEIGHT: f32 = 768.0;
const ASPECT: f32 = SCREEN_HEIGHT / SCREEN_WIDTH;
const TEX_WIDTH: f32 = 2048.0;
const TEX_HEIGHT: f32 = 2048.0;
const TEX_DIM: vec2<f32> = vec2(TEX_WIDTH, TEX_HEIGHT);

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

// ASPECT RATIO
fn scale_aspect(fc: vec2<f32>) -> vec2<f32> {
  // Scale from screen dimensions to 0.0 --> 1.0
  var uv: vec2<f32> = ((2.0 * fc) / vec2(SCREEN_WIDTH, SCREEN_HEIGHT)) - 1.0;
  uv.y = -uv.y * ASPECT;
  return uv;
}

fn sphereSDF(pos: vec3<f32>, radius: f32) -> f32 {
  return length(pos) - radius;
}

// LIGHTING
fn get_normal(pos: vec3<f32>, uv: vec2<f32>) -> vec3<f32> {
  let e = vec2(rp.epsilon, 0.0);
  let n = vec3(map(pos, uv)) - vec3(map(pos - e.xyy, uv), map(pos - e.yxy, uv), map(pos -
  e.yyx, uv));

  return normalize(n);
}

fn get_ambient_occlusion(pos: vec3<f32>, normal: vec3<f32>, uv: vec2<f32>) -> f32 {
  var occ = 0.0;
  var weight = 0.4;

  for (var i: i32 = 0; i < 8; i++) {
    let len = 0.01 + 0.02 * f32(i * i);
    let dist = map(pos + normal * len, uv);
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
    let hit = map(pos + light_pos * dist, uv);
    res = min(res, hit / (dist * light_size));
    if (hit < rp.epsilon) { break; }
    dist += hit;
    if (dist > 40.0) { break; }
  }

  return clamp(res, 0.0, 1.0);
}

fn get_light(pos: vec3<f32>, rd: vec3<f32>, uv: vec2<f32>) -> vec3<f32> {
  var light_pos: vec3<f32> = vec3(250.0, 100.0, -300.0);
  let color: vec3<f32> = vec3(1.0);

  let l: vec3<f32> = normalize(light_pos - pos);
  let normal: vec3<f32> = get_normal(pos, uv);

  let v: vec3<f32> = -rd;
  let r: vec3<f32> = reflect(-l, normal);

  let diff: f32 = 0.70 * max(dot(l, normal), 0.0);
  let specular: f32 = 0.1 * pow(clamp(dot(r, v), 0.0, 1.0), 10.0);
  let ambient: f32 = 0.15; 

  let shadow: f32 = get_soft_shadow(pos, light_pos, uv);
  let occ: f32 = get_ambient_occlusion(pos, normal, uv);

  return (ambient * occ + (specular * occ + diff) * shadow) * color;
}

// CAMERA
fn get_cam(ro: vec3<f32>, look_at: vec3<f32>) -> mat3x3<f32> {
  let camf = normalize(vec3(look_at - ro));
  let camr = normalize(cross(vec3(0.0, 1.0, 0.0), camf));
  let camu = cross(camf, camr);

  return mat3x3(camr, camu, camf);
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

 // Apply the rotations in sequence
 let rotatedX = v * mtxX;
 let rotatedY = rotatedX * mtxY;

 return rotatedY;
}

struct TpMap {
  xz: f32,
  xy: f32,
  yz: f32,
}

fn tex_triplanar_mapping(pos: vec3<f32>, uv: vec2<f32>) -> TpMap {
  let amp = 30.0;

  let tex_XZ: vec2<f32> = (pos.xz / TEX_DIM)*0.5 + 0.5;
  let tex_XY: vec2<f32> = (pos.xy / TEX_DIM)*0.5 + 0.5;
  let tex_YZ: vec2<f32> = (pos.yz / TEX_DIM)*0.5 + 0.5;

  let XZ = textureSample(terrain, terrain_sampler, tex_XZ).x * amp;
  let XY = textureSample(terrain, terrain_sampler, tex_XY).x * amp;
  let YZ = textureSample(terrain, terrain_sampler, tex_YZ).x * amp;

  return TpMap(XZ, XY, YZ);
}

// RAY MARCHING
fn get_terrain(pos: vec3<f32>, uv: vec2<f32>) -> f32 {
  var d = sphereSDF(pos, 50.0);
  
  return d;
}

fn map(pos: vec3<f32>, uv: vec2<f32>) -> f32 {
  var d = 0.0;

  d += get_terrain(pos, uv);
  return d;
}


fn ray_march(ro: vec3<f32>, rd: vec3<f32>, uv: vec2<f32>) -> f32 {
  var dist = 0.0;
  let steps = i32(rp.max_steps);

  for (var i: i32 = 0; i < steps; i++) {
    let pos = ro + dist * rd;
    var hit = map(pos, uv);

    var n = get_normal(pos, uv);
    n *= n*n*n*n*n*n*n;
    n /= n.x + n.y + n.z;

    let tx_map = tex_triplanar_mapping(pos, uv);
    hit += tx_map.xz*n.y + tx_map.yz*n.x + tx_map.xy*n.z;

    if (abs(hit) < rp.epsilon) {
      break;
    }
    dist += hit;

    if (dist > rp.max_dist) {
      break;
    }
  }

  return dist;
}

// RENDERING
fn render(uv: vec2<f32>) -> vec3<f32> {
  var ro: vec3<f32> = vec3(0.0, 1.0, 110.0);
  ro = rotate3d(ro, vp.y_rot, vp.x_rot);

  let fov = radians(60.0);
  let look_at: vec3<f32> = vec3(0.0, 0.0, 0.0);
  let rd: vec3<f32> = get_cam(ro, look_at) * normalize(vec3(uv * fov, 1.0));

  let dist: f32 = ray_march(ro, rd, uv);
  let pos = ro + dist * rd;

  var col: vec3<f32> = vec3(0.0);

  if (dist < rp.max_dist) {
    col += get_light(pos, rd, uv);
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
