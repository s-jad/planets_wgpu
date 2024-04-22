use nalgebra::{Matrix4, Perspective3};

use crate::collections::{
    consts::{ASPECT, CLIP_FAR, CLIP_NEAR, FOV_RAD},
    structs::PerspectiveUniform,
};

pub(crate) fn get_perspective_projection() -> PerspectiveUniform {
    let projection = Perspective3::new(ASPECT, FOV_RAD, CLIP_NEAR, CLIP_FAR);
    let projection_matrix = projection.as_matrix();
    let adjoint = projection_matrix.adjoint();
    let inverse = projection_matrix
        .try_inverse()
        .unwrap_or(Matrix4::identity());

    if inverse == Matrix4::identity() {
        eprintln!("Coudn't calculate matrix inverse");
    } else {
        println!("projection matrix: {:?}", projection_matrix);
        println!("inverse projection matrix: {:?}", inverse);
    }

    return PerspectiveUniform { adjoint, inverse };
}
