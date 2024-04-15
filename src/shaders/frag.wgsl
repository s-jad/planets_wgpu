// CONSTANTS
const SCREEN_WIDTH: f32 = 1376.0;
const SCREEN_HEIGHT: f32 = 768.0;

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
  time_modifier: f32,
}

// GROUPS AND BINDINGS
@group(0) @binding(0) var<uniform> tu: TimeUniform;

@group(1) @binding(0) var<storage, read_write> rp: RayParams;
@group(1) @binding(1) var<storage, read_write> vp: ViewParams;

@group(2) @binding(0) var terrain: texture_2d<f32>;
@group(2) @binding(1) var terrain_sampler: sampler;

// ASPECT RATIO
fn scale_aspect(fc: vec2<f32>) -> vec2<f32> {
  // Scale from screen dimensions to 0.0 --> 1.0
  var uv: vec2<f32> = fc / vec2(SCREEN_WIDTH, SCREEN_HEIGHT);
  uv.y = 1.0 - uv.y; // Flip Y axis if necessary
  return uv;
}

// RAY MARCHING
fn get_terrain(pos: vec3<f32>) -> f32 {
  var d = pos.y + 1.0;
  
  return d;
}

fn map(pos: vec3<f32>, uv: vec2<f32>) -> f32 {
  var d = 0.0;

  d += get_terrain(pos);
  // d += textureSample(terrain, terrain_sampler, uv).x;

  return d;
}


fn ray_march(ro: vec3<f32>, rd: vec3<f32>, uv: vec2<f32>) -> f32 {
  var dist = 0.0;
  let steps = i32(rp.max_steps);

  for (var i: i32 = 0; i < steps; i++) {
    let p = ro + dist * rd;
    let hit = map(p, uv);

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
  var light_pos: vec3<f32> = vec3(250.0, 100.0, -300.0) * 4.0;
  let color: vec3<f32> = vec3(1.0);

  let l: vec3<f32> = normalize(light_pos - pos);
  let normal: vec3<f32> = get_normal(pos, uv);

  let v: vec3<f32> = -rd;
  let r: vec3<f32> = reflect(-l, normal);

  let diff: f32 = 0.70 * max(dot(l, normal), 0.0);
  let specular: f32 = 0.3 * pow(clamp(dot(r, v), 0.0, 1.0), 10.0);
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

// RENDERING
fn render(uv: vec2<f32>) -> vec3<f32> {
  var ro: vec3<f32> = vec3(210.0, 180.0, 220.0);
  let fov = 1.0;
  let look_at: vec3<f32> = vec3(20.0, 1.0, 20.0);
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
