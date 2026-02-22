import MySQLdb
from flask import current_app
import re
from datetime import datetime

class Content:
    """Content model for managing articles/posts"""
    
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
    
    def _generate_slug(self, title):
        """Generate slug from title"""
        slug = title.lower()
        slug = re.sub(r'[^a-z0-9\s-]', '', slug)
        slug = re.sub(r'[\s]+', '-', slug)
        
        # Add timestamp to ensure uniqueness
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        slug = f"{slug}-{timestamp}"
        
        return slug
    
    def create_content(self, title, excerpt, body, category_id, author_id, featured_image=None):
        """Create new content (status: draft)"""
        try:
            self._get_db_connection()
            
            slug = self._generate_slug(title)
            
            query = """
                INSERT INTO contents (title, slug, excerpt, body, category_id, author_id, featured_image, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, 'draft')
            """
            self.cursor.execute(query, (title, slug, excerpt, body, category_id, author_id, featured_image))
            self.conn.commit()
            
            content_id = self.cursor.lastrowid
            
            print(f"[CONTENT] Created content ID: {content_id} by user: {author_id}")
            
            return {'success': True, 'content_id': content_id}
            
        except Exception as e:
            if self.conn:
                self.conn.rollback()
            print(f"[CONTENT ERROR] {str(e)}")
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def get_contents(self, filters=None, page=1, per_page=10):
        """Get contents with filters and pagination"""
        try:
            self._get_db_connection()
            
            # Build query
            query = """
                SELECT c.*, cc.name as category_name, u.full_name as author_name
                FROM contents c
                JOIN content_categories cc ON c.category_id = cc.id
                JOIN users u ON c.author_id = u.id
                WHERE 1=1
            """
            params = []
            
            # Apply filters
            if filters:
                if filters.get('status'):
                    query += " AND c.status = %s"
                    params.append(filters['status'])
                
                if filters.get('category_id'):
                    query += " AND c.category_id = %s"
                    params.append(filters['category_id'])
                
                if filters.get('author_id'):
                    query += " AND c.author_id = %s"
                    params.append(filters['author_id'])
                
                if filters.get('search'):
                    query += " AND (c.title LIKE %s OR c.excerpt LIKE %s OR c.body LIKE %s)"
                    search_term = f"%{filters['search']}%"
                    params.extend([search_term, search_term, search_term])
            
            # Count total
            count_query = f"SELECT COUNT(*) as total FROM ({query}) as count_table"
            self.cursor.execute(count_query, params)
            total = self.cursor.fetchone()['total']
            
            # Add pagination
            query += " ORDER BY c.created_at DESC LIMIT %s OFFSET %s"
            offset = (page - 1) * per_page
            params.extend([per_page, offset])
            
            self.cursor.execute(query, params)
            contents = self.cursor.fetchall()
            
            return {
                'success': True,
                'contents': contents,
                'pagination': {
                    'page': page,
                    'per_page': per_page,
                    'total': total,
                    'total_pages': (total + per_page - 1) // per_page
                }
            }
            
        except Exception as e:
            print(f"[GET CONTENTS ERROR] {str(e)}")
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def get_content_by_id(self, content_id):
        """Get content by ID"""
        try:
            self._get_db_connection()
            
            query = """
                SELECT c.*, cc.name as category_name, cc.icon as category_icon,
                       u.full_name as author_name, u.username as author_username
                FROM contents c
                JOIN content_categories cc ON c.category_id = cc.id
                JOIN users u ON c.author_id = u.id
                WHERE c.id = %s
            """
            self.cursor.execute(query, (content_id,))
            content = self.cursor.fetchone()
            
            if not content:
                return {'success': False, 'message': 'Content not found'}
            
            return {'success': True, 'content': content}
            
        except Exception as e:
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def update_content(self, content_id, title, excerpt, body, category_id, featured_image=None, reset_status=False):
        """Update content"""
        try:
            self._get_db_connection()

            if reset_status:
                query = """
                    UPDATE contents
                    SET title = %s, excerpt = %s, body = %s, category_id = %s, featured_image = %s,
                        status = 'draft', published_at = NULL
                    WHERE id = %s
                """
                params = (title, excerpt, body, category_id, featured_image, content_id)
            else:
                query = """
                    UPDATE contents
                    SET title = %s, excerpt = %s, body = %s, category_id = %s, featured_image = %s
                    WHERE id = %s
                """
                params = (title, excerpt, body, category_id, featured_image, content_id)

            self.cursor.execute(query, params)
            self.conn.commit()
            
            if self.cursor.rowcount == 0:
                return {'success': False, 'message': 'Content not found'}
            
            print(f"[CONTENT] Updated content ID: {content_id}")
            
            return {'success': True, 'message': 'Content updated successfully'}
            
        except Exception as e:
            if self.conn:
                self.conn.rollback()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def delete_content(self, content_id):
        """Delete content"""
        try:
            self._get_db_connection()
            
            query = "DELETE FROM contents WHERE id = %s"
            self.cursor.execute(query, (content_id,))
            self.conn.commit()
            
            if self.cursor.rowcount == 0:
                return {'success': False, 'message': 'Content not found'}
            
            print(f"[CONTENT] Deleted content ID: {content_id}")
            
            return {'success': True, 'message': 'Content deleted successfully'}
            
        except Exception as e:
            if self.conn:
                self.conn.rollback()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def change_status(self, content_id, new_status, approver_id, approver_role, notes=None):
        """Change content status with approval tracking"""
        try:
            self._get_db_connection()
            
            # Validate status transition
            valid_statuses = ['draft', 'pending', 'approved', 'published', 'rejected']
            if new_status not in valid_statuses:
                return {'success': False, 'message': 'Invalid status'}
            
            # Update content status
            if new_status == 'published':
                query = "UPDATE contents SET status = %s, published_at = NOW() WHERE id = %s"
            else:
                query = "UPDATE contents SET status = %s WHERE id = %s"
            
            self.cursor.execute(query, (new_status, content_id))
            
            # Map status to action
            action_map = {
                'pending': 'submit',
                'approved': 'approve',
                'published': 'publish',
                'rejected': 'reject'
            }
            action = action_map.get(new_status, 'submit')
            
            # Insert approval record
            approval_query = """
                INSERT INTO content_approvals (content_id, approver_id, approver_role, action, notes)
                VALUES (%s, %s, %s, %s, %s)
            """
            self.cursor.execute(approval_query, (content_id, approver_id, approver_role, action, notes))
            
            self.conn.commit()
            
            print(f"[CONTENT] Status changed to '{new_status}' for content ID: {content_id}")
            
            return {'success': True, 'message': f'Content status changed to {new_status}'}
            
        except Exception as e:
            if self.conn:
                self.conn.rollback()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def get_approval_history(self, content_id):
        """Get approval history for content"""
        try:
            self._get_db_connection()
            
            query = """
                SELECT ca.*, COALESCE(u.full_name, ca.approver_role) as approver_name
                FROM content_approvals ca
                LEFT JOIN users u ON ca.approver_id = u.id
                WHERE ca.content_id = %s
                ORDER BY ca.created_at DESC
            """
            self.cursor.execute(query, (content_id,))
            history = self.cursor.fetchall()
            
            return {'success': True, 'history': history}
            
        except Exception as e:
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()

    def get_approved_roles(self, content_id):
        """Get distinct roles that have approved the content"""
        try:
            self._get_db_connection()

            last_submit_query = """
                SELECT MAX(created_at) AS last_submit
                FROM content_approvals
                WHERE content_id = %s AND action = 'submit'
            """
            self.cursor.execute(last_submit_query, (content_id,))
            last_submit = self.cursor.fetchone()['last_submit']

            if not last_submit:
                return {'success': True, 'roles': []}

            query = """
                SELECT DISTINCT approver_role
                FROM content_approvals
                WHERE content_id = %s
                  AND action = 'approve'
                  AND created_at >= %s
            """
            self.cursor.execute(query, (content_id, last_submit))
            roles = [row['approver_role'] for row in self.cursor.fetchall()]

            return {'success': True, 'roles': roles}

        except Exception as e:
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
