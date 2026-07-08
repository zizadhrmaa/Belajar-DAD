-- ============================================================
-- SKEMA 6: SISTEM PERBANKAN DIGITAL MULTI-CABANG
-- PostgreSQL
--
-- Tujuan data:
-- 1. Mendukung seluruh 7 soal OLAP pada Skema 6.
-- 2. Menyediakan data nasabah, rekening, transaksi, transfer,
--    kartu, merchant, pinjaman, angsuran, perangkat, login,
--    fraud alert, cabang, pegawai, dan wilayah.
-- 3. Menyediakan pola analitik untuk ranking, NOT EXISTS,
--    pertumbuhan bulanan, moving average, persentil merchant,
--    deteksi anomali, pergantian perangkat, dan risiko fraud.
--
-- Jalankan seluruh file ini pada database PostgreSQL.
-- ============================================================

DROP SCHEMA IF EXISTS perbankan_digital_multicabang CASCADE;
CREATE SCHEMA perbankan_digital_multicabang;
SET search_path TO perbankan_digital_multicabang, public;

-- ============================================================
-- 1. TABEL WILAYAH
-- ============================================================

CREATE TABLE negara (
    negara_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_negara        varchar(100) NOT NULL UNIQUE,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE provinsi (
    provinsi_id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_provinsi      varchar(100) NOT NULL,
    negara_id          integer NOT NULL REFERENCES negara(negara_id),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (nama_provinsi, negara_id)
);

CREATE TABLE kota (
    kota_id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_kota          varchar(100) NOT NULL,
    provinsi_id        integer NOT NULL REFERENCES provinsi(provinsi_id),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (nama_kota, provinsi_id)
);

CREATE TABLE alamat (
    alamat_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alamat             varchar(200) NOT NULL,
    kecamatan          varchar(100) NOT NULL,
    kota_id            integer NOT NULL REFERENCES kota(kota_id),
    kode_pos           varchar(10) NOT NULL,
    telepon            varchar(30),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 2. CABANG, JABATAN, DAN PEGAWAI
-- ============================================================

CREATE TABLE jabatan (
    jabatan_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_jabatan       varchar(100) NOT NULL UNIQUE,
    level_otorisasi    integer NOT NULL CHECK (level_otorisasi > 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cabang (
    cabang_id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kode_cabang            varchar(20) NOT NULL UNIQUE,
    nama_cabang            varchar(120) NOT NULL UNIQUE,
    manager_pegawai_id     integer,
    alamat_id              bigint NOT NULL REFERENCES alamat(alamat_id),
    status                 varchar(20) NOT NULL
                           CHECK (status IN ('AKTIF','NONAKTIF')),
    last_update            timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pegawai (
    pegawai_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cabang_id          integer NOT NULL REFERENCES cabang(cabang_id),
    atasan_id          integer REFERENCES pegawai(pegawai_id),
    jabatan_id         integer NOT NULL REFERENCES jabatan(jabatan_id),
    nama_depan         varchar(80) NOT NULL,
    nama_belakang      varchar(80) NOT NULL,
    email              varchar(150) NOT NULL UNIQUE,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('AKTIF','CUTI','NONAKTIF')),
    tanggal_masuk      date NOT NULL,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE cabang
    ADD CONSTRAINT fk_cabang_manager
    FOREIGN KEY (manager_pegawai_id)
    REFERENCES pegawai(pegawai_id);

-- ============================================================
-- 3. NASABAH DAN REKENING
-- ============================================================

CREATE TABLE nasabah (
    nasabah_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nomor_identitas    varchar(40) NOT NULL UNIQUE,
    nama_depan         varchar(80) NOT NULL,
    nama_belakang      varchar(80) NOT NULL,
    tanggal_lahir      date NOT NULL,
    email              varchar(150) NOT NULL UNIQUE,
    telepon            varchar(30) NOT NULL,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    tanggal_daftar     date NOT NULL,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('AKTIF','DIBLOKIR','NONAKTIF')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE jenis_rekening (
    jenis_rekening_id  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_jenis         varchar(100) NOT NULL UNIQUE,
    saldo_minimum      numeric(18,2) NOT NULL CHECK (saldo_minimum >= 0),
    suku_bunga         numeric(8,4) NOT NULL CHECK (suku_bunga >= 0),
    biaya_admin        numeric(14,2) NOT NULL CHECK (biaya_admin >= 0),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE rekening (
    rekening_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nomor_rekening     varchar(30) NOT NULL UNIQUE,
    nasabah_id         integer NOT NULL REFERENCES nasabah(nasabah_id),
    jenis_rekening_id  integer NOT NULL REFERENCES jenis_rekening(jenis_rekening_id),
    cabang_id          integer NOT NULL REFERENCES cabang(cabang_id),
    tanggal_buka       date NOT NULL,
    saldo              numeric(20,2) NOT NULL CHECK (saldo >= 0),
    status             varchar(20) NOT NULL
                       CHECK (status IN ('AKTIF','DIBEKUKAN','DITUTUP')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE rekening_bersama (
    rekening_id        bigint NOT NULL REFERENCES rekening(rekening_id),
    nasabah_id         integer NOT NULL REFERENCES nasabah(nasabah_id),
    peran               varchar(30) NOT NULL
                        CHECK (peran IN ('PEMILIK_UTAMA','PEMILIK_BERSAMA','KUASA')),
    tanggal_mulai       date NOT NULL,
    tanggal_selesai    date,
    PRIMARY KEY (rekening_id, nasabah_id),
    CHECK (tanggal_selesai IS NULL OR tanggal_selesai >= tanggal_mulai)
);

-- ============================================================
-- 4. TRANSAKSI DAN TRANSFER
-- ============================================================

CREATE TABLE jenis_transaksi (
    jenis_transaksi_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_jenis         varchar(100) NOT NULL UNIQUE,
    kategori           varchar(40) NOT NULL,
    arah_saldo         varchar(10) NOT NULL
                       CHECK (arah_saldo IN ('DEBIT','KREDIT','NETRAL')),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE channel_transaksi (
    channel_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_channel       varchar(100) NOT NULL UNIQUE,
    jenis_channel      varchar(40) NOT NULL,
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transaksi (
    transaksi_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rekening_id        bigint NOT NULL REFERENCES rekening(rekening_id),
    jenis_transaksi_id integer NOT NULL REFERENCES jenis_transaksi(jenis_transaksi_id),
    tanggal_transaksi  timestamp NOT NULL,
    jumlah             numeric(20,2) NOT NULL CHECK (jumlah > 0),
    saldo_setelah      numeric(20,2) NOT NULL CHECK (saldo_setelah >= 0),
    channel_id         integer NOT NULL REFERENCES channel_transaksi(channel_id),
    status             varchar(20) NOT NULL
                       CHECK (status IN ('MENUNGGU','BERHASIL','GAGAL','DIBATALKAN')),
    keterangan         varchar(250),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transfer (
    transfer_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaksi_debit_id     bigint NOT NULL UNIQUE REFERENCES transaksi(transaksi_id),
    transaksi_kredit_id    bigint NOT NULL UNIQUE REFERENCES transaksi(transaksi_id),
    rekening_pengirim_id   bigint NOT NULL REFERENCES rekening(rekening_id),
    rekening_penerima_id   bigint NOT NULL REFERENCES rekening(rekening_id),
    jumlah                 numeric(20,2) NOT NULL CHECK (jumlah > 0),
    berita                 varchar(250),
    CHECK (rekening_pengirim_id <> rekening_penerima_id)
);

-- ============================================================
-- 5. KARTU DAN MERCHANT
-- ============================================================

CREATE TABLE jenis_kartu (
    jenis_kartu_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_jenis         varchar(80) NOT NULL UNIQUE,
    limit_harian       numeric(18,2) NOT NULL CHECK (limit_harian > 0),
    biaya_tahunan      numeric(14,2) NOT NULL CHECK (biaya_tahunan >= 0),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kartu (
    kartu_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rekening_id        bigint NOT NULL REFERENCES rekening(rekening_id),
    nomor_kartu        varchar(30) NOT NULL UNIQUE,
    jenis_kartu_id     integer NOT NULL REFERENCES jenis_kartu(jenis_kartu_id),
    tanggal_terbit     date NOT NULL,
    tanggal_kedaluwarsa date NOT NULL,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('AKTIF','DIBLOKIR','KEDALUWARSA','DITUTUP')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (tanggal_kedaluwarsa > tanggal_terbit)
);

CREATE TABLE kategori_merchant (
    kategori_merchant_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_kategori        varchar(100) NOT NULL UNIQUE,
    kode_mcc             varchar(10) NOT NULL UNIQUE,
    last_update          timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE merchant (
    merchant_id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_merchant          varchar(150) NOT NULL UNIQUE,
    kategori_merchant_id   integer NOT NULL REFERENCES kategori_merchant(kategori_merchant_id),
    alamat_id              bigint NOT NULL REFERENCES alamat(alamat_id),
    status                 varchar(20) NOT NULL
                           CHECK (status IN ('AKTIF','DIBEKUKAN','NONAKTIF')),
    last_update            timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transaksi_kartu (
    transaksi_kartu_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kartu_id           bigint NOT NULL REFERENCES kartu(kartu_id),
    merchant_id        integer NOT NULL REFERENCES merchant(merchant_id),
    transaksi_id       bigint NOT NULL UNIQUE REFERENCES transaksi(transaksi_id),
    tanggal_transaksi  timestamp NOT NULL,
    jumlah             numeric(20,2) NOT NULL CHECK (jumlah > 0),
    status             varchar(20) NOT NULL
                       CHECK (status IN ('MENUNGGU','BERHASIL','GAGAL','DIBATALKAN'))
);

-- ============================================================
-- 6. PINJAMAN
-- ============================================================

CREATE TABLE produk_pinjaman (
    produk_pinjaman_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_produk        varchar(120) NOT NULL UNIQUE,
    suku_bunga         numeric(8,4) NOT NULL CHECK (suku_bunga >= 0),
    jumlah_minimum     numeric(20,2) NOT NULL CHECK (jumlah_minimum > 0),
    jumlah_maksimum    numeric(20,2) NOT NULL CHECK (jumlah_maksimum >= jumlah_minimum),
    tenor_maksimum     integer NOT NULL CHECK (tenor_maksimum > 0),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pengajuan_pinjaman (
    pengajuan_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nasabah_id         integer NOT NULL REFERENCES nasabah(nasabah_id),
    produk_pinjaman_id integer NOT NULL REFERENCES produk_pinjaman(produk_pinjaman_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    tanggal_pengajuan  timestamp NOT NULL,
    jumlah_pengajuan   numeric(20,2) NOT NULL CHECK (jumlah_pengajuan > 0),
    tenor              integer NOT NULL CHECK (tenor > 0),
    status             varchar(25) NOT NULL
                       CHECK (status IN ('DIAJUKAN','DIPROSES','DISETUJUI','DITOLAK','DIBATALKAN')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE jenis_dokumen (
    jenis_dokumen_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_dokumen       varchar(100) NOT NULL UNIQUE,
    wajib              boolean NOT NULL DEFAULT true,
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dokumen_pengajuan (
    dokumen_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pengajuan_id       bigint NOT NULL REFERENCES pengajuan_pinjaman(pengajuan_id),
    jenis_dokumen_id   integer NOT NULL REFERENCES jenis_dokumen(jenis_dokumen_id),
    nomor_dokumen      varchar(80) NOT NULL,
    status_verifikasi  varchar(20) NOT NULL
                       CHECK (status_verifikasi IN ('MENUNGGU','VALID','TIDAK_VALID')),
    UNIQUE (pengajuan_id, jenis_dokumen_id)
);

CREATE TABLE penilaian_kredit (
    penilaian_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pengajuan_id       bigint NOT NULL UNIQUE REFERENCES pengajuan_pinjaman(pengajuan_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    skor_kredit        integer NOT NULL CHECK (skor_kredit BETWEEN 0 AND 1000),
    pendapatan_bulanan numeric(20,2) NOT NULL CHECK (pendapatan_bulanan >= 0),
    rasio_utang        numeric(8,4) NOT NULL CHECK (rasio_utang >= 0),
    rekomendasi        varchar(20) NOT NULL
                       CHECK (rekomendasi IN ('SETUJUI','TINJAU_ULANG','TOLAK')),
    tanggal_penilaian  timestamp NOT NULL
);

CREATE TABLE pinjaman (
    pinjaman_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pengajuan_id           bigint NOT NULL UNIQUE REFERENCES pengajuan_pinjaman(pengajuan_id),
    rekening_pencairan_id  bigint NOT NULL REFERENCES rekening(rekening_id),
    jumlah_pinjaman        numeric(20,2) NOT NULL CHECK (jumlah_pinjaman > 0),
    suku_bunga             numeric(8,4) NOT NULL CHECK (suku_bunga >= 0),
    tenor                  integer NOT NULL CHECK (tenor > 0),
    tanggal_pencairan      timestamp NOT NULL,
    status                 varchar(20) NOT NULL
                           CHECK (status IN ('AKTIF','LUNAS','MACET','DIBATALKAN')),
    last_update            timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE jadwal_angsuran (
    angsuran_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pinjaman_id          bigint NOT NULL REFERENCES pinjaman(pinjaman_id),
    angsuran_ke          integer NOT NULL CHECK (angsuran_ke > 0),
    tanggal_jatuh_tempo  date NOT NULL,
    pokok                numeric(20,2) NOT NULL CHECK (pokok >= 0),
    bunga                numeric(20,2) NOT NULL CHECK (bunga >= 0),
    denda                numeric(20,2) NOT NULL DEFAULT 0 CHECK (denda >= 0),
    status               varchar(20) NOT NULL
                         CHECK (status IN ('BELUM_JATUH_TEMPO','BELUM_DIBAYAR','DIBAYAR','TERLAMBAT')),
    UNIQUE (pinjaman_id, angsuran_ke)
);

CREATE TABLE pembayaran_angsuran (
    pembayaran_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    angsuran_id        bigint NOT NULL REFERENCES jadwal_angsuran(angsuran_id),
    transaksi_id       bigint NOT NULL UNIQUE REFERENCES transaksi(transaksi_id),
    tanggal_bayar      timestamp NOT NULL,
    jumlah_bayar       numeric(20,2) NOT NULL CHECK (jumlah_bayar > 0),
    status             varchar(20) NOT NULL
                       CHECK (status IN ('BERHASIL','GAGAL','DIKEMBALIKAN'))
);

CREATE TABLE jenis_jaminan (
    jenis_jaminan_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_jenis         varchar(100) NOT NULL UNIQUE,
    persentase_nilai   numeric(8,4) NOT NULL CHECK (persentase_nilai > 0),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE jaminan (
    jaminan_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pinjaman_id        bigint NOT NULL REFERENCES pinjaman(pinjaman_id),
    jenis_jaminan_id   integer NOT NULL REFERENCES jenis_jaminan(jenis_jaminan_id),
    nilai_taksiran     numeric(20,2) NOT NULL CHECK (nilai_taksiran > 0),
    status             varchar(20) NOT NULL
                       CHECK (status IN ('AKTIF','DILEPAS','DIEKSEKUSI'))
);

-- ============================================================
-- 7. LOGIN, PERANGKAT, DAN FRAUD
-- ============================================================

CREATE TABLE login_nasabah (
    login_id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nasabah_id             integer NOT NULL UNIQUE REFERENCES nasabah(nasabah_id),
    username               varchar(100) NOT NULL UNIQUE,
    password_hash          varchar(250) NOT NULL,
    tanggal_login_terakhir timestamp,
    status                 varchar(20) NOT NULL
                           CHECK (status IN ('AKTIF','TERKUNCI','NONAKTIF'))
);

CREATE TABLE perangkat_nasabah (
    perangkat_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nasabah_id         integer NOT NULL REFERENCES nasabah(nasabah_id),
    device_id          varchar(120) NOT NULL UNIQUE,
    jenis_perangkat    varchar(30) NOT NULL
                       CHECK (jenis_perangkat IN ('ANDROID','IOS','WINDOWS','MACOS','LINUX')),
    tanggal_registrasi timestamp NOT NULL,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('TERPERCAYA','DIBLOKIR','DIHAPUS'))
);

CREATE TABLE aktivitas_login (
    aktivitas_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    login_id           bigint NOT NULL REFERENCES login_nasabah(login_id),
    perangkat_id       bigint NOT NULL REFERENCES perangkat_nasabah(perangkat_id),
    waktu_login        timestamp NOT NULL,
    ip_address         inet NOT NULL,
    status_login       varchar(20) NOT NULL
                       CHECK (status_login IN ('BERHASIL','GAGAL','DITOLAK'))
);

CREATE TABLE jenis_fraud_alert (
    jenis_alert_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_alert         varchar(120) NOT NULL UNIQUE,
    tingkat_risiko     varchar(20) NOT NULL
                       CHECK (tingkat_risiko IN ('RENDAH','SEDANG','TINGGI','KRITIS')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fraud_alert (
    alert_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaksi_id       bigint NOT NULL REFERENCES transaksi(transaksi_id),
    nasabah_id         integer NOT NULL REFERENCES nasabah(nasabah_id),
    jenis_alert_id     integer NOT NULL REFERENCES jenis_fraud_alert(jenis_alert_id),
    tanggal_alert      timestamp NOT NULL,
    risk_score         numeric(8,2) NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
    status             varchar(20) NOT NULL
                       CHECK (status IN ('BARU','DIPROSES','SELESAI','FALSE_POSITIVE')),
    UNIQUE (transaksi_id, jenis_alert_id)
);

CREATE TABLE penanganan_fraud (
    penanganan_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alert_id           bigint NOT NULL REFERENCES fraud_alert(alert_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    tanggal_penanganan timestamp NOT NULL,
    tindakan           text NOT NULL,
    hasil              varchar(30) NOT NULL
                       CHECK (hasil IN ('TRANSAKSI_VALID','TRANSAKSI_DIBLOKIR','AKUN_DIBEKUKAN','PERLU_INVESTIGASI'))
);

-- ============================================================
-- 8. INDEKS UNTUK ANALISIS OLAP
-- ============================================================

CREATE INDEX idx_rekening_nasabah_status
    ON rekening(nasabah_id, status);

CREATE INDEX idx_rekening_cabang_status
    ON rekening(cabang_id, status);

CREATE INDEX idx_transaksi_rekening_tanggal
    ON transaksi(rekening_id, tanggal_transaksi);

CREATE INDEX idx_transaksi_status_tanggal
    ON transaksi(status, tanggal_transaksi);

CREATE INDEX idx_transaksi_jenis
    ON transaksi(jenis_transaksi_id, tanggal_transaksi);

CREATE INDEX idx_kartu_rekening
    ON kartu(rekening_id, status);

CREATE INDEX idx_transaksi_kartu_merchant_tanggal
    ON transaksi_kartu(merchant_id, tanggal_transaksi, status);

CREATE INDEX idx_merchant_kategori
    ON merchant(kategori_merchant_id, merchant_id);

CREATE INDEX idx_pengajuan_nasabah_produk
    ON pengajuan_pinjaman(nasabah_id, produk_pinjaman_id, status);

CREATE INDEX idx_pinjaman_pencairan
    ON pinjaman(tanggal_pencairan, status);

CREATE INDEX idx_login_aktivitas_waktu
    ON aktivitas_login(login_id, waktu_login);

CREATE INDEX idx_perangkat_nasabah
    ON perangkat_nasabah(nasabah_id, status);

CREATE INDEX idx_fraud_nasabah_tanggal
    ON fraud_alert(nasabah_id, tanggal_alert);

CREATE INDEX idx_fraud_transaksi
    ON fraud_alert(transaksi_id);

-- ============================================================
-- 9. DATA MASTER WILAYAH, CABANG, DAN PEGAWAI
-- ============================================================

INSERT INTO negara (nama_negara) VALUES
('Indonesia'),
('Malaysia'),
('Singapura'),
('Thailand');

INSERT INTO provinsi (nama_provinsi, negara_id) VALUES
('Aceh', 1),
('Sumatera Utara', 1),
('DKI Jakarta', 1),
('Jawa Barat', 1),
('Jawa Timur', 1),
('Selangor', 2),
('Central Region', 3),
('Bangkok Metropolitan', 4);

INSERT INTO kota (nama_kota, provinsi_id) VALUES
('Banda Aceh', 1),
('Meulaboh', 1),
('Medan', 2),
('Jakarta Pusat', 3),
('Jakarta Selatan', 3),
('Bandung', 4),
('Bekasi', 4),
('Surabaya', 5),
('Malang', 5),
('Shah Alam', 6),
('Singapore', 7),
('Bangkok', 8);

INSERT INTO alamat (
    alamat,
    kecamatan,
    kota_id,
    kode_pos,
    telepon
)
SELECT
    'Jalan Finansial Nomor ' || g,
    'Kecamatan ' || ((g - 1) % 45 + 1),
    ((g - 1) % 12) + 1,
    lpad((14000 + g)::text, 5, '0'),
    '08' || lpad((5000000000 + g)::text, 10, '0')
FROM generate_series(1, 2200) AS g;

INSERT INTO jabatan (nama_jabatan, level_otorisasi) VALUES
('Kepala Cabang', 1),
('Supervisor Operasional', 2),
('Analis Kredit', 3),
('Investigator Fraud', 3),
('Customer Service', 4),
('Teller', 4);

INSERT INTO cabang (
    kode_cabang,
    nama_cabang,
    alamat_id,
    status
)
SELECT
    'CBG-' || lpad(g::text, 3, '0'),
    'Cabang Bank ' || lpad(g::text, 2, '0'),
    g,
    'AKTIF'
FROM generate_series(1, 8) AS g;

INSERT INTO pegawai (
    cabang_id,
    atasan_id,
    jabatan_id,
    nama_depan,
    nama_belakang,
    email,
    status,
    tanggal_masuk
)
SELECT
    ((g - 1) % 8) + 1,
    NULL,
    CASE
        WHEN g <= 8 THEN 1
        WHEN g <= 16 THEN 2
        WHEN g % 5 = 0 THEN 4
        ELSE 3 + (g % 3)
    END,
    'Pegawai',
    lpad(g::text, 3, '0'),
    'pegawai' || g || '@bank.id',
    'AKTIF',
    CURRENT_DATE - ((500 + g * 13) || ' days')::interval
FROM generate_series(1, 48) AS g;

UPDATE pegawai p
SET atasan_id = (
    SELECT MIN(m.pegawai_id)
    FROM pegawai m
    WHERE m.cabang_id = p.cabang_id
      AND m.jabatan_id = 1
)
WHERE p.jabatan_id <> 1;

UPDATE cabang c
SET manager_pegawai_id = (
    SELECT MIN(p.pegawai_id)
    FROM pegawai p
    WHERE p.cabang_id = c.cabang_id
      AND p.jabatan_id = 1
);

-- ============================================================
-- 10. DATA NASABAH, REKENING, DAN KARTU
-- ============================================================

INSERT INTO nasabah (
    nomor_identitas,
    nama_depan,
    nama_belakang,
    tanggal_lahir,
    email,
    telepon,
    alamat_id,
    tanggal_daftar,
    status
)
SELECT
    'NIK-' || lpad(g::text, 12, '0'),
    'Nasabah',
    lpad(g::text, 4, '0'),
    date '1960-01-01' + ((g * 37) % 19000),
    'nasabah' || g || '@contoh.id',
    '081' || lpad((600000000 + g)::text, 9, '0'),
    200 + g,
    CURRENT_DATE - ((60 + (g % 1800)) || ' days')::interval,
    CASE WHEN g % 157 = 0 THEN 'DIBLOKIR' ELSE 'AKTIF' END
FROM generate_series(1, 960) AS g;

INSERT INTO jenis_rekening (
    nama_jenis,
    saldo_minimum,
    suku_bunga,
    biaya_admin,
    aktif
) VALUES
('Tabungan Reguler', 50000, 0.0200, 10000, true),
('Tabungan Premium', 1000000, 0.0350, 25000, true),
('Giro', 2000000, 0.0100, 50000, true),
('Deposito Fleksibel', 5000000, 0.0550, 0, true);

-- Rekening utama: 120 rekening per cabang.
INSERT INTO rekening (
    nomor_rekening,
    nasabah_id,
    jenis_rekening_id,
    cabang_id,
    tanggal_buka,
    saldo,
    status
)
SELECT
    '1000' || lpad(g::text, 12, '0'),
    g,
    1 + ((g - 1) % 4),
    ((g - 1) % 8) + 1,
    CURRENT_DATE - ((50 + (g % 1600)) || ' days')::interval,
    CASE
        WHEN g BETWEEN 11 AND 20
            THEN 8000000000::numeric + g * 100000000
        WHEN g BETWEEN 1 AND 10
            THEN 350000000::numeric + g * 1000000
        ELSE 5000000::numeric + ((g * 7919) % 450000000)
    END,
    CASE
        WHEN ((g - 1) / 8 + 1) <= (120 - (((g - 1) % 8) * 3))
            THEN 'AKTIF'
        ELSE 'DITUTUP'
    END
FROM generate_series(1, 960) AS g;

-- Rekening tambahan: 20 rekening tambahan per cabang.
INSERT INTO rekening (
    nomor_rekening,
    nasabah_id,
    jenis_rekening_id,
    cabang_id,
    tanggal_buka,
    saldo,
    status
)
SELECT
    '2000' || lpad(g::text, 12, '0'),
    g,
    2,
    ((g - 1) % 8) + 1,
    CURRENT_DATE - ((30 + (g % 900)) || ' days')::interval,
    CASE
        WHEN g BETWEEN 11 AND 20 THEN 1500000000
        ELSE 10000000 + ((g * 3571) % 90000000)
    END,
    'AKTIF'
FROM generate_series(1, 160) AS g;

INSERT INTO rekening_bersama (
    rekening_id,
    nasabah_id,
    peran,
    tanggal_mulai,
    tanggal_selesai
)
SELECT
    r.rekening_id,
    r.nasabah_id,
    'PEMILIK_UTAMA',
    r.tanggal_buka,
    NULL
FROM rekening r
WHERE r.rekening_id <= 40
UNION ALL
SELECT
    r.rekening_id,
    480 + r.rekening_id::integer,
    'PEMILIK_BERSAMA',
    r.tanggal_buka + 30,
    NULL
FROM rekening r
WHERE r.rekening_id <= 40;

INSERT INTO jenis_kartu (
    nama_jenis,
    limit_harian,
    biaya_tahunan,
    aktif
) VALUES
('Debit Reguler', 25000000, 0, true),
('Debit Premium', 100000000, 250000, true),
('Kartu Bisnis', 250000000, 500000, true);

INSERT INTO kartu (
    rekening_id,
    nomor_kartu,
    jenis_kartu_id,
    tanggal_terbit,
    tanggal_kedaluwarsa,
    status
)
SELECT
    r.rekening_id,
    '5221' || lpad(r.nasabah_id::text, 12, '0'),
    1 + ((r.nasabah_id - 1) % 3),
    r.tanggal_buka,
    r.tanggal_buka + interval '5 years',
    CASE WHEN r.status = 'AKTIF' THEN 'AKTIF' ELSE 'DITUTUP' END
FROM rekening r
WHERE r.rekening_id <= 960;

-- ============================================================
-- 11. MASTER TRANSAKSI DAN MERCHANT
-- ============================================================

INSERT INTO jenis_transaksi (
    nama_jenis,
    kategori,
    arah_saldo,
    aktif
) VALUES
('Setoran', 'SETORAN', 'KREDIT', true),
('Penarikan', 'PENARIKAN', 'DEBIT', true),
('Pembayaran Kartu', 'KARTU', 'DEBIT', true),
('Transfer Keluar', 'TRANSFER', 'DEBIT', true),
('Transfer Masuk', 'TRANSFER', 'KREDIT', true),
('Pencairan Pinjaman', 'PINJAMAN', 'KREDIT', true),
('Pembayaran Angsuran', 'PINJAMAN', 'DEBIT', true),
('Biaya Administrasi', 'BIAYA', 'DEBIT', true);

INSERT INTO channel_transaksi (
    nama_channel,
    jenis_channel,
    aktif
) VALUES
('Mobile Banking', 'DIGITAL', true),
('Internet Banking', 'DIGITAL', true),
('ATM', 'SELF_SERVICE', true),
('Teller', 'CABANG', true),
('EDC', 'MERCHANT', true),
('API Banking', 'INTEGRASI', true);

INSERT INTO kategori_merchant (
    nama_kategori,
    kode_mcc
) VALUES
('Makanan dan Minuman', '5812'),
('Ritel', '5411'),
('Transportasi', '4121'),
('Kesehatan', '5912'),
('Pendidikan', '8299'),
('Perjalanan', '4722'),
('Elektronik', '5732'),
('Layanan Profesional', '7399');

INSERT INTO merchant (
    nama_merchant,
    kategori_merchant_id,
    alamat_id,
    status
)
SELECT
    'Merchant ' || lpad(g::text, 3, '0'),
    ((g - 1) / 6) + 1,
    1300 + g,
    'AKTIF'
FROM generate_series(1, 48) AS g;

-- ============================================================
-- 12. MASTER PINJAMAN, DOKUMEN, JAMINAN, DAN FRAUD
-- ============================================================

INSERT INTO produk_pinjaman (
    nama_produk,
    suku_bunga,
    jumlah_minimum,
    jumlah_maksimum,
    tenor_maksimum,
    aktif
) VALUES
('Kredit Konsumtif', 0.1050, 5000000, 250000000, 60, true),
('Kredit Kendaraan', 0.0850, 25000000, 750000000, 72, true),
('Kredit Rumah', 0.0725, 100000000, 5000000000, 240, true),
('Kredit Usaha Mikro', 0.0650, 10000000, 500000000, 60, true),
('Kredit Modal Kerja', 0.0800, 50000000, 2000000000, 84, true),
('Kredit Pendidikan', 0.0600, 10000000, 300000000, 60, true),
('Kredit Renovasi', 0.0775, 25000000, 1000000000, 120, true),
('Kredit Ekspansi Digital', 0.0550, 100000000, 3000000000, 96, true);

INSERT INTO jenis_dokumen (
    nama_dokumen,
    wajib,
    aktif
) VALUES
('Identitas', true, true),
('Bukti Penghasilan', true, true),
('Rekening Koran', true, true),
('Dokumen Jaminan', false, true);

INSERT INTO jenis_jaminan (
    nama_jenis,
    persentase_nilai,
    aktif
) VALUES
('Tanah dan Bangunan', 0.8000, true),
('Kendaraan', 0.6500, true),
('Deposito', 0.9500, true),
('Persediaan Usaha', 0.5000, true);

INSERT INTO jenis_fraud_alert (
    nama_alert,
    tingkat_risiko
) VALUES
('Nilai Transaksi Tidak Wajar', 'TINGGI'),
('Pergantian Perangkat Cepat', 'TINGGI'),
('Lokasi Login Tidak Biasa', 'SEDANG'),
('Percobaan Login Berulang', 'RENDAH'),
('Pola Transaksi Kritis', 'KRITIS');

-- ============================================================
-- 13. LOGIN DAN PERANGKAT
-- ============================================================

INSERT INTO login_nasabah (
    nasabah_id,
    username,
    password_hash,
    tanggal_login_terakhir,
    status
)
SELECT
    nasabah_id,
    'user' || nasabah_id,
    'hash_login_' || nasabah_id,
    CURRENT_TIMESTAMP - ((nasabah_id % 72) || ' hours')::interval,
    CASE WHEN status = 'AKTIF' THEN 'AKTIF' ELSE 'TERKUNCI' END
FROM nasabah;

-- Satu perangkat utama untuk seluruh nasabah.
INSERT INTO perangkat_nasabah (
    nasabah_id,
    device_id,
    jenis_perangkat,
    tanggal_registrasi,
    status
)
SELECT
    nasabah_id,
    'DEVICE-PRIMARY-' || nasabah_id,
    CASE nasabah_id % 4
        WHEN 0 THEN 'ANDROID'
        WHEN 1 THEN 'IOS'
        WHEN 2 THEN 'WINDOWS'
        ELSE 'MACOS'
    END,
    CURRENT_TIMESTAMP - ((200 + nasabah_id % 500) || ' days')::interval,
    'TERPERCAYA'
FROM nasabah;

-- Nasabah 201-216 memiliki tiga perangkat untuk analisis risiko.
INSERT INTO perangkat_nasabah (
    nasabah_id,
    device_id,
    jenis_perangkat,
    tanggal_registrasi,
    status
)
SELECT
    n,
    'DEVICE-SECOND-' || n,
    'ANDROID',
    CURRENT_TIMESTAMP - interval '120 days',
    'TERPERCAYA'
FROM generate_series(201, 216) AS n
UNION ALL
SELECT
    n,
    'DEVICE-THIRD-' || n,
    'IOS',
    CURRENT_TIMESTAMP - interval '45 days',
    'TERPERCAYA'
FROM generate_series(201, 216) AS n;

-- ============================================================
-- 14. FUNGSI BANTU SEED TRANSAKSI
-- ============================================================

CREATE OR REPLACE FUNCTION seed_transaksi(
    p_rekening_id        bigint,
    p_jenis_transaksi_id integer,
    p_tanggal            timestamp,
    p_jumlah             numeric,
    p_channel_id         integer,
    p_status             varchar,
    p_keterangan         varchar
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_id              bigint;
    v_saldo           numeric(20,2);
BEGIN
    SELECT saldo
    INTO v_saldo
    FROM rekening
    WHERE rekening_id = p_rekening_id;

    INSERT INTO transaksi (
        rekening_id,
        jenis_transaksi_id,
        tanggal_transaksi,
        jumlah,
        saldo_setelah,
        channel_id,
        status,
        keterangan
    )
    VALUES (
        p_rekening_id,
        p_jenis_transaksi_id,
        p_tanggal,
        p_jumlah,
        greatest(v_saldo, 0),
        p_channel_id,
        p_status,
        p_keterangan
    )
    RETURNING transaksi_id INTO v_id;

    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION seed_transaksi_kartu(
    p_nasabah_id       integer,
    p_merchant_id      integer,
    p_tanggal          timestamp,
    p_jumlah           numeric,
    p_status           varchar
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rekening_id      bigint;
    v_kartu_id         bigint;
    v_transaksi_id     bigint;
BEGIN
    SELECT r.rekening_id
    INTO v_rekening_id
    FROM rekening r
    WHERE r.nasabah_id = p_nasabah_id
      AND r.status = 'AKTIF'
    ORDER BY r.rekening_id
    LIMIT 1;

    SELECT k.kartu_id
    INTO v_kartu_id
    FROM kartu k
    WHERE k.rekening_id = v_rekening_id
      AND k.status = 'AKTIF'
    ORDER BY k.kartu_id
    LIMIT 1;

    v_transaksi_id := seed_transaksi(
        v_rekening_id,
        3,
        p_tanggal,
        p_jumlah,
        5,
        p_status,
        'Transaksi kartu pada merchant ' || p_merchant_id
    );

    INSERT INTO transaksi_kartu (
        kartu_id,
        merchant_id,
        transaksi_id,
        tanggal_transaksi,
        jumlah,
        status
    )
    VALUES (
        v_kartu_id,
        p_merchant_id,
        v_transaksi_id,
        p_tanggal,
        p_jumlah,
        p_status
    );

    RETURN v_transaksi_id;
END;
$$;

-- ============================================================
-- 15. DATA TRANSAKSI KARTU DAN AKTIVITAS CABANG 15 BULAN
-- ============================================================

DO $$
DECLARE
    v_month_start      date := (date_trunc('month', CURRENT_DATE)::date - interval '14 months')::date;
    v_date             timestamp;
    v_customer         integer;
    v_branch           integer;
    v_account          bigint;
    v_amount           numeric(20,2);
    v_day              integer;
    v_champion         integer;
    m                  integer;
    mer                integer;
    j                  integer;
    c                  integer;
    b                  integer;
BEGIN
    -- --------------------------------------------------------
    -- A. Setiap merchant memiliki transaksi pada setiap bulan.
    --    Setiap kategori berisi enam merchant aktif.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR mer IN 1..48 LOOP
            FOR j IN 1..2 LOOP
                v_customer := 50 + ((mer * 17 + m * 23 + j * 11) % 880);
                v_branch := ((v_customer - 1) % 8) + 1;

                -- Cabang 8 sengaja kosong pada dua bulan.
                IF v_branch = 8 AND m IN (4, 9) THEN
                    v_customer := v_customer + 1;
                    IF v_customer > 960 THEN
                        v_customer := 50;
                    END IF;
                END IF;

                v_day := CASE
                    WHEN m = 14 THEN 1 + ((mer + j) % 6)
                    ELSE 2 + ((mer * 3 + j + m) % 24)
                END;

                v_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((v_day - 1) || ' days')::interval
                    + ((9 + j) || ' hours')::interval;

                v_amount := 150000 + (mer % 12) * 35000 + j * 25000;

                PERFORM seed_transaksi_kartu(
                    v_customer,
                    mer,
                    v_date,
                    v_amount,
                    'BERHASIL'
                );
            END LOOP;
        END LOOP;

        -- Merchant unggulan pada tiap kategori.
        FOR c IN 1..8 LOOP
            v_champion := ((c - 1) * 6) + 1;

            FOR j IN 1..3 LOOP
                v_customer := 300 + ((c * 47 + m * 13 + j * 19) % 600);
                v_branch := ((v_customer - 1) % 8) + 1;

                IF v_branch = 8 AND m IN (4, 9) THEN
                    v_customer := v_customer + 1;
                END IF;

                v_day := CASE
                    WHEN m = 14 THEN 1 + ((c + j) % 6)
                    ELSE 3 + ((c * 2 + j * 5 + m) % 22)
                END;

                v_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((v_day - 1) || ' days')::interval
                    + interval '14 hours';

                PERFORM seed_transaksi_kartu(
                    v_customer,
                    v_champion,
                    v_date,
                    1200000 + c * 125000,
                    'BERHASIL'
                );
            END LOOP;
        END LOOP;

        -- ----------------------------------------------------
        -- B. Aktivitas transaksi umum per cabang.
        -- ----------------------------------------------------
        FOR b IN 1..8 LOOP
            IF b = 8 AND m IN (4, 9) THEN
                CONTINUE;
            END IF;

            FOR j IN 1..12 LOOP
                v_customer := b + 8 * (200 + ((m * 17 + j * 7) % 700));
                WHILE v_customer > 960 LOOP
                    v_customer := v_customer - 8 * 700;
                END LOOP;

                SELECT rekening_id
                INTO v_account
                FROM rekening
                WHERE nasabah_id = v_customer
                  AND cabang_id = b
                  AND status = 'AKTIF'
                ORDER BY rekening_id
                LIMIT 1;

                IF v_account IS NULL THEN
                    SELECT rekening_id
                    INTO v_account
                    FROM rekening
                    WHERE cabang_id = b
                      AND status = 'AKTIF'
                    ORDER BY rekening_id
                    OFFSET ((m * 12 + j) % 80)
                    LIMIT 1;
                END IF;

                v_day := CASE
                    WHEN m = 14 THEN 1 + (j % 6)
                    ELSE 2 + ((j * 2 + m) % 24)
                END;

                v_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((v_day - 1) || ' days')::interval
                    + interval '10 hours';

                v_amount := 500000 + b * 75000 + j * 25000;

                PERFORM seed_transaksi(
                    v_account,
                    CASE WHEN j % 2 = 0 THEN 1 ELSE 2 END,
                    v_date,
                    v_amount,
                    CASE WHEN j % 3 = 0 THEN 4 ELSE 1 END,
                    'BERHASIL',
                    'Aktivitas transaksi cabang'
                );
            END LOOP;
        END LOOP;

        -- ----------------------------------------------------
        -- C. Nasabah 1-10 memiliki total transaksi terbesar.
        --    Mereka tidak pernah bertransaksi pada merchant 40.
        -- ----------------------------------------------------
        FOR c IN 1..10 LOOP
            IF c = 8 AND m IN (4, 9) THEN
                CONTINUE;
            END IF;

            FOR j IN 1..2 LOOP
                v_day := CASE
                    WHEN m = 14 THEN 1 + ((c + j) % 6)
                    ELSE 3 + ((c + j * 3 + m) % 21)
                END;

                v_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((v_day - 1) || ' days')::interval
                    + interval '17 hours';

                v_amount := CASE
                    WHEN c <= 5 THEN 25000000
                    ELSE 20000000
                END;

                PERFORM seed_transaksi_kartu(
                    c,
                    1 + ((c + m + j) % 12),
                    v_date,
                    v_amount,
                    'BERHASIL'
                );
            END LOOP;
        END LOOP;

        -- ----------------------------------------------------
        -- D. Merchant 40 memiliki nilai transaksi sangat tinggi,
        --    tetapi tidak pernah menerima transaksi nasabah 1-10.
        -- ----------------------------------------------------
        FOR j IN 1..10 LOOP
            v_customer := 100 + ((m * 41 + j * 29) % 800);
            IF v_customer <= 10 THEN
                v_customer := v_customer + 20;
            END IF;

            v_branch := ((v_customer - 1) % 8) + 1;
            IF v_branch = 8 AND m IN (4, 9) THEN
                v_customer := v_customer + 1;
            END IF;

            v_day := CASE
                WHEN m = 14 THEN 1 + (j % 6)
                ELSE 2 + ((j * 2 + m) % 23)
            END;

            v_date :=
                v_month_start
                + (m || ' months')::interval
                + ((v_day - 1) || ' days')::interval
                + interval '19 hours';

            PERFORM seed_transaksi_kartu(
                v_customer,
                40,
                v_date,
                5000000,
                'BERHASIL'
            );
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 16. TRANSFER
-- ============================================================

DO $$
DECLARE
    v_month_start      date := (date_trunc('month', CURRENT_DATE)::date - interval '2 months')::date;
    v_sender           bigint;
    v_receiver         bigint;
    v_debit_id         bigint;
    v_credit_id        bigint;
    v_date             timestamp;
    i                  integer;
BEGIN
    FOR i IN 1..80 LOOP
        SELECT rekening_id
        INTO v_sender
        FROM rekening
        WHERE nasabah_id = 300 + i
          AND status = 'AKTIF'
        ORDER BY rekening_id
        LIMIT 1;

        SELECT rekening_id
        INTO v_receiver
        FROM rekening
        WHERE nasabah_id = 500 + i
          AND status = 'AKTIF'
        ORDER BY rekening_id
        LIMIT 1;

        v_date :=
            v_month_start
            + ((i % 55) || ' days')::interval
            + interval '12 hours';

        v_debit_id := seed_transaksi(
            v_sender,
            4,
            v_date,
            1000000 + i * 10000,
            1,
            'BERHASIL',
            'Transfer keluar'
        );

        v_credit_id := seed_transaksi(
            v_receiver,
            5,
            v_date,
            1000000 + i * 10000,
            1,
            'BERHASIL',
            'Transfer masuk'
        );

        INSERT INTO transfer (
            transaksi_debit_id,
            transaksi_kredit_id,
            rekening_pengirim_id,
            rekening_penerima_id,
            jumlah,
            berita
        )
        VALUES (
            v_debit_id,
            v_credit_id,
            v_sender,
            v_receiver,
            1000000 + i * 10000,
            'Transfer simulasi'
        );
    END LOOP;
END $$;

-- ============================================================
-- 17. DATA PINJAMAN
-- ============================================================

DO $$
DECLARE
    v_apply_id         bigint;
    v_loan_id          bigint;
    v_account          bigint;
    v_employee         integer;
    v_product          integer;
    v_amount           numeric(20,2);
    v_date             timestamp;
    v_tx               bigint;
    v_installment_id   bigint;
    v_monthly_principal numeric(20,2);
    n                  integer;
    i                  integer;
    a                  integer;
BEGIN
    -- Nasabah 11-20 adalah 10 nasabah dengan saldo aktif terbesar.
    -- Mereka hanya menggunakan produk pinjaman 1-4.
    FOR n IN 11..20 LOOP
        v_product := 1 + ((n - 11) % 4);
        v_amount := 250000000 + (n - 10) * 10000000;
        v_employee := 17 + ((n - 11) % 8);
        v_date := date_trunc('month', CURRENT_DATE)::timestamp - interval '8 months'
                  + ((n - 10) || ' days')::interval;

        SELECT rekening_id
        INTO v_account
        FROM rekening
        WHERE nasabah_id = n
          AND status = 'AKTIF'
        ORDER BY rekening_id
        LIMIT 1;

        INSERT INTO pengajuan_pinjaman (
            nasabah_id,
            produk_pinjaman_id,
            pegawai_id,
            tanggal_pengajuan,
            jumlah_pengajuan,
            tenor,
            status
        )
        VALUES (
            n,
            v_product,
            v_employee,
            v_date,
            v_amount,
            24,
            'DISETUJUI'
        )
        RETURNING pengajuan_id INTO v_apply_id;

        INSERT INTO dokumen_pengajuan (
            pengajuan_id,
            jenis_dokumen_id,
            nomor_dokumen,
            status_verifikasi
        )
        SELECT
            v_apply_id,
            jd.jenis_dokumen_id,
            'DOC-' || v_apply_id || '-' || jd.jenis_dokumen_id,
            'VALID'
        FROM jenis_dokumen jd
        WHERE jd.jenis_dokumen_id <= 3;

        INSERT INTO penilaian_kredit (
            pengajuan_id,
            pegawai_id,
            skor_kredit,
            pendapatan_bulanan,
            rasio_utang,
            rekomendasi,
            tanggal_penilaian
        )
        VALUES (
            v_apply_id,
            v_employee,
            790,
            50000000,
            0.2200,
            'SETUJUI',
            v_date + interval '2 days'
        );

        INSERT INTO pinjaman (
            pengajuan_id,
            rekening_pencairan_id,
            jumlah_pinjaman,
            suku_bunga,
            tenor,
            tanggal_pencairan,
            status
        )
        SELECT
            v_apply_id,
            v_account,
            v_amount,
            pp.suku_bunga,
            24,
            v_date + interval '5 days',
            'AKTIF'
        FROM produk_pinjaman pp
        WHERE pp.produk_pinjaman_id = v_product
        RETURNING pinjaman_id INTO v_loan_id;

        v_tx := seed_transaksi(
            v_account,
            6,
            v_date + interval '5 days',
            v_amount,
            6,
            'BERHASIL',
            'Pencairan pinjaman'
        );

        INSERT INTO jaminan (
            pinjaman_id,
            jenis_jaminan_id,
            nilai_taksiran,
            status
        )
        VALUES (
            v_loan_id,
            1 + ((n - 11) % 4),
            v_amount * 1.30,
            'AKTIF'
        );

        v_monthly_principal := round(v_amount / 24, 2);

        FOR a IN 1..24 LOOP
            INSERT INTO jadwal_angsuran (
                pinjaman_id,
                angsuran_ke,
                tanggal_jatuh_tempo,
                pokok,
                bunga,
                denda,
                status
            )
            VALUES (
                v_loan_id,
                a,
                (v_date + interval '5 days' + (a || ' months')::interval)::date,
                v_monthly_principal,
                round(v_amount * 0.0075, 2),
                0,
                CASE WHEN a <= 3 THEN 'DIBAYAR' ELSE 'BELUM_JATUH_TEMPO' END
            );
        END LOOP;
    END LOOP;

    -- Produk 8 memiliki total pencairan tertinggi dan tidak pernah
    -- digunakan oleh nasabah 11-20.
    FOR i IN 1..60 LOOP
        n := 300 + i;
        v_product := 8;
        v_amount := 550000000 + (i % 10) * 25000000;
        v_employee := 17 + ((i - 1) % 8);
        v_date := date_trunc('month', CURRENT_DATE)::timestamp - interval '6 months'
                  + ((i % 150) || ' days')::interval;

        SELECT rekening_id
        INTO v_account
        FROM rekening
        WHERE nasabah_id = n
          AND status = 'AKTIF'
        ORDER BY rekening_id
        LIMIT 1;

        INSERT INTO pengajuan_pinjaman (
            nasabah_id,
            produk_pinjaman_id,
            pegawai_id,
            tanggal_pengajuan,
            jumlah_pengajuan,
            tenor,
            status
        )
        VALUES (
            n,
            v_product,
            v_employee,
            v_date,
            v_amount,
            36,
            'DISETUJUI'
        )
        RETURNING pengajuan_id INTO v_apply_id;

        INSERT INTO dokumen_pengajuan (
            pengajuan_id,
            jenis_dokumen_id,
            nomor_dokumen,
            status_verifikasi
        )
        SELECT
            v_apply_id,
            jd.jenis_dokumen_id,
            'DOC-' || v_apply_id || '-' || jd.jenis_dokumen_id,
            'VALID'
        FROM jenis_dokumen jd;

        INSERT INTO penilaian_kredit (
            pengajuan_id,
            pegawai_id,
            skor_kredit,
            pendapatan_bulanan,
            rasio_utang,
            rekomendasi,
            tanggal_penilaian
        )
        VALUES (
            v_apply_id,
            v_employee,
            820 - (i % 40),
            90000000 + i * 500000,
            0.1800 + (i % 5) * 0.0100,
            'SETUJUI',
            v_date + interval '2 days'
        );

        INSERT INTO pinjaman (
            pengajuan_id,
            rekening_pencairan_id,
            jumlah_pinjaman,
            suku_bunga,
            tenor,
            tanggal_pencairan,
            status
        )
        VALUES (
            v_apply_id,
            v_account,
            v_amount,
            0.0550,
            36,
            v_date + interval '5 days',
            'AKTIF'
        )
        RETURNING pinjaman_id INTO v_loan_id;

        PERFORM seed_transaksi(
            v_account,
            6,
            v_date + interval '5 days',
            v_amount,
            6,
            'BERHASIL',
            'Pencairan Kredit Ekspansi Digital'
        );

        INSERT INTO jaminan (
            pinjaman_id,
            jenis_jaminan_id,
            nilai_taksiran,
            status
        )
        VALUES (
            v_loan_id,
            1 + (i % 4),
            v_amount * 1.35,
            'AKTIF'
        );

        v_monthly_principal := round(v_amount / 36, 2);

        FOR a IN 1..12 LOOP
            INSERT INTO jadwal_angsuran (
                pinjaman_id,
                angsuran_ke,
                tanggal_jatuh_tempo,
                pokok,
                bunga,
                denda,
                status
            )
            VALUES (
                v_loan_id,
                a,
                (v_date + interval '5 days' + (a || ' months')::interval)::date,
                v_monthly_principal,
                round(v_amount * 0.0045, 2),
                0,
                CASE WHEN a <= 2 THEN 'DIBAYAR' ELSE 'BELUM_JATUH_TEMPO' END
            )
            RETURNING angsuran_id INTO v_installment_id;

            IF a <= 2 THEN
                v_tx := seed_transaksi(
                    v_account,
                    7,
                    v_date + interval '5 days' + (a || ' months')::interval,
                    v_monthly_principal + round(v_amount * 0.0045, 2),
                    1,
                    'BERHASIL',
                    'Pembayaran angsuran pinjaman'
                );

                INSERT INTO pembayaran_angsuran (
                    angsuran_id,
                    transaksi_id,
                    tanggal_bayar,
                    jumlah_bayar,
                    status
                )
                VALUES (
                    v_installment_id,
                    v_tx,
                    v_date + interval '5 days' + (a || ' months')::interval,
                    v_monthly_principal + round(v_amount * 0.0045, 2),
                    'BERHASIL'
                );
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 18. DATA RISIKO TRANSAKSI ENAM BULAN TERAKHIR
-- ============================================================

DO $$
DECLARE
    v_six_month_start  date := (date_trunc('month', CURRENT_DATE)::date - interval '5 months')::date;
    v_account          bigint;
    v_tx               bigint;
    v_date             timestamp;
    v_login_id         bigint;
    v_device_1         bigint;
    v_device_2         bigint;
    v_device_3         bigint;
    v_alert_id         bigint;
    v_employee         integer;
    v_branch           integer;
    n                  integer;
    m                  integer;
    j                  integer;
BEGIN
    -- Dua nasabah per cabang: 201-208 dan 209-216.
    FOR n IN 201..216 LOOP
        v_branch := ((n - 1) % 8) + 1;

        SELECT rekening_id
        INTO v_account
        FROM rekening
        WHERE nasabah_id = n
          AND status = 'AKTIF'
        ORDER BY rekening_id
        LIMIT 1;

        SELECT login_id
        INTO v_login_id
        FROM login_nasabah
        WHERE nasabah_id = n;

        SELECT MIN(perangkat_id)
        INTO v_device_1
        FROM perangkat_nasabah
        WHERE nasabah_id = n;

        SELECT MIN(perangkat_id)
        INTO v_device_2
        FROM perangkat_nasabah
        WHERE nasabah_id = n
          AND perangkat_id > v_device_1;

        SELECT MAX(perangkat_id)
        INTO v_device_3
        FROM perangkat_nasabah
        WHERE nasabah_id = n;

        -- 36 transaksi rutin: enam transaksi per bulan.
        FOR m IN 0..5 LOOP
            IF v_branch = 8 AND m = 0 THEN
                -- Bulan ini bertepatan dengan bulan kosong cabang 8.
                CONTINUE;
            END IF;

            FOR j IN 1..6 LOOP
                v_date :=
                    v_six_month_start
                    + (m || ' months')::interval
                    + ((2 + ((j * 3 + n) % 20)) || ' days')::interval
                    + interval '09 hours';

                PERFORM seed_transaksi(
                    v_account,
                    CASE WHEN j % 2 = 0 THEN 1 ELSE 2 END,
                    v_date,
                    100000 + (j * 15000) + (n % 8) * 5000,
                    1,
                    'BERHASIL',
                    'Transaksi rutin profil risiko'
                );
            END LOOP;
        END LOOP;

        -- Tiga transaksi anomali bernilai besar.
        FOR j IN 1..3 LOOP
            v_date :=
                date_trunc('month', CURRENT_DATE)::timestamp
                - ((3 - j) || ' months')::interval
                + ((2 + ((n + j) % 5)) || ' days')::interval
                + interval '18 hours';

            v_tx := seed_transaksi(
                v_account,
                2,
                v_date,
                CASE
                    WHEN n BETWEEN 201 AND 208 THEN 30000000 + j * 5000000
                    ELSE 18000000 + j * 2000000
                END,
                1,
                'BERHASIL',
                'Transaksi anomali profil risiko'
            );

            -- Login dari beberapa perangkat dalam 24 jam sebelum anomali.
            INSERT INTO aktivitas_login (
                login_id,
                perangkat_id,
                waktu_login,
                ip_address,
                status_login
            )
            VALUES
            (
                v_login_id,
                v_device_1,
                v_date - interval '20 hours',
                ('10.' || v_branch || '.' || j || '.10')::inet,
                'BERHASIL'
            ),
            (
                v_login_id,
                v_device_2,
                v_date - interval '10 hours',
                ('10.' || v_branch || '.' || j || '.20')::inet,
                'BERHASIL'
            );

            IF n BETWEEN 201 AND 208 THEN
                INSERT INTO aktivitas_login (
                    login_id,
                    perangkat_id,
                    waktu_login,
                    ip_address,
                    status_login
                )
                VALUES (
                    v_login_id,
                    v_device_3,
                    v_date - interval '2 hours',
                    ('172.16.' || v_branch || '.' || (30 + j))::inet,
                    'BERHASIL'
                );

                INSERT INTO fraud_alert (
                    transaksi_id,
                    nasabah_id,
                    jenis_alert_id,
                    tanggal_alert,
                    risk_score,
                    status
                )
                VALUES (
                    v_tx,
                    n,
                    CASE WHEN j = 3 THEN 5 ELSE 1 END,
                    v_date + interval '1 minute',
                    CASE WHEN j = 3 THEN 96 ELSE 88 + j END,
                    'SELESAI'
                )
                RETURNING alert_id INTO v_alert_id;

                v_employee := 25 + ((v_branch - 1) % 8);

                INSERT INTO penanganan_fraud (
                    alert_id,
                    pegawai_id,
                    tanggal_penanganan,
                    tindakan,
                    hasil
                )
                VALUES (
                    v_alert_id,
                    v_employee,
                    v_date + interval '2 hours',
                    'Verifikasi transaksi dan perangkat nasabah',
                    CASE WHEN j = 3 THEN 'TRANSAKSI_DIBLOKIR' ELSE 'PERLU_INVESTIGASI' END
                );
            ELSE
                IF j = 1 THEN
                    INSERT INTO fraud_alert (
                        transaksi_id,
                        nasabah_id,
                        jenis_alert_id,
                        tanggal_alert,
                        risk_score,
                        status
                    )
                    VALUES (
                        v_tx,
                        n,
                        3,
                        v_date + interval '2 minutes',
                        62,
                        'SELESAI'
                    )
                    RETURNING alert_id INTO v_alert_id;

                    v_employee := 25 + ((v_branch - 1) % 8);

                    INSERT INTO penanganan_fraud (
                        alert_id,
                        pegawai_id,
                        tanggal_penanganan,
                        tindakan,
                        hasil
                    )
                    VALUES (
                        v_alert_id,
                        v_employee,
                        v_date + interval '3 hours',
                        'Konfirmasi lokasi login',
                        'TRANSAKSI_VALID'
                    );
                END IF;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 19. CONTOH TRANSAKSI GAGAL
-- ============================================================

DO $$
DECLARE
    v_account          bigint;
    v_date             timestamp;
    i                  integer;
BEGIN
    FOR i IN 1..40 LOOP
        SELECT rekening_id
        INTO v_account
        FROM rekening
        WHERE nasabah_id = 700 + i
          AND status = 'AKTIF'
        ORDER BY rekening_id
        LIMIT 1;

        v_date := CURRENT_TIMESTAMP - ((i % 90) || ' days')::interval;

        PERFORM seed_transaksi(
            v_account,
            2,
            v_date,
            2500000 + i * 10000,
            3,
            'GAGAL',
            'Contoh transaksi gagal'
        );
    END LOOP;
END $$;

DROP FUNCTION seed_transaksi_kartu(integer, integer, timestamp, numeric, varchar);
DROP FUNCTION seed_transaksi(bigint, integer, timestamp, numeric, integer, varchar, varchar);

ANALYZE;

-- ============================================================
-- 20. RINGKASAN POLA DATA
-- ============================================================
-- Tabel utama:
--   cabang                 : 8
--   nasabah                : 960
--   rekening               : 1.120, sedikitnya 140 per cabang
--   merchant               : 48, 8 kategori x 6 merchant
--   periode transaksi      : 15 bulan
--   produk pinjaman        : 8
--
-- Pola analitik:
--   * Nasabah 1-10 memiliki total transaksi berhasil terbesar.
--   * Rekening utama nasabah 1-5 memiliki nilai transaksi yang sama
--     dan sangat tinggi, sehingga kondisi peringkat seri dapat diuji.
--   * Merchant 40 memiliki total transaksi kartu sangat tinggi, tetapi
--     tidak pernah menerima transaksi dari nasabah 1-10.
--   * Nasabah 11-20 memiliki total saldo rekening aktif terbesar.
--   * Produk pinjaman 8 memiliki total pencairan tertinggi dan tidak
--     pernah digunakan oleh nasabah 11-20.
--   * Setiap kategori merchant memiliki 6 merchant yang bertransaksi
--     pada seluruh bulan, sehingga analisis persentil valid.
--   * Cabang 8 tidak memiliki transaksi pada dua bulan tertentu.
--   * Nasabah 201-216 memiliki sedikitnya dua perangkat dan lebih dari
--     30 transaksi selama enam bulan terakhir.
--   * Nasabah 201-208 memiliki anomali, pergantian tiga perangkat,
--     dan fraud alert berisiko tinggi lebih banyak daripada pasangan
--     pembandingnya di cabang yang sama.
--
-- Filter transaksi valid yang disarankan:
--   transaksi.status = 'BERHASIL'
--   transaksi_kartu.status = 'BERHASIL'
--   pinjaman.status IN ('AKTIF','LUNAS')
--
-- Catatan bulan tanpa transaksi:
--   Pertanyaan pertumbuhan bulanan sebaiknya membangun kalender dengan
--   generate_series(), lalu LEFT JOIN ke agregasi transaksi per cabang.
-- ============================================================
