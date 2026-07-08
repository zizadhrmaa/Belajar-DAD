-- ============================================================
-- SKEMA 4: SISTEM AKADEMIK PERGURUAN TINGGI
-- PostgreSQL
--
-- Tujuan data:
-- 1. Mendukung seluruh 7 soal OLAP pada Skema 4.
-- 2. Menyediakan data multi-kampus, fakultas, program studi,
--    mata kuliah, dosen, mahasiswa, kelas, KRS, nilai, dan UKT.
-- 3. Menyediakan pola khusus untuk ranking, NOT EXISTS,
--    pertumbuhan antarperiode, moving average, persentil,
--    dan analisis cohort tiga semester.
--
-- Jalankan seluruh file ini pada database PostgreSQL.
-- ============================================================

DROP SCHEMA IF EXISTS akademik_perguruan_tinggi CASCADE;
CREATE SCHEMA akademik_perguruan_tinggi;
SET search_path TO akademik_perguruan_tinggi, public;

-- ============================================================
-- 1. TABEL WILAYAH DAN KAMPUS
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

CREATE TABLE kampus (
    kampus_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_kampus        varchar(120) NOT NULL UNIQUE,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE gedung (
    gedung_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kampus_id          integer NOT NULL REFERENCES kampus(kampus_id),
    nama_gedung        varchar(120) NOT NULL,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (kampus_id, nama_gedung)
);

CREATE TABLE ruangan (
    ruangan_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gedung_id          integer NOT NULL REFERENCES gedung(gedung_id),
    nama_ruangan       varchar(80) NOT NULL,
    kapasitas          integer NOT NULL CHECK (kapasitas > 0),
    jenis_ruangan      varchar(30) NOT NULL
                       CHECK (jenis_ruangan IN ('KELAS','LABORATORIUM','STUDIO','AUDITORIUM')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (gedung_id, nama_ruangan)
);

-- ============================================================
-- 2. TABEL DOSEN, FAKULTAS, DAN PROGRAM STUDI
-- ============================================================

CREATE TABLE dosen (
    dosen_id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nidn               varchar(30) NOT NULL UNIQUE,
    nama_depan         varchar(80) NOT NULL,
    nama_belakang      varchar(80) NOT NULL,
    email              varchar(150) NOT NULL UNIQUE,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    aktif              boolean NOT NULL DEFAULT true,
    tanggal_masuk      date NOT NULL,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fakultas (
    fakultas_id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_fakultas      varchar(150) NOT NULL UNIQUE,
    dekan_dosen_id     integer REFERENCES dosen(dosen_id),
    kampus_id          integer NOT NULL REFERENCES kampus(kampus_id),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE program_studi (
    prodi_id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fakultas_id        integer NOT NULL REFERENCES fakultas(fakultas_id),
    nama_prodi         varchar(150) NOT NULL UNIQUE,
    jenjang            varchar(10) NOT NULL
                       CHECK (jenjang IN ('D3','D4','S1','S2','S3')),
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 3. TABEL MATA KULIAH DAN PERIODE
-- ============================================================

CREATE TABLE mata_kuliah (
    mata_kuliah_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    prodi_id               integer NOT NULL REFERENCES program_studi(prodi_id),
    kode                   varchar(20) NOT NULL UNIQUE,
    nama                   varchar(150) NOT NULL,
    sks                    integer NOT NULL CHECK (sks BETWEEN 1 AND 6),
    semester_rekomendasi   integer NOT NULL CHECK (semester_rekomendasi BETWEEN 1 AND 14),
    aktif                  boolean NOT NULL DEFAULT true,
    last_update            timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (prodi_id, nama)
);

CREATE TABLE mata_kuliah_prasyarat (
    mata_kuliah_id     integer NOT NULL REFERENCES mata_kuliah(mata_kuliah_id),
    prasyarat_id       integer NOT NULL REFERENCES mata_kuliah(mata_kuliah_id),
    nilai_minimum      numeric(5,2) NOT NULL CHECK (nilai_minimum BETWEEN 0 AND 100),
    PRIMARY KEY (mata_kuliah_id, prasyarat_id),
    CHECK (mata_kuliah_id <> prasyarat_id)
);

CREATE TABLE dosen_mata_kuliah (
    dosen_id           integer NOT NULL REFERENCES dosen(dosen_id),
    mata_kuliah_id     integer NOT NULL REFERENCES mata_kuliah(mata_kuliah_id),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (dosen_id, mata_kuliah_id)
);

CREATE TABLE periode_akademik (
    periode_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tahun_ajaran       varchar(20) NOT NULL,
    semester           varchar(10) NOT NULL
                       CHECK (semester IN ('GANJIL','GENAP')),
    tanggal_mulai      date NOT NULL,
    tanggal_selesai    date NOT NULL,
    aktif              boolean NOT NULL DEFAULT false,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tahun_ajaran, semester),
    CHECK (tanggal_selesai > tanggal_mulai)
);

-- ============================================================
-- 4. TABEL KELAS DAN JADWAL
-- ============================================================

CREATE TABLE kelas_kuliah (
    kelas_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mata_kuliah_id     integer NOT NULL REFERENCES mata_kuliah(mata_kuliah_id),
    dosen_id           integer NOT NULL REFERENCES dosen(dosen_id),
    periode_id         integer NOT NULL REFERENCES periode_akademik(periode_id),
    ruangan_id         integer NOT NULL REFERENCES ruangan(ruangan_id),
    nama_kelas         varchar(20) NOT NULL,
    kapasitas          integer NOT NULL CHECK (kapasitas > 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (mata_kuliah_id, periode_id, nama_kelas)
);

CREATE TABLE jadwal_kuliah (
    jadwal_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kelas_id           bigint NOT NULL UNIQUE REFERENCES kelas_kuliah(kelas_id),
    hari               varchar(10) NOT NULL
                       CHECK (hari IN ('SENIN','SELASA','RABU','KAMIS','JUMAT','SABTU')),
    jam_mulai          time NOT NULL,
    jam_selesai        time NOT NULL,
    CHECK (jam_selesai > jam_mulai)
);

-- ============================================================
-- 5. TABEL MAHASISWA, KRS, NILAI, DAN UKT
-- ============================================================

CREATE TABLE mahasiswa (
    mahasiswa_id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nim                varchar(30) NOT NULL UNIQUE,
    prodi_id           integer NOT NULL REFERENCES program_studi(prodi_id),
    nama_depan         varchar(80) NOT NULL,
    nama_belakang      varchar(80) NOT NULL,
    email              varchar(150) NOT NULL UNIQUE,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    angkatan           integer NOT NULL CHECK (angkatan BETWEEN 2000 AND 2100),
    tanggal_masuk      date NOT NULL,
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE krs (
    krs_id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mahasiswa_id       integer NOT NULL REFERENCES mahasiswa(mahasiswa_id),
    kelas_id           bigint NOT NULL REFERENCES kelas_kuliah(kelas_id),
    tanggal_ambil      timestamp NOT NULL,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('DIAJUKAN','DISETUJUI','DIBATALKAN')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (mahasiswa_id, kelas_id)
);

CREATE TABLE nilai (
    nilai_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    krs_id             bigint NOT NULL UNIQUE REFERENCES krs(krs_id),
    nilai_tugas        numeric(5,2) NOT NULL CHECK (nilai_tugas BETWEEN 0 AND 100),
    nilai_uts          numeric(5,2) NOT NULL CHECK (nilai_uts BETWEEN 0 AND 100),
    nilai_uas          numeric(5,2) NOT NULL CHECK (nilai_uas BETWEEN 0 AND 100),
    nilai_akhir        numeric(5,2) NOT NULL CHECK (nilai_akhir BETWEEN 0 AND 100),
    nilai_huruf        varchar(2) NOT NULL
                       CHECK (nilai_huruf IN ('A','AB','B','BC','C','D','E')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pembayaran_ukt (
    pembayaran_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mahasiswa_id       integer NOT NULL REFERENCES mahasiswa(mahasiswa_id),
    periode_id         integer NOT NULL REFERENCES periode_akademik(periode_id),
    jumlah             numeric(16,2) NOT NULL CHECK (jumlah >= 0),
    tanggal_bayar      timestamp NOT NULL,
    metode             varchar(30) NOT NULL
                       CHECK (metode IN ('TRANSFER','VIRTUAL_ACCOUNT','KARTU','E_WALLET')),
    status             varchar(20) NOT NULL
                       CHECK (status IN ('MENUNGGU','BERHASIL','GAGAL','DIKEMBALIKAN')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (mahasiswa_id, periode_id)
);

-- ============================================================
-- 6. INDEKS UNTUK ANALISIS OLAP
-- ============================================================

CREATE INDEX idx_mahasiswa_prodi_aktif
    ON mahasiswa(prodi_id, aktif);

CREATE INDEX idx_mahasiswa_angkatan
    ON mahasiswa(angkatan, mahasiswa_id);

CREATE INDEX idx_mata_kuliah_prodi
    ON mata_kuliah(prodi_id, mata_kuliah_id);

CREATE INDEX idx_kelas_periode_mk
    ON kelas_kuliah(periode_id, mata_kuliah_id);

CREATE INDEX idx_kelas_dosen_periode
    ON kelas_kuliah(dosen_id, periode_id);

CREATE INDEX idx_krs_mahasiswa
    ON krs(mahasiswa_id, kelas_id);

CREATE INDEX idx_krs_kelas_status
    ON krs(kelas_id, status);

CREATE INDEX idx_nilai_krs
    ON nilai(krs_id, nilai_akhir);

CREATE INDEX idx_pembayaran_ukt_mahasiswa
    ON pembayaran_ukt(mahasiswa_id, status);

CREATE INDEX idx_pembayaran_ukt_periode
    ON pembayaran_ukt(periode_id, status);

-- ============================================================
-- 7. DATA MASTER WILAYAH DAN KAMPUS
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
('Jakarta Pusat', 3),
('Bandung', 4),
('Bogor', 4),
('Surabaya', 5),
('Malang', 5);

INSERT INTO alamat (
    alamat,
    kecamatan,
    kota_id,
    kode_pos,
    telepon
)
SELECT
    'Jalan Pendidikan Nomor ' || g,
    'Kecamatan ' || ((g - 1) % 30 + 1),
    ((g - 1) % 8) + 1,
    lpad((12000 + g)::text, 5, '0'),
    '08' || lpad((3000000000 + g)::text, 10, '0')
FROM generate_series(1, 1100) AS g;

INSERT INTO kampus (nama_kampus, alamat_id) VALUES
('Kampus Utama', 1),
('Kampus Barat', 2),
('Kampus Timur', 3);

INSERT INTO gedung (kampus_id, nama_gedung, alamat_id)
SELECT
    ((g - 1) % 3) + 1,
    'Gedung ' || chr(64 + g),
    10 + g
FROM generate_series(1, 9) AS g;

INSERT INTO ruangan (
    gedung_id,
    nama_ruangan,
    kapasitas,
    jenis_ruangan
)
SELECT
    ((g - 1) % 9) + 1,
    'Ruang ' || lpad(g::text, 3, '0'),
    CASE WHEN g % 5 = 0 THEN 200 ELSE 120 END,
    CASE
        WHEN g % 7 = 0 THEN 'LABORATORIUM'
        WHEN g % 11 = 0 THEN 'STUDIO'
        ELSE 'KELAS'
    END
FROM generate_series(1, 72) AS g;

-- ============================================================
-- 8. DATA DOSEN, FAKULTAS, PROGRAM STUDI, DAN MATA KULIAH
-- ============================================================

INSERT INTO dosen (
    nidn,
    nama_depan,
    nama_belakang,
    email,
    alamat_id,
    aktif,
    tanggal_masuk
)
SELECT
    'NIDN-' || lpad(g::text, 6, '0'),
    'Dosen',
    lpad(g::text, 3, '0'),
    'dosen' || g || '@kampus.ac.id',
    100 + g,
    true,
    date '2012-01-01' + ((g * 71) % 4000)
FROM generate_series(1, 80) AS g;

INSERT INTO fakultas (
    nama_fakultas,
    dekan_dosen_id,
    kampus_id
) VALUES
('Fakultas Teknologi Informasi', 1, 1),
('Fakultas Ekonomi dan Bisnis', 9, 1),
('Fakultas Ilmu Sosial', 17, 2),
('Fakultas Sains Terapan', 25, 2);

INSERT INTO program_studi (
    fakultas_id,
    nama_prodi,
    jenjang
) VALUES
(1, 'Informatika', 'S1'),
(1, 'Sistem Informasi', 'S1'),
(2, 'Manajemen', 'S1'),
(2, 'Akuntansi', 'S1'),
(3, 'Ilmu Komunikasi', 'S1'),
(3, 'Administrasi Publik', 'S1'),
(4, 'Statistika Terapan', 'S1'),
(4, 'Teknologi Pangan', 'S1');

INSERT INTO mata_kuliah (
    prodi_id,
    kode,
    nama,
    sks,
    semester_rekomendasi,
    aktif
)
SELECT
    p,
    'MK' || lpad(((p - 1) * 8 + c)::text, 3, '0'),
    'Mata Kuliah ' || lpad(((p - 1) * 8 + c)::text, 3, '0'),
    2 + (c % 3),
    c,
    true
FROM generate_series(1, 8) AS p
CROSS JOIN generate_series(1, 8) AS c;

INSERT INTO mata_kuliah_prasyarat (
    mata_kuliah_id,
    prasyarat_id,
    nilai_minimum
)
SELECT
    ((p - 1) * 8 + c),
    ((p - 1) * 8 + c - 1),
    60
FROM generate_series(1, 8) AS p
CROSS JOIN generate_series(2, 8) AS c;

-- Dosen untuk prodi 1-5 menggunakan dosen 1-40.
-- Prodi 6-7 menggunakan dosen 41-56.
-- Semua mata kuliah prodi 8 ditangani dosen 70.
INSERT INTO dosen_mata_kuliah (dosen_id, mata_kuliah_id)
SELECT
    CASE
        WHEN mk.prodi_id = 8 THEN 70
        ELSE ((mk.prodi_id - 1) * 8) + ((mk.mata_kuliah_id - 1) % 8) + 1
    END,
    mk.mata_kuliah_id
FROM mata_kuliah mk;

-- ============================================================
-- 9. DATA PERIODE AKADEMIK
-- ============================================================

INSERT INTO periode_akademik (
    tahun_ajaran,
    semester,
    tanggal_mulai,
    tanggal_selesai,
    aktif
) VALUES
('2022/2023', 'GANJIL', date '2022-08-01', date '2023-01-15', false),
('2022/2023', 'GENAP',  date '2023-02-01', date '2023-07-15', false),
('2023/2024', 'GANJIL', date '2023-08-01', date '2024-01-15', false),
('2023/2024', 'GENAP',  date '2024-02-01', date '2024-07-15', false),
('2024/2025', 'GANJIL', date '2024-08-01', date '2025-01-15', false),
('2024/2025', 'GENAP',  date '2025-02-01', date '2025-07-15', false),
('2025/2026', 'GANJIL', date '2025-08-01', date '2026-01-15', false),
('2025/2026', 'GENAP',  date '2026-02-01', date '2026-07-31', true);

-- ============================================================
-- 10. DATA KELAS DAN JADWAL
-- ============================================================

INSERT INTO kelas_kuliah (
    mata_kuliah_id,
    dosen_id,
    periode_id,
    ruangan_id,
    nama_kelas,
    kapasitas
)
SELECT
    mk.mata_kuliah_id,
    dmk.dosen_id,
    pa.periode_id,
    1 + ((mk.mata_kuliah_id + pa.periode_id - 2) % 72),
    'A',
    200
FROM mata_kuliah mk
JOIN dosen_mata_kuliah dmk
  ON dmk.mata_kuliah_id = mk.mata_kuliah_id
CROSS JOIN periode_akademik pa;

INSERT INTO jadwal_kuliah (
    kelas_id,
    hari,
    jam_mulai,
    jam_selesai
)
SELECT
    kk.kelas_id,
    (ARRAY['SENIN','SELASA','RABU','KAMIS','JUMAT','SABTU'])
        [((kk.mata_kuliah_id + kk.periode_id - 2) % 6) + 1],
    time '08:00' + (((kk.mata_kuliah_id - 1) % 5) || ' hours')::interval,
    time '10:00' + (((kk.mata_kuliah_id - 1) % 5) || ' hours')::interval
FROM kelas_kuliah kk;

-- ============================================================
-- 11. DATA MAHASISWA
-- ============================================================

INSERT INTO mahasiswa (
    nim,
    prodi_id,
    nama_depan,
    nama_belakang,
    email,
    alamat_id,
    angkatan,
    tanggal_masuk,
    aktif
)
SELECT
    'MHS' || lpad((((p - 1) * 100) + n)::text, 7, '0'),
    p,
    'Mahasiswa',
    lpad((((p - 1) * 100) + n)::text, 4, '0'),
    'mahasiswa' || (((p - 1) * 100) + n) || '@student.ac.id',
    200 + (((p - 1) * 100) + n),
    CASE
        WHEN n <= 25 THEN 2022
        WHEN n <= 50 THEN 2023
        WHEN n <= 75 THEN 2024
        ELSE 2025
    END,
    CASE
        WHEN n <= 25 THEN date '2022-08-01'
        WHEN n <= 50 THEN date '2023-08-01'
        WHEN n <= 75 THEN date '2024-08-01'
        ELSE date '2025-08-01'
    END,
    CASE
        WHEN p <= 5 THEN n <= 95
        ELSE n <= 75
    END
FROM generate_series(1, 8) AS p
CROSS JOIN generate_series(1, 100) AS n;

-- ============================================================
-- 12. DATA PEMBAYARAN UKT
-- ============================================================

DO $$
DECLARE
    r                   record;
    v_start_period      integer;
    v_amount            numeric(16,2);
    v_pay_date          timestamp;
BEGIN
    FOR r IN
        SELECT
            m.mahasiswa_id,
            m.prodi_id,
            m.angkatan,
            ((m.mahasiswa_id - 1) % 100) + 1 AS local_no
        FROM mahasiswa m
        ORDER BY m.mahasiswa_id
    LOOP
        v_start_period := CASE r.angkatan
            WHEN 2022 THEN 1
            WHEN 2023 THEN 3
            WHEN 2024 THEN 5
            ELSE 7
        END;

        FOR p IN v_start_period..8 LOOP
            v_amount := CASE
                WHEN r.mahasiswa_id BETWEEN 1 AND 10
                    THEN 25000000 + r.mahasiswa_id * 250000
                WHEN r.prodi_id = 8
                    THEN 9500000 + (r.local_no % 5) * 150000
                WHEN r.prodi_id IN (6, 7)
                    THEN 7500000 + (r.local_no % 5) * 125000
                ELSE 6000000 + (r.local_no % 5) * 100000
            END;

            SELECT pa.tanggal_mulai::timestamp + interval '10 days'
            INTO v_pay_date
            FROM periode_akademik pa
            WHERE pa.periode_id = p;

            INSERT INTO pembayaran_ukt (
                mahasiswa_id,
                periode_id,
                jumlah,
                tanggal_bayar,
                metode,
                status
            )
            VALUES (
                r.mahasiswa_id,
                p,
                v_amount,
                v_pay_date + ((r.mahasiswa_id % 12) || ' hours')::interval,
                CASE (r.mahasiswa_id + p) % 4
                    WHEN 0 THEN 'TRANSFER'
                    WHEN 1 THEN 'VIRTUAL_ACCOUNT'
                    WHEN 2 THEN 'KARTU'
                    ELSE 'E_WALLET'
                END,
                'BERHASIL'
            );
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 13. DATA KRS DAN NILAI
-- ============================================================

DO $$
DECLARE
    r                   record;
    v_start_period      integer;
    v_semester_index    integer;
    v_course_position   integer;
    v_course_id         integer;
    v_class_id          bigint;
    v_krs_id            bigint;
    v_score             numeric(5,2);
    v_task              numeric(5,2);
    v_mid               numeric(5,2);
    v_final_exam        numeric(5,2);
    v_letter            varchar(2);
    v_cohort_rank       integer;
    v_pass_limit        integer;
    v_fail_semester     boolean;
BEGIN
    FOR r IN
        SELECT
            m.mahasiswa_id,
            m.prodi_id,
            m.angkatan,
            ((m.mahasiswa_id - 1) % 100) + 1 AS local_no
        FROM mahasiswa m
        ORDER BY m.mahasiswa_id
    LOOP
        v_start_period := CASE r.angkatan
            WHEN 2022 THEN 1
            WHEN 2023 THEN 3
            WHEN 2024 THEN 5
            ELSE 7
        END;

        v_cohort_rank :=
            (r.prodi_id - 1) * 25
            + ((r.local_no - 1) % 25)
            + 1;

        FOR p IN v_start_period..8 LOOP
            -- Prodi 8 sengaja tidak memiliki pengambilan reguler
            -- pada periode 4, agar analisis periode nol dapat diuji.
            IF r.prodi_id = 8 AND p = 4 THEN
                CONTINUE;
            END IF;

            v_semester_index := p - v_start_period + 1;

            v_pass_limit := CASE
                WHEN r.angkatan = 2022 AND v_semester_index = 1 THEN 170
                WHEN r.angkatan = 2022 AND v_semester_index = 2 THEN 150
                WHEN r.angkatan = 2022 AND v_semester_index = 3 THEN 130
                WHEN r.angkatan = 2023 AND v_semester_index = 1 THEN 175
                WHEN r.angkatan = 2023 AND v_semester_index = 2 THEN 155
                WHEN r.angkatan = 2023 AND v_semester_index = 3 THEN 135
                WHEN r.angkatan = 2024 AND v_semester_index = 1 THEN 180
                WHEN r.angkatan = 2024 AND v_semester_index = 2 THEN 160
                WHEN r.angkatan = 2024 AND v_semester_index = 3 THEN 140
                ELSE 200
            END;

            v_fail_semester :=
                v_semester_index <= 3
                AND v_cohort_rank > v_pass_limit;

            FOR k IN 0..2 LOOP
                v_course_position :=
                    1 + ((r.local_no + p + k - 2) % 8);

                v_course_id :=
                    ((r.prodi_id - 1) * 8) + v_course_position;

                SELECT kk.kelas_id
                INTO v_class_id
                FROM kelas_kuliah kk
                WHERE kk.mata_kuliah_id = v_course_id
                  AND kk.periode_id = p
                  AND kk.nama_kelas = 'A';

                INSERT INTO krs (
                    mahasiswa_id,
                    kelas_id,
                    tanggal_ambil,
                    status
                )
                SELECT
                    r.mahasiswa_id,
                    v_class_id,
                    pa.tanggal_mulai::timestamp
                        + interval '3 days'
                        + ((r.mahasiswa_id % 10) || ' hours')::interval,
                    'DISETUJUI'
                FROM periode_akademik pa
                WHERE pa.periode_id = p
                ON CONFLICT (mahasiswa_id, kelas_id) DO NOTHING
                RETURNING krs_id INTO v_krs_id;

                IF v_krs_id IS NULL THEN
                    SELECT krs_id
                    INTO v_krs_id
                    FROM krs
                    WHERE mahasiswa_id = r.mahasiswa_id
                      AND kelas_id = v_class_id;
                END IF;

                IF v_fail_semester AND k = 0 THEN
                    v_score := 55;
                ELSE
                    v_score :=
                        greatest(
                            60,
                            least(
                                98,
                                92
                                - (v_course_position - 1) * 4
                                + ((r.mahasiswa_id + p + k) % 5)
                                - 2
                            )
                        );
                END IF;

                v_task := least(100, v_score + 4);
                v_mid := greatest(0, v_score - 2);
                v_final_exam := greatest(0, v_score - 1);

                v_letter := CASE
                    WHEN v_score >= 85 THEN 'A'
                    WHEN v_score >= 80 THEN 'AB'
                    WHEN v_score >= 75 THEN 'B'
                    WHEN v_score >= 70 THEN 'BC'
                    WHEN v_score >= 60 THEN 'C'
                    WHEN v_score >= 50 THEN 'D'
                    ELSE 'E'
                END;

                INSERT INTO nilai (
                    krs_id,
                    nilai_tugas,
                    nilai_uts,
                    nilai_uas,
                    nilai_akhir,
                    nilai_huruf
                )
                VALUES (
                    v_krs_id,
                    v_task,
                    v_mid,
                    v_final_exam,
                    v_score,
                    v_letter
                )
                ON CONFLICT (krs_id) DO NOTHING;

                v_krs_id := NULL;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 14. PENGAYAAN DATA UNTUK MATA KULIAH 64
-- ============================================================
-- Mata kuliah 64 berada di prodi 8, diajar dosen 70, dan diambil
-- oleh hampir seluruh mahasiswa prodi 8 pada seluruh periode
-- setelah mereka masuk. Mahasiswa 1-10 tidak mungkin mengambilnya.
-- Pola ini mendukung soal pendapatan UKT dan dosen yang mengajar
-- mahasiswa terbanyak di luar lima prodi terbesar.

DO $$
DECLARE
    r                   record;
    v_start_period      integer;
    v_class_id          bigint;
    v_krs_id            bigint;
    v_score             numeric(5,2);
BEGIN
    FOR r IN
        SELECT
            mahasiswa_id,
            angkatan
        FROM mahasiswa
        WHERE prodi_id = 8
        ORDER BY mahasiswa_id
    LOOP
        v_start_period := CASE r.angkatan
            WHEN 2022 THEN 1
            WHEN 2023 THEN 3
            WHEN 2024 THEN 5
            ELSE 7
        END;

        FOR p IN v_start_period..8 LOOP
            IF p = 4 THEN
                CONTINUE;
            END IF;

            SELECT kelas_id
            INTO v_class_id
            FROM kelas_kuliah
            WHERE mata_kuliah_id = 64
              AND periode_id = p
              AND nama_kelas = 'A';

            INSERT INTO krs (
                mahasiswa_id,
                kelas_id,
                tanggal_ambil,
                status
            )
            SELECT
                r.mahasiswa_id,
                v_class_id,
                pa.tanggal_mulai::timestamp + interval '5 days',
                'DISETUJUI'
            FROM periode_akademik pa
            WHERE pa.periode_id = p
            ON CONFLICT (mahasiswa_id, kelas_id) DO NOTHING
            RETURNING krs_id INTO v_krs_id;

            IF v_krs_id IS NULL THEN
                SELECT krs_id
                INTO v_krs_id
                FROM krs
                WHERE mahasiswa_id = r.mahasiswa_id
                  AND kelas_id = v_class_id;
            END IF;

            v_score := 88 + ((r.mahasiswa_id + p) % 4);

            INSERT INTO nilai (
                krs_id,
                nilai_tugas,
                nilai_uts,
                nilai_uas,
                nilai_akhir,
                nilai_huruf
            )
            VALUES (
                v_krs_id,
                least(100, v_score + 4),
                v_score - 2,
                v_score - 1,
                v_score,
                'A'
            )
            ON CONFLICT (krs_id) DO NOTHING;

            v_krs_id := NULL;
        END LOOP;
    END LOOP;
END $$;

-- ============================================================
-- 15. DATA PEMBAYARAN GAGAL SEBAGAI PEMBANDING
-- ============================================================
-- Karena kombinasi mahasiswa-periode sudah unik, data gagal
-- ditempatkan pada mahasiswa yang belum memasuki perguruan tinggi
-- pada periode tersebut. Data ini tidak boleh dihitung sebagai UKT
-- berhasil pada analisis.

INSERT INTO pembayaran_ukt (
    mahasiswa_id,
    periode_id,
    jumlah,
    tanggal_bayar,
    metode,
    status
)
SELECT
    m.mahasiswa_id,
    1,
    6500000,
    timestamp '2022-08-15 10:00:00'
        + ((m.mahasiswa_id % 10) || ' hours')::interval,
    'VIRTUAL_ACCOUNT',
    'GAGAL'
FROM mahasiswa m
WHERE m.angkatan = 2025
  AND ((m.mahasiswa_id - 1) % 100) + 1 BETWEEN 76 AND 80;

ANALYZE;

-- ============================================================
-- 16. RINGKASAN POLA DATA
-- ============================================================
-- Tabel utama:
--   kampus                : 3
--   fakultas              : 4
--   program_studi         : 8
--   dosen                 : 80
--   mata_kuliah           : 64, masing-masing prodi 8 mata kuliah
--   periode_akademik      : 8
--   mahasiswa             : 800, masing-masing prodi 100
--
-- Pola analitik:
--   * Periode 8 adalah periode akademik aktif.
--   * Prodi 1-5 masing-masing memiliki 95 mahasiswa aktif.
--   * Prodi 6-8 masing-masing memiliki 75 mahasiswa aktif.
--   * Mahasiswa 1-10 memiliki pembayaran UKT berhasil terbesar.
--   * Mata kuliah 64 tidak pernah diambil mahasiswa 1-10 dan
--     memiliki basis mahasiswa serta pendapatan UKT yang besar.
--   * Dosen 70 hanya mengajar prodi 8 dan menangani seluruh
--     mata kuliah pada prodi tersebut.
--   * Prodi 8 tidak memiliki KRS reguler pada periode 4.
--   * Setiap prodi memiliki delapan mata kuliah dengan pola nilai
--     yang mendukung analisis persentil per periode.
--   * Angkatan 2022, 2023, dan 2024 masing-masing berjumlah
--     200 mahasiswa dan memiliki observasi minimal tiga semester.
--   * Tingkat kelulusan seluruh mata kuliah per semester berbeda
--     menurut angkatan dan semester.
--
-- Filter transaksi valid yang disarankan:
--   krs.status = 'DISETUJUI'
--   pembayaran_ukt.status = 'BERHASIL'
-- ============================================================
