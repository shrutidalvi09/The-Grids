import { randomBytes } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import {
  Controller,
  HttpStatus,
  Inject,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiError } from '../common/api-error.js';
import { ENV, type Env } from '../config/env.js';

export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

/** Detects the image type from its first bytes; the client's MIME type is not trusted. */
export function sniffImage(bytes: Buffer): 'jpg' | 'png' | 'webp' | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'jpg';
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return 'png';
  }
  if (bytes.length >= 12 && bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') {
    return 'webp';
  }
  return null;
}

/**
 * Stores a photo and returns its path (e.g. `/uploads/3f9c….jpg`) to save on
 * a facility or complaint. Local disk for development; swap for object
 * storage (S3/R2) before production.
 */
@Controller('uploads')
export class UploadsController {
  constructor(@Inject(ENV) private readonly env: Env) {}

  @Post()
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_BYTES, files: 1 } }))
  async upload(@UploadedFile() file: Express.Multer.File | undefined): Promise<{ url: string }> {
    if (!file) throw new ApiError(HttpStatus.BAD_REQUEST, 'UNSUPPORTED_FILE', 'Attach an image as "file"');
    const ext = sniffImage(file.buffer);
    if (!ext) throw new ApiError(HttpStatus.BAD_REQUEST, 'UNSUPPORTED_FILE', 'Only JPEG, PNG or WebP images');

    const name = `${randomBytes(16).toString('hex')}.${ext}`;
    const dir = path.resolve(this.env.uploadsDir);
    await mkdir(dir, { recursive: true });
    await writeFile(path.join(dir, name), file.buffer);
    return { url: `/uploads/${name}` };
  }
}
