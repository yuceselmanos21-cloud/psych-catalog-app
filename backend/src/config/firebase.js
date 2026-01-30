import admin from 'firebase-admin';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { readFileSync } from 'fs';

// ✅ .env dosyasını backend klasöründen oku
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const envPath = join(__dirname, '../../.env');

// ✅ FIREBASE_SERVICE_ACCOUNT'u .env dosyasından doğrudan oku (dotenv JSON'u bozuyor)
// Bu fonksiyon sadece bir kez çalışacak ve değeri cache'leyecek
let _cachedServiceAccount = null;

function loadFirebaseServiceAccount() {
  if (_cachedServiceAccount !== null) {
    return _cachedServiceAccount;
  }

  try {
    console.log('🔵 .env dosyası okunuyor:', envPath);
    const envContent = readFileSync(envPath, 'utf-8');
    const lines = envContent.split(/\r?\n/); // Windows ve Unix line endings
    const firebaseLine = lines.find(line => line.trim().startsWith('FIREBASE_SERVICE_ACCOUNT='));
    
    if (!firebaseLine) {
      console.warn('⚠️  .env dosyasında FIREBASE_SERVICE_ACCOUNT satırı bulunamadı');
      _cachedServiceAccount = null;
      return null;
    }

    // FIREBASE_SERVICE_ACCOUNT={"json":"here"} formatından JSON'u çıkar
    const match = firebaseLine.match(/^FIREBASE_SERVICE_ACCOUNT=(.+)$/);
    if (!match || !match[1]) {
      console.error('❌ FIREBASE_SERVICE_ACCOUNT satırı parse edilemedi');
      _cachedServiceAccount = null;
      return null;
    }

    let jsonStr = match[1].trim();
    
    // Eğer tırnak içindeyse, tırnakları kaldır
    if ((jsonStr.startsWith('"') && jsonStr.endsWith('"')) || 
        (jsonStr.startsWith("'") && jsonStr.endsWith("'"))) {
      jsonStr = jsonStr.slice(1, -1);
    }
    
    // ✅ JSON string'ini olduğu gibi kullan (escape karakterleri zaten JSON formatında)
    // PowerShell ConvertTo-Json zaten escape ediyor, ekstra işlem yapma
    
    // JSON'u parse et ve validate et
    try {
      const parsed = JSON.parse(jsonStr);
      
      if (!parsed.project_id) {
        console.error('❌ Service account JSON missing project_id');
        _cachedServiceAccount = null;
        return null;
      }
      
      if (!parsed.private_key) {
        console.error('❌ Service account JSON missing private_key');
        _cachedServiceAccount = null;
        return null;
      }
      
      console.log('✅ FIREBASE_SERVICE_ACCOUNT .env dosyasından doğrudan okundu');
      console.log('✅ project_id:', parsed.project_id);
      console.log('✅ client_email:', parsed.client_email?.substring(0, 40) + '...');
      
      _cachedServiceAccount = jsonStr;
      process.env.FIREBASE_SERVICE_ACCOUNT = jsonStr;
      return jsonStr;
    } catch (parseError) {
      console.error('❌ JSON parse hatası (doğrudan okuma):', parseError.message);
      console.error('❌ İlk 200 karakter:', jsonStr.substring(0, 200));
      _cachedServiceAccount = null;
      return null;
    }
  } catch (readError) {
    console.error('❌ .env dosyası doğrudan okunamadı:', readError.message);
    _cachedServiceAccount = null;
    return null;
  }
}

/**
 * Initialize Firebase Admin SDK
 */
let _db = null;
let _auth = null;

