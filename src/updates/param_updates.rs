use crate::{
    collections::structs::{DebugParams, ViewParams},
    state::app_state::State,
};

pub(crate) fn update_view_params_buffer(state: &mut State) {
    let new_view_params = ViewParams {
        x_shift: state.params.view_params.x_shift,
        y_shift: state.params.view_params.y_shift,
        x_rot: state.params.view_params.x_rot,
        y_rot: state.params.view_params.y_rot,
        zoom: state.params.view_params.zoom,
        time_modifier: state.params.view_params.time_modifier,
        fov_degrees: state.params.view_params.fov_degrees,
    };

    state.queue.write_buffer(
        &state.buffers.view_params,
        0,
        bytemuck::cast_slice(&[new_view_params]),
    );
}

pub(crate) fn update_debug_params_buffer(state: &mut State) {
    let new_debug_params = DebugParams {
        pole_start: state.params.debug_params.pole_start,
        pole_scale: state.params.debug_params.pole_scale,
    };

    state.queue.write_buffer(
        &state.buffers.debug_params,
        0,
        bytemuck::cast_slice(&[new_debug_params]),
    );
}

pub(crate) fn update_cpu_read_buffers(state: &mut State) {
    let mut encoder = state
        .device
        .create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("update_cpu_read_buffers encoder"),
        });

    encoder.copy_buffer_to_buffer(
        &state.buffers.generic_debug,
        0,
        &state.buffers.cpu_read_generic_debug,
        0,
        (std::mem::size_of::<[f32; 4]>()) as wgpu::BufferAddress,
    );

    encoder.copy_buffer_to_buffer(
        &state.buffers.generic_debug_array,
        0,
        &state.buffers.cpu_read_generic_debug_array,
        0,
        (std::mem::size_of::<[[f32; 4]; 512]>()) as wgpu::BufferAddress,
    );

    state.queue.submit(Some(encoder.finish()));
}
