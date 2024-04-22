use nalgebra::Matrix4;

#[repr(C)]
#[derive(Copy, Clone)]
pub(crate) struct TimeUniform {
    pub(crate) time: f32,
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub(crate) struct PerspectiveUniform {
    pub(crate) adjoint: Matrix4<f32>,
    pub(crate) inverse: Matrix4<f32>,
}

#[derive(Debug)]
pub(crate) struct Buffers {
    pub(crate) vertex: wgpu::Buffer,
    pub(crate) time_uniform: wgpu::Buffer,
    pub(crate) perspective_uniform: wgpu::Buffer,
    pub(crate) terrain_params: wgpu::Buffer,
    pub(crate) ray_params: wgpu::Buffer,
    pub(crate) view_params: wgpu::Buffer,
    pub(crate) debug_params: wgpu::Buffer,
    pub(crate) generic_debug: wgpu::Buffer,
    pub(crate) cpu_read_generic_debug: wgpu::Buffer,
    pub(crate) generic_debug_array: wgpu::Buffer,
    pub(crate) cpu_read_generic_debug_array: wgpu::Buffer,
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
    pub(crate) generate_terrain: wgpu::ComputePipeline,
}

#[derive(Debug)]
pub(crate) struct Textures {
    pub(crate) terrain_sampler: wgpu::Sampler,
    pub(crate) terrain_view: wgpu::TextureView,
    pub(crate) wave_sampler: wgpu::Sampler,
    pub(crate) wave_view: wgpu::TextureView,
}

// PARAMETERS
#[derive(Debug)]
pub(crate) struct Params {
    pub(crate) terrain_params: TerrainParams,
    pub(crate) ray_params: RayParams,
    pub(crate) view_params: ViewParams,
    pub(crate) perspective_uniform: PerspectiveUniform,
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
    pub(crate) x_rot: f32,
    pub(crate) y_rot: f32,
    pub(crate) zoom: f32,
    pub(crate) time_modifier: f32,
    pub(crate) fov_degrees: f32,
}
