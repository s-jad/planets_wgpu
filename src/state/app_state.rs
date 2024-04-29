use super::control_state::{update_controls, KeyboardState};
use crate::{
    collections::{
        consts::{
            MOON_TEX_DISPATCH_SIZE_X, MOON_TEX_DISPATCH_SIZE_Y, PLANET_TEXTURE_HEIGHT,
            PLANET_TEXTURE_WIDTH, PLANET_TEX_DISPATCH_SIZE_X, PLANET_TEX_DISPATCH_SIZE_Y,
        },
        structs::{BindGroups, Buffers, Params, Pipelines, PlanetTexture, Point},
        vertices::VERTICES,
    },
    init::init_functions::{
        init_bind_groups, init_buffers, init_params, init_pipelines, init_shader_modules,
        init_textures,
    },
    updates::param_updates::{
        update_cpu_read_buffers, update_debug_params_buffer, update_view_params_buffer,
    },
};
use std::sync::Arc;

#[derive(Debug)]
pub(crate) struct State<'a> {
    pub(crate) device: wgpu::Device,
    pub(crate) queue: wgpu::Queue,
    pub(crate) surface: wgpu::Surface<'a>,
    pub(crate) surface_config: wgpu::SurfaceConfiguration,
    pub(crate) size: winit::dpi::PhysicalSize<u32>,
    pub(crate) params: Params,
    pub(crate) buffers: Buffers,
    pub(crate) bind_groups: BindGroups,
    pub(crate) pipelines: Pipelines,
    pub(crate) controls: KeyboardState,
    pub(crate) planet_texture: PlanetTexture,
    pub(crate) app_time: std::time::Instant,
    // Keep window at the bottom,
    // must be dropped after surface
    pub(crate) window: std::sync::Arc<winit::window::Window>,
}

impl<'a> State<'a> {
    pub(crate) async fn new(window: Arc<winit::window::Window>) -> Self {
        let size = window.inner_size();

        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::default());
        let app_time = std::time::Instant::now();

        // SURFACE
        let surface = instance
            .create_surface(Arc::clone(&window))
            .expect("surface init should work");

