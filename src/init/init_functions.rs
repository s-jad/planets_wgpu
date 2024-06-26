use wgpu::util::DeviceExt;

use crate::collections::{
    consts::{
        MOON_TEXTURE_HEIGHT, MOON_TEXTURE_WIDTH, MOON_TEX_BUF_SIZE, PLANET_TEXTURE_HEIGHT,
        PLANET_TEXTURE_WIDTH, PLANET_TEX_BUF_SIZE,
    },
    structs::{
        BindGroups, Buffers, DebugParams, Params, Pipelines, RayParams, ShaderModules,
        TerrainParams, Textures, TimeUniform, ViewParams,
    },
    vertices::{vertices_as_bytes, VERTICES},
};

pub(crate) fn init_shader_modules(device: &wgpu::Device) -> ShaderModules {
    let vdesc = wgpu::ShaderModuleDescriptor {
        label: Some("Vertex Shader"),
        source: wgpu::ShaderSource::Wgsl(include_str!("../shaders/v2.wgsl").into()),
    };
    let v_shader = device.create_shader_module(vdesc);

    let fdesc = wgpu::ShaderModuleDescriptor {
        label: Some("Fragment Shader"),
        source: wgpu::ShaderSource::Wgsl(include_str!("../shaders/frag.wgsl").into()),
    };
    let f_shader = device.create_shader_module(fdesc);

    let generate_terrain_desc = wgpu::ShaderModuleDescriptor {
        label: Some("Generate Terrain Shader"),
        source: wgpu::ShaderSource::Wgsl(
            include_str!("../shaders/compute/generate_terrain.wgsl").into(),
        ),
    };

    let generate_terrain = device.create_shader_module(generate_terrain_desc);

    ShaderModules {
        v_shader,
        f_shader,
        generate_terrain,
    }
}

pub(crate) fn init_params() -> Params {
    let terrain_params = TerrainParams { octaves: 19 };

    let ray_params = RayParams {
        epsilon: 0.02,
        max_steps: 2500.0,
        max_dist: 500.0,
    };

    let debug_params = DebugParams {
        pole_start: 0.01,
        pole_scale: 1.0,
    };

    let view_params = ViewParams {
        x_shift: 0.0,
        y_shift: 0.0,
        zoom: 1.0,
        x_rot: 0.0,
        y_rot: 0.0,
        time_modifier: 1.0,
        fov_degrees: 20.0,
    };

    Params {
        terrain_params,
        ray_params,
        view_params,
        debug_params,
    }
}

