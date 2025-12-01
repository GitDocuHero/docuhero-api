// Authentication routes: Firebase-based authentication
// Firebase handles auth, this API syncs users to database
import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { body, validationResult } from 'express-validator';
import { generateToken } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

/**
 * POST /auth/sync-user
 * Sync Firebase user to database (called after Firebase auth)
 */
router.post(
  '/sync-user',
  [
    body('firebaseUid').notEmpty(),
    body('email').optional().isEmail().normalizeEmail(),
    body('phone').optional(),
    body('firstName').trim().notEmpty(),
    body('lastName').trim().notEmpty(),
    body('role').isIn(['AGENCY_ADMIN', 'EMPLOYEE', 'GUARDIAN', 'CASE_MANAGER']),
  ],
  async (req: Request, res: Response): Promise<void> => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      res.status(400).json({ errors: errors.array() });
      return;
    }

    const { firebaseUid, email, phone, firstName, lastName, role, agencyId } = req.body;

    try {
      // Upsert user (create if not exists, update if exists)
      const user = await prisma.user.upsert({
        where: { firebaseUid },
        create: {
          firebaseUid,
          email: email || null,
          phone: phone || null,
          firstName,
          lastName,
          role,
          agencyId: agencyId || null,
          status: 'PENDING',
        },
        update: {
          email: email || null,
          phone: phone || null,
          firstName,
          lastName,
        },
        select: {
          id: true,
          firebaseUid: true,
          email: true,
          phone: true,
          firstName: true,
          lastName: true,
          role: true,
          status: true,
          agencyId: true,
          createdAt: true,
        },
      });

      // Generate JWT token for API access
      const token = generateToken({
        userId: user.id,
        email: user.email || user.phone || '',
        role: user.role,
      });

      res.status(200).json({
        message: 'User synced successfully',
        user,
        token,
      });
    } catch (error) {
      console.error('User sync error:', error);
      res.status(500).json({ error: 'Failed to sync user' });
    }
  }
);

/**
 * POST /auth/verify
 * Verify if token is valid (no authentication required)
 */
router.post('/verify', async (req: Request, res: Response): Promise<void> => {
  const { token } = req.body;

  if (!token) {
    res.status(400).json({ error: 'Token required' });
    return;
  }

  try {
    const { verifyToken } = await import('../middleware/auth');
    const payload = verifyToken(token);

    if (!payload) {
      res.status(401).json({ valid: false, error: 'Invalid or expired token' });
      return;
    }

    res.json({
      valid: true,
      user: payload,
    });
  } catch (error) {
    res.status(500).json({ error: 'Token verification failed' });
  }
});

export default router;
