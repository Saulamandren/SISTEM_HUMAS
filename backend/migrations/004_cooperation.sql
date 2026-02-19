-- =====================================================
-- Cooperation Module
-- Migration: 004_cooperation.sql
-- =====================================================

USE sistem_humas_poltek;

CREATE TABLE IF NOT EXISTS cooperations (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- Done! Cooperation Schema Created
-- =====================================================
