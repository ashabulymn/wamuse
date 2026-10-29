# SETUP PROMPT — tempel seluruh isi file ini ke Muse (atau AI agent lain) sebagai satu prompt

> Kamu adalah agen setup. Tugasmu: menginstal dan mengkonfigurasi bot standby
> WhatsApp "wamuse" sampai BENAR-BENAR JALAN untuk satu nomor WhatsApp baru,
> memakai file-file di repo ini. Jangan berhenti sebelum tes end-to-end dari HP
> owner lulus. Jangan umumkan "selesai" sebelum tes itu lulus.

## 0. Prasyarat — tanyakan ke manusia bila belum ada, jangan mengarang

Sebelum mulai, pastikan manusia sudah menyediakan (bila belum, minta dia
menyediakannya dulu, lalu lanjut):

1. Server dengan Docker (disarankan Dokploy) + domain yang sudah mengarah ke
   server itu, dengan HTTPS aktif. Dibutuhkan dua subdomain:
   `<YOUR_N8N_DOMAIN>` (untuk n8n) dan `<YOUR_GOWA_DOMAIN>` (untuk panel GOWA).
2. Satu nomor WhatsApp khusus standby (BUKAN nomor pribadi owner).
3. Groq API key gratis (buat di console.groq.com) untuk transkripsi suara.
   Free tier Groq bersifat permanen (bukan trial berbatas waktu), hanya
   dibatasi rate limit — cukup untuk voice note.
4. `ffmpeg` terinstal di mesin agen (untuk ekstrak frame video).
5. Nilai-nilai placeholder di bawah (minta manusia mengisinya, satu per satu):

| Placeholder | Diisi dengan |
|---|---|
| `<YOUR_N8N_DOMAIN>` | Domain n8n |
| `<YOUR_GOWA_DOMAIN>` | Domain panel GOWA |
| `<YOUR_DEVICE_ID>` | ID device GOWA yang akan dibuat (case-sensitive, satu kata, mis. nama brand) |
| `<YOUR_DEVICE_KEYWORD>` | Versi huruf kecil dari device ID, dipakai sebagai kata kunci mention grup |
| `<YOUR_OWNER_NUMBER>` | Nomor HP owner format `62...` (tanpa `+`), untuk eskalasi |
| `<YOUR_NAME>` | Nama owner untuk tanda tangan balasan (mis. nama depan) |
| `<YOUR_GOWA_WEBHOOK_SECRET>` | String acak panjang untuk secret webhook (buat baru) |
| `<TOKEN_A>` | Sufiks acak path webhook (buat baru; dipakai bersama inbox, outbox, queue-ops) |
| `<TOKEN_B>` | Sufiks acak path webhook download media (buat baru) |
| `<TOKEN_C>` | Sufiks acak path webhook transkripsi audio (buat baru) |

## 1. Deploy GOWA + n8n

1. Deploy GOWA (go-whatsapp-web-multidevice) dan n8n di Dokploy/Docker.
2. Perhatian Dokploy: variabel di tab Environment HANYA untuk interpolasi
   compose file. Pastikan blok `environment:` ada di compose file untuk setiap
   variabel yang harus dibaca container (lihat `config/gowa-dokploy-notes.md`).

## 2. Import workflow n8n

1. Import `n8n/wf1-gowa-standby.json` sebagai workflow "GOWA Standby" dan
   `n8n/wf2-muse-bridge.json` sebagai workflow "Muse Bridge". Aktifkan
   keduanya (Published/Active).
2. PERINGATAN: jangan pernah mencari workflow by nama — bisa ada duplikat
   nonaktif bernama sama. Selalu bekerja by ID workflow.
3. Buat credential n8n:
   - "GoWA Basic Auth" (Basic Auth untuk API GOWA).
   - Header Auth untuk Groq (key dari langkah 0).
   - Pasang credential tersebut ke node-node yang merujuk namanya di WF2.
4. Ganti semua placeholder di kedua workflow dengan nilai langkah 0.
   Perhatian konsistensi: `<TOKEN_A>` harus SAMA di path queue-ops (WF1),
   inbox, outbox (WF2), dan URL HTTP Request ke queue-ops.

## 3. Konfigurasi device + webhook GOWA (satu langkah MANUAL)

1. Di panel GOWA, buat device dengan ID = `<YOUR_DEVICE_ID>`.
2. **MANUAL — manusia harus melakukannya sendiri:** scan QR pairing dari HP
   owner sampai device berstatus `logged_in`. Langkah ini tidak bisa
   diotomatisasi.
3. Set webhook GOWA ke `https://<YOUR_N8N_DOMAIN>/webhook/gowa-standby-in`
   (path ini dari WF1, tanpa token), events `message,call.offer`, dan secret
   = `<YOUR_GOWA_WEBHOOK_SECRET>`.
4. Verifikasi dari panel/API: device `logged_in`, webhook terpasang.

## 4. Instal prompt + poller agen

1. Salin `agent/standby-prompt.md` menjadi prompt pekerja standby. Ganti semua
   placeholder dengan nilai langkah 0.
