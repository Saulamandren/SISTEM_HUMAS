import MySQLdb
from flask import current_app
import re

class Category:
    """Category model for content categorization"""
    
    def __init__(self):
        self.conn = None
        self.cursor = None
    
    def _get_db_connection(self):
        """Get database connection"""
        try:
            self.conn = MySQLdb.connect(
                host=current_app.config['MYSQL_HOST'],
                port=current_app.config['MYSQL_PORT'],
                user=current_app.config['MYSQL_USER'],
                password=current_app.config['MYSQL_PASSWORD'],
                database=current_app.config['MYSQL_DB']
            )
            self.cursor = self.conn.cursor(MySQLdb.cursors.DictCursor)
        except Exception as e:
            raise Exception(f"Database connection failed: {str(e)}")
    
    def _close_db_connection(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
    
    def _generate_slug(self, name):
        """Generate slug from name"""
        slug = name.lower()
        slug = re.sub(r'[^a-z0-9\s-]', '', slug)
        slug = re.sub(r'[\s]+', '-', slug)
        return slug
    
    def create_category(self, name, description, icon, color, created_by):
        """Create new category"""
        try:
            self._get_db_connection()
            
            slug = self._generate_slug(name)
            
            # Check if slug exists
            self.cursor.execute("SELECT id FROM content_categories WHERE slug = %s", (slug,))
            if self.cursor.fetchone():
                return {'success': False, 'message': 'Category with similar name already exists'}
            
            query = """
                INSERT INTO content_categories (name, slug, description, icon, color, created_by)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            self.cursor.execute(query, (name, slug, description, icon, color, created_by))
            self.conn.commit()
            
            category_id = self.cursor.lastrowid
            
            return {'success': True, 'category_id': category_id}
            
        except Exception as e:
            if self.conn:
                self.conn.rollback()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def get_all_categories(self, active_only=True):
        """Get all categories"""
        try:
            self._get_db_connection()
            
            query = "SELECT * FROM content_categories"
            if active_only:
                query += " WHERE is_active = TRUE"
            query += " ORDER BY name ASC"
            
            self.cursor.execute(query)
            categories = self.cursor.fetchall()
            
            return {'success': True, 'categories': categories}
            
        except Exception as e:
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def get_category_by_id(self, category_id):
        """Get category by ID"""
        try:
            self._get_db_connection()
            
            query = "SELECT * FROM content_categories WHERE id = %s"
            self.cursor.execute(query, (category_id,))
            category = self.cursor.fetchone()
            
            if not category:
                return {'success': False, 'message': 'Category not found'}
            
            return {'success': True, 'category': category}
            
        except Exception as e:
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def update_category(self, category_id, name, description, icon, color):
        """Update category"""
        try:
            self._get_db_connection()
            
            slug = self._generate_slug(name)
            
            # Check if slug exists (excluding current category)
            self.cursor.execute(
                "SELECT id FROM content_categories WHERE slug = %s AND id != %s",
                (slug, category_id)
            )
            if self.cursor.fetchone():
                return {'success': False, 'message': 'Category with similar name already exists'}
            
            query = """
                UPDATE content_categories
                SET name = %s, slug = %s, description = %s, icon = %s, color = %s
                WHERE id = %s
            """
            self.cursor.execute(query, (name, slug, description, icon, color, category_id))
            self.conn.commit()
            
            if self.cursor.rowcount == 0:
                return {'success': False, 'message': 'Category not found'}
            
            return {'success': True, 'message': 'Category updated successfully'}
            
        except Exception as e:
            if self.conn:
                self.conn.rollback()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def delete_category(self, category_id):
        """Delete category (soft delete - set is_active to FALSE)"""
        try:
            self._get_db_connection()
            
            # Check if category has contents
            self.cursor.execute("SELECT COUNT(*) as count FROM contents WHERE category_id = %s", (category_id,))
            result = self.cursor.fetchone()
            
            if result['count'] > 0:
                return {
                    'success': False,
                    'message': f'Cannot delete category. It has {result["count"]} content(s) associated with it.'
                }
            
            # Soft delete
            query = "UPDATE content_categories SET is_active = FALSE WHERE id = %s"
            self.cursor.execute(query, (category_id,))
            self.conn.commit()
            
            if self.cursor.rowcount == 0:
                return {'success': False, 'message': 'Category not found'}
            
            return {'success': True, 'message': 'Category deleted successfully'}
            
        except Exception as e:
            if self.conn:
                self.conn.rollback()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
