-- =====================================================
-- Fix Content Audit Log Triggers
-- Migration: 003_fix_triggers.sql
-- =====================================================

USE sistem_humas_poltek;

-- Drop old triggers (if exist)
DROP TRIGGER IF EXISTS after_content_insert;
DROP TRIGGER IF EXISTS after_content_update;
DROP TRIGGER IF EXISTS after_content_delete;

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
