use std::collections::HashSet;
use std::thread;
use std::time;

use winit::keyboard::{KeyCode, PhysicalKey};

// use crate::updates::update_functions::update_terrain_buffer;

use crate::updates::param_updates::update_view_params_buffer;

use super::app_state::State;

#[derive(Debug, Copy, Clone)]
pub(crate) enum KeyboardMode {
    DEBUG,
    VIEW,
    TERRAIN,
    PRINT,
}

#[derive(Debug, Clone)]
pub(crate) struct KeyboardState {
    keys: HashSet<winit::keyboard::PhysicalKey>,
    mode: KeyboardMode,
}

impl KeyboardState {
    pub(crate) fn new() -> Self {
        Self {
            keys: HashSet::new(),
            mode: KeyboardMode::PRINT,
        }
    }

    pub(crate) fn key_pressed(&self, key: winit::keyboard::PhysicalKey) -> bool {
        self.keys.contains(&key)
    }

    pub(crate) fn handle_keyboard_input(&mut self, input: &winit::event::KeyEvent) {
        let key = input.physical_key;
        if input.state == winit::event::ElementState::Pressed {
            self.keys.insert(key);
        } else {
            self.keys.remove(&key);
        }
    }

    pub(crate) fn clear_keys(&mut self) {
        self.keys.clear();
    }

    pub(crate) fn get_keys(&self) -> &HashSet<winit::keyboard::PhysicalKey> {
        &self.keys
    }

    pub(crate) fn get_mode(&self) -> &KeyboardMode {
        &self.mode
    }

    pub(crate) fn set_mode(&mut self, new_mode: KeyboardMode) {
        self.mode = new_mode;
    }
}

pub(crate) fn print_gpu_data<T: bytemuck::Pod + std::fmt::Debug>(
    device: &wgpu::Device,
    buffer: &wgpu::Buffer,
    obj_label: &str,
) {
    // Map the buffer for reading
    let buffer_slice = buffer.slice(..);
    let (tx, rx) = futures::channel::oneshot::channel();

    buffer_slice.map_async(wgpu::MapMode::Read, move |result| {
        tx.send(result).unwrap();
    });

    println!("buffer size: {:?}", buffer.size());
    // Wait for the GPU to finish executing the commands
    device.poll(wgpu::Maintain::Wait);
    // Wait for the buffer to be mapped
    let result = futures::executor::block_on(rx);

    match result {
        Ok(_) => {
            let buf_view = buffer_slice.get_mapped_range();
            let data: &[T] = bytemuck::cast_slice(&buf_view);

            // Print the boids current properties
            for (i, obj) in data.iter().enumerate() {
                println!("{} {}:\n{:?}", obj_label, i, obj);
            }

            drop(buf_view);
            buffer.unmap();
        }
        Err(e) => eprintln!("Error retrieving gpu data: {:?}", e),
    }
}

pub(crate) fn update_controls(state: &mut State) {
    if state.controls.key_pressed(PhysicalKey::Code(KeyCode::KeyP)) {
        state.controls.set_mode(KeyboardMode::DEBUG);
    } else if state
        .controls
        .key_pressed(PhysicalKey::Code(KeyCode::Digit1))
    {
        state.controls.set_mode(KeyboardMode::TERRAIN);
    } else if state
        .controls
        .key_pressed(PhysicalKey::Code(KeyCode::Digit2))
    {
        state.controls.set_mode(KeyboardMode::VIEW);
    } else if state
        .controls
        .key_pressed(PhysicalKey::Code(KeyCode::Digit3))
    {
        state.controls.set_mode(KeyboardMode::PRINT);
    }

    match state.controls.get_mode() {
        KeyboardMode::DEBUG => debug_controls(state),
        KeyboardMode::VIEW => view_controls(state),
        KeyboardMode::TERRAIN => terrain_controls(state),
        KeyboardMode::PRINT => print_controls(state),
    }
}

fn debug_controls(state: &mut State) {
    let pressed = state.controls.get_keys();

    if pressed.contains(&PhysicalKey::Code(KeyCode::KeyS)) {
        print_gpu_data::<[f32; 4]>(
            &state.device,
            &state.buffers.cpu_read_generic_debug,
            "Debug",
        );
        thread::sleep(time::Duration::from_millis(50));
        state.controls.set_mode(KeyboardMode::TERRAIN);
    } else if pressed.contains(&PhysicalKey::Code(KeyCode::KeyA)) {
        print_gpu_data::<[[f32; 4]; 512]>(
            &state.device,
            &state.buffers.cpu_read_generic_debug_array,
            "Debug",
        );
        thread::sleep(time::Duration::from_millis(50));
        state.controls.set_mode(KeyboardMode::TERRAIN);
    }
}

