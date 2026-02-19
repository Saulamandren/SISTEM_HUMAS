-- =====================================================
-- Content Management Module
-- Migration: 002_content_management.sql
-- =====================================================

USE sistem_humas_poltek;

-- =====================================================
-- 1. Table: content_categories
-- =====================================================
CREATE TABLE IF NOT EXISTS content_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(50) DEFAULT 'article',
    color VARCHAR(20) DEFAULT '#1976D2',
    is_active BOOLEAN DEFAULT TRUE,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_slug (slug),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- 2. Table: contents
-- =====================================================
CREATE TABLE IF NOT EXISTS contents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    excerpt TEXT,
    body LONGTEXT NOT NULL,
    featured_image VARCHAR(500),
    category_id INT NOT NULL,
    author_id INT NOT NULL,
    status ENUM('draft', 'pending', 'approved', 'published', 'rejected') DEFAULT 'draft',
    views INT DEFAULT 0,
    published_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES content_categories(id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_slug (slug),
    INDEX idx_status (status),
    INDEX idx_category (category_id),
    INDEX idx_author (author_id),
    INDEX idx_published (published_at),
    FULLTEXT KEY idx_search (title, excerpt, body)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- 3. Table: content_approvals
-- =====================================================
CREATE TABLE IF NOT EXISTS content_approvals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    content_id INT NOT NULL,
    approver_id INT NOT NULL,
    approver_role VARCHAR(50) NOT NULL,
    action ENUM('submit', 'approve', 'reject', 'publish') NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (content_id) REFERENCES contents(id) ON DELETE CASCADE,
    FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_content (content_id),
    INDEX idx_approver (approver_id),
    INDEX idx_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- 4. Table: content_tags (Optional - for tagging)
-- =====================================================
CREATE TABLE IF NOT EXISTS content_tags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    slug VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- 5. Table: content_tag_relations (Many-to-Many)
-- =====================================================
CREATE TABLE IF NOT EXISTS content_tag_relations (
    content_id INT NOT NULL,
    tag_id INT NOT NULL,
    PRIMARY KEY (content_id, tag_id),
    FOREIGN KEY (content_id) REFERENCES contents(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES content_tags(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- 6. Insert Default Categories
-- =====================================================
INSERT INTO content_categories (name, slug, description, icon, color, created_by) VALUES
('Berita Kampus', 'berita-kampus', 'Berita dan informasi seputar kampus', 'newspaper', '#1976D2', 1),
('Pengumuman', 'pengumuman', 'Pengumuman resmi dari kampus', 'campaign', '#F57C00', 1),
('Artikel', 'artikel', 'Artikel dan tulisan edukatif', 'article', '#388E3C', 1),
('Kegiatan', 'kegiatan', 'Informasi kegiatan dan event kampus', 'event', '#7B1FA2', 1),
('Prestasi', 'prestasi', 'Prestasi mahasiswa dan dosen', 'emoji_events', '#D32F2F', 1);

-- =====================================================
-- 7. Add Permissions for Content Management
-- =====================================================
INSERT INTO permissions (permission_name, description) VALUES
('content.create', 'Create new content'),
('content.read.own', 'Read own content'),
('content.read.all', 'Read all content'),
('content.update.own', 'Update own content'),
('content.update.all', 'Update all content'),
('content.delete.own', 'Delete own content'),
('content.delete.all', 'Delete all content'),
('content.publish', 'Publish content'),
('content.approve', 'Approve content'),
('category.create', 'Create content category'),
('category.update', 'Update content category'),
('category.delete', 'Delete content category');

-- =====================================================
-- 8. Assign Permissions to Roles
-- =====================================================

-- User Role (role_id = 1)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, id FROM permissions WHERE permission_name IN (
    'content.create',
    'content.read.own',
    'content.update.own',
    'content.delete.own'
);

-- Staff Jashumas Role (role_id = 2)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 2, id FROM permissions WHERE permission_name IN (
    'content.create',
    'content.read.own',
    'content.read.all',
    'content.update.own',
    'content.update.all',
    'content.delete.own',
    'content.approve',
    'category.create',
    'category.update'
);

-- Kasubbag Jashumas Role (role_id = 3)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 3, id FROM permissions WHERE permission_name IN (
    'content.create',
    'content.read.own',
    'content.read.all',
    'content.update.own',
    'content.update.all',
    'content.delete.own',
    'content.delete.all',
    'content.approve',
    'content.publish',
    'category.create',
    'category.update',
    'category.delete'
);

-- =====================================================
-- 9. Audit Log Triggers for Contents
-- =====================================================
DELIMITER $$

CREATE TRIGGER after_content_insert
AFTER INSERT ON contents
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, action, module, ip_address, user_agent, details)
    VALUES (
        NEW.author_id,
        'INSERT',
        'content',
        NULL,
        NULL,
        JSON_OBJECT(
            'table', 'contents',
            'record_id', NEW.id,
            'new_values', JSON_OBJECT(
                'title', NEW.title,
                'category_id', NEW.category_id,
                'status', NEW.status
            )
        )
    );
END$$

CREATE TRIGGER after_content_update
AFTER UPDATE ON contents
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, action, module, ip_address, user_agent, details)
    VALUES (
        NEW.author_id,
        'UPDATE',
        'content',
        NULL,
        NULL,
        JSON_OBJECT(
            'table', 'contents',
            'record_id', NEW.id,
            'old_values', JSON_OBJECT(
                'title', OLD.title,
                'status', OLD.status
            ),
            'new_values', JSON_OBJECT(
                'title', NEW.title,
                'status', NEW.status
            )
        )
    );
END$$

CREATE TRIGGER after_content_delete
AFTER DELETE ON contents
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, action, module, ip_address, user_agent, details)
    VALUES (
        OLD.author_id,
        'DELETE',
        'content',
        NULL,
        NULL,
        JSON_OBJECT(
            'table', 'contents',
            'record_id', OLD.id,
            'old_values', JSON_OBJECT(
                'title', OLD.title,
                'status', OLD.status
            )
        )
    );
END$$

DELIMITER ;

-- =====================================================
-- Done! Content Management Schema Created
-- =====================================================
