const SCREEN_WIDTH: f32 = 1376.0;
const SCREEN_HEIGHT: f32 = 768.0;
const I_SCREEN_WIDTH: i32 = 1376;
const I_SCREEN_HEIGHT: i32 = 768;
const MIN_POSITIVE_F32: f32 = 0x1.0p-126f;

const m3: mat3x3<f32> = mat3x3(
  0.00, 0.80, 0.60,
  -0.80, 0.36, -0.48,
  -0.60, -0.48, 0.64
);

const m3Inv: mat3x3<f32> = mat3x3(
  0.00, -0.80, -0.60,
  0.80, 0.36, -0.48,
  0.60, -0.48, 0.64
);

@group(0) @binding(0) var<uniform> tu: TimeUniform;

@group(1) @binding(0) var<storage, read_write> tp: TerrainParams;
@group(1) @binding(9) var<storage, read_write> debug: vec4<f32>;

@group(2) @binding(0) var terrain: texture_storage_2d<rgba32float, read_write>;

struct TimeUniform {
time: f32,
}
struct TerrainParams {
  octaves: i32,
}

// HASHING
fn murmur_hash13(pos: vec3<u32>) -> u32 {
  var p: vec3<u32> = pos;
  let M: u32 = 0x5bd1e995u;
  var h: u32 = 1190494759u;

  p *= M;
  p ^= vec3(p.x >> 24u, p.y >> 24u, p.z >> 24u);
  p *= M;
  h ^= p.x;
  h *= M;
  h ^= p.y;
  h *= M;
  h ^= p.z;
  h ^= h >> 13u;
  h *= M;
  h ^= h >> 15u;

  return h;
}

fn hash13(pos: vec3<f32>) -> f32 {
  var h: u32 = murmur_hash13(vec3(u32(pos.x), u32(pos.y), u32(pos.z)));
  h = h & 0x007fffffu | 0x3f800000u;
  return f32(h);
}

// FBM
fn noise34(pos: vec3<f32>) -> vec4<f32> {
  // grid
  let p = floor(pos);
  let w = fract(pos);

  // quintic interpolation
  let u = w*w*w*(w*(w*6.0 - 15.0) + 10.0);
  let du = 30.0*w*w*(w*(w - 2.0) + 1.0);

  // gradients
  let a: f32 = hash13(p + vec3(0.0, 0.0, 0.0));
  let b: f32 = hash13(p + vec3(1.0, 0.0, 0.0));
  let c: f32 = hash13(p + vec3(0.0, 1.0, 0.0));
  let d: f32 = hash13(p + vec3(1.0, 1.0, 0.0));
  let e: f32 = hash13(p + vec3(0.0, 0.0, 1.0));
  let f: f32 = hash13(p + vec3(0.0, 0.0, 1.0));
  let g: f32 = hash13(p + vec3(0.0, 1.0, 1.0));
  let h: f32 = hash13(p + vec3(1.0, 1.0, 1.0));

  let k0: f32 = a;
  let k1: f32 = b - a;
  let k2: f32 = c - a;
  let k3: f32 = e - a;
  let k4: f32 = a - b - c + d;
  let k5: f32 = a - c - e + g;
  let k6: f32 = a - b - e + f;
  let k7: f32 = a + b + c - d + e - f - g + h;

  return vec4(
    // Noise value
    -1.0 + 2.0*(k0 + k1*u.x + k2*u.y + k3*u.z  + k4*u.x*u.y + k5*u.y*u.z + k4*u.z*u.x +
    k7*u.x*u.y*u.z),
    // Gradients
    2.0 * du * vec3(
      k1 + k4*u.y + k6*u.z + k7*u.y*u.z,
      k2 + k5*u.z + k4*u.x + k7*u.z*u.x,
      k3 + k6*u.x + k5*u.y + k7*u.x*u.y
    )
  );
}

fn fbm34(pos: vec2<f32>) -> vec4<f32> {
  var p = vec3(pos, 1.0);
  let f = 1.98;
  let s = 0.49;
  var a = 0.0;
  var frac = 0.5;

  var d: vec3<f32> = vec3(0.0);

  var mId = mat3x3(
    1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 0.0, 1.0
  );

  for (var i: i32 = 0; i < tp.octaves; i++) {
    let noise: vec4<f32> = noise34(p);
    a += frac*noise.x;
    d += frac*mId*noise.yzw;
    frac *= s;
    p = f*m3*p;
    mId = f*m3Inv*mId;
  }

  return vec4<f32>(a, d);
}

@compute 
@workgroup_size(32, 32, 1) 
fn generate_terrain_map(@builtin(global_invocation_id) id: vec3<u32>) {
  let tx_coord: vec2<u32> = id.xy;
  let uv: vec2<f32> = vec2(f32(tx_coord.x), f32(tx_coord.y)) / vec2(SCREEN_WIDTH, SCREEN_HEIGHT);

  var tx = textureLoad(terrain, tx_coord);
  tx += fbm34(uv);

  textureStore(terrain, tx_coord, tx);
}
