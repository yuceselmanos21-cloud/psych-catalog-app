/**
 * wipe_all.js
 * - Varsayılan: Firestore + Auth siler
 * - Storage: kapalı (isteğe bağlı açılır)
 *
 * Kullanım:
 *   node wipe_all.js --key ./serviceAccount.json --all
 *
 * Opsiyonel:
 *   node wipe_all.js --key ./serviceAccount.json --all --withStorage --bucket your-bucket-name
 */

const path = require("path");
const fs = require("fs");
const yargs = require("yargs/yargs");
const { hideBin } = require("yargs/helpers");

const admin = require("firebase-admin");

const argv = yargs(hideBin(process.argv))
  .option("key", { type: "string", demandOption: true, describe: "Service account json path" })
  .option("all", { type: "boolean", default: false, describe: "Delete Firestore + Auth" })
  .option("firestore", { type: "boolean", default: false, describe: "Delete Firestore only" })
  .option("auth", { type: "boolean", default: false, describe: "Delete Auth users only" })
  .option("withStorage", { type: "boolean", default: false, describe: "Also wipe Storage bucket" })
  .option("bucket", { type: "string", default: "", describe: "Bucket name (if withStorage=true)" })
  .help()
  .argv;

function assertKeyFile(p) {
  const full = path.resolve(p);
  if (!fs.existsSync(full)) {
    throw new Error(`Key file not found: ${full}`);
  }
  return full;
}

function initAdmin(keyPath) {
  const full = assertKeyFile(keyPath);
  const sa = require(full);

  admin.initializeApp({
    credential: admin.credential.cert(sa),
    // storageBucket: argv.bucket || undefined, // sadece storage wipe yapacaksan aç
  });
}

async function deleteAllAuthUsers() {
  const auth = admin.auth();
  let nextPageToken = undefined;
  let total = 0;

  console.log("Auth: kullanıcılar listeleniyor...");

  do {
    const res = await auth.listUsers(1000, nextPageToken);
    const uids = res.users.map(u => u.uid);

    if (uids.length > 0) {
      await auth.deleteUsers(uids);
      total += uids.length;
      console.log(`Auth: silindi -> ${uids.length} (toplam: ${total})`);
    }

    nextPageToken = res.pageToken;
  } while (nextPageToken);

  console.log(`Auth: bitti. Toplam silinen kullanıcı: ${total}`);
}

async function deleteDocumentRecursively(docRef) {
  const subCols = await docRef.listCollections();
  for (const col of subCols) {
    await deleteCollectionRecursively(col);
  }
  await docRef.delete();
}

async function deleteCollectionRecursively(colRef) {
  const db = admin.firestore();
  const batchSize = 200;

  while (true) {
    const snap = await colRef
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(batchSize)
      .get();

    if (snap.empty) break;

    // tek tek recursive sil (küçük projelerde güvenli, basit)
    for (const doc of snap.docs) {
      await deleteDocumentRecursively(doc.ref);
    }
  }
}

async function deleteAllFirestore() {
  const db = admin.firestore();

  console.log("Firestore: root koleksiyonlar listeleniyor...");
  const cols = await db.listCollections();

  if (!cols.length) {
    console.log("Firestore: root koleksiyon yok.");
    return;
  }

  console.log(`Firestore: ${cols.length} koleksiyon bulundu.`);
  for (const col of cols) {
    console.log(`Firestore: siliniyor -> ${col.id}`);
    await deleteCollectionRecursively(col);
  }

  console.log("Firestore: bitti.");
}

async function wipeStorageIfRequested() {
  if (!argv.withStorage) return;

  const bucketName = (argv.bucket || "").trim();
  if (!bucketName) {
    console.log("Storage: bucket adı verilmedi. --bucket ile ver veya --withStorage kullanma.");
    return;
  }

  console.log(`Storage: temizleniyor -> ${bucketName}`);

  try {
    const bucket = admin.storage().bucket(bucketName);

    // bucket var mı kontrol et
    const [exists] = await bucket.exists();
    if (!exists) {
      console.log("Storage: bucket yok. Bu projede Storage etkin değilse normal. Atlandı.");
      return;
    }

    await bucket.deleteFiles({ force: true });
    console.log("Storage: bitti.");
  } catch (e) {
    console.log("Storage: hata aldı ama devam edildi (kullanmadığın için sorun değil).");
    console.log(String(e));
  }
}

async function main() {
  initAdmin(argv.key);

  const doFirestore = argv.all || argv.firestore;
  const doAuth = argv.all || argv.auth;

  if (!doFirestore && !doAuth && !argv.withStorage) {
    console.log("Hiçbir işlem seçilmedi. Örn: --all");
    return;
  }

  if (doFirestore) await deleteAllFirestore();
  if (doAuth) await deleteAllAuthUsers();

  await wipeStorageIfRequested();

  console.log("Tamamlandı.");
}

main().catch((e) => {
  console.error("Hata:", e);
  process.exit(1);
});
