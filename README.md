# wamuse — WhatsApp standby bot (GOWA + n8n + AI agent)

Bot standby WhatsApp yang menjawab sebagai owner: teks, gambar, voice note,
video, dan follow-up panggilan masuk. Hemat token: agen LLM hanya bangun saat
ada pesan pending di antrean.

## Arsitektur

```
WhatsApp ──> GOWA (gateway) ──webhook──> n8n WF1 "GOWA Standby"
                                            (verifikasi, dedup, filter grup,
                                             deteksi media, antrean)
                                                    │
                              poller tiap 60 detik  │
                              (tanpa token)         ▼
                              n8n WF2 "Muse Bridge" ──> inbox GET
                                            │  (agen bangun hanya bila pending > 0)
                                            ▼
                              agen AI (prompt: agent/standby-prompt.md)
                              baca media, transkrip suara (Groq Whisper),
                              analisa frame video (ffmpeg), balas
                                            │
                                            ▼
                              n8n WF2 outbox POST ──> GOWA /send/*
                              + ack antrean via Queue Ops (WF1)
```

## Isi repo

- `n8n/wf1-gowa-standby.json` — workflow antrean (4 node)
- `n8n/wf2-muse-bridge.json` — workflow bridge inbox/outbox/media/transkrip (19 node)
- `agent/standby-prompt.md` — prompt pekerja standby (aturan balas, sandbox
  per-chat, anti-loop, discovery, pengingat prospek, eskalasi)
- `agent/poller.sh` — poller hemat tiap 60 detik (baca antrean, bangunkan agen
  hanya bila ada pesan baru)
- `config/n8n-bridge.conf.example` — template URL inbox/outbox
- `config/tarif.example.txt` — template daftar tarif (ganti dengan tarifmu)
- `config/gowa-dokploy-notes.md` — catatan setup GOWA di Dokploy
- `SETUP_PROMPT.md` — **prompt sekali tempel** untuk Muse/agent AI lain agar
  menginstal dan mengkonfigurasi semuanya sampai jalan

## Mulai cepat

1. Baca `SETUP_PROMPT.md`, salin seluruh isinya, tempel ke Muse (atau AI
   agent lain) sebagai satu prompt.
2. Siapkan yang hanya bisa dilakukan manusia (lihat bawah).
3. Jangan umumkan "selesai" sebelum tes end-to-end dari HP owner lulus:
   kirim pesan teks, gambar, voice note, dan video ke nomor standby, lalu
   pastikan semua dibalas dengan benar.

## Langkah yang HARUS dilakukan manusia (tidak bisa otomatis)

- Membuat akun: GitHub (opsional), Dokploy/VPS, n8n, Groq (API key gratis).
- DNS/domain untuk GOWA dan n8n (HTTPS wajib untuk webhook WhatsApp).
- Pairing perangkat WhatsApp: scan QR GOWA dari HP owner.
- Mengisi semua placeholder `<...>` dengan nilai sendiri (lihat tabel di
  `SETUP_PROMPT.md`).
- Membuat credential di n8n: "GoWA Basic Auth" dan Header Auth Groq.

## Placeholder

| Placeholder | Artinya |
|---|---|
| `<YOUR_N8N_DOMAIN>` | Domain n8n, mis. `n8n.domain-kamu.com` |
| `<YOUR_GOWA_DOMAIN>` | Domain panel GOWA |
| `<YOUR_DEVICE_ID>` | ID device GOWA (case-sensitive) |
| `<YOUR_DEVICE_KEYWORD>` | Kata kunci mention grup (nama device, huruf kecil) |
| `<YOUR_OWNER_NUMBER>` | Nomor HP owner (format `62...`, tanpa `+`) |
| `<YOUR_NAME>` | Nama owner untuk tanda tangan balasan |
| `<YOUR_GOWA_WEBHOOK_SECRET>` | Secret webhook GOWA (sama di GOWA dan WF1) |
| `<TOKEN_A>`, `<TOKEN_B>`, `<TOKEN_C>` | Sufiks acak path webhook (buat baru, jangan pakai contoh) |

Catatan: `<TOKEN_A>` dipakai bersama oleh inbox, outbox, dan queue-ops —
ketiganya harus memakai nilai yang sama.

## Pitfall yang sudah terbukti (jangan diulang)

- **Jangan cari workflow by nama** — bisa ada duplikat nonaktif bernama sama.
  Selalu target by ID.
- **Silent-ack HANYA lewat Queue Ops** (`POST .../webhook/gowa-queue-ops-<TOKEN_A>`
  body `{"mode":"ack","wids":[...]}`). Jangan pernah pakai outbox action `ack`
  — outbox selalu mengirim teks ke klien.
- **Deadlock self-call**: poll yang menunggu webhook-nya sendiri bisa saling
  mengunci slot worker n8n bila banyak eksekusi menggantung. Bila standby diam
  padahal n8n hidup, cek dan hentikan eksekusi yang menggantung dulu sebelum
  mengubah konfigurasi.
- **Verifikasi signature WF1 nonaktif secara default** pada kode template
  (baris `if (false && ...)`). Aktifkan untuk produksi (lihat
  `config/gowa-dokploy-notes.md`).
- **Backup dulu sebelum mengubah konfigurasi/infrastruktur apapun.**

## Keamanan

Repo ini TIDAK berisi secret, token, API key, nomor HP, nama klien, isi chat,
atau harga asli. Semua nilai sensitif sudah diganti placeholder dan diverifikasi
nol residu sebelum publish. Jangan pernah commit file `n8n-bridge.conf` yang
sudah terisi, credential n8n, atau file state per-chat.