2. Instal `agent/poller.sh` sebagai poller: jalankan tiap 60 detik, baca
   `config/n8n-bridge.conf` (salin dari `.example`, isi URL inbox/outbox),
   dan bangunkan agen HANYA bila jumlah pending berubah dan > 0 (hemat token).
   - Bila agenmu adalah Muse: pasang sebagai hook dengan perilaku yang sama.
   - Bila agenmu lain: padankan dengan cron/systemd + skrip pemicu yang sama.
3. Siapkan file state per-chat (satu file JSON per `chat_jid`, mode 600):
   ringkasan, flow stage, 20 riwayat terakhir. Pekerja WAJIB hanya membaca file
   chat yang sedang dibalas dan memperbaruinya setelah outbox terkonfirmasi.
4. Isi `config/tarif.example.txt` menjadi daftar tarif ASLI owner (format sama),
   simpan di luar repo publik (file ini berisi harga bisnis, jangan di-commit).

## 5. Aturan operasi yang wajib dipertahankan

- Semua chat pribadi dibalas; grup hanya bila ada mention ke device.
- Gaya balasan: natural seperti manusia, singkat, santai tapi sopan dan ramah,
  emoticon 1–2 per pesan bila natural, tanda tangan dengan `<YOUR_NAME>`.
  Ikuti gaya bahasa lawan bicara, kecuali lawan bicara marah/menggunakan
  kapital — tetap profesional. Pesan berbahasa daerah dibalas dengan Bahasa
  Indonesia.
- Gali kebutuhan dulu sebelum bicara harga (satu pertanyaan per balasan,
  dipasangkan saran/opsi konkret, jangan interogasi). Sebelum mengutip tarif,
  konfirmasi dulu ke owner (eskalasi). Item bertanda (usulan) tidak boleh
  dikutip — eskalasikan.
- Hal privasi/sensitif, uang, password, hukum, kesehatan, atau fakta valid
  yang tidak diketahui: JANGAN dijawab sebagai owner — jawab profesional
  dulu ("sebentar, saya cek dulu"), lalu eskalasikan detailnya ke owner.
- Anti-loop + circuit breaker: bingung 1x → eskalasi ke owner, jangan mengulang
  pertanyaan yang sudah dijawab.
- Pengingat prospek: hanya bila kita yang terakhir bicara + chat menunggu
  keputusan klien; jeda >= 6 jam, hanya 08:00–21:00 WIB, maks 1x per 48 jam
  per prospek.
- **Silent-ack HANYA lewat Queue Ops**: `POST https://<YOUR_N8N_DOMAIN>/webhook/gowa-queue-ops-<TOKEN_A>`
  body `{"mode":"ack","wids":[...]}`. JANGAN PERNAH pakai outbox action `ack`
  — outbox selalu mengirim teks ke klien (terbukti menyebabkan spam "ack").
- **Deadlock self-call**: bila standby diam padahal n8n hidup, JANGAN langsung
  mengubah konfigurasi. Cek eksekusi n8n yang menggantung (terutama poll yang
  menunggu webhook-nya sendiri) dan hentikan dulu — itu penyebab paling umum.
- **Backup dulu sebelum mengubah konfigurasi/infrastruktur apapun.**
- Catatan keamanan WF1: verifikasi signature webhook nonaktif secara default
  pada kode template (baris `if (false && !safeEqual(...))`). Untuk produksi,
  aktifkan dengan menghapus `false &&` dan pastikan secret sama di GOWA dan WF1.

## 6. Tes end-to-end (WAJIB lulus semua sebelum "selesai")

Dari HP owner, kirim ke nomor standby, satu per satu, dan verifikasi balasannya:

1. Pesan teks biasa → dibalas natural sebagai `<YOUR_NAME>`.
2. Gambar + caption pertanyaan → gambar dibaca dan dijawab sesuai isinya.
3. Voice note → ditranskrip (Groq) dan dijawab sesuai isinya.
4. Video + caption → audio ditranskrip + frame dibaca (ffmpeg, 1 frame/2 detik,
   maks 30 frame) dan dijawab gabungan keduanya; frame dihapus setelah analisa,
   video dihapus otomatis setelah 2 hari.
5. Panggilan masuk (call.offer) → follow-up hangat terkirim (standby tidak
   mengangkat panggilan — keterbatasan protokol WhatsApp Web).
6. Pesan grup tanpa mention → TIDAK dibalas. Pesan grup dengan mention →
   dibalas.
7. Setelah semua balasan terkirim, antrean harus kosong (inbox GET
   mengembalikan `pending: []`).

Bila ada satu tes gagal: diagnosis dari riwayat eksekusi n8n dan log poller,
perbaiki, ulangi tes itu. Jangan mengumumkan selesai sebelum SEMUA tes lulus.

## 7. Penyerahan

Bila semua tes lulus, laporkan ke manusia: URL panel GOWA, URL n8n, ID device,
ringkasan tes yang lulus, dan daftar placeholder yang dipakai (tanpa nilai
secret). Simpan backup konfigurasi final (workflow JSON + prompt + conf
template) di repo atau arsip owner.
