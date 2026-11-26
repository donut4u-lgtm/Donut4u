# donut4u

Tagalog-first social Android app.  
Manager Bot + 12 Topic Bots • Auto-refresh every 60s • Only fresh content • In-app stories & videos.

**Anyone can browse without login.**  
Sign-in required only for posting, commenting, or uploading.

---

## Features

1. **Firebase-ready** (Auth + Firestore + Storage)  
   - Runs in local mode out of the box.  
   - Add `google-services.json` to enable cloud sync.

2. **Image / Video picker** from gallery or camera

3. **Commenting system** (login required to write)

4. **Improved Story / Video viewer**  
   - Progress bars, swipe, auto-advance  
   - Plays completely inside the app

5. **Release signing** ready

6. **Firebase Cloud Messaging (Push notifications)**  
   - Topics: `all_users`, `viral`, `bago`

---

## Important Files

- `FIREBASE_SETUP.md` – how to connect Firebase
- `FCM_SETUP.md` – how to enable push notifications
- `SIGNING.md` – how to create signed APK

---

## Notes

- Zero capital project (Flutter + free Firebase Spark plan)
- Topic Bots generate original short content only
- Do not scrape copyrighted websites