export function initializeFirebase() {
  if (admin.apps.length > 0) {
    console.log('🔵 Firebase already initialized, returning existing app');
    return admin.app();
  }
  
  try {
    // ✅ Önce .env dosyasından service account'u yükle
    const serviceAccountStr = loadFirebaseServiceAccount();
    
    let app;
    if (serviceAccountStr) {
      console.log('🔵 Using FIREBASE_SERVICE_ACCOUNT from .env');
      console.log('🔵 FIREBASE_SERVICE_ACCOUNT length:', serviceAccountStr.length);
      
      try {
        const serviceAccount = JSON.parse(serviceAccountStr);
        console.log('🔵 Service account parsed successfully');
        console.log('🔵 project_id:', serviceAccount.project_id);
        console.log('🔵 client_email:', serviceAccount.client_email?.substring(0, 40) + '...');
        
        if (!serviceAccount.project_id) {
          throw new Error('Service account JSON missing project_id');
        }
        
        if (!serviceAccount.private_key) {
          throw new Error('Service account JSON missing private_key');
        }
        
        console.log('🔵 Initializing Firebase Admin with service account...');
        app = admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: serviceAccount.project_id, // ✅ Explicit project ID
        });
        console.log('✅ Firebase Admin app initialized with projectId:', serviceAccount.project_id);
        
        // ✅ Firestore settings - proxy ve timeout ayarları
        const firestoreSettings = {
          ignoreUndefinedProperties: true,
        };
        
        // Firestore instance'ı al ve settings uygula
        const firestore = admin.firestore();
        firestore.settings(firestoreSettings);
        console.log('✅ Firestore settings configured');
      } catch (parseError) {
        console.error('❌ Error parsing FIREBASE_SERVICE_ACCOUNT:', parseError.message);
        console.error('❌ Error stack:', parseError.stack);
        console.error('❌ First 200 chars of FIREBASE_SERVICE_ACCOUNT:', serviceAccountStr?.substring(0, 200));
        throw new Error(`Failed to parse FIREBASE_SERVICE_ACCOUNT: ${parseError.message}`);
      }
    } else {
      console.log('⚠️  FIREBASE_SERVICE_ACCOUNT not found in .env');
      console.log('🔵 Attempting to use default Firebase credentials...');
      // Use default credentials (for local development or GCP)
      // This requires GOOGLE_APPLICATION_CREDENTIALS environment variable
      // or running on GCP/Cloud Run
      try {
        app = admin.initializeApp();
        console.log('✅ Firebase Admin initialized with default credentials');
      } catch (defaultError) {
        console.error('❌ Default credentials also failed:', defaultError.message);
        throw new Error(`Firebase initialization failed. Set FIREBASE_SERVICE_ACCOUNT in .env or GOOGLE_APPLICATION_CREDENTIALS. Error: ${defaultError.message}`);
      }
    }
    
    _db = admin.firestore();
    _auth = admin.auth();
    console.log('✅ Firebase Admin initialized successfully');
    console.log('✅ Firestore available:', !!_db);
    console.log('✅ Auth available:', !!_auth);
    console.log('✅ App name:', app.name);
    console.log('✅ App project ID:', app.options.projectId);
    return app;
  } catch (error) {
    console.error('❌ Firebase Admin initialization failed:', error.message);
    console.error('❌ Error code:', error.code);
    console.error('❌ Error stack:', error.stack);
    throw error; // ✅ Always throw, never return null
  }
}

export function getDb() {
  if (!_db) {
    console.log('🔵 getDb() called, initializing Firebase...');
    console.log('🔵 FIREBASE_SERVICE_ACCOUNT exists:', !!process.env.FIREBASE_SERVICE_ACCOUNT);
    
    try {
      const app = initializeFirebase();
      if (!app) {
        console.error('❌ Firebase Admin SDK initialization returned null');
        throw new Error('Firebase Admin SDK could not be initialized. Check FIREBASE_SERVICE_ACCOUNT in .env');
      }
      
      _db = admin.firestore();
      if (!_db) {
        throw new Error('Firestore could not be initialized');
      }
      console.log('✅ Firestore instance created successfully');
    } catch (error) {
      console.error('❌ Error in getDb():', error.message);
      console.error('❌ Error stack:', error.stack);
      throw error; // Re-throw to preserve original error
    }
  }
  return _db;
}

export function getAuth() {
  if (!_auth) {
    const app = initializeFirebase();
    if (!app) {
      throw new Error('Firebase Admin SDK could not be initialized. Check FIREBASE_SERVICE_ACCOUNT in .env');
    }
    _auth = admin.auth();
    if (!_auth) {
      throw new Error('Auth could not be initialized');
    }
  }
  return _auth;
}

// For backward compatibility
export const db = new Proxy({}, {
  get(target, prop) {
    return getDb()[prop];
  }
});

export const auth = new Proxy({}, {
  get(target, prop) {
    return getAuth()[prop];
  }
});