pub(crate) fn init_buffers(device: &wgpu::Device, params: &Params) -> Buffers {
    let vertices_bytes = vertices_as_bytes(&VERTICES[..]);
    let vertex = wgpu::util::DeviceExt::create_buffer_init(
        device,
        &wgpu::util::BufferInitDescriptor {
            label: Some("Vertex Buffer"),
            contents: vertices_bytes,
            usage: wgpu::BufferUsages::VERTEX,
        },
    );

    // UNIFORM BUFFERS
    let time_uniform = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("Time Uniform Buffer"),
        size: std::mem::size_of::<f32>() as wgpu::BufferAddress,
        usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    // PARAMETER BUFFERS
    let terrain_params = wgpu::util::DeviceExt::create_buffer_init(
        device,
        &wgpu::util::BufferInitDescriptor {
            label: Some("Terrain Parameters Storage Buffer"),
            contents: bytemuck::cast_slice(&[params.terrain_params.octaves]),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        },
    );

    let ray_params = wgpu::util::DeviceExt::create_buffer_init(
        device,
        &wgpu::util::BufferInitDescriptor {
            label: Some("Ray Marching Parameters Storage Buffer"),
            contents: bytemuck::cast_slice(&[
                params.ray_params.epsilon,
                params.ray_params.max_dist,
                params.ray_params.max_steps,
            ]),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        },
    );

    let view_params = wgpu::util::DeviceExt::create_buffer_init(
        device,
        &wgpu::util::BufferInitDescriptor {
            label: Some("Ray Marching Parameters Storage Buffer"),
            contents: bytemuck::cast_slice(&[
                params.view_params.x_shift,
                params.view_params.y_shift,
                params.view_params.zoom,
                params.view_params.x_rot,
                params.view_params.y_rot,
                params.view_params.time_modifier,
                params.view_params.fov_degrees,
            ]),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        },
    );

    let planet_tex_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("Planet Tex Readback Buffer"),
        size: PLANET_TEX_BUF_SIZE as wgpu::BufferAddress,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });

    let debug_params = wgpu::util::DeviceExt::create_buffer_init(
        device,
        &wgpu::util::BufferInitDescriptor {
            label: Some("Ray Marching Parameters Storage Buffer"),
            contents: bytemuck::cast_slice(&[
                params.debug_params.pole_start,
                params.debug_params.pole_scale,
            ]),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        },
    );
    // STORAGE/CPU-READABLE BUFFER PAIRS
    let generic_debug = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("Debug Shaders Buffer"),
        size: (std::mem::size_of::<[f32; 4]>()) as wgpu::BufferAddress,
        usage: wgpu::BufferUsages::STORAGE
            | wgpu::BufferUsages::COPY_SRC
            | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    let cpu_read_generic_debug = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("CPU Readable Buffer - Debug Shaders"),
        size: (std::mem::size_of::<[f32; 4]>()) as wgpu::BufferAddress,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });

    let debug_array1 = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("Debug Shaders Buffer 1"),
        size: (std::mem::size_of::<[[f32; 4]; 512]>()) as wgpu::BufferAddress,
        usage: wgpu::BufferUsages::STORAGE
            | wgpu::BufferUsages::COPY_SRC
            | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    let cpu_read_debug_array1 = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("CPU Readable Buffer 1 - Debug Shaders"),
        size: (std::mem::size_of::<[[f32; 4]; 512]>()) as wgpu::BufferAddress,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });

    let debug_array2 = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("Debug Shaders Buffer 2"),
        size: (std::mem::size_of::<[[f32; 4]; 512]>()) as wgpu::BufferAddress,
        usage: wgpu::BufferUsages::STORAGE
            | wgpu::BufferUsages::COPY_SRC
            | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    let cpu_read_debug_array2 = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("CPU Readable Buffer 2 - Debug Shaders"),
        size: (std::mem::size_of::<[[f32; 4]; 512]>()) as wgpu::BufferAddress,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });

    Buffers {
        vertex,
        time_uniform,
        terrain_params,
        ray_params,
        view_params,
        planet_tex_buffer,
        debug_params,
        generic_debug,
        cpu_read_generic_debug,
        debug_array1,
        cpu_read_debug_array1,
        debug_array2,
        cpu_read_debug_array2,
    }
}

