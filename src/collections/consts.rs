pub(crate) const SCREEN_WIDTH: u32 = 1376;
pub(crate) const SCREEN_HEIGHT: u32 = 768;
pub(crate) const DISPATCH_SIZE_X: u32 = ((SCREEN_WIDTH as u32).saturating_add(32)) / 32;
pub(crate) const DISPATCH_SIZE_Y: u32 = ((SCREEN_HEIGHT as u32).saturating_add(32)) / 32;

pub(crate) const TERRAIN_TEX_BUF_SIZE: usize =
    SCREEN_WIDTH as usize * SCREEN_HEIGHT as usize * 4 * (std::mem::size_of::<f32>());
