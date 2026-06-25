import firebase_admin
from firebase_admin import credentials, firestore
from config import settings

_app = None
_db = None


def get_db():
    """Returns a singleton Firestore client."""
    global _app, _db
    if _db is None:
        if not firebase_admin._apps:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            _app = firebase_admin.initialize_app(cred)
        _db = firestore.client()
    return _db
