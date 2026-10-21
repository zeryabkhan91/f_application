# AWS deployment

## Container images

Build from the repository root:

```sh
docker build -f apps/api/Dockerfile --target runtime -t f-application-api .
docker build -f apps/api/Dockerfile --target migrations -t f-application-migrations .
```

If your build network uses a private CA, append
`--secret id=build_ca,src=/path/to/trusted-ca.pem`. The Dockerfile makes that
trusted certificate available only during dependency installation and compilation;
it does not disable TLS verification or put the certificate in the runtime image.
In the Codex cloud environment, use the existing `NODE_EXTRA_CA_CERTS` file as
the source and set `BUILDX_CONFIG=/workspace/.cache/buildx` for a writable cache.

Push images to ECR through your deployment pipeline. Use an ECS/Fargate service
for the API and run the migration image as a one-off ECS task with the same RDS
connectivity before rolling out a new API version. Do not run migrations in every
API task at startup. Production images run as a non-root user. The API writes
JSON logs to stdout for CloudWatch and drains HTTP requests on SIGTERM.

## Runtime settings

Provide `DATABASE_URL` through AWS Secrets Manager. Use RDS PostgreSQL, encryption
at rest, private networking, backups, and verified TLS using the current AWS RDS
CA trust configuration. Do not disable certificate validation. Supply
`CORS_ORIGINS=https://your-frontend-domain`, `AWS_REGION`, and `S3_BUCKET` as task
environment settings. Set `TRUST_PROXY_HOPS=1` for a single trusted ALB. The image
sets `NODE_ENV=production`, `HOST=0.0.0.0`, and `PORT=4000`; docs default to disabled.

Configure the ALB target group to call `/health/ready`. The container health check
uses `/health/live`; this allows the task to recover from a temporary database
outage without restarting the process. Give ECS at least 30 seconds of stop
timeout for the API's 25-second graceful-shutdown deadline.

Use separate ECS task roles and execution roles. The execution role reads image,
log, and configured secret resources. The API task role receives only the S3
`GetObject`, `PutObject`, and `DeleteObject` permissions required by the configured
document prefix. Keep buckets private and block public access. Use CloudFront
for the frontend and approved document-delivery patterns as the product requires.
SES can be added when email notification requirements exist.

## Before exposing business endpoints

Define authentication, tenant/user ownership, authorization, and audit requirements.
The current API exposes only health and service information, with no public file
upload or business-data routes. Add those policies with the actual system modules.
The built-in rate limiter keeps counters per process; use AWS WAF or a shared
store when multiple API tasks need a global quota. No AWS resources, deployment
pipeline, Next.js app, or SES configuration are created by this repository setup.
