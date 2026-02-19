# File: backend/test_db.py

import MySQLdb
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

print("🔍 Testing Database Connection...")
print("="*50)

try:
    # Connect to database
    conn = MySQLdb.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        user=os.getenv('DB_USER', 'root'),
        password=os.getenv('DB_PASSWORD', ''),
        database=os.getenv('DB_NAME', 'sistem_humas_poltek')
    )
    
    print("✅ Database connection: SUCCESS")
    print()
    
    cursor = conn.cursor()
    
    # Test 1: Check tables
    print("📋 Checking tables...")
    cursor.execute("SHOW TABLES")
    tables = cursor.fetchall()
    print(f"✅ Found {len(tables)} tables:")
    for table in tables:
        print(f"   - {table[0]}")
    print()
    
    # Test 2: Check roles
    print("👥 Checking roles...")
    cursor.execute("SELECT id, role_name FROM roles")
    roles = cursor.fetchall()
    print(f"✅ Found {len(roles)} roles:")
    for role in roles:
        print(f"   - ID {role[0]}: {role[1]}")
    print()
    
    # Test 3: Check users
    print("🔐 Checking users...")
    cursor.execute("SELECT id, username, email, full_name FROM users")
    users = cursor.fetchall()
    print(f"✅ Found {len(users)} users:")
    for user in users:
        print(f"   - ID {user[0]}: {user[1]} ({user[2]})")
    print()
    
    # Test 4: Check permissions
    print("🛡️ Checking permissions...")
    cursor.execute("SELECT COUNT(*) as total FROM permissions")
    perm_count = cursor.fetchone()[0]
    print(f"✅ Found {perm_count} permissions")
    print()
    
    cursor.close()
    conn.close()
    
    print("="*50)
    print("🎉 All tests PASSED! Database setup is complete!")
    
except MySQLdb.Error as e:
    print(f"❌ Database Error: {e}")
    print()
    print("💡 Troubleshooting:")
    print("   1. Check if MySQL is running")
    print("   2. Verify credentials in .env file")
    print("   3. Make sure database 'sistem_humas_poltek' exists")
    print("   4. Ensure init_db.sql has been imported")
    
except Exception as e:
    print(f"❌ Error: {e}")
