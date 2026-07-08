-- ============================================================
-- SKEMA 3: SISTEM RUMAH SAKIT / KLINIK MULTI-CABANG
-- PostgreSQL
--
-- Tujuan data:
-- 1. Mendukung seluruh 7 soal OLAP pada Skema 3.
-- 2. Menyediakan data 15 bulan, banyak cabang, poli, dokter,
--    pasien, kunjungan, pembayaran, resep, dan obat.
-- 3. Menyediakan pola khusus untuk analisis ranking, NOT EXISTS,
--    pertumbuhan bulanan, moving average, persentil, dan cohort.
--
-- Jalankan seluruh file ini pada database PostgreSQL.
-- ============================================================

DROP SCHEMA IF EXISTS rumah_sakit_multicabang CASCADE;
CREATE SCHEMA rumah_sakit_multicabang;
SET search_path TO rumah_sakit_multicabang, public;

-- ============================================================
-- 1. TABEL WILAYAH
-- ============================================================

CREATE TABLE provinsi (
    provinsi_id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_provinsi     varchar(100) NOT NULL UNIQUE,
    last_update       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
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
-- 2. TABEL CABANG DAN SUMBER DAYA MANUSIA
-- ============================================================

CREATE TABLE cabang (
    cabang_id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_cabang            varchar(120) NOT NULL UNIQUE,
    kepala_petugas_id      integer,
    alamat_id              bigint NOT NULL REFERENCES alamat(alamat_id),
    aktif                  boolean NOT NULL DEFAULT true,
    last_update            timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE petugas (
    petugas_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_depan          varchar(80) NOT NULL,
    nama_belakang       varchar(80) NOT NULL,
    cabang_id           integer NOT NULL REFERENCES cabang(cabang_id),
    alamat_id           bigint NOT NULL REFERENCES alamat(alamat_id),
    email               varchar(150) NOT NULL UNIQUE,
    username            varchar(80) NOT NULL UNIQUE,
    password_hash       varchar(200) NOT NULL,
    aktif               boolean NOT NULL DEFAULT true,
    tanggal_masuk       date NOT NULL,
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE cabang
    ADD CONSTRAINT fk_cabang_kepala_petugas
    FOREIGN KEY (kepala_petugas_id)
    REFERENCES petugas(petugas_id);

CREATE TABLE spesialisasi (
    spesialisasi_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama                varchar(120) NOT NULL UNIQUE,
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dokter (
    dokter_id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_depan          varchar(80) NOT NULL,
    nama_belakang       varchar(80) NOT NULL,
    nomor_sip           varchar(50) NOT NULL UNIQUE,
    email               varchar(150) NOT NULL UNIQUE,
    alamat_id           bigint NOT NULL REFERENCES alamat(alamat_id),
    aktif               boolean NOT NULL DEFAULT true,
    tanggal_masuk       date NOT NULL,
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dokter_spesialisasi (
    dokter_id           integer NOT NULL REFERENCES dokter(dokter_id),
    spesialisasi_id     integer NOT NULL REFERENCES spesialisasi(spesialisasi_id),
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (dokter_id, spesialisasi_id)
);

CREATE TABLE poli (
    poli_id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_poli           varchar(120) NOT NULL,
    cabang_id           integer NOT NULL REFERENCES cabang(cabang_id),
    aktif               boolean NOT NULL DEFAULT true,
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (nama_poli, cabang_id)
);

CREATE TABLE jadwal_dokter (
    jadwal_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dokter_id           integer NOT NULL REFERENCES dokter(dokter_id),
    poli_id             integer NOT NULL REFERENCES poli(poli_id),
    hari                varchar(10) NOT NULL
                        CHECK (hari IN ('SENIN','SELASA','RABU','KAMIS','JUMAT','SABTU','MINGGU')),
    jam_mulai           time NOT NULL,
    jam_selesai         time NOT NULL,
    aktif               boolean NOT NULL DEFAULT true,
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (jam_selesai > jam_mulai)
);

-- ============================================================
-- 3. TABEL PASIEN DAN TRANSAKSI KLINIS
-- ============================================================

CREATE TABLE pasien (
    pasien_id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nomor_rm            varchar(30) NOT NULL UNIQUE,
    nama_depan          varchar(80) NOT NULL,
    nama_belakang       varchar(80) NOT NULL,
    tanggal_lahir       date NOT NULL,
    email               varchar(150) UNIQUE,
    alamat_id           bigint NOT NULL REFERENCES alamat(alamat_id),
    tanggal_daftar      date NOT NULL,
    aktif               boolean NOT NULL DEFAULT true,
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kunjungan (
    kunjungan_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pasien_id           integer NOT NULL REFERENCES pasien(pasien_id),
    jadwal_id           bigint NOT NULL REFERENCES jadwal_dokter(jadwal_id),
    petugas_id          integer NOT NULL REFERENCES petugas(petugas_id),
    tanggal_kunjungan   timestamp NOT NULL,
    keluhan             text NOT NULL,
    status              varchar(20) NOT NULL
                        CHECK (status IN ('TERJADWAL','DIPERIKSA','SELESAI','DIBATALKAN')),
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE rekam_medis (
    rekam_medis_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kunjungan_id        bigint NOT NULL UNIQUE REFERENCES kunjungan(kunjungan_id),
    dokter_id           integer NOT NULL REFERENCES dokter(dokter_id),
    diagnosis           text NOT NULL,
    tindakan            text NOT NULL,
    catatan             text,
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 4. TABEL OBAT DAN RESEP
-- ============================================================

CREATE TABLE kategori_obat (
    kategori_obat_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama                varchar(120) NOT NULL UNIQUE,
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE obat (
    obat_id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_obat           varchar(150) NOT NULL UNIQUE,
    kategori_obat_id    integer NOT NULL REFERENCES kategori_obat(kategori_obat_id),
    harga               numeric(14,2) NOT NULL CHECK (harga > 0),
    stok                integer NOT NULL CHECK (stok >= 0),
    aktif               boolean NOT NULL DEFAULT true,
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE resep (
    resep_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rekam_medis_id      bigint NOT NULL UNIQUE REFERENCES rekam_medis(rekam_medis_id),
    dokter_id           integer NOT NULL REFERENCES dokter(dokter_id),
    tanggal_resep       timestamp NOT NULL,
    status              varchar(20) NOT NULL
                        CHECK (status IN ('DIBUAT','DISIAPKAN','DISERAHKAN','DIBATALKAN')),
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE detail_resep (
    detail_resep_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    resep_id            bigint NOT NULL REFERENCES resep(resep_id),
    obat_id             integer NOT NULL REFERENCES obat(obat_id),
    jumlah              integer NOT NULL CHECK (jumlah > 0),
    dosis               varchar(100) NOT NULL,
    aturan_pakai        varchar(200) NOT NULL,
    UNIQUE (resep_id, obat_id)
);

-- ============================================================
-- 5. TABEL PEMBAYARAN
-- ============================================================

CREATE TABLE pembayaran (
    pembayaran_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kunjungan_id        bigint NOT NULL UNIQUE REFERENCES kunjungan(kunjungan_id),
    pasien_id           integer NOT NULL REFERENCES pasien(pasien_id),
    petugas_id          integer NOT NULL REFERENCES petugas(petugas_id),
    jumlah              numeric(16,2) NOT NULL CHECK (jumlah >= 0),
    metode              varchar(30) NOT NULL
                        CHECK (metode IN ('TUNAI','TRANSFER','KARTU','ASURANSI','E_WALLET')),
    tanggal_bayar       timestamp NOT NULL,
    status              varchar(20) NOT NULL
                        CHECK (status IN ('MENUNGGU','BERHASIL','GAGAL','DIKEMBALIKAN')),
    last_update         timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 6. INDEKS UNTUK ANALISIS OLAP
-- ============================================================

CREATE INDEX idx_dokter_spesialisasi_spesialisasi
    ON dokter_spesialisasi(spesialisasi_id, dokter_id);

CREATE INDEX idx_poli_cabang
    ON poli(cabang_id, poli_id);

CREATE INDEX idx_jadwal_dokter_poli
    ON jadwal_dokter(dokter_id, poli_id);

CREATE INDEX idx_kunjungan_tanggal_status
    ON kunjungan(tanggal_kunjungan, status);

CREATE INDEX idx_kunjungan_pasien_tanggal
    ON kunjungan(pasien_id, tanggal_kunjungan);

CREATE INDEX idx_kunjungan_jadwal
    ON kunjungan(jadwal_id);

CREATE INDEX idx_rekam_medis_dokter
    ON rekam_medis(dokter_id);

CREATE INDEX idx_resep_tanggal
    ON resep(tanggal_resep, status);

CREATE INDEX idx_detail_resep_obat
    ON detail_resep(obat_id, resep_id);

CREATE INDEX idx_pembayaran_status_tanggal
    ON pembayaran(status, tanggal_bayar);

CREATE INDEX idx_pembayaran_pasien
    ON pembayaran(pasien_id, status);

-- ============================================================
-- 7. DATA MASTER
-- ============================================================

INSERT INTO provinsi (nama_provinsi) VALUES
('Aceh'),
('Sumatera Utara'),
('DKI Jakarta'),
('Jawa Barat'),
('Jawa Timur');

INSERT INTO kota (nama_kota, provinsi_id) VALUES
('Banda Aceh', 1),
('Meulaboh', 1),
('Medan', 2),
('Binjai', 2),
('Jakarta Pusat', 3),
('Jakarta Selatan', 3),
('Bandung', 4),
('Bekasi', 4),
('Bogor', 4),
('Surabaya', 5),
('Malang', 5),
('Sidoarjo', 5);

INSERT INTO alamat (
    alamat,
    kecamatan,
    kota_id,
    kode_pos,
    telepon
)
SELECT
    'Jalan Kesehatan Nomor ' || g,
    'Kecamatan ' || ((g - 1) % 35 + 1),
    ((g - 1) % 12) + 1,
    lpad((11000 + g)::text, 5, '0'),
    '08' || lpad((2000000000 + g)::text, 10, '0')
FROM generate_series(1, 1000) AS g;

INSERT INTO cabang (
    nama_cabang,
    alamat_id,
    aktif
)
SELECT
    'Cabang Klinik ' || lpad(g::text, 2, '0'),
    g,
    true
FROM generate_series(1, 8) AS g;

INSERT INTO petugas (
    nama_depan,
    nama_belakang,
    cabang_id,
    alamat_id,
    email,
    username,
    password_hash,
    aktif,
    tanggal_masuk
)
SELECT
    'Petugas',
    lpad(g::text, 3, '0'),
    ((g - 1) % 8) + 1,
    30 + g,
    'petugas' || g || '@contoh.id',
    'petugas' || g,
    'hash_petugas_' || g,
    true,
    CURRENT_DATE - ((300 + g * 11) || ' days')::interval
FROM generate_series(1, 24) AS g;

UPDATE cabang c
SET kepala_petugas_id = (
    SELECT MIN(p.petugas_id)
    FROM petugas p
    WHERE p.cabang_id = c.cabang_id
);

INSERT INTO spesialisasi (nama) VALUES
('Penyakit Dalam'),
('Anak'),
('Kebidanan dan Kandungan'),
('Bedah'),
('Saraf'),
('Jantung'),
('Kulit dan Kelamin'),
('Telinga Hidung Tenggorokan');

INSERT INTO dokter (
    nama_depan,
    nama_belakang,
    nomor_sip,
    email,
    alamat_id,
    aktif,
    tanggal_masuk
)
SELECT
    'Dokter',
    lpad(g::text, 3, '0'),
    'SIP-' || lpad(g::text, 5, '0'),
    'dokter' || g || '@contoh.id',
    80 + g,
    true,
    CURRENT_DATE - ((500 + g * 13) || ' days')::interval
FROM generate_series(1, 48) AS g;

INSERT INTO dokter_spesialisasi (
    dokter_id,
    spesialisasi_id
)
SELECT
    g,
    ((g - 1) % 8) + 1
FROM generate_series(1, 48) AS g;

INSERT INTO poli (
    nama_poli,
    cabang_id,
    aktif
)
SELECT
    CASE WHEN g % 2 = 1 THEN 'Poli Utama' ELSE 'Poli Lanjutan' END,
    ((g - 1) / 2) + 1,
    true
FROM generate_series(1, 16) AS g;

-- Dokter 1-30 hanya dijadwalkan pada cabang 1-5.
INSERT INTO jadwal_dokter (
    dokter_id,
    poli_id,
    hari,
    jam_mulai,
    jam_selesai,
    aktif
)
SELECT
    d,
    (((d - 1) % 5) * 2) + CASE WHEN d % 2 = 0 THEN 2 ELSE 1 END,
    (ARRAY['SENIN','SELASA','RABU','KAMIS','JUMAT','SABTU'])[((d - 1) % 6) + 1],
    time '08:00' + (((d - 1) % 4) || ' hours')::interval,
    time '12:00' + (((d - 1) % 4) || ' hours')::interval,
    true
FROM generate_series(1, 30) AS d;

-- Dokter 31-48 hanya dijadwalkan pada cabang 6-8.
INSERT INTO jadwal_dokter (
    dokter_id,
    poli_id,
    hari,
    jam_mulai,
    jam_selesai,
    aktif
)
SELECT
    d,
    ((6 + ((d - 31) % 3) - 1) * 2) + CASE WHEN d % 2 = 0 THEN 2 ELSE 1 END,
    (ARRAY['SENIN','SELASA','RABU','KAMIS','JUMAT','SABTU'])[((d - 1) % 6) + 1],
    time '08:00' + (((d - 1) % 4) || ' hours')::interval,
    time '12:00' + (((d - 1) % 4) || ' hours')::interval,
    true
FROM generate_series(31, 48) AS d;

INSERT INTO kategori_obat (nama) VALUES
('Analgesik'),
('Antibiotik'),
('Antihistamin'),
('Antipiretik'),
('Gastrointestinal'),
('Kardiovaskular'),
('Neurologi'),
('Dermatologi');

INSERT INTO obat (
    nama_obat,
    kategori_obat_id,
    harga,
    stok,
    aktif
)
SELECT
    'Obat ' || lpad(g::text, 3, '0'),
    ((g - 1) % 8) + 1,
    CASE
        WHEN g = 40 THEN 500000.00
        ELSE (12000 + (g % 20) * 3500)::numeric(14,2)
    END,
    1000 + g * 20,
    true
FROM generate_series(1, 64) AS g;

INSERT INTO pasien (
    nomor_rm,
    nama_depan,
    nama_belakang,
    tanggal_lahir,
    email,
    alamat_id,
    tanggal_daftar,
    aktif
)
SELECT
    'RM-' || lpad(g::text, 6, '0'),
    'Pasien',
    lpad(g::text, 4, '0'),
    date '1965-01-01' + ((g * 37) % 18000),
    'pasien' || g || '@contoh.id',
    200 + g,
    CURRENT_DATE - ((30 + (g % 1200)) || ' days')::interval,
    CASE WHEN g % 41 = 0 THEN false ELSE true END
FROM generate_series(1, 600) AS g;

-- ============================================================
-- 8. FUNGSI BANTU UNTUK DATA SEED
-- ============================================================

CREATE OR REPLACE FUNCTION seed_tambah_kunjungan(
    p_pasien_id          integer,
    p_jadwal_id          bigint,
    p_tanggal            timestamp,
    p_status             varchar,
    p_keluhan            text,
    p_jumlah_bayar       numeric,
    p_status_bayar       varchar,
    p_obat_id            integer,
    p_jumlah_obat        integer
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_kunjungan_id       bigint;
    v_rekam_medis_id     bigint;
    v_resep_id           bigint;
    v_dokter_id          integer;
    v_poli_id            integer;
    v_cabang_id          integer;
    v_petugas_id         integer;
BEGIN
    SELECT jd.dokter_id, jd.poli_id, p.cabang_id
    INTO v_dokter_id, v_poli_id, v_cabang_id
    FROM jadwal_dokter jd
    JOIN poli p ON p.poli_id = jd.poli_id
    WHERE jd.jadwal_id = p_jadwal_id;

    SELECT MIN(petugas_id)
    INTO v_petugas_id
    FROM petugas
    WHERE cabang_id = v_cabang_id;

    INSERT INTO kunjungan (
        pasien_id,
        jadwal_id,
        petugas_id,
        tanggal_kunjungan,
        keluhan,
        status
    )
    VALUES (
        p_pasien_id,
        p_jadwal_id,
        v_petugas_id,
        p_tanggal,
        p_keluhan,
        p_status
    )
    RETURNING kunjungan_id INTO v_kunjungan_id;

    IF p_status IN ('DIPERIKSA', 'SELESAI') THEN
        INSERT INTO rekam_medis (
            kunjungan_id,
            dokter_id,
            diagnosis,
            tindakan,
            catatan
        )
        VALUES (
            v_kunjungan_id,
            v_dokter_id,
            'Diagnosis simulasi untuk kunjungan ' || v_kunjungan_id,
            'Pemeriksaan dan terapi sesuai hasil evaluasi',
            'Data dibuat untuk latihan analisis OLAP'
        )
        RETURNING rekam_medis_id INTO v_rekam_medis_id;

        IF p_obat_id IS NOT NULL THEN
            INSERT INTO resep (
                rekam_medis_id,
                dokter_id,
                tanggal_resep,
                status
            )
            VALUES (
                v_rekam_medis_id,
                v_dokter_id,
                p_tanggal + interval '20 minutes',
                'DISERAHKAN'
            )
            RETURNING resep_id INTO v_resep_id;

            INSERT INTO detail_resep (
                resep_id,
                obat_id,
                jumlah,
                dosis,
                aturan_pakai
            )
            VALUES (
                v_resep_id,
                p_obat_id,
                p_jumlah_obat,
                '1 dosis',
                'Gunakan sesuai petunjuk dokter'
            );
        END IF;
    END IF;

    INSERT INTO pembayaran (
        kunjungan_id,
        pasien_id,
        petugas_id,
        jumlah,
        metode,
        tanggal_bayar,
        status
    )
    VALUES (
        v_kunjungan_id,
        p_pasien_id,
        v_petugas_id,
        p_jumlah_bayar,
        CASE (v_kunjungan_id % 5)
            WHEN 0 THEN 'TUNAI'
            WHEN 1 THEN 'TRANSFER'
            WHEN 2 THEN 'KARTU'
            WHEN 3 THEN 'ASURANSI'
            ELSE 'E_WALLET'
        END,
        p_tanggal + interval '1 hour',
        p_status_bayar
    );

    RETURN v_kunjungan_id;
END;
$$;

-- ============================================================
-- 9. DATA KUNJUNGAN 15 BULAN
-- ============================================================

DO $$
DECLARE
    v_month_start       date := (date_trunc('month', CURRENT_DATE)::date - interval '14 months')::date;
    v_visit_date        timestamp;
    v_jadwal_id         bigint;
    v_poli_id           integer;
    v_cabang_id         integer;
    v_status            varchar(20);
    v_payment_status    varchar(20);
    v_payment           numeric(16,2);
    v_patient           integer;
    v_obat              integer;
    v_count             integer;
    v_day               integer;
    m                   integer;
    d                   integer;
    j                   integer;
    s                   integer;
    c                   integer;
    p                   integer;
    follow_month        integer;
BEGIN
    -- --------------------------------------------------------
    -- A. Aktivitas dasar setiap dokter setiap bulan.
    --    Setiap spesialisasi memiliki 6 dokter aktif.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR d IN 1..48 LOOP
            SELECT jd.jadwal_id, jd.poli_id, po.cabang_id
            INTO v_jadwal_id, v_poli_id, v_cabang_id
            FROM jadwal_dokter jd
            JOIN poli po ON po.poli_id = jd.poli_id
            WHERE jd.dokter_id = d
            ORDER BY jd.jadwal_id
            LIMIT 1;

            -- Cabang 8 tidak memiliki transaksi pada bulan 5 dan 10.
            IF v_cabang_id = 8 AND m IN (4, 9) THEN
                CONTINUE;
            END IF;

            v_count := 2 + ((d + m) % 3);

            FOR j IN 1..v_count LOOP
                v_patient := 241 + ((d * 17 + m * 29 + j * 7) % 360);
                v_day := CASE
                    WHEN m = 14 THEN 1
                    ELSE 2 + ((d * 3 + m + j * 5) % 24)
                END;

                v_visit_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((v_day - 1) || ' days')::interval
                    + ((8 + (j % 8)) || ' hours')::interval;

                IF v_poli_id = 1 THEN
                    v_status := 'SELESAI';
                ELSIF (d + m + j) % 17 = 0 THEN
                    v_status := 'DIBATALKAN';
                ELSIF (d + m + j) % 13 = 0 THEN
                    v_status := 'DIPERIKSA';
                ELSE
                    v_status := 'SELESAI';
                END IF;

                v_payment_status := CASE
                    WHEN v_status = 'DIBATALKAN' THEN 'GAGAL'
                    ELSE 'BERHASIL'
                END;

                v_payment := CASE
                    WHEN v_payment_status = 'GAGAL' THEN 0
                    WHEN v_cabang_id <= 5
                        THEN 180000 + v_cabang_id * 45000 + ((d + j) % 4) * 25000
                    ELSE 110000 + (v_cabang_id - 5) * 20000 + ((d + j) % 3) * 15000
                END;

                v_obat := CASE
                    WHEN v_status = 'DIBATALKAN' THEN NULL
                    ELSE 1 + ((d + m + j) % 39)
                END;

                PERFORM seed_tambah_kunjungan(
                    v_patient,
                    v_jadwal_id,
                    v_visit_date,
                    v_status,
                    'Keluhan umum pasien',
                    v_payment,
                    v_payment_status,
                    v_obat,
                    1 + ((d + j) % 3)
                );
            END LOOP;
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- B. Dokter unggulan tiap spesialisasi.
    --    Dokter 1-8 mendapat tambahan aktivitas setiap bulan,
    --    sehingga analisis persentil memiliki pola yang jelas.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR s IN 1..8 LOOP
            d := s;

            SELECT jd.jadwal_id, jd.poli_id, po.cabang_id
            INTO v_jadwal_id, v_poli_id, v_cabang_id
            FROM jadwal_dokter jd
            JOIN poli po ON po.poli_id = jd.poli_id
            WHERE jd.dokter_id = d
            ORDER BY jd.jadwal_id
            LIMIT 1;

            FOR j IN 1..4 LOOP
                v_patient := 300 + ((s * 31 + m * 11 + j * 9) % 290);
                v_day := CASE
                    WHEN m = 14 THEN 1
                    ELSE 3 + ((s * 2 + j * 4 + m) % 23)
                END;

                v_visit_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((v_day - 1) || ' days')::interval
                    + interval '15 hours';

                PERFORM seed_tambah_kunjungan(
                    v_patient,
                    v_jadwal_id,
                    v_visit_date,
                    'SELESAI',
                    'Kontrol lanjutan',
                    260000 + s * 15000,
                    'BERHASIL',
                    1 + ((s + m + j) % 20),
                    2
                );
            END LOOP;
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- C. Cohort pasien berdasarkan bulan kunjungan pertama.
    --    8 cohort, masing-masing 30 pasien.
    --    Retensi M1, M2, dan M3 dibuat berbeda antar-cohort.
    -- --------------------------------------------------------
    SELECT jadwal_id
    INTO v_jadwal_id
    FROM jadwal_dokter
    WHERE dokter_id = 1
    ORDER BY jadwal_id
    LIMIT 1;

    FOR c IN 0..7 LOOP
        FOR p IN 1..30 LOOP
            v_patient := c * 30 + p;
            v_day := CASE WHEN c = 7 AND c = 14 THEN 1 ELSE 4 + (p % 20) END;

            v_visit_date :=
                v_month_start
                + (c || ' months')::interval
                + (((4 + (p % 20)) - 1) || ' days')::interval
                + interval '10 hours';

            PERFORM seed_tambah_kunjungan(
                v_patient,
                v_jadwal_id,
                v_visit_date,
                'SELESAI',
                'Kunjungan pertama cohort',
                300000 + c * 10000,
                'BERHASIL',
                1 + ((c + p) % 15),
                1
            );

            -- Retensi bulan pertama.
            IF p <= (20 + (c % 6)) THEN
                follow_month := c + 1;
                v_visit_date :=
                    v_month_start
                    + (follow_month || ' months')::interval
                    + (((5 + (p % 18)) - 1) || ' days')::interval
                    + interval '11 hours';

                PERFORM seed_tambah_kunjungan(
                    v_patient,
                    v_jadwal_id,
                    v_visit_date,
                    'SELESAI',
                    'Kontrol bulan pertama',
                    285000,
                    'BERHASIL',
                    2 + ((c + p) % 15),
                    1
                );
            END IF;

            -- Retensi bulan kedua.
            IF p <= (15 + (c % 5)) THEN
                follow_month := c + 2;
                v_visit_date :=
                    v_month_start
                    + (follow_month || ' months')::interval
                    + (((6 + (p % 17)) - 1) || ' days')::interval
                    + interval '12 hours';

                PERFORM seed_tambah_kunjungan(
                    v_patient,
                    v_jadwal_id,
                    v_visit_date,
                    'SELESAI',
                    'Kontrol bulan kedua',
                    275000,
                    'BERHASIL',
                    3 + ((c + p) % 15),
                    1
                );
            END IF;

            -- Retensi bulan ketiga.
            IF p <= (10 + (c % 4)) THEN
                follow_month := c + 3;
                v_visit_date :=
                    v_month_start
                    + (follow_month || ' months')::interval
                    + (((7 + (p % 16)) - 1) || ' days')::interval
                    + interval '13 hours';

                PERFORM seed_tambah_kunjungan(
                    v_patient,
                    v_jadwal_id,
                    v_visit_date,
                    'SELESAI',
                    'Kontrol bulan ketiga',
                    265000,
                    'BERHASIL',
                    4 + ((c + p) % 15),
                    1
                );
            END IF;
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- D. Pasien 1-10 menjadi pasien dengan pembayaran terbesar.
    --    Obat 40 tidak pernah diresepkan kepada mereka.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR p IN 1..10 LOOP
            SELECT jadwal_id
            INTO v_jadwal_id
            FROM jadwal_dokter
            WHERE dokter_id = 2
            ORDER BY jadwal_id
            LIMIT 1;

            v_visit_date :=
                v_month_start
                + (m || ' months')::interval
                + (((2 + p) - 1) || ' days')::interval
                + interval '17 hours';

            PERFORM seed_tambah_kunjungan(
                p,
                v_jadwal_id,
                v_visit_date,
                'SELESAI',
                'Pemeriksaan eksekutif',
                5000000 + p * 100000,
                'BERHASIL',
                1 + ((p + m) % 10),
                2
            );
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- E. Obat 40 memiliki estimasi pendapatan resep tinggi,
    --    tetapi hanya diberikan kepada pasien selain 1-10.
    --    Dokter 31 juga mendapat volume kunjungan tinggi dan
    --    hanya berpraktik di cabang 6-8.
    -- --------------------------------------------------------
    SELECT jadwal_id
    INTO v_jadwal_id
    FROM jadwal_dokter
    WHERE dokter_id = 31
    ORDER BY jadwal_id
    LIMIT 1;

    FOR m IN 0..14 LOOP
        FOR j IN 1..12 LOOP
            v_patient := 100 + ((m * 23 + j * 19) % 480);
            IF v_patient <= 10 THEN
                v_patient := v_patient + 20;
            END IF;

            v_day := CASE
                WHEN m = 14 THEN 1
                ELSE 2 + ((j * 2 + m) % 24)
            END;

            v_visit_date :=
                v_month_start
                + (m || ' months')::interval
                + ((v_day - 1) || ' days')::interval
                + interval '16 hours';

            PERFORM seed_tambah_kunjungan(
                v_patient,
                v_jadwal_id,
                v_visit_date,
                'SELESAI',
                'Terapi khusus',
                190000,
                'BERHASIL',
                40,
                5
            );
        END LOOP;
    END LOOP;
END;
$$;

DROP FUNCTION seed_tambah_kunjungan(
    integer,
    bigint,
    timestamp,
    varchar,
    text,
    numeric,
    varchar,
    integer,
    integer
);

ANALYZE;

-- ============================================================
-- 10. RINGKASAN POLA DATA
-- ============================================================
-- Tabel utama:
--   cabang               : 8 cabang
--   poli                 : 16 poli
--   dokter               : 48 dokter
--   spesialisasi         : 8 spesialisasi
--   pasien               : 600 pasien
--   obat                 : 64 obat
--   periode transaksi    : 15 bulan
--
-- Pola analitik:
--   * Setiap spesialisasi memiliki 6 dokter aktif.
--   * Dokter 1-8 konsisten memiliki kunjungan lebih tinggi.
--   * Dokter 31 memiliki banyak kunjungan tetapi hanya berjadwal
--     di cabang 6-8.
--   * Cabang 1-5 memiliki nilai pembayaran lebih tinggi.
--   * Cabang 8 tidak memiliki transaksi pada dua bulan tertentu.
--   * Pasien 1-10 memiliki total pembayaran sangat tinggi.
--   * Obat 40 memiliki estimasi pendapatan resep sangat tinggi,
--     tetapi tidak pernah diresepkan kepada pasien 1-10.
--   * Terdapat 8 cohort pasien, masing-masing 30 pasien, dengan
--     pola retensi bulan pertama, kedua, dan ketiga.
--
-- Filter transaksi valid yang disarankan:
--   kunjungan.status = 'SELESAI'
--   pembayaran.status = 'BERHASIL'
--   resep.status = 'DISERAHKAN'
-- ============================================================
