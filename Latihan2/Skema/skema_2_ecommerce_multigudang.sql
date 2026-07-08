-- ============================================================
-- SKEMA 2: SISTEM E-COMMERCE MULTI-GUDANG
-- PostgreSQL
--
-- Tujuan data:
-- 1. Mendukung analisis OLAP untuk 7 soal pada Skema 2.
-- 2. Menyediakan data 15 bulan agar analisis 12 bulan terakhir
--    tetap memiliki bulan pembanding.
-- 3. Menyediakan pola pelanggan teratas, produk unggulan,
--    gudang teraktif, bulan tanpa transaksi, distribusi kategori,
--    dan pasangan produk yang sering dibeli bersama.
--
-- Jalankan seluruh file ini pada database PostgreSQL.
-- ============================================================

DROP SCHEMA IF EXISTS ecommerce_multigudang CASCADE;
CREATE SCHEMA ecommerce_multigudang;
SET search_path TO ecommerce_multigudang, public;

-- ============================================================
-- 1. TABEL REFERENSI WILAYAH
-- ============================================================

CREATE TABLE provinsi (
    provinsi_id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_provinsi    varchar(100) NOT NULL UNIQUE,
    last_update      timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kota (
    kota_id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_kota         varchar(100) NOT NULL,
    provinsi_id       integer NOT NULL REFERENCES provinsi(provinsi_id),
    last_update       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (nama_kota, provinsi_id)
);

CREATE TABLE alamat (
    alamat_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alamat            varchar(200) NOT NULL,
    alamat2           varchar(200),
    kecamatan         varchar(100) NOT NULL,
    kota_id           integer NOT NULL REFERENCES kota(kota_id),
    kode_pos          varchar(10) NOT NULL,
    telepon           varchar(30),
    last_update       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 2. TABEL MASTER PRODUK DAN SUPPLIER
-- ============================================================

CREATE TABLE merek (
    merek_id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_merek        varchar(100) NOT NULL UNIQUE,
    last_update       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kategori_produk (
    kategori_id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama              varchar(100) NOT NULL UNIQUE,
    last_update       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE produk (
    produk_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_produk       varchar(150) NOT NULL UNIQUE,
    deskripsi         text,
    merek_id          integer NOT NULL REFERENCES merek(merek_id),
    harga              numeric(14,2) NOT NULL CHECK (harga > 0),
    berat              numeric(10,2) NOT NULL CHECK (berat > 0),
    aktif              boolean NOT NULL DEFAULT true,
    last_update       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE produk_kategori (
    produk_id         integer NOT NULL REFERENCES produk(produk_id),
    kategori_id       integer NOT NULL REFERENCES kategori_produk(kategori_id),
    last_update       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (produk_id, kategori_id)
);

CREATE TABLE supplier (
    supplier_id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_supplier     varchar(150) NOT NULL UNIQUE,
    email             varchar(150) NOT NULL UNIQUE,
    telepon           varchar(30) NOT NULL,
    alamat_id         bigint NOT NULL REFERENCES alamat(alamat_id),
    aktif             boolean NOT NULL DEFAULT true,
    last_update       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE produk_supplier (
    produk_id         integer NOT NULL REFERENCES produk(produk_id),
    supplier_id       integer NOT NULL REFERENCES supplier(supplier_id),
    harga_beli        numeric(14,2) NOT NULL CHECK (harga_beli > 0),
    minimum_order     integer NOT NULL CHECK (minimum_order > 0),
    lead_time_hari    integer NOT NULL CHECK (lead_time_hari >= 0),
    last_update       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (produk_id, supplier_id)
);

-- ============================================================
-- 3. TABEL GUDANG, PEGAWAI, DAN STOK
-- ============================================================

CREATE TABLE gudang (
    gudang_id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_gudang           varchar(120) NOT NULL UNIQUE,
    manager_pegawai_id    integer,
    alamat_id             bigint NOT NULL REFERENCES alamat(alamat_id),
    aktif                 boolean NOT NULL DEFAULT true,
    last_update           timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pegawai (
    pegawai_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_depan         varchar(80) NOT NULL,
    nama_belakang      varchar(80) NOT NULL,
    email              varchar(150) NOT NULL UNIQUE,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    gudang_id          integer NOT NULL REFERENCES gudang(gudang_id),
    username           varchar(80) NOT NULL UNIQUE,
    password_hash      varchar(200) NOT NULL,
    aktif              boolean NOT NULL DEFAULT true,
    tanggal_masuk      date NOT NULL,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE gudang
    ADD CONSTRAINT fk_gudang_manager
    FOREIGN KEY (manager_pegawai_id)
    REFERENCES pegawai(pegawai_id);

CREATE TABLE stok (
    stok_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    produk_id          integer NOT NULL REFERENCES produk(produk_id),
    gudang_id          integer NOT NULL REFERENCES gudang(gudang_id),
    jumlah             integer NOT NULL CHECK (jumlah >= 0),
    stok_minimum       integer NOT NULL CHECK (stok_minimum >= 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (produk_id, gudang_id)
);

-- ============================================================
-- 4. TABEL PELANGGAN DAN TRANSAKSI
-- ============================================================

CREATE TABLE pelanggan (
    pelanggan_id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nama_depan         varchar(80) NOT NULL,
    nama_belakang      varchar(80) NOT NULL,
    email              varchar(150) NOT NULL UNIQUE,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    tanggal_daftar     date NOT NULL,
    aktif              boolean NOT NULL DEFAULT true,
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pesanan (
    pesanan_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nomor_pesanan      varchar(40) NOT NULL UNIQUE,
    pelanggan_id       integer NOT NULL REFERENCES pelanggan(pelanggan_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    tanggal_pesanan    timestamp NOT NULL,
    alamat_id          bigint NOT NULL REFERENCES alamat(alamat_id),
    status             varchar(20) NOT NULL
                       CHECK (status IN ('DIPROSES', 'DIKIRIM', 'SELESAI', 'DIBATALKAN')),
    total              numeric(16,2) NOT NULL CHECK (total >= 0),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE detail_pesanan (
    detail_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pesanan_id         bigint NOT NULL REFERENCES pesanan(pesanan_id),
    stok_id            bigint NOT NULL REFERENCES stok(stok_id),
    jumlah             integer NOT NULL CHECK (jumlah > 0),
    harga              numeric(14,2) NOT NULL CHECK (harga > 0),
    subtotal           numeric(16,2)
                       GENERATED ALWAYS AS (jumlah * harga) STORED,
    UNIQUE (pesanan_id, stok_id)
);

CREATE TABLE pembayaran (
    pembayaran_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pesanan_id         bigint NOT NULL UNIQUE REFERENCES pesanan(pesanan_id),
    pelanggan_id       integer NOT NULL REFERENCES pelanggan(pelanggan_id),
    pegawai_id         integer NOT NULL REFERENCES pegawai(pegawai_id),
    jumlah             numeric(16,2) NOT NULL CHECK (jumlah >= 0),
    metode             varchar(30) NOT NULL
                       CHECK (metode IN ('TRANSFER_BANK', 'KARTU', 'E_WALLET', 'VIRTUAL_ACCOUNT', 'COD')),
    tanggal_bayar      timestamp NOT NULL,
    status             varchar(20) NOT NULL
                       CHECK (status IN ('MENUNGGU', 'BERHASIL', 'GAGAL', 'DIKEMBALIKAN')),
    last_update        timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 5. INDEKS UNTUK ANALISIS
-- ============================================================

CREATE INDEX idx_produk_kategori_kategori
    ON produk_kategori(kategori_id, produk_id);

CREATE INDEX idx_produk_supplier_supplier
    ON produk_supplier(supplier_id, produk_id);

CREATE INDEX idx_stok_gudang_produk
    ON stok(gudang_id, produk_id);

CREATE INDEX idx_stok_produk_gudang
    ON stok(produk_id, gudang_id);

CREATE INDEX idx_pesanan_tanggal_status
    ON pesanan(tanggal_pesanan, status);

CREATE INDEX idx_pesanan_pelanggan_tanggal
    ON pesanan(pelanggan_id, tanggal_pesanan);

CREATE INDEX idx_detail_pesanan_pesanan
    ON detail_pesanan(pesanan_id);

CREATE INDEX idx_detail_pesanan_stok
    ON detail_pesanan(stok_id);

CREATE INDEX idx_pembayaran_status_tanggal
    ON pembayaran(status, tanggal_bayar);

CREATE INDEX idx_pembayaran_pelanggan
    ON pembayaran(pelanggan_id, status);

-- ============================================================
-- 6. DATA MASTER
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
    alamat2,
    kecamatan,
    kota_id,
    kode_pos,
    telepon
)
SELECT
    'Jalan Niaga Nomor ' || g,
    CASE WHEN g % 4 = 0 THEN 'Blok ' || chr(65 + (g % 20)) ELSE NULL END,
    'Kecamatan ' || ((g - 1) % 30 + 1),
    ((g - 1) % 12) + 1,
    lpad((10000 + g)::text, 5, '0'),
    '08' || lpad((1000000000 + g)::text, 10, '0')
FROM generate_series(1, 900) AS g;

INSERT INTO merek (nama_merek)
SELECT 'Merek ' || lpad(g::text, 2, '0')
FROM generate_series(1, 12) AS g;

INSERT INTO kategori_produk (nama) VALUES
('Elektronik'),
('Aksesori Komputer'),
('Peralatan Rumah Tangga'),
('Kesehatan dan Perawatan'),
('Olahraga'),
('Buku dan Alat Tulis'),
('Makanan dan Minuman'),
('Fashion'),
('Perlengkapan Bayi'),
('Otomotif'),
('Hobi dan Koleksi'),
('Perlengkapan Kantor');

INSERT INTO produk (
    nama_produk,
    deskripsi,
    merek_id,
    harga,
    berat,
    aktif
)
SELECT
    'Produk ' || lpad(g::text, 3, '0'),
    'Produk analitik nomor ' || g ||
    ' untuk simulasi transaksi e-commerce multi-gudang.',
    ((g - 1) % 12) + 1,
    CASE
        WHEN g = 50 THEN 175.00
        WHEN g = 21 THEN 55.00
        WHEN g = 22 THEN 60.00
        WHEN g = 73 THEN 35.00
        ELSE (20 + (g % 15) * 7.50)::numeric(14,2)
    END,
    (0.20 + (g % 25) * 0.15)::numeric(10,2),
    true
FROM generate_series(1, 96) AS g;

INSERT INTO produk_kategori (produk_id, kategori_id)
SELECT
    g,
    ((g - 1) / 8) + 1
FROM generate_series(1, 96) AS g;

INSERT INTO supplier (
    nama_supplier,
    email,
    telepon,
    alamat_id,
    aktif
)
SELECT
    'Supplier ' || lpad(g::text, 2, '0'),
    'supplier' || g || '@contoh.id',
    '021' || lpad((7000000 + g)::text, 7, '0'),
    20 + g,
    true
FROM generate_series(1, 24) AS g;

INSERT INTO produk_supplier (
    produk_id,
    supplier_id,
    harga_beli,
    minimum_order,
    lead_time_hari
)
SELECT
    p.produk_id,
    ((p.produk_id - 1) % 24) + 1,
    round((p.harga * 0.62)::numeric, 2),
    5 + (p.produk_id % 10),
    2 + (p.produk_id % 8)
FROM produk p
UNION ALL
SELECT
    p.produk_id,
    ((p.produk_id + 6) % 24) + 1,
    round((p.harga * 0.68)::numeric, 2),
    8 + (p.produk_id % 12),
    3 + (p.produk_id % 10)
FROM produk p;

INSERT INTO gudang (
    nama_gudang,
    alamat_id,
    aktif
)
SELECT
    'Gudang Regional ' || lpad(g::text, 2, '0'),
    g,
    true
FROM generate_series(1, 8) AS g;

INSERT INTO pegawai (
    nama_depan,
    nama_belakang,
    email,
    alamat_id,
    gudang_id,
    username,
    password_hash,
    aktif,
    tanggal_masuk
)
SELECT
    'Pegawai',
    lpad(g::text, 3, '0'),
    'pegawai' || g || '@contoh.id',
    100 + g,
    ((g - 1) % 8) + 1,
    'pegawai' || g,
    'hash_demo_' || g,
    true,
    CURRENT_DATE - ((200 + g * 7) || ' days')::interval
FROM generate_series(1, 24) AS g;

UPDATE gudang g
SET manager_pegawai_id = (
    SELECT MIN(p.pegawai_id)
    FROM pegawai p
    WHERE p.gudang_id = g.gudang_id
);

-- Produk 1-72 tersedia pada seluruh gudang utama 1-5.
INSERT INTO stok (
    produk_id,
    gudang_id,
    jumlah,
    stok_minimum
)
SELECT
    p,
    w,
    CASE
        WHEN ((p + w * 3) % 10) < w
            THEN 8 + ((p + w) % 7)
        ELSE 35 + ((p * 3 + w * 5) % 90)
    END,
    15
FROM generate_series(1, 72) AS p
CROSS JOIN generate_series(1, 5) AS w;

-- Produk 73-96 hanya tersedia pada gudang regional 6-8.
INSERT INTO stok (
    produk_id,
    gudang_id,
    jumlah,
    stok_minimum
)
SELECT
    p,
    w,
    CASE
        WHEN ((p + w) % 4) = 0 THEN 10
        ELSE 40 + ((p * 2 + w * 7) % 75)
    END,
    15
FROM generate_series(73, 96) AS p
CROSS JOIN generate_series(6, 8) AS w;

INSERT INTO pelanggan (
    nama_depan,
    nama_belakang,
    email,
    alamat_id,
    tanggal_daftar,
    aktif
)
SELECT
    'Pelanggan',
    lpad(g::text, 4, '0'),
    'pelanggan' || g || '@contoh.id',
    200 + g,
    CURRENT_DATE - ((40 + (g % 900)) || ' days')::interval,
    CASE WHEN g % 29 = 0 THEN false ELSE true END
FROM generate_series(1, 500) AS g;

-- ============================================================
-- 7. DATA TRANSAKSI 15 BULAN
-- ============================================================

DO $$
DECLARE
    v_month_start       date := (date_trunc('month', CURRENT_DATE)::date - interval '14 months')::date;
    v_order_date        timestamp;
    v_order_id          bigint;
    v_stock_id          bigint;
    v_price             numeric(14,2);
    v_total             numeric(16,2);
    v_qty               integer;
    v_customer          integer;
    v_warehouse         integer;
    v_employee          integer;
    v_counter           bigint := 0;
    v_product           integer;
    v_category          integer;
    v_champion          integer;
    m                   integer;
    p                   integer;
    c                   integer;
    k                   integer;
    j                   integer;
BEGIN
    -- --------------------------------------------------------
    -- A. Transaksi dasar:
    --    setiap produk terjual setiap bulan sehingga analisis
    --    per kategori dan persentil memiliki cakupan memadai.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR p IN 1..96 LOOP
            v_customer := 11 + ((p * 7 + m * 13) % 490);

            IF p <= 72 THEN
                v_warehouse := 1 + ((p + m) % 5);
            ELSE
                v_warehouse := 6 + ((p + m) % 3);

                -- Gudang 8 sengaja tidak memiliki transaksi
                -- pada dua bulan tertentu.
                IF m IN (4, 9) AND v_warehouse = 8 THEN
                    v_warehouse := 6;
                END IF;
            END IF;

            SELECT stok_id
            INTO v_stock_id
            FROM stok
            WHERE produk_id = p
              AND gudang_id = v_warehouse;

            SELECT harga
            INTO v_price
            FROM produk
            WHERE produk_id = p;

            v_qty := 1 + ((p + m) % 4);
            v_price := round(
                (v_price * (0.90 + ((p + m) % 3) * 0.05))::numeric,
                2
            );
            v_total := v_qty * v_price;
            v_order_date :=
                v_month_start
                + (m || ' months')::interval
                + (((p * 3 + m) % 24) || ' days')::interval
                + (((p + m) % 11) || ' hours')::interval;

            v_employee := 1 + ((v_warehouse - 1) % 8);
            v_counter := v_counter + 1;

            INSERT INTO pesanan (
                nomor_pesanan,
                pelanggan_id,
                pegawai_id,
                tanggal_pesanan,
                alamat_id,
                status,
                total
            )
            VALUES (
                'ORD-' || to_char(v_order_date, 'YYYYMMDD') || '-' || lpad(v_counter::text, 7, '0'),
                v_customer,
                v_employee,
                v_order_date,
                200 + v_customer,
                'SELESAI',
                v_total
            )
            RETURNING pesanan_id INTO v_order_id;

            INSERT INTO detail_pesanan (
                pesanan_id,
                stok_id,
                jumlah,
                harga
            )
            VALUES (
                v_order_id,
                v_stock_id,
                v_qty,
                v_price
            );

            INSERT INTO pembayaran (
                pesanan_id,
                pelanggan_id,
                pegawai_id,
                jumlah,
                metode,
                tanggal_bayar,
                status
            )
            VALUES (
                v_order_id,
                v_customer,
                v_employee,
                v_total,
                CASE (v_order_id % 5)
                    WHEN 0 THEN 'TRANSFER_BANK'
                    WHEN 1 THEN 'KARTU'
                    WHEN 2 THEN 'E_WALLET'
                    WHEN 3 THEN 'VIRTUAL_ACCOUNT'
                    ELSE 'COD'
                END,
                v_order_date + interval '1 day',
                'BERHASIL'
            );
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- B. Pesanan bernilai besar untuk pelanggan 1-10.
    --    Mereka menjadi sepuluh pelanggan dengan belanja terbesar,
    --    tetapi tidak membeli produk 50 dan produk 73.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR c IN 1..10 LOOP
            FOR k IN 1..2 LOOP
                v_product := 1 + ((c * 2 + m + k) % 15);
                v_warehouse := 1 + ((c + m + k) % 5);

                SELECT stok_id
                INTO v_stock_id
                FROM stok
                WHERE produk_id = v_product
                  AND gudang_id = v_warehouse;

                SELECT harga
                INTO v_price
                FROM produk
                WHERE produk_id = v_product;

                v_qty := 10 + (c % 5) + k;
                v_price := round((v_price * 1.15)::numeric, 2);
                v_total := v_qty * v_price;
                v_order_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((2 + c + k) || ' days')::interval
                    + ((8 + k) || ' hours')::interval;

                v_employee := 1 + ((v_warehouse - 1) % 8);
                v_counter := v_counter + 1;

                INSERT INTO pesanan (
                    nomor_pesanan,
                    pelanggan_id,
                    pegawai_id,
                    tanggal_pesanan,
                    alamat_id,
                    status,
                    total
                )
                VALUES (
                    'VIP-' || to_char(v_order_date, 'YYYYMMDD') || '-' || lpad(v_counter::text, 7, '0'),
                    c,
                    v_employee,
                    v_order_date,
                    200 + c,
                    'SELESAI',
                    v_total
                )
                RETURNING pesanan_id INTO v_order_id;

                INSERT INTO detail_pesanan (
                    pesanan_id,
                    stok_id,
                    jumlah,
                    harga
                )
                VALUES (
                    v_order_id,
                    v_stock_id,
                    v_qty,
                    v_price
                );

                INSERT INTO pembayaran (
                    pesanan_id,
                    pelanggan_id,
                    pegawai_id,
                    jumlah,
                    metode,
                    tanggal_bayar,
                    status
                )
                VALUES (
                    v_order_id,
                    c,
                    v_employee,
                    v_total,
                    'VIRTUAL_ACCOUNT',
                    v_order_date + interval '2 hours',
                    'BERHASIL'
                );
            END LOOP;
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- C. Produk 50 memiliki pendapatan sangat tinggi,
    --    tetapi tidak pernah dibeli pelanggan 1-10.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR j IN 1..8 LOOP
            v_product := 50;
            v_customer := 50 + ((m * 17 + j * 11) % 430);
            v_warehouse := 1 + ((m + j) % 5);

            SELECT stok_id
            INTO v_stock_id
            FROM stok
            WHERE produk_id = v_product
              AND gudang_id = v_warehouse;

            SELECT harga
            INTO v_price
            FROM produk
            WHERE produk_id = v_product;

            v_qty := 7 + (j % 4);
            v_total := v_qty * v_price;
            v_order_date :=
                v_month_start
                + (m || ' months')::interval
                + ((3 + j * 2) || ' days')::interval
                + interval '14 hours';

            v_employee := 1 + ((v_warehouse - 1) % 8);
            v_counter := v_counter + 1;

            INSERT INTO pesanan (
                nomor_pesanan,
                pelanggan_id,
                pegawai_id,
                tanggal_pesanan,
                alamat_id,
                status,
                total
            )
            VALUES (
                'P50-' || to_char(v_order_date, 'YYYYMMDD') || '-' || lpad(v_counter::text, 7, '0'),
                v_customer,
                v_employee,
                v_order_date,
                200 + v_customer,
                'SELESAI',
                v_total
            )
            RETURNING pesanan_id INTO v_order_id;

            INSERT INTO detail_pesanan (
                pesanan_id,
                stok_id,
                jumlah,
                harga
            )
            VALUES (
                v_order_id,
                v_stock_id,
                v_qty,
                v_price
            );

            INSERT INTO pembayaran (
                pesanan_id,
                pelanggan_id,
                pegawai_id,
                jumlah,
                metode,
                tanggal_bayar,
                status
            )
            VALUES (
                v_order_id,
                v_customer,
                v_employee,
                v_total,
                'TRANSFER_BANK',
                v_order_date + interval '1 hour',
                'BERHASIL'
            );
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- D. Produk 73 memiliki unit terjual tinggi dan hanya
    --    tersedia pada gudang 6-8.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR j IN 1..7 LOOP
            v_product := 73;
            v_customer := 100 + ((m * 19 + j * 13) % 380);
            v_warehouse := 6 + ((m + j) % 3);

            IF m IN (4, 9) AND v_warehouse = 8 THEN
                v_warehouse := 6;
            END IF;

            SELECT stok_id
            INTO v_stock_id
            FROM stok
            WHERE produk_id = v_product
              AND gudang_id = v_warehouse;

            SELECT harga
            INTO v_price
            FROM produk
            WHERE produk_id = v_product;

            v_qty := 12;
            v_total := v_qty * v_price;
            v_order_date :=
                v_month_start
                + (m || ' months')::interval
                + ((4 + j * 2) || ' days')::interval
                + interval '16 hours';

            v_employee := 1 + ((v_warehouse - 1) % 8);
            v_counter := v_counter + 1;

            INSERT INTO pesanan (
                nomor_pesanan,
                pelanggan_id,
                pegawai_id,
                tanggal_pesanan,
                alamat_id,
                status,
                total
            )
            VALUES (
                'P73-' || to_char(v_order_date, 'YYYYMMDD') || '-' || lpad(v_counter::text, 7, '0'),
                v_customer,
                v_employee,
                v_order_date,
                200 + v_customer,
                'SELESAI',
                v_total
            )
            RETURNING pesanan_id INTO v_order_id;

            INSERT INTO detail_pesanan (
                pesanan_id,
                stok_id,
                jumlah,
                harga
            )
            VALUES (
                v_order_id,
                v_stock_id,
                v_qty,
                v_price
            );

            INSERT INTO pembayaran (
                pesanan_id,
                pelanggan_id,
                pegawai_id,
                jumlah,
                metode,
                tanggal_bayar,
                status
            )
            VALUES (
                v_order_id,
                v_customer,
                v_employee,
                v_total,
                'E_WALLET',
                v_order_date + interval '30 minutes',
                'BERHASIL'
            );
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- E. Produk unggulan pada setiap kategori.
    --    Pola ini membuat analisis percentile_cont/persentil
    --    per kategori dan bulan menghasilkan data bermakna.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR v_category IN 1..12 LOOP
            v_champion := ((v_category - 1) * 8) + 1;

            FOR j IN 1..2 LOOP
                v_customer := 30 + ((v_category * 31 + m * 7 + j) % 450);

                IF v_champion <= 72 THEN
                    v_warehouse := 1 + ((v_category + m + j) % 5);
                ELSE
                    v_warehouse := 6 + ((v_category + m + j) % 3);

                    IF m IN (4, 9) AND v_warehouse = 8 THEN
                        v_warehouse := 7;
                    END IF;
                END IF;

                SELECT stok_id
                INTO v_stock_id
                FROM stok
                WHERE produk_id = v_champion
                  AND gudang_id = v_warehouse;

                SELECT harga
                INTO v_price
                FROM produk
                WHERE produk_id = v_champion;

                v_qty := 5 + (v_category % 3);
                v_total := v_qty * v_price;
                v_order_date :=
                    v_month_start
                    + (m || ' months')::interval
                    + ((6 + v_category + j) || ' days')::interval
                    + interval '11 hours';

                v_employee := 1 + ((v_warehouse - 1) % 8);
                v_counter := v_counter + 1;

                INSERT INTO pesanan (
                    nomor_pesanan,
                    pelanggan_id,
                    pegawai_id,
                    tanggal_pesanan,
                    alamat_id,
                    status,
                    total
                )
                VALUES (
                    'CHP-' || to_char(v_order_date, 'YYYYMMDD') || '-' || lpad(v_counter::text, 7, '0'),
                    v_customer,
                    v_employee,
                    v_order_date,
                    200 + v_customer,
                    'SELESAI',
                    v_total
                )
                RETURNING pesanan_id INTO v_order_id;

                INSERT INTO detail_pesanan (
                    pesanan_id,
                    stok_id,
                    jumlah,
                    harga
                )
                VALUES (
                    v_order_id,
                    v_stock_id,
                    v_qty,
                    v_price
                );

                INSERT INTO pembayaran (
                    pesanan_id,
                    pelanggan_id,
                    pegawai_id,
                    jumlah,
                    metode,
                    tanggal_bayar,
                    status
                )
                VALUES (
                    v_order_id,
                    v_customer,
                    v_employee,
                    v_total,
                    'KARTU',
                    v_order_date + interval '45 minutes',
                    'BERHASIL'
                );
            END LOOP;
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- F. Pasangan produk 21 dan 22 sering muncul bersama.
    --    Produk tersebut jarang muncul secara terpisah sehingga
    --    support, confidence, dan lift dapat dianalisis.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR j IN 1..6 LOOP
            v_customer := 120 + ((m * 23 + j * 17) % 350);
            v_warehouse := 1 + ((m + j) % 5);
            v_order_date :=
                v_month_start
                + (m || ' months')::interval
                + ((8 + j * 2) || ' days')::interval
                + interval '18 hours';

            v_employee := 1 + ((v_warehouse - 1) % 8);
            v_counter := v_counter + 1;

            v_total :=
                (SELECT harga FROM produk WHERE produk_id = 21)
                +
                (SELECT harga FROM produk WHERE produk_id = 22);

            INSERT INTO pesanan (
                nomor_pesanan,
                pelanggan_id,
                pegawai_id,
                tanggal_pesanan,
                alamat_id,
                status,
                total
            )
            VALUES (
                'PAIR-' || to_char(v_order_date, 'YYYYMMDD') || '-' || lpad(v_counter::text, 7, '0'),
                v_customer,
                v_employee,
                v_order_date,
                200 + v_customer,
                'SELESAI',
                v_total
            )
            RETURNING pesanan_id INTO v_order_id;

            SELECT stok_id
            INTO v_stock_id
            FROM stok
            WHERE produk_id = 21
              AND gudang_id = v_warehouse;

            SELECT harga
            INTO v_price
            FROM produk
            WHERE produk_id = 21;

            INSERT INTO detail_pesanan (
                pesanan_id,
                stok_id,
                jumlah,
                harga
            )
            VALUES (
                v_order_id,
                v_stock_id,
                1,
                v_price
            );

            SELECT stok_id
            INTO v_stock_id
            FROM stok
            WHERE produk_id = 22
              AND gudang_id = v_warehouse;

            SELECT harga
            INTO v_price
            FROM produk
            WHERE produk_id = 22;

            INSERT INTO detail_pesanan (
                pesanan_id,
                stok_id,
                jumlah,
                harga
            )
            VALUES (
                v_order_id,
                v_stock_id,
                1,
                v_price
            );

            INSERT INTO pembayaran (
                pesanan_id,
                pelanggan_id,
                pegawai_id,
                jumlah,
                metode,
                tanggal_bayar,
                status
            )
            VALUES (
                v_order_id,
                v_customer,
                v_employee,
                v_total,
                'E_WALLET',
                v_order_date + interval '10 minutes',
                'BERHASIL'
            );
        END LOOP;
    END LOOP;

    -- --------------------------------------------------------
    -- G. Sampel pesanan dibatalkan dan pembayaran gagal.
    --    Data ini berguna untuk melatih filtering status.
    -- --------------------------------------------------------
    FOR m IN 0..14 LOOP
        FOR j IN 1..3 LOOP
            v_product := 30 + ((m + j) % 20);
            v_customer := 200 + ((m * 9 + j * 5) % 250);
            v_warehouse := 1 + ((m + j) % 5);

            SELECT stok_id
            INTO v_stock_id
            FROM stok
            WHERE produk_id = v_product
              AND gudang_id = v_warehouse;

            SELECT harga
            INTO v_price
            FROM produk
            WHERE produk_id = v_product;

            v_qty := 2;
            v_total := v_qty * v_price;
            v_order_date :=
                v_month_start
                + (m || ' months')::interval
                + ((20 + j) || ' days')::interval
                + interval '9 hours';

            v_employee := 1 + ((v_warehouse - 1) % 8);
            v_counter := v_counter + 1;

            INSERT INTO pesanan (
                nomor_pesanan,
                pelanggan_id,
                pegawai_id,
                tanggal_pesanan,
                alamat_id,
                status,
                total
            )
            VALUES (
                'CNL-' || to_char(v_order_date, 'YYYYMMDD') || '-' || lpad(v_counter::text, 7, '0'),
                v_customer,
                v_employee,
                v_order_date,
                200 + v_customer,
                'DIBATALKAN',
                v_total
            )
            RETURNING pesanan_id INTO v_order_id;

            INSERT INTO detail_pesanan (
                pesanan_id,
                stok_id,
                jumlah,
                harga
            )
            VALUES (
                v_order_id,
                v_stock_id,
                v_qty,
                v_price
            );

            INSERT INTO pembayaran (
                pesanan_id,
                pelanggan_id,
                pegawai_id,
                jumlah,
                metode,
                tanggal_bayar,
                status
            )
            VALUES (
                v_order_id,
                v_customer,
                v_employee,
                v_total,
                'KARTU',
                v_order_date + interval '15 minutes',
                'GAGAL'
            );
        END LOOP;
    END LOOP;
END $$;

ANALYZE;

-- ============================================================
-- 8. RINGKASAN DATA
-- ============================================================
-- Tabel utama:
--   produk              : 96 produk
--   kategori_produk     : 12 kategori, masing-masing 8 produk
--   gudang              : 8 gudang
--   pelanggan           : 500 pelanggan
--   transaksi           : 15 bulan
--
-- Pola analitik:
--   * Pelanggan 1-10 mempunyai nilai belanja sangat tinggi.
--   * Produk 50 berpendapatan tinggi, tetapi tidak dibeli oleh
--     pelanggan 1-10.
--   * Produk 73 hanya tersedia di gudang 6-8 dan memiliki unit
--     terjual tinggi.
--   * Gudang 1-5 memproses lebih banyak pesanan berbeda.
--   * Gudang 8 tidak memiliki transaksi pada dua bulan tertentu.
--   * Setiap kategori memiliki delapan produk yang tetap terjual.
--   * Produk 21 dan 22 sering dibeli bersama.
--   * Pesanan dibatalkan dan pembayaran gagal tersedia sebagai
--     data pembanding untuk filter status.
--
-- Saran filter transaksi valid:
--   pesanan.status = 'SELESAI'
--   pembayaran.status = 'BERHASIL'
-- ============================================================
