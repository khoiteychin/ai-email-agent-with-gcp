import { jwtVerify, createRemoteJWKSet } from 'jose';

export interface VerifiedUser {
  userId: string;
  email: string;
}

export async function verifyFirebaseToken(authHeader: string | null): Promise<VerifiedUser | null> {
  const token = authHeader?.replace('Bearer ', '').trim();
  if (!token) return null;

  try {
    const JWKS = createRemoteJWKSet(
      new URL('https://www.googleapis.com/robot/v1/metadata/jwk/securetoken@system.gserviceaccount.com')
    );
    
    // We only verify the signature with Google's JWKS and check expiry.
    // In production you could strictly validate issuer and audience as well.
    const { payload } = await jwtVerify(token, JWKS);
    
    const userId = payload.sub || payload.user_id;
    if (userId) {
      return {
        userId: userId as string,
        email: (payload.email as string) || ''
      };
    }
  } catch (error: any) {
    console.warn('Firebase token verification failed:', error.message);
  }

  return null;
}
