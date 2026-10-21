import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { z } from '@repo/validation';
import { validateRequest } from '../src/middleware/validate-request.js';
import { errorHandler } from '../src/middleware/error-handler.js';

describe('request validation', () => {
  const server = express();
  server.use(express.json());
  server.post(
    '/validated',
    validateRequest(z.object({ name: z.string().trim().min(1) })),
    (_req, res) => {
      res.json(res.locals.body);
    },
  );
  server.get(
    '/validated',
    validateRequest(
      z.object({ page: z.coerce.number().int().positive() }),
      'query',
    ),
    (_req, res) => {
      res.json(res.locals.query);
    },
  );
  server.use(errorHandler);

  it('returns field errors for invalid bodies', async () => {
    const response = await request(server)
      .post('/validated')
      .send({ name: '' })
      .expect(422);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
    expect(response.body.error.details[0].path).toBe('name');
  });

  it('uses parsed values and strips unknown fields', async () => {
    const response = await request(server)
      .post('/validated')
      .send({ name: ' valid ', unexpected: true })
      .expect(200);
    expect(response.body).toEqual({ name: 'valid' });
  });

  it('coerces query values without mutating Express 5 request.query', async () => {
    const response = await request(server).get('/validated?page=2').expect(200);
    expect(response.body).toEqual({ page: 2 });
    await request(server).get('/validated?page=-1').expect(422);
  });
});
