# Catatan setup GOWA di Dokploy (template)

## Yang di-deploy
- Aplikasi GOWA (go-whatsapp-web-multidevice): WhatsApp gateway via protokol
  WhatsApp Web. Satu device = satu nomor WhatsApp.
- n8n: mesin workflow (WF1 antrean + WF2 bridge). Bisa di server yang sama.

## Pelajaran Dokploy yang penting
- Variabel di tab Environment aplikasi HANYA dipakai untuk interpolasi compose file.
  Kalau compose file tidak meneruskan variabel ke container (tidak ada blok
  `environment:`), variabel itu TIDAK masuk ke proses container.
- Jadi: pastikan blok `environment:` ada di compose file untuk setiap variabel
  yang harus dibaca aplikasi.

## Konfigurasi device GOWA
- Buat device baru, ID device bersifat case-sensitive (contoh: `MyBrand`).
  Header `X-Device-Id` di semua panggilan API harus sama persis dengan ID ini.
- Pairing perangkat = LANGKAH MANUAL: scan QR dari HP owner. Tidak bisa
  diotomatisasi oleh prompt setup manapun.

## Webhook GOWA -> n8n (WF1)
- URL: `https://<YOUR_N8N_DOMAIN>/webhook/gowa-standby-in`
- Events: `message,call.offer` (call.offer = deteksi panggilan masuk).
- Secret webhook: isi `<YOUR_GOWA_WEBHOOK_SECRET>` yang sama dengan nilai
  `staticData.webhookSecret` di node "Verify + filter + queue" WF1.
- Basic Auth untuk API GOWA (`/send/message`, `/send/image`, `/send/file`,
  `/message/{id}/download`): buat credential "GoWA Basic Auth" di n8n.

## Endpoint API GOWA yang dipakai WF2
- `POST /send/message` (teks, JSON: phone, message)
- `POST /send/image` (form-data: phone, caption, image_url)
- `POST /send/file` (form-data: phone, caption, file_url)
- `GET /message/{message_id}/download?phone={chat_jid}` (unduh media masuk)
- Semua memakai header `X-Device-Id: <YOUR_DEVICE_ID>` + Basic Auth.

## Catatan keamanan
- Verifikasi signature webhook di WF1 secara default NONAKTIF pada kode template
  ini (baris `if (false && !safeEqual(...))`), sama seperti sistem asal saat
  diexport. Untuk produksi, AKTIFKAN dengan menghapus `false &&` dan pastikan
  secret-nya sama di sisi GOWA dan WF1.
- Jangan pernah commit secret, token webhook, API key, atau nomor HP asli ke repo.
