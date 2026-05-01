import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import sys
import os

# Path to your service account key
CRED_PATH = 'assets/credentials.json'

def manage_admins():
    if not os.path.exists(CRED_PATH):
        print(f"❌ Error: {CRED_PATH} not found.")
        return

    if not firebase_admin._apps:
        cred = credentials.Certificate(CRED_PATH)
        firebase_admin.initialize_app(cred)

    db = firestore.client()

    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 manage_admins.py add <email> [role]")
        print("  python3 manage_admins.py remove <email>")
        print("  python3 manage_admins.py list")
        return

    action = sys.argv[1].lower()

    if action == 'list':
        docs = db.collection('admins').stream()
        print("\n--- Current Authorized Users ---")
        for doc in docs:
            data = doc.to_dict()
            print(f"📧 {doc.id} | 🔑 Role: {data.get('role', 'admin')}")
        print("--------------------------------\n")
        return

    if len(sys.argv) < 3:
        print(f"Error: Email required for {action}")
        return

    email = sys.argv[2].lower().strip()
    doc_ref = db.collection('admins').document(email)

    if action == 'add':
        role = sys.argv[3].lower() if len(sys.argv) > 3 else 'admin'
        doc_ref.set({
            'added_at': firestore.SERVER_TIMESTAMP,
            'role': role
        })
        print(f"✅ Added: {email} as {role}")
    
    elif action == 'remove':
        doc_ref.delete()
        print(f"🗑️  Removed: {email}")

if __name__ == "__main__":
    manage_admins()
