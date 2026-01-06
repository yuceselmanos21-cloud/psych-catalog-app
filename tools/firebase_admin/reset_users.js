// tools/firebase_admin/reset_users.js
const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

function requireServiceAccount() {
  const p = process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? process.env.GOOGLE_APPLICATION_CREDENTIALS
    : path.join(__dirname, "serviceAccountKey.json");

  if (!fs.existsSync(p)) {
    console.error("Service account JSON bulunamadı:", p);
    console.error(
      "Çözüm: serviceAccountKey.json dosyasını bu klasöre koy veya GOOGLE_APPLICATION_CREDENTIALS env ayarla."
    );
    process.exit(1);
  }
  return require(p);
}

admin.initializeApp({
  credential: admin.credential.cert(requireServiceAccount()),
});

const db = admin.firestore();

async function deleteAllAuthUsers() {
  console.log("Auth kullanıcıları siliniyor...");
  let pageToken = undefined;
  let total = 0;

  while (true) {
    const res = await admin.auth().listUsers(1000, pageToken);
    if (!res.users.length) break;

    const uids = res.users.map((u) => u.uid);
    // deleteUsers max 1000
    const delRes = await admin.auth().deleteUsers(uids);
    total += uids.length;

    console.log(
      `Silindi: ${uids.length} (başarılı=${uids.length - delRes.failureCount}, hata=${delRes.failureCount})`
    );

    pageToken = res.pageToken;
    if (!pageToken) break;
  }

  console.log("Auth toplam silinen:", total);
}

async function deleteCollectionDocs(collectionName) {
  console.log(`Firestore '${collectionName}' koleksiyonu siliniyor...`);

  const snap = await db.collection(collectionName).get();
  if (snap.empty) {
    console.log(`'${collectionName}' boş.`);
    return;
  }

  // BulkWriter büyük silmeler için daha güvenli
  const bulkWriter = db.bulkWriter();
  let count = 0;

  snap.docs.forEach((d) => {
    bulkWriter.delete(d.ref);
    count++;
  });

  await bulkWriter.close();
  console.log(`'${collectionName}' silinen doc:`, count);
}

async function main() {
  const args = new Set(process.argv.slice(2));

  // Kullanım:
  // node reset_users.js --auth --firestore
  // node reset_users.js --auth
  // node reset_users.js --firestore
  const doAuth = args.has("--auth");
  const doFirestore = args.has("--firestore");

  if (!doAuth && !doFirestore) {
    console.log("Kullanım:");
    console.log("  node reset_users.js --auth --firestore");
    console.log("  node reset_users.js --auth");
    console.log("  node reset_users.js --firestore");
    process.exit(0);
  }

  if (doFirestore) {
    // İstersen posts/replies da ekleyebilirsin:
    await deleteCollectionDocs("users");
    // await deleteCollectionDocs("posts");
    // await deleteCollectionDocs("replies");
  }

  if (doAuth) {
    await deleteAllAuthUsers();
  }

  console.log("Bitti.");
  process.exit(0);
}

main().catch((e) => {
  console.error("Hata:", e);
  process.exit(1);
});

