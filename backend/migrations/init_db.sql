-- File: backend/migrations/init_db.sql

-- Drop existing tables if needed (for fresh install)
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS cooperations;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS roles;

-- Create database
CREATE DATABASE IF NOT EXISTS sistem_humas_poltek 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE sistem_humas_poltek;

-- Table: roles
CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Table: permissions
CREATE TABLE permissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    permission_name VARCHAR(100) NOT NULL UNIQUE,
    module ENUM('konten', 'kerjasama', 'user', 'system') NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Table: role_permissions (Many-to-Many relationship)
CREATE TABLE role_permissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_id INT NOT NULL,
    permission_id INT NOT NULL,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE,
    UNIQUE KEY unique_role_permission (role_id, permission_id)
) ENGINE=InnoDB;

-- Table: users
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    nip VARCHAR(20) UNIQUE,
    role_id INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    email_verified BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT,
    INDEX idx_username (username),
    INDEX idx_email (email)
) ENGINE=InnoDB;

-- Table: sessions (JWT token management)
CREATE TABLE sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token TEXT NOT NULL,
    refresh_token TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB;

-- Table: audit_logs
CREATE TABLE audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    module VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id INT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    details JSON,
    old_values JSON,
    new_values JSON,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_timestamp (timestamp),
    INDEX idx_action (action)
) ENGINE=InnoDB;

-- Table: cooperations (pengajuan kerjasama)
CREATE TABLE cooperations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    institution_name VARCHAR(150) NOT NULL,
    contact_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(30) NOT NULL,
    purpose TEXT NOT NULL,
    event_date DATE NOT NULL,
    document_name VARCHAR(255) NOT NULL,
    document_mime VARCHAR(100),
    document_data LONGBLOB,
    status ENUM('pending', 'verified', 'approved', 'rejected') DEFAULT 'pending',
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_status (status),
    INDEX idx_created_by (created_by),
    INDEX idx_event_date (event_date)
) ENGINE=InnoDB;

-- Insert default roles
INSERT INTO roles (role_name, description) VALUES
('User', 'Pengguna biasa - dapat membuat konten dan mengajukan kerjasama'),
('Staff Jashumas', 'Staf HUMAS - dapat memverifikasi konten dan kerjasama'),
('Kasubbag Jashumas', 'Kepala Sub Bagian HUMAS - dapat menyetujui publikasi dan kerjasama');

-- Insert permissions
INSERT INTO permissions (permission_name, module, description) VALUES
-- Konten permissions
('create_content', 'konten', 'Membuat draft konten/berita'),
('edit_own_content', 'konten', 'Mengedit konten sendiri'),
('delete_own_content', 'konten', 'Menghapus konten sendiri'),
('view_all_content', 'konten', 'Melihat semua konten'),
('verify_content', 'konten', 'Memverifikasi konten'),
('approve_content', 'konten', 'Menyetujui publikasi konten'),
('publish_content', 'konten', 'Mempublikasikan konten'),

-- Kerjasama permissions
('submit_coop', 'kerjasama', 'Mengajukan permohonan kerjasama'),
('view_own_coop', 'kerjasama', 'Melihat pengajuan kerjasama sendiri'),
('view_all_coop', 'kerjasama', 'Melihat semua pengajuan kerjasama'),
('verify_coop', 'kerjasama', 'Memverifikasi pengajuan kerjasama'),
('approve_coop', 'kerjasama', 'Menyetujui/menolak kerjasama'),

-- User management permissions
('view_users', 'user', 'Melihat daftar pengguna'),
('create_user', 'user', 'Membuat pengguna baru'),
('edit_user', 'user', 'Mengedit data pengguna'),
('delete_user', 'user', 'Menghapus pengguna'),
('reset_password', 'user', 'Reset password pengguna'),

-- System permissions
('view_audit_log', 'system', 'Melihat audit log sistem'),
('manage_roles', 'system', 'Mengelola role dan permission');

-- Assign permissions to roles
-- User role permissions
INSERT INTO role_permissions (role_id, permission_id) 
SELECT r.id, p.id 
FROM roles r, permissions p 
WHERE r.role_name = 'User' 
AND p.permission_name IN ('create_content', 'edit_own_content', 'delete_own_content', 'submit_coop', 'view_own_coop');

-- Staff Jashumas role permissions
INSERT INTO role_permissions (role_id, permission_id) 
SELECT r.id, p.id 
FROM roles r, permissions p 
WHERE r.role_name = 'Staff Jashumas' 
AND p.permission_name IN (
    'create_content', 'edit_own_content', 'delete_own_content', 
    'view_all_content', 'verify_content', 
    'submit_coop', 'view_all_coop', 'verify_coop',
    'view_users', 'view_audit_log'
);

-- Kasubbag Jashumas role permissions (full access)
INSERT INTO role_permissions (role_id, permission_id) 
SELECT r.id, p.id 
FROM roles r, permissions p 
WHERE r.role_name = 'Kasubbag Jashumas';

-- Create default admin user (password: Admin@123)
-- Password hash generated with Argon2
INSERT INTO users (username, email, password_hash, full_name, nip, role_id, is_active, email_verified) 
VALUES (
    'admin',
    'admin@poltek-ssn.ac.id',
    '$argon2id$v=19$m=65536,t=3,p=4$somebase64salt$somebase64hash',
    'Administrator',
    '199999999999999999',
    (SELECT id FROM roles WHERE role_name = 'Kasubbag Jashumas'),
    TRUE,
    TRUE
);