pub(crate) fn init_bind_groups(
    device: &wgpu::Device,
    buffers: &Buffers,
    textures: &Textures,
) -> BindGroups {
    let uniform_bgl = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
        entries: &[wgpu::BindGroupLayoutEntry {
            binding: 0,
            visibility: wgpu::ShaderStages::FRAGMENT | wgpu::ShaderStages::COMPUTE,
            ty: wgpu::BindingType::Buffer {
                ty: wgpu::BufferBindingType::Uniform,
                has_dynamic_offset: false,
                min_binding_size: wgpu::BufferSize::new(std::mem::size_of::<TimeUniform>() as _),
            },
            count: None,
        }],
        label: Some("uniform_bind_group_layout"),
    });

    let uniform_bg = device.create_bind_group(&wgpu::BindGroupDescriptor {
        layout: &uniform_bgl,
        entries: &[wgpu::BindGroupEntry {
            binding: 0,
            resource: buffers.time_uniform.as_entire_binding(),
        }],
        label: Some("uniforms_bind_group"),
    });

    let frag_bgl = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
        entries: &[
            wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::COMPUTE | wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: wgpu::BufferSize::new(std::mem::size_of::<RayParams>() as _),
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 1,
                visibility: wgpu::ShaderStages::COMPUTE | wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: wgpu::BufferSize::new(std::mem::size_of::<ViewParams>() as _),
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 7,
                visibility: wgpu::ShaderStages::COMPUTE | wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: wgpu::BufferSize::new(
                        std::mem::size_of::<[[f32; 4]; 512]>() as _
                    ),
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 8,
                visibility: wgpu::ShaderStages::COMPUTE | wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: wgpu::BufferSize::new(
                        std::mem::size_of::<[[f32; 4]; 512]>() as _
                    ),
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 9,
                visibility: wgpu::ShaderStages::COMPUTE | wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: wgpu::BufferSize::new(std::mem::size_of::<[f32; 4]>() as _),
                },
                count: None,
            },
        ],
        label: Some("fragment_bind_group_layout"),
    });

    let frag_bg = device.create_bind_group(&wgpu::BindGroupDescriptor {
        layout: &frag_bgl,
        entries: &[
            wgpu::BindGroupEntry {
                binding: 0,
                resource: buffers.ray_params.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 1,
                resource: buffers.view_params.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 7,
                resource: buffers.debug_array1.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 8,
                resource: buffers.debug_array2.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 9,
                resource: buffers.generic_debug.as_entire_binding(),
            },
        ],
        label: Some("compute_bind_group"),
    });

    let compute_bgl = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
        entries: &[
            wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::COMPUTE | wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: wgpu::BufferSize::new(
                        std::mem::size_of::<TerrainParams>() as _
                    ),
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 7,
                visibility: wgpu::ShaderStages::COMPUTE | wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: wgpu::BufferSize::new(
                        std::mem::size_of::<[[f32; 4]; 512]>() as _
                    ),
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 8,
                visibility: wgpu::ShaderStages::COMPUTE | wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: wgpu::BufferSize::new(
                        std::mem::size_of::<[[f32; 4]; 512]>() as _
                    ),
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 9,
                visibility: wgpu::ShaderStages::COMPUTE | wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: wgpu::BufferSize::new(std::mem::size_of::<[f32; 4]>() as _),
                },
                count: None,
            },
        ],
        label: Some("compute_bind_group_layout"),
    });

    let compute_bg = device.create_bind_group(&wgpu::BindGroupDescriptor {
        layout: &compute_bgl,
        entries: &[
            wgpu::BindGroupEntry {
                binding: 0,
                resource: buffers.terrain_params.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 7,
                resource: buffers.debug_array1.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 8,
                resource: buffers.debug_array2.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 9,
                resource: buffers.generic_debug.as_entire_binding(),
            },
        ],
        label: Some("compute_bind_group"),
    });

    let texture_bgl = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
        entries: &[
            wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::COMPUTE,
                ty: wgpu::BindingType::StorageTexture {
                    access: wgpu::StorageTextureAccess::ReadWrite,
                    format: wgpu::TextureFormat::Rgba32Float,
                    view_dimension: wgpu::TextureViewDimension::D2,
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 1,
                visibility: wgpu::ShaderStages::COMPUTE,
                ty: wgpu::BindingType::StorageTexture {
                    access: wgpu::StorageTextureAccess::ReadWrite,
                    format: wgpu::TextureFormat::Rgba32Float,
                    view_dimension: wgpu::TextureViewDimension::D2,
                },
                count: None,
            },
        ],
        label: Some("texture_bgl"),
    });

    let texture_bg = device.create_bind_group(&wgpu::BindGroupDescriptor {
        layout: &texture_bgl,
        entries: &[
            wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::TextureView(&textures.planet_view),
            },
            wgpu::BindGroupEntry {
                binding: 1,
                resource: wgpu::BindingResource::TextureView(&textures.moon_view),
            },
        ],
        label: Some("texture_bg"),
    });

    let sampled_texture_bgl = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
        entries: &[
            wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Texture {
                    sample_type: wgpu::TextureSampleType::Float { filterable: true },
                    view_dimension: wgpu::TextureViewDimension::D2,
                    multisampled: false,
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 1,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 2,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Texture {
                    sample_type: wgpu::TextureSampleType::Float { filterable: true },
                    view_dimension: wgpu::TextureViewDimension::D2,
                    multisampled: false,
                },
                count: None,
            },
            wgpu::BindGroupLayoutEntry {
                binding: 3,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                count: None,
            },
        ],
        label: Some("sampled_texture_bgl"),
    });

    let sampled_texture_bg = device.create_bind_group(&wgpu::BindGroupDescriptor {
        layout: &sampled_texture_bgl,
        entries: &[
            wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::TextureView(&textures.planet_view),
            },
            wgpu::BindGroupEntry {
                binding: 1,
                resource: wgpu::BindingResource::Sampler(&textures.planet_sampler),
            },
            wgpu::BindGroupEntry {
                binding: 2,
                resource: wgpu::BindingResource::TextureView(&textures.moon_view),
            },
            wgpu::BindGroupEntry {
                binding: 3,
                resource: wgpu::BindingResource::Sampler(&textures.moon_sampler),
            },
        ],
        label: Some("sampled_texture_bg"),
    });

    BindGroups {
        uniform_bg,
        uniform_bgl,
        frag_bg,
        frag_bgl,
        compute_bg,
        compute_bgl,
        texture_bg,
        texture_bgl,
        sampled_texture_bg,
        sampled_texture_bgl,
    }
}

