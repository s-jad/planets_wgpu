// CONSTANTS
const SCREEN_WIDTH: f32 = 1376.0;
const SCREEN_HEIGHT: f32 = 768.0;

struct TimeUniform {
    time: f32,
};

// GROUPS AND BINDINGS
@group(1) @binding(0)
var<uniform> tu: TimeUniform;

// ASPECT RATIO
fn scale_aspect(fc: vec2<f32>) -> vec2<f32> {
  // Scale from screen dimensions to 0.0 --> 1.0
  var uv: vec2<f32> = fc / vec2(SCREEN_WIDTH, SCREEN_HEIGHT);
  uv.y = 1.0 - uv.y; // Flip Y axis if necessary
  return uv;
}

@fragment
fn main(@builtin(position) FragCoord: vec4<f32>) -> @location(0) vec4<f32> {
  let t: f32 = tu.time;
  var uv: vec2<f32> = scale_aspect(FragCoord.xy); // Scale to 0.0 -> 1.0 + fix aspect ratio
  var color = vec3(0.0);
// -----------------------------------------------------------------------------------------------



// -----------------------------------------------------------------------------------------------
  return vec4<f32>(color, 1.0);
}
