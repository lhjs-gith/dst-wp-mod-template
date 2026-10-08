// FSB5 reader/writer. Layout taken from the 010 template + parser shipped in
// HearthSim/python-fsb5 (Simon Pinfold), then validated byte-exactly against banks
// that the game already plays.
import fs from 'node:fs';

export const MODE = { NONE: 0, PCM8: 1, PCM16: 2, PCM24: 3, PCM32: 4, PCMFLOAT: 5,
  GCADPCM: 6, IMAADPCM: 7, VAG: 8, HEVAG: 9, XMA: 10, MPEG: 11, CELT: 12, AT9: 13,
  XWMA: 14, VORBIS: 15 };

const FREQ_INDEX = { 8000: 1, 11000: 2, 11025: 3, 16000: 4, 22050: 5, 24000: 6,
  32000: 7, 44100: 8, 48000: 9 };
const FREQ_VALUE = Object.fromEntries(Object.entries(FREQ_INDEX).map(([k, v]) => [v, +k]));
const CHUNK = { CHANNELS: 1, FREQUENCY: 2, LOOP: 3, XMASEEK: 6, DSPCOEFF: 7,
  XWMADATA: 10, VORBISDATA: 11 };

export function parse(buf) {
  if (buf.subarray(0, 4).toString('latin1') !== 'FSB5') throw new Error('not FSB5');
  const version = buf.readUInt32LE(4);
  const numSamples = buf.readUInt32LE(8);
  const sampleHeadersSize = buf.readUInt32LE(0x0C);
  const nameTableSize = buf.readUInt32LE(0x10);
  const dataSize = buf.readUInt32LE(0x14);
  const mode = buf.readUInt32LE(0x18);
  const zero = buf.subarray(0x1C, 0x24);
  const hash = buf.subarray(0x24, 0x34);
  const dummy = buf.subarray(0x34, 0x3C);
  let size = 0x3C;
  let unknown = null;
  if (version === 0) { unknown = buf.readUInt32LE(size); size += 4; }

  const hdr = { version, numSamples, sampleHeadersSize, nameTableSize, dataSize, mode,
    zero: Buffer.from(zero), hash: Buffer.from(hash), dummy: Buffer.from(dummy), unknown, size };

  // sample headers
  let o = size;
  const samples = [];
  for (let i = 0; i < numSamples; i++) {
    const w = buf.readBigUInt64LE(o); o += 8;
    const hasChunk = Number(w & 1n);
    const frequency = Number((w >> 1n) & 0xFn);
    const channels = Number((w >> 5n) & 1n) + 1;
    const dataOffset = Number((w >> 6n) & 0x0FFFFFFFn) * 16;
    const nSamples = Number(w >> 34n);
    const chunks = [];
    let next = hasChunk;
    while (next) {
      const c = buf.readUInt32LE(o); o += 4;
      next = c & 1;
      const csize = (c >> 1) & 0xFFFFFF;
      const ctype = (c >> 25) & 0x7F;
      const payload = buf.subarray(o, o + csize);
      o += csize;
      chunks.push({ type: ctype, size: csize, payload: Buffer.from(payload) });
    }
    samples.push({ frequency, channels, dataOffset, samples: nSamples, chunks, data: null, name: null });
  }
  if (o - size !== sampleHeadersSize) throw new Error(`sample headers ${o - size} != ${sampleHeadersSize}`);

  // name table: offsets array then NUL-terminated strings, offsets relative to table start
  if (nameTableSize) {
    const tableStart = o;
    const offs = [];
    for (let i = 0; i < numSamples; i++) offs.push(buf.readUInt32LE(o + i * 4));
    for (let i = 0; i < numSamples; i++) {
      let s = tableStart + offs[i], e = s;
      while (buf[e] !== 0) e++;
      samples[i].name = buf.subarray(s, e).toString('utf8');
    }
    o = tableStart + nameTableSize;
  }

  const dataStart = size + sampleHeadersSize + nameTableSize;
  const pad = o - dataStart;
  if (pad < 0) throw new Error('prefix shorter than declared');
  if (buf.length - dataStart !== dataSize) throw new Error(`dataSize ${dataSize} != ${buf.length - dataStart}`);
  for (let i = 0; i < numSamples; i++) {
    const end = i + 1 < numSamples ? samples[i + 1].dataOffset : dataSize;
    samples[i].data = buf.subarray(dataStart + samples[i].dataOffset, dataStart + end);
  }
  return { hdr, samples, dataStart, prefixPad: pad };
}