pub(crate) fn init_pipelines(
    device: &wgpu::Device,
    bind_groups: &BindGroups,
    shader_modules: &ShaderModules,
) -> Pipelines {
    let render_pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        label: Some("Render Pipeline Layout"),
        bind_group_layouts: &[
            &bind_groups.uniform_bgl,
            &bind_groups.frag_bgl,
            &bind_groups.sampled_texture_bgl,
        ],
        push_constant_ranges: &[],
    });

    let render = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
        label: Some("Render Pipeline"),
        layout: Some(&render_pipeline_layout),
        vertex: wgpu::VertexState {
            module: &shader_modules.v_shader,
            entry_point: "main",
            buffers: &[wgpu::VertexBufferLayout {
                array_stride: 8, // 2 * 4byte float
                step_mode: wgpu::VertexStepMode::Vertex,
                attributes: &wgpu::vertex_attr_array![
                    0 => Float32x2,
                    1 => Float32x2,
                ],
            }],
        },
        fragment: Some(wgpu::FragmentState {
            module: &shader_modules.f_shader,
            entry_point: "main",
            targets: &[Some(wgpu::ColorTargetState {
                format: wgpu::TextureFormat::Bgra8UnormSrgb,
                blend: Some(wgpu::BlendState::REPLACE),
                write_mask: wgpu::ColorWrites::ALL,
            })],
        }),
        primitive: wgpu::PrimitiveState::default(),
        depth_stencil: None,
        multisample: wgpu::MultisampleState::default(),
        multiview: None,
    });

    let compute_pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        label: Some("Compute Pipeline Layout"),
        bind_group_layouts: &[
            &bind_groups.uniform_bgl,
            &bind_groups.compute_bgl,
            &bind_groups.texture_bgl,
        ],
        push_constant_ranges: &[],
    });

    let generate_planet_terrain =
        device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
            label: Some("Generate Planet Terrrain Pipeline"),
            layout: Some(&compute_pipeline_layout),
            module: &shader_modules.generate_terrain,
            entry_point: "generate_planet_terrain_map",
        });

    let generate_moon_terrain = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
        label: Some("Generate Moon Terrain Pipeline"),
        layout: Some(&compute_pipeline_layout),
        module: &shader_modules.generate_terrain,
        entry_point: "generate_moon_terrain_map",
    });

    Pipelines {
        render,
        generate_planet_terrain,
        generate_moon_terrain,
    }
}

