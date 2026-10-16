// mkbank.mjs — build an FSB5 (FMOD Ex sample bank) that Don't Starve Together will
// actually play, from plain MP3 files. No FMOD Designer, no fsbankcl, no FMOD Studio.
//
//   node mkbank.mjs <srcDir> <out.fsb> <donor.fsb> [nat|pad4] [loopDelta] [align]
//
//   <srcDir>      one <name>.mp3 per sample the donor bank declares. <name> must equal the
//                 basename the .fev sounddef references (extension stripped) — normally the
//                 donor IS the .fsb belonging to the .fev shell you borrowed, so its name
//                 table is exactly the list of files you have to provide.
//   <out.fsb>     produced bank.
//   <donor.fsb>   ANY bank the game already plays. Its 60-byte header is copied verbatim
//                 (version, mode, the u32@0x1C codec constant, the opaque build ids at 0x24
//                 and 0x34); only the sizes and the sample data are replaced. Do not invent
//                 that header: the 16 bytes at 0x24 are non-zero in every bank known to play
//                 and zero in every FMOD Studio slice, and nobody has tested which matters.
//   nat|pad4      MP3 payload framing. pad4 zero-pads every frame to a multiple of 4 bytes,
//                 which is what FMOD requires (MPEG slot = 4). nat (raw back-to-back frames)
//                 desyncs from frame 2 on: silent, no error, playing=true. Use pad4.
//   loopDelta     samples trimmed off the loop end (default 1152 = one MP3 frame; the p3r
//                 bank used 469..1117).
//   align         byte alignment of every sample's data offset. MUST be >= 32 and a power of
//                 two. FMOD loads a 16-aligned-but-not-32 bank without a single error
//                 message and then plays nothing — see README route 5.
//
// Input audio must be MPEG-1 Layer III CBR (e.g. ffmpeg -c:a libmp3lame -b:a 160k
// -ar 44100 -ac 2). An ID3v2 tag in front is stripped automatically.
import fs from 'node:fs';
const { parse, serialize, FREQ_INDEX } = await import(new URL('./fsb5.mjs', import.meta.url));

const [srcDir, outFile, donorFile, variant = 'pad4', deltaS = '1152', alignS = '32'] = process.argv.slice(2);
if (!srcDir || !outFile || !donorFile) throw new Error('usage: mkbank.mjs <srcDir> <out.fsb> <donor.fsb> [nat|pad4] [loopDelta] [align]');
const ALIGN = Number(alignS);
if (ALIGN < 32 || (ALIGN & (ALIGN - 1))) throw new Error('align must be a power of two >= 32');
const loopDelta = Number(deltaS);

const donor = parse(fs.readFileSync(donorFile));
if (donor.hdr.mode !== 11) throw new Error('donor bank is not MPEG (mode ' + donor.hdr.mode + '); this tool writes MP3 banks only');
const order = donor.samples.map(s => s.name);

function frame(d, i) {
  if (i + 4 > d.length) return null;
  if (d[i] !== 0xFF || (d[i + 1] & 0xE0) !== 0xE0) return null;
  const b1 = d[i + 1], b2 = d[i + 2];
  if (((b1 >> 3) & 3) !== 3 || ((b1 >> 1) & 3) !== 1) return null; // MPEG-1 Layer III only
  const bitrate = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0][(b2 >> 4) & 0xF];
  const freq = [44100, 48000, 32000, 0][(b2 >> 2) & 3];
  if (!bitrate || !freq) return null;
  return {
    len: Math.floor(144000 * bitrate / freq) + ((b2 >> 1) & 1),
    freq,
    channels: ((b2 >> 6) & 1) ? 1 : 2,
  };
}

function stripId3(d) {
  if (d.subarray(0, 3).toString('latin1') !== 'ID3') return d;
  const size = ((d[6] & 0x7F) << 21) | ((d[7] & 0x7F) << 14) | ((d[8] & 0x7F) << 7) | (d[9] & 0x7F);
  let o = 10 + size;
  if (!frame(d, o)) { for (o = 10; o + 4 <= d.length; o++) if (frame(d, o)) break; }
  return d.subarray(o);
}

const pad4 = n => (n + 3) & ~3;
const samples = [];
let cursor = 0;
for (const name of order) {
  const file = srcDir + '/' + name + '.mp3';
  if (!fs.existsSync(file)) throw new Error('missing ' + file + ' (one mp3 per donor sample, named after the FEV sounddef)');
  const d = stripId3(fs.readFileSync(file));
  const first = frame(d, 0);
  if (!first) throw new Error(name + ': no MPEG-1 Layer III frame at offset 0');
  const list = [];
  for (let o = 0; ; ) {
    const f = frame(d, o);
    if (!f || f.freq !== first.freq || f.channels !== first.channels || o + f.len > d.length) break;
    list.push({ off: o, len: f.len });
    o += f.len;
  }
  if (!list.length) throw new Error(name + ': no walkable CBR frame run');

  let payload;
  if (variant === 'nat') {
    payload = d.subarray(0, list.at(-1).off + list.at(-1).len);
  } else {
    const parts = list.map(f => {
      const b = Buffer.alloc(pad4(f.len));
      d.copy(b, 0, f.off, f.off + f.len);
      return b;
    });
    payload = Buffer.concat(parts);
  }
  const data = Buffer.concat([payload, Buffer.alloc((ALIGN - (payload.length % ALIGN)) % ALIGN)]);
  const n = list.length * 1152;
  const loop = Buffer.alloc(8);
  loop.writeUInt32LE(0, 0);
  loop.writeUInt32LE(Math.max(0, n - loopDelta), 4);

  samples.push({
    name, frequency: FREQ_INDEX[first.freq], channels: first.channels,
    dataOffset: cursor, samples: n, chunks: [{ type: 3, size: 8, payload: loop }], data,
  });
  cursor += data.length;
  console.log(name, 'frames', list.length, 'samples', n, 'sec', (n / first.freq).toFixed(1),
    first.freq + 'Hz', first.channels + 'ch', 'payload', payload.length, 'off', cursor - data.length);
}

const buf = serialize({
  hdr: { ...donor.hdr, zero: Buffer.from(donor.hdr.zero), hash: Buffer.from(donor.hdr.hash),
    dummy: Buffer.from(donor.hdr.dummy), dataSize: cursor },
  samples,
  prefixPad: 0,
});
fs.writeFileSync(outFile, buf);

const back = parse(buf);
const nonaligned = back.samples.filter(s => s.dataOffset % ALIGN !== 0).length;
console.log('WROTE', outFile, buf.length, 'dataStart', back.dataStart, 'samples', back.samples.length,
  'nonaligned', nonaligned, 'roundtrip', Buffer.compare(serialize(back), buf) === 0 ? 'BYTE-EXACT' : 'MISMATCH');
if (nonaligned) throw new Error('INTERNAL: sample offsets are not ' + ALIGN + '-aligned');
