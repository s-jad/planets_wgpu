const PI: f32 = 3.14159265358979323846;
const SCREEN_WIDTH: f32 = 1376.0;
const SCREEN_HEIGHT: f32 = 768.0;
const I_SCREEN_WIDTH: i32 = 1376;
const I_SCREEN_HEIGHT: i32 = 768;
// Incorrect (2048x2048), but when corrected
// produces less interesting terrain
const PLANET_TEX_WIDTH: f32 = 2048.0;
const PLANET_TEX_HEIGHT: f32 = 2048.0;

const MOON_TEX_WIDTH: f32 = 1024.0;
const MOON_TEX_HEIGHT: f32 = 1024.0;
const NUM_CRATERS: u32 = 4;
const CRATER_DEPTH: f32 = 0.5;
const MIN_CRATER_RAD: f32 = 0.15;

const MIN_POSITIVE_F32: f32 = 0x1.0p-126f;

const m2: mat2x2<f32> = mat2x2(
  0.80, 0.60,
  -0.60, 0.80,
);

const m2Inv: mat2x2<f32> = mat2x2(
  0.80, -0.60,
  0.60, 0.80,
);

@group(0) @binding(0) var<uniform> tu: TimeUniform;

@group(1) @binding(7) var<storage, read_write> debug_arr1: array<vec4<f32>>;
@group(1) @binding(8) var<storage, read_write> debug_arr2: array<vec4<f32>>;
@group(1) @binding(9) var<storage, read_write> debug: vec4<f32>;

@group(2) @binding(0) var planet_terrain: texture_storage_2d<rgba32float, read_write>;
@group(2) @binding(1) var moon_terrain: texture_storage_2d<rgba32float, read_write>;

struct TimeUniform {
  time: f32,
}

// FBM
// perlinNoise2 - MIT License. © Stefan Gustavson, Munrocket ------------------------------
fn permute4(x: vec4f) -> vec4f { return ((x * 34. + 1.) * x) % vec4f(289.); }
fn fade2(t: vec2f) -> vec2f { return t * t * t * (t * (t * 6. - 15.) + 10.); }

fn perlinNoise2(P: vec2f) -> f32 {
    var Pi: vec4f = floor(P.xyxy) + vec4f(0., 0., 1., 1.);
    let Pf = fract(P.xyxy) - vec4f(0., 0., 1., 1.);
    Pi = Pi % vec4f(289.); // To avoid truncation effects in permutation

    let ix = Pi.xzxz;
    let iy = Pi.yyww;
    let fx = Pf.xzxz;
    let fy = Pf.yyww;

    let i = permute4(permute4(ix) + iy);

    var gx: vec4f = 2. * fract(i * 0.0243902439) - 1.; // 1/41 = 0.024...
    let gy = abs(gx) - 0.5;
    let tx = floor(gx + 0.5);
    gx = gx - tx;

    var g00: vec2f = vec2f(gx.x, gy.x);
    var g10: vec2f = vec2f(gx.y, gy.y);
    var g01: vec2f = vec2f(gx.z, gy.z);
    var g11: vec2f = vec2f(gx.w, gy.w);

    let norm = 1.79284291400159 - 0.85373472095314 *
        vec4f(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11));

    g00 = g00 * norm.x;
    g01 = g01 * norm.y;
    g10 = g10 * norm.z;
    g11 = g11 * norm.w;

    let n00 = dot(g00, vec2f(fx.x, fy.x));
    let n10 = dot(g10, vec2f(fx.y, fy.y));
    let n01 = dot(g01, vec2f(fx.z, fy.z));
    let n11 = dot(g11, vec2f(fx.w, fy.w));

    let fade_xy = fade2(Pf.xy);

    let n_x = mix(vec2f(n00, n01), vec2f(n10, n11), vec2f(fade_xy.x));
    let n_xy = mix(n_x.x, n_x.y, fade_xy.y);

    return 2.3 * n_xy;
}

