pub(crate) const SCREEN_WIDTH: u32 = 1376;
pub(crate) const SCREEN_HEIGHT: u32 = 768;
pub(crate) const ASPECT: f32 = SCREEN_WIDTH as f32 / SCREEN_HEIGHT as f32;
pub(crate) const FOV_RAD: f32 = 0.1708;
pub(crate) const CLIP_NEAR: f32 = 0.1;
pub(crate) const CLIP_FAR: f32 = 300.0;

pub(crate) const PLANET_TEXTURE_WIDTH: u32 = 2048;
pub(crate) const PLANET_TEXTURE_HEIGHT: u32 = 2048;
pub(crate) const MOON_TEXTURE_WIDTH: u32 = 512;
pub(crate) const MOON_TEXTURE_HEIGHT: u32 = 512;

pub(crate) const PLANET_TEX_DISPATCH_SIZE_X: u32 = ((PLANET_TEXTURE_WIDTH).saturating_add(32)) / 32;
pub(crate) const PLANET_TEX_DISPATCH_SIZE_Y: u32 =
    ((PLANET_TEXTURE_HEIGHT).saturating_add(32)) / 32;
pub(crate) const MOON_TEX_DISPATCH_SIZE_X: u32 = ((MOON_TEXTURE_WIDTH).saturating_add(32)) / 32;
pub(crate) const MOON_TEX_DISPATCH_SIZE_Y: u32 = ((MOON_TEXTURE_HEIGHT).saturating_add(32)) / 32;

pub(crate) const PLANET_TEX_BUF_SIZE: usize = PLANET_TEXTURE_WIDTH as usize
    * PLANET_TEXTURE_HEIGHT as usize
    * 4
    * (std::mem::size_of::<f32>());

pub(crate) const MOON_TEX_BUF_SIZE: usize =
    MOON_TEXTURE_WIDTH as usize * MOON_TEXTURE_HEIGHT as usize * 4 * (std::mem::size_of::<f32>());
