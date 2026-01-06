/**
 * Migration: Eski yorumlara deleted: false field'ı ekle
 * 
 * Bu script tüm post'lara (yorumlar dahil) deleted field'ı ekler.
 * Eğer deleted field'ı yoksa, deleted: false ekler.
 * 
 * Kullanım:
 * node tools/migration_add_deleted_field.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Firebase Admin SDK'yı başlat
const serviceAccount = require(path.join(__dirname, '../serviceAccountKey.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migratePosts() {
  console.log('🔄 Migration başlatılıyor...');
  
  let processed = 0;
  let updated = 0;
  let batch = db.batch();
  let batchCount = 0;
  const BATCH_SIZE = 500; // Firestore batch limit
  
  try {
    // Tüm post'ları al (yorumlar dahil)
    const postsSnapshot = await db.collection('posts').get();
    
    console.log(`📊 Toplam ${postsSnapshot.size} post bulundu`);
    
    for (const doc of postsSnapshot.docs) {
      const data = doc.data();
      
      // Eğer deleted field'ı yoksa, ekle
      if (data.deleted === undefined) {
        batch.update(doc.ref, { deleted: false });
        updated++;
        batchCount++;
        
        // Batch limit'e ulaştıysa, commit et
        if (batchCount >= BATCH_SIZE) {
          await batch.commit();
          console.log(`✅ ${updated} post güncellendi (batch commit)`);
          batch = db.batch();
          batchCount = 0;
        }
      }
      
      processed++;
      
      // Her 1000 post'ta bir progress göster
      if (processed % 1000 === 0) {
        console.log(`⏳ İşleniyor: ${processed}/${postsSnapshot.size} (${updated} güncellendi)`);
      }
    }
    
    // Kalan batch'i commit et
    if (batchCount > 0) {
      await batch.commit();
      console.log(`✅ Son batch commit edildi (${batchCount} post)`);
    }
    
    console.log(`\n✅ Migration tamamlandı!`);
    console.log(`📊 İstatistikler:`);
    console.log(`   - Toplam işlenen: ${processed}`);
    console.log(`   - Güncellenen: ${updated}`);
    console.log(`   - Zaten deleted field'ı olan: ${processed - updated}`);
    
  } catch (error) {
    console.error('❌ Migration hatası:', error);
    throw error;
  }
}

// Migration'ı çalıştır
migratePosts()
  .then(() => {
    console.log('✅ Migration başarıyla tamamlandı');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Migration başarısız:', error);
    process.exit(1);
  });

