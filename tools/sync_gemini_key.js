/**
 * Bu script, lib/analysis_secrets.dart dosyasından Gemini API key'ini okuyup
 * Firebase Functions config'e set eder.
 * 
 * Kullanım: node tools/sync_gemini_key.js
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const SECRETS_FILE = path.join(__dirname, '..', 'lib', 'analysis_secrets.dart');
const CONFIG_KEY = 'ai.key';

function extractApiKey() {
  try {
    const content = fs.readFileSync(SECRETS_FILE, 'utf8');
    
    // Gemini API key'ini bul (static const String geminiApiKey = '...')
    const match = content.match(/geminiApiKey\s*=\s*['"]([^'"]+)['"]/);
    
    if (!match || !match[1]) {
      throw new Error('API key bulunamadı. analysis_secrets.dart dosyasını kontrol edin.');
    }
    
    const apiKey = match[1].trim();
    
    if (!apiKey || apiKey.length < 10) {
      throw new Error('Geçersiz API key formatı.');
    }
    
    return apiKey;
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new Error(`Dosya bulunamadı: ${SECRETS_FILE}`);
    }
    throw error;
  }
}

function setFirebaseConfig(key, value) {
  try {
    console.log(`Firebase Functions config'e set ediliyor: ${CONFIG_KEY}...`);
    
    // Firebase CLI komutu
    const command = `firebase functions:config:set ${CONFIG_KEY}="${value}"`;
    execSync(command, { stdio: 'inherit' });
    
    console.log('✅ Başarılı! Firebase Functions config güncellendi.');
    console.log('⚠️  Değişikliklerin etkili olması için functions\'ları yeniden deploy etmelisiniz:');
    console.log('   firebase deploy --only functions');
  } catch (error) {
    console.error('❌ Hata:', error.message);
    process.exit(1);
  }
}

// Ana işlem
try {
  console.log('🔍 analysis_secrets.dart dosyasından API key okunuyor...');
  const apiKey = extractApiKey();
  
  console.log(`✅ API key bulundu: ${apiKey.substring(0, 10)}...`);
  
  setFirebaseConfig(CONFIG_KEY, apiKey);
} catch (error) {
  console.error('❌ Hata:', error.message);
  process.exit(1);
}

