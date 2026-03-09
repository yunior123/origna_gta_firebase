"""Module test_firestore.py."""
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate('orignagta-dev-firebase-adminsdk.json')
try:
    firebase_admin.initialize_app(cred, {'projectId': 'orignagta-dev'})
except ValueError:
    pass

db = firestore.client()
doc_ref = db.collection("_mail_logs").document("test_doc")
doc_ref.set({"to": "test@example.com", "subject": "Test", "html": "Hello"})
print("Document written")
