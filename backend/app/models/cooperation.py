import MySQLdb
from flask import current_app


class Cooperation:
    """Cooperation model for managing collaboration applications"""

    def __init__(self):
        self.conn = None
        self.cursor = None

    def _get_db_connection(self):
        try:
            self.conn = MySQLdb.connect(
                host=current_app.config['MYSQL_HOST'],
                port=current_app.config['MYSQL_PORT'],
                user=current_app.config['MYSQL_USER'],
                password=current_app.config['MYSQL_PASSWORD'],
                database=current_app.config['MYSQL_DB'],
            )
            self.cursor = self.conn.cursor(MySQLdb.cursors.DictCursor)
        except Exception as e:
            raise Exception(f"Database connection failed: {str(e)}")

    def _close_db_connection(self):
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()

    def create_cooperation(
        self,
        institution_name,
        contact_name,
        email,
        phone,
        purpose,
        event_date,
        document_name,
        document_mime,
        document_data,
        created_by,
    ):
        """Create new cooperation application (status: pending)"""
        try:
            self._get_db_connection()

            query = """
                INSERT INTO cooperations
                (institution_name, contact_name, email, phone, purpose, event_date,
                 document_name, document_mime, document_data, status, created_by)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'pending', %s)
            """
            self.cursor.execute(
                query,
                (
                    institution_name,
                    contact_name,
                    email,
                    phone,
                    purpose,
                    event_date,
                    document_name,
                    document_mime,
                    document_data,
                    created_by,
                ),
            )
            self.conn.commit()

            coop_id = self.cursor.lastrowid
            return {'success': True, 'cooperation_id': coop_id}
        except Exception as e:
            if self.conn:
                self.conn.rollback()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()

    def get_cooperations(self, created_by=None, status=None):
        """Get cooperation applications (all or by creator)"""
        try:
            self._get_db_connection()

            query = """
                SELECT
                    c.id, c.institution_name, c.contact_name, c.email, c.phone,
                    c.purpose, c.event_date, c.document_name, c.document_mime,
                    c.status, c.created_by, c.created_at, c.updated_at,
                    u.full_name as created_by_name
                FROM cooperations c
                JOIN users u ON c.created_by = u.id
                WHERE 1=1
            """
            params = []

            if created_by:
                query += " AND c.created_by = %s"
                params.append(created_by)

            if status:
                query += " AND c.status = %s"
                params.append(status)

            query += " ORDER BY c.created_at DESC"

            self.cursor.execute(query, params)
            rows = self.cursor.fetchall()

            return {'success': True, 'cooperations': rows}
        except Exception as e:
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()

    def get_cooperation_by_id(self, cooperation_id):
        """Get cooperation by ID"""
        try:
            self._get_db_connection()
            query = """
                SELECT
                    c.id, c.institution_name, c.contact_name, c.email, c.phone,
                    c.purpose, c.event_date, c.document_name, c.document_mime,
                    c.status, c.created_by, c.created_at, c.updated_at,
                    u.full_name as created_by_name
                FROM cooperations c
                JOIN users u ON c.created_by = u.id
                WHERE c.id = %s
            """
            self.cursor.execute(query, (cooperation_id,))
            row = self.cursor.fetchone()
            if not row:
                return {'success': False, 'message': 'Cooperation not found'}
            return {'success': True, 'cooperation': row}
        except Exception as e:
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()

    def get_document_by_id(self, cooperation_id):
        """Get cooperation document by ID"""
        try:
            self._get_db_connection()
            query = """
                SELECT document_name, document_mime, document_data, created_by
                FROM cooperations
                WHERE id = %s
            """
            self.cursor.execute(query, (cooperation_id,))
            row = self.cursor.fetchone()
            if not row:
                return {'success': False, 'message': 'Cooperation not found'}
            return {'success': True, 'document': row}
        except Exception as e:
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()

    def change_status(self, cooperation_id, new_status):
        """Change cooperation status"""
        try:
            self._get_db_connection()

            query = "UPDATE cooperations SET status = %s WHERE id = %s"
            self.cursor.execute(query, (new_status, cooperation_id))
            self.conn.commit()

            if self.cursor.rowcount == 0:
                return {'success': False, 'message': 'Cooperation not found'}

            return {'success': True}
        except Exception as e:
            if self.conn:
                self.conn.rollback()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