pub(crate) fn init_textures(device: &wgpu::Device, queue: &wgpu::Queue) -> Textures {
    let planet_view_desc = wgpu::TextureViewDescriptor {
        label: Some("planet - View Descriptor"),
        format: Some(wgpu::TextureFormat::Rgba32Float),
        dimension: Some(wgpu::TextureViewDimension::D2),
        aspect: wgpu::TextureAspect::All,
        base_mip_level: 0,
        mip_level_count: Some(1),
        base_array_layer: 0,
        array_layer_count: None,
    };

    let planet_tex_extent = wgpu::Extent3d {
        width: PLANET_TEXTURE_WIDTH,
        height: PLANET_TEXTURE_HEIGHT,
        depth_or_array_layers: 1,
    };

    let planet_tex = device.create_texture_with_data(
        queue,
        &wgpu::TextureDescriptor {
            label: Some("planet - Read-Write Storage Texture"),
            size: planet_tex_extent,
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Rgba32Float,
            usage: wgpu::TextureUsages::STORAGE_BINDING
                | wgpu::TextureUsages::TEXTURE_BINDING
                | wgpu::TextureUsages::COPY_DST
                | wgpu::TextureUsages::COPY_SRC,
            view_formats: &[wgpu::TextureFormat::Rgba32Float],
        },
        wgpu::util::TextureDataOrder::default(),
        &[0; PLANET_TEX_BUF_SIZE],
    );

    let planet_view = planet_tex.create_view(&planet_view_desc);

    let planet_sampler = device.create_sampler(&wgpu::SamplerDescriptor {
        label: Some("planet - Sampler"),
        mag_filter: wgpu::FilterMode::Linear,
        min_filter: wgpu::FilterMode::Linear,
        mipmap_filter: wgpu::FilterMode::Linear,
        anisotropy_clamp: 2,
        ..Default::default()
    });

    let moon_view_desc = wgpu::TextureViewDescriptor {
        label: Some("moon - View Descriptor"),
        format: Some(wgpu::TextureFormat::Rgba32Float),
        dimension: Some(wgpu::TextureViewDimension::D2),
        aspect: wgpu::TextureAspect::All,
        base_mip_level: 0,
        mip_level_count: Some(1),
        base_array_layer: 0,
        array_layer_count: None,
    };

    let moon_tex_extent = wgpu::Extent3d {
        width: MOON_TEXTURE_WIDTH,
        height: MOON_TEXTURE_HEIGHT,
        depth_or_array_layers: 1,
    };

    let moon_tex = device.create_texture_with_data(
        queue,
        &wgpu::TextureDescriptor {
            label: Some("moon - Read-Write Storage Texture"),
            size: moon_tex_extent,
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Rgba32Float,
            usage: wgpu::TextureUsages::STORAGE_BINDING
                | wgpu::TextureUsages::TEXTURE_BINDING
                | wgpu::TextureUsages::COPY_DST,
            view_formats: &[wgpu::TextureFormat::Rgba32Float],
        },
        wgpu::util::TextureDataOrder::default(),
        &[0; MOON_TEX_BUF_SIZE],
    );

    let moon_view = moon_tex.create_view(&moon_view_desc);

    let moon_sampler = device.create_sampler(&wgpu::SamplerDescriptor {
        label: Some("moons - Sampler"),
        mag_filter: wgpu::FilterMode::Linear,
        min_filter: wgpu::FilterMode::Linear,
        mipmap_filter: wgpu::FilterMode::Linear,
        ..Default::default()
    });

    Textures {
        planet_tex,
        planet_tex_extent,
        planet_sampler,
        planet_view,
        moon_sampler,
        moon_view,
    }
}
