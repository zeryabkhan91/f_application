import type { NumberSequenceType, OrganizationContext } from '@repo/types';
import type { Prisma } from './generated/prisma/client.js';

/** The increment and the document insert must share the surrounding scoped transaction. */
export async function nextDocumentNumber(
  tx: Prisma.TransactionClient,
  context: OrganizationContext,
  type: NumberSequenceType,
) {
  const sequence = await tx.numberSequence.update({
    where: {
      tenantId_organizationId_type: {
        tenantId: context.tenantId,
        organizationId: context.organizationId,
        type,
      },
    },
    data: { currentNumber: { increment: 1 }, updatedBy: context.userId },
    select: { prefix: true, currentNumber: true, padding: true },
  });
  return `${sequence.prefix}${sequence.currentNumber.toString().padStart(sequence.padding, '0')}`;
}
