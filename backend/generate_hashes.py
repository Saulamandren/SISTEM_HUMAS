from argon2 import PasswordHasher
ph = PasswordHasher()

staff_hash = ph.hash("staff123")
kasubag_hash = ph.hash("kasubag123")

print("ARGON2 STAFF1:", staff_hash)
print("ARGON2 KASUBAG2:", kasubag_hash)