        // ADAPTER
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::default(),
                force_fallback_adapter: false,
                compatible_surface: Some(&surface),
            })
            .await
            .expect("get_dev_storage_texture:: adapter should work");

        let limits = adapter.limits();

        // DEVICE/QUEUE
        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    label: Some("dev_storage_texture_capable Device"),
                    required_features: wgpu::Features::TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES
                        | wgpu::Features::FLOAT32_FILTERABLE,
                    required_limits: limits,
                },
                None,
            )
            .await
            .expect("get_dev_storage_texture:: device request should work");

        let surface_caps = surface.get_capabilities(&adapter);

        let surface_format = surface_caps
            .formats
            .iter()
            .copied()
            .filter(|f| f.is_srgb())
            .next()
            .unwrap_or(surface_caps.formats[0]);

        let surface_config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: surface_format,
            width: size.width,
            height: size.height,
            present_mode: surface_caps.present_modes[0],
            desired_maximum_frame_latency: 1,
            view_formats: vec![wgpu::TextureFormat::Bgra8UnormSrgb],
            alpha_mode: surface_caps.alpha_modes[0],
        };

        surface.configure(&device, &surface_config);

        let shader_modules = init_shader_modules(&device);
        let params = init_params();
        let buffers = init_buffers(&device, &params);
        let textures = init_textures(&device, &queue);
        let bind_groups = init_bind_groups(&device, &buffers, &textures);
        let pipelines = init_pipelines(&device, &bind_groups, &shader_modules);
        let controls = KeyboardState::new();
        let planet_texture = PlanetTexture {
            planet_tex: textures.planet_tex,
            planet_tex_extent: textures.planet_tex_extent,
        };

        Self {
            device,
            queue,
            surface,
            surface_config,
            size,
            pipelines,
            params,
            buffers,
            bind_groups,
            controls,
            planet_texture,
            app_time,
            // Keep at bottom, must be dropped after surface
            // and declared after it
            window,
        }
    }

    pub(crate) fn update(&mut self) {
        update_controls(self);
        update_debug_params_buffer(self);
        update_view_params_buffer(self);
        update_cpu_read_buffers(self);
    }

    pub(crate) fn render(&mut self) -> Result<(), wgpu::SurfaceError> {
        let output = self.surface.get_current_texture()?;
        let view = output
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Render Encoder"),
            });

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Render Pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                ..Default::default()
            });

            render_pass.set_pipeline(&self.pipelines.render);

            render_pass.set_bind_group(0, &self.bind_groups.uniform_bg, &[]);
            render_pass.set_bind_group(1, &self.bind_groups.frag_bg, &[]);
            render_pass.set_bind_group(2, &self.bind_groups.sampled_texture_bg, &[]);
            render_pass.set_vertex_buffer(0, self.buffers.vertex.slice(..));

            let vertex_range = 0..VERTICES.len() as u32;
            let instance_range = 0..1;
            render_pass.draw(vertex_range, instance_range);
        }

        self.queue.submit(Some(encoder.finish()));
        output.present();

        Ok(())
    }

    pub(crate) fn resize(&mut self, new_size: winit::dpi::PhysicalSize<u32>) {
        if new_size.width > 0 && new_size.height > 0 {
            self.size = new_size;
            self.surface_config.width = new_size.width;
            self.surface_config.height = new_size.height;
            self.surface.configure(&self.device, &self.surface_config);
        }
    }

    pub(crate) fn get_time(&self) -> f32 {
        self.app_time.elapsed().as_secs_f32()
    }

    pub(crate) fn init_planet_terrain(&mut self) {
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Generate terrain - encoder"),
            });

        {
            let mut compute_pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
                label: Some("Generate planet terrain - compute pass"),
                timestamp_writes: None,
            });
            compute_pass.set_pipeline(&self.pipelines.generate_planet_terrain);
            compute_pass.set_bind_group(0, &self.bind_groups.uniform_bg, &[]);
            compute_pass.set_bind_group(1, &self.bind_groups.compute_bg, &[]);
            compute_pass.set_bind_group(2, &self.bind_groups.texture_bg, &[]);
            compute_pass.dispatch_workgroups(
                PLANET_TEX_DISPATCH_SIZE_X,
                PLANET_TEX_DISPATCH_SIZE_Y,
                1,
            );
        }

        self.queue.submit(Some(encoder.finish()));
    }

    pub(crate) fn init_moon_terrain(&mut self) {
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Generate moon terrain - encoder"),
            });
        {
            let mut compute_pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
                label: Some("Generate moon terrain - compute pass"),
                timestamp_writes: None,
            });
            compute_pass.set_pipeline(&self.pipelines.generate_moon_terrain);
            compute_pass.set_bind_group(0, &self.bind_groups.uniform_bg, &[]);
            compute_pass.set_bind_group(1, &self.bind_groups.compute_bg, &[]);
            compute_pass.set_bind_group(2, &self.bind_groups.texture_bg, &[]);
            compute_pass.dispatch_workgroups(MOON_TEX_DISPATCH_SIZE_X, MOON_TEX_DISPATCH_SIZE_Y, 1);
        }

        self.queue.submit(Some(encoder.finish()));
    }

    fn copy_tex_to_buffer(&mut self) {
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Generate moon terrain - encoder"),
            });

        encoder.copy_texture_to_buffer(
            wgpu::ImageCopyTexture {
                texture: &self.planet_texture.planet_tex,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            wgpu::ImageCopyBuffer {
                buffer: &self.buffers.planet_tex_buffer,
                layout: wgpu::ImageDataLayout {
                    offset: 0,
                    bytes_per_row: Some(PLANET_TEXTURE_WIDTH * 4 * 4), // 16bytes -> 4*f32
                    rows_per_image: Some(PLANET_TEXTURE_HEIGHT),
                },
            },
            wgpu::Extent3d {
                width: PLANET_TEXTURE_WIDTH,
                height: PLANET_TEXTURE_HEIGHT,
                depth_or_array_layers: 1,
            },
        );

        self.queue.submit(Some(encoder.finish()));
    }

    fn copy_buffer_data(&mut self) -> Result<Vec<f32>, futures::channel::oneshot::Canceled> {
        let buffer_slice = self.buffers.planet_tex_buffer.slice(..);
        let (tx, rx) = futures::channel::oneshot::channel();

        buffer_slice.map_async(wgpu::MapMode::Read, move |result| {
            tx.send(result).unwrap();
        });

        self.device.poll(wgpu::Maintain::Wait);
        let result = futures::executor::block_on(rx);

        match result {
            Ok(_) => {
                let buf_view = buffer_slice.get_mapped_range();
                let data: &[u8] = bytemuck::cast_slice(&buf_view);
                let data_f32: &[[f32; 4]] = bytemuck::cast_slice(data);
                let mut flattened_data = Vec::new();

                for i in data_f32.into_iter() {
                    flattened_data.extend(i.to_owned());
                }

                return Ok(flattened_data);
            }
            Err(e) => Err(e),
        }
    }

    fn find_extreme_elevations(&self, map: Vec<f32>, count: usize) -> (Vec<Point>, Vec<Point>) {
        let mut y = 0u32;

        let mut indexed = map
            .into_iter()
            .enumerate()
            .map(|(idx, val)| {
                let x = idx as u32 % PLANET_TEXTURE_WIDTH;

                if x == 0 && idx != 0 {
                    y += 1;
                }

                return Point {
                    elevation: val,
                    x,
                    y,
                };
            })
            .collect::<Vec<Point>>();

        println!("indexed first row + 1: {:?}", &indexed[0..2050]);

        indexed.sort_unstable_by(|p1, p2| {
            p1.elevation
                .partial_cmp(&p2.elevation)
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        let min = indexed[0..count + 1].to_vec();
        let max = indexed[(indexed.len() - count)..].to_vec();

        return (max, min);
    }

    pub(crate) fn calculate_wave_dir(&mut self) {
        self.copy_tex_to_buffer();
        let height_map = self.copy_buffer_data();

        match height_map {
            Ok(map) => {
                let elevation_map = map
                    .into_iter()
                    .enumerate()
                    .filter(|(idx, _)| idx % 4 == 0)
                    .map(|(_, val)| val)
                    .collect::<Vec<f32>>();

                println!("elevation_map: {:?}", &elevation_map[0..128]);
                let (max_values, min_values) = self.find_extreme_elevations(elevation_map, 16);

                println!("min: {:?}", min_values);
                println!("max: {:?}", max_values);
            }
            Err(e) => eprintln!("Error mapping planet texture buffer: {:?}", e),
        }
    }
}
