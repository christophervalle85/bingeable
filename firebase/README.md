# Firebase backend (Auth + Firestore)

This project stores signed-in library records in:

- `users/{uid}/library/{showId}`

## Local emulator run

1. Install Firebase CLI (`firebase-tools`).
2. From the repo root, start emulators:

```bash
firebase emulators:start --only auth,firestore
```

3. In Xcode Scheme > Run > Arguments > Environment Variables, set:

- `FIREBASE_AUTH_USE_EMULATOR=1`
- `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1`
- `FIREBASE_AUTH_EMULATOR_PORT=9099`
- `FIRESTORE_USE_EMULATOR=1`
- `FIRESTORE_EMULATOR_HOST=127.0.0.1`
- `FIRESTORE_EMULATOR_PORT=8080`

## Deploy rules/indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```
