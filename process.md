가상화
venv\Scripts\activate

git pull, push
git pull origin main
git add .
git commit -m ""
git push -u origin main

배포
firebase login
flutter build apk --release
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
 --app 1:645349953984:android:7e5aa56212bde3ad0bb825 --groups "testers"
