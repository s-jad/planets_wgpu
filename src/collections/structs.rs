#[repr(C)]
#[derive(Copy, Clone)]
pub(crate) struct TimeUniform {
    pub(crate) time: f32,
}

#[derive(Debug)]
pub(crate) struct Buffers {
    pub(crate) vertex: wgpu::Buffer,
    pub(crate) time_uniform: wgpu::Buffer,
    pub(crate) terrain_params: wgpu::Buffer,
    pub(crate) ray_params: wgpu::Buffer,
    pub(crate) view_params: wgpu::Buffer,
    pub(crate) planet_tex_buffer: wgpu::Buffer,
    pub(crate) debug_params: wgpu::Buffer,
    pub(crate) generic_debug: wgpu::Buffer,
    pub(crate) cpu_read_generic_debug: wgpu::Buffer,
    pub(crate) debug_array1: wgpu::Buffer,
    pub(crate) cpu_read_debug_array1: wgpu::Buffer,
    pub(crate) debug_array2: wgpu::Buffer,
    pub(crate) cpu_read_debug_array2: wgpu::Buffer,
}

#[derive(Debug)]
pub(crate) struct BindGroups {
    pub(crate) uniform_bg: wgpu::BindGroup,
    pub(crate) uniform_bgl: wgpu::BindGroupLayout,
    pub(crate) frag_bg: wgpu::BindGroup,
    pub(crate) frag_bgl: wgpu::BindGroupLayout,
    pub(crate) compute_bg: wgpu::BindGroup,
    pub(crate) compute_bgl: wgpu::BindGroupLayout,
    pub(crate) texture_bg: wgpu::BindGroup,
    pub(crate) texture_bgl: wgpu::BindGroupLayout,
    pub(crate) sampled_texture_bg: wgpu::BindGroup,
    pub(crate) sampled_texture_bgl: wgpu::BindGroupLayout,
}

#[derive(Debug)]
pub(crate) struct ShaderModules {
    pub(crate) v_shader: wgpu::ShaderModule,
    pub(crate) f_shader: wgpu::ShaderModule,
    pub(crate) generate_terrain: wgpu::ShaderModule,
}

#[derive(Debug)]
pub(crate) struct Pipelines {
    pub(crate) render: wgpu::RenderPipeline,
    pub(crate) generate_planet_terrain: wgpu::ComputePipeline,
    pub(crate) generate_moon_terrain: wgpu::ComputePipeline,
}

#[derive(Debug)]
pub(crate) struct Textures {
    pub(crate) planet_tex: wgpu::Texture,
    pub(crate) planet_tex_extent: wgpu::Extent3d,
    pub(crate) planet_sampler: wgpu::Sampler,
    pub(crate) planet_view: wgpu::TextureView,
    pub(crate) moon_sampler: wgpu::Sampler,
    pub(crate) moon_view: wgpu::TextureView,
}

#[derive(Debug)]
pub(crate) struct PlanetTexture {
    pub(crate) planet_tex: wgpu::Texture,
    pub(crate) planet_tex_extent: wgpu::Extent3d,
}

#[derive(Debug, Copy, Clone, PartialEq)]
pub(crate) struct Point {
    pub(crate) elevation: f32,
    pub(crate) x: u32,
    pub(crate) y: u32,
}

impl Point {
    pub(crate) fn manhattan_distance(&self, other: &Point) -> u32 {
        let dx = (self.x as i32 - other.x as i32).abs() as u32;
        let dy = (self.y as i32 - other.y as i32).abs() as u32;
        dx + dy
    }
}

impl PartialOrd for Point {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        return self.elevation.partial_cmp(&other.elevation);
    }
}

// PARAMETERS
#[derive(Debug)]
pub(crate) struct Params {
    pub(crate) terrain_params: TerrainParams,
    pub(crate) ray_params: RayParams,
    pub(crate) view_params: ViewParams,
    pub(crate) debug_params: DebugParams,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub(crate) struct RayParams {
    pub(crate) epsilon: f32,
    pub(crate) max_steps: f32,
    pub(crate) max_dist: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub(crate) struct TerrainParams {
    pub(crate) octaves: i32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub(crate) struct DebugParams {
    pub(crate) pole_start: f32,
    pub(crate) pole_scale: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub(crate) struct ViewParams {
    pub(crate) x_shift: f32,
    pub(crate) y_shift: f32,
    pub(crate) zoom: f32,
    pub(crate) x_rot: f32,
    pub(crate) y_rot: f32,
    pub(crate) time_modifier: f32,
    pub(crate) fov_degrees: f32,
}