fn terrain_controls(state: &mut State) {
    let pressed = state.controls.get_keys();
    let mut dval_f = 0.0f32;
    let mut dval_i = 0i32;

    if pressed.contains(&PhysicalKey::Code(KeyCode::ArrowUp)) {
        dval_f = 1.0f32;
        dval_i = 1;
    } else if pressed.contains(&PhysicalKey::Code(KeyCode::ArrowDown)) {
        dval_f = -1.0f32;
        dval_i = -1;
    }

    // FBM
    //  if pressed.contains(&PhysicalKey::Code(KeyCode::Period)) {
    //      let maxv = &mut state.params.terrain_params.octaves;
    //      *maxv = i32::max(0i32, *maxv + (1 * dval_i));
    //      update_terrain_params_buffer(state);
    //  }
}

fn view_controls(state: &mut State) {
    let pressed = state.controls.get_keys();
    let mz = state.params.view_params.zoom;

    if pressed.contains(&PhysicalKey::Code(KeyCode::ArrowLeft)) {
        if pressed.contains(&PhysicalKey::Code(KeyCode::ShiftLeft)) {
            state.params.view_params.x_rot = f32::max(0.0, state.params.view_params.x_rot - 0.01);
            update_view_params_buffer(state);
        } else {
            state.params.view_params.x_shift -= 0.01 / mz;
            update_view_params_buffer(state);
        }
    } else if pressed.contains(&PhysicalKey::Code(KeyCode::ArrowRight)) {
        if pressed.contains(&PhysicalKey::Code(KeyCode::ShiftLeft)) {
            state.params.view_params.x_rot += 0.01;
            update_view_params_buffer(state);
        } else {
            state.params.view_params.x_shift += 0.01 / mz;
            update_view_params_buffer(state);
        }
    } else if pressed.contains(&PhysicalKey::Code(KeyCode::ArrowUp)) {
        if pressed.contains(&PhysicalKey::Code(KeyCode::ShiftLeft)) {
            state.params.view_params.y_rot = f32::max(0.0, state.params.view_params.y_rot - 0.01);
            update_view_params_buffer(state);
        } else {
            state.params.view_params.y_shift -= 0.01 / mz;
            update_view_params_buffer(state);
        }
    } else if pressed.contains(&PhysicalKey::Code(KeyCode::ArrowDown)) {
        if pressed.contains(&PhysicalKey::Code(KeyCode::ShiftLeft)) {
            state.params.view_params.y_rot += 0.01;
            update_view_params_buffer(state);
        } else {
            state.params.view_params.y_shift += 0.01 / mz;
            update_view_params_buffer(state);
        }
    } else if pressed.contains(&PhysicalKey::Code(KeyCode::KeyX)) {
        state.params.view_params.zoom -= 0.1 * mz;
        update_view_params_buffer(state);
    } else if pressed.contains(&PhysicalKey::Code(KeyCode::KeyZ)) {
        state.params.view_params.zoom += 0.1 * mz;
        update_view_params_buffer(state);
    }
}

fn print_controls(state: &State) {
    let pressed = state.controls.get_keys();

    // PRINT CURRENT FRAME --------------------------------------------------------
    //if pressed.contains(&PhysicalKey::Code(KeyCode::Space)) {
    //    capture_frame_and_save(&state.device, &state.queue, &state.surface);
    //}

    // PRINT CURRENT PARAMETER VALUES ----------------------------------------------
    if pressed.contains(&PhysicalKey::Code(KeyCode::KeyT)) {
        println!("\nterrain_params:\n{:#?}", state.params.terrain_params);
        thread::sleep(time::Duration::from_millis(50));
    } else if pressed.contains(&PhysicalKey::Code(KeyCode::KeyV)) {
        println!("\nterrain_params:\n{:#?}", state.params.view_params);
        thread::sleep(time::Duration::from_millis(50));
    } else if pressed.contains(&PhysicalKey::Code(KeyCode::KeyR)) {
        println!("\nterrain_params:\n{:#?}", state.params.ray_params);
        thread::sleep(time::Duration::from_millis(50));
    }
}
