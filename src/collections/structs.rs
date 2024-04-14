#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub(crate) struct Vertex {
    pub(crate) position: [f32; 2],
}

pub(crate) const VERTICES: &[Vertex; 6] = &[
    // Bottom left triangle
    Vertex {
        position: [-1.0, -1.0],
    },
    Vertex {
        position: [1.0, -1.0],
    },
    Vertex {
        position: [-1.0, 1.0],
    },
    // Top right triangle
    Vertex {
        position: [1.0, -1.0],
    },
    Vertex {
        position: [1.0, 1.0],
    },
    Vertex {
        position: [-1.0, 1.0],
    },
];

#[repr(C)]
#[derive(Copy, Clone)]
pub(crate) struct TimeUniform {
    pub(crate) time: f32,
}
#[derive(Debug)]
pub(crate) struct Buffers {
    pub(crate) vertex_buf: wgpu::Buffer,
    pub(crate) time_uniform_buf: wgpu::Buffer,
    pub(crate) generic_debug_buf: wgpu::Buffer,
    pub(crate) cpu_read_generic_debug_buf: wgpu::Buffer,
}

#[derive(Debug)]
pub(crate) struct BindGroups {
    pub(crate) uniform_bg: wgpu::BindGroup,
    pub(crate) uniform_bgl: wgpu::BindGroupLayout,
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
    //pub(crate) generate_terrain_shader: wgpu::ShaderModule,
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
}

// PARAMETERS
#[derive(Debug)]
pub(crate) struct Params {
    pub(crate) terrain_params: TerrainParams,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub(crate) struct TerrainParams {
    pub(crate) octaves: u32,
}
