const SCREEN_WIDTH: f32 = 1376.0;
const SCREEN_HEIGHT: f32 = 768.0;
const I_SCREEN_WIDTH: i32 = 1376;
const I_SCREEN_HEIGHT: i32 = 768;
const TEX_WIDTH: f32 = 1408.0;
const TEX_HEIGHT: f32 = 800.0;
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

@group(1) @binding(0) var<storage, read_write> tp: TerrainParams;
@group(1) @binding(8) var<storage, read_write> debug_arr: array<vec4<f32>>;
@group(1) @binding(9) var<storage, read_write> debug: vec4<f32>;

@group(2) @binding(0) var terrain: texture_storage_2d<rgba32float, read_write>;
@group(2) @binding(1) var waves: texture_storage_2d<rgba32float, read_write>;

struct TimeUniform {
time: f32,
}
struct TerrainParams {
  octaves: i32,
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

fn fbm(pos: vec2<f32>) -> f32 {
  var p = pos;
  var f = 2.03;
  let s = 0.49;
  var res = 0.0;
  var frac = 0.5;

  for (var i: i32 = 0; i < tp.octaves; i++) {
    res += frac*perlinNoise2(p);
    frac *= s;
    p = f*m2*p;
    f -= 0.01;
  }

  return res;
}

fn generate_waves(pos: vec2<f32>, terrain_height: f32) -> f32 {
  let height = 0.1;
  let freq = 10.0;
  let speed = 1.0;
  let amp = 1.0;
  
  let wx = sin(terrain_height*height*freq + pos.x*speed)*amp;
  let wy = sin(terrain_height*height*freq + pos.y*speed)*amp;
  
  return wx*wy;
}

@compute 
@workgroup_size(32, 32, 1) 
fn generate_terrain_map(@builtin(global_invocation_id) id: vec3<u32>) {
  let tx_coord: vec2<u32> = id.xy;
  let tx_uv: vec2<f32> = ((2.0 * vec2(f32(tx_coord.x), f32(tx_coord.y))) / vec2(TEX_WIDTH,
  TEX_HEIGHT)) - 1.0;

  var tx = textureLoad(terrain, tx_coord);
  let noise = fbm(tx_uv);
  tx.x += noise;
  tx.y += generate_waves(tx_uv, noise);
  debug_arr[id.x] = tx; 
  textureStore(terrain, tx_coord, tx);
}