export function serialize(f) {
  const { hdr, samples } = f;
  // sample headers + chunks, and name table, are emitted from parsed values only
  const sh = [];
  for (const s of samples) {
    let w = 0n;
    w |= BigInt(s.chunks.length ? 1 : 0) & 1n;
    w |= (BigInt(s.frequency) & 0xFn) << 1n;
    w |= (BigInt(s.channels - 1) & 1n) << 5n;
    w |= (BigInt(s.dataOffset / 16) & 0x0FFFFFFFn) << 6n;
    w |= BigInt(s.samples) << 34n;
    sh.push(w);
  }
  const body = [];
  samples.forEach((s, i) => {
    const b = Buffer.alloc(8);
    b.writeBigUInt64LE(sh[i]);
    body.push(b);
    s.chunks.forEach((c, ci) => {
      const word = ((ci + 1 < s.chunks.length ? 1 : 0) | ((c.size & 0xFFFFFF) << 1) | (c.type << 25)) >>> 0;
      const cb = Buffer.alloc(4);
      cb.writeUInt32LE(word);
      body.push(cb, c.payload);
    });
  });
  const sampleHeaders = Buffer.concat(body);

  let names = Buffer.alloc(0);
  if (hdr.nameTableSize) {
    const offs = Buffer.alloc(samples.length * 4);
    const strs = [];
    let p = samples.length * 4;
    samples.forEach((s, i) => {
      offs.writeUInt32LE(p, i * 4);
      const b = Buffer.from(s.name, 'utf8');
      strs.push(b, Buffer.from([0]));
      p += b.length + 1;
    });
    names = Buffer.concat([offs, ...strs]);
    if (names.length > hdr.nameTableSize) throw new Error('name table grew');
    if (hdr.numSamples && names.length < hdr.nameTableSize) {
      names = Buffer.concat([names, Buffer.alloc(hdr.nameTableSize - names.length)]);
    }
  }

  const data = Buffer.concat(samples.map(s => s.data));
  if (data.length !== hdr.dataSize) throw new Error(`data ${data.length} != dataSize ${hdr.dataSize}`);

  const head = Buffer.alloc(hdr.size);
  head.write('FSB5', 0, 'latin1');
  head.writeUInt32LE(hdr.version, 4);
  head.writeUInt32LE(hdr.numSamples, 8);
  head.writeUInt32LE(sampleHeaders.length, 0x0C);
  head.writeUInt32LE(names.length, 0x10);
  head.writeUInt32LE(data.length, 0x14);
  head.writeUInt32LE(hdr.mode, 0x18);
  hdr.zero.copy(head, 0x1C);
  hdr.hash.copy(head, 0x24);
  hdr.dummy.copy(head, 0x34);
  if (hdr.unknown !== null) head.writeUInt32LE(hdr.unknown, 0x3C);

  const padLen = f.prefixPad;
  return Buffer.concat([head, sampleHeaders, names, Buffer.alloc(padLen), data]);
}

export function readMp3FrameCount(buf) {
  let n = 0, o = 0;
  while (o + 4 <= buf.length) {
    if (buf[o] === 0xFF && (buf[o + 1] & 0xE0) === 0xE0) {
      const ver = (buf[o + 1] >> 3) & 3, layer = (buf[o + 1] >> 1) & 3;
      const bitrateIdx = (buf[o + 2] >> 4) & 0xF, srIdx = (buf[o + 2] >> 2) & 3, pad = (buf[o + 2] >> 1) & 1;
      if (layer !== 1) break;                       // only MPEG-1 Layer III here
      const mpeg1 = ver === 3;
      const br = mpeg1 ? [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0][bitrateIdx]
                       : [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256, 0][bitrateIdx];
      const sr = mpeg1 ? [44100, 48000, 32000, 0][srIdx] : [22050, 24000, 16000, 0][srIdx];
      const spf = mpeg1 ? 1152 : 576;
      if (!br || !sr) break;
      const slot = mpeg1 ? 1 : 1;
      const flen = Math.floor(144000 * br / sr) + (pad ? slot : 0);
      n++; o += flen;
    } else break;
  }
  return { frames: n, bytes: o };
}

export { FREQ_INDEX, FREQ_VALUE, CHUNK };
