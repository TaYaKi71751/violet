interface PdfImage {
  data: Uint8Array;
  width: number;
  height: number;
}

const encoder = new TextEncoder();

function ascii(value: string): Uint8Array {
  return encoder.encode(value);
}

function concat(chunks: Uint8Array[]): Uint8Array {
  const total = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const output = new Uint8Array(total);
  let offset = 0;

  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.length;
  }

  return output;
}

export function createImagePdf(images: PdfImage[]): Blob {
  const chunks: Uint8Array[] = [];
  const offsets: number[] = [0];
  let position = 0;

  function push(chunk: Uint8Array) {
    chunks.push(chunk);
    position += chunk.length;
  }

  function writeObject(id: number, parts: Uint8Array[]) {
    offsets[id] = position;
    push(ascii(`${id} 0 obj\n`));
    for (const part of parts) push(part);
    push(ascii('\nendobj\n'));
  }

  push(ascii('%PDF-1.4\n%\xff\xff\xff\xff\n'));

  const pageIds = images.map((_, index) => 3 + index * 3);
  const kidRefs = pageIds.map((id) => `${id} 0 R`).join(' ');

  writeObject(1, [ascii('<< /Type /Catalog /Pages 2 0 R >>')]);
  writeObject(2, [ascii(`<< /Type /Pages /Kids [${kidRefs}] /Count ${images.length} >>`)]);

  images.forEach((image, index) => {
    const pageId = 3 + index * 3;
    const contentId = pageId + 1;
    const imageId = pageId + 2;
    const imageName = `Im${index + 1}`;
    const width = Math.max(1, Math.round(image.width));
    const height = Math.max(1, Math.round(image.height));
    const content = ascii(`q\n${width} 0 0 ${height} 0 0 cm\n/${imageName} Do\nQ\n`);

    writeObject(pageId, [
      ascii(
        `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${width} ${height}] ` +
          `/Resources << /XObject << /${imageName} ${imageId} 0 R >> >> ` +
          `/Contents ${contentId} 0 R >>`,
      ),
    ]);

    writeObject(contentId, [
      ascii(`<< /Length ${content.length} >>\nstream\n`),
      content,
      ascii('endstream'),
    ]);

    writeObject(imageId, [
      ascii(
        `<< /Type /XObject /Subtype /Image /Width ${width} /Height ${height} ` +
          `/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode ` +
          `/Length ${image.data.length} >>\nstream\n`,
      ),
      image.data,
      ascii('\nendstream'),
    ]);
  });

  const xrefOffset = position;
  const objectCount = 2 + images.length * 3;
  push(ascii(`xref\n0 ${objectCount + 1}\n`));
  push(ascii('0000000000 65535 f \n'));

  for (let id = 1; id <= objectCount; id += 1) {
    push(ascii(`${String(offsets[id]).padStart(10, '0')} 00000 n \n`));
  }

  push(ascii(
    `trailer\n<< /Size ${objectCount + 1} /Root 1 0 R >>\n` +
      `startxref\n${xrefOffset}\n%%EOF\n`,
  ));

  const data = concat(chunks);
  const buffer = new ArrayBuffer(data.byteLength);
  new Uint8Array(buffer).set(data);
  return new Blob([buffer], { type: 'application/pdf' });
}
