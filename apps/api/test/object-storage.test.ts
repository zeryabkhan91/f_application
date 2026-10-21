import { S3Client } from '@aws-sdk/client-s3';
import { describe, expect, it } from 'vitest';
import { createObjectStorage } from '../src/services/object-storage.js';

describe('S3 signing without network access', () => {
  // Test-only fake credentials. No AWS requests are sent by presigning.
  const client = new S3Client({
    region: 'us-east-1',
    requestChecksumCalculation: 'WHEN_REQUIRED',
    credentials: {
      accessKeyId: 'test-access-key',
      secretAccessKey: 'test-secret-key',
    },
  });
  const storage = createObjectStorage(client, 'test-private-bucket');

  it('signs private uploads and downloads for the expected bucket and key', async () => {
    const signed = await storage.presignUpload(
      'documents/one.pdf',
      'application/pdf',
      300,
    );
    const upload = new URL(signed.url);
    expect(upload.hostname).toBe(
      'test-private-bucket.s3.us-east-1.amazonaws.com',
    );
    expect(upload.pathname).toBe('/documents/one.pdf');
    expect(upload.searchParams.get('X-Amz-Expires')).toBe('300');
    expect(upload.searchParams.get('X-Amz-Signature')).toBeTruthy();
    expect(upload.searchParams.get('X-Amz-SignedHeaders')).toContain(
      'x-amz-server-side-encryption',
    );
    expect(signed.headers).toEqual({
      'Content-Type': 'application/pdf',
      'x-amz-server-side-encryption': 'AES256',
    });
    expect(upload.searchParams.has('x-amz-checksum-crc32')).toBe(false);
    const download = new URL(
      await storage.presignDownload('documents/one.pdf'),
    );
    expect(download.searchParams.get('X-Amz-Expires')).toBe('900');
    expect(download.pathname).toBe('/documents/one.pdf');
  });

  it('rejects invalid keys and excessive URL lifetimes', async () => {
    await expect(storage.presignUpload('', 'application/pdf')).rejects.toThrow(
      'Invalid object key',
    );
    expect(() => storage.presignDownload('/absolute')).toThrow(
      'Invalid object key',
    );
    expect(() => storage.presignDownload('文'.repeat(400))).toThrow(
      'Invalid object key',
    );
    expect(() => storage.presignDownload('valid', 3601)).toThrow('expiry');
    expect(() => createObjectStorage(client, '')).toThrow('bucket');
  });
});
