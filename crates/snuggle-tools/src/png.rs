//! A PNG writer with no compression (stored deflate blocks): the pictures are
//! small, flat and only read by people.

fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xFFFF_FFFFu32;
    for &b in data {
        crc ^= b as u32;
        for _ in 0..8 {
            crc = if crc & 1 != 0 {
                (crc >> 1) ^ 0xEDB8_8320
            } else {
                crc >> 1
            };
        }
    }
    !crc
}

fn adler32(data: &[u8]) -> u32 {
    let (mut a, mut b) = (1u32, 0u32);
    for &x in data {
        a = (a + x as u32) % 65521;
        b = (b + a) % 65521;
    }
    (b << 16) | a
}

fn chunk(out: &mut Vec<u8>, tag: &[u8; 4], body: &[u8]) {
    out.extend_from_slice(&(body.len() as u32).to_be_bytes());
    let mut tb = tag.to_vec();
    tb.extend_from_slice(body);
    out.extend_from_slice(&tb);
    out.extend_from_slice(&crc32(&tb).to_be_bytes());
}

/// An RGB picture, 8 bits a channel, `rgb.len() == width * height * 3`.
pub fn encode(width: usize, height: usize, rgb: &[u8]) -> Vec<u8> {
    let mut raw = Vec::with_capacity(height * (width * 3 + 1));
    for y in 0..height {
        raw.push(0);
        raw.extend_from_slice(&rgb[y * width * 3..(y + 1) * width * 3]);
    }
    let mut z = vec![0x78, 0x01];
    let mut chunks = raw.chunks(65535).peekable();
    while let Some(c) = chunks.next() {
        z.push(if chunks.peek().is_none() { 1 } else { 0 });
        z.extend_from_slice(&(c.len() as u16).to_le_bytes());
        z.extend_from_slice(&(!(c.len() as u16)).to_le_bytes());
        z.extend_from_slice(c);
    }
    z.extend_from_slice(&adler32(&raw).to_be_bytes());
    let mut out = b"\x89PNG\r\n\x1a\n".to_vec();
    let mut ihdr = Vec::new();
    ihdr.extend_from_slice(&(width as u32).to_be_bytes());
    ihdr.extend_from_slice(&(height as u32).to_be_bytes());
    ihdr.extend_from_slice(&[8, 2, 0, 0, 0]);
    chunk(&mut out, b"IHDR", &ihdr);
    chunk(&mut out, b"IDAT", &z);
    chunk(&mut out, b"IEND", &[]);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn checksums() {
        assert_eq!(crc32(b"123456789"), 0xCBF4_3926);
        assert_eq!(adler32(b"Wikipedia"), 0x11E6_0398);
    }

    #[test]
    fn one_pixel() {
        let p = encode(1, 1, &[255, 0, 0]);
        assert_eq!(&p[..8], b"\x89PNG\r\n\x1a\n");
        assert!(p.ends_with(&[0xAE, 0x42, 0x60, 0x82]));
    }
}
