// Main entry point
// Security: Public access removed for HIPAA compliance
// JWT authentication required for all PHI endpoints
import express from 'express';
import { PrismaClient } from '@prisma/client';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import authRoutes from './routes/auth';
import { authenticateToken } from './middleware/auth';

const app = express();
const prisma = new PrismaClient();
const PORT = process.env.PORT || 8080;

// Security: Helmet adds various HTTP headers for security
app.use(helmet());

// Security: CORS configuration
const corsOptions = {
  origin: process.env.FRONTEND_URL || 'https://hero-ui-w53h35jjsq-ue.a.run.app',
  credentials: true,
  optionsSuccessStatus: 200,
};
app.use(cors(corsOptions));

// Security: Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later',
});
app.use('/api', limiter);

// Body parsing
app.use(express.json());

// Public health check endpoint (no auth required)
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Public root endpoint (no auth required)
app.get('/', (req, res) => {
  res.json({
    message: 'DocuHero API',
    version: '2.0.0',
    security: 'Firebase + JWT authentication',
    endpoints: {
      health: '/health',
      auth: '/auth/sync-user, /auth/verify',
      api: '/api/* (authenticated)'
    }
  });
});

// Public authentication routes
app.use('/auth', authRoutes);

// Protected API routes (require authentication)
app.get('/api', authenticateToken, (req, res) => {
  res.json({
    message: 'Protected API endpoint',
    user: req.user,
    info: 'This endpoint requires valid JWT token'
  });
});

// Protected example: Get user profile
app.get('/api/profile', authenticateToken, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.userId },
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

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({ user });
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Error handler
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🔒 Firebase + JWT authentication enabled`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔐 Auth endpoints: /auth/sync-user, /auth/verify`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  await prisma.$disconnect();
  process.exit(0);
});
