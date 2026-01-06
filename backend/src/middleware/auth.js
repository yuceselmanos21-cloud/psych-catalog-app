import { getAuth } from '../config/firebase.js';

/**
 * Authentication middleware
 * Verifies Firebase ID token from Authorization header
 */
export async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('❌ Auth: No token provided');
      return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }

    const token = authHeader.split('Bearer ')[1];
    
    if (!token || token.length < 10) {
      console.log('❌ Auth: Invalid token format');
      return res.status(401).json({ error: 'Unauthorized: Invalid token format' });
    }
    
    // Verify Firebase ID token
    const authInstance = getAuth();
    
    if (!authInstance) {
      console.error('❌ Auth: Firebase Admin Auth not initialized');
      return res.status(500).json({ error: 'Server error: Auth not initialized' });
    }
    
    console.log('🔵 Auth: Verifying token...');
    const decodedToken = await authInstance.verifyIdToken(token);
    console.log('✅ Auth: Token verified for user:', decodedToken.uid);
    
    // Attach user info to request
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      role: decodedToken.role || 'client',
    };
    
    next();
  } catch (error) {
    console.error('❌ Auth error:', error.message);
    console.error('❌ Auth error details:', {
      code: error.code,
      message: error.message,
      stack: error.stack?.substring(0, 200),
    });
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
}

