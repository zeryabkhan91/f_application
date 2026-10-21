import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

/** Internal service only. Authorize ownership and generate object keys before calling it. */
export function createObjectStorage(client: S3Client, bucket: string) {
  if (!bucket.trim()) throw new Error('S3 bucket is required');
  return {
    async presignUpload(key: string, contentType: string, expiresIn = 900) {
      assertObjectKey(key);
      assertExpiry(expiresIn);
      const url = await getSignedUrl(
        client,
        new PutObjectCommand({
          Bucket: bucket,
          Key: key,
          ContentType: contentType,
          ServerSideEncryption: 'AES256',
        }),
        { expiresIn },
      );
      // SSE headers remain signed headers rather than query parameters.
      return {
        url,
        headers: {
          'Content-Type': contentType,
          'x-amz-server-side-encryption': 'AES256',
        },
      };
    },
    presignDownload(key: string, expiresIn = 900) {
      assertObjectKey(key);
      assertExpiry(expiresIn);
      return getSignedUrl(
        client,
        new GetObjectCommand({
          Bucket: bucket,
          Key: key,
        }),
        { expiresIn },
      );
    },
    async remove(key: string) {
      assertObjectKey(key);
      await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
    },
  };
}

export function createS3Client(config: {
  AWS_REGION: string;
  S3_ENDPOINT?: string;
  S3_FORCE_PATH_STYLE: boolean;
}) {
  // The default credential chain supports ECS task roles, profiles, and local credentials.
  return new S3Client({
    region: config.AWS_REGION,
    endpoint: config.S3_ENDPOINT,
    forcePathStyle: config.S3_FORCE_PATH_STYLE,
    // The browser supplies the upload body after signing; do not checksum an empty body.
    requestChecksumCalculation: 'WHEN_REQUIRED',
  });
}

function assertObjectKey(key: string) {
  if (
    !key.trim() ||
    Buffer.byteLength(key, 'utf8') > 1024 ||
    key.startsWith('/')
  ) {
    throw new Error('Invalid object key');
  }
}

function assertExpiry(expiresIn: number) {
  if (!Number.isInteger(expiresIn) || expiresIn < 1 || expiresIn > 3600) {
    throw new Error('Signed URL expiry must be between 1 and 3600 seconds');
  }
}