fn fbm(pos: vec2<f32>, octaves: i32, fraction: f32) -> f32 {
  var p = pos;
  var f = 2.03;
  let s = 0.49;
  var res = 0.0;
  var frac = fraction;

  for (var i: i32 = 0; i < octaves; i++) {
    res += frac*perlinNoise2(p);
    frac *= s;
    p = f*m2*p;
    f -= 0.01;
  }

  return res;
}

@compute 
@workgroup_size(32, 32, 1) 
fn generate_planet_terrain_map(@builtin(global_invocation_id) id: vec3<u32>) {
  let tx_coord: vec2<u32> = id.xy;
  let ptx_uv: vec2<f32> = ((2.0 * vec2(f32(tx_coord.x), f32(tx_coord.y))) / vec2(PLANET_TEX_WIDTH,
  PLANET_TEX_HEIGHT)) - 1.0;

  var ptx = textureLoad(planet_terrain, tx_coord);

  var t1 = fbm(ptx_uv, 11, 0.51)*1.032417;
  t1 += fbm(ptx_uv, 5, 0.47)*0.9432;
  t1 += fbm(ptx_uv, 3, 0.53)*-0.541793;
  t1 += fbm(ptx_uv, 2, 0.53)*-0.441793;
  t1 += fbm(ptx_uv, 9, 0.49)*0.175379;
  
  //var sand_mask = smoothstep(0.0, 0.5, fbm(ptx_uv, 2, 0.5)*3.0);
  let ice_tex = fbm(ptx_uv, 11, 0.125);

  ptx += vec4(t1, 0.0, 0.0, ice_tex);

  textureStore(planet_terrain, tx_coord, ptx);
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

struct Crater {
  height: f32,
  clr: f32,
}

fn crater_bowl(x: f32) -> f32 {
  return -pow(abs(x), 2.5) + 1.0;
}

fn crater_ridge(x: f32) -> f32 {
  return pow(abs(sin(PI * x / 2.0)), 1.5);
}

fn linear_scale(low: f32, high: f32, x: f32) -> f32 {
  return clamp((x - low) / (high - low), 0.0, 1.0);
}

fn generate_craters(tx_uv: vec2<f32>, height: f32) -> Crater {
  var crater = vec2(-0.8, -0.8);
  var d = height;
  var clr = 0.0;
  let shaded = 0.15;

  for (var i: u32 = 0u; i < NUM_CRATERS; i++) {
    let dist = length(crater - tx_uv);
    let radius = max(MIN_CRATER_RAD, pcg_f32()*0.25);

    let b_switch = step(dist, radius);
    let r_switch = step(dist, radius + 0.1);
 
    let x = linear_scale(0.0, radius, dist);
    var cbowl = CRATER_DEPTH*crater_bowl(x)*b_switch;

    let y = linear_scale(radius, radius+0.1, dist);
    let cridge = (crater_ridge(y) - 1.0)*r_switch;

    d += (cbowl*3.0 + cridge) * 0.3;
    clr += shaded*b_switch;
    
    let new_crater_pos_diff = vec2(max(0.4, pcg_f32()*0.6), max(0.4, pcg_f32()*0.6));
    crater += new_crater_pos_diff;
  }

  return Crater(d, clr);
}

@compute 
@workgroup_size(32, 32, 1) 
fn generate_moon_terrain_map(@builtin(global_invocation_id) id: vec3<u32>) {
  let tx_coord: vec2<u32> = id.xy;
  let mtx_uv: vec2<f32> = ((2.0 * vec2(f32(tx_coord.x), f32(tx_coord.y))) / vec2(MOON_TEX_WIDTH,
  MOON_TEX_HEIGHT)) - 1.0;

  var mtx = textureLoad(moon_terrain, tx_coord);
  var t1 = fbm(mtx_uv, 5, 0.51)*0.41793;
  t1 += fbm(mtx_uv, 3, 0.49)*-0.31231;
  let t2 = fbm(mtx_uv, 7, 0.47)*0.19373;

  let craters = generate_craters(mtx_uv, mtx.z);
  mtx.x += t1;
  mtx.y += t2;
  mtx.z += craters.height;
  mtx.w += craters.clr;

  textureStore(moon_terrain, tx_coord, mtx);
}
